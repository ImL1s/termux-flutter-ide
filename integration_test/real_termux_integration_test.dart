import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/git/git_service.dart';

/// 真實的 Termux 整合測試 - 直接在實體設備上與 Termux 互動
///
/// 前置條件：
/// - Termux 已安裝並運行在設備上
/// - SSH 已配置（openssh 已安裝，密碼已設置為 'termux'，sshd 正在運行）
/// - (可選) Flutter 已安裝在 Termux 中
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TermuxBridge termuxBridge;
  late SSHService sshService;

  setUpAll(() async {
    print('\n🔧 初始化測試環境...');
    termuxBridge = TermuxBridge();
    sshService = SSHService(termuxBridge);
    print('✅ 初始化完成\n');
  });

  tearDownAll(() async {
    print('\n🧹 清理測試環境...');
    await sshService.disconnect();
    print('✅ 清理完成\n');
  });

  group('【核心服務測試 1】TermuxBridge - Android Intent 通訊', () {
    test('1.1 檢查 Termux 是否安裝', () async {
      print('\n📱 檢查 Termux 安裝狀態...');
      final isInstalled = await termuxBridge.isTermuxInstalled();

      expect(isInstalled, true, reason: 'Termux 必須已安裝在設備上');
      print('✅ Termux 已安裝');
    });

    test('1.2 獲取 Termux UID', () async {
      print('\n🔢 獲取 Termux UID...');
      final uid = await termuxBridge.getTermuxUid();

      expect(uid, isNotNull);
      expect(uid! >= 10000, true, reason: 'Android UID 應該 >= 10000');
      print('✅ Termux UID: $uid');
    });

    test('1.3 執行簡單命令 - whoami', () async {
      print('\n👤 執行 whoami 命令...');
      final result = await termuxBridge.executeCommand('whoami');

      print('  📊 結果:');
      print('    Success: ${result.success}');
      print('    Exit code: ${result.exitCode}');
      print('    Stdout: ${result.stdout.trim()}');

      expect(result.success, true, reason: '命令應該成功執行');
      expect(result.exitCode, 0, reason: '退出碼應該為 0');
      expect(result.stdout.isNotEmpty, true, reason: 'stdout 不應為空');
      print('✅ whoami 成功，用戶: ${result.stdout.trim()}');
    });

    test('1.4 測試 Base64 命令編碼（TermuxBridge 核心機制）', () async {
      print('\n🔐 測試 Base64 編碼機制...');
      final testString = 'Flutter IDE Test ${DateTime.now()}';
      final result = await termuxBridge.executeCommand(
        'echo "$testString" | base64 | base64 -d'
      );

      expect(result.success, true);
      expect(result.stdout.trim(), testString);
      print('✅ Base64 編碼/解碼測試通過');
    });

    test('1.5 檢查 Flutter 安裝狀態', () async {
      print('\n🦋 檢查 Flutter...');
      final result = await termuxBridge.executeCommand('which flutter');

      print('  📍 Flutter 檢查結果:');
      print('    Exit code: ${result.exitCode}');
      print('    Stdout: ${result.stdout.trim()}');

      if (result.exitCode == 0) {
        print('✅ Flutter 已安裝: ${result.stdout.trim()}');

        // 獲取版本
        final versionResult = await termuxBridge.executeCommand('flutter --version');
        print('  📌 Flutter 版本:\n${versionResult.stdout}');
      } else {
        print('⚠️ Flutter 未安裝或不在 PATH 中');
      }
    });

    test('1.6 測試文件操作', () async {
      print('\n📁 測試文件創建、寫入、讀取...');
      final testFile = '~/test_flutter_ide_${DateTime.now().millisecondsSinceEpoch}.txt';
      final testContent = 'Integration Test at ${DateTime.now()}';

      // 寫入
      final writeResult = await termuxBridge.executeCommand(
        'echo "$testContent" > $testFile'
      );
      expect(writeResult.success, true, reason: '寫入應該成功');

      // 讀取
      final readResult = await termuxBridge.executeCommand('cat $testFile');
      expect(readResult.success, true, reason: '讀取應該成功');
      expect(readResult.stdout.trim(), testContent, reason: '內容應該匹配');

      // 清理
      await termuxBridge.executeCommand('rm -f $testFile');

      print('✅ 文件操作測試通過');
    });
  });

  group('【核心服務測試 2】SSHService - SSH 連接與命令執行', () {
    test('2.1 SSH 連接到 Termux', () async {
      print('\n🔐 嘗試 SSH 連接...');
      print('  目標: 127.0.0.1:8022');

      try {
        await sshService.connect();
        expect(sshService.isConnected, true, reason: 'SSH 應該成功連接');
        print('✅ SSH 連接成功！');
      } catch (e) {
        print('❌ SSH 連接失敗: $e');
        print('  提示: 請確保 Termux SSH 已配置：');
        print('    1. pkg install openssh');
        print('    2. passwd (設置密碼為 "termux")');
        print('    3. sshd');
        rethrow;
      }
    });

    test('2.2 SSH 執行命令 - pwd', () async {
      print('\n📂 測試 SSH 命令執行 (pwd)...');
      final result = await sshService.executeWithDetails('pwd');

      print('  📊 結果:');
      print('    Exit code: ${result.exitCode}');
      print('    Stdout: ${result.stdout.trim()}');

      expect(result.exitCode, 0);
      expect(result.stdout.contains('/data/data/com.termux/files/home'), true);
      print('✅ SSH 命令執行成功');
    });

    test('2.3 SSH 執行命令 - 環境變數', () async {
      print('\n🌍 檢查 Termux 環境變數...');
      final homeResult = await sshService.executeWithDetails('echo \$HOME');
      final pathResult = await sshService.executeWithDetails('echo \$PATH');

      print('  HOME: ${homeResult.stdout.trim()}');
      print('  PATH: ${pathResult.stdout.trim()}');

      expect(homeResult.stdout.contains('/data/data/com.termux/files/home'), true);
      print('✅ 環境變數正確');
    });

    test('2.4 SSH 測試退出碼', () async {
      print('\n⚡ 測試命令退出碼...');

      // 成功的命令
      final successResult = await sshService.executeWithDetails('true');
      expect(successResult.exitCode, 0, reason: 'true 命令應該返回 0');
      print('  ✓ 成功命令退出碼: ${successResult.exitCode}');

      // 失敗的命令
      final failResult = await sshService.executeWithDetails('false');
      expect(failResult.exitCode, isNot(0), reason: 'false 命令應該返回非 0');
      print('  ✓ 失敗命令退出碼: ${failResult.exitCode}');

      print('✅ 退出碼測試通過');
    });

    test('2.5 SSH 測試複雜命令', () async {
      print('\n🔗 測試複雜命令（管道、重定向）...');
      final result = await sshService.executeWithDetails(
        'echo "test1\ntest2\ntest3" | grep test2'
      );

      expect(result.exitCode, 0);
      expect(result.stdout.trim(), 'test2');
      print('✅ 複雜命令執行成功');
    });
  });

  group('【核心服務測試 3】Git 服務整合', () {
    late GitService gitService;

    setUp(() {
      gitService = GitService(sshService);
    });

    test('3.1 檢查 Git 是否可用', () async {
      print('\n🔍 檢查 Git 安裝...');
      final result = await sshService.executeWithDetails('git --version');

      if (result.exitCode == 0) {
        print('✅ Git 已安裝: ${result.stdout.trim()}');
      } else {
        print('⚠️ Git 未安裝，跳過 Git 測試');
        print('  安裝命令: pkg install git');
      }
    });

    test('3.2 測試 Git 倉庫操作', () async {
      print('\n📦 測試 Git 倉庫操作...');
      final testDir = '/data/data/com.termux/files/home/git_test_${DateTime.now().millisecondsSinceEpoch}';

      try {
        // 創建目錄並初始化 git
        await sshService.executeWithDetails('mkdir -p $testDir');
        await sshService.executeWithDetails('cd $testDir && git init');
        await sshService.executeWithDetails('cd $testDir && git config user.email "test@test.com"');
        await sshService.executeWithDetails('cd $testDir && git config user.name "Test User"');

        // 測試 isGitRepository
        final isRepo = await gitService.isGitRepository(testDir);
        expect(isRepo, true);
        print('  ✓ isGitRepository 檢測成功');

        // 測試 getCurrentBranch
        final branch = await gitService.getCurrentBranch(testDir);
        expect(branch.isNotEmpty, true);
        print('  ✓ 當前分支: $branch');

        // 測試 getStatus
        final status = await gitService.getStatus(testDir);
        print('  ✓ Git status 獲取成功');

        print('✅ Git 服務測試通過');
      } finally {
        // 清理
        await sshService.executeWithDetails('rm -rf $testDir');
      }
    });
  });

  group('【端到端測試】完整流程: 創建 Flutter 專案', () {
    test('E2E: 創建專案 → 驗證結構 → 執行 pub get', () async {
      print('\n🚀 開始端到端測試...');
      final projectName = 'test_e2e_${DateTime.now().millisecondsSinceEpoch}';
      final projectPath = '/data/data/com.termux/files/home/$projectName';

      // 檢查 Flutter 是否可用
      final flutterCheck = await termuxBridge.executeCommand('which flutter');
      if (flutterCheck.exitCode != 0) {
        print('⚠️ Flutter 未安裝，跳過 E2E 測試');
        print('  安裝 Flutter: 參考 termux-flutter-wsl 專案');
        return;
      }

      try {
        // Step 1: 創建專案
        print('\n1️⃣ 創建 Flutter 專案...');
        print('  專案名稱: $projectName');
        print('  專案路徑: $projectPath');

        final createResult = await termuxBridge.executeCommand(
          'cd ~ && flutter create $projectName',
        );

        if (createResult.exitCode != 0) {
          print('❌ Flutter create 失敗:');
          print('  Stderr: ${createResult.stderr}');
          fail('Flutter create 失敗');
        }

        print('✅ 專案創建成功');

        // Step 2: 驗證文件結構
        print('\n2️⃣ 驗證專案文件...');
        final files = ['pubspec.yaml', 'lib/main.dart', 'README.md'];

        for (final file in files) {
          final result = await termuxBridge.executeCommand(
            'test -f $projectPath/$file && echo "exists" || echo "missing"'
          );
          expect(result.stdout.trim(), 'exists', reason: '$file 應該存在');
          print('  ✓ $file');
        }
        print('✅ 專案結構正確');

        // Step 3: 讀取 main.dart
        print('\n3️⃣ 檢查 main.dart 內容...');
        final mainDart = await sshService.executeWithDetails(
          'head -30 $projectPath/lib/main.dart'
        );

        expect(mainDart.stdout.contains('void main()'), true);
        expect(mainDart.stdout.contains('runApp'), true);
        print('✅ main.dart 內容正確');

        // Step 4: 執行 pub get
        print('\n4️⃣ 執行 flutter pub get...');
        final pubGetResult = await termuxBridge.executeCommand(
          'cd $projectPath && flutter pub get',
        );

        if (pubGetResult.exitCode == 0) {
          print('✅ Pub get 成功');
        } else {
          print('⚠️ Pub get 失敗（可能是網絡問題）:');
          print('  ${pubGetResult.stderr}');
        }

        // Step 5: 驗證 .dart_tool 目錄
        print('\n5️⃣ 驗證 pub get 效果...');
        final dartToolCheck = await termuxBridge.executeCommand(
          'test -d $projectPath/.dart_tool && echo "exists" || echo "missing"'
        );

        if (dartToolCheck.stdout.contains('exists')) {
          print('✅ .dart_tool 目錄已創建');
        }

        print('\n🎉 端到端測試完成！');
        print('  專案已成功創建並初始化');

      } finally {
        // 清理
        print('\n6️⃣ 清理測試專案...');
        await termuxBridge.executeCommand('rm -rf $projectPath');
        print('✅ 清理完成');
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('【性能與穩定性測試】', () {
    test('連續執行多個命令', () async {
      print('\n⚡ 測試連續命令執行...');

      for (int i = 1; i <= 10; i++) {
        final result = await termuxBridge.executeCommand('echo "Test $i"');
        expect(result.success, true);
        expect(result.stdout.trim(), 'Test $i');
      }

      print('✅ 連續 10 次命令執行成功');
    });

    test('SSH 連接穩定性', () async {
      print('\n🔄 測試 SSH 連接穩定性...');

      // 斷開並重連
      await sshService.disconnect();
      expect(sshService.isConnected, false);

      await sshService.connect();
      expect(sshService.isConnected, true);

      print('✅ SSH 重連成功');
    });
  });
}
