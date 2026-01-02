import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:highlight/languages/dart.dart';

/// Unit tests for Find/Replace logic
/// Note: Full widget tests require a Flutter test environment
void main() {
  group('Find/Replace Logic', () {
    test('find all occurrences of a word', () {
      const text = 'Hello world, hello Dart, hello Flutter';
      const query = 'hello';

      final pattern = query.toLowerCase();
      final searchText = text.toLowerCase();
      final List<int> offsets = [];

      int start = 0;
      while (true) {
        final index = searchText.indexOf(pattern, start);
        if (index == -1) break;
        offsets.add(index);
        start = index + 1;
      }

      expect(offsets.length, 3);
      expect(offsets[0], 0); // "Hello" at start
      expect(offsets[1], 13); // "hello" before Dart
      expect(offsets[2], 25); // "hello" before Flutter
    });

    test('case-sensitive search finds fewer matches', () {
      const text = 'Hello world, hello Dart, HELLO Flutter';
      const query = 'Hello';

      // Case-sensitive search
      final List<int> offsets = [];
      int start = 0;
      while (true) {
        final index = text.indexOf(query, start);
        if (index == -1) break;
        offsets.add(index);
        start = index + 1;
      }

      expect(offsets.length, 1); // Only matches "Hello" at start
      expect(offsets[0], 0);
    });

    test('replace single occurrence', () {
      const text = 'Hello world, hello Dart';
      const query = 'hello';
      const replacement = 'Hi';
      final offset = 13; // Second "hello"

      final newText =
          text.replaceRange(offset, offset + query.length, replacement);

      expect(newText, 'Hello world, Hi Dart');
    });

    test('replace all occurrences case-insensitive', () {
      const text = 'Hello world, hello Dart, HELLO Flutter';
      const query = 'hello';
      const replacement = 'Hi';

      final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
      final newText = text.replaceAll(pattern, replacement);

      expect(newText, 'Hi world, Hi Dart, Hi Flutter');
    });

    test('replace all case-sensitive', () {
      const text = 'Hello world, hello Dart, HELLO Flutter';
      const query = 'hello';
      const replacement = 'Hi';

      final newText = text.replaceAll(query, replacement);

      expect(newText, 'Hello world, Hi Dart, HELLO Flutter');
    });

    test('empty query returns no matches', () {
      const text = 'Hello world';
      const query = '';

      final List<int> offsets = [];
      if (query.isNotEmpty) {
        int start = 0;
        while (true) {
          final index = text.indexOf(query, start);
          if (index == -1) break;
          offsets.add(index);
          start = index + 1;
        }
      }

      expect(offsets, isEmpty);
    });

    test('match navigation wraps around', () {
      final matches = [0, 10, 20, 30];
      int currentIndex = 3; // Last match

      // Next should wrap to 0
      currentIndex = (currentIndex + 1) % matches.length;
      expect(currentIndex, 0);

      // Previous from 0 should wrap to last
      currentIndex = (currentIndex - 1 + matches.length) % matches.length;
      expect(currentIndex, 3);
    });
  });

  group('CodeController Integration', () {
    test('CodeController can be created with Dart language', () {
      final controller = CodeController(language: dart);
      controller.text = 'void main() { }';

      expect(controller.text, 'void main() { }');
      controller.dispose();
    });

    // Note: Modifying CodeController.text directly may not work as expected
    // due to internal highlighting buffer. Full widget tests with pump() are
    // needed for comprehensive CodeController testing.
  });
}
