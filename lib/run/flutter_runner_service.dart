import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_apps/device_apps.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart'; // Import Flag
import 'package:url_launcher/url_launcher.dart'; // For opening download link
import 'launch_config.dart';
import '../terminal/terminal_session.dart';
import '../core/providers.dart';
import '../file_manager/file_operations.dart';

/// Runner State Enum
enum RunnerState {
  idle,
  connecting,
  running,
  stopped,
  error,
}

/// Provider for runner state
final runnerStateProvider = NotifierProvider<RunnerStateNotifier, RunnerState>(
  RunnerStateNotifier.new,
);

class RunnerStateNotifier extends Notifier<RunnerState> {
  @override
  RunnerState build() => RunnerState.idle;

  void setState(RunnerState newState) {
    state = newState;
  }
}

/// Provider for runner error message
final runnerErrorProvider = NotifierProvider<RunnerErrorNotifier, String?>(
  RunnerErrorNotifier.new,
);

class RunnerErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String? error) {
    state = error;
  }
}

/// Active session ID provider
final activeRunnerSessionIdProvider =
    NotifierProvider<ActiveRunnerSessionIdNotifier, String?>(
  ActiveRunnerSessionIdNotifier.new,
);

class ActiveRunnerSessionIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) {
    state = value;
  }

  void clear() {
    state = null;
  }
}

final flutterRunnerServiceProvider = Provider<FlutterRunnerService>((ref) {
  return FlutterRunnerService(ref);
});

class FlutterRunnerService {
  final Ref _ref;

  FlutterRunnerService(this._ref);

  /// Check if project is valid Flutter project using SSH
  Future<bool> isValidFlutterProject() async {
    final projectPath = _ref.read(projectPathProvider);
    if (projectPath == null) return false;

    // Use FileOperations to check remote file existence
    final fileOps = _ref.read(fileOperationsProvider);
    return await fileOps.exists('$projectPath/pubspec.yaml');
  }

  /// Main run method with full error handling
  Future<void> run(LaunchConfiguration config) async {
    final stateNotifier = _ref.read(runnerStateProvider.notifier);
    final errorNotifier = _ref.read(runnerErrorProvider.notifier);
    final sessionIdNotifier = _ref.read(activeRunnerSessionIdProvider.notifier);

    // Clear previous error
    errorNotifier.setError(null);

    // 1. Check project path
    final projectPath = _ref.read(projectPathProvider);
    if (projectPath == null) {
      stateNotifier.setState(RunnerState.error);
      errorNotifier.setError('請先開啟 Flutter 專案');
      return;
    }

    // 2. Check if valid Flutter project
    if (!await isValidFlutterProject()) {
      stateNotifier.setState(RunnerState.error);
      errorNotifier.setError('此目錄不是有效的 Flutter 專案 (缺少 pubspec.yaml)');
      return;
    }

    // 3. Set connecting state
    stateNotifier.setState(RunnerState.connecting);
    print('FlutterRunnerService: Starting run for ${config.name}');

    try {
      final notifier = _ref.read(terminalSessionsProvider.notifier);

      // Create new session manually to set ID before awaiting connection
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final workingDir = config.cwd ?? projectPath;
      final session = TerminalSession(
        id: id,
        name: 'Run: ${config.name}',
        initialDirectory: workingDir,
      );

      // 1. Add to session list
      notifier.addSession(session);

      // 2. Set active ID for Debug Console
      sessionIdNotifier.set(id);

      // 3. Verbose Visual Feedback
      session.onDataReceived(
          '\x1B[1;33m[IDE] 🚀 Starting Runner for ${config.name}...\x1B[0m\r\n');
      session.onDataReceived('\x1B[1;30m[IDE] Project: $workingDir\x1B[0m\r\n');
      session.onDataReceived(
          '\x1B[1;36m[IDE] Step 1/3: Establishing SSH connection...\x1B[0m\r\n');

      // 4. Connect
      await notifier.connectSession(session);

      // Check if session connected successfully
      if (session.state == SessionState.failed) {
        stateNotifier.setState(RunnerState.error);
        final err = session.lastError ?? "請確認 Termux 中已執行 sshd";
        session.onDataReceived(
            '\x1B[31m[IDE] ❌ SSH connection failed: $err\x1B[0m\r\n');
        errorNotifier.setError('SSH 連線失敗: $err');
        return;
      }

      session.onDataReceived('\x1B[1;32m[IDE] ✔ SSH connected!\x1B[0m\r\n');
      session.onDataReceived(
          '\x1B[1;36m[IDE] Step 2/3: Validating Flutter project...\x1B[0m\r\n');

      // 5. Validate project (already checked but let's be sure in the terminal)
      if (!await isValidFlutterProject()) {
        session.onDataReceived(
            '\x1B[31m[IDE] ❌ Not a valid Flutter project (missing pubspec.yaml)\x1B[0m\r\n');
        stateNotifier.setState(RunnerState.error);
        errorNotifier.setError('此目錄不是有效的 Flutter 專案');
        return;
      }

      session.onDataReceived('\x1B[1;32m[IDE] ✔ Project validated!\x1B[0m\r\n');
      session.onDataReceived(
          '\x1B[1;36m[IDE] Step 3/3: Sending run command...\x1B[0m\r\n');

      stateNotifier.setState(RunnerState.running);

      // Listen for session end
      _listenForSessionEnd(session);

      final cmdBuffer = StringBuffer();

      // Check if targeting Linux (explicitly or implicitly) and add X11 setup
      // If deviceId is null, Flutter defaults to available devices. On Termux, 'linux' is often the default/only choice for 'run'.
      // We assume if we are in Termux (which this IDE is), and running locally, we likely need X11 for the Linux target.
      final isExplicitLinux = config.deviceId?.toLowerCase() == 'linux';

      // Heuristic: If deviceId is null, or explicit linux, set DISPLAY.
      // Setting DISPLAY=:0 usually doesn't hurt other targets (like web-server), but implies X11 usage.
      if (isExplicitLinux || config.deviceId == null) {
        // X11 Detection & Auto-Launch
        final isX11Installed =
            await DeviceApps.isAppInstalled('com.termux.x11');

        if (!isX11Installed) {
          session.onDataReceived(
              '\x1B[31m[IDE] ❌ Termux:X11 APP is NOT installed.\x1B[0m\r\n');
          session.onDataReceived(
              '\x1B[1;33m[IDE] ⚠️ Linux GUI apps require the "Termux:X11" companion app to display content.\x1B[0m\r\n');
          session.onDataReceived(
              '\x1B[1;34m[IDE] 🔗 Please download it from: https://github.com/termux/termux-x11/releases\x1B[0m\r\n');

          stateNotifier.setState(RunnerState.error);
          errorNotifier.setError('請先安裝 Termux:X11 APP 以顯示畫面');
          await launchUrl(
              Uri.parse('https://github.com/termux/termux-x11/releases'),
              mode: LaunchMode.externalApplication);
          return;
        } else {
          session.onDataReceived(
              '\x1B[1;32m[IDE] ✔ Termux:X11 detected, attempting to launch...\x1B[0m\r\n');
          try {
            // Launch Termux:X11 to ensure it's active
            final intent = AndroidIntent(
              action: 'android.intent.action.MAIN',
              package: 'com.termux.x11',
              category: 'android.intent.category.LAUNCHER',
              flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
            );
            await intent.launch();
          } catch (e) {
            session.onDataReceived(
                '\x1B[1;33m[IDE] ⚠️ Failed to auto-launch Termux:X11: $e\x1B[0m\r\n');
          }
        }

        session.onDataReceived(
            '\x1B[1;35m[IDE] 🖥️ Linux environment detected (Termux environment), ensuring DISPLAY=:0...\x1B[0m\r\n');
        cmdBuffer.write('export DISPLAY=:0 && ');
        // Also possibly needed for Termux-X11
        cmdBuffer.write('export PULSE_SERVER=tcp:127.0.0.1:4713 && ');
      }

      // Env vars
      if (config.env.isNotEmpty) {
        config.env.forEach((key, value) {
          cmdBuffer.write('export $key="${value}" && ');
        });
      }

      // Flutter executable
      final flutterExe = config.flutterPath ?? 'flutter';
      cmdBuffer.write(flutterExe);

      // Command
      cmdBuffer.write(' run');

      // Program (entry point)
      if (config.program != null) {
        cmdBuffer.write(' -t ${config.program}');
      }

      // Device
      if (config.deviceId != null) {
        cmdBuffer.write(' -d ${config.deviceId}');
      }

      // Mode
      if (config.mode != null) {
        cmdBuffer.write(' --${config.mode}');
      }

      // Args
      for (final arg in config.args) {
        cmdBuffer.write(' $arg');
      }

      final cmd = cmdBuffer.toString();
      session.onDataReceived('\x1B[1;33m[IDE] 🚀 Executing: $cmd\x1B[0m\r\n');
      _sendToSession(session, cmd);
    } catch (e) {
      stateNotifier.setState(RunnerState.error);
      errorNotifier.setError('執行錯誤: $e');
    }
  }

  /// Listen for shell completion to update state
  void _listenForSessionEnd(TerminalSession session) {
    session.shell?.done.then((_) {
      final currentId = _ref.read(activeRunnerSessionIdProvider);
      if (currentId == session.id) {
        _ref.read(runnerStateProvider.notifier).setState(RunnerState.stopped);
        // Do NOT clear the session ID so the user can see the exit logs/crash report.
      }
    });
  }

  void hotReload() {
    final state = _ref.read(runnerStateProvider);
    if (state != RunnerState.running) return;
    _sendKey('r');
  }

  void hotRestart() {
    final state = _ref.read(runnerStateProvider);
    if (state != RunnerState.running) return;
    _sendKey('R');
  }

  void stop() {
    _sendKey('q');
    // Update state after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _ref.read(runnerStateProvider.notifier).setState(RunnerState.stopped);
      // Do NOT clear active session ID
    });
  }

  void _sendKey(String key) {
    final currentId = _ref.read(activeRunnerSessionIdProvider);
    if (currentId == null) return;

    final sessions = _ref.read(terminalSessionsProvider).sessions;
    try {
      final session = sessions.firstWhere((s) => s.id == currentId);
      if (session.shell != null) {
        session.shell!.write(Uint8List.fromList(utf8.encode(key)));
      }
    } catch (e) {
      // Session might be gone
    }
  }

  void _sendToSession(TerminalSession session, String command) {
    if (session.shell != null) {
      session.shell!.write(Uint8List.fromList(utf8.encode('$command\r\n')));
    }
  }

  TerminalSession? get currentSession {
    final currentId = _ref.read(activeRunnerSessionIdProvider);
    if (currentId == null) return null;

    final sessions = _ref.read(terminalSessionsProvider).sessions;
    try {
      return sessions.firstWhere((s) => s.id == currentId);
    } catch (e) {
      return null;
    }
  }
}
