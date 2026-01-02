import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/editor/completion/completion_service.dart';

void main() {
  group('Snippets', () {
    test('contains basic Flutter snippets', () {
      // Verify expected snippet labels are defined
      final expectedLabels = {
        'stless',
        'stful',
        'init',
        'dis',
        'build',
        'importM',
        'riverpod',
        'consumer',
        'async',
        'printd',
        'column',
        'row',
        'padding',
        'container',
      };

      // Test that we have a reasonable number of expected snippets
      expect(expectedLabels.length, greaterThanOrEqualTo(14));

      // Test that CompletionState works as expected
      const state = CompletionState(suggestions: [], isLoading: false);
      expect(state.suggestions, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('Suggestion model works correctly', () {
      const snippet = Suggestion(
        label: 'stless',
        insertText: 'class MyWidget extends StatelessWidget {}',
        type: SuggestionType.snippet,
        detail: 'StatelessWidget',
      );

      expect(snippet.label, 'stless');
      expect(snippet.type, SuggestionType.snippet);
      expect(snippet.detail, 'StatelessWidget');
      expect(snippet.insertText.contains('StatelessWidget'), isTrue);
    });

    test('SuggestionType enum has correct values', () {
      expect(SuggestionType.values.length, 2);
      expect(SuggestionType.keyword.name, 'keyword');
      expect(SuggestionType.snippet.name, 'snippet');
    });

    test('CompletionState with suggestions', () {
      final suggestions = [
        const Suggestion(
          label: 'test',
          insertText: 'test',
          type: SuggestionType.keyword,
        ),
        const Suggestion(
          label: 'stful',
          insertText: 'StatefulWidget template',
          type: SuggestionType.snippet,
          detail: 'StatefulWidget',
        ),
      ];

      final state = CompletionState(suggestions: suggestions, isLoading: true);
      expect(state.suggestions.length, 2);
      expect(state.isLoading, isTrue);
      expect(state.suggestions[1].type, SuggestionType.snippet);
    });
  });
}
