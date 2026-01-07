import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/setup/environment_check_step.dart';
import 'package:termux_flutter_ide/setup/ssh_connection_progress.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';

// Mock Bridge
class MockTermuxBridgeForCheck implements TermuxBridge {
  final bool termuxInstalled;
  final ExternalAppsStatus extAppsStatus;
  final bool canOverlayResult;

  MockTermuxBridgeForCheck({
    this.termuxInstalled = true,
    this.extAppsStatus = ExternalAppsStatus.allowed,
    this.canOverlayResult = true,
  });

  @override
  Future<bool> isTermuxInstalled() async => termuxInstalled;
  @override
  Future<ExternalAppsStatus> checkExternalAppsAllowed() async => extAppsStatus;
  @override
  Future<bool> canDrawOverlays() async => canOverlayResult;
  @override
  Future<bool> openBatteryOptimizationSettings() async => true;
  @override
  Future<TermuxResult> enableExternalApps() async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<bool> openTermuxSettings() async => true;
  @override
  Future<bool> openTermux() async => true;
  @override
  Future<bool> launchTermux() async => true;
  @override
  Future<String?> getTermuxPackageInstaller() async => 'com.termux';

  // Not used in these tests
  @override
  Future<int?> getTermuxUid() async => 10001;
  @override
  Future<TermuxResult> executeCommand(String c,
          {String? workingDirectory, bool background = false}) async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<TermuxResult> setupTermuxSSH() async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<bool> isFlutterInstalled() async => false;
  @override
  Future<TermuxResult> installFlutter() async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<TermuxResult> flutterRun({String? target}) async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<TermuxResult> flutterBuildApk({bool release = true}) async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<TermuxResult> flutterDoctor() async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<TermuxResult> runFlutterCommand(String subCommand) async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<String?> getTermuxPrefix() async => '/data/data/com.termux/files/usr';
  @override
  Stream<String> executeCommandStream(String c,
      {String? workingDirectory}) async* {
    yield '';
  }

  @override
  Future<TermuxResult> setupStorage() async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');

  @override
  @override
  Future<bool> checkSSHServiceStatus() async => true;

  @override
  Future<bool> checkTermuxPrefix() async => true;

  @override
  Future<bool> checkPermission(String permission) async => true;

  @override
  Future<void> fixTermuxEnvironment() async {}
}

void main() {
  group('EnvironmentCheckStep', () {
    testWidgets('EnvironmentCheckStep Shows all checks after loading',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termuxBridgeProvider.overrideWithValue(MockTermuxBridgeForCheck()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EnvironmentCheckStep(
                onAllPassed: () {},
                onContinueAnyway: () {},
              ),
            ),
          ),
        ),
      );

      // Initially shows loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Pump until loading completes
      await tester.pumpAndSettle();

      // Pump past the auto-proceed delay (800ms)
      await tester.pump(const Duration(milliseconds: 900));

      // Note: allPassedCalled may be true due to auto-proceed
      // We are mainly testing that the UI shows correctly before auto-proceed
      expect(find.text('Termux 已安裝'), findsOneWidget);
      expect(find.textContaining('allow-external-apps'), findsOneWidget);
      expect(find.text('Draw Over Apps 權限'), findsAtLeastNWidgets(1));
      expect(find.textContaining('電池優化'), findsAtLeastNWidgets(1));

      // Buttons visible
      expect(find.text('重新檢查'), findsOneWidget);
      expect(find.text('繼續設定'), findsOneWidget);
    });

    testWidgets('Shows failed state when Termux not installed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termuxBridgeProvider.overrideWithValue(MockTermuxBridgeForCheck(
              termuxInstalled: false,
            )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EnvironmentCheckStep(
                onAllPassed: () {},
                onContinueAnyway: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show failed message
      expect(find.textContaining('請先安裝 Termux 應用程式'), findsOneWidget);
      expect(find.text('下載最新版 (GitHub)'), findsOneWidget);
    });

    testWidgets('Shows allow-external-apps warning', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termuxBridgeProvider.overrideWithValue(MockTermuxBridgeForCheck(
              extAppsStatus: ExternalAppsStatus.notAllowed,
            )),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: EnvironmentCheckStep(
                onAllPassed: () {},
                onContinueAnyway: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show fix button
      expect(find.text('複製並開啟 Termux'), findsOneWidget);
    });
  });

  group('SSHConnectionProgress', () {
    testWidgets('Shows socket stage correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SSHConnectionProgress(
              currentStage: ConnectionStage.socket,
            ),
          ),
        ),
      );

      expect(find.text('建立連線'), findsOneWidget);
      expect(find.text('驗證身份'), findsOneWidget);
      expect(find.text('取得終端'), findsOneWidget);
      expect(find.text('正在建立 Socket 連線...'), findsOneWidget);
    });

    testWidgets('Shows auth stage correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SSHConnectionProgress(
              currentStage: ConnectionStage.auth,
            ),
          ),
        ),
      );

      expect(find.text('正在驗證 SSH 憑證...'), findsOneWidget);
    });

    testWidgets('Shows complete state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SSHConnectionProgress(
              currentStage: ConnectionStage.shell,
              isComplete: true,
            ),
          ),
        ),
      );

      expect(find.text('✓ 連線成功'), findsOneWidget);
    });

    testWidgets('Shows error state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SSHConnectionProgress(
              currentStage: ConnectionStage.auth,
              errorMessage: 'Authentication failed',
            ),
          ),
        ),
      );

      expect(find.text('連線失敗'), findsOneWidget);
      expect(find.text('Authentication failed'), findsOneWidget);
    });
  });
}
