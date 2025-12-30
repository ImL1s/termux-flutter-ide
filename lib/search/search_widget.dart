import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../theme/app_theme.dart';
import 'search_providers.dart';
import '../editor/editor_request_provider.dart'; // Import Request Provider

class SearchWidget extends ConsumerStatefulWidget {
  const SearchWidget({super.key});

  @override
  ConsumerState<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends ConsumerState<SearchWidget> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);

    return Container(
      color: AppTheme.surface, // Themed
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  size: 16,
                  color: AppTheme.secondary,
                ), // Themed
                const SizedBox(width: 8),
                const Text(
                  'SEARCH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary, // Themed
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search Input
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search in files...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          ref.read(searchQueryProvider.notifier).setQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.surfaceVariant, // Themed
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              onChanged: (value) {
                // Debounce search
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (_controller.text == value) {
                    ref.read(searchQueryProvider.notifier).setQuery(value);
                  }
                });
              },
              onSubmitted: (value) {
                ref.read(searchQueryProvider.notifier).setQuery(value);
              },
            ),
          ),

          // Results
          Expanded(
            child: resultsAsync.when(
              data: (results) => _buildResults(results),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(List<SearchResult> results) {
    if (_controller.text.isEmpty) {
      return const Center(
        child: Text(
          'Type to search in files',
          style: TextStyle(color: AppTheme.textDisabled),
        ),
      );
    }

    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(color: AppTheme.textDisabled),
        ),
      );
    }

    // Group by file
    final groupedResults = <String, List<SearchResult>>{};
    for (final result in results) {
      groupedResults.putIfAbsent(result.filePath, () => []).add(result);
    }

    return ListView.builder(
      itemCount: groupedResults.length,
      itemBuilder: (context, index) {
        final filePath = groupedResults.keys.elementAt(index);
        final fileResults = groupedResults[filePath]!;

        return _buildFileResultGroup(filePath, fileResults);
      },
    );
  }

  Widget _buildFileResultGroup(String filePath, List<SearchResult> results) {
    final fileName = filePath.split('/').last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(
                _getFileIcon(fileName),
                size: 14,
                color: _getFileColor(fileName),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant, // Themed
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${results.length}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ),
        // Results
        ...results.map((result) => _buildResultItem(result)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildResultItem(SearchResult result) {
    return InkWell(
      onTap: () => _openResult(result),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Line number
            SizedBox(
              width: 40,
              child: Text(
                '${result.lineNumber}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            // Line content with highlighted match
            Expanded(
              child: _buildHighlightedText(
                result.lineContent,
                result.matchText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String match) {
    final lowerText = text.toLowerCase();
    final lowerMatch = match.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerMatch);

    if (matchIndex == -1) {
      return Text(
        text,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 12, color: Colors.white),
        children: [
          TextSpan(text: text.substring(0, matchIndex)),
          TextSpan(
            text: text.substring(matchIndex, matchIndex + match.length),
            style: const TextStyle(
              backgroundColor: Color(0xFFF9E2AF),
              color: Colors.black,
            ),
          ),
          TextSpan(text: text.substring(matchIndex + match.length)),
        ],
      ),
    );
  }

  void _openResult(SearchResult result) {
    ref.read(openFilesProvider.notifier).add(result.filePath);
    ref.read(currentFileProvider.notifier).select(result.filePath);

    // Request jump to line
    // We delay slightly to allow file to open/load if it wasn't already
    Future.delayed(const Duration(milliseconds: 100), () {
      ref.read(editorRequestProvider.notifier).request(
            JumpToLineRequest(result.filePath, result.lineNumber),
          );
    });
  }

  IconData _getFileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.flutter_dash;
    if (name.endsWith('.yaml')) return Icons.settings;
    if (name.endsWith('.md')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String name) {
    if (name.endsWith('.dart')) return const Color(0xFF89B4FA);
    if (name.endsWith('.yaml')) return const Color(0xFFF9E2AF);
    if (name.endsWith('.md')) return const Color(0xFFA6E3A1);
    return Colors.grey;
  }
}
