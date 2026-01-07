import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:termux_flutter_ide/setup/setup_wizard.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/termux/connection_diagnostics.dart';

// Mock Classes
class MockTermuxBridge extends Mock implements TermuxBridge {
  @override
  Future<bool> isTermuxInstalled() async => true;
  @override
  Future<bool> isFlutterInstalled() async => false;
  @override
  Future<int?> getTermuxUid() async => 10001;
  @override
  Future<TermuxResult> executeCommand(String command,
          {String? workingDirectory, bool background = false}) async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<TermuxResult> setupTermuxSSH() async => const TermuxResult(
      success: true, exitCode: 0, stdout: 'SSHD_STARTED=SUCCESS', stderr: '');
  @override
  Future<ExternalAppsStatus> checkExternalAppsAllowed() async =>
      ExternalAppsStatus.allowed;
  @override
  Future<TermuxResult> enableExternalApps() async =>
      const TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<bool> openBatteryOptimizationSettings() async => true;
  @override
  Future<bool> canDrawOverlays() async => true;
  @override
  Future<bool> openTermux() async => true;
  @override
  Future<bool> openTermuxSettings() async => true;
  @override
  Future<String?> getTermuxPackageInstaller() async => 'com.termux';
  @override
  Future<String?> getTermuxPrefix() async => '/data/data/com.termux/files/usr';
  @override
  Future<bool> checkTermuxPrefix() async => true;
  bool _sshStatus = true;
  void setSSHStatus(bool status) => _sshStatus = status;

  @override
  Future<bool> checkSSHServiceStatus() async => _sshStatus;
  @override
  Future<bool> checkPermission(String permission) async => true;
  @override
  Future<bool> launchTermux() async => true;
}

class MockSSHService extends Mock implements SSHService {
  bool _shouldFail = false;
  bool _isConnected = false;

  void setShouldFail(bool value) => _shouldFail = value;

  @override
  bool get isConnected => _isConnected;

  @override
  ConnectionDiagnostics? get lastDiagnostics => null;

  @override
  Future<bool> ensureBootstrapped({bool background = true}) async => true;

  @override
  Future<void> connect() async {
    // No delay needed for widget test, or small one
    if (_shouldFail) {
      throw Exception('Connection refused');
    }
    _isConnected = true;
  }

  @override
  Future<SSHExecResult> executeWithDetails(String command) async {
    return SSHExecResult(exitCode: 0, stdout: 'mock_output', stderr: '');
  }
}

void main() {
  testWidgets('SetupWizard: Auto Config Success Flow',
      (WidgetTester tester) async {
    // Resize for visibility
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    // Setup Mocks
    final mockBridge = MockTermuxBridge();
    final mockSSH = MockSSHService();
    // Crucial: SSH must fail initially for "Auto Config" button to appear
    mockSSH.setShouldFail(true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          termuxBridgeProvider.overrideWithValue(mockBridge),
          sshServiceProvider.overrideWithValue(mockSSH),
        ],
        child: const MaterialApp(home: SetupWizardPage()),
      ),
    );
    await tester.pumpAndSettle();

    debugPrint('DEBUG: Initial state summary:');
    debugPrint(tester.allWidgets.map((w) => w.runtimeType).toSet().join(', '));

    // Navigate to SSH Step
    // 1. Welcome -> Start
    await tester.tap(find.text('開始設置'));
    await tester.pumpAndSettle();

    // 2. EnvironmentCheck auto-advances after 800ms
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // 3. Verify on SSH Step
    expect(find.text('2. 嘗試自動配置 SSH'), findsOneWidget);

    // 4. Tap Auto Config (ensure visible first)
    final autoConfigButton = find.text('2. 嘗試自動配置 SSH');
    await tester.ensureVisible(autoConfigButton);
    await tester.pumpAndSettle();

    await tester.tap(autoConfigButton);
    await tester.pumpAndSettle();

    // 5. Confirm Dialog
    expect(find.text('開始自動配置'), findsOneWidget);

    // Now switch mock to SUCCESS state so the process succeeds
    mockSSH.setShouldFail(false);

    await tester.tap(find.text('開始配置'));

    // Pump frames to process async logic
    // We need to advance the virtual clock because of Future.delayed(4s)
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // 6. Verify Success Dialog
    expect(find.text('連線成功！'), findsOneWidget);
    expect(find.text('太好了'), findsOneWidget);
  });

  testWidgets('SetupWizard: Auto Config Failure Flow (Diagnostics)',
      (WidgetTester tester) async {
    // Resize for visibility
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    final mockBridge = MockTermuxBridge();
    final mockSSH = MockSSHService();
    mockSSH.setShouldFail(true); // Always fail
    mockBridge.setSSHStatus(true); // Allow auto-advance

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          termuxBridgeProvider.overrideWithValue(mockBridge),
          sshServiceProvider.overrideWithValue(mockSSH),
        ],
        child: const MaterialApp(home: SetupWizardPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to SSH Step
    await tester.tap(find.text('開始設置'));
    await tester.pumpAndSettle();

    // Wait for auto-advance
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pumpAndSettle();

    // Should be on SSH step now (Auto-advanced)

    // Verify we are on SSH Step
    final autoConfigButton = find.text('2. 嘗試自動配置 SSH');
    expect(autoConfigButton, findsOneWidget);

    await tester.ensureVisible(autoConfigButton);
    await tester.pumpAndSettle();
    await tester.tap(autoConfigButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('開始配置'));

    // Pass time
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // 7. Verify Diagnostics Dialog
    expect(find.text('SSH 服務未啟動'), findsOneWidget);
    expect(find.text('請在 Termux 執行：'), findsOneWidget);
    expect(find.text('開啟 Termux'), findsOneWidget);
  });
}
