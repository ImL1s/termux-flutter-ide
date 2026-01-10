import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently open files
final openFilesProvider = NotifierProvider<OpenFilesNotifier, List<String>>(
  OpenFilesNotifier.new,
);

class OpenFilesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void add(String path) {
    if (!state.contains(path)) {
      state = [...state, path];
    }
  }

  void remove(String path) {
    state = state.where((f) => f != path).toList();
  }

  void renameFile(String oldPath, String newPath) {
    state = state.map((f) {
      if (f == oldPath) return newPath;
      if (f.startsWith('$oldPath/')) {
        return f.replaceFirst(oldPath, newPath);
      }
      return f;
    }).toList();
  }

  void removeUnderPath(String path) {
    state = state.where((f) => f != path && !f.startsWith('$path/')).toList();
  }
}

/// Current active file
final currentFileProvider = NotifierProvider<CurrentFileNotifier, String?>(
  CurrentFileNotifier.new,
);

class CurrentFileNotifier extends Notifier<String?> {
  @override
  String? build() {
    final files = ref.watch(openFilesProvider);
    return files.isNotEmpty ? files.first : null;
  }

  void select(String? path) {
    state = path;
  }
}

/// Current project path
final projectPathProvider = NotifierProvider<ProjectPathNotifier, String?>(
  ProjectPathNotifier.new,
);

class ProjectPathNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? path) {
    state = path;
  }
}

/// Terminal output
final terminalOutputProvider =
    NotifierProvider<TerminalOutputNotifier, List<String>>(
  TerminalOutputNotifier.new,
);

class TerminalOutputNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ['Welcome to Termux Flutter IDE Terminal', ''];

  void addLine(String line) {
    state = [...state, line];
  }

  void clear() {
    state = ['Welcome to Termux Flutter IDE Terminal', ''];
  }
}

/// Is terminal command running
final terminalRunningProvider = NotifierProvider<TerminalRunningNotifier, bool>(
  TerminalRunningNotifier.new,
);

class TerminalRunningNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setRunning(bool running) {
    state = running;
  }
}

/// Terminal Command Injection
final terminalCommandProvider =
    NotifierProvider<TerminalCommandNotifier, String?>(
  TerminalCommandNotifier.new,
);

class TerminalCommandNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void run(String cmd) {
    state = cmd;
  }

  void clear() {
    state = null;
  }
}
