import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/ssh_service.dart';
import '../core/providers.dart';
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
  final SSHService _ssh;

  SearchService(this._ssh);

  /// Search for text in files using grep
  Future<List<SearchResult>> search(String query, String directory) async {
    if (query.isEmpty) return [];

    // Use grep -rnI for recursive search with line numbers
    // -I to skip binary files
    // --exclude-dir to skip irrelevant directories for better performance
    final command =
        'grep -rnI --exclude-dir={.git,.dart_tool,.fvm,build} "$query" "$directory" 2>/dev/null | head -100';

    final output = await _ssh.execute(command);

    if (output.isEmpty) {
      return [];
    }

    final results = <SearchResult>[];
    final lines = output.split('\n');

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
    final command =
        'find "$directory" -name "*$pattern*" -type f 2>/dev/null | head -50';
    final output = await _ssh.execute(command);

    if (output.isEmpty) {
      return [];
    }

    return output.split('\n').where((line) => line.isNotEmpty).toList();
  }
}

/// Search Service Provider
final searchServiceProvider = Provider<SearchService>((ref) {
  final ssh = ref.watch(sshServiceProvider);
  return SearchService(ssh);
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
  final projectPath = ref.watch(projectPathProvider);
  final currentDir = ref.watch(currentDirectoryProvider);
  final service = ref.watch(searchServiceProvider);

  if (query.isEmpty) return [];

  // Prioritize project path for workspace-wide search, fallback to current dir
  final searchDir = projectPath ?? currentDir;

  return service.search(query, searchDir);
});
