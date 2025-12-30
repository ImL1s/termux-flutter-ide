import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/file_manager/file_operations.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';

// MockTermuxBridge for testing
class MockTermuxBridge {
  final Map<String, TermuxResult> _responses = {};
  final List<String> executedCommands = [];

  void setResponse(String commandPattern, TermuxResult result) {
    _responses[commandPattern] = result;
  }

  Future<TermuxResult> executeCommand(
    String command, {
    String? workingDirectory,
    bool background = false,
  }) async {
    executedCommands.add(command);

    for (final pattern in _responses.keys) {
      if (command.contains(pattern)) {
        return _responses[pattern]!;
      }
    }

    return TermuxResult(
      success: true,
      exitCode: 0,
      stdout: '',
      stderr: '',
    );
  }
}

// Testable FileOperations that accepts any bridge-like object
class TestableFileOperations {
  final MockTermuxBridge _bridge;

  TestableFileOperations(this._bridge);

  Future<bool> createFile(String path) async {
    final result = await _bridge.executeCommand('touch "$path"');
    return result.success;
  }

  Future<bool> createDirectory(String path) async {
    final result = await _bridge.executeCommand('mkdir -p "$path"');
    return result.success;
  }

  Future<bool> rename(String oldPath, String newPath) async {
    final result = await _bridge.executeCommand('mv "$oldPath" "$newPath"');
    return result.success;
  }

  Future<bool> deleteFile(String path) async {
    final result = await _bridge.executeCommand('rm "$path"');
    return result.success;
  }

  Future<bool> deleteDirectory(String path) async {
    final result = await _bridge.executeCommand('rm -rf "$path"');
    return result.success;
  }

  Future<String?> readFile(String path) async {
    final result = await _bridge.executeCommand('cat "$path"');
    if (result.success) {
      return result.stdout;
    }
    return null;
  }

  Future<bool> writeFile(String path, String content) async {
    final escaped = content
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\$', '\\\$')
        .replaceAll('`', '\\`');
    final result = await _bridge.executeCommand('echo "$escaped" > "$path"');
    return result.success;
  }

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
}

void main() {
  late MockTermuxBridge mockBridge;
  late TestableFileOperations fileOps;

  setUp(() {
    mockBridge = MockTermuxBridge();
    fileOps = TestableFileOperations(mockBridge);
  });

  group('FileOperations', () {
    test('createFile executes touch command', () async {
      final result = await fileOps.createFile('/path/to/file.txt');

      expect(result, isTrue);
      expect(mockBridge.executedCommands.last, 'touch "/path/to/file.txt"');
    });

    test('createDirectory executes mkdir -p command', () async {
      final result = await fileOps.createDirectory('/path/to/dir');

      expect(result, isTrue);
      expect(mockBridge.executedCommands.last, 'mkdir -p "/path/to/dir"');
    });

    test('rename executes mv command', () async {
      final result = await fileOps.rename('/old/path', '/new/path');

      expect(result, isTrue);
      expect(mockBridge.executedCommands.last, 'mv "/old/path" "/new/path"');
    });

    test('deleteFile executes rm command', () async {
      final result = await fileOps.deleteFile('/path/to/file.txt');

      expect(result, isTrue);
      expect(mockBridge.executedCommands.last, 'rm "/path/to/file.txt"');
    });

    test('deleteDirectory executes rm -rf command', () async {
      final result = await fileOps.deleteDirectory('/path/to/dir');

      expect(result, isTrue);
      expect(mockBridge.executedCommands.last, 'rm -rf "/path/to/dir"');
    });

    test('readFile returns content on success', () async {
      mockBridge.setResponse(
          'cat',
          TermuxResult(
            success: true,
            exitCode: 0,
            stdout: 'file content here',
            stderr: '',
          ));

      final content = await fileOps.readFile('/path/to/file.txt');

      expect(content, 'file content here');
      expect(mockBridge.executedCommands.last, 'cat "/path/to/file.txt"');
    });

    test('readFile returns null on failure', () async {
      mockBridge.setResponse(
          'cat',
          TermuxResult(
            success: false,
            exitCode: 1,
            stdout: '',
            stderr: 'No such file',
          ));

      final content = await fileOps.readFile('/nonexistent');

      expect(content, isNull);
    });

    test('writeFile escapes special characters', () async {
      await fileOps.writeFile('/path/file.txt', 'hello "world" \$var `cmd`');

      final cmd = mockBridge.executedCommands.last;
      expect(cmd, contains('echo'));
      expect(cmd, contains('> "/path/file.txt"'));
    });

    test('listDirectory parses ls -la output', () async {
      mockBridge.setResponse(
          'ls -la',
          TermuxResult(
            success: true,
            exitCode: 0,
            stdout: '''total 16
drwxr-xr-x  4 user group 4096 Dec 30 12:00 .
drwxr-xr-x  3 user group 4096 Dec 30 11:00 ..
-rw-r--r--  1 user group  100 Dec 30 12:00 file.txt
drwxr-xr-x  2 user group 4096 Dec 30 12:00 subdir''',
            stderr: '',
          ));

      final items = await fileOps.listDirectory('/test');

      expect(items.length, 2);
      expect(items[0].name, 'file.txt');
      expect(items[0].isDirectory, isFalse);
      expect(items[1].name, 'subdir');
      expect(items[1].isDirectory, isTrue);
    });

    test('listDirectory returns empty list on failure', () async {
      mockBridge.setResponse(
          'ls -la',
          TermuxResult(
            success: false,
            exitCode: 1,
            stdout: '',
            stderr: 'Permission denied',
          ));

      final items = await fileOps.listDirectory('/protected');

      expect(items, isEmpty);
    });
  });

  group('FileItem', () {
    test('stores correct properties', () {
      final item = FileItem(
        name: 'test.dart',
        path: '/path/to/test.dart',
        isDirectory: false,
      );

      expect(item.name, 'test.dart');
      expect(item.path, '/path/to/test.dart');
      expect(item.isDirectory, isFalse);
    });
  });
}
