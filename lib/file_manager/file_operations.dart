import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/ssh_service.dart';

/// File Operations Service
class FileOperations {
  final SSHService _ssh;

  FileOperations(this._ssh);

  Future<String> _exec(String cmd) async {
    if (!_ssh.isConnected) {
      try {
        await _ssh.connect();
      } catch (e) {
        throw Exception("Failed to connect to Termux: $e");
      }
    }
    return await _ssh.execute(cmd);
  }

  /// Create a new file
  Future<bool> createFile(String path) async {
    try {
      await _exec('touch "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create a new directory
  Future<bool> createDirectory(String path) async {
    try {
      await _exec('mkdir -p "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Rename/move a file or directory
  Future<bool> rename(String oldPath, String newPath) async {
    try {
      await _exec('mv "$oldPath" "$newPath"');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a file
  Future<bool> deleteFile(String path) async {
    try {
      await _exec('rm "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a directory (recursive)
  Future<bool> deleteDirectory(String path) async {
    try {
      await _exec('rm -rf "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// List directory contents
  Future<List<FileItem>> listDirectory(String path) async {
    try {
      // Use -la to show hidden files. Use -F to show file types (e.g., / for dirs, @ for links)
      final stdout = await _exec('ls -la "$path"');
      final lines = stdout.split('\n');
      final items = <FileItem>[];

      for (final line in lines) {
        if (line.isEmpty || line.startsWith('total')) continue;

        // Skip . and ..
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 9) continue;

        final permissions = parts[0];
        // Name is usually the 9th part onwards
        String name = parts.sublist(8).join(' ');

        if (name == '.' || name == '..') continue;

        bool isDirectory = permissions.startsWith('d');

        // Handle symlinks
        if (permissions.startsWith('l')) {
          // Name format for links: "linkname -> target"
          final linkParts = name.split(' -> ');
          if (linkParts.isNotEmpty) {
            name = linkParts[0];
            // We assume links might be directories to allow navigation (e.g., /sdcard)
            // A more robust way would be `[ -d "$path/$name" ]` but that's an extra command.
            // For now, let's treat all symlinks as navigable in the browser.
            isDirectory = true;
          }
        }

        items.add(FileItem(
          name: name,
          path: '$path/$name',
          isDirectory: isDirectory,
        ));
      }
      return items;
    } catch (e) {
      print('List directory failed: $e');
      rethrow; // Rethrow to allow UI to handle error
    }
  }

  /// Read file content
  Future<String?> readFile(String path) async {
    try {
      return await _exec('cat "$path"');
    } catch (e) {
      print('Read file failed: $e');
      return null;
    }
  }

  /// Write file content
  Future<bool> writeFile(String path, String content) async {
    try {
      // Escape special characters for shell
      final escaped = content
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\$', '\\\$')
          .replaceAll('`', '\\`');

      await _exec('echo "$escaped" > "$path"');
      return true;
    } catch (e) {
      return false;
    }
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
  final ssh = ref.watch(sshServiceProvider);
  return FileOperations(ssh);
});

/// Current Directory Notifier
class CurrentDirectoryNotifier extends Notifier<String> {
  @override
  String build() => '/data/data/com.termux/files/home';

  void setPath(String path) => state = path;
}

/// Current Directory Provider
final currentDirectoryProvider =
    NotifierProvider<CurrentDirectoryNotifier, String>(
  CurrentDirectoryNotifier.new,
);

/// Directory Contents Provider
final directoryContentsProvider =
    FutureProvider.family<List<FileItem>, String>((ref, path) async {
  final ops = ref.watch(fileOperationsProvider);
  return ops.listDirectory(path);
});
