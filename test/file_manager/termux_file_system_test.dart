import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:termux_flutter_ide/file_manager/termux_file_system.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';

@GenerateNiceMocks([MockSpec<TermuxBridge>()])
import 'termux_file_system_test.mocks.dart';

void main() {
  late TermuxFileSystem fileSystem;
  late MockTermuxBridge mockBridge;

  setUp(() {
    mockBridge = MockTermuxBridge();
    fileSystem = TermuxFileSystem(mockBridge);
  });

  group('TermuxFileSystem Command Construction', () {
    test('Cmd wrapper includes LD_LIBRARY_PATH and PATH', () async {
      when(mockBridge.executeCommand(any, background: anyNamed('background')))
          .thenAnswer((_) async =>
              TermuxResult(stdout: '', stderr: '', exitCode: 0, success: true));

      await fileSystem.exists('/test/path');

      final captured = verify(mockBridge.executeCommand(captureAny,
              background: anyNamed('background')))
          .captured;
      final cmd = captured.first as String;

      expect(cmd,
          contains('export PATH=/data/data/com.termux/files/usr/bin:\$PATH'));
      expect(
          cmd,
          contains(
              'export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib'));
      expect(cmd, contains('export LC_ALL=C'));
      expect(cmd, contains('[ -e "/test/path" ]'));
    });
  });

  group('TermuxFileSystem Parsing', () {
    test('listDirectory parses ls -la output correctly', () async {
      // Simulated ls -la output from Termux
      const lsOutput = '''
total 24
drwx------ 16 u0_a257 u0_a257 4096 Jan  3 12:00 .
drwx------ 16 u0_a257 u0_a257 4096 Jan  3 12:00 ..
-rw-------  1 u0_a257 u0_a257  123 Jan  3 12:01 file.txt
drwx------  2 u0_a257 u0_a257 4096 Jan  3 12:02 folder
lrwxrwxrwx  1 u0_a257 u0_a257   10 Jan  3 12:03 link -> /target
''';

      when(mockBridge.executeCommand(any, background: anyNamed('background')))
          .thenAnswer((_) async => TermuxResult(
              stdout: lsOutput, stderr: '', exitCode: 0, success: true));

      final items = await fileSystem.listDirectory('/home');

      expect(items.length, 3);

      // File
      expect(items[0].name, 'file.txt');
      expect(items[0].isDirectory, false);

      // Folder
      expect(items[1].name, 'folder');
      expect(items[1].isDirectory, true);

      // Symlink
      expect(items[2].name, 'link'); // Parsing should extract name before " ->"
      expect(items[2].isDirectory,
          true); // We assume links are dirs for navigation in current logic
    });

    test('listDirectory handles spaces in filenames', () async {
      const lsOutput = '''
total 8
-rw-------  1 user group  123 Jan  3 12:00 my cool file.txt
drwx------  2 user group 4096 Jan  3 12:00 my folder name
''';
      when(mockBridge.executeCommand(any, background: anyNamed('background')))
          .thenAnswer((_) async => TermuxResult(
              stdout: lsOutput, stderr: '', exitCode: 0, success: true));

      final items = await fileSystem.listDirectory('/home');

      expect(items.length, 2);
      expect(items[0].name, 'my cool file.txt');
      expect(items[0].isDirectory, false);

      expect(items[1].name, 'my folder name');
      expect(items[1].isDirectory, true);
    });

    test('listDirectory throws on non-zero exit code', () async {
      when(mockBridge.executeCommand(any, background: anyNamed('background')))
          .thenAnswer((_) async => TermuxResult(
              stdout: '',
              stderr: 'Permission denied',
              exitCode: 1,
              success: false));

      expect(() => fileSystem.listDirectory('/root'), throwsException);
    });
  });

  group('TermuxFileSystem Write', () {
    test('writeFile uses base64 encoding', () async {
      when(mockBridge.executeCommand(any, background: anyNamed('background')))
          .thenAnswer((_) async =>
              TermuxResult(stdout: '', stderr: '', exitCode: 0, success: true));

      const content = 'Hello World';
      await fileSystem.writeFile('/path/file.txt', content);

      final captured = verify(mockBridge.executeCommand(captureAny,
              background: anyNamed('background')))
          .captured;
      final cmd = captured.first as String;

      // Check for base64 decode command structure
      expect(cmd, contains('base64 -d > "/path/file.txt"'));
      // Check content is encoded (SGVsbG8gV29ybGQ= is Hello World)
      expect(cmd, contains('echo "SGVsbG8gV29ybGQ="'));
    });
  });
}
