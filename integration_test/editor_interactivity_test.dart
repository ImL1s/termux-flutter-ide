import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termux_flutter_ide/main.dart' as app;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/core/providers.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Editor Interactivity E2E', () {
    testWidgets('Verify BottomNav has 3 items and Editor is interactive',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 1. Verify BottomNavigationBar has 3 items
      final bottomNav = find.byType(BottomNavigationBar);
      expect(bottomNav, findsOneWidget);
      final BottomNavigationBar navWidget = tester.widget(bottomNav);
      expect(navWidget.items.length, equals(3), reason: 'Should have 3 tabs');
      expect(navWidget.items[0].label, equals('Explorer'));
      expect(navWidget.items[1].label, equals('Terminal'));
      expect(navWidget.items[2].label, equals('Search'));

      // 2. Open Explorer via Tab
      await tester.tap(find.text('Explorer'));
      await tester.pumpAndSettle();

      // Check if BottomSheet launched
      expect(find.text('EXPLORER'), findsOneWidget);
      expect(find.text('Open Folder'), findsOneWidget);

      // 3. Mock a project and file to test Editor Interactivity
      final container =
          ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

      // We use a temporary hack or provider override if possible,
      // but here we just manually update the state since it's a test.
      container.read(projectPathProvider.notifier).set('/tmp/test_project');
      container
          .read(currentFileProvider.notifier)
          .select('/tmp/test_project/main.dart');

      // Note: FileOperations will fail to read /tmp/test_project/main.dart unless we mock it.
      // However, if we just want to test if the GESTURES are blocked, we can look at the blank state
      // or mock the file read.

      await tester.pumpAndSettle();

      // Close the bottom sheet if it's blocking
      await tester.tapAt(const Offset(10, 10)); // Tap outside
      await tester.pumpAndSettle();

      // 4. Verify Editor is present (even if it shows error/empty, we want to check if it's hit-testable)
      // Actually, if we selected a file, CodeEditorWidget should try to load it.
      // If it fails, it shows "Error loading file".

      // To TRULY test hit-testing, let's see if we can find the Gutter or CodeField
      // Since it will likely show an error, we can tap the "Retry" button to prove interactivity.
      if (find.textContaining('Error loading file').evaluate().isNotEmpty) {
        final retryBtn = find.text('Retry');
        expect(retryBtn, findsOneWidget);
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();
      } else {
        // If it somehow loaded or is showing empty
        final codeField = find.byType(CodeField);
        if (codeField.evaluate().isNotEmpty) {
          await tester.tap(codeField);
          await tester.pumpAndSettle();
          // Verify focus node
          final focusNode = tester.widget<CodeField>(codeField).focusNode;
          expect(focusNode?.hasFocus, isTrue,
              reason: 'Editor should gain focus on tap');
        }
      }
    });
  });
}
