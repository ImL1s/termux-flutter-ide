import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E: Open Folder and Run Project', (WidgetTester tester) async {
    // 1. Load the App
    // We use UncontrolledProviderScope to mimic main.dart behavior if needed,
    // or just ProviderScope if main.dart uses it.
    // MyApp() in main.dart already wraps in ProviderScope? Check main.dart.
    // Assuming MyApp() is the root widget.

    await tester.pumpWidget(const ProviderScope(child: TermuxFlutterIDE()));

    // Force mobile size to ensure Drawer logic works
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    // Reset view after test
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpAndSettle();

    // 2. Open Drawer
    print('Tap Drawer Menu');
    final drawerBtn = find.byKey(const Key('main_drawer_button'));
    expect(drawerBtn, findsOneWidget);
    await tester.tap(drawerBtn);
    await tester.pumpAndSettle();

    // 3. Tap "Open Folder"
    print('Tap Open Folder');
    final openFolderBtn = find.byKey(const Key('drawer_open_folder'));
    expect(openFolderBtn, findsOneWidget);
    await tester.tap(openFolderBtn);
    await tester.pumpAndSettle();

    // 4. Select "verify_app" folder
    // Note: This assumes verify_app exists in the current directory list.
    // If it's a subfolder, we might need navigation logic.
    // Based on screenshots, verify_app is in HOME.
    print('Select verify_app');
    final verifyAppItem = find.byKey(const Key('folder_item_verify_app'));

    // Fallback: If not found, maybe we need to scroll or wait.
    // For now, fail if not found to verify environment.
    if (errorMessage('verify_app not found') != null) {
      // Just print, the expect will fail.
    }
    expect(verifyAppItem, findsOneWidget,
        reason: 'verify_app folder should be visible');
    await tester.tap(verifyAppItem);
    await tester.pumpAndSettle();

    // 5. Confirm Selection
    print('Tap Select This Folder');
    final selectBtn = find.byKey(const Key('directory_browser_select'));
    expect(selectBtn, findsOneWidget);
    await tester.tap(selectBtn);
    await tester.pumpAndSettle();

    // 6. Verify Project Title in AppBar
    print('Verify Project Loaded');
    expect(find.text('verify_app - Termux IDE'), findsOneWidget);

    // 7. Open Run Panel
    // 7. Open Run Panel via Drawer (More reliable)
    print('Open Drawer again');
    final drawerBtn2 = find.byKey(const Key('main_drawer_button'));
    await tester.ensureVisible(drawerBtn2);
    await tester.tap(drawerBtn2);
    await tester.pumpAndSettle();

    print('Tap Run Project in Drawer');
    final runProjectItem = find.byKey(const Key('drawer_run_project'));
    expect(runProjectItem, findsOneWidget,
        reason: 'Run Project item should be visible in drawer');
    await tester.tap(runProjectItem);
    await tester.pumpAndSettle();

    // 8. Start Execution (Center Button)
    print('Tap Center Run Button');
    final centerRunBtn = find.byKey(const Key('run_app_center_button'));
    // If center button is not there, maybe we are already running?
    // Or maybe the small button is there.
    if (centerRunBtn.evaluate().isNotEmpty) {
      await tester.tap(centerRunBtn);
    } else {
      // Try small button
      final smallRunBtn = find.byKey(const Key('run_app_button'));
      expect(smallRunBtn, findsOneWidget, reason: 'Run button must be visible');
      await tester.tap(smallRunBtn);
    }
    await tester.pump(); // Start animation

    // 9. Verify Terminal/Logs appear
    // Wait for a bit for logs to start
    await Future.delayed(const Duration(seconds: 2));
    await tester.pump();

    print('Verify Terminal View is visible');
    final terminalView = find.byKey(const Key('runner_terminal_view'));
    expect(terminalView, findsOneWidget);
  });
}

String? errorMessage(String s) => null; // Helper
