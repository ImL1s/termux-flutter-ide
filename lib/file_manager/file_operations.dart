import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/termux_bridge.dart';
import '../termux/termux_providers.dart';

/// File Operations Service
class FileOperations {
  final TermuxBridge _bridge;

  FileOperations(this._bridge);

  /// Create a new file
  Future<bool> createFile(String path) async {
    final result = await _bridge.executeCommand('touch "$path"');
    return result.success;
  }

  /// Create a new directory
  Future<bool> createDirectory(String path) async {
    final result = await _bridge.executeCommand('mkdir -p "$path"');
    return result.success;
  }

  /// Rename/move a file or directory
  Future<bool> rename(String oldPath, String newPath) async {
    final result = await _bridge.executeCommand('mv "$oldPath" "$newPath"');
    return result.success;
  }

  /// Delete a file
  Future<bool> deleteFile(String path) async {
    final result = await _bridge.executeCommand('rm "$path"');
    return result.success;
  }

  /// Delete a directory (recursive)
  Future<bool> deleteDirectory(String path) async {
    final result = await _bridge.executeCommand('rm -rf "$path"');
    return result.success;
  }

  /// List directory contents
  Future<List<FileItem>> listDirectory(String path) async {
    final result = await _bridge.executeCommand('ls -la "$path"');
    if (!result.success) return [];

    final lines = result.stdout.split('\n');
    final items = <FileItem>[];

    for (final line in lines) {
      if (line.isEmpty || line.startsWith('total')) continue;
      
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 9) continue;

      final permissions = parts[0];
      final name = parts.sublist(8).join(' ');
      
      if (name == '.' || name == '..') continue;

      items.add(FileItem(
        name: name,
        path: '$path/$name',
        isDirectory: permissions.startsWith('d'),
      ));
    }

    return items;
  }

  /// Read file content
  Future<String?> readFile(String path) async {
    final result = await _bridge.executeCommand('cat "$path"');
    if (result.success) {
      return result.stdout;
    }
    return null;
  }

  /// Write file content
  Future<bool> writeFile(String path, String content) async {
    // Escape special characters for shell
    final escaped = content
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\$', '\\\$')
        .replaceAll('`', '\\`');
    
    final result = await _bridge.executeCommand('echo "$escaped" > "$path"');
    return result.success;
  }
}

/// File item model
class FileItem {
  final String name;
  final String path;
  final bool isDirectory;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
  });
}

/// File Operations Provider
final fileOperationsProvider = Provider<FileOperations>((ref) {
  final bridge = ref.watch(termuxBridgeProvider);
  return FileOperations(bridge);
});

/// Current Directory Notifier
class CurrentDirectoryNotifier extends Notifier<String> {
  @override
  String build() => '/storage/emulated/0';
  
  void setPath(String path) => state = path;
}

/// Current Directory Provider
final currentDirectoryProvider = NotifierProvider<CurrentDirectoryNotifier, String>(
  CurrentDirectoryNotifier.new,
);

/// Directory Contents Provider
final directoryContentsProvider = FutureProvider.family<List<FileItem>, String>((ref, path) async {
  final ops = ref.watch(fileOperationsProvider);
  return ops.listDirectory(path);
});

