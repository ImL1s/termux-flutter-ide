import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys for SharedPreferences
const String kEnableDiagnosticsKey = 'enable_diagnostics';
const String kDiagnosticPanelHeightKey = 'diagnostic_panel_height';
const String kTermuxUsernameKey =
    'termux_ssh_username'; // For manual username override
const String kFontSizeKey = 'editor_font_size';
const String kEditorThemeKey = 'editor_theme';

/// Available editor themes
enum EditorTheme {
  monokai('Monokai Sublime', 'monokai-sublime'),
  vsDark('VS Dark', 'vs-dark'),
  githubDark('GitHub Dark', 'github-dark'),
  atomOneDark('Atom One Dark', 'atom-one-dark');

  const EditorTheme(this.displayName, this.id);
  final String displayName;
  final String id;
}

/// SharedPreferences instance provider
final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// Font size provider with persistence
class FontSizeNotifier extends Notifier<double> {
  static const double defaultSize = 14.0;
  static const double minSize = 10.0;
  static const double maxSize = 24.0;

  @override
  double build() {
    _loadFromPrefs();
    return defaultSize;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSize = prefs.getDouble(kFontSizeKey);
    if (savedSize != null) {
      state = savedSize;
    }
  }

  Future<void> setFontSize(double size) async {
    if (size < minSize || size > maxSize) return;
    state = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(kFontSizeKey, size);
  }
}

final fontSizeProvider = NotifierProvider<FontSizeNotifier, double>(
  FontSizeNotifier.new,
);

/// Editor theme provider with persistence
class EditorThemeNotifier extends Notifier<EditorTheme> {
  @override
  EditorTheme build() {
    _loadFromPrefs();
    return EditorTheme.monokai;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeId = prefs.getString(kEditorThemeKey);
    if (savedThemeId != null) {
      final theme = EditorTheme.values.firstWhere(
        (t) => t.id == savedThemeId,
        orElse: () => EditorTheme.monokai,
      );
      state = theme;
    }
  }

  Future<void> setTheme(EditorTheme theme) async {
    state = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kEditorThemeKey, theme.id);
  }
}

final editorThemeProvider = NotifierProvider<EditorThemeNotifier, EditorTheme>(
  EditorThemeNotifier.new,
);
