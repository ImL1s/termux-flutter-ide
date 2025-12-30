import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/git/git_service.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';

// MockTermuxBridge for testing
class MockTermuxBridge {
  final Map<String, TermuxResult> _responses = {};
  final List<String> executedCommands = [];

  void setResponse(String commandPattern, TermuxResult result) {
    _responses[commandPattern] = result;
  }

  Future<TermuxResult> executeCommand(
    String command, {
    String? workingDirectory,
    bool background = false,
  }) async {
    executedCommands.add(command);

    for (final pattern in _responses.keys) {
      if (command.contains(pattern)) {
        return _responses[pattern]!;
      }
    }

    return TermuxResult(
      success: true,
      exitCode: 0,
      stdout: '',
      stderr: '',
    );
  }
}

// Testable GitService that accepts MockTermuxBridge
class TestableGitService {
  final MockTermuxBridge _bridge;

  TestableGitService(this._bridge);

  Future<bool> isGitRepository(String path) async {
    final result = await _bridge.executeCommand(
      'cd "$path" && git rev-parse --is-inside-work-tree',
    );
    return result.success && result.stdout.trim() == 'true';
  }

  Future<String> getStatus(String path) async {
    final result = await _bridge.executeCommand(
      'cd "$path" && git status --porcelain',
    );
    return result.success ? result.stdout : '';
  }

  Future<bool> stageFile(String path, String file) async {
    final result = await _bridge.executeCommand(
      'cd "$path" && git add "$file"',
    );
    return result.success;
  }

  Future<bool> unstageFile(String path, String file) async {
    final result = await _bridge.executeCommand(
      'cd "$path" && git restore --staged "$file"',
    );
    return result.success;
  }

  Future<bool> commit(String path, String message) async {
    final escapedMessage = message.replaceAll('"', '\\"');
    final result = await _bridge.executeCommand(
      'cd "$path" && git commit -m "$escapedMessage"',
    );
    return result.success;
  }

  Future<String> diff(String path, String file) async {
    final result = await _bridge.executeCommand(
      'cd "$path" && git diff "$file"',
    );
    return result.success ? result.stdout : '';
  }

  Future<bool> init(String path) async {
    final result = await _bridge.executeCommand(
      'cd "$path" && git init',
    );
    return result.success;
  }
}

void main() {
  late MockTermuxBridge mockBridge;
  late TestableGitService gitService;

  setUp(() {
    mockBridge = MockTermuxBridge();
    gitService = TestableGitService(mockBridge);
  });

  group('GitService', () {
    test('isGitRepository returns true for git repos', () async {
      mockBridge.setResponse(
          'rev-parse',
          TermuxResult(
            success: true,
            exitCode: 0,
            stdout: 'true',
            stderr: '',
          ));

      final result = await gitService.isGitRepository('/my/project');

      expect(result, isTrue);
      expect(mockBridge.executedCommands.last, contains('git rev-parse'));
    });

    test('isGitRepository returns false for non-git dirs', () async {
      mockBridge.setResponse(
          'rev-parse',
          TermuxResult(
            success: false,
            exitCode: 128,
            stdout: '',
            stderr: 'fatal: not a git repository',
          ));

      final result = await gitService.isGitRepository('/not/a/repo');

      expect(result, isFalse);
    });

    test('getStatus returns porcelain output', () async {
      mockBridge.setResponse(
          'status --porcelain',
          TermuxResult(
            success: true,
            exitCode: 0,
            stdout: ' M modified.dart\n?? untracked.txt\nA  staged.dart',
            stderr: '',
          ));

      final status = await gitService.getStatus('/my/project');

      expect(status, contains('modified.dart'));
      expect(status, contains('untracked.txt'));
      expect(status, contains('staged.dart'));
    });

    test('stageFile executes git add', () async {
      final result = await gitService.stageFile('/project', 'file.dart');

      expect(result, isTrue);
      expect(mockBridge.executedCommands.last, contains('git add "file.dart"'));
    });

    test('unstageFile executes git restore --staged', () async {
      final result = await gitService.unstageFile('/project', 'file.dart');

      expect(result, isTrue);
      expect(
          mockBridge.executedCommands.last, contains('git restore --staged'));
    });

    test('commit escapes message and executes git commit', () async {
      final result = await gitService.commit('/project', 'Fix "bug" in code');

      expect(result, isTrue);
      final cmd = mockBridge.executedCommands.last;
      expect(cmd, contains('git commit -m'));
      expect(cmd, contains('Fix \\"bug\\" in code'));
    });

    test('diff returns diff output', () async {
      mockBridge.setResponse(
          'git diff',
          TermuxResult(
            success: true,
            exitCode: 0,
            stdout: '''--- a/file.dart
+++ b/file.dart
@@ -1,3 +1,4 @@
 void main() {
+  print('hello');
 }''',
            stderr: '',
          ));

      final diff = await gitService.diff('/project', 'file.dart');

      expect(diff, contains('--- a/file.dart'));
      expect(diff, contains('+  print'));
    });

    test('init executes git init', () async {
      final result = await gitService.init('/new/project');

      expect(result, isTrue);
      expect(mockBridge.executedCommands.last, contains('git init'));
    });
  });

  group('GitFileChange', () {
    test('isStaged detects staged files', () {
      final change = GitFileChange(
        path: 'file.dart',
        stagedStatus: 'A',
        unstagedStatus: ' ',
      );

      expect(change.isStaged, isTrue);
      expect(change.isModified, isFalse);
      expect(change.isUntracked, isFalse);
    });

    test('isModified detects modified files', () {
      final change = GitFileChange(
        path: 'file.dart',
        stagedStatus: ' ',
        unstagedStatus: 'M',
      );

      expect(change.isStaged, isFalse);
      expect(change.isModified, isTrue);
    });

    test('isUntracked detects untracked files', () {
      final change = GitFileChange(
        path: 'new_file.dart',
        stagedStatus: '?',
        unstagedStatus: '?',
      );

      expect(change.isUntracked, isTrue);
    });
  });
}
