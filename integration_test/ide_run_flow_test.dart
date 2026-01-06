import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/main.dart';
import 'package:termux_flutter_ide/core/providers.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/file_manager/file_operations.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/setup/setup_service.dart';

// Mock Bridge
class MockBridge implements TermuxBridge {
  @override
  Future<int?> getTermuxUid() async => 1000;

  @override
  Future<TermuxResult> executeCommand(String command,
      {bool background = false, String? workingDirectory}) async {
    return TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<bool> isTermuxInstalled() async => true;

  @override
  Future<bool> openTermux() async => true;

  @override
  Future<bool> openTermuxSettings() async => true;

  @override
  Future<bool> launchTermux() async => true;

  @override
  Future<String?> getTermuxPackageInstaller() async => 'com.termux';

  @override
  Future<TermuxResult> setupTermuxSSH() async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');

  @override
  Future<TermuxResult> setupStorage() async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');

  @override
  Future<TermuxResult> installFlutter() async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');

  @override
  Future<bool> isFlutterInstalled() async => true;

  @override
  Future<TermuxResult> flutterRun({String? target}) async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');

  @override
  Future<TermuxResult> flutterBuildApk({bool release = true}) async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');

  @override
  Future<TermuxResult> flutterDoctor() async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');

  @override
  Future<TermuxResult> runFlutterCommand(String subCommand) async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');

  @override
  Future<String?> getTermuxPrefix() async => '/data/data/com.termux/files/usr';

  @override
  Stream<String> executeCommandStream(String command,
      {String? workingDirectory}) async* {
    yield '';
  }

  @override
  Future<ExternalAppsStatus> checkExternalAppsAllowed() async =>
      ExternalAppsStatus.allowed;

  @override
  Future<TermuxResult> enableExternalApps() async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');

  @override
  Future<bool> openBatteryOptimizationSettings() async => true;

  @override
  Future<bool> canDrawOverlays() async => true;

  @override
  Future<bool> checkSSHServiceStatus() async => true;

  @override
  Future<bool> checkTermuxPrefix() async => true;
}

// Mock FileOperations
class MockFileOperations extends SshFileOperations {
  // Pass a dummy SSHService to super, assuming it won't be used due to overrides
  MockFileOperations() : super(SSHService(MockBridge()));

  @override
  Future<bool> exists(String path) async {
    if (path.endsWith('pubspec.yaml')) return true;
    return true;
  }
}

class MockProjectPathNotifier extends ProjectPathNotifier {
  @override
  String? build() => '/data/data/com.termux/files/home/test_project';
}

class MockSetupService extends SetupService {
  @override
  SetupState build() {
    return const SetupState(
      currentStep: SetupStep.complete,
      isTermuxInstalled: true,
      isSSHConnected: true,
      isFlutterInstalled: true,
      isX11Installed: true,
    );
  }

  @override
  Future<void> checkEnvironment() async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IDE Run Button Verification', (tester) async {
    final mockBridge = MockBridge();
    final mockFileOps = MockFileOperations();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setupServiceProvider.overrideWith(() => MockSetupService()),
          projectPathProvider.overrideWith(() => MockProjectPathNotifier()),
          termuxBridgeProvider.overrideWithValue(mockBridge),
          fileOperationsProvider.overrideWithValue(mockFileOps),
        ],
        child: const TermuxFlutterIDE(),
      ),
    );

    await tester.pumpAndSettle();

    // Debugging print
    if (find.byType(TermuxFlutterIDE).evaluate().isNotEmpty) {
      print('TEST: TermuxFlutterIDE is present');
    } else {
      print('TEST: TermuxFlutterIDE NOT present');
    }

    // 1. Verify Project Title in AppBar
    expect(find.textContaining('test_project'), findsOneWidget,
        reason: 'Project name missing in AppBar');

    // 2. Verify Run Button
    final runButton = find.byIcon(Icons.play_arrow);
    expect(runButton, findsOneWidget, reason: 'Run button not found');

    // 3. Tap Run
    print('TEST: Tapping Run Button...');
    await tester.tap(runButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 4. Verify no error banner
    expect(find.textContaining('此目錄不是有效的 Flutter 專案'), findsNothing);
    print('TEST: Run execution triggered successfully.');
  });
}
