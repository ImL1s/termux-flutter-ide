import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dirty files provider (Set of file paths that have unsaved changes)
final dirtyFilesProvider = NotifierProvider<DirtyFilesNotifier, Set<String>>(
  DirtyFilesNotifier.new,
);

class DirtyFilesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void markDirty(String path) {
    if (!state.contains(path)) {
      state = {...state, path};
    }
  }

  void markClean(String path) {
    if (state.contains(path)) {
      state = {...state}..remove(path);
    }
  }

  bool isDirty(String path) => state.contains(path);
}

/// Cache for original file content to detect if changes were made.
/// Using `Map<Path, Content>` to avoid FamilyNotifier complexity.
final originalContentProvider =
    NotifierProvider<OriginalContentNotifier, Map<String, String>>(
  OriginalContentNotifier.new,
);

class OriginalContentNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  void set(String path, String content) {
    state = {...state, path: content};
  }

  String? get(String path) => state[path];
}

/// Currently saving file provider
final isSavingProvider = NotifierProvider<IsSavingNotifier, bool>(
  IsSavingNotifier.new,
);

class IsSavingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

/// Trigger for save action
final saveTriggerProvider = NotifierProvider<SaveTriggerNotifier, int>(
  SaveTriggerNotifier.new,
);

class SaveTriggerNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void trigger() => state++;
}

class CursorPosition {
  final int line;
  final int column;
  const CursorPosition(this.line, this.column);
}

final cursorPositionProvider = StateProvider<CursorPosition?>((ref) => null);
