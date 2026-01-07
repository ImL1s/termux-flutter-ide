import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/termux_bridge.dart';
import '../termux/termux_providers.dart';
import 'file_operations.dart';

/// Termux Bridge Implementation of FileOperations
///
/// This implementation relies on Android Intents (RunCommandService) via TermuxBridge.
/// It does NOT require an SSH connection.
class TermuxFileSystem implements FileOperations {
  final TermuxBridge _bridge;

  TermuxFileSystem(this._bridge);

  String _wrapCmd(String cmd) {
    const termuxPrefix = '/data/data/com.termux/files/usr';
    return 'export PATH=$termuxPrefix/bin:\$PATH; '
        'export LD_LIBRARY_PATH=$termuxPrefix/lib; '
        'export LC_ALL=C; $cmd';
  }

  Future<TermuxResult> _exec(String cmd, {bool background = false}) async {
    return _bridge.executeCommand(_wrapCmd(cmd), background: background);
  }

  @override
  Future<bool> exists(String path) async {
    try {
      final result = await _exec('[ -e "$path" ]', background: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isDirectory(String path) async {
    try {
      final result = await _exec('[ -d "$path" ]', background: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> createFile(String path) async {
    try {
      final result = await _exec('touch "$path"', background: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> createDirectory(String path) async {
    try {
      final result = await _exec('mkdir -p "$path"', background: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> rename(String oldPath, String newPath) async {
    try {
      final result = await _exec('mv "$oldPath" "$newPath"', background: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteFile(String path) async {
    try {
      final result = await _exec('rm "$path"', background: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteDirectory(String path) async {
    try {
      final result = await _exec('rm -rf "$path"', background: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<FileItem>> listDirectory(String path) async {
    try {
      // ls -la: detailed list, no fancy type suffixes (-F) to ensure compatibility
      final result = await _exec('ls -la "$path"', background: true);
      if (result.exitCode != 0) {
        throw Exception('List directory failed: ${result.stderr}');
      }

      final stdout = result.stdout;
      final lines = stdout.split('\n');
      final items = <FileItem>[];

      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith('total')) continue;

        // ls -la output format: drwx------ 2 u0_a257 u0_a257 4096 Jan 1 12:00 folder
        final parts = line.split(RegExp(r'\s+'));
        if (parts.length < 9) continue;

        // Name is usually the 9th part onwards
        String name = parts.sublist(8).join(' ');

        if (name == '.' || name == '..') continue;

        // specific check from permissions (drwx...)
        final permissions = parts[0];
        bool isDirectory = permissions.startsWith('d');

        // Handle symlinks
        if (permissions.startsWith('l')) {
          // For symlinks, ls -l outputs: link -> target
          // We need to parse out the real name.
          final arrowIndex = parts.indexOf('->', 8);
          if (arrowIndex != -1) {
            name = parts.sublist(8, arrowIndex).join(' ');
            // For now, treat symlinks as navigable directories
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
      rethrow;
    }
  }

  @override
  Future<String?> readFile(String path) async {
    try {
      // Use cat to read file string.
      // Warning: binary files might be corrupted or result in weird text.
      // Ideally use base64 for safety.
      final result = await _exec('cat "$path"', background: true);
      if (result.exitCode == 0) {
        return result.stdout;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> writeFile(String path, String content) async {
    try {
      // Use base64 to avoid special character issues in Intent extras
      final encoded = base64Encode(utf8.encode(content));
      // Decode and redirect to file
      final cmd = 'echo "$encoded" | base64 -d > "$path"';
      final result = await _exec(cmd, background: true);
      return result.exitCode == 0;
    } catch (e) {
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
      final cmd = 'cd "$parentDir" && flutter create $orgArg "$name"';
      final result = await _exec(cmd, background: true);

      // Check exit code directly
      if (result.exitCode == 0) {
        // Double check stdout just in case
        return (success: true, error: null);
      }

      return (
        success: false,
        error: result.stderr.isNotEmpty ? result.stderr : result.stdout
      );
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }
}

final termuxFileSystemProvider = Provider<TermuxFileSystem>((ref) {
  final bridge = ref.watch(termuxBridgeProvider);
  return TermuxFileSystem(bridge);
});
