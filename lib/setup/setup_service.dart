import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/ssh_service.dart';
import '../termux/x11_service.dart';
import '../termux/termux_providers.dart'; // import termuxBridgeProvider

/// Setup steps
enum SetupStep {
  welcome,
  termux, // Check if Termux app is installed
  ssh,
  termuxPermission, // Enable allow-external-apps in Termux
  flutter,
  x11, // Optional, can be done later, but good to check
  complete,
}

/// Setup state
class SetupState {
  final SetupStep currentStep;
  final bool isTermuxInstalled;
  final bool isSSHConnected;
  final bool isFlutterInstalled;
  final bool isX11Installed;
  final bool isInstalling;
  final String? installLog;

  const SetupState({
    this.currentStep = SetupStep.welcome,
    this.isTermuxInstalled = false,
    this.isSSHConnected = false,
    this.isFlutterInstalled = false,
    this.isX11Installed = false,
    this.isInstalling = false,
    this.installLog,
  });

  SetupState copyWith({
    SetupStep? currentStep,
    bool? isTermuxInstalled,
    bool? isSSHConnected,
    bool? isFlutterInstalled,
    bool? isX11Installed,
    bool? isInstalling,
    String? installLog,
  }) {
    return SetupState(
      currentStep: currentStep ?? this.currentStep,
      isTermuxInstalled: isTermuxInstalled ?? this.isTermuxInstalled,
      isSSHConnected: isSSHConnected ?? this.isSSHConnected,
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

    // Check Termux installation first
    final isTermux = await termuxBridge.isTermuxInstalled();
    // final isConnected = true; // Mock for Flutter testing
    final isConnected = sshService.isConnected;

    bool isFlutter = false;
    bool isX11 = false;

    if (isConnected) {
      try {
        final flutterPath = await sshService.execute('which flutter');
        isFlutter = flutterPath.trim().isNotEmpty;
        isX11 = await x11Service.isInstalled();
      } catch (e) {
        // Ignore errors during check
      }
    }

    state = state.copyWith(
      isTermuxInstalled: isTermux,
      isSSHConnected: isConnected,
      isFlutterInstalled: isFlutter,
      isX11Installed: isX11,
    );
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
        if (!state.isTermuxInstalled) {
          state = state.copyWith(currentStep: SetupStep.termux);
        } else if (state.isSSHConnected) {
          // Skip SSH step if already connected
          if (state.isFlutterInstalled) {
            state = state.copyWith(currentStep: SetupStep.complete);
          } else {
            // Go through permission step first
            state = state.copyWith(currentStep: SetupStep.termuxPermission);
          }
        } else {
          state = state.copyWith(currentStep: SetupStep.ssh);
        }
        break;
      case SetupStep.termux:
        checkEnvironment().then((_) {
          if (state.isTermuxInstalled) {
            // After installing, go to next step (usually SSH)
            state = state.copyWith(currentStep: SetupStep.ssh);
          }
          // If not installed, stay on step (UI handles it)
        });
        break;
      case SetupStep.ssh:
        checkEnvironment().then((_) {
          if (state.isSSHConnected) {
            if (state.isFlutterInstalled) {
              state = state.copyWith(currentStep: SetupStep.complete);
            } else {
              // Go to permission step first
              state = state.copyWith(currentStep: SetupStep.termuxPermission);
            }
          }
        });
        break;
      case SetupStep.termuxPermission:
        // After permission configuration, go to Flutter install
        if (state.isFlutterInstalled) {
          state = state.copyWith(currentStep: SetupStep.complete);
        } else {
          state = state.copyWith(currentStep: SetupStep.flutter);
        }
        break;
      case SetupStep.flutter:
        // Assume installation done or skipped
        state = state.copyWith(currentStep: SetupStep.complete);
        break;
      // ignore: unreachable_switch_case
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
        isInstalling: true,
        installLog: '正在開始安裝 Flutter (透過 SSH)...\n這可能需要幾分鐘，請勿關閉應用程式。\n\n');

    try {
      const installCmd =
          'curl -sL https://raw.githubusercontent.com/ImL1s/termux-flutter-wsl/main/install_termux_flutter.sh | bash';

      // Use executeStream to show real-time progress
      // Note: We need to append logs, not replace logging state continuously which might be heavy?
      // State updates trigger rebuilds. Let's buffer or just update.
      // Rebuilding on every chunk is fine for now usually.

      await for (final log in sshService.executeStream(installCmd)) {
        state = state.copyWith(
          installLog: '${state.installLog ?? ""}$log',
        );
      }

      state = state.copyWith(
        isInstalling: false,
        installLog: '${state.installLog ?? ""}安裝腳本執行完畢。\n',
        isFlutterInstalled: true,
      );
    } catch (e) {
      state = state.copyWith(
        isInstalling: false,
        installLog: '${state.installLog ?? ""}安裝失敗: $e\n',
      );
    }
  }

  /// Install Flutter via Termux Bridge (no SSH required)
  Future<void> installFlutterViaBridge() async {
    final termuxBridge = ref.read(termuxBridgeProvider);

    state = state.copyWith(
      isInstalling: true,
      installLog: '正在啟動安裝腳本...\n請切換到 Termux 查看進度\n',
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
}

final setupServiceProvider =
    NotifierProvider<SetupService, SetupState>(SetupService.new);
