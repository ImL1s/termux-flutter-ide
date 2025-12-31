import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartssh2/dartssh2.dart';
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
    // Use absolute path for flutter to bypass environment issues in non-interactive SSH
    const flutterPath = '/data/data/com.termux/files/home/flutter/bin';
    final cmdWithEnv = 'export PATH=\$PATH:$flutterPath && $cmd';
    return await _ssh.execute(cmdWithEnv);
  }

  /// Check if path exists
  Future<bool> exists(String path) async {
    try {
      final result =
          await _exec('[ -e "$path" ] && echo "exists" || echo "not found"');
      return result.trim() == "exists";
    } catch (e) {
      return false;
    }
  }

  /// Check if path is directory
  Future<bool> isDirectory(String path) async {
    try {
      final result =
          await _exec('[ -d "$path" ] && echo "dir" || echo "not dir"');
      return result.trim() == "dir";
    } catch (e) {
      return false;
    }
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
      print('FileOperations: ls -la "$path" result:\n$stdout');
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

  /// Read file content via SFTP
  Future<String?> readFile(String path) async {
    try {
      if (!_ssh.isConnected) await _ssh.connect();
      final client = _ssh.client;
      if (client == null) throw Exception('SSH client not available');

      final sftp = await client.sftp();
      try {
        final file = await sftp.open(path);
        final content = await file.readBytes();
        return utf8.decode(content);
      } finally {
        sftp.close();
      }
    } catch (e) {
      print('Read file failed: $e');
      return null;
    }
  }

  /// Write file content via SFTP
  Future<bool> writeFile(String path, String content) async {
    try {
      if (!_ssh.isConnected) await _ssh.connect();
      final client = _ssh.client;
      if (client == null) throw Exception('SSH client not available');

      final sftp = await client.sftp();
      try {
        final file = await sftp.open(
          path,
          mode: SftpFileOpenMode.write |
              SftpFileOpenMode.create |
              SftpFileOpenMode.truncate,
        );
        await file.writeBytes(utf8.encode(content));
      } finally {
        sftp.close();
      }

      return true;
    } catch (e) {
      print('Write file failed: $e');
      return false;
    }
  }

  /// Create a new Flutter project
  Future<bool> createFlutterProject(String parentDir, String name,
      {String? org}) async {
    final result =
        await createFlutterProjectWithError(parentDir, name, org: org);
    return result.success;
  }

  /// Create a new Flutter project with detailed error information
  Future<({bool success, String? error})> createFlutterProjectWithError(
      String parentDir, String name,
      {String? org}) async {
    try {
      final orgArg = org != null && org.isNotEmpty ? '--org "$org"' : '';
      final cmd = 'cd "$parentDir" && flutter create $orgArg "$name"';
      print('FileOperations: Executing $cmd');
      final result = await _exec(cmd);
      print('FileOperations: Create result: $result');

      // Check if output indicates success (Flutter create outputs "All done!")
      if (result.contains('All done!') || result.contains('wrote')) {
        return (success: true, error: null);
      }

      // Check for common errors
      if (result.toLowerCase().contains('command not found') ||
          result.toLowerCase().contains('no such file')) {
        return (success: false, error: result);
      }

      // Assume success if no obvious error
      return (success: true, error: null);
    } catch (e) {
      print('Create Flutter project failed: $e');
      return (success: false, error: e.toString());
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
