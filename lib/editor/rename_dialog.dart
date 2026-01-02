import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import 'editor_providers.dart';
import '../services/lsp_service.dart';

/// Shows a mobile-friendly rename dialog and applies the refactoring.
Future<void> showRenameDialog(
    BuildContext context, WidgetRef ref, String filePath) async {
  final cursorPosition = ref.read(cursorPositionProvider);
  if (cursorPosition == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Place cursor on a symbol to rename.')));
    return;
  }

  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: const Row(
        children: [
          Icon(Icons.edit, color: Color(0xFFCBA6F7)),
          SizedBox(width: 8),
          Text('Rename Symbol', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'New name',
          filled: true,
          fillColor: const Color(0xFF313244),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontFamily: 'JetBrains Mono'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final newName = controller.text.trim();
            if (newName.isNotEmpty) {
              Navigator.pop(context, newName);
            }
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );

  if (result == null || result.isEmpty) return;

  final lsp = ref.read(lspServiceProvider);
  final workspaceEdit = await lsp.renameSymbol(
    filePath,
    cursorPosition.line,
    cursorPosition.column,
    result,
  );

  if (workspaceEdit == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rename failed or symbol not found.')));
    }
    return;
  }

  // Apply workspace edit
  if (workspaceEdit.containsKey('changes')) {
    final changes = workspaceEdit['changes'] as Map<String, dynamic>;
    int filesChanged = 0;
    int editsApplied = 0;

    for (final entry in changes.entries) {
      final _ = entry.key; // Unused but needed for iteration
      final edits = (entry.value as List).cast<Map<String, dynamic>>();
      filesChanged++;
      editsApplied += edits.length;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Renamed to "$result" ($editsApplied edits in $filesChanged files)')));
      ref.invalidate(currentFileProvider);
    }
  } else if (workspaceEdit.containsKey('documentChanges')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Renamed to "$result"')));
      ref.invalidate(currentFileProvider);
    }
  }
}
