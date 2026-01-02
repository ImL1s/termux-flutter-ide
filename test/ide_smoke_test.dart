import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/editor_page.dart';
import 'package:termux_flutter_ide/editor/code_editor_widget.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';

void main() {
  testWidgets('IDE Smoke Test - Verify Phase 9 Features in Widget Environment',
      (tester) async {
    // Set screen size to known Mobile Portrait
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    // Pump EditorPage directly
    // Mock Setup Wizard checks with Providers
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          termuxInstalledProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(
          home: EditorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Test Breadcrumb Bar (P1)
    expect(find.byType(CodeEditorWidget), findsOneWidget);

    // 3. Test Command Palette (P1) - Mobile usually has AppBar action or Drawer
    // Mobile AppBar has 'Run' action. Let's find AppBar.
    expect(find.byType(AppBar), findsOneWidget);

    // 4. Test Problems Tab Badge (P9) and Terminal (P9)
    // In Mobile, these are in the Bottom Sheet via BottomNavBar.

    // Tap 'Terminal' in BottomNavigationBar
    // Using text because Icon might be used in multiple places
    await tester.tap(find.text('Terminal'));
    await tester.pumpAndSettle(); // Wait for ModalBottomSheet

    // Verify TabBar with 'TERMINAL' and 'PROBLEMS' exists
    expect(find.text('TERMINAL'), findsOneWidget);
    expect(find.text('PROBLEMS'), findsOneWidget);

    // Switch to Problems Tab
    await tester.tap(find.text('PROBLEMS'));
    await tester.pumpAndSettle();

    // Switch back to Terminal for auto-scroll check
    await tester.tap(find.text('TERMINAL'));
    await tester.pumpAndSettle();

    // 5. Test Terminal Auto-Scroll Toggle (P9)
    // Should be visible in the Terminal tab content (or header?)
    // In our implementation, the toggle is inside TerminalWidget header/tab bar?
    // Let's verify.
    expect(find.byIcon(Icons.vertical_align_bottom), findsOneWidget);

    // Toggle it
    await tester.tap(find.byIcon(Icons.vertical_align_bottom));
    await tester.pump();

    // Should change to Pause icon
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // Toggle back
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(find.byIcon(Icons.vertical_align_bottom), findsOneWidget);

    // Close the Terminal modal to return to main screen
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();

    // 6. Phase 10: Git Branch Management - Verify Drawer access
    // Open the drawer to access Git functionality
    await tester.tap(find.byKey(const Key('main_drawer_button')));
    await tester.pumpAndSettle();

    // Verify Source Control option exists in drawer
    expect(find.text('Source Control'), findsOneWidget);
  });
}
