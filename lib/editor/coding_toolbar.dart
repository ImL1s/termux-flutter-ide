import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'completion/completion_service.dart';
import 'command_palette.dart';
import 'editor_providers.dart';
import 'diagnostics_provider.dart';
import '../services/lsp_service.dart';
import '../core/providers.dart';

class CodingToolbar extends ConsumerWidget {
  final CodeController controller;
  final VoidCallback onSearch;

  const CodingToolbar({
    super.key,
    required this.controller,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionState = ref.watch(completionProvider);
    final cursorPosition = ref.watch(cursorPositionProvider);
    final currentFile = ref.watch(currentFileProvider);
    final diagnosticsState = ref.watch(diagnosticsProvider);

    // Find diagnostics for current line
    final currentDiagnostics = _getDiagnosticsForCurrentLine(
      currentFile,
      cursorPosition,
      diagnosticsState,
    );

    return Container(
      color: const Color(0xFF1E1E2E),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Suggestions Row
          if (completionState.suggestions.isNotEmpty)
            Container(
              height: 40,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF313244))),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: completionState.suggestions.length,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemBuilder: (context, index) {
                  final suggestion = completionState.suggestions[index];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: TextButton(
                      onPressed: () => _insertSuggestion(ref, suggestion),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF45475A), // Surface1
                        foregroundColor: const Color(0xFFCDD6F4),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            suggestion.type == SuggestionType.snippet
                                ? Icons.code
                                : Icons.text_fields,
                            size: 14,
                            color: const Color(0xFF89B4FA), // Blue
                          ),
                          const SizedBox(width: 6),
                          Text(
                            suggestion.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'JetBrainsMono',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Symbols Row
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _symbols.length + 2,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildButton('Tab', () => _insertText('\t'));
                }
                if (index == 1) {
                  return _buildButton('Def', () {
                    final registry = ref.read(commandServiceProvider);
                    registry.execute('editor.goToDefinition');
                  });
                }
                if (index == 2) {
                  return _buildButton('Ref', () {
                    final registry = ref.read(commandServiceProvider);
                    registry.execute('editor.findReferences');
                  });
                }
                if (index == 3) {
                  return _buildButton('Fmt', () {
                    final registry = ref.read(commandServiceProvider);
                    registry.execute('editor.format');
                  });
                }
                if (index == 4) {
                  return _buildButton('🔍', onSearch);
                }
                if (index == _symbols.length + 5) {
                  return const SizedBox(width: 8);
                }

                final symbol = _symbols[index - 5];
                return _buildButton(symbol, () => _insertText(symbol));
              },
            ),
          ),

          // Diagnostic / Quick Fix Row (if diagnostics exist)
          if (currentDiagnostics.isNotEmpty)
            Container(
              height: 40,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF313244))),
                color: Color(0xFF181825),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.lightbulb_outline,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentDiagnostics.first.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCDD6F4),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        _showQuickFixes(context, ref, currentDiagnostics),
                    child: const Text('Quick Fix',
                        style: TextStyle(color: Color(0xFF89B4FA))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<LspDiagnostic> _getDiagnosticsForCurrentLine(
    String? currentFile,
    CursorPosition? position,
    DiagnosticsState state,
  ) {
    if (currentFile == null || position == null) return [];
    final uri = 'file://$currentFile';
    final diagnostics = state.fileDiagnostics[uri] ?? [];

    return diagnostics
        .where((d) => d.range.startLine == position.line)
        .toList();
  }

  void _showQuickFixes(BuildContext context, WidgetRef ref,
      List<LspDiagnostic> diagnostics) async {
    final currentFile = ref.read(currentFileProvider);
    final cursor = ref.read(cursorPositionProvider);
    if (currentFile == null || cursor == null) return;

    final lsp = ref.read(lspServiceProvider);
    final actions = await lsp.getCodeActions(
      currentFile,
      cursor.line,
      cursor.column,
      diagnostics,
    );

    if (!context.mounted) return;

    if (actions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quick fixes available')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (context) => ListView.builder(
        shrinkWrap: true,
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          final title = action['title'] as String;

          return ListTile(
            leading: const Icon(Icons.build, color: Colors.blue),
            title: Text(title, style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _applyCodeAction(ref, action);
            },
          );
        },
      ),
    );
  }

  void _applyCodeAction(WidgetRef ref, Map<String, dynamic> action) {
    // A code action can have 'edit' (WorkspaceEdit) or 'command' (Command)
    if (action.containsKey('edit')) {
      final edit = action['edit'] as Map<String, dynamic>;
      _applyWorkspaceEdit(ref, edit);
    } else if (action.containsKey('command')) {
      // Execute command via LSP? Or just ignore for now if it requires server-side execution
      // Some formatting/refactors use commands
    }
  }

  void _applyWorkspaceEdit(WidgetRef ref, Map<String, dynamic> edit) {
    if (edit.containsKey('changes')) {
      final changes = edit['changes'] as Map<String, dynamic>;
      changes.forEach((uri, textEdits) {
        final filePath = uri.replaceAll('file://', '');
        final currentFilePath = ref.read(currentFileProvider);

        if (filePath == currentFilePath) {
          final edits = (textEdits as List).cast<Map<String, dynamic>>();
          _applyTextEdits(ref, edits);
        }
      });
    }
  }

  void _applyTextEdits(WidgetRef ref, List<Map<String, dynamic>> edits) {
    // For now, we only support single edits for simplicity (like Quick Fixes usually are)
    if (edits.isEmpty) return;

    // We need to apply edits to the controller
    // If we have multiple, we must apply them from bottom to top to preserve offsets
    edits.sort((a, b) {
      final aStart = a['range']['start'] as Map<String, dynamic>;
      final bStart = b['range']['start'] as Map<String, dynamic>;
      if (aStart['line'] != bStart['line']) {
        return bStart['line'].compareTo(aStart['line']);
      }
      return bStart['character'].compareTo(aStart['character']);
    });

    String text = controller.text;
    for (final edit in edits) {
      final range = edit['range'] as Map<String, dynamic>;
      final start = range['start'] as Map<String, dynamic>;
      final end = range['end'] as Map<String, dynamic>;
      final newText = edit['newText'] as String;

      final startOffset = _getOffset(text, start['line'], start['character']);
      final endOffset = _getOffset(text, end['line'], end['character']);

      text = text.replaceRange(startOffset, endOffset, newText);
    }

    controller.text = text;
    // We might need to adjust selection too, but let's keep it simple for now.
  }

  int _getOffset(String text, int line, int character) {
    final lines = text.split('\n');
    int offset = 0;
    for (int i = 0; i < line; i++) {
      if (i < lines.length) {
        offset += lines[i].length + 1; // +1 for \n
      } else {
        offset += 1;
      }
    }
    return offset + character;
  }

  static const _symbols = [
    '{',
    '}',
    '(',
    ')',
    '[',
    ']',
    ';',
    ':',
    '.',
    ',',
    '"',
    '\'',
    '=',
    '+',
    '-',
    '*',
    '/',
    '_',
    '\$'
  ];

  Widget _buildButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF313244),
          foregroundColor: const Color(0xFFCDD6F4),
          minimumSize: const Size(40, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _insertSuggestion(WidgetRef ref, Suggestion suggestion) {
    final selection = controller.selection;
    if (!selection.isValid) return;

    // We need to figure out what part of text to replace (the current word being typed)
    // For MVP, we'll naive replace the current word left of cursor
    final text = controller.text;
    final cursor = selection.baseOffset;

    // Find word start
    int start = cursor - 1;
    while (start >= 0) {
      final char = text[start];
      if (!RegExp(r'[a-zA-Z0-9_]').hasMatch(char)) {
        break;
      }
      start--;
    }
    start++; // Move back to first char of word

    final newText = text.replaceRange(start, cursor, suggestion.insertText);
    controller.text = newText;

    // Find where the cursor should be (handle ${1:placeholder} logic if needed)
    // For MVP, just place cursor at end
    // Advanced: Handle snippet tab stops (future work)
    controller.selection =
        TextSelection.collapsed(offset: start + suggestion.insertText.length);

    // Clear suggestions
    ref.read(completionProvider.notifier).clear();
  }

  void _insertText(String text) {
    final selection = controller.selection;
    if (selection.isValid) {
      final currentText = controller.text;
      final newText =
          currentText.replaceRange(selection.start, selection.end, text);
      controller.text = newText;
      controller.selection =
          TextSelection.collapsed(offset: selection.start + text.length);
    } else {
      controller.text += text;
    }
  }
}
