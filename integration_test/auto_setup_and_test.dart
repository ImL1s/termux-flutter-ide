import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';

/// 自動設置 Termux 環境並運行測試
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TermuxBridge termuxBridge;
  late SSHService sshService;

  setUpAll(() async {
    termuxBridge = TermuxBridge();
    sshService = SSHService(termuxBridge);
  });

  tearDownAll(() async {
    await sshService.disconnect();
  });

  group('自動設置 Termux 環境', () {
    test('步驟 1: 檢查並啟動 Termux', () async {
      print('\n📱 檢查 Termux...');

      final isInstalled = await termuxBridge.isTermuxInstalled();
      expect(isInstalled, true);
      print('✅ Termux 已安裝');

      final uid = await termuxBridge.getTermuxUid();
      print('✅ Termux UID: $uid');

      // 檢查 external apps 權限
      print('\n🔍 檢查 allow-external-apps 權限...');
      final status = await termuxBridge.checkExternalAppsAllowed();
      print('  狀態: $status');

      if (status != ExternalAppsStatus.allowed) {
        print('⚠️ allow-external-apps 未啟用 (狀態: $status)');
        print('📱 嘗試打開 Termux 並請求權限...');

        await termuxBridge.openTermux();
        await Future.delayed(const Duration(seconds: 3));

        print('💡 請在 Termux 中手動啟用 "允許來自外部應用的執行" 設置');
        print('   設置路徑: Settings → Allow external apps');

        // 等待用戶設置
        print('⏳ 等待 10 秒讓您設置...');
        await Future.delayed(const Duration(seconds: 10));
      } else {
        print('✅ allow-external-apps 已啟用');
      }
    });

    test('步驟 2: 自動設置 SSH', () async {
      print('\n🔐 開始自動設置 SSH...');

      // 打開 Termux
      print('📱 打開 Termux...');
      await termuxBridge.openTermux();
      await Future.delayed(const Duration(seconds: 2));

      // 運行自動設置
      print('⚙️ 執行 setupTermuxSSH...');
      final setupResult = await termuxBridge.setupTermuxSSH();

      print('📊 設置結果:');
      print('  Success: ${setupResult.success}');
      print('  Exit code: ${setupResult.exitCode}');
      print('  Stdout: ${setupResult.stdout}');
      if (setupResult.stderr.isNotEmpty) {
        print('  Stderr: ${setupResult.stderr}');
      }

      if (setupResult.success) {
        print('✅ SSH 設置成功！');
      } else {
        print('⚠️ 自動設置可能失敗，嘗試手動命令...');

        // 手動執行設置命令
        print('\n📝 手動安裝 openssh...');
        final installResult = await termuxBridge.executeCommand(
          'pkg install openssh -y'
        );
        print('  安裝結果: ${installResult.success}');

        print('\n📝 啟動 sshd...');
        final sshdResult = await termuxBridge.executeCommand('sshd');
        print('  啟動結果: ${sshdResult.success}');
      }

      // 等待 sshd 啟動
      print('\n⏳ 等待 5 秒讓 sshd 啟動...');
      await Future.delayed(const Duration(seconds: 5));
    });

    test('步驟 3: 驗證 SSH 連接', () async {
      print('\n🔐 測試 SSH 連接...');

      try {
        await sshService.connect();
        expect(sshService.isConnected, true);
        print('✅ SSH 連接成功！');

        // 執行測試命令
        final result = await sshService.executeWithDetails('whoami');
        print('  用戶名: ${result.stdout.trim()}');

      } catch (e) {
        print('❌ SSH 連接失敗: $e');

        // 診斷
        print('\n🔍 診斷問題...');

        // 檢查 sshd 是否運行
        final checkSshd = await termuxBridge.executeCommand(
          'pgrep sshd && echo "running" || echo "not running"'
        );
        print('  sshd 狀態: ${checkSshd.stdout.trim()}');

        // 檢查端口
        final checkPort = await termuxBridge.executeCommand(
          'netstat -tuln 2>/dev/null | grep 8022 || echo "port not listening"'
        );
        print('  端口 8022: ${checkPort.stdout.trim()}');

        // 嘗試重啟 sshd
        print('\n🔄 嘗試重啟 sshd...');
        await termuxBridge.executeCommand('pkill sshd');
        await Future.delayed(const Duration(seconds: 1));
        await termuxBridge.executeCommand('sshd');
        await Future.delayed(const Duration(seconds: 3));

        // 重試連接
        print('🔄 重試 SSH 連接...');
        await sshService.connect();

        if (sshService.isConnected) {
          print('✅ 重試成功！');
        } else {
          print('❌ 重試失敗');
          rethrow;
        }
      }
    });

    test('步驟 4: 測試基本命令執行', () async {
      print('\n⚡ 測試命令執行能力...');

      // 測試 TermuxBridge
      print('\n1️⃣ 測試 TermuxBridge:');
      final bridgeResult = await termuxBridge.executeCommand('echo "Hello from Bridge"');
      print('  Success: ${bridgeResult.success}');
      print('  Output: ${bridgeResult.stdout.trim()}');

      if (bridgeResult.success) {
        print('  ✅ TermuxBridge 工作正常');
      } else {
        print('  ❌ TermuxBridge 仍有問題');
        print('  請確保在 Termux 設置中啟用了 "allow-external-apps"');
      }

      // 測試 SSH
      print('\n2️⃣ 測試 SSH:');
      final sshResult = await sshService.executeWithDetails('echo "Hello from SSH"');
      print('  Exit code: ${sshResult.exitCode}');
      print('  Output: ${sshResult.stdout.trim()}');

      if (sshResult.exitCode == 0) {
        print('  ✅ SSH 工作正常');
      } else {
        print('  ❌ SSH 仍有問題');
      }
    });

    test('步驟 5: 檢查 Flutter 安裝', () async {
      print('\n🦋 檢查 Flutter 狀態...');

      final flutterCheck = await termuxBridge.executeCommand('which flutter');

      if (flutterCheck.exitCode == 0) {
        print('✅ Flutter 已安裝: ${flutterCheck.stdout.trim()}');

        final versionCheck = await termuxBridge.executeCommand('flutter --version');
        print('\n📌 Flutter 版本:');
        print(versionCheck.stdout);
      } else {
        print('⚠️ Flutter 未安裝');
        print('\n💡 安裝建議:');
        print('  1. 在 Termux 中執行:');
        print('     curl -fsSL https://raw.githubusercontent.com/ImL1s/termux-flutter-wsl/main/install.sh | bash');
        print('  2. 或參考: https://github.com/ImL1s/termux-flutter-wsl');
      }
    });
  });

  group('運行完整測試套件', () {
    test('執行所有核心服務測試', () async {
      print('\n🎯 開始完整測試...\n');

      // 1. TermuxBridge 測試
      print('【測試 1/3】TermuxBridge 命令執行');
      final whoami = await termuxBridge.executeCommand('whoami');
      expect(whoami.success, true, reason: 'TermuxBridge 應該能執行命令');
      print('  ✓ whoami: ${whoami.stdout.trim()}');

      final pwd = await termuxBridge.executeCommand('pwd');
      expect(pwd.success, true);
      print('  ✓ pwd: ${pwd.stdout.trim()}');

      // 2. SSH 測試
      print('\n【測試 2/3】SSH 服務');
      expect(sshService.isConnected, true, reason: 'SSH 應該已連接');

      final sshWhoami = await sshService.executeWithDetails('whoami');
      expect(sshWhoami.exitCode, 0);
      print('  ✓ SSH whoami: ${sshWhoami.stdout.trim()}');

      final home = await sshService.executeWithDetails('echo \$HOME');
      expect(home.stdout.contains('/data/data/com.termux/files/home'), true);
      print('  ✓ HOME: ${home.stdout.trim()}');

      // 3. 文件操作測試
      print('\n【測試 3/3】文件操作');
      final testFile = '~/test_auto_${DateTime.now().millisecondsSinceEpoch}.txt';
      final testContent = 'Auto setup test ${DateTime.now()}';

      final writeResult = await termuxBridge.executeCommand(
        'echo "$testContent" > $testFile'
      );
      expect(writeResult.success, true);

      final readResult = await termuxBridge.executeCommand('cat $testFile');
      expect(readResult.stdout.trim(), testContent);
      print('  ✓ 文件讀寫正常');

      await termuxBridge.executeCommand('rm -f $testFile');
      print('  ✓ 文件清理完成');

      print('\n🎉 所有核心服務測試通過！');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
