import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/analyzer/analysis_dashboard.dart';
import 'package:termux_flutter_ide/analyzer/analyzer_service.dart';
import 'package:termux_flutter_ide/analyzer/analyzer_models.dart';

void main() {
  testWidgets('AnalysisDashboard shows empty state when no report',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analysisReportProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: Scaffold(body: AnalysisDashboard())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Open a project to see analysis'), findsOneWidget);
  });

  testWidgets('AnalysisDashboard shows loading state', (tester) async {
    final completer = Completer<AnalysisReport?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analysisReportProvider.overrideWith((ref) => completer.future),
        ],
        child: const MaterialApp(home: Scaffold(body: AnalysisDashboard())),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('AnalysisDashboard renders report data correctly',
      (tester) async {
    final mockReport = AnalysisReport(
      timestamp: DateTime.now(),
      totalLoc: 1234,
      maintainabilityScore: 92.5,
      topComplexFiles: [
        FileMetric(
            path: 'lib/main.dart',
            loc: 100,
            methodCount: 5,
            averageComplexity: 12),
      ],
      totalWarnings: 3,
      totalTodos: 5,
    );

    // Set a larger surface size to ensure everything is visible without scrolling
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analysisReportProvider.overrideWith((ref) async => mockReport),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 1200,
              child: AnalysisDashboard(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Score
    expect(find.text('93%'), findsOneWidget);
    expect(find.text('Maintainability Score'), findsOneWidget);

    // Verify Stats
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    // Check for the filename 'main.dart'
    // It should be there as metric.path.split('/').last
    expect(find.text('main.dart'), findsWidgets);
    expect(find.text('C: 12'), findsOneWidget);

    // reset view
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
