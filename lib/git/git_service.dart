import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/termux_bridge.dart';
import '../termux/termux_providers.dart';
import '../file_manager/file_operations.dart';
import '../core/providers.dart';

/// Git Service
class GitService {
  final TermuxBridge _bridge;

  GitService(this._bridge);

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

  // Initialize new repo
  Future<bool> init(String path) async {
    final result = await _bridge.executeCommand(
      'cd "$path" && git init',
    );
    return result.success;
  }

  /// Clone a repository from URL
  Future<String?> clone(String url, String targetDir) async {
    // Extract repo name from URL (e.g., user/repo.git -> repo)
    String repoName = url.split('/').last;
    if (repoName.endsWith('.git')) {
      repoName = repoName.substring(0, repoName.length - 4);
    }

    final clonePath = '$targetDir/$repoName';
    final result = await _bridge.executeCommand(
      'cd "$targetDir" && git clone "$url"',
    );

    if (result.success) {
      return clonePath;
    }
    return null;
  }

  /// Get formatted git log for graph rendering
  Future<List<GitCommit>> getGitLog(String path) async {
    // Format: hash|parents|timestamp|message|refs|author
    final format = '%H|%P|%at|%s|%d|%an';
    final result = await _bridge.executeCommand(
      'cd "$path" && git log --all --pretty=format:"$format"',
    );

    if (!result.success || result.stdout.isEmpty) {
      return [];
    }

    final commits = <GitCommit>[];
    for (final line in result.stdout.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('|');
      if (parts.length < 6) continue;

      commits.add(GitCommit(
        hash: parts[0],
        parents: parts[1].split(' ').where((p) => p.isNotEmpty).toList(),
        timestamp: int.tryParse(parts[2]) ?? 0,
        message: parts[3],
        refs: parts[4].trim(),
        author: parts[5],
      ));
    }
    return commits;
  }
}

/// Git Service Provider
final gitServiceProvider = Provider<GitService>((ref) {
  final bridge = ref.watch(termuxBridgeProvider);
  return GitService(bridge);
});

/// Git Status Provider
final gitStatusProvider =
    FutureProvider.autoDispose<List<GitFileChange>>((ref) async {
  final path = ref.watch(projectPathProvider);
  if (path == null) return [];

  final service = ref.watch(gitServiceProvider);

  if (!await service.isGitRepository(path)) {
    return [];
  }

  final statusOutput = await service.getStatus(path);
  final changes = <GitFileChange>[];

  for (final line in statusOutput.split('\n')) {
    if (line.trim().isEmpty) continue;

    // Parse porcelain format: XY Path
    // X = staged status, Y = unstaged status
    if (line.length < 4) continue;

    final x = line[0];
    final y = line[1];
    final filePath = line.substring(3).trim();

    changes.add(GitFileChange(
      path: filePath,
      stagedStatus: x,
      unstagedStatus: y,
    ));
  }

  return changes;
});

class GitFileChange {
  final String path;
  final String stagedStatus;
  final String unstagedStatus;

  GitFileChange({
    required this.path,
    required this.stagedStatus,
    required this.unstagedStatus,
  });

  bool get isStaged => stagedStatus != ' ' && stagedStatus != '?';
  bool get isModified => unstagedStatus != ' ';
  bool get isUntracked => stagedStatus == '?' && unstagedStatus == '?';
}

class GitCommit {
  final String hash;
  final List<String> parents;
  final int timestamp;
  final String message;
  final String refs;
  final String author;

  GitCommit({
    required this.hash,
    required this.parents,
    required this.timestamp,
    required this.message,
    required this.refs,
    required this.author,
  });

  String get shortHash => hash.substring(0, 7);
}

final gitHistoryProvider =
    FutureProvider.autoDispose<List<GitCommit>>((ref) async {
  final path = ref.watch(projectPathProvider);
  if (path == null) return [];

  final service = ref.watch(gitServiceProvider);
  if (!await service.isGitRepository(path)) return [];

  return service.getGitLog(path);
});
