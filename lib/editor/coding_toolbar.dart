import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'completion/completion_service.dart';
import 'command_palette.dart';

class CodingToolbar extends ConsumerWidget {
  final CodeController controller;

  const CodingToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionState = ref.watch(completionProvider);

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
                if (index == _symbols.length + 3) {
                  return const SizedBox(width: 8);
                }

                final symbol = _symbols[index - 3];
                return _buildButton(symbol, () => _insertText(symbol));
              },
            ),
          ),
        ],
      ),
    );
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
