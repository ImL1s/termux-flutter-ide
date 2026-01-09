import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartssh2/dartssh2.dart';
import '../termux/ssh_service.dart';
import '../termux/termux_bridge.dart';
import '../termux/termux_providers.dart';

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

/// Abstract File Operations Interface
abstract class FileOperations {
  Future<bool> exists(String path);
  Future<bool> isDirectory(String path);
  Future<bool> createFile(String path);
  Future<bool> createDirectory(String path);
  Future<bool> rename(String oldPath, String newPath);
  Future<bool> deleteFile(String path);
  Future<bool> deleteDirectory(String path);
  Future<List<FileItem>> listDirectory(String path);
  Future<String?> readFile(String path);
  Future<bool> writeFile(String path, String content);
  Future<bool> createFlutterProject(String parentDir, String name,
      {String? org});
  Future<({bool success, String? error})> createFlutterProjectWithError(
      String parentDir, String name,
      {String? org});
}

/// SSH Implementation of FileOperations
class SshFileOperations implements FileOperations {
  final SSHService _ssh;

  SshFileOperations(this._ssh);

  Future<String> _exec(String cmd) async {
    if (!_ssh.isConnected) {
      try {
        await _ssh.connect();
      } catch (e) {
        throw Exception("Failed to connect to Termux: $e");
      }
    }
    // Use multiple potential paths for flutter to ensure it's found in different installation methods
    // /usr/bin is for .deb (system), ~/flutter/bin is for manual install
    const systemPath = '/data/data/com.termux/files/usr/bin';
    const userPath = '/data/data/com.termux/files/home/flutter/bin';

    // We source the flutter profile if it exists, and prepend common paths to PATH
    final cmdWithEnv =
        'source /data/data/com.termux/files/usr/etc/profile.d/flutter.sh 2>/dev/null; '
        'export PATH=$systemPath:$userPath:\$PATH; $cmd';
    return await _ssh.execute(cmdWithEnv);
  }

  /// Check if path exists
  @override
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
  @override
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
  @override
  Future<bool> createFile(String path) async {
    try {
      await _exec('touch "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create a new directory
  @override
  Future<bool> createDirectory(String path) async {
    try {
      await _exec('mkdir -p "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Rename/move a file or directory
  @override
  Future<bool> rename(String oldPath, String newPath) async {
    try {
      await _exec('mv "$oldPath" "$newPath"');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a file
  @override
  Future<bool> deleteFile(String path) async {
    try {
      await _exec('rm "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a directory (recursive)
  @override
  Future<bool> deleteDirectory(String path) async {
    try {
      await _exec('rm -rf "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
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
  @override
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
  @override
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
  @override
  Future<bool> createFlutterProject(String parentDir, String name,
      {String? org}) async {
    final result =
        await createFlutterProjectWithError(parentDir, name, org: org);
    return result.success;
  }

  /// Create a new Flutter project with detailed error information
  @override
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

/// Bridge Implementation of FileOperations (uses TermuxBridge instead of SSH)
class BridgeFileOperations implements FileOperations {
  final TermuxBridge _bridge;

  BridgeFileOperations(this._bridge);

  Future<String> _exec(String cmd) async {
    final result = await _bridge.executeCommand(cmd);
    if (!result.success && result.stderr.isNotEmpty) {
      throw Exception(result.stderr);
    }
    return result.stdout;
  }

  @override
  Future<bool> exists(String path) async {
    try {
      final result =
          await _exec('[ -e "$path" ] && echo "exists" || echo "not found"');
      return result.trim() == "exists";
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isDirectory(String path) async {
    try {
      final result =
          await _exec('[ -d "$path" ] && echo "dir" || echo "not dir"');
      return result.trim() == "dir";
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> createFile(String path) async {
    try {
      await _exec('touch "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> createDirectory(String path) async {
    try {
      await _exec('mkdir -p "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> rename(String oldPath, String newPath) async {
    try {
      await _exec('mv "$oldPath" "$newPath"');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteFile(String path) async {
    try {
      await _exec('rm "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteDirectory(String path) async {
    try {
      await _exec('rm -rf "$path"');
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<FileItem>> listDirectory(String path) async {
    try {
      final stdout = await _exec('ls -la "$path"');
      print('BridgeFileOperations: ls -la "$path" result:\n$stdout');
      final lines = stdout.split('\n');
      final items = <FileItem>[];

      for (final line in lines) {
        if (line.isEmpty || line.startsWith('total')) continue;

        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 9) continue;

        final permissions = parts[0];
        String name = parts.sublist(8).join(' ');

        if (name == '.' || name == '..') continue;

        bool isDirectory = permissions.startsWith('d');

        if (permissions.startsWith('l')) {
          final linkParts = name.split(' -> ');
          if (linkParts.isNotEmpty) {
            name = linkParts[0];
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
      print('BridgeFileOperations: List directory failed: $e');
      rethrow;
    }
  }

  @override
  Future<String?> readFile(String path) async {
    try {
      // Use a marker approach to ensure we can detect successful empty files vs failures
      // cmd: if file exists, output marker + content + marker, else output error marker
      final cmd = '[ -f "$path" ] && { echo "__FILE_START__"; cat "$path"; echo "__FILE_END__"; } || echo "__FILE_NOT_FOUND__"';
      final result = await _bridge.executeCommand(cmd);
      
      print('BridgeFileOperations.readFile: exitCode=${result.exitCode}, stdout=[${result.stdout}], stderr=[${result.stderr}]');
      
      final output = result.stdout;
      
      if (output.contains('__FILE_NOT_FOUND__')) {
        print('BridgeFileOperations: File not found: $path');
        return null;
      }
      
      if (output.contains('__FILE_START__') && output.contains('__FILE_END__')) {
        // Extract content between markers
        final start = output.indexOf('__FILE_START__') + '__FILE_START__'.length;
        final end = output.lastIndexOf('__FILE_END__');
        if (start < end) {
          final content = output.substring(start, end).trim();
          return content;
        }
      }
      
      // Fallback: if markers not found but output is not empty, assume it's the content
      if (output.isNotEmpty) {
        return output.trim();
      }
      
      print('BridgeFileOperations: Read file returned empty output');
      return null;
    } catch (e) {
      print('BridgeFileOperations: Read file failed: $e');
      return null;
    }
  }

  @override
  Future<bool> writeFile(String path, String content) async {
    try {
      // Use printf to handle special characters, escape single quotes
      final escaped = content.replaceAll("'", "'\\''");
      await _exec("printf '%s' '$escaped' > \"$path\"");
      return true;
    } catch (e) {
      print('BridgeFileOperations: Write file failed: $e');
      return false;
    }
  }

  @override
  Future<bool> createFlutterProject(String parentDir, String name,
      {String? org}) async {
    final result =
        await createFlutterProjectWithError(parentDir, name, org: org);
    return result.success;
  }

  @override
  Future<({bool success, String? error})> createFlutterProjectWithError(
      String parentDir, String name,
      {String? org}) async {
    try {
      final orgArg = org != null && org.isNotEmpty ? '--org "$org"' : '';
      // Source flutter profile to ensure PATH is correct
      // Export PATH to include Flutter binary location directly
      final envSetup = 'export PATH=/data/data/com.termux/files/usr/opt/flutter/bin:/data/data/com.termux/files/home/flutter/bin:\$PATH';
      final cmd = 'cd "$parentDir" && $envSetup && flutter create $orgArg "$name"';
      print('BridgeFileOperations: Executing $cmd');
      final result = await _exec(cmd);
      print('BridgeFileOperations: Create result: $result');

      if (result.contains('All done!') || result.contains('wrote')) {
        return (success: true, error: null);
      }

      if (result.toLowerCase().contains('command not found') ||
          result.toLowerCase().contains('no such file')) {
        return (success: false, error: result);
      }

      return (success: true, error: null);
    } catch (e) {
      print('BridgeFileOperations: Create Flutter project failed: $e');
      return (success: false, error: e.toString());
    }
  }
}

/// File Operations Provider - Uses Bridge by default (no SSH required)
final fileOperationsProvider = Provider<FileOperations>((ref) {
  // Use BridgeFileOperations as the default - works without SSH
  final bridge = ref.watch(termuxBridgeProvider);
  return BridgeFileOperations(bridge);
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
