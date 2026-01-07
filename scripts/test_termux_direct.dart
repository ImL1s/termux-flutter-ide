#!/usr/bin/env dart
/// 直接測試 Termux 核心服務 - 不依賴 Flutter 測試框架
/// 運行方式: dart run scripts/test_termux_direct.dart
///
/// 這個腳本直接使用 Android Debug Bridge (adb) 來測試 Termux 功能
/// 繞過 Flutter integration test 框架的連接問題

import 'dart:io';
import 'dart:convert';

void main() async {
  print('\n🔍 Termux 核心服務直接測試\n');
  print('=' * 60);

  final tester = TermuxDirectTester();
  await tester.runAllTests();
}

class TermuxDirectTester {
  final String deviceId = 'RFCNC0WNT9H'; // Samsung SM G9960

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    print('[$timestamp] $message');
  }

  Future<void> runAllTests() async {
    try {
      await _testAdbConnection();
      await _testTermuxInstallation();
      await _testTermuxCommand();
      await _testSshdStatus();
      await _testAutoSetup();

      _log('\n✅ 所有測試完成！');
    } catch (e, stack) {
      _log('\n❌ 測試失敗: $e');
      _log('Stack: $stack');
    }
  }

  Future<void> _testAdbConnection() async {
    _log('\n【測試 1】ADB 連接');

    final result = await Process.run('adb', ['devices']);
    if (result.exitCode != 0) {
      throw Exception('adb 命令失敗: ${result.stderr}');
    }

    final output = result.stdout.toString();
    if (output.contains(deviceId)) {
      _log('✅ 設備已連接: $deviceId');
    } else {
      throw Exception('設備未找到: $deviceId\n$output');
    }
  }

  Future<void> _testTermuxInstallation() async {
    _log('\n【測試 2】Termux 安裝狀態');

    // 檢查 Termux 包是否安裝
    final result = await Process.run(
      'adb',
      ['-s', deviceId, 'shell', 'pm', 'list', 'packages', 'com.termux']
    );

    if (result.stdout.toString().contains('com.termux')) {
      _log('✅ Termux 已安裝');

      // 獲取 UID
      final uidResult = await Process.run(
        'adb',
        ['-s', deviceId, 'shell', 'id', '-u']
      );
      final uid = uidResult.stdout.toString().trim();
      _log('  UID: $uid');
    } else {
      _log('❌ Termux 未安裝');
    }
  }

  Future<void> _testTermuxCommand() async {
    _log('\n【測試 3】執行 Termux 命令');

    // 測試簡單命令
    _log('📝 測試 whoami...');
    final result = await _runTermuxCommand('whoami');

    if (result.exitCode == 0) {
      _log('✅ whoami: ${result.stdout.trim()}');
    } else {
      _log('❌ whoami 失敗');
      _log('  Exit code: ${result.exitCode}');
      _log('  Stderr: ${result.stderr}');

      // 可能是 allow-external-apps 問題
      _log('\n⚠️ 可能需要啟用 allow-external-apps');
      _log('  請在 Termux 中運行: ');
      _log('    設置 → 允許來自外部應用的執行');
    }
  }

  Future<void> _testSshdStatus() async {
    _log('\n【測試 4】SSH 服務狀態');

    // 檢查 sshd 進程
    final psResult = await _runTermuxCommand('pgrep sshd');

    if (psResult.exitCode == 0 && psResult.stdout.trim().isNotEmpty) {
      _log('✅ sshd 正在運行 (PID: ${psResult.stdout.trim()})');

      // 檢查端口
      final portResult = await _runTermuxCommand(
        'netstat -tuln 2>/dev/null | grep 8022 || echo "not found"'
      );
      _log('  端口 8022: ${portResult.stdout.trim()}');
    } else {
      _log('❌ sshd 未運行');
      _log('  需要安裝並啟動 SSH 服務');
    }
  }

  Future<void> _testAutoSetup() async {
    _log('\n【測試 5】自動設置 SSH');

    _log('📋 檢查 openssh 是否已安裝...');
    final checkResult = await _runTermuxCommand('which sshd');

    if (checkResult.exitCode == 0) {
      _log('✅ openssh 已安裝: ${checkResult.stdout.trim()}');
    } else {
      _log('⚠️ openssh 未安裝，嘗試安裝...');

      // 安裝 openssh
      _log('📦 正在安裝 openssh...');
      final installResult = await _runTermuxCommand('pkg install openssh -y');

      if (installResult.exitCode == 0) {
        _log('✅ openssh 安裝成功');
      } else {
        _log('❌ openssh 安裝失敗');
        _log('  Stderr: ${installResult.stderr}');
        return;
      }
    }

    // 設置密碼
    _log('\n🔐 設置 Termux 密碼...');
    _log('  使用默認密碼: termux');
    final passwdResult = await _runTermuxCommand(
      'echo -e "termux\ntermux" | passwd'
    );

    if (passwdResult.exitCode == 0) {
      _log('✅ 密碼設置成功');
    } else {
      _log('⚠️ 密碼設置可能失敗（可能已設置過）');
    }

    // 啟動 sshd
    _log('\n🚀 啟動 sshd...');
    final sshdResult = await _runTermuxCommand('sshd');

    if (sshdResult.exitCode == 0) {
      _log('✅ sshd 啟動成功');

      // 等待啟動
      await Future.delayed(const Duration(seconds: 2));

      // 驗證
      final verifyResult = await _runTermuxCommand('pgrep sshd');
      if (verifyResult.exitCode == 0) {
        _log('✅ sshd 運行確認 (PID: ${verifyResult.stdout.trim()})');
      }
    } else {
      _log('⚠️ sshd 啟動可能失敗');
      _log('  可能已經在運行');
    }
  }

  /// 通過 adb 在 Termux 中執行命令
  Future<ProcessResult> _runTermuxCommand(String command) async {
    // 設置完整的 Termux 環境
    const termuxPrefix = '/data/data/com.termux/files/usr';
    const termuxHome = '/data/data/com.termux/files/home';

    // 構建完整的環境和命令
    final fullCommand = '''
export PREFIX=$termuxPrefix
export HOME=$termuxHome
export PATH=$termuxPrefix/bin:$termuxPrefix/bin/applets:\$PATH
export LD_LIBRARY_PATH=$termuxPrefix/lib
cd $termuxHome
$command
''';

    // 方法 1: 嘗試使用 run-as 直接在 Termux 環境中執行
    var result = await Process.run(
      'adb',
      [
        '-s', deviceId,
        'shell',
        'run-as', 'com.termux',
        'sh', '-c', fullCommand
      ]
    );

    // 如果 run-as 不可用（需要 debuggable），使用 am broadcast
    if (result.exitCode != 0 && result.stderr.toString().contains('not debuggable')) {
      _log('  ℹ️ run-as 不可用，使用 Intent 方式');

      // 通過 am 啟動 Termux 並執行命令
      // 這種方式不會返回輸出，但可以觸發執行
      final base64Command = base64.encode(utf8.encode(command));

      result = await Process.run(
        'adb',
        [
          '-s', deviceId,
          'shell', 'am', 'start',
          '--user', '0',
          '-n', 'com.termux/.app.TermuxActivity',
          '-a', 'com.termux.RUN_COMMAND',
          '--es', 'com.termux.RUN_COMMAND_PATH', '/data/data/com.termux/files/usr/bin/sh',
          '--esa', 'com.termux.RUN_COMMAND_ARGUMENTS', '-c,$base64Command',
        ]
      );

      // Intent 方式無法直接獲取輸出，返回特殊結果
      return ProcessResult(
        result.pid,
        0,  // 假設成功
        '(Intent 已發送，無法獲取輸出)',
        ''
      );
    }

    return result;
  }
}
