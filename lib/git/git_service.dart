import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/termux_bridge.dart';
import '../termux/termux_providers.dart';
import '../file_manager/file_operations.dart';

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
}

/// Git Service Provider
final gitServiceProvider = Provider<GitService>((ref) {
  final bridge = ref.watch(termuxBridgeProvider);
  return GitService(bridge);
});

/// Git Status Provider
final gitStatusProvider = FutureProvider.autoDispose<List<GitFileChange>>((ref) async {
  final path = ref.watch(currentDirectoryProvider);
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
