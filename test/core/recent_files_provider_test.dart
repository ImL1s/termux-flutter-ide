import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/core/recent_files_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecentFilesProvider', () {
    setUp(() {
      // Reset SharedPreferences for each test
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state is empty list', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(recentFilesProvider.future);
      expect(result, isEmpty);
    });

    test('add() inserts file at the beginning', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file1.dart');
      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file2.dart');

      final result = await container.read(recentFilesProvider.future);
      expect(result.first, '/path/to/file2.dart');
      expect(result[1], '/path/to/file1.dart');
    });

    test('add() moves existing file to the front', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file1.dart');
      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file2.dart');
      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file1.dart');

      final result = await container.read(recentFilesProvider.future);
      expect(result.length, 2);
      expect(result.first, '/path/to/file1.dart');
    });

    test('add() limits to 20 files', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (int i = 0; i < 25; i++) {
        await container
            .read(recentFilesProvider.notifier)
            .add('/path/to/file$i.dart');
      }

      final result = await container.read(recentFilesProvider.future);
      expect(result.length, 20);
      expect(result.first, '/path/to/file24.dart');
    });

    test('remove() removes specific file', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file1.dart');
      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file2.dart');
      await container
          .read(recentFilesProvider.notifier)
          .remove('/path/to/file1.dart');

      final result = await container.read(recentFilesProvider.future);
      expect(result.length, 1);
      expect(result.first, '/path/to/file2.dart');
    });

    test('clear() removes all files', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file1.dart');
      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file2.dart');
      await container.read(recentFilesProvider.notifier).clear();

      final result = await container.read(recentFilesProvider.future);
      expect(result, isEmpty);
    });

    test('persists data to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(recentFilesProvider.notifier)
          .add('/path/to/file.dart');

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('recent_files');

      expect(saved, isNotNull);
      expect(saved!.first, '/path/to/file.dart');
    });
  });
}
