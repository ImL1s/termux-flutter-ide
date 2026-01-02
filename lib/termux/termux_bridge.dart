import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert'; // For utf8

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
    bool background = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'executeCommand',
        {
          'command': command,
          'workingDirectory': workingDirectory,
          'background': background,
        },
      );

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

  /// 自動設定 Termux SSH 環境 (Auto-Bootstrap)
  ///
  /// 執行: pkg update && pkg install openssh && passwd -d && sshd
  /// 注意：這裡為了無人值守，使用 chpasswd 設定預設密碼。
  /// chpasswd 可以透過 stdin 設定密碼，不需要 TTY。
  ///
  /// MVP 策略：啟動 SSHD (需要用戶先手動設定密碼)
  Future<TermuxResult> setupTermuxSSH() {
    // 1. Acquire WakeLock
    // 2. Install OpenSSH if not present
    // 3. Generate SSH keys if needed
    // 4. Start SSHD
    //
    // NOTE: We attempt to set the password to 'termux' automatically.
    // 1. Try 'chpasswd' with current user
    // 2. Try piping to 'passwd' as fallback
    const cmd = 'export PATH=/data/data/com.termux/files/usr/bin:\$PATH; '
        'termux-wake-lock; '
        'apt-get update -y > /dev/null 2>&1 || true; ' // Update repo lists
        'apt-get install -y openssh > /dev/null 2>&1 || true; ' // Use apt-get for consistency
        'echo "\$(whoami):termux" | chpasswd > /dev/null 2>&1 || (echo "termux"; echo "termux") | passwd > /dev/null 2>&1 || true; '
        'ssh-keygen -A 2>/dev/null || true; '
        'sshd 2>/dev/null || pkill sshd; sleep 1; sshd';
    return executeCommand(cmd, background: false);
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
    const cmd =
        'termux-wake-lock; curl -sL $installScript | bash; termux-wake-unlock';
    return executeCommand(cmd, background: false);
  }

  /// 檢查 Flutter 是否已安裝
  Future<bool> isFlutterInstalled() async {
    final result = await executeCommand('which flutter');
    return result.success && result.stdout.trim().isNotEmpty;
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
      // 使用 sh -c 執行，並將 stdout (1) 和 stderr (2) 導向到 /dev/tcp/127.0.0.1/PORT
      // Note: The simple redirection > /dev/tcp/... sometimes closes too early or buffers.
      // A more robust way might be needed, but let's try direct redirection first.
      // Direct redirection: ($command) > /dev/tcp/127.0.0.1/$port 2>&1

      final robustCommand =
          'sh -c "($command) > /dev/tcp/127.0.0.1/$port 2>&1"';

      // 3. 執行指令 (Fire and forget, output comes via socket)
      // 使用 background=true 避免 Termux 搶焦點 (視需求而定)
      executeCommand(robustCommand,
          workingDirectory: workingDirectory, background: true);

      // 4. 等待連線
      // 設定超時
      await for (final socket
          in server.timeout(const Duration(seconds: 5), onTimeout: (sink) {
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
