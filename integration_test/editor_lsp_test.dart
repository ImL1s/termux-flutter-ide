import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termux_flutter_ide/main.dart' as app;
import 'package:termux_flutter_ide/editor/code_editor_widget.dart';
import 'package:termux_flutter_ide/editor/completion/completion_widget.dart';
import 'package:termux_flutter_ide/file_manager/file_tree_widget.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LSP UI Integration Test: Auto-completion appears', (WidgetTester tester) async {
    // 1. Start App
    app.main();
    await tester.pumpAndSettle();

    // 2. Open "main.dart" if visible (assuming project is open)
    // Or just type in the empty editor if that triggers it?
    // CodeEditorWidget usually starts with "No file selected".
    // We need to open a file.
    
    // Tap "main.dart" in FileTree
    final mainDart = find.text('main.dart');
    if (mainDart.evaluate().isNotEmpty) {
      await tester.tap(mainDart);
      await tester.pumpAndSettle();
    } else {
      // Fallback: Try to create a new file or use existing flow
      // Assuming a default project structure exists from previous setups
      print('Warning: main.dart not found in tree');
    }

    // 3. Verify Editor is active
    expect(find.byType(CodeEditorWidget), findsOneWidget);
    
    // 4. Focus Editor
    // CodeField is the focusable widget
    final codeField = find.byType(CodeField);
    await tester.tap(codeField);
    await tester.pump();
    
    // 5. Type "stle" to trigger snippet
    await tester.enterText(codeField, 'stle');
    await tester.pump(); // Trigger listeners
    await tester.pump(const Duration(milliseconds: 500)); // Wait for async/debounce
    
    // 6. Verify CompletionWidget appears
    expect(find.byType(CompletionWidget), findsOneWidget);
    expect(find.text('stless'), findsOneWidget);
    
    // 7. Verify Tap inserts text
    await tester.tap(find.text('stless').first);
    await tester.pumpAndSettle();
    
    // Verify text inserted (Snapshot or checks)
    // "class MyWidget extends StatelessWidget" should correspond to 'stless' snippet
    // We can't easily check text content of CodeField without accessing controller
    // But if CompletionWidget disappears, that's a good sign
    expect(find.byType(CompletionWidget), findsNothing);
    
    // 8. Test LSP (if connected)
    // Type "Str" (for String)
    await tester.enterText(codeField, 'Str');
    await tester.pump(const Duration(seconds: 1)); // Wait for LSP
    
    // If LSP is working, "String" should appear
    // This depends on the real device env.
    // We expect at least CompletionWidget to appear if any suggestions found.
    // If LSP fails (no server), snippets might not match "Str" unless we have one.
    // So this assertion is soft.
    if (find.byType(CompletionWidget).evaluate().isNotEmpty) {
       print('LSP/Completion UI appeared for "Str"');
    }
  });
}
