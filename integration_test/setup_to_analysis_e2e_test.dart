import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/main.dart' as app;
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/analyzer/analyzer_models.dart';
import 'package:termux_flutter_ide/analyzer/analyzer_service.dart';

// Manual Mock for Bridge to skip real Termux calls
class MockBridge extends Fake implements TermuxBridge {
  @override
  Future<bool> isTermuxInstalled() async => true;
  @override
  Future<TermuxResult> executeCommand(String command,
          {String? workingDirectory, bool background = false}) async =>
      TermuxResult(success: true, exitCode: 0, stdout: 'success', stderr: '');
  @override
  Future<bool> openTermux() async => true;
  @override
  Future<TermuxResult> setupTermuxSSH() async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<int?> getTermuxUid() async => 10001;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E: Setup Wizard to Project Analysis Flow', (tester) async {
    final mockBridge = MockBridge();

    // Start the app with overrides
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          termuxBridgeProvider.overrideWithValue(mockBridge),
          // Ensure we start at the wizard
          sshStatusProvider
              .overrideWith((ref) => Stream.value(SSHStatus.disconnected)),
          // Mock some analysis data for later
          analysisReportProvider.overrideWith((ref) async => AnalysisReport(
                timestamp: DateTime.now(),
                totalLoc: 100,
                maintainabilityScore: 95,
                topComplexFiles: [],
                totalWarnings: 0,
                totalTodos: 0,
              )),
        ],
        child: const app.TermuxFlutterIDE(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Welcome Screen
    expect(find.text('歡迎使用 Termux Flutter IDE'), findsOneWidget);
    await tester.tap(find.text('開始設定'));
    await tester.pumpAndSettle();

    // 2. Termux Check (Skip/Next)
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 3. Permission Step
    expect(find.text('我已啟用，下一步'), findsOneWidget);
    await tester.tap(find.text('我已啟用，下一步'));
    await tester.pumpAndSettle();

    // 4. SSH Step (Normally needs connecting, but we override it)
    // For this test, let's assume the user successfully skips or connects
    await tester.tap(find.text('跳過 (使用 Bridge)'));
    await tester.pumpAndSettle();

    // 5. Flutter Step
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 6. Complete
    await tester.tap(find.text('進入 IDE'));
    await tester.pumpAndSettle();

    // now in IDE EditorPage
    // Navigate to Project Health
    await tester.tap(find.byIcon(Icons.analytics_outlined));
    await tester.pumpAndSettle();

    // Verify Dashboard is visible
    expect(find.text('PROJECT HEALTH'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);
  });
}
