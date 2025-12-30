import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';

// MockTermuxBridge for testing - implements same interface without extending
// Note: TermuxBridge uses factory singleton, so we can't extend it
class MockTermuxBridge {
  final Map<String, TermuxResult> _responses = {};
  final List<String> executedCommands = [];

  void setResponse(String commandPattern, TermuxResult result) {
    _responses[commandPattern] = result;
  }

  void clearCommands() {
    executedCommands.clear();
  }

  Future<TermuxResult> executeCommand(
    String command, {
    String? workingDirectory,
    bool background = false,
  }) async {
    executedCommands.add(command);

    // Check for matching pattern
    for (final pattern in _responses.keys) {
      if (command.contains(pattern)) {
        return _responses[pattern]!;
      }
    }

    // Default success response
    return TermuxResult(
      success: true,
      exitCode: 0,
      stdout: '',
      stderr: '',
    );
  }

  Future<bool> isTermuxInstalled() async => true;

  Future<bool> openTermux() async => true;

  Future<TermuxResult> runFlutterCommand(String subCommand) {
    return executeCommand('flutter $subCommand');
  }

  Stream<String> executeCommandStream(String command) async* {
    final result = await executeCommand(command);
    yield result.stdout;
  }
}

void main() {
  group('TermuxResult', () {
    test('fromMap parses correctly', () {
      final result = TermuxResult.fromMap({
        'success': true,
        'exitCode': 0,
        'stdout': 'hello world',
        'stderr': '',
      });

      expect(result.success, isTrue);
      expect(result.exitCode, 0);
      expect(result.stdout, 'hello world');
      expect(result.stderr, isEmpty);
    });

    test('fromMap handles missing fields', () {
      final result = TermuxResult.fromMap({});

      expect(result.success, isFalse);
      expect(result.exitCode, -1);
      expect(result.stdout, isEmpty);
      expect(result.stderr, isEmpty);
    });

    test('toString formats correctly', () {
      final result = TermuxResult(
        success: true,
        exitCode: 0,
        stdout: 'output',
        stderr: '',
      );

      expect(result.toString(), contains('success: true'));
      expect(result.toString(), contains('exitCode: 0'));
    });
  });

  group('MockTermuxBridge', () {
    late MockTermuxBridge bridge;

    setUp(() {
      bridge = MockTermuxBridge();
    });

    test('records executed commands', () async {
      await bridge.executeCommand('ls -la');
      await bridge.executeCommand('cat file.txt');

      expect(bridge.executedCommands, ['ls -la', 'cat file.txt']);
    });

    test('returns configured responses', () async {
      bridge.setResponse(
          'ls',
          TermuxResult(
            success: true,
            exitCode: 0,
            stdout: 'file1.txt\nfile2.txt',
            stderr: '',
          ));

      final result = await bridge.executeCommand('ls -la');

      expect(result.success, isTrue);
      expect(result.stdout, 'file1.txt\nfile2.txt');
    });

    test('returns default success for unknown commands', () async {
      final result = await bridge.executeCommand('unknown command');

      expect(result.success, isTrue);
      expect(result.exitCode, 0);
    });
  });
}
