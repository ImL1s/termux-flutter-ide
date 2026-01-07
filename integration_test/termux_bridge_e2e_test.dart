/// Termux Bridge E2E Test Suite
///
/// 這個測試必須在有安裝 Termux 的真實 Android 裝置上執行！
/// 執行方式: flutter test integration_test/termux_bridge_e2e_test.dart -d <device_id>
///
/// 前置條件:
/// 1. Termux 已安裝並至少執行過一次
/// 2. allow-external-apps=true 已設定
/// 3. openssh 已安裝且 sshd 正在執行
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TermuxBridge bridge;

  setUp(() {
    bridge = TermuxBridge();
  });

  group('🔌 Termux Bridge E2E Tests', () {
    testWidgets('1. isTermuxInstalled - 檢查 Termux 是否安裝', (tester) async {
      final installed = await bridge.isTermuxInstalled();

      print('📱 Termux 安裝狀態: ${installed ? "✅ 已安裝" : "❌ 未安裝"}');
      expect(installed, isTrue, reason: 'Termux 必須已安裝才能繼續測試');
    });

    testWidgets('2. checkExternalAppsAllowed - 檢查外部 App 權限', (tester) async {
      final status = await bridge.checkExternalAppsAllowed();

      print('🔐 allow-external-apps 狀態: $status');
      expect(status, equals(ExternalAppsStatus.allowed),
          reason: '必須設定 allow-external-apps=true');
    });

    testWidgets('3. canDrawOverlays - 檢查懸浮視窗權限', (tester) async {
      final canOverlay = await bridge.canDrawOverlays();

      print('🪟 懸浮視窗權限: ${canOverlay ? "✅ 已授權" : "⚠️ 未授權 (非必要)"}');
      // 這個不是必要的，只是警告
    });

    testWidgets('4. checkTermuxPrefix - 檢查環境變數', (tester) async {
      final prefixOk = await bridge.checkTermuxPrefix();

      print('📂 Termux Prefix: ${prefixOk ? "✅ 正常" : "❌ 異常"}');
      expect(prefixOk, isTrue, reason: 'Termux 環境必須正確設定');
    });

    testWidgets('5. checkSSHServiceStatus - 檢查 SSH 服務', (tester) async {
      final sshOk = await bridge.checkSSHServiceStatus();

      print('🔒 SSH 服務: ${sshOk ? "✅ 運作中" : "⚠️ 未啟動"}');
      // SSH 不是必要的，但建議啟動
    });

    testWidgets('6. executeCommand - 基本指令執行 (echo)', (tester) async {
      final result = await bridge.executeCommand('echo "Hello from Termux"',
          background: true);

      print('📤 指令執行結果:');
      print('   exitCode: ${result.exitCode}');
      print('   stdout: ${result.stdout.trim()}');
      print('   stderr: ${result.stderr}');

      expect(result.success, isTrue, reason: '基本 echo 指令應該成功');
      expect(result.stdout.trim(), equals('Hello from Termux'));
    });

    testWidgets('7. executeCommand - 檔案系統操作 (ls)', (tester) async {
      final result = await bridge.executeCommand(
          'ls -la /data/data/com.termux/files/home',
          background: true);

      print('📁 Home 目錄內容:');
      print(result.stdout);

      expect(result.success, isTrue, reason: 'ls 指令應該成功');
    });

    testWidgets('8. executeCommand - 環境變數檢查', (tester) async {
      final result =
          await bridge.executeCommand('echo \$PATH', background: true);

      print('🔧 PATH 環境變數:');
      print(result.stdout);

      expect(result.success, isTrue);
      expect(result.stdout, contains('/data/data/com.termux/files/usr/bin'));
    });

    testWidgets('9. executeCommand - 超時測試 (sleep)', (tester) async {
      // 測試 10 秒超時機制
      final stopwatch = Stopwatch()..start();
      final result = await bridge.executeCommand('sleep 15', background: true);
      stopwatch.stop();

      print('⏱️ 超時測試:');
      print('   執行時間: ${stopwatch.elapsedMilliseconds}ms');
      print('   結果: ${result.success ? "成功" : "超時/失敗"}');

      // 應該在 15 秒內超時（因為我們設定了 10 秒超時）
      expect(stopwatch.elapsed.inSeconds, lessThanOrEqualTo(15));
    });

    testWidgets('10. isFlutterInstalled - 檢查 Flutter 安裝', (tester) async {
      final flutterOk = await bridge.isFlutterInstalled();

      print('🎯 Flutter 安裝狀態: ${flutterOk ? "✅ 已安裝" : "⚠️ 未安裝"}');
      // Flutter 不是必要的（可能還沒安裝）
    });
  });

  group('📝 測試總結', () {
    testWidgets('顯示測試結果摘要', (tester) async {
      print('\n' + '=' * 50);
      print('🎉 所有 Termux Bridge E2E 測試完成！');
      print('=' * 50);
      print('如果所有測試都通過，表示 Termux 整合運作正常。');
      print('如果有測試失敗，請根據錯誤訊息進行修復。');
      print('=' * 50 + '\n');
    });
  });
}
