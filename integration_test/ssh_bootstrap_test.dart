import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/core/providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E SSH Bootstrap & Connection Verification', (tester) async {
    // 1. Setup instances
    final bridge = TermuxBridge();
    final sshService = SSHService(bridge);

    print('TEST: Verifying Termux UID...');
    final uid = await bridge.getTermuxUid();
    print('TEST: Termux UID: $uid');
    expect(uid, isNotNull, reason: 'Should get a valid Termux UID');

    print('TEST: Triggering SSH Bootstrap (setupTermuxSSH)...');
    // Using manual command execution to mimic the fix
    // This runs the complex command: pkg install openssh ... chpasswd ... sshd
    final result = await bridge.setupTermuxSSH();
    print('TEST: Bootstrap Exited with code: ${result.exitCode}');
    print('TEST: Bootstrap Stdout: ${result.stdout}');
    print('TEST: Bootstrap Stderr: ${result.stderr}');

    // We expect 0 or success, but sometimes it might return non-zero if already running
    // The real test is the CONNECTION.

    print('TEST: Waiting for SSHD to stabilize...');
    await Future.delayed(const Duration(seconds: 5));

    print('TEST: Attempting SSH Connection...');
    await sshService.connect();

    print('TEST: Connection Status: ${sshService.isConnected}');
    expect(sshService.isConnected, isTrue,
        reason: 'SSH Service should be connected after bootstrap');

    // Cleanup
    if (sshService.client != null) {
      sshService.client!.close();
    }
  });
}
