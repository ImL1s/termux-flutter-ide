import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:termux_flutter_ide/run/flutter_runner_service.dart';
import 'package:termux_flutter_ide/run/launch_config.dart';
import 'package:termux_flutter_ide/core/providers.dart';
import 'package:termux_flutter_ide/terminal/terminal_session.dart';
import 'package:termux_flutter_ide/file_manager/file_operations.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';

// Mock TerminalSessionNotifier
class MockTerminalSessionNotifier extends TerminalSessionNotifier {
  @override
  Future<String> createSession({String? name, String? initialDirectory}) async {
    const id = 'test-session-id';
    final session = TerminalSession(
      id: id,
      name: name ?? 'Test Session',
      initialDirectory: initialDirectory,
    );
    state = TerminalSessionsState(
        sessions: [...state.sessions, session], activeSessionId: id);
    return id;
  }

  @override
  Future<void> connectSession(TerminalSession session) async {
    session.state = SessionState.connected;
    // Notify listeners
    state = state.copyWith();
  }
}

// Mock ProjectPathNotifier
class MockProjectPathNotifier extends ProjectPathNotifier {
  final String? _initialPath;
  MockProjectPathNotifier(this._initialPath);

  @override
  String? build() => _initialPath;
}

// Mock for null project path
class NullProjectPathNotifier extends ProjectPathNotifier {
  @override
  String? build() => null;
}

class MockSSHService extends SSHService {
  MockSSHService() : super(TermuxBridge());
}

class MockFileOperations extends FileOperations {
  MockFileOperations() : super(MockSSHService());

  @override
  Future<bool> exists(String path) async {
    return File(path).exists();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LaunchConfiguration Tests', () {
    test('fromJson parses basic configuration correctly', () {
      final json = {
        'name': 'My Config',
        'type': 'flutter',
        'request': 'launch',
        'program': 'lib/main.dart',
        'mode': 'debug',
      };

      final config = LaunchConfiguration.fromJson(json);

      expect(config.name, 'My Config');
      expect(config.type, 'flutter');
      expect(config.request, 'launch');
      expect(config.program, 'lib/main.dart');
      expect(config.mode, 'debug');
    });

    test('fromJson parses args and env correctly', () {
      final json = {
        'name': 'With Args',
        'args': ['--flavor', 'dev', '--no-sound-null-safety'],
        'env': {'FLUTTER_TEST': 'true', 'MY_VAR': '123'},
      };

      final config = LaunchConfiguration.fromJson(json);

      expect(config.args, ['--flavor', 'dev', '--no-sound-null-safety']);
      expect(config.env['FLUTTER_TEST'], 'true');
      expect(config.env['MY_VAR'], '123');
    });

    test('fromJson handles device alias', () {
      // 'device' should map to deviceId
      final json = {
        'name': 'With Device',
        'device': 'chrome',
      };

      final config = LaunchConfiguration.fromJson(json);
      expect(config.deviceId, 'chrome');
    });

    test('fromJson handles deviceId directly', () {
      final json = {
        'name': 'With DeviceId',
        'deviceId': 'emulator-5554',
      };

      final config = LaunchConfiguration.fromJson(json);
      expect(config.deviceId, 'emulator-5554');
    });

    test('toJson produces valid output', () {
      const config = LaunchConfiguration(
        name: 'Test Config',
        program: 'lib/main_dev.dart',
        mode: 'release',
        deviceId: 'linux',
        args: ['--verbose'],
        env: {'DEBUG': '1'},
      );

      final json = config.toJson();

      expect(json['name'], 'Test Config');
      expect(json['program'], 'lib/main_dev.dart');
      expect(json['mode'], 'release');
      expect(
          json['device'], 'linux'); // Note: deviceId is serialized as 'device'
      expect(json['args'], ['--verbose']);
      expect(json['env'], {'DEBUG': '1'});
    });

    test('default values are applied', () {
      const config = LaunchConfiguration(name: 'Minimal');

      expect(config.type, 'flutter');
      expect(config.request, 'launch');
      expect(config.args, isEmpty);
      expect(config.env, isEmpty);
      expect(config.program, isNull);
      expect(config.cwd, isNull);
      expect(config.flutterPath, isNull);
      expect(config.deviceId, isNull);
      expect(config.mode, isNull);
    });
  });

  group('FlutterRunnerService Tests', () {
    late ProviderContainer container;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('flutter_runner_test');

      // Mock installed_apps channel
      const MethodChannel('installed_apps')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        if (methodCall.method == 'isAppInstalled') {
          return true; // Simulate Termux:X11 installed
        }
        return null;
      });
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('isValidFlutterProject returns false without pubspec.yaml', () async {
      container = ProviderContainer(
        overrides: [
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(tempDir.path)),
          activeRunnerSessionIdProvider
              .overrideWith(ActiveRunnerSessionIdNotifier.new),
          runnerStateProvider.overrideWith(RunnerStateNotifier.new),
          runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
          fileOperationsProvider.overrideWithValue(MockFileOperations()),
        ],
      );

      final service = container.read(flutterRunnerServiceProvider);
      final isValid = await service.isValidFlutterProject();
      expect(isValid, false);
    });

    test('isValidFlutterProject returns true with pubspec.yaml', () async {
      await File('${tempDir.path}/pubspec.yaml').create();

      container = ProviderContainer(
        overrides: [
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(tempDir.path)),
          activeRunnerSessionIdProvider
              .overrideWith(ActiveRunnerSessionIdNotifier.new),
          runnerStateProvider.overrideWith(RunnerStateNotifier.new),
          runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
          fileOperationsProvider.overrideWithValue(MockFileOperations()),
        ],
      );

      final service = container.read(flutterRunnerServiceProvider);
      final isValid = await service.isValidFlutterProject();
      expect(isValid, true);
    });

    test('run() fails if project path is null', () async {
      container = ProviderContainer(
        overrides: [
          projectPathProvider.overrideWith(() => NullProjectPathNotifier()),
          activeRunnerSessionIdProvider
              .overrideWith(ActiveRunnerSessionIdNotifier.new),
          runnerStateProvider.overrideWith(RunnerStateNotifier.new),
          runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
          fileOperationsProvider.overrideWithValue(MockFileOperations()),
        ],
      );

      final service = container.read(flutterRunnerServiceProvider);
      const config = LaunchConfiguration(name: 'Test');

      await service.run(config);

      final state = container.read(runnerStateProvider);
      final error = container.read(runnerErrorProvider);

      expect(state, RunnerState.error);
      expect(error, contains('Flutter 專案'));
    });

    test('run() fails if not a valid Flutter project', () async {
      container = ProviderContainer(
        overrides: [
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(tempDir.path)),
          activeRunnerSessionIdProvider
              .overrideWith(ActiveRunnerSessionIdNotifier.new),
          runnerStateProvider.overrideWith(RunnerStateNotifier.new),
          runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
          fileOperationsProvider.overrideWithValue(MockFileOperations()),
        ],
      );

      final service = container.read(flutterRunnerServiceProvider);
      const config = LaunchConfiguration(name: 'Test', flutterPath: 'flutter');

      await service.run(config);

      final state = container.read(runnerStateProvider);
      final error = container.read(runnerErrorProvider);

      expect(state, RunnerState.error);
      expect(error, contains('pubspec.yaml'));
    });

    test('run() creates session and sets running state on valid project',
        () async {
      await File('${tempDir.path}/pubspec.yaml').create();

      container = ProviderContainer(
        overrides: [
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(tempDir.path)),
          terminalSessionsProvider
              .overrideWith(MockTerminalSessionNotifier.new),
          activeRunnerSessionIdProvider
              .overrideWith(ActiveRunnerSessionIdNotifier.new),
          runnerStateProvider.overrideWith(RunnerStateNotifier.new),
          runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
          fileOperationsProvider.overrideWithValue(MockFileOperations()),
        ],
      );

      final service = container.read(flutterRunnerServiceProvider);
      const config = LaunchConfiguration(
        name: 'Test Config',
        flutterPath: 'flutter',
        args: ['--verbose'],
      );

      await service.run(config);

      final state = container.read(runnerStateProvider);
      final activeId = container.read(activeRunnerSessionIdProvider);
      final sessions = container.read(terminalSessionsProvider).sessions;
      final error = container.read(runnerErrorProvider);

      expect(error, isNull);
      expect(sessions.length, 1);
      expect(sessions.first.name, 'Run: Test Config');
      expect(activeId, sessions.first.id);
      // State depends on mock behavior; but should not be error
      expect(state, isNot(RunnerState.error));
    });

    test('hotReload only works when running', () async {
      container = ProviderContainer(
        overrides: [
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(tempDir.path)),
          terminalSessionsProvider
              .overrideWith(MockTerminalSessionNotifier.new),
          activeRunnerSessionIdProvider
              .overrideWith(ActiveRunnerSessionIdNotifier.new),
          runnerStateProvider.overrideWith(RunnerStateNotifier.new),
          runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
          fileOperationsProvider.overrideWithValue(MockFileOperations()),
        ],
      );

      final service = container.read(flutterRunnerServiceProvider);

      // Not running -> hotReload should not crash, just no-op
      service.hotReload();

      // Verify no error
      final error = container.read(runnerErrorProvider);
      expect(error, isNull);
    });

    test('hotRestart only works when running', () async {
      container = ProviderContainer(
        overrides: [
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(tempDir.path)),
          terminalSessionsProvider
              .overrideWith(MockTerminalSessionNotifier.new),
          activeRunnerSessionIdProvider
              .overrideWith(ActiveRunnerSessionIdNotifier.new),
          runnerStateProvider.overrideWith(RunnerStateNotifier.new),
          runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
          fileOperationsProvider.overrideWithValue(MockFileOperations()),
        ],
      );

      final service = container.read(flutterRunnerServiceProvider);

      // Not running -> hotRestart should not crash
      service.hotRestart();

      final error = container.read(runnerErrorProvider);
      expect(error, isNull);
    });

    test('stop updates state to stopped', () async {
      container = ProviderContainer(
        overrides: [
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(tempDir.path)),
          terminalSessionsProvider
              .overrideWith(MockTerminalSessionNotifier.new),
          activeRunnerSessionIdProvider
              .overrideWith(ActiveRunnerSessionIdNotifier.new),
          runnerStateProvider.overrideWith(RunnerStateNotifier.new),
          runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
          fileOperationsProvider.overrideWithValue(MockFileOperations()),
        ],
      );

      final service = container.read(flutterRunnerServiceProvider);

      // Call stop (even without a running session)
      service.stop();

      // Wait for delayed state update
      await Future.delayed(const Duration(milliseconds: 600));

      final state = container.read(runnerStateProvider);
      expect(state, RunnerState.stopped);
    });

    test('currentSession returns null when no active session', () async {
      container = ProviderContainer(
        overrides: [
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(tempDir.path)),
          terminalSessionsProvider
              .overrideWith(MockTerminalSessionNotifier.new),
          activeRunnerSessionIdProvider
              .overrideWith(ActiveRunnerSessionIdNotifier.new),
          runnerStateProvider.overrideWith(RunnerStateNotifier.new),
          runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
          fileOperationsProvider.overrideWithValue(MockFileOperations()),
        ],
      );

      final service = container.read(flutterRunnerServiceProvider);
      expect(service.currentSession, isNull);
    });
  });

  group('RunnerState Provider Tests', () {
    test('RunnerStateNotifier starts with idle', () {
      final container = ProviderContainer();
      final state = container.read(runnerStateProvider);
      expect(state, RunnerState.idle);
    });

    test('RunnerStateNotifier can transition states', () {
      final container = ProviderContainer();

      container
          .read(runnerStateProvider.notifier)
          .setState(RunnerState.connecting);
      expect(container.read(runnerStateProvider), RunnerState.connecting);

      container
          .read(runnerStateProvider.notifier)
          .setState(RunnerState.running);
      expect(container.read(runnerStateProvider), RunnerState.running);

      container
          .read(runnerStateProvider.notifier)
          .setState(RunnerState.stopped);
      expect(container.read(runnerStateProvider), RunnerState.stopped);
    });
  });

  group('RunnerError Provider Tests', () {
    test('RunnerErrorNotifier starts with null', () {
      final container = ProviderContainer();
      final error = container.read(runnerErrorProvider);
      expect(error, isNull);
    });

    test('RunnerErrorNotifier can set and clear error', () {
      final container = ProviderContainer();

      container.read(runnerErrorProvider.notifier).setError('Test error');
      expect(container.read(runnerErrorProvider), 'Test error');

      container.read(runnerErrorProvider.notifier).setError(null);
      expect(container.read(runnerErrorProvider), isNull);
    });
  });

  group('ActiveRunnerSessionId Provider Tests', () {
    test('ActiveRunnerSessionIdNotifier starts with null', () {
      final container = ProviderContainer();
      final id = container.read(activeRunnerSessionIdProvider);
      expect(id, isNull);
    });

    test('ActiveRunnerSessionIdNotifier can set and clear', () {
      final container = ProviderContainer();

      container.read(activeRunnerSessionIdProvider.notifier).set('session-123');
      expect(container.read(activeRunnerSessionIdProvider), 'session-123');

      container.read(activeRunnerSessionIdProvider.notifier).clear();
      expect(container.read(activeRunnerSessionIdProvider), isNull);
    });
  });

  group('LaunchConfiguration File Creation Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('launch_config_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('createDefaultLaunchConfig creates directory and file', () async {
      await createDefaultLaunchConfig(tempDir.path);

      final dir = Directory('${tempDir.path}/.termux-ide');
      final file = File('${tempDir.path}/.termux-ide/launch.json');

      expect(await dir.exists(), true);
      expect(await file.exists(), true);

      final content = await file.readAsString();
      expect(content, contains('Flutter (Debug)'));
      expect(content, contains('Flutter (Profile)'));
      expect(content, contains('Flutter (Release)'));
    });

    test('createDefaultLaunchConfig does not overwrite existing file',
        () async {
      final dir = Directory('${tempDir.path}/.termux-ide');
      await dir.create();
      final file = File('${tempDir.path}/.termux-ide/launch.json');
      await file.writeAsString('{"custom": true}');

      await createDefaultLaunchConfig(tempDir.path);

      final content = await file.readAsString();
      expect(content, '{"custom": true}');
    });
  });
}
