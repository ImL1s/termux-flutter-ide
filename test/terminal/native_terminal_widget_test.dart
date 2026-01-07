import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/terminal/native_terminal_service.dart';

/// Unit tests for NativeTerminalWidget focusing on service integration.
/// Note: Full widget rendering tests are skipped due to TerminalView internal timers.
/// Use integration_test/native_terminal_e2e_test.dart for full E2E testing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeTerminalWidget Service Integration', () {
    late List<MethodCall> methodCalls;
    late NativeTerminalService service;

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
              return 'widget-test-session';
            case 'initializeSession':
              return true;
            case 'writeToSession':
              return true;
            case 'resizeSession':
              return true;
            case 'closeSession':
              return true;
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

    test('service creates session with cwd', () async {
      final sessionId = await service.createSession(cwd: '/custom/path');

      expect(sessionId, 'widget-test-session');
      expect(methodCalls.first.arguments['cwd'], '/custom/path');
    });

    test('service creates session with shellPath', () async {
      await service.createSession(shellPath: '/bin/zsh');

      expect(methodCalls.first.arguments['shellPath'], '/bin/zsh');
    });

    test('service initializes session with dimensions', () async {
      await service.initializeSession('session-1', columns: 120, rows: 40);

      final call = methodCalls.first;
      expect(call.method, 'initializeSession');
      expect(call.arguments['sessionId'], 'session-1');
      expect(call.arguments['columns'], 120);
      expect(call.arguments['rows'], 40);
    });

    test('service writes to session', () async {
      await service.writeToSession('session-1', 'echo hello\n');

      expect(methodCalls.first.arguments['data'], 'echo hello\n');
    });

    test('service resizes session', () async {
      await service.resizeSession('session-1', columns: 80, rows: 24);

      expect(methodCalls.first.arguments['columns'], 80);
      expect(methodCalls.first.arguments['rows'], 24);
    });

    test('service closes session', () async {
      final result = await service.closeSession('session-1');

      expect(result, true);
      expect(methodCalls.first.method, 'closeSession');
    });

    test('full session lifecycle', () async {
      // Create
      final sessionId = await service.createSession(cwd: '/home');
      expect(sessionId, isNotNull);

      // Initialize
      final initialized =
          await service.initializeSession(sessionId, columns: 80, rows: 24);
      expect(initialized, true);

      // Write
      final written = await service.writeToSession(sessionId, 'ls\n');
      expect(written, true);

      // Resize
      final resized =
          await service.resizeSession(sessionId, columns: 100, rows: 30);
      expect(resized, true);

      // Close
      final closed = await service.closeSession(sessionId);
      expect(closed, true);

      // Verify all calls were made
      expect(methodCalls.length, 5);
    });
  });
}
