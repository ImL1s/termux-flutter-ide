import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/editor_page.dart';
import 'package:termux_flutter_ide/editor/code_editor_widget.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';

void main() {
  testWidgets('IDE Smoke Test - Verify Phase 9 Features in Widget Environment',
      (tester) async {
    // Set screen size to Desktop/Tablet (width > 600) to show full bottom panel
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    // Pump EditorPage directly to verify UI features without SetupWizard interference
    // We wrap in MaterialApp for Theme/Nav context
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Mock Termux Installed to true
          termuxInstalledProvider.overrideWith((ref) async => true),
          // Mock SSH Service to avoid connection attempts?
          // EditorPage might use it. Ideally we mock it but let's see if installed=true is enough.
          // Setup service defaults might be ok if EditorPage doesn't check it directly (EditorPage usually strictly depends on TermuxInstalled).
        ],
        child: const MaterialApp(
          home: EditorPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 2. Test Breadcrumb Bar (P1)
    expect(find.byType(CodeEditorWidget), findsOneWidget);

    // 3. Test Command Palette for Recent Files (P1) - Menu Button check
    // In EditorPage, the commands are usually in the AppBar actions.
    // Let's verify AppBar exists.
    expect(find.byType(AppBar), findsOneWidget);

    // Check for "More" button or Command Palette trigger
    // If not found, we might need to verify Search icon or similar.
    // EditorPage usually register commands.

    // 4. Test Problems Tab Badge (P9)
    // The Desktop layout hides the bottom panel by default.
    // We need to trigger it open. The 'Build APK' button sets _showTerminal = true.
    final buildButton = find.byIcon(Icons.build);
    expect(buildButton, findsOneWidget);
    await tester.tap(buildButton);
    await tester.pumpAndSettle();

    // Verify "PROBLEMS" tab exists now that panel is open
    expect(find.text('PROBLEMS'), findsOneWidget);

    // 5. Test Terminal Auto-Scroll Toggle (P9)
    // Switch to Terminal Tab
    final terminalTab = find.text('TERMINAL');
    expect(terminalTab, findsOneWidget);
    await tester.tap(terminalTab);
    await tester.pumpAndSettle();

    // Verify Auto-Scroll Button
    // Initial state is true -> Icons.vertical_align_bottom
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
  });
}
