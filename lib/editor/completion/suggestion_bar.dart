import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'completion_service.dart';
import '../../theme/app_theme.dart';

class SuggestionBar extends ConsumerWidget {
  final Function(Suggestion) onSuggestionSelected;

  const SuggestionBar({super.key, required this.onSuggestionSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionState = ref.watch(completionProvider);

    if (completionState.suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 48,
      color: AppTheme.surface, // Themed
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: completionState.suggestions.length,
        separatorBuilder: (context, index) => const VerticalDivider(
          width: 1,
          color: Colors.white10,
          indent: 12,
          endIndent: 12,
        ),
        itemBuilder: (context, index) {
          final suggestion = completionState.suggestions[index];
          return InkWell(
            onTap: () => onSuggestionSelected(suggestion),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                children: [
                  Icon(
                    suggestion.type == SuggestionType.snippet
                        ? Icons.code
                        : Icons.abc,
                    size: 16,
                    color: suggestion.type == SuggestionType.snippet
                        ? AppTheme
                              .primary // Themed
                        : AppTheme.secondary, // Themed
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.label,
                        style: const TextStyle(
                          color: AppTheme.textPrimary, // Themed
                          fontSize: 14,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      if (suggestion.detail != null)
                        Text(
                          suggestion.detail!,
                          style: const TextStyle(
                            color: AppTheme.textDisabled, // Themed
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
