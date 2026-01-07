#!/usr/bin/env dart
/// 測試 SSH 連接到 Termux
/// 運行方式: dart run scripts/test_ssh_connection.dart

import 'dart:io';

void main() async {
  print('\n🔐 測試 SSH 連接到 Termux\n');
  print('=' * 60);

  final tester = SSHConnectionTester();
  await tester.testConnection();
}

class SSHConnectionTester {
  final String host = '127.0.0.1';
  final int port = 8022;
  final String password = 'termux';

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    print('[$timestamp] $message');
  }

  Future<void> testConnection() async {
    _log('測試 SSH 連接...');
    _log('  主機: $host:$port');
    _log('  密碼: $password');

    // 測試 1: 檢查端口是否監聽
    await _testPort();

    // 測試 2: 嘗試 SSH 連接
    await _testSSHCommand();
  }

  Future<void> _testPort() async {
    _log('\n【測試 1】檢查 SSH 端口');

    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _log('✅ 端口 $port 可以連接');
      socket.destroy();
    } catch (e) {
      _log('❌ 端口 $port 無法連接: $e');
    }
  }

  Future<void> _testSSHCommand() async {
    _log('\n【測試 2】SSH 命令執行');

    try {
      // 使用 sshpass 執行 SSH 命令（如果有安裝）
      var result = await Process.run(
        'sshpass',
        ['-p', password, 'ssh', '-p', port.toString(), '-o', 'StrictHostKeyChecking=no', 'localhost', 'whoami']
      );

      if (result.exitCode == 0) {
        _log('✅ SSH 命令成功');
        _log('  輸出: ${result.stdout.toString().trim()}');
      } else {
        _log('⚠️ SSH 命令失敗');
        _log('  Exit code: ${result.exitCode}');
        _log('  Stderr: ${result.stderr}');
      }
    } catch (e) {
      if (e.toString().contains('No such file')) {
        _log('ℹ️ sshpass 未安裝，嘗試其他方式...');

        // 嘗試直接使用 ssh（需要手動輸入密碼）
        _log('\n請手動測試:');
        _log('  ssh -p $port localhost');
        _log('  密碼: $password');
      } else {
        _log('❌ 測試失敗: $e');
      }
    }
  }
}
