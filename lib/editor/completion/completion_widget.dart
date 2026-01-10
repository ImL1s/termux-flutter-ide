import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'completion_service.dart';

class CompletionWidget extends ConsumerWidget {
  final Function(Suggestion) onApply;

  const CompletionWidget({super.key, required this.onApply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(completionProvider);

    if (state.suggestions.isEmpty && !state.isLoading) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF252526), // VS Code Dark Menu
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 200, // Limit height
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: state.suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = state.suggestions[index];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: _buildIcon(suggestion.type),
                    title: Text.rich(
                      TextSpan(
                        children: [
                           TextSpan(
                             text: suggestion.label,
                             style: const TextStyle(
                               fontFamily: 'JetBrains Mono',
                               color: Colors.white,
                               fontSize: 14
                             )
                           ),
                           if (suggestion.detail != null)
                             TextSpan(
                               text: '  ${suggestion.detail}',
                               style: TextStyle(
                                 color: Colors.grey[400],
                                 fontSize: 12
                               )
                             )
                        ]
                      )
                    ),
                    onTap: () => onApply(suggestion),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(SuggestionType type) {
    switch (type) {
      case SuggestionType.keyword:
        return const Icon(Icons.text_fields, size: 16, color: Colors.blueAccent);
      case SuggestionType.snippet:
        return const Icon(Icons.code, size: 16, color: Colors.orangeAccent);
      default:
        return const Icon(Icons.label, size: 16, color: Colors.grey);
    }
  }
}
