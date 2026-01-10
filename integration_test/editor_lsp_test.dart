import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/code_editor_widget.dart';
import 'package:termux_flutter_ide/editor/completion/completion_widget.dart';
import 'package:termux_flutter_ide/services/lsp_service.dart';
import 'package:termux_flutter_ide/file_manager/file_operations.dart';
import 'package:termux_flutter_ide/core/providers.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:termux_flutter_ide/editor/diagnostics_provider.dart';
import 'package:termux_flutter_ide/editor/editor_page.dart';

// --- Mocks ---

class MockLspService extends Fake implements LspService {
  @override
  bool get isStarted => true;

  @override
  Future<bool> start(String projectPath) async {
    return true;
  }
  
  @override
  Future<void> stop() async {}

  @override
  Future<void> notifyDidOpen(String filePath, String content) async {}

  @override
  Future<void> notifyDidChange(String filePath, String content) async {}
  
  @override
  Future<String?> formatDocument(String filePath) async { return null; }
  
  @override
  Future<Map<String, dynamic>?> getDefinition(String filePath, int line, int column) async { return null; }

  @override
  Future<List<Map<String, dynamic>>?> getReferences(String filePath, int line, int column) async { return []; }
  
  @override
  Future<List<Map<String, dynamic>>> getCodeActions(String filePath, int line, int column, List<LspDiagnostic> diagnostics) async { return []; }
  
  @override
  Future<Map<String, dynamic>?> renameSymbol(String filePath, int line, int column, String newName) async { return null; }
  
  @override
  Future<List<Map<String, dynamic>>> workspaceSymbol(String query) async { return []; }

  @override
  Future<List<Map<String, dynamic>>> getCompletions(String filePath, int line, int column) async {
    print('MockLspService: getCompletions called for $filePath at $line:$column');
    return [
      {'label': 'MockLspItem', 'kind': 1, 'detail': 'Test Detail', 'insertText': 'MockLspItem'}
    ];
  }
}

class MockFileOperations extends Fake implements FileOperations {
  @override
  Future<String?> readFile(String path) async {
    // Return content for any file ending in main.dart
    if (path.endsWith('main.dart')) {
      return "void main() {\n  \n}";
    }
    return null;
  }

  @override
  Future<List<FileItem>> listDirectory(String path) async {
    if (path == '/mock_project') {
      return [
        FileItem(
          name: 'main.dart',
          path: '/mock_project/main.dart', 
          isDirectory: false
        )
      ];
    }
    return [];
  }
  
  @override
  Future<bool> exists(String path) async => true; // Assume files exist
  
  @override
  Future<bool> isDirectory(String path) async => false;
}

class MockProjectPathNotifier extends ProjectPathNotifier {
  @override
  String? build() => '/mock_project';
}

class MockCurrentFileNotifier extends CurrentFileNotifier {
  @override
  String? build() => '/mock_project/main.dart';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LSP UI Integration Test: Auto-completion appears (Mocked)', (WidgetTester tester) async {
    // 1. Pump App
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lspServiceProvider.overrideWith((ref) => MockLspService()),
          fileOperationsProvider.overrideWith((ref) => MockFileOperations()),
          projectPathProvider.overrideWith(() => MockProjectPathNotifier()),
          currentFileProvider.overrideWith(() => MockCurrentFileNotifier()),
        ],
        child: const MaterialApp(
          home: EditorPage(),
        ),
      ),
    );
    
    // Wait for app load
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Check if CodeEditorWidget is present
    expect(find.byType(CodeEditorWidget), findsOneWidget);

    print('CodeEditorWidget found. File should be loaded via MockCurrentFileNotifier.');

    // 4. Focus Editor
    final codeField = find.byType(CodeField);
    if (codeField.evaluate().isNotEmpty) {
      await tester.tap(codeField);
      await tester.pump();
      
      // 5. Type "Mock" to trigger LSP
      await tester.enterText(codeField, 'Mock');
      await tester.pump(); // Trigger listeners
      await tester.pump(const Duration(milliseconds: 500)); // Debounce
      
      // 6. Verify CompletionWidget appears
      expect(find.byType(CompletionWidget), findsOneWidget);
      
      // 7. Verify Mock Item exists (Use textContaining because RichText includes detail)
      expect(find.textContaining('MockLspItem'), findsOneWidget);
      expect(find.textContaining('Test Detail'), findsOneWidget);

      print('LSP Mock UI Verified Successfully');
    } else {
      print('CodeField not found. Editor might not have loaded the file.');
      debugDumpApp();
      fail('CodeField not found');
    }
  });
}
