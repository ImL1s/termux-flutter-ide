import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing recently opened files
/// Stores up to 20 files and persists across app restarts
class RecentFilesNotifier extends AsyncNotifier<List<String>> {
  static const _key = 'recent_files';
  static const _maxFiles = 20;

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final files = prefs.getStringList(_key) ?? [];
    return files;
  }

  /// Add a file to recent list (most recent first)
  Future<void> add(String filePath) async {
    final currentList = state.value ?? [];

    // Remove if already exists (to move to front)
    final updated = currentList.where((f) => f != filePath).toList();
    updated.insert(0, filePath);

    // Limit to max files
    if (updated.length > _maxFiles) {
      updated.removeRange(_maxFiles, updated.length);
    }

    state = AsyncValue.data(updated);

    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated);
  }

  /// Clear all recent files
  Future<void> clear() async {
    state = const AsyncValue.data([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Remove a specific file from recent list
  Future<void> remove(String filePath) async {
    final currentList = state.value ?? [];
    final updated = currentList.where((f) => f != filePath).toList();

    state = AsyncValue.data(updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, updated);
  }
}

final recentFilesProvider =
    AsyncNotifierProvider<RecentFilesNotifier, List<String>>(
  RecentFilesNotifier.new,
);
