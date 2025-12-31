import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/core/providers.dart';

void main() {
  group('OpenFilesNotifier', () {
    test('starts with empty list', () {
      final container = ProviderContainer();
      final files = container.read(openFilesProvider);

      expect(files, isEmpty);
    });

    test('add adds new file', () {
      final container = ProviderContainer();
      container.read(openFilesProvider.notifier).add('/path/to/file.dart');

      expect(container.read(openFilesProvider), contains('/path/to/file.dart'));
    });

    test('add does not duplicate files', () {
      final container = ProviderContainer();
      container.read(openFilesProvider.notifier).add('/path/file.dart');
      container.read(openFilesProvider.notifier).add('/path/file.dart');

      final files = container.read(openFilesProvider);
      expect(files.where((f) => f == '/path/file.dart').length, 1);
    });

    test('remove removes file', () {
      final container = ProviderContainer();
      container.read(openFilesProvider.notifier).add('/path/file.dart');
      container.read(openFilesProvider.notifier).remove('/path/file.dart');

      expect(container.read(openFilesProvider),
          isNot(contains('/path/file.dart')));
    });
  });

  group('CurrentFileNotifier', () {
    test('starts with null (no file selected)', () {
      final container = ProviderContainer();
      final current = container.read(currentFileProvider);

      expect(current, isNull);
    });

    test('select changes current file', () {
      final container = ProviderContainer();
      container.read(currentFileProvider.notifier).select('/new/file.dart');

      expect(container.read(currentFileProvider), '/new/file.dart');
    });

    test('select accepts null', () {
      final container = ProviderContainer();
      container.read(currentFileProvider.notifier).select(null);

      expect(container.read(currentFileProvider), isNull);
    });
  });

  group('ProjectPathNotifier', () {
    test('starts null', () {
      final container = ProviderContainer();
      expect(container.read(projectPathProvider), isNull);
    });

    test('set changes project path', () {
      final container = ProviderContainer();
      container.read(projectPathProvider.notifier).set('/my/project');

      expect(container.read(projectPathProvider), '/my/project');
    });
  });

  group('TerminalOutputNotifier', () {
    test('starts with welcome message', () {
      final container = ProviderContainer();
      final output = container.read(terminalOutputProvider);

      expect(output, isNotEmpty);
      expect(output.first, contains('Welcome'));
    });

    test('addLine adds line', () {
      final container = ProviderContainer();
      container.read(terminalOutputProvider.notifier).addLine('Test output');

      expect(container.read(terminalOutputProvider), contains('Test output'));
    });

    test('clear resets to welcome', () {
      final container = ProviderContainer();
      container.read(terminalOutputProvider.notifier).addLine('Test');
      container.read(terminalOutputProvider.notifier).clear();

      final output = container.read(terminalOutputProvider);
      expect(output.first, contains('Welcome'));
      expect(output, isNot(contains('Test')));
    });
  });

  group('TerminalRunningNotifier', () {
    test('starts false', () {
      final container = ProviderContainer();
      expect(container.read(terminalRunningProvider), isFalse);
    });

    test('setRunning changes state', () {
      final container = ProviderContainer();
      container.read(terminalRunningProvider.notifier).setRunning(true);

      expect(container.read(terminalRunningProvider), isTrue);
    });
  });
}
