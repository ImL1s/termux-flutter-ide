import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/terminal/native_terminal_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeTerminalService', () {
    late NativeTerminalService service;
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      service = NativeTerminalService();

      // Mock the MethodChannel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('termux_flutter_ide/native_terminal'),
        (MethodCall call) async {
          methodCalls.add(call);
          switch (call.method) {
            case 'createSession':
              return 'test-session-id-123';
            case 'initializeSession':
              return true;
            case 'writeToSession':
              return true;
            case 'resizeSession':
              return true;
            case 'getSessionCwd':
              return '/data/data/com.termux/files/home';
            case 'isSessionRunning':
              return true;
            case 'closeSession':
              return true;
            case 'getActiveSessions':
              return ['session-1', 'session-2'];
            case 'getSessionCount':
              return 2;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('termux_flutter_ide/native_terminal'),
        null,
      );
      service.dispose();
    });

    test('createSession returns session ID', () async {
      final sessionId = await service.createSession();

      expect(sessionId, 'test-session-id-123');
      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'createSession');
    });

    test('createSession passes cwd and shellPath arguments', () async {
      await service.createSession(
        cwd: '/custom/path',
        shellPath: '/bin/zsh',
      );

      expect(methodCalls.first.arguments['cwd'], '/custom/path');
      expect(methodCalls.first.arguments['shellPath'], '/bin/zsh');
    });

    test('initializeSession sends correct dimensions', () async {
      final result = await service.initializeSession(
        'session-123',
        columns: 120,
        rows: 40,
      );

      expect(result, true);
      expect(methodCalls.first.method, 'initializeSession');
      expect(methodCalls.first.arguments['sessionId'], 'session-123');
      expect(methodCalls.first.arguments['columns'], 120);
      expect(methodCalls.first.arguments['rows'], 40);
    });

    test('writeToSession sends data correctly', () async {
      final result = await service.writeToSession('session-123', 'ls -la\n');

      expect(result, true);
      expect(methodCalls.first.method, 'writeToSession');
      expect(methodCalls.first.arguments['sessionId'], 'session-123');
      expect(methodCalls.first.arguments['data'], 'ls -la\n');
    });

    test('resizeSession updates terminal dimensions', () async {
      final result = await service.resizeSession(
        'session-123',
        columns: 80,
        rows: 24,
      );

      expect(result, true);
      expect(methodCalls.first.arguments['columns'], 80);
      expect(methodCalls.first.arguments['rows'], 24);
    });

    test('getSessionCwd returns current directory', () async {
      final cwd = await service.getSessionCwd('session-123');

      expect(cwd, '/data/data/com.termux/files/home');
    });

    test('isSessionRunning returns session state', () async {
      final running = await service.isSessionRunning('session-123');

      expect(running, true);
    });

    test('closeSession terminates session', () async {
      final result = await service.closeSession('session-123');

      expect(result, true);
      expect(methodCalls.first.method, 'closeSession');
    });

    test('getActiveSessions returns list of session IDs', () async {
      final sessions = await service.getActiveSessions();

      expect(sessions, ['session-1', 'session-2']);
    });

    test('getSessionCount returns number of active sessions', () async {
      final count = await service.getSessionCount();

      expect(count, 2);
    });

    group('Native Callbacks', () {
      test('onOutput stream receives terminal output', () async {
        final completer = Completer<TerminalOutputEvent>();
        final subscription = service.onOutput.listen(completer.complete);

        // Simulate native callback
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'termux_flutter_ide/native_terminal',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onTerminalOutput', {
              'sessionId': 'test-session',
              'output': 'Hello World\n',
            }),
          ),
          (ByteData? data) {},
        );

        final event = await completer.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => throw TimeoutException('No output received'),
        );

        expect(event.sessionId, 'test-session');
        expect(event.output, 'Hello World\n');

        await subscription.cancel();
      });

      test('onTitleChanged stream receives title updates', () async {
        final completer = Completer<TerminalTitleEvent>();
        final subscription = service.onTitleChanged.listen(completer.complete);

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'termux_flutter_ide/native_terminal',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onTitleChanged', {
              'sessionId': 'test-session',
              'title': 'user@localhost:~',
            }),
          ),
          (ByteData? data) {},
        );

        final event = await completer.future.timeout(
          const Duration(seconds: 1),
        );

        expect(event.sessionId, 'test-session');
        expect(event.title, 'user@localhost:~');

        await subscription.cancel();
      });

      test('onSessionFinished stream receives exit events', () async {
        final completer = Completer<TerminalFinishedEvent>();
        final subscription =
            service.onSessionFinished.listen(completer.complete);

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'termux_flutter_ide/native_terminal',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onSessionFinished', {
              'sessionId': 'test-session',
              'exitCode': 0,
            }),
          ),
          (ByteData? data) {},
        );

        final event = await completer.future.timeout(
          const Duration(seconds: 1),
        );

        expect(event.sessionId, 'test-session');
        expect(event.exitCode, 0);

        await subscription.cancel();
      });

      test('onBell stream receives bell events', () async {
        final completer = Completer<String>();
        final subscription = service.onBell.listen(completer.complete);

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'termux_flutter_ide/native_terminal',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onBell', {
              'sessionId': 'test-session',
            }),
          ),
          (ByteData? data) {},
        );

        final sessionId = await completer.future.timeout(
          const Duration(seconds: 1),
        );

        expect(sessionId, 'test-session');

        await subscription.cancel();
      });
    });
  });
}
