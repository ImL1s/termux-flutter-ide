import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';

// MockTermuxBridge for testing new branch methods
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

// Extended TestableGitService with new branch methods
class TestableGitService {
  final MockTermuxBridge _bridge;

  TestableGitService(this._bridge);

  Future<List<String>> listBranches(String path) async {
    final result = await _bridge.executeCommand(
      'cd "$path" && git branch --format="%(refname:short)"',
    );
    if (!result.success) return [];

    return result.stdout
        .split('\n')
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
  }

  Future<TermuxResult> checkout(String path, String branch) async {
    return await _bridge.executeCommand('cd "$path" && git checkout "$branch"');
  }

  Future<TermuxResult> createBranch(String path, String branchName) async {
    return await _bridge
        .executeCommand('cd "$path" && git checkout -b "$branchName"');
  }

  Future<String> getCurrentBranch(String path) async {
    final result = await _bridge.executeCommand(
      'cd "$path" && git rev-parse --abbrev-ref HEAD',
    );
    return result.success ? result.stdout.trim() : '';
  }

  Future<TermuxResult> push(String path) async {
    return await _bridge.executeCommand('cd "$path" && git push');
  }

  Future<TermuxResult> pull(String path) async {
    return await _bridge.executeCommand('cd "$path" && git pull');
  }
}

void main() {
  late MockTermuxBridge mockBridge;
  late TestableGitService gitService;

  setUp(() {
    mockBridge = MockTermuxBridge();
    gitService = TestableGitService(mockBridge);
  });

  group('GitService Branch Methods', () {
    test('listBranches returns list of branch names', () async {
      mockBridge.setResponse(
        'git branch',
        TermuxResult(
          success: true,
          exitCode: 0,
          stdout: 'main\nfeature/new-feature\ndevelop\n',
          stderr: '',
        ),
      );

      final branches = await gitService.listBranches('/my/project');

      expect(branches.length, 3);
      expect(branches, contains('main'));
      expect(branches, contains('feature/new-feature'));
      expect(branches, contains('develop'));
    });

    test('listBranches returns empty list on failure', () async {
      mockBridge.setResponse(
        'git branch',
        TermuxResult(
          success: false,
          exitCode: 128,
          stdout: '',
          stderr: 'fatal: not a git repository',
        ),
      );

      final branches = await gitService.listBranches('/not/a/repo');

      expect(branches, isEmpty);
    });

    test('checkout executes git checkout command', () async {
      mockBridge.setResponse(
        'git checkout',
        TermuxResult(
          success: true,
          exitCode: 0,
          stdout: "Switched to branch 'develop'",
          stderr: '',
        ),
      );

      final result = await gitService.checkout('/my/project', 'develop');

      expect(result.success, isTrue);
      expect(
          mockBridge.executedCommands.last, contains('git checkout "develop"'));
    });

    test('checkout fails for non-existent branch', () async {
      mockBridge.setResponse(
        'git checkout',
        TermuxResult(
          success: false,
          exitCode: 1,
          stdout: '',
          stderr:
              "error: pathspec 'nonexistent' did not match any file(s) known to git",
        ),
      );

      final result = await gitService.checkout('/my/project', 'nonexistent');

      expect(result.success, isFalse);
      expect(result.stderr, contains("pathspec 'nonexistent'"));
    });

    test('createBranch executes git checkout -b command', () async {
      mockBridge.setResponse(
        'checkout -b',
        TermuxResult(
          success: true,
          exitCode: 0,
          stdout: "Switched to a new branch 'feature/new'",
          stderr: '',
        ),
      );

      final result =
          await gitService.createBranch('/my/project', 'feature/new');

      expect(result.success, isTrue);
      expect(mockBridge.executedCommands.last,
          contains('git checkout -b "feature/new"'));
    });

    test('createBranch fails when branch already exists', () async {
      mockBridge.setResponse(
        'checkout -b',
        TermuxResult(
          success: false,
          exitCode: 128,
          stdout: '',
          stderr: "fatal: a branch named 'main' already exists",
        ),
      );

      final result = await gitService.createBranch('/my/project', 'main');

      expect(result.success, isFalse);
      expect(result.stderr, contains('already exists'));
    });

    test('getCurrentBranch returns current branch name', () async {
      mockBridge.setResponse(
        'rev-parse --abbrev-ref',
        TermuxResult(
          success: true,
          exitCode: 0,
          stdout: 'feature/my-branch\n',
          stderr: '',
        ),
      );

      final branch = await gitService.getCurrentBranch('/my/project');

      expect(branch, 'feature/my-branch');
    });

    test('push executes git push command', () async {
      mockBridge.setResponse(
        'git push',
        TermuxResult(
          success: true,
          exitCode: 0,
          stdout: 'Everything up-to-date',
          stderr: '',
        ),
      );

      final result = await gitService.push('/my/project');

      expect(result.success, isTrue);
      expect(mockBridge.executedCommands.last, contains('git push'));
    });

    test('pull executes git pull command', () async {
      mockBridge.setResponse(
        'git pull',
        TermuxResult(
          success: true,
          exitCode: 0,
          stdout: 'Already up to date.',
          stderr: '',
        ),
      );

      final result = await gitService.pull('/my/project');

      expect(result.success, isTrue);
      expect(mockBridge.executedCommands.last, contains('git pull'));
    });
  });
}
