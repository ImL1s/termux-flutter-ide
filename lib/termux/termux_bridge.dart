import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert'; // For utf8

/// Termux allow-external-apps 設定狀態
enum ExternalAppsStatus {
  /// 已允許外部 App 執行命令
  allowed,

  /// 未允許外部 App 執行命令
  notAllowed,

  /// 無法確定（檢查失敗）
  unknown,
}

/// Termux Bridge - 與 Termux 應用程式通訊的服務
///
/// 使用 Android Intent 透過 Termux:API 或 RunCommandService 執行指令
class TermuxBridge {
  static const MethodChannel _channel =
      MethodChannel('termux_flutter_ide/termux');

  static final TermuxBridge _instance = TermuxBridge._internal();

  factory TermuxBridge() => _instance;

  TermuxBridge._internal();

  /// 檢查 Termux 是否已安裝
  Future<bool> isTermuxInstalled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTermuxInstalled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 執行 Termux 指令
  ///
  /// [command] - 要執行的指令
  /// [workingDirectory] - 工作目錄（可選）
  /// [background] - 是否在背景執行
  Future<TermuxResult> executeCommand(
    String command, {
    String? workingDirectory,
    bool background = true,
  }) async {
    try {
      // Use bash -l (login shell) to ensure .bashrc is sourced.
      // We use Base64 encoding to avoid all quoting issues and ensure complex commands run correctly.
      // This solves issues with nested quotes in SSH commands and other complex scripts.
      final encodedCommand = base64.encode(utf8.encode(command));
      final envCommand =
          "/data/data/com.termux/files/usr/bin/bash -l -c 'eval \$(echo $encodedCommand | base64 -d)'";

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'executeCommand',
        {
          'command': envCommand,
          'workingDirectory': workingDirectory,
          'background': background,
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        return {
          'success': false,
          'exitCode': -1,
          'stdout': '',
          'stderr':
              'Command timed out after 10 seconds. Check allow-external-apps in Termux.'
        };
      });

      return TermuxResult.fromMap(result ?? {});
    } on PlatformException catch (e) {
      return TermuxResult(
        success: false,
        exitCode: -1,
        stdout: '',
        stderr: e.message ?? 'Unknown error',
      );
    }
  }

  /// 執行 Flutter 指令
  Future<TermuxResult> runFlutterCommand(String subCommand) {
    return executeCommand('flutter $subCommand');
  }

  /// 執行 flutter run
  Future<TermuxResult> flutterRun({String? target}) {
    final cmd = target != null ? 'flutter run -t $target' : 'flutter run';
    return executeCommand(cmd, background: true);
  }

  /// 執行 flutter build apk
  Future<TermuxResult> flutterBuildApk({bool release = true}) {
    final mode = release ? '--release' : '--debug';
    return executeCommand('flutter build apk $mode');
  }

  /// 執行 flutter doctor
  Future<TermuxResult> flutterDoctor() {
    return executeCommand('flutter doctor');
  }

  Future<String?> getTermuxPrefix() async {
    try {
      final String? prefix = await _channel.invokeMethod('getTermuxPrefix');
      return prefix;
    } on PlatformException catch (e) {
      print("Failed to get Termux prefix: '${e.message}'.");
      return null;
    }
  }

  Future<int?> getTermuxUid() async {
    try {
      final int? uid = await _channel.invokeMethod('getTermuxUid');
      return uid;
    } on PlatformException catch (e) {
      print("Failed to get Termux UID: '${e.message}'.");
      return null;
    }
  }

  /// 檢查 Termux 是否允許外部應用程式執行命令
  ///
  /// 透過嘗試執行一個簡單的測試指令來判斷：
  /// - 如果指令成功執行 (exit 0)，表示 allow-external-apps 已啟用
  /// - 如果超時或返回 -1，表示 allow-external-apps 未啟用
  /// 這是 Termux RUN_COMMAND API 的必要前提條件
  Future<ExternalAppsStatus> checkExternalAppsAllowed() async {
    try {
      // 嘗試執行一個最簡單的指令來測試 RUN_COMMAND 是否可用
      // 如果 allow-external-apps 未啟用，這個指令會超時
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'executeCommand',
        {
          'command': 'echo __TERMUX_TEST_OK__',
          'workingDirectory': null,
          'background': true,
        },
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        // 超時表示 Termux 沒有回應，很可能是 allow-external-apps 未啟用
        return {'exitCode': -999, 'stdout': '', 'stderr': 'timeout'};
      });

      final exitCode = result?['exitCode'] as int? ?? -1;
      final stdout = result?['stdout'] as String? ?? '';

      // 如果指令成功執行並輸出了預期的字串，表示 allow-external-apps 已啟用
      if (exitCode == 0 && stdout.contains('__TERMUX_TEST_OK__')) {
        return ExternalAppsStatus.allowed;
      } else if (exitCode == -999 || exitCode == -1) {
        // 超時或未收到結果，表示 allow-external-apps 未啟用
        return ExternalAppsStatus.notAllowed;
      } else {
        // 其他情況（如 Termux 未安裝等）
        return ExternalAppsStatus.unknown;
      }
    } on PlatformException catch (e) {
      print('Failed to check allow-external-apps: $e');
      // PlatformException 通常表示 Termux 未安裝或權限問題
      return ExternalAppsStatus.unknown;
    } catch (e) {
      print('Failed to check allow-external-apps: $e');
      return ExternalAppsStatus.unknown;
    }
  }

  /// 啟用 allow-external-apps 設定
  ///
  /// 自動將設定添加到 termux.properties 並重新載入設定
  Future<TermuxResult> enableExternalApps() {
    return executeCommand(
      'mkdir -p ~/.termux && '
      'grep -q "allow-external-apps" ~/.termux/termux.properties 2>/dev/null && '
      'sed -i "s/allow-external-apps=.*/allow-external-apps=true/" ~/.termux/termux.properties || '
      'echo "allow-external-apps=true" >> ~/.termux/termux.properties; '
      'termux-reload-settings 2>/dev/null || true',
      background: true,
    );
  }

  Future<bool> checkTermuxPrefix() async {
    try {
      // 檢查 /data/data/com.termux/files/usr/bin 是否存在
      final result = await executeCommand(
        'ls -d "/data/data/com.termux/files/usr/bin" >/dev/null 2>&1',
        background: true,
      );
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  /// 檢查 SSH 服務狀態
  ///
  /// 回傳 0 表示服務正在執行 (port 9022 有監聽)
  Future<bool> checkSSHServiceStatus() async {
    try {
      // 使用 ss 或 netstat 檢查 port 9022
      // 注意: Android 10+ 限制了 netstat/ss 的輸出，普通權限可能看不到其他 process 的 port
      // 但檢查自己的 process (Termux) 應該是可以的，或者嘗試 pgrep sshd

      // 嘗試 pgrep sshd
      final pgrepResult = await executeCommand('pgrep sshd', background: true);
      if (pgrepResult.exitCode == 0 && pgrepResult.stdout.trim().isNotEmpty) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 開啟 Termux 應用程式
  Future<bool> openTermux() async {
    try {
      final result = await _channel.invokeMethod<bool>('openTermux');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to open Termux: ${e.message}');
      return false;
    }
  }

  /// 開啟 Termux 的 "顯示在其他應用程式上層" 設定頁面
  Future<bool> openTermuxSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openTermuxSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to open Termux settings: ${e.message}');
      return false;
    }
  }

  /// 獲取 Termux 的安裝來源
  ///
  /// 用於檢測是否從 Google Play 安裝 (不支援 RUN_COMMAND)
  Future<String?> getTermuxPackageInstaller() async {
    try {
      return await _channel.invokeMethod<String>('getTermuxPackageInstaller');
    } on PlatformException catch (e) {
      print('Failed to get Termux installer: ${e.message}');
      return null;
    }
  }

  /// 檢查是否擁有特定 Android 權限
  Future<bool> checkPermission(String permission) async {
    try {
      final bool granted = await _channel.invokeMethod('checkPermission', {
        'permission': permission,
      });
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// 開啟 Termux 應用程式
  ///
  /// 用於複製指令後自動打開 Termux，讓使用者可以直接貼上
  Future<bool> launchTermux() async {
    try {
      final bool success = await _channel.invokeMethod('openTermux');
      return success;
    } on PlatformException catch (e) {
      print('Failed to launch Termux: ${e.message}');
      return false;
    }
  }

  /// 開啟電池優化設定頁面
  ///
  /// 用戶可以在此頁面將 Termux 加入電池優化白名單，
  /// 防止系統殺掉 Termux 服務
  Future<bool> openBatteryOptimizationSettings() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to open battery optimization settings: ${e.message}');
      return false;
    }
  }

  /// 檢查 Termux 是否有 "顯示在其他應用程式上層" 權限
  ///
  /// Android 10+ 需要此權限才能自動啟動前台終端
  Future<bool> canDrawOverlays() async {
    try {
      final result = await _channel.invokeMethod<bool>('canDrawOverlays');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check draw overlays permission: ${e.message}');
      return false;
    }
  }

  /// 自動設定 Termux SSH 環境 (Auto-Bootstrap)
  ///
  /// 執行: pkg update && pkg install openssh && passwd -d && sshd
  /// 注意：這裡為了無人值守，使用 chpasswd 設定預設密碼。
  /// chpasswd 可以透過 stdin 設定密碼，不需要 TTY。
  ///
  /// MVP 策略：啟動 SSHD (需要用戶先手動設定密碼)
  Future<TermuxResult> setupTermuxSSH() {
    // Comprehensive SSH setup command that:
    // 1. Installs openssh
    // 2. Enables PasswordAuthentication in sshd_config
    // 3. Sets password to "termux" using passwd
    // 4. Generates host keys
    // 5. Restarts sshd
    const cmd =
        // Install openssh
        'pkg install -y openssh 2>/dev/null || apt-get install -y openssh 2>/dev/null; '
        // Enable PasswordAuthentication in sshd_config
        'SSHD_CONFIG="\$PREFIX/etc/ssh/sshd_config"; '
        'if [ -f "\$SSHD_CONFIG" ]; then '
        '  sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication yes/" "\$SSHD_CONFIG" 2>/dev/null || true; '
        '  grep -q "^PasswordAuthentication" "\$SSHD_CONFIG" || echo "PasswordAuthentication yes" >> "\$SSHD_CONFIG"; '
        'fi; '
        // Set password using printf (more reliable than chpasswd)
        'printf "termux\\ntermux\\n" | passwd 2>/dev/null || true; '
        // Generate host keys if missing
        'ssh-keygen -A 2>/dev/null || true; '
        // Restart sshd (kill existing and start fresh) with confirmation
        'pkill sshd 2>/dev/null; sleep 1; sshd && '
        // Verify SSHD is running on port 8022
        '(sleep 1; ss -tlnp 2>/dev/null | grep -q ":8022" && echo "SSHD_STARTED=SUCCESS" || echo "SSHD_STARTED=FAILED")';

    return executeCommand(cmd, background: true);
  }

  /// 執行 termux-setup-storage
  Future<TermuxResult> setupStorage() {
    return executeCommand('termux-setup-storage', background: true);
  }

  /// 安裝 Flutter (使用 termux-flutter-wsl 腳本)
  ///
  /// 這個方法透過 Intent 直接在 Termux 中執行安裝腳本，
  /// 不需要 SSH 連線就能安裝 Flutter。
  Future<TermuxResult> installFlutter() {
    const installScript =
        'https://raw.githubusercontent.com/ImL1s/termux-flutter-wsl/master/install_termux_flutter.sh';
    // Ensure termux-tools is installed (for termux-fix-shebang) and git/curl.
    // Then run the install script.
    // Finally, explicitly run termux-fix-shebang on the flutter directory to ensure
    // all scripts (including the main flutter wrapper and dart) have correct paths.
    const cmd = 'termux-wake-lock; '
        'pkg update -y && pkg install -y termux-tools git curl wget unzip; '
        'curl -sL $installScript | bash; '
        'echo "Fixing shebangs..."; '
        'termux-fix-shebang "\$PREFIX/opt/flutter/bin/flutter"; '
        'termux-fix-shebang "\$PREFIX/opt/flutter/bin/dart"; '
        'find "\$PREFIX/opt/flutter/bin" -type f -exec termux-fix-shebang {} \\;; '
        'echo "Flutter installation and fix complete."; '
        'termux-wake-unlock';
    return executeCommand(cmd, background: true);
  }

  /// 檢查 Flutter 是否已安裝
  Future<bool> isFlutterInstalled() async {
    // Strictly check for a working flutter binary.
    // We try to run flutter --version and verify exitCode is 0 and output contains 'Flutter'.
    // We redirect stderr to stdout to catch "not found" or other execution errors as well.
    final result =
        await executeCommand('flutter --version 2>&1', background: true);
    print(
        'TERMUX_BRIDGE_DEBUG: flutter check -> code=${result.exitCode}, out=${result.stdout}, err=${result.stderr}');
    return result.exitCode == 0 && result.stdout.contains('Flutter');
  }

  /// 發送指令到 Termux 並取得串流輸出
  ///
  /// 使用 TCP Socket Bridge 技術：
  /// 1. 本地啟動 ServerSocket
  /// 2. 將指令包裝成 Bash TCP Redirection
  /// 3. Termux 執行時將 stdout/stderr 寫入 socket
  Stream<String> executeCommandStream(String command,
      {String? workingDirectory}) async* {
    ServerSocket? server;
    try {
      // 1. 啟動本地伺服器
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;

      // 2. 包裝指令
      // 我們不需要在這裡手動添加 PATH，因為 executeCommand 現在會使用 bash -l
      // 我們不需要使用 & 背景執行，因為我們希望 executeCommand 等待指令完成 (而指令 output 會流向 tcp)
      // 如果使用 &，bash -l 過程會立即結束，可能導致子進程被殺死或 socket 關閉太快
      final robustCommand = '($command) > /dev/tcp/127.0.0.1/$port 2>&1';

      // 3. 執行指令
      executeCommand(robustCommand,
          workingDirectory: workingDirectory, background: true);

      // 4. 等待連線
      // 設定超時 (增加到 15 秒，因為 Termux 啟動可能有延遲)
      await for (final socket
          in server.timeout(const Duration(seconds: 15), onTimeout: (sink) {
        sink.addError('Connection timeout: Termux did not connect back.');
      })) {
        // 處理連線數據
        // transform socket data to string
        yield* socket.cast<List<int>>().transform(utf8.decoder);

        // 通常一次指令一個連線，結束後關閉
        await socket.close();
        break; // 只接受一個連線
      }
    } catch (e) {
      yield 'Error: $e';
    } finally {
      await server?.close();
    }
  }

  /// 修復 Termux 環境 (Mirrors, Pkg, Shebang)
  /// 此過程可能需要一些時間
  Future<void> fixTermuxEnvironment() async {
    print('Starting Termux Environment Fix...');
    try {
      // 1. Fix Mirrors
      await executeCommand(
          "echo 'deb https://grimler.se/termux/termux-main stable main' > \$PREFIX/etc/apt/sources.list",
          background: true);

      // 2. Update & Install
      await executeCommand("pkg update -y", background: true);
      await executeCommand("pkg install -y termux-tools", background: true);

      // 3. Fix Shebang
      await executeCommand(
          "termux-fix-shebang \$PREFIX/opt/flutter/bin/flutter",
          background: true);
      await executeCommand("termux-fix-shebang \$PREFIX/opt/flutter/bin/dart",
          background: true);
      print('Termux Environment Fix Completed.');
    } catch (e) {
      print('Error during Termux fix: $e');
    }
  }
}

/// Termux 指令執行結果
class TermuxResult {
  final bool success;
  final int exitCode;
  final String stdout;
  final String stderr;

  const TermuxResult({
    required this.success,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  factory TermuxResult.fromMap(Map<dynamic, dynamic> map) {
    return TermuxResult(
      success: map['success'] as bool? ?? false,
      exitCode: map['exitCode'] as int? ?? -1,
      stdout: map['stdout'] as String? ?? '',
      stderr: map['stderr'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'TermuxResult(success: $success, exitCode: $exitCode, stdout: $stdout, stderr: $stderr)';
  }
}
