import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termux_flutter_ide/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Verify Flutter Project Creation and Run UI',
      (WidgetTester tester) async {
    // 1. Start the App
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Allow time for SSH connect and setup check
    // If the app is in Setup mode, we might need to navigate through it.
    // Assuming the environment is already set up (based on recent conversation),
    // it should go to EditorPage.

    // Check if we are on Editor Page
    // Mobile title might be "Termux IDE" or "ProjectName - Termux IDE"
    expect(find.textContaining('Termux IDE'), findsOneWidget);

    // 2. Open Menu
    // Look for the Menu button (Icon(Icons.menu))
    final menuButton = find.byIcon(Icons.menu);
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Now Explorer should be visible in Drawer
    expect(find.text('Explorer'), findsOneWidget);

    // 3. Verify "New Flutter Project" button exists
    final newProjectBtn = find.text('New Flutter Project');
    expect(newProjectBtn, findsOneWidget);

    // 4. Tap "New Flutter Project"
    await tester.tap(newProjectBtn);
    await tester.pumpAndSettle();

    // 5. Verify Dialog appears
    expect(find.text('創建新 Flutter 專案'), findsOneWidget);
    expect(find.text('開始創建'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // 6. Enter Project Name
    await tester.enterText(find.widgetWithText(TextField, ''), 'test_e2e_app');
    // Note: Finding TextField might be tricky if no label, but typically verified by 'widgetWithText' or type.
    // Let's assume the first TextField is project name.

    // 7. Close Dialog (Cancel to avoid polluting real env too much in this specific test run,
    //    or we could proceed. Let's Cancel for UI verification first).
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // 8. Verify Run Functionality UI
    // Open Menu again
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Find Run Project
    final runProjectBtn = find.text('Run Project');
    expect(runProjectBtn, findsOneWidget);

    // Note: Tapping Run Project might not do anything if no project is open/selected,
    // or might trigger a pick.
    // For now, verifying the UI existence is a good step 0 of E2E.
  });
}
