import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/termux_bridge.dart';
import '../termux/termux_providers.dart';
import '../file_manager/file_operations.dart';

/// Search result model
class SearchResult {
  final String filePath;
  final int lineNumber;
  final String lineContent;
  final String matchText;

  SearchResult({
    required this.filePath,
    required this.lineNumber,
    required this.lineContent,
    required this.matchText,
  });
}

/// Search Service
class SearchService {
  final TermuxBridge _bridge;

  SearchService(this._bridge);

  /// Search for text in files using grep
  Future<List<SearchResult>> search(String query, String directory) async {
    if (query.isEmpty) return [];

    // Use grep -rn for recursive search with line numbers
    // -I to skip binary files
    final result = await _bridge.executeCommand(
      'grep -rnI "$query" "$directory" 2>/dev/null | head -100',
    );

    if (!result.success || result.stdout.isEmpty) {
      return [];
    }

    final results = <SearchResult>[];
    final lines = result.stdout.split('\n');

    for (final line in lines) {
      if (line.isEmpty) continue;

      // Parse grep output: filepath:linenum:content
      final firstColon = line.indexOf(':');
      if (firstColon == -1) continue;

      final secondColon = line.indexOf(':', firstColon + 1);
      if (secondColon == -1) continue;

      final filePath = line.substring(0, firstColon);
      final lineNumStr = line.substring(firstColon + 1, secondColon);
      final lineContent = line.substring(secondColon + 1);

      final lineNumber = int.tryParse(lineNumStr);
      if (lineNumber == null) continue;

      results.add(SearchResult(
        filePath: filePath,
        lineNumber: lineNumber,
        lineContent: lineContent.trim(),
        matchText: query,
      ));
    }

    return results;
  }

  /// Find files by name
  Future<List<String>> findFiles(String pattern, String directory) async {
    final result = await _bridge.executeCommand(
      'find "$directory" -name "*$pattern*" -type f 2>/dev/null | head -50',
    );

    if (!result.success || result.stdout.isEmpty) {
      return [];
    }

    return result.stdout
        .split('\n')
        .where((line) => line.isNotEmpty)
        .toList();
  }
}

/// Search Service Provider
final searchServiceProvider = Provider<SearchService>((ref) {
  final bridge = ref.watch(termuxBridgeProvider);
  return SearchService(bridge);
});

/// Search Query Notifier
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  
  void setQuery(String query) => state = query;
}

/// Search Query Provider
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Search Results Provider
final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final directory = ref.watch(currentDirectoryProvider);
  final service = ref.watch(searchServiceProvider);

  if (query.isEmpty) return [];
  
  return service.search(query, directory);
});

