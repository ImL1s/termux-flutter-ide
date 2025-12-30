import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/settings/settings_providers.dart';

void main() {
  group('EditorTheme', () {
    test('has display name and id', () {
      expect(EditorTheme.monokai.displayName, 'Monokai Sublime');
      expect(EditorTheme.monokai.id, 'monokai-sublime');
    });

    test('all themes have unique ids', () {
      final ids = EditorTheme.values.map((t) => t.id).toSet();
      expect(ids.length, EditorTheme.values.length);
    });
  });

  group('FontSizeNotifier', () {
    test('has correct constants', () {
      expect(FontSizeNotifier.defaultSize, 14.0);
      expect(FontSizeNotifier.minSize, 10.0);
      expect(FontSizeNotifier.maxSize, 24.0);
    });
  });

  // Note: Full provider tests require SharedPreferences mock
  // which is complex to set up. The constants and enum tests above
  // verify the core logic without async persistence.
}
