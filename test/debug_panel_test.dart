import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/debug_panel_widget.dart';

// Mock/Fake VMServiceManager could be complex, but for disconnected UI we might not need it
// if the default provider state is clean.
// However, vmServiceStatusProvider reads from Manager.
// We can override vmServiceStatusProvider directly.

void main() {
  testWidgets(
      'DebugPanelWidget displays all sections and controls in disconnected state',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DebugPanelWidget(),
          ),
        ),
      ),
    );

    // Verify Headers
    expect(find.text('VARIABLES'), findsOneWidget);
    expect(find.text('CALL STACK'), findsOneWidget);
    expect(find.text('BREAKPOINTS'), findsOneWidget);

    // Verify Controls (Icons)
    // Pause button (disconnected -> disabled, but icon should be there)
    // Actually, logic says:
    // icon: isPaused ? Icons.play_arrow : Icons.pause
    // color: isPaused ? ... : ...
    // onPressed: isConnected ? ... : null

    // Status default is disconnected. So isPaused = false. Icon = pause.
    expect(find.byIcon(Icons.pause), findsOneWidget);

    // Step buttons
    expect(find.byIcon(Icons.redo), findsOneWidget); // Step Over
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget); // Step Into
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget); // Step Out
    expect(find.byIcon(Icons.stop), findsOneWidget); // Stop

    // Verify Input
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Evaluate expression...'), findsOneWidget);

    // Verify Empty States
    expect(find.text('No variables'), findsOneWidget);
    expect(find.text('No call stack'), findsOneWidget);
    expect(find.text('No breakpoints'), findsOneWidget);
  });
}
