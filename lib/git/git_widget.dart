import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../file_manager/file_operations.dart';
import 'git_service.dart';

class GitWidget extends ConsumerStatefulWidget {
  const GitWidget({super.key});

  @override
  ConsumerState<GitWidget> createState() => _GitWidgetState();
}

class _GitWidgetState extends ConsumerState<GitWidget> {
  final _commitController = TextEditingController();
  bool _isCommitting = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(gitStatusProvider);
    final currentDir = ref.watch(currentDirectoryProvider);

    return Container(
      color: const Color(0xFF181825),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Text(
                  'SOURCE CONTROL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () => ref.invalidate(gitStatusProvider),
                  tooltip: 'Refresh Status',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: statusAsync.when(
              data: (changes) {
                if (changes.isEmpty) {
                  return _buildEmptyState(currentDir);
                }
                return _buildChangesList(context, changes, currentDir);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
            ),
          ),
          // Commit Box
          if (statusAsync.hasValue && statusAsync.value!.isNotEmpty)
            _buildCommitBox(currentDir),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String currentDir) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          const Text('No changes detected', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          TextButton.icon(
             icon: const Icon(Icons.refresh),
             label: const Text('Initialize Repo'),
             onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Init Git Repo?'),
                    content: const Text('Initialize a new git repository in this folder?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                      TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
                    ],
                  ),
                );
                
                if (confirm == true) {
                   await ref.read(gitServiceProvider).init(currentDir);
                   ref.invalidate(gitStatusProvider);
                }
             },
          ),
        ],
      ),
    );
  }

  Widget _buildChangesList(BuildContext context, List<GitFileChange> changes, String currentDir) {
    final staged = changes.where((c) => c.isStaged).toList();
    final unstaged = changes.where((c) => !c.isStaged).toList();

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (staged.isNotEmpty) ...[
          _buildSectionHeader('STAGED CHANGES', staged.length),
          ...staged.map((c) => _buildChangeItem(c, currentDir)),
        ],
        if (staged.isNotEmpty && unstaged.isNotEmpty)
          const SizedBox(height: 16),
        if (unstaged.isNotEmpty) ...[
          _buildSectionHeader('CHANGES', unstaged.length),
          ...unstaged.map((c) => _buildChangeItem(c, currentDir)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: Colors.grey[400],
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeItem(GitFileChange change, String currentDir) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 4, right: 8),
      leading: _getStatusIcon(change),
      title: Text(change.path, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        change.isStaged ? 'Staged' : (change.isUntracked ? 'Untracked' : 'Modified'),
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(change.isStaged ? Icons.remove : Icons.add, size: 16),
            onPressed: () async {
              final service = ref.read(gitServiceProvider);
              if (change.isStaged) {
                await service.unstageFile(currentDir, change.path);
              } else {
                await service.stageFile(currentDir, change.path);
              }
              ref.invalidate(gitStatusProvider);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Icon _getStatusIcon(GitFileChange change) {
    if (change.isUntracked) return const Icon(Icons.adjust, color: Colors.green, size: 12);
    if (change.isModified) return const Icon(Icons.mode_edit, color: Colors.amber, size: 12);
    if (change.isStaged) return const Icon(Icons.check, color: Colors.blue, size: 12);
    // Deleted, Renamed etc not fully handled visually yet
    return const Icon(Icons.circle, color: Colors.grey, size: 12);
  }

  Widget _buildCommitBox(String currentDir) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E), // Surface
        border: Border(top: BorderSide(color: Color(0xFF45475A))),
      ),
      child: Column(
        children: [
          TextField(
            controller: _commitController,
            decoration: const InputDecoration(
              hintText: 'Message (Ctrl+Enter to commit)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            maxLines: 2,
            minLines: 1,
            onSubmitted: (_) => _commit(currentDir),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _isCommitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 16),
              label: const Text('Commit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA), // Blue
                foregroundColor: Colors.black,
              ),
              onPressed: _isCommitting ? null : () => _commit(currentDir),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _commit(String currentDir) async {
    final message = _commitController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isCommitting = true);
    
    try {
      final success = await ref.read(gitServiceProvider).commit(currentDir, message);
      if (success) {
        _commitController.clear();
        ref.invalidate(gitStatusProvider);
      }
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }
}
