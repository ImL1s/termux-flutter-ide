#!/usr/bin/env dart
/// 使用實際的 SSHService 測試連接
/// 運行方式: dart run scripts/test_with_ssh_service.dart

import 'dart:io';
import '../lib/termux/ssh_service.dart';
import '../lib/termux/termux_bridge.dart';

void main() async {
  print('\n🔐 使用 SSHService 測試 Termux 連接\n');
  print('=' * 60);

  // 注意：這需要首先設置 ADB port forwarding:
  // adb -s RFCNC0WNT9H forward tcp:8022 tcp:8022

  final bridge = TermuxBridge();
  final ssh = SSHService(bridge);

  try {
    _log('🔌 準備連接...');
    _log('  主機: 127.0.0.1:8022');
    _log('  用戶: (自動檢測)');
    _log('  密碼: termux');

    _log('\n🔄 開始連接...');
    await ssh.connect();

    if (ssh.isConnected) {
      _log('✅ SSH 連接成功！');

      // 測試命令執行
      _log('\n📋 測試命令執行:');

      final whoamiResult = await ssh.executeWithDetails('whoami');
      _log('  whoami: ${whoamiResult.stdout.trim()}');

      final pwdResult = await ssh.executeWithDetails('pwd');
      _log('  pwd: ${pwdResult.stdout.trim()}');

      final homeResult = await ssh.executeWithDetails('echo \$HOME');
      _log('  HOME: ${homeResult.stdout.trim()}');

      _log('\n🎉 所有測試通過！');
    } else {
      _log('❌ 連接失敗');
    }
  } catch (e, stack) {
    _log('❌ 錯誤: $e');
    _log('Stack trace:');
    print(stack);
  } finally {
    await ssh.disconnect();
    _log('\n👋 已斷開連接');
  }

  exit(0);
}

void _log(String message) {
  final timestamp = DateTime.now().toIso8601String().substring(11, 19);
  print('[$timestamp] $message');
}
