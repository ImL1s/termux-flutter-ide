import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'code_actions_provider.dart';
import 'editor_request_provider.dart';
import '../services/lsp_service.dart';
import '../core/providers.dart';

/// Shows the code actions bottom sheet
void showCodeActionsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E1E2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const CodeActionsSheet(),
  );
}

/// Mobile-optimized Code Actions Bottom Sheet
class CodeActionsSheet extends ConsumerWidget {
  const CodeActionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsState = ref.watch(codeActionsProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF181825),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline,
                    color: Color(0xFFF9E2AF), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Code Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF313244)),
          // Content
          Flexible(
            child: actionsState.isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFFCBA6F7),
                      ),
                    ),
                  )
                : actionsState.error != null
                    ? _buildErrorState(actionsState.error!)
                    : actionsState.actions.isEmpty
                        ? _buildEmptyState()
                        : _buildActionsList(context, ref, actionsState.actions),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No actions available',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            'Move cursor to a line with issues to see suggestions',
            style: TextStyle(color: Color(0xFF6C7086), fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFF38BA8)),
          const SizedBox(height: 12),
          const Text(
            'Failed to load actions',
            style: TextStyle(color: Color(0xFFF38BA8), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(color: Color(0xFF6C7086), fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsList(
    BuildContext context,
    WidgetRef ref,
    List<CodeAction> actions,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: actions.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        color: Color(0xFF313244),
        indent: 56,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return _CodeActionTile(action: action);
      },
    );
  }
}

class _CodeActionTile extends ConsumerWidget {
  final CodeAction action;

  const _CodeActionTile({required this.action});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: _buildIcon(),
      title: Text(
        action.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      subtitle: action.kind != null
          ? Text(
              _kindToLabel(action.kind!),
              style: const TextStyle(
                color: Color(0xFF6C7086),
                fontSize: 11,
              ),
            )
          : null,
      trailing: action.isPreferred
          ? const Icon(Icons.star, color: Color(0xFFF9E2AF), size: 16)
          : null,
      onTap: () => _applyAction(context, ref),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    if (action.isQuickFix) {
      icon = Icons.lightbulb;
      color = const Color(0xFFA6E3A1); // Green
    } else if (action.isRefactor) {
      icon = Icons.build;
      color = const Color(0xFF89B4FA); // Blue
    } else {
      icon = Icons.auto_fix_high;
      color = const Color(0xFFCBA6F7); // Purple
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _kindToLabel(String kind) {
    if (kind.startsWith('quickfix')) return 'Quick Fix';
    if (kind.startsWith('refactor.extract')) return 'Extract';
    if (kind.startsWith('refactor.inline')) return 'Inline';
    if (kind.startsWith('refactor')) return 'Refactor';
    if (kind.startsWith('source.organizeImports')) return 'Organize Imports';
    return kind.split('.').last;
  }

  Future<void> _applyAction(BuildContext context, WidgetRef ref) async {
    Navigator.pop(context); // Close the sheet first

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applying: ${action.title}'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF313244),
      ),
    );

    try {
      final lsp = ref.read(lspServiceProvider);

      // Apply workspace edit if present
      if (action.edit != null) {
        await _applyWorkspaceEdit(ref, action.edit!);
      }

      // Execute command if present
      if (action.command != null) {
        await lsp.sendRequest('workspace/executeCommand', {
          'command': action.command!['command'],
          'arguments': action.command!['arguments'] ?? [],
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Action applied successfully'),
            backgroundColor: Color(0xFFA6E3A1),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply action: $e'),
            backgroundColor: const Color(0xFFF38BA8),
          ),
        );
      }
    }
  }

  Future<void> _applyWorkspaceEdit(
    WidgetRef ref,
    Map<String, dynamic> edit,
  ) async {
    // Handle documentChanges or changes
    final documentChanges = edit['documentChanges'] as List?;
    final changes = edit['changes'] as Map<String, dynamic>?;

    if (documentChanges != null) {
      for (final change in documentChanges) {
        if (change['kind'] == 'rename') {
          // Handle file rename - not implemented yet
          continue;
        }

        final textDocument = change['textDocument'];
        final edits = change['edits'] as List?;
        if (textDocument != null && edits != null) {
          final uri = textDocument['uri'] as String;
          final filePath = uri.replaceFirst('file://', '');
          await _applyTextEdits(ref, filePath, edits);
        }
      }
    } else if (changes != null) {
      for (final entry in changes.entries) {
        final filePath = entry.key.replaceFirst('file://', '');
        final edits = entry.value as List;
        await _applyTextEdits(ref, filePath, edits);
      }
    }
  }

  Future<void> _applyTextEdits(
    WidgetRef ref,
    String filePath,
    List edits,
  ) async {
    // For now, trigger a file reload request
    // In a more complete implementation, we'd apply edits in-place
    final currentFile = ref.read(currentFileProvider);
    if (currentFile == filePath) {
      // Request editor to reload/refresh
      ref.read(editorRequestProvider.notifier).request(ReloadFileRequest());
    }
  }
}

/// Request to reload current file content
class ReloadFileRequest extends EditorRequest {}
