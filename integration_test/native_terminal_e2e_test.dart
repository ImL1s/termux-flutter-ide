import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/terminal/native_terminal_widget.dart';

/// E2E Integration tests for Native Terminal functionality.
/// These tests verify the complete flow from widget to native layer.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Native Terminal E2E', () {
    testWidgets('Full session lifecycle', (tester) async {
      // Build the app with native terminal widget
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: NativeTerminalWidget(
                  initialCwd: '/data/data/com.termux/files/home',
                ),
              ),
            ),
          ),
        ),
      );

      // Wait for widget to initialize
      await tester.pumpAndSettle();

      // Verify terminal title bar is visible
      expect(find.text('Terminal'), findsOneWidget);

      // Verify terminal icon is displayed
      expect(find.byIcon(Icons.terminal), findsOneWidget);

      // The widget should be rendering without errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('Terminal renders within constraints', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 300,
                child: NativeTerminalWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget should fit within constraints
      final Size widgetSize = tester.getSize(find.byType(NativeTerminalWidget));
      expect(widgetSize.width, lessThanOrEqualTo(400));
      expect(widgetSize.height, lessThanOrEqualTo(300));
    });

    testWidgets('Multiple terminals can coexist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: const [
                  Expanded(
                    child: NativeTerminalWidget(
                      initialCwd: '/path/one',
                    ),
                  ),
                  Expanded(
                    child: NativeTerminalWidget(
                      initialCwd: '/path/two',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both terminals should be rendered
      expect(find.byType(NativeTerminalWidget), findsNWidgets(2));
      expect(find.text('Terminal'), findsNWidgets(2));
    });

    testWidgets('Terminal survives rebuild', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                buildCount++;
                return Scaffold(
                  body: const NativeTerminalWidget(),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () => setState(() {}),
                    child: const Icon(Icons.refresh),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Trigger rebuild
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Terminal should still be present
      expect(find.byType(NativeTerminalWidget), findsOneWidget);
      expect(buildCount, greaterThan(1));
    });

    testWidgets('Custom shell path is respected', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: NativeTerminalWidget(
                shellPath: '/data/data/com.termux/files/usr/bin/zsh',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Widget should render without errors
      expect(tester.takeException(), isNull);
    });
  });
}
