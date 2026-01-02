import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import 'git_service.dart';
import '../termux/ssh_service.dart';

/// Provider for GitService
final gitServiceProvider = Provider<GitService>((ref) {
  final ssh = ref.watch(sshServiceProvider);
  return GitService(ssh);
});

/// Represents a Git branch
class GitBranch {
  final String name;
  final bool isActive;
  final bool isRemote;

  const GitBranch({
    required this.name,
    this.isActive = false,
    this.isRemote = false,
  });
}

/// State for branch management
class BranchState {
  final List<GitBranch> localBranches;
  final List<GitBranch> remoteBranches;
  final String? currentBranch;
  final bool isLoading;
  final String? error;

  const BranchState({
    this.localBranches = const [],
    this.remoteBranches = const [],
    this.currentBranch,
    this.isLoading = false,
    this.error,
  });

  BranchState copyWith({
    List<GitBranch>? localBranches,
    List<GitBranch>? remoteBranches,
    String? currentBranch,
    bool? isLoading,
    String? error,
  }) {
    return BranchState(
      localBranches: localBranches ?? this.localBranches,
      remoteBranches: remoteBranches ?? this.remoteBranches,
      currentBranch: currentBranch ?? this.currentBranch,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<GitBranch> get allBranches => [...localBranches, ...remoteBranches];
}

/// Notifier for branch state management
class BranchNotifier extends AsyncNotifier<BranchState> {
  @override
  Future<BranchState> build() async {
    return const BranchState();
  }

  /// Load branches for the current project
  Future<void> loadBranches() async {
    final projectPath = ref.read(projectPathProvider);
    if (projectPath == null) {
      state = AsyncValue.data(
        const BranchState(error: 'No project open'),
      );
      return;
    }

    state = const AsyncValue.loading();

    try {
      final gitService = ref.read(gitServiceProvider);

      // Check if it's a git repo
      final isRepo = await gitService.isGitRepository(projectPath);
      if (!isRepo) {
        state = AsyncValue.data(
          const BranchState(error: 'Not a Git repository'),
        );
        return;
      }

      // Get current branch
      final currentBranch = await gitService.getCurrentBranch(projectPath);

      // Get local branches
      final localBranchNames = await gitService.listBranches(projectPath);
      final localBranches = localBranchNames.map((name) {
        return GitBranch(
          name: name,
          isActive: name == currentBranch,
          isRemote: false,
        );
      }).toList();

      // Get remote branches
      final remoteBranchNames =
          await gitService.listRemoteBranches(projectPath);
      final remoteBranches = remoteBranchNames.map((name) {
        return GitBranch(
          name: name,
          isActive: false,
          isRemote: true,
        );
      }).toList();

      state = AsyncValue.data(
        BranchState(
          localBranches: localBranches,
          remoteBranches: remoteBranches,
          currentBranch: currentBranch,
          isLoading: false,
        ),
      );
    } catch (e) {
      state = AsyncValue.data(
        BranchState(error: e.toString()),
      );
    }
  }

  /// Checkout to a branch
  Future<bool> checkout(String branchName) async {
    final projectPath = ref.read(projectPathProvider);
    if (projectPath == null) return false;

    final gitService = ref.read(gitServiceProvider);
    final result = await gitService.checkout(projectPath, branchName);

    if (result.success) {
      await loadBranches(); // Refresh
      return true;
    }
    return false;
  }

  /// Create a new branch and checkout
  Future<bool> createBranch(String branchName) async {
    final projectPath = ref.read(projectPathProvider);
    if (projectPath == null) return false;

    final gitService = ref.read(gitServiceProvider);
    final result = await gitService.createBranch(projectPath, branchName);

    if (result.success) {
      await loadBranches(); // Refresh
      return true;
    }
    return false;
  }

  /// Delete a branch
  Future<bool> deleteBranch(String branchName, {bool force = false}) async {
    final projectPath = ref.read(projectPathProvider);
    if (projectPath == null) return false;

    final gitService = ref.read(gitServiceProvider);
    final result =
        await gitService.deleteBranch(projectPath, branchName, force: force);

    if (result.success) {
      await loadBranches(); // Refresh
      return true;
    }
    return false;
  }
}

/// Provider for branch management
final branchProvider = AsyncNotifierProvider<BranchNotifier, BranchState>(
  BranchNotifier.new,
);
