import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/editor_providers.dart';

void main() {
  group('DirtyFilesNotifier', () {
    test('should start empty', () {
      final container = ProviderContainer();
      final dirtyFiles = container.read(dirtyFilesProvider);
      expect(dirtyFiles, isEmpty);
    });

    test('should mark file as dirty', () {
      final container = ProviderContainer();
      container
          .read(dirtyFilesProvider.notifier)
          .markDirty('/path/to/file.dart');

      expect(
        container.read(dirtyFilesProvider),
        contains('/path/to/file.dart'),
      );
    });

    test('should mark file as clean', () {
      final container = ProviderContainer();
      container
          .read(dirtyFilesProvider.notifier)
          .markDirty('/path/to/file.dart');
      container
          .read(dirtyFilesProvider.notifier)
          .markClean('/path/to/file.dart');

      expect(container.read(dirtyFilesProvider), isEmpty);
    });
  });

  group('OriginalContentNotifier', () {
    test('should store content by path', () {
      final container = ProviderContainer();
      final notifier = container.read(originalContentProvider.notifier);

      notifier.set('/path/a.dart', 'content A');
      notifier.set('/path/b.dart', 'content B');

      final map = container.read(originalContentProvider);
      expect(map['/path/a.dart'], 'content A');
      expect(map['/path/b.dart'], 'content B');
    });
  });

  group('SaveTriggerNotifier', () {
    test('should increment on trigger', () {
      final container = ProviderContainer();
      final sub = container.listen(saveTriggerProvider, (_, __) {});

      // Initial is 0
      expect(sub.read(), 0);

      // Trigger
      container.read(saveTriggerProvider.notifier).trigger();
      expect(sub.read(), 1);

      container.read(saveTriggerProvider.notifier).trigger();
      expect(sub.read(), 2);
    });
  });
}
