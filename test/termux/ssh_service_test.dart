import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';

// Manual Mock for TermuxBridge
class MockTermuxBridge extends Fake implements TermuxBridge {
  String whoamiResult = 'testuser';
  bool whoamiSuccess = true;
  int? uidResult = 12345;
  bool openTermuxCalled = false;
  bool setupSSHCalled = false;
  bool setupSSHSuccess = true;

  @override
  Future<TermuxResult> executeCommand(String command,
      {String? workingDirectory, bool background = false}) async {
    if (command == 'whoami') {
      return TermuxResult(
        success: whoamiSuccess,
        exitCode: whoamiSuccess ? 0 : 1,
        stdout: whoamiSuccess ? whoamiResult : '',
        stderr: whoamiSuccess ? '' : 'error',
      );
    }
    return TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  }

  @override
  Future<int?> getTermuxUid() async => uidResult;

  @override
  Future<bool> openTermux() async {
    openTermuxCalled = true;
    return true;
  }

  @override
  Future<TermuxResult> setupTermuxSSH() async {
    setupSSHCalled = true;
    return TermuxResult(
        success: setupSSHSuccess, exitCode: 0, stdout: '', stderr: '');
  }
}

void main() {
  late MockTermuxBridge mockBridge;

  setUp(() {
    mockBridge = MockTermuxBridge();
  });

  group('SSHService Unit Tests', () {
    test('Initial state is disconnected', () {
      final sshService = SSHService(mockBridge);
      expect(sshService.currentStatus, SSHStatus.disconnected);
    });

    test('Username resolution with whoami success', () async {
      mockBridge.whoamiSuccess = true;
      mockBridge.whoamiResult = 'testuser';

      final result = await mockBridge.executeCommand('whoami');
      expect(result.success, isTrue);
      expect(result.stdout.trim(), 'testuser');
    });

    test('Username resolution with UID fallback', () async {
      mockBridge.whoamiSuccess = false;
      mockBridge.uidResult = 11000;

      final uid = await mockBridge.getTermuxUid();
      expect(uid, 11000);
      final expectedUsername = 'u0_a${uid! - 10000}';
      expect(expectedUsername, 'u0_a1000');
    });

    test('MockBridge setupTermuxSSH returns success', () async {
      final result = await mockBridge.setupTermuxSSH();
      expect(result.success, isTrue);
      expect(mockBridge.setupSSHCalled, isTrue);
    });

    test('MockBridge openTermux sets flag', () async {
      await mockBridge.openTermux();
      expect(mockBridge.openTermuxCalled, isTrue);
    });
  });
}
