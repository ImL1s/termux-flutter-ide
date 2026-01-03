import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/editor_page.dart';
import 'package:termux_flutter_ide/editor/code_editor_widget.dart';
import 'package:termux_flutter_ide/file_manager/file_operations.dart';
import 'package:termux_flutter_ide/core/providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E: Editor Edit and Run flow', (tester) async {
    final projectPath = '/home/test_project';
    final testFile = FileItem(
      name: 'main.dart',
      path: '$projectPath/lib/main.dart',
      isDirectory: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectPathProvider.overrideWith(
            () => TestProjectPathNotifier(projectPath),
          ),
          // Mock file reading
          fileOperationsProvider.overrideWithValue(MockFileOps()),
          // Open the test file by default
          openFilesProvider.overrideWith(
            () => TestOpenFilesNotifier([testFile.path]),
          ),
          currentFileProvider.overrideWith(
            () => TestCurrentFileNotifier(testFile.path),
          ),
        ],
        child: const MaterialApp(home: EditorPage()),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Editor is open with the file
    expect(find.byType(CodeEditorWidget), findsOneWidget);
    expect(find.text('main.dart'), findsAtLeastNWidgets(1));

    // 2. Perform Save
    // We can find the Save icon in the AppBar/Toolbar
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();

    // 3. Trigger Run
    // Find the 'Run' button (usually an icon or text in the app bar)
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    // Verify Runner Panel appears (usually a modal or bottom sheet)
    expect(find.text('FLUTTER RUNNER'), findsWidgets);
  });
}

class MockFileOps extends Fake implements FileOperations {
  @override
  Future<String?> readFile(String path) async =>
      "void main() { print('hello'); }";
  @override
  Future<bool> writeFile(String path, String content) async => true;
}

class TestProjectPathNotifier extends ProjectPathNotifier {
  final String? initial;
  TestProjectPathNotifier(this.initial);
  @override
  String? build() => initial;
}

class TestOpenFilesNotifier extends OpenFilesNotifier {
  final List<String> initial;
  TestOpenFilesNotifier(this.initial);
  @override
  List<String> build() => initial;
}

class TestCurrentFileNotifier extends CurrentFileNotifier {
  final String? initial;
  TestCurrentFileNotifier(this.initial);
  @override
  String? build() => initial;
}
