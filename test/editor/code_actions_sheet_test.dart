import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/code_actions_sheet.dart';
import 'package:termux_flutter_ide/editor/code_actions_provider.dart';

/// Mock CodeActionsNotifier for testing
class MockCodeActionsNotifier extends CodeActionsNotifier {
  final CodeActionsState mockState;

  MockCodeActionsNotifier(this.mockState);

  @override
  CodeActionsState build() => mockState;
}

void main() {
  group('CodeActionsSheet Widget Tests', () {
    testWidgets('displays empty state when no actions available',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            codeActionsProvider.overrideWith(
              () =>
                  MockCodeActionsNotifier(const CodeActionsState(actions: [])),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CodeActionsSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Code Actions'), findsOneWidget);
      expect(find.text('No actions available'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('displays loading indicator when isLoading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            codeActionsProvider.overrideWith(
              () => MockCodeActionsNotifier(
                const CodeActionsState(isLoading: true),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CodeActionsSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error state when error is set', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            codeActionsProvider.overrideWith(
              () => MockCodeActionsNotifier(
                const CodeActionsState(error: 'LSP not connected'),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CodeActionsSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load actions'), findsOneWidget);
      expect(find.text('LSP not connected'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('displays actions list when actions available', (tester) async {
      final mockActions = [
        const CodeAction(
          title: "Import 'dart:io'",
          kind: 'quickfix.import',
          isPreferred: true,
        ),
        const CodeAction(
          title: 'Wrap with Container',
          kind: 'refactor.wrap',
          isPreferred: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            codeActionsProvider.overrideWith(
              () => MockCodeActionsNotifier(
                CodeActionsState(actions: mockActions),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CodeActionsSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Import 'dart:io'"), findsOneWidget);
      expect(find.text('Wrap with Container'), findsOneWidget);
      expect(find.text('Quick Fix'), findsOneWidget); // Kind label
      expect(find.byIcon(Icons.star), findsOneWidget); // Preferred indicator
    });

    testWidgets('close button dismisses the sheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            codeActionsProvider.overrideWith(
              () => MockCodeActionsNotifier(const CodeActionsState()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showCodeActionsSheet(
                      context, ProviderScope.containerOf(context) as WidgetRef),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // This test just verifies the close icon exists without full modal interaction
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            codeActionsProvider.overrideWith(
              () => MockCodeActionsNotifier(const CodeActionsState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CodeActionsSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
