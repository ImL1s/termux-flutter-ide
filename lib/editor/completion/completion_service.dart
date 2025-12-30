import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  void updateSuggestions(String currentWord, String fullLine) {
    if (currentWord.isEmpty) {
      state = const CompletionState(suggestions: []);
      return;
    }

    final List<Suggestion> results = [];

    // 1. Check Snippets
    for (final snippet in _dartSnippets) {
      if (snippet.label.startsWith(currentWord)) {
        results.add(snippet);
      }
    }

    // 2. Check File Keywords
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

    state = CompletionState(suggestions: results);
  }

  void clear() {
    state = const CompletionState(suggestions: []);
  }
}

final completionProvider =
    NotifierProvider<CompletionNotifier, CompletionState>(
      CompletionNotifier.new,
    );
