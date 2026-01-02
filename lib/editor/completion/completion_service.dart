import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/lsp_service.dart';

enum SuggestionType { keyword, snippet }

class Suggestion {
  final String label;
  final String insertText;
  final SuggestionType type;
  final String? detail;

  const Suggestion({
    required this.label,
    required this.insertText,
    required this.type,
    this.detail,
  });
}

class CompletionState {
  final List<Suggestion> suggestions;
  final bool isLoading;

  const CompletionState({this.suggestions = const [], this.isLoading = false});
}

class CompletionNotifier extends Notifier<CompletionState> {
  // Cached keywords from the current file
  final Set<String> _fileKeywords = {};

  @override
  CompletionState build() {
    return const CompletionState();
  }

  // Predefined Dart Snippets
  static const List<Suggestion> _dartSnippets = [
    Suggestion(
      label: 'stless',
      insertText: '''class \${1:MyWidget} extends StatelessWidget {
  const \${1:MyWidget}({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}''',
      type: SuggestionType.snippet,
      detail: 'StatelessWidget',
    ),
    Suggestion(
      label: 'stful',
      insertText: '''class \${1:MyWidget} extends StatefulWidget {
  const \${1:MyWidget}({super.key});

  @override
  State<\${1:MyWidget}> createState() => _\${1:MyWidget}State();
}

class _\${1:MyWidget}State extends State<\${1:MyWidget}> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}''',
      type: SuggestionType.snippet,
      detail: 'StatefulWidget',
    ),
    Suggestion(
      label: 'init',
      insertText: '''@override
  void initState() {
    super.initState();
    \${1}
  }''',
      type: SuggestionType.snippet,
      detail: 'initState',
    ),
    Suggestion(
      label: 'dis',
      insertText: '''@override
  void dispose() {
    \${1}
    super.dispose();
  }''',
      type: SuggestionType.snippet,
      detail: 'dispose',
    ),
    Suggestion(
      label: 'build',
      insertText: '''@override
  Widget build(BuildContext context) {
    return \${0:Container()};
  }''',
      type: SuggestionType.snippet,
      detail: 'build method',
    ),
    Suggestion(
      label: 'importM',
      insertText: "import 'package:flutter/material.dart';",
      type: SuggestionType.snippet,
      detail: 'Import Material',
    ),
    // Additional mobile-productivity snippets
    Suggestion(
      label: 'riverpod',
      insertText:
          '''final \${1:name}Provider = StateProvider<\${2:Type}>((ref) {
  return \${0:initialValue};
});''',
      type: SuggestionType.snippet,
      detail: 'Riverpod Provider',
    ),
    Suggestion(
      label: 'consumer',
      insertText: '''Consumer(
  builder: (context, ref, child) {
    final \${1:value} = ref.watch(\${2:provider});
    return \${0:Container()};
  },
)''',
      type: SuggestionType.snippet,
      detail: 'Riverpod Consumer',
    ),
    Suggestion(
      label: 'async',
      insertText: '''Future<\${1:void}> \${2:functionName}() async {
  try {
    \${0}
  } catch (e) {
    print('Error: \$e');
  }
}''',
      type: SuggestionType.snippet,
      detail: 'Async Function',
    ),
    Suggestion(
      label: 'printd',
      insertText: "print('DEBUG: \${1:message}');",
      type: SuggestionType.snippet,
      detail: 'Debug Print',
    ),
    Suggestion(
      label: 'column',
      insertText: '''Column(
  mainAxisAlignment: MainAxisAlignment.\${1:center},
  children: [
    \${0}
  ],
)''',
      type: SuggestionType.snippet,
      detail: 'Column Widget',
    ),
    Suggestion(
      label: 'row',
      insertText: '''Row(
  mainAxisAlignment: MainAxisAlignment.\${1:spaceBetween},
  children: [
    \${0}
  ],
)''',
      type: SuggestionType.snippet,
      detail: 'Row Widget',
    ),
    Suggestion(
      label: 'padding',
      insertText: '''Padding(
  padding: const EdgeInsets.all(\${1:8.0}),
  child: \${0:Container()},
)''',
      type: SuggestionType.snippet,
      detail: 'Padding Widget',
    ),
    Suggestion(
      label: 'container',
      insertText: '''Container(
  padding: const EdgeInsets.all(\${1:16}),
  decoration: BoxDecoration(
    color: \${2:Colors.white},
    borderRadius: BorderRadius.circular(\${3:8}),
  ),
  child: \${0},
)''',
      type: SuggestionType.snippet,
      detail: 'Styled Container',
    ),
  ];

  /// Scan file content to extract keywords (naive approach)
  void updateFileContent(String content) {
    // Regex to match words starting with letter/underscore, followed by alphanumerics
    final regex = RegExp(r'[a-zA-Z_]\w*');
    final matches = regex.allMatches(content);
    _fileKeywords.clear();
    for (final match in matches) {
      final word = match.group(0);
      if (word != null && word.length > 2) {
        _fileKeywords.add(word);
      }
    }
  }

  /// Generate suggestions based on current input
  Future<void> updateSuggestions(String currentWord, String fullLine,
      {String? filePath, int? line, int? column}) async {
    if (currentWord.isEmpty && !fullLine.endsWith('.')) {
      state = const CompletionState(suggestions: []);
      return;
    }

    // Set loading state if we're going to use LSP
    final isDart = filePath?.endsWith('.dart') ?? false;
    if (isDart) {
      state = CompletionState(suggestions: state.suggestions, isLoading: true);
    }

    final List<Suggestion> results = [];

    // 1. Check Snippets (Sync)
    for (final snippet in _dartSnippets) {
      if (snippet.label.startsWith(currentWord)) {
        results.add(snippet);
      }
    }

    // 2. Check File Keywords (Sync)
    for (final keyword in _fileKeywords) {
      if (keyword.startsWith(currentWord) && keyword != currentWord) {
        results.add(
          Suggestion(
            label: keyword,
            insertText: keyword,
            type: SuggestionType.keyword,
          ),
        );
      }
    }

    // 3. Check LSP (Async)
    if (isDart && filePath != null && line != null && column != null) {
      try {
        final lsp = ref.read(lspServiceProvider);
        final lspItems = await lsp.getCompletions(filePath, line, column);

        for (final item in lspItems) {
          final label = item['label'] as String;
          final insertText = (item['insertText'] ?? label) as String;
          final detail = item['detail'] as String?;

          results.add(Suggestion(
            label: label,
            insertText: insertText,
            type: SuggestionType
                .keyword, // Could map LSP kinds to SuggestionType later
            detail: detail,
          ));
        }
      } catch (e) {
        print('Completion LSP Error: $e');
      }
    }

    state = CompletionState(suggestions: results, isLoading: false);
  }

  void clear() {
    state = const CompletionState(suggestions: []);
  }
}

final completionProvider =
    NotifierProvider<CompletionNotifier, CompletionState>(
  CompletionNotifier.new,
);
