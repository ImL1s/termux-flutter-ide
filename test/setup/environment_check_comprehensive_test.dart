import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:termux_flutter_ide/setup/environment_check_step.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';

import 'environment_check_comprehensive_test.mocks.dart';

@GenerateMocks([TermuxBridge])
void main() {
  late MockTermuxBridge mockBridge;

  setUp(() {
    mockBridge = MockTermuxBridge();
    // Default: Everything is perfect
    when(mockBridge.isTermuxInstalled()).thenAnswer((_) async => true);
    when(mockBridge.checkExternalAppsAllowed())
        .thenAnswer((_) async => ExternalAppsStatus.allowed);
    when(mockBridge.canDrawOverlays()).thenAnswer((_) async => true);
    when(mockBridge.checkTermuxPrefix()).thenAnswer((_) async => true);
    when(mockBridge.checkSSHServiceStatus()).thenAnswer((_) async => true);
    when(mockBridge.getTermuxPrefix())
        .thenAnswer((_) async => '/data/data/com.termux/files/usr');
    when(mockBridge.getTermuxPackageInstaller())
        .thenAnswer((_) async => 'com.termux');
    when(mockBridge.checkPermission(any)).thenAnswer((_) async => true);
    when(mockBridge.launchTermux()).thenAnswer((_) async => true);
  });

  Future<void> pumpCheckStep(WidgetTester tester,
      {VoidCallback? onAllPassed}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          termuxBridgeProvider.overrideWithValue(mockBridge),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EnvironmentCheckStep(
              onAllPassed: onAllPassed ?? () {},
              onContinueAnyway: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('EnvironmentCheckStep Comprehensive Scenarios', () {
    testWidgets('Case: All Passed -> Should trigger onAllPassed',
        (tester) async {
      bool allPassedCalled = false;
      await pumpCheckStep(tester, onAllPassed: () => allPassedCalled = true);

      // Wait for the simulated delay in _runChecks
      await tester.pump(const Duration(milliseconds: 1000));

      expect(allPassedCalled, isTrue,
          reason: 'Should proceed automatically if all checks pass');
    });

    testWidgets(
        'Case: Termux Not Installed -> Shows failure and Install button',
        (tester) async {
      when(mockBridge.isTermuxInstalled()).thenAnswer((_) async => false);

      await pumpCheckStep(tester);

      expect(find.text('Termux 已安裝'), findsOneWidget);
      expect(find.textContaining('請先安裝 Termux 應用程式'), findsOneWidget);
      expect(find.text('下載最新版 (GitHub)'), findsOneWidget);
    });

    testWidgets(
        'Case: allow-external-apps Disabled -> Shows failure and Copy button',
        (tester) async {
      when(mockBridge.checkExternalAppsAllowed())
          .thenAnswer((_) async => ExternalAppsStatus.notAllowed);

      await pumpCheckStep(tester);

      expect(find.textContaining('allow-external-apps'), findsOneWidget);
      // When checkPermission returns true but checkExternalAppsAllowed returns notAllowed
      expect(find.textContaining('已偵測到權限但 Termux 拒絕執行'), findsOneWidget);
      expect(find.text('複製並開啟 Termux'), findsOneWidget);
    });

    testWidgets(
        'Case: Overlay Permission Missing -> Shows warning and Settings button',
        (tester) async {
      when(mockBridge.canDrawOverlays()).thenAnswer((_) async => false);

      await pumpCheckStep(tester);

      expect(find.text('Draw Over Apps 權限'), findsOneWidget);
      expect(find.text('前往設定'), findsOneWidget);

      // Clear pending auto-proceed timer (since warning doesn't block proceed)
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Case: Termux Prefix Broken -> Shows Critical Failure',
        (tester) async {
      when(mockBridge.checkTermuxPrefix()).thenAnswer((_) async => false);

      await pumpCheckStep(tester);

      expect(find.text('Termux 環境變數'), findsOneWidget);
      expect(find.text('無法存取 \$PREFIX/usr/bin'), findsOneWidget);
      expect(find.text('修復'), findsOneWidget);
    });

    testWidgets('Case: Command Timeout -> UI should recover and show error',
        (tester) async {
      // Simulate a hang that then returns a timeout error (as implemented in our bridge fix)
      when(mockBridge.isTermuxInstalled()).thenAnswer((_) async {
        return Future.delayed(const Duration(seconds: 1), () => true);
      });
      when(mockBridge.checkExternalAppsAllowed()).thenAnswer((_) async {
        // Return exactly what our timeout handler in bridge returns
        return ExternalAppsStatus.unknown;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termuxBridgeProvider.overrideWithValue(mockBridge),
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

      // Should be in checking state initially
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Advance time to finish the delayed checks
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // UI should have stopped searching and displayed results (even if some failed due to "unknown"/timeout)
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('重新檢查'), findsOneWidget);

      // Clear pending timers if any
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
