import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/ssh_service.dart';
import '../termux/x11_service.dart';
import '../termux/termux_providers.dart'; // import termuxBridgeProvider

/// Setup steps
enum SetupStep {
  welcome,
  environmentCheck, // New: check all prerequisites before starting
  termux, // Check if Termux app is installed
  termuxPermission, // Enable allow-external-apps in Termux (Prerequisite for Bridge)
  dependencies, // New: Fix environment (pkg upgrade) and install Git
  ssh,
  flutter,
  x11, // Optional, can be done later, but good to check
  complete,
}

/// Setup state
class SetupState {
  final SetupStep currentStep;
  final bool isTermuxInstalled;
  final bool isSSHConnected;
  final bool isGitInstalled;
  final bool isFlutterInstalled;
  final bool isX11Installed;
  final bool isInstalling;
  final String? installLog;

  const SetupState({
    this.currentStep = SetupStep.welcome,
    this.isTermuxInstalled = false,
    this.isSSHConnected = false,
    this.isGitInstalled = false,
    this.isFlutterInstalled = false,
    this.isX11Installed = false,
    this.isInstalling = false,
    this.installLog,
  });

  SetupState copyWith({
    SetupStep? currentStep,
    bool? isTermuxInstalled,
    bool? isSSHConnected,
    bool? isGitInstalled,
    bool? isFlutterInstalled,
    bool? isX11Installed,
    bool? isInstalling,
    String? installLog,
  }) {
    return SetupState(
      currentStep: currentStep ?? this.currentStep,
      isTermuxInstalled: isTermuxInstalled ?? this.isTermuxInstalled,
      isSSHConnected: isSSHConnected ?? this.isSSHConnected,
      isGitInstalled: isGitInstalled ?? this.isGitInstalled,
      isFlutterInstalled: isFlutterInstalled ?? this.isFlutterInstalled,
      isX11Installed: isX11Installed ?? this.isX11Installed,
      isInstalling: isInstalling ?? this.isInstalling,
      installLog: installLog ?? this.installLog,
    );
  }
}

/// Setup Service Notifier
class SetupService extends Notifier<SetupState> {
  @override
  SetupState build() => const SetupState();

  /// Check overall environment status
  Future<void> checkEnvironment() async {
    final sshService = ref.read(sshServiceProvider);
    final x11Service = ref.read(x11ServiceProvider);
    final termuxBridge = ref.read(termuxBridgeProvider);

    // Auto-reconnect SSH if needed
    if (!sshService.isConnected) {
      try {
        await sshService.connect();

        if (!sshService.isConnected) {
          print('SetupService: SSH check failed. Bootstrapping...');
          await sshService.ensureBootstrapped();
          await sshService.connect();
        }
      } catch (e) {
        print('SetupService: Auto-reconnect failed: $e');
      }
    }

    // Check Termux installation first
    final isTermux = await termuxBridge.isTermuxInstalled();
    // final isConnected = true; // Mock for Flutter testing
    final isConnected = sshService.isConnected;

    bool isFlutter = false;
    bool isGit = false;
    bool isX11 = false;

    if (isConnected) {
      try {
        // 1. Verify functionality
        final gitResult =
            await sshService.executeWithDetails('git --version');
        isGit = gitResult.exitCode == 0;

        final result =
            await sshService.executeWithDetails('source /data/data/com.termux/files/usr/etc/profile.d/flutter.sh 2>/dev/null; flutter --version 2>&1');
        print(
            'TERMUX_IDE_SETUP: flutter --version -> ${result.exitCode}, val: ${result.stdout}');
        isFlutter = result.exitCode == 0 && result.stdout.contains('Flutter');

        if (isFlutter) {
          print('TERMUX_IDE_SETUP: Flutter FOUND and WORKING!');
        } else {
          print('TERMUX_IDE_SETUP: Flutter NOT found or BROKEN.');
        }
        isX11 = await x11Service.isInstalled();
      } catch (e) {
        print('TERMUX_IDE_SETUP: Error checking environment: $e');
        // Ignore errors during check
      }
    } else {
      // If SSH not connected, try checking via bridge (Intent)
      print('TERMUX_IDE_SETUP: SSH not connected. Checking via bridge...');
      // Limited check via bridge if SSH down
      isFlutter = await termuxBridge.isFlutterInstalled();
    }

    print(
        'TERMUX_IDE_SETUP: Final Check -> isFlutter: $isFlutter, isGit: $isGit, isTermux: $isTermux, isSSH: $isConnected');

    state = state.copyWith(
      isTermuxInstalled: isTermux,
      isSSHConnected: isConnected,
      isGitInstalled: isGit,
      isFlutterInstalled: isFlutter,
      isX11Installed: isX11,
      // If we found flutter, we are definitely not "installing" anymore
      isInstalling: isFlutter ? false : state.isInstalling,
    );
  }

  /// Install X11 environment (x11-repo, termux-x11-nightly, fix dependencies)
  Future<void> installX11() async {
    final sshService = ref.read(sshServiceProvider);

    // Ensure SSH is connected
    if (!sshService.isConnected) {
      state = state.copyWith(
          isInstalling: true, installLog: '正在建立 SSH 連線...\n');
      try {
        await sshService.connect();
      } catch (e) {
        state = state.copyWith(
            installLog: '${state.installLog}SSH 連線失敗: $e\n無法繼續安裝 X11。\n');
        return;
      }
    }

    state = state.copyWith(
        isInstalling: true,
        installLog: '正在安裝 X11 圖形介面環境...\n這需要安裝多個套件，請稍候。\n\n');

    try {
      // 1. Install x11-repo
      state = state.copyWith(
          installLog: '${state.installLog ?? ""}正在啟用 X11 repository...\n');
      await sshService.executeWithDetails('pkg install x11-repo -y');

      // 2. Fix broken dependencies (Crucial step observed in E2E)
      state = state.copyWith(
          installLog: '${state.installLog ?? ""}正在檢查並修復套件依賴 (apt --fix-broken)...\n');
      // We ignore exit code here as there might be nothing to fix, but we run it just in case
      await sshService.executeWithDetails('apt --fix-broken install -y');

      // 3. Install termux-x11-nightly and pulseaudio
      state = state.copyWith(
          installLog: '${state.installLog ?? ""}正在安裝 termux-x11-nightly 與 pulseaudio...\n');
      final installResult = await sshService.executeWithDetails('pkg install termux-x11-nightly pulseaudio -y');

      if (installResult.exitCode != 0) {
        throw Exception('安裝失敗: ${installResult.stderr}');
      }

      // 4. Configure environment variables in .bashrc (Persistence)
      state = state.copyWith(
          installLog: '${state.installLog ?? ""}正在設定環境變數 (.bashrc)...\n');
      
      // Check if DISPLAY is already in bashrc to avoid duplicates
      final bashrcCheck = await sshService.executeWithDetails('grep -q "DISPLAY=:0" ~/.bashrc');
      if (bashrcCheck.exitCode != 0) {
          // Add variables
          await sshService.executeWithDetails('echo "export TMPDIR=\$PREFIX/tmp" >> ~/.bashrc');
          await sshService.executeWithDetails('echo "export PKG_CONFIG_PATH=\$PREFIX/lib/pkgconfig" >> ~/.bashrc');
          await sshService.executeWithDetails('echo "export DISPLAY=:0" >> ~/.bashrc');
          state = state.copyWith(
            installLog: '${state.installLog ?? ""}已加入 DISPLAY 與 TMPDIR 設定至 .bashrc\n',
          );
      } else {
        state = state.copyWith(
            installLog: '${state.installLog ?? ""}環境變數已存在，跳過設定。\n',
          );
      }

      state = state.copyWith(
          isInstalling: false,
          installLog: '${state.installLog ?? ""}X11 安裝完成！\n請記得在 Android 端安裝 Termux:X11 應用程式。\n',
          isX11Installed: true,
      );

      // Refresh environment
      await checkEnvironment();

    } catch (e) {
      state = state.copyWith(
        isInstalling: false,
        installLog: '${state.installLog ?? ""}X11 安裝發生錯誤: $e\n',
      );
    }
  }


  /// Go directly to Flutter installation step (via permission step)
  void goToFlutterStep() {
    state = state.copyWith(
      currentStep: SetupStep.termuxPermission,
      isFlutterInstalled: false,
    );
  }

  /// Move to next step
  void nextStep() {
    switch (state.currentStep) {
      case SetupStep.welcome:
        // After welcome, go to environment check
        state = state.copyWith(currentStep: SetupStep.environmentCheck);
        break;
      case SetupStep.environmentCheck:
        // Go to permissions step first to ensure external apps are allowed
        state = state.copyWith(currentStep: SetupStep.termuxPermission);
        break;
      case SetupStep.termux:
        state = state.copyWith(currentStep: SetupStep.ssh);
        break;
      case SetupStep.termuxPermission:
        state = state.copyWith(currentStep: SetupStep.dependencies);
        break;
      case SetupStep.dependencies:
        state = state.copyWith(currentStep: SetupStep.ssh);
        break;
      case SetupStep.ssh:
        // Always go to Flutter from SSH for now to simplify setup
        state = state.copyWith(currentStep: SetupStep.flutter);
        break;
      case SetupStep.flutter:
        // Assume installation done or skipped
        state = state.copyWith(currentStep: SetupStep.x11);
        break;
      case SetupStep.x11:
        state = state.copyWith(currentStep: SetupStep.complete);
        break;
      case SetupStep.complete:
        // Finish
        break;
    }
  }

  /// Retry connection
  Future<bool> retryConnection() async {
    // Force a connection attempt
    await ref.read(sshServiceProvider).connectWithRetry();
    await checkEnvironment();
    return state.isSSHConnected;
  }

  /// Install Flutter using the script (via SSH)
  Future<void> installFlutter() async {
    final sshService = ref.read(sshServiceProvider);

    // Ensure SSH is connected
    if (!sshService.isConnected) {
      state =
          state.copyWith(isInstalling: true, installLog: '正在建立 SSH 連線...\n');
      try {
        await sshService.connect();
      } catch (e) {
        state = state.copyWith(
            installLog: '${state.installLog}SSH 連線失敗: $e\n嘗試使用 Bridge 安裝...\n');
      }
    }

    if (!sshService.isConnected) {
      // Fall back to Bridge installation if SSH not connected
      await installFlutterViaBridge();
      return;
    }

    state = state.copyWith(
        isInstalling: true, installLog: '正在初始化安裝程序...\n請勿關閉應用程式。\n\n');

    try {
      // 1. 下載腳本
      state =
          state.copyWith(installLog: '${state.installLog ?? ""}正在下載安裝腳本...\n');

      final downloadCmd =
          '/data/data/com.termux/files/usr/bin/curl -sLf https://raw.githubusercontent.com/ImL1s/termux-flutter-wsl/master/install_flutter_complete.sh -o ~/install_termux_flutter.sh';
      final downloadResult = await sshService.executeWithDetails(downloadCmd);

      if (downloadResult.exitCode != 0) {
        throw Exception(
            '下載失敗 (Code ${downloadResult.exitCode}): ${downloadResult.stderr}\n${downloadResult.stdout}');
      }

      state = state.copyWith(
          installLog: '${state.installLog ?? ""}下載成功，正在賦予執行權限...\n');

      // 2. 賦予權限
      await sshService
          .executeWithDetails('chmod +x ~/install_termux_flutter.sh');

      // 2.5 修復可能的 libuuid 連結問題 (Termux 常見問題)
      state = state.copyWith(
          installLog: '${state.installLog ?? ""}正在修復依賴套件並安裝 termux-tools...\n');
      await sshService.executeWithDetails(
          'pkg install -y termux-tools libandroid-posix-semaphore libuuid 2>/dev/null || true');

      // 3. 執行腳本 (使用 nohup 在背景執行，避免 SSH 連線逾時)
      state = state.copyWith(
          installLog:
              '${state.installLog ?? ""}開始執行安裝腳本...\n這個過程可能需要 5-10 分鐘。\n');

      // 使用 nohup 在背景執行腳本，輸出到 log 檔案
      const logFile = '/data/data/com.termux/files/home/flutter_install.log';
      const installCmd =
          'nohup /data/data/com.termux/files/usr/bin/bash ~/install_termux_flutter.sh > $logFile 2>&1 &';

      // 啟動背景安裝
      await sshService.executeWithDetails(installCmd);

      // 等待一秒讓腳本開始
      await Future.delayed(const Duration(seconds: 1));

      // 使用 tail -f 監控 log 檔案，直到安裝完成
      // 設定一個監控迴圈，每 2 秒檢查一次
      bool installComplete = false;
      int checkCount = 0;
      const maxChecks = 300; // 最多等待 10 分鐘 (300 * 2 秒)

      while (!installComplete && checkCount < maxChecks) {
        await Future.delayed(const Duration(seconds: 2));
        checkCount++;

        // 讀取最新的 log 內容
        final logResult = await sshService.executeWithDetails('cat $logFile');
        if (logResult.exitCode == 0) {
          state = state.copyWith(
            installLog:
                '正在初始化安裝程序...\n請勿關閉應用程式。\n\n正在下載安裝腳本...\n下載成功，正在賦予執行權限...\n開始執行安裝腳本...\n這個過程可能需要 5-10 分鐘。\n${logResult.stdout}',
          );

          // 檢查安裝是否完成 (腳本結尾會顯示 "Installation Complete!")
          if (logResult.stdout.contains('Installation Complete!') ||
              logResult.stdout.contains('安裝完成') ||
              logResult.stdout.contains('Verify installation:')) {
            installComplete = true;
          }
        }

        // 檢查腳本是否還在執行
        final psResult = await sshService
            .executeWithDetails('pgrep -f install_termux_flutter || echo done');
        if (psResult.stdout.trim() == 'done' && checkCount > 5) {
          // 腳本已結束
          installComplete = true;
        }
      }

      // Verify installation result and fix shebangs
      final flutterPathResult = await sshService.executeWithDetails(
          'which flutter || (ls ~/flutter/bin/flutter 2>/dev/null && echo /data/data/com.termux/files/home/flutter/bin/flutter)');
      if (flutterPathResult.exitCode == 0 &&
          flutterPathResult.stdout.trim().isNotEmpty) {
        final flutterPath = flutterPathResult.stdout.trim();
        state = state.copyWith(
            installLog:
                '${state.installLog ?? ""}正在修復 Flutter 及其 SDK 的執行檔路徑 (shebangs)...\n');

        // Fix shebangs for the main binary and everything in its bin dir
        final flutterBinDir = flutterPath.replaceAll('/flutter', '');
        await sshService.executeWithDetails(
            'termux-fix-shebang "$flutterPath" && find "$flutterBinDir" -type f -exec termux-fix-shebang {} \\; && termux-fix-shebang "\$PREFIX/opt/flutter/packages/flutter_tools/bin/tool_backend.sh"');

        state = state.copyWith(
          isInstalling: false,
          installLog: '${state.installLog ?? ""}安裝腳本執行完畢，Flutter 已準備就緒。\n',
          isFlutterInstalled: true,
        );
      } else {
        state = state.copyWith(
          isInstalling: false,
          installLog:
              '${state.installLog ?? ""}安裝腳本執行完畢，但無法找到 Flutter 指令。\n請檢查上方日誌了解詳細資訊。\n',
          isFlutterInstalled: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isInstalling: false,
        installLog: '${state.installLog ?? ""}安裝過程中發生錯誤: $e\n',
      );
    }
  }

  /// Install Flutter via Termux Bridge (no SSH required)
  Future<void> installFlutterViaBridge() async {
    final termuxBridge = ref.read(termuxBridgeProvider);

    state = state.copyWith(
      isInstalling: true,
      installLog:
          '${state.installLog ?? ""}正在啟動安裝腳本 (Fallback)...\n請切換到 Termux 查看進度\n',
    );

    try {
      await termuxBridge.installFlutter();

      // Note: We can't know when it finishes since it runs in Termux
      // User should manually check or call checkEnvironment()
      state = state.copyWith(
        installLog:
            '${state.installLog ?? ""}安裝指令已發送到 Termux\n請查看 Termux 應用程式以追蹤進度\n',
      );
    } catch (e) {
      state = state.copyWith(
        isInstalling: false,
        installLog: '${state.installLog ?? ""}發送失敗: $e\n',
      );
    }
  }

  /// Set installing state (for UI control)
  void setInstalling(bool installing, {String? log}) {
    state = state.copyWith(
      isInstalling: installing,
      installLog: log ?? state.installLog,
    );
  }


  /// Install Dependencies (Git, pkg upgrade)
  Future<void> installDependencies() async {
    final sshService = ref.read(sshServiceProvider);

    // Ensure SSH is connected
    if (!sshService.isConnected) {
      state = state.copyWith(
          isInstalling: true, installLog: '正在建立 SSH 連線...\n');
      try {
        await sshService.connect();
      } catch (e) {
        state = state.copyWith(
            installLog: '${state.installLog}SSH 連線失敗: $e\n請先檢查連線設定。\n');
        return;
      }
    }

    state = state.copyWith(
        isInstalling: true,
        installLog: '正在更新系統套件並安裝 Git...\n這可能需要幾分鐘，請勿關閉。\n\n');

    try {
      // Use 'yes n' to answer 'No' to all interactive prompts during upgrade
      // This is crucial for automation
      // Also install curl and wget which are needed for the flutter install script
      const cmd =
          'yes n | pkg upgrade -y && pkg install git curl wget clang cmake ninja pkg-config gtk3 binutils -y && echo "DEPENDENCIES_INSTALLED"';

      state = state.copyWith(
          installLog:
              '${state.installLog}正在執行: pkg upgrade -y && pkg install git curl wget\n(自動拒絕設定檔覆蓋以保持預設)\n\n');

      final result = await sshService.executeWithDetails(cmd);

      if (result.exitCode == 0) {
        state = state.copyWith(
          isInstalling: false,
          installLog: '${state.installLog}安裝成功！\nGit 已就緒。\n系統已更新。\n',
          isGitInstalled: true,
        );
        // Refresh environment logic
        await checkEnvironment();
      } else {
        state = state.copyWith(
          isInstalling: false,
          installLog:
              '${state.installLog}安裝失敗 (Code ${result.exitCode}):\n${result.stderr}\n${result.stdout}\n',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isInstalling: false,
        installLog: '${state.installLog}發生錯誤: $e\n',
      );
    }
  }

  /// Automate Termux permission setup (allow-external-apps)
  Future<void> setupTermuxPermissions() async {
    final sshService = ref.read(sshServiceProvider);

    state = state.copyWith(
        isInstalling: true, installLog: '正在設定 Termux 權限...\n請勿關閉應用程式。\n\n');

    try {
      // 1. Check/Install SSH connection first
      if (!sshService.isConnected) {
        state = state.copyWith(
            installLog: '${state.installLog}正在嘗試建立連線...\n');
        try {
          await sshService.connect();
        } catch (e) {
          // If SSH fails, we can't automate this via SSH.
           state = state.copyWith(
            isInstalling: false,
            installLog: '${state.installLog}SSH 連線失敗，無法自動設定。\n請手動執行指令。\n',
          );
          return;
        }
      }

      state = state.copyWith(
            installLog: '${state.installLog}SSH 連線成功，寫入設定檔...\n');

      // 2. Execute command
      // mkdir -p ~/.termux
      // echo "allow-external-apps=true" > ~/.termux/termux.properties
      // termux-reload-settings
      const cmd = 'mkdir -p ~/.termux && echo "allow-external-apps=true" > ~/.termux/termux.properties && termux-reload-settings';
      
      final result = await sshService.executeWithDetails(cmd);

      if (result.exitCode == 0) {
         state = state.copyWith(
          isInstalling: false,
          installLog: '${state.installLog}設定成功！\nallow-external-apps 已啟用。\n設定已重載。\n',
        );
      } else {
        state = state.copyWith(
          isInstalling: false,
          installLog:
              '${state.installLog}設定失敗 (Code ${result.exitCode}):\n${result.stderr}\n${result.stdout}\n',
        );
      }

    } catch (e) {
      state = state.copyWith(
        isInstalling: false,
        installLog: '${state.installLog}發生錯誤: $e\n',
      );
    }
  }

  /// Verify Termux connection by running a simple command
  Future<void> verifyTermuxConnection() async {
    state = state.copyWith(isInstalling: true, installLog: '正在驗證 Termux 連線權限...\n');
    
    try {
      final result = await ref.read(termuxBridgeProvider).executeCommand('echo "connection_ok"');
      
      if (result.exitCode == 0 && result.stdout.contains('connection_ok')) {
        state = state.copyWith(
          isInstalling: false,
          installLog: '${state.installLog}✅ 連線驗證成功！\n權限設定正確。\n',
        );
        // Refresh environment logic as well
        await checkEnvironment();
      } else {
        state = state.copyWith(
          isInstalling: false,
          installLog: '${state.installLog}❌ 驗證失敗。\n請確保您已手動執行指令並授權。\n',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isInstalling: false,
        installLog: '${state.installLog}❌ 發生錯誤 (可能是權限被拒)：\n請確認 Android 設定中已授權 App「跑指令」的權限。\n',
      );
    }
  }
}

final setupServiceProvider =
    NotifierProvider<SetupService, SetupState>(SetupService.new);
