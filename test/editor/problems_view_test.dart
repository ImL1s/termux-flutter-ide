import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/problems_view.dart';
import 'package:termux_flutter_ide/editor/diagnostics_provider.dart';

void main() {
  testWidgets('ProblemsView shows "No problems" when empty', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ProblemsView()),
        ),
      ),
    );

    expect(find.text('No problems detected'), findsOneWidget);
  });

  testWidgets('ProblemsView groups diagnostics by file', (tester) async {
    final diagnostic1 = const LspDiagnostic(
      message: 'Unused variable',
      range: LspRange(startLine: 1, startColumn: 0, endLine: 1, endColumn: 5),
      severity: DiagnosticSeverity.warning,
      source: 'dart_analyzer',
      code: 'unused_local_variable',
    );

    final diagnostic2 = const LspDiagnostic(
      message: 'Syntax error',
      range: LspRange(startLine: 10, startColumn: 2, endLine: 10, endColumn: 3),
      severity: DiagnosticSeverity.error,
      source: 'dart_analyzer',
      code: 'syntax_error',
    );

    // Mock state
    final diagnostics = DiagnosticsState(
      fileDiagnostics: {
        'file:///src/main.dart': [diagnostic1],
        'file:///src/utils.dart': [diagnostic2],
      },
      // allDiagnostics is computed getter, no need to mock if fileDiagnostics is set
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosticsProvider
              .overrideWith(() => MockDiagnosticsNotifier(diagnostics)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProblemsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check file headers
    expect(find.text('main.dart (1)'), findsOneWidget);
    expect(find.text('utils.dart (1)'), findsOneWidget);

    // Check messages
    expect(find.text('Unused variable'), findsOneWidget);
    expect(find.text('Syntax error'), findsOneWidget);

    // Check severity icons (Error = Red, Warning = Orange)
    // Finding by IconData is standard
    expect(find.byIcon(Icons.error), findsOneWidget);
    expect(find.byIcon(Icons.warning), findsOneWidget);
  });
}

class MockDiagnosticsNotifier extends DiagnosticsNotifier {
  final DiagnosticsState initialState;
  MockDiagnosticsNotifier(this.initialState);

  @override
  DiagnosticsState build() {
    return initialState;
  }
}
