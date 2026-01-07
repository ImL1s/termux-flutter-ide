import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:termux_flutter_ide/main.dart';
import 'package:termux_flutter_ide/setup/setup_wizard.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';

// Mock TermuxBridge
class MockTermuxBridge extends Mock implements TermuxBridge {
  @override
  Future<bool> isTermuxInstalled() async => true;

  @override
  Future<bool> isFlutterInstalled() async =>
      false; // Simulate not installed to force setup

  @override
  Future<int?> getTermuxUid() async => 10001;

  @override
  Future<TermuxResult> executeCommand(String command,
      {String? workingDirectory, bool background = false}) async {
    if (command.contains('which flutter')) {
      return const TermuxResult(
          success: true,
          exitCode: 1, // Not installed initially
          stdout: '',
          stderr: 'not found');
    }
    return const TermuxResult(
        success: true, exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<TermuxResult> setupTermuxSSH() async {
    return const TermuxResult(
        success: true, exitCode: 0, stdout: 'SSH Setup OK', stderr: '');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Setup Wizard Flow E2E Test', (WidgetTester tester) async {
    // Set a large enough screen size to avoid scrolling issues in test environment
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Setup Mocks
    final mockBridge = MockTermuxBridge();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          termuxBridgeProvider.overrideWithValue(mockBridge),
        ],
        child: const TermuxFlutterIDE(),
      ),
    );

    // Initial pump
    await tester.pump();
    // Allow logic in initState and generic async tasks to complete (like navigation)
    await tester.pumpAndSettle();

    // 1. Initial State: Should be on EditorPage or redirected to Setup
    // We expect redirection to /setup because SSH is not connected initially in main.dart
    expect(find.byType(SetupWizardPage), findsOneWidget);

    // 2. Welcome Step
    expect(find.text('歡迎使用 Termux Flutter IDE'), findsOneWidget);

    final startButton = find.text('開始設置');
    // Ensure visibility in case of small screens (though we set large size)
    await tester.scrollUntilVisible(startButton, 50);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // 3. Termux Check Step (Should be skipped or passed if mocked correctly)
    // If mocked isTermuxInstalled returns true, logic in setup_service usually skips to Permission or SSH
    // Let's verify current step by looking for UI

    // Logic: Welcome -> nextStep -> checkEnvironment -> if installed -> Permission
    expect(find.text('啟用外部應用權限'), findsOneWidget);

    // 4. Permission Step
    final permissionNext = find.text('我已啟用，下一步'); // Button text from code
    await tester.scrollUntilVisible(permissionNext, 50);
    await tester.tap(permissionNext);
    await tester.pumpAndSettle();

    // 5. SSH Step
    expect(find.text('尚未連線到 Termux'), findsOneWidget); // Initial state

    // Tap "Start Auto Configure" (Background)
    final autoConfigButton = find.text('2. 嘗試自動配置 SSH'); // Button text
    await tester.tap(autoConfigButton);
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('開始自動配置'), findsOneWidget);
    await tester.tap(find.text('開始')); // Confirm dialog
    await tester.pumpAndSettle();

    // Installing state... wait a bit simulating installation
    // In test environment, we might need to manually trigger state change or wait
    // But since we mocked executeCommand, it returns immediately.
    // The real logic calls setupTermuxSSH and then checkEnvironment.

    // We need to verify that after "installation", it moves to next step or shows connected.
    // For this E2E, we mainly ensure the UI flow doesn't crash and dialogs appear.

    // Force complete (Simulate successful connection for the purpose of flow completion)
    // Note: In a real integration test on device, this would actually run commands.
  });
}
