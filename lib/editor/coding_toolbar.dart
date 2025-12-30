import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

class CodingToolbar extends StatelessWidget {
  final CodeController controller;

  const CodingToolbar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final symbols = [
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

    return Container(
      height: 48,
      color: const Color(0xFF1E1E2E), // Base/Mantle color from Catppuccin
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: symbols.length + 2, // Symbols + Tab + Backspace/Clear
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildButton('Tab', () => _insertText('\t'));
          }
          if (index == symbols.length + 1) {
            // Optional: Add space or special actions
            return const SizedBox(width: 8);
          }

          final symbol = symbols[index - 1];
          return _buildButton(symbol, () => _insertText(symbol));
        },
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF313244), // Surface0
          foregroundColor: const Color(0xFFCDD6F4), // Text
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
