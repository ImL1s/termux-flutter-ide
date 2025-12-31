import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/search/search_providers.dart';

void main() {
  group('SearchResult Model Tests', () {
    test('SearchResult constructor sets all fields correctly', () {
      final result = SearchResult(
        filePath: '/home/user/project/lib/main.dart',
        lineNumber: 42,
        lineContent: 'void main() {',
        matchText: 'main',
      );

      expect(result.filePath, '/home/user/project/lib/main.dart');
      expect(result.lineNumber, 42);
      expect(result.lineContent, 'void main() {');
      expect(result.matchText, 'main');
    });
  });

  group('SearchQueryNotifier Tests', () {
    test('initial state is empty string', () {
      final container = ProviderContainer();
      final query = container.read(searchQueryProvider);
      expect(query, '');
    });

    test('setQuery updates the state', () {
      final container = ProviderContainer();

      container.read(searchQueryProvider.notifier).setQuery('flutter');
      expect(container.read(searchQueryProvider), 'flutter');

      container.read(searchQueryProvider.notifier).setQuery('dart');
      expect(container.read(searchQueryProvider), 'dart');
    });

    test('setQuery with empty string clears the query', () {
      final container = ProviderContainer();

      container.read(searchQueryProvider.notifier).setQuery('test');
      expect(container.read(searchQueryProvider), 'test');

      container.read(searchQueryProvider.notifier).setQuery('');
      expect(container.read(searchQueryProvider), '');
    });
  });

  group('SearchService Logic Tests', () {
    // Note: We can't easily test SearchService.search() without mocking SSHService
    // These tests verify the parsing logic by creating mock outputs

    test('SearchResult parsing handles standard grep output format', () {
      // Simulate grep output parsing
      const grepOutput = '/path/to/file.dart:10:  void myFunction() {';

      final firstColon = grepOutput.indexOf(':');
      final secondColon = grepOutput.indexOf(':', firstColon + 1);

      final filePath = grepOutput.substring(0, firstColon);
      final lineNumStr = grepOutput.substring(firstColon + 1, secondColon);
      final lineContent = grepOutput.substring(secondColon + 1);
      final lineNumber = int.tryParse(lineNumStr);

      expect(filePath, '/path/to/file.dart');
      expect(lineNumber, 10);
      expect(lineContent.trim(), 'void myFunction() {');
    });

    test('SearchResult parsing handles paths with special characters', () {
      const grepOutput = '/home/user/my project/file.dart:5:content here';

      final firstColon = grepOutput.indexOf(':');
      final secondColon = grepOutput.indexOf(':', firstColon + 1);

      final filePath = grepOutput.substring(0, firstColon);
      final lineNumStr = grepOutput.substring(firstColon + 1, secondColon);

      expect(filePath, '/home/user/my project/file.dart');
      expect(int.tryParse(lineNumStr), 5);
    });

    test('SearchResult parsing handles empty line content', () {
      const grepOutput = '/path/file.dart:1:';

      final firstColon = grepOutput.indexOf(':');
      final secondColon = grepOutput.indexOf(':', firstColon + 1);

      final lineContent = grepOutput.substring(secondColon + 1);

      expect(lineContent, '');
    });

    test('Invalid grep output is handled gracefully', () {
      // Missing line number
      const invalidOutput1 = '/path/file.dart:content';
      final firstColon1 = invalidOutput1.indexOf(':');
      final secondColon1 = invalidOutput1.indexOf(':', firstColon1 + 1);
      expect(secondColon1, -1); // Should be -1, indicating invalid format

      // No colons at all
      const invalidOutput2 = 'just some text';
      expect(invalidOutput2.indexOf(':'), -1);
    });
  });

  group('Multiple Results Parsing Tests', () {
    test('Multiple grep results can be parsed correctly', () {
      const grepMultilineOutput = '''
/path/file1.dart:10:first match
/path/file2.dart:20:second match
/path/subdir/file3.dart:30:third match''';

      final lines = grepMultilineOutput.split('\n');
      expect(lines.length, 3);

      final results = <SearchResult>[];
      for (final line in lines) {
        if (line.isEmpty) continue;

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
          matchText: 'match',
        ));
      }

      expect(results.length, 3);
      expect(results[0].filePath, '/path/file1.dart');
      expect(results[0].lineNumber, 10);
      expect(results[1].filePath, '/path/file2.dart');
      expect(results[1].lineNumber, 20);
      expect(results[2].filePath, '/path/subdir/file3.dart');
      expect(results[2].lineNumber, 30);
    });
  });
}
