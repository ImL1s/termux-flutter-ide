#!/usr/bin/env dart
/// 純 Dart SSH 測試 - 不依賴 Flutter
/// 運行方式: dart run scripts/test_ssh_pure.dart

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';

void main() async {
  print('\n🔐 純 Dart SSH 連接測試\n');
  print('=' * 60);

  // 確保 ADB port forwarding 已設置:
  // adb -s RFCNC0WNT9H forward tcp:8022 tcp:8022

  SSHClient? client;

  try {
    _log('🔌 連接到 127.0.0.1:8022...');

    final socket = await SSHSocket.connect('127.0.0.1', 8022);

    _log('✅ Socket 連接成功');

    _log('🔐 SSH 客戶端握手...');

    client = SSHClient(
      socket,
      username: 'u0_a1258', // Calculated from UID 11258
      keepAliveInterval: const Duration(seconds: 10),
      onPasswordRequest: () {
        _log('  📝 Password requested');
        return 'termux';
      },
      onUserInfoRequest: (request) {
        _log('  📝 Keyboard-interactive auth (${request.prompts.length} prompts)');
        return request.prompts.map((_) => 'termux').toList();
      },
    );

    _log('⏳ Waiting for authentication...');
    await client.authenticated.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('Authentication timeout'),
    );

    _log('✅ SSH 認證成功！');

    // 測試命令執行
    _log('\n📋 測試命令執行:');

    final whoamiResult = await client.run('whoami');
    _log('  whoami: ${utf8.decode(whoamiResult).trim()}');

    final pwdResult = await client.run('pwd');
    _log('  pwd: ${utf8.decode(pwdResult).trim()}');

    final homeResult = await client.run('echo \$HOME');
    _log('  HOME: ${utf8.decode(homeResult).trim()}');

    final lsResult = await client.run('ls -la');
    _log('  ls -la (首10行):');
    final lsLines = utf8.decode(lsResult).split('\n');
    for (var i = 0; i < lsLines.length && i < 10; i++) {
      _log('    ${lsLines[i]}');
    }

    _log('\n🎉 SSH 測試成功！所有命令都正常執行');
  } catch (e, stack) {
    _log('❌ 錯誤: $e');
    _log('\nStack trace:');
    print(stack);

    _log('\n💡 可能的問題:');
    _log('  1. ADB port forwarding 未設置');
    _log('     運行: adb -s RFCNC0WNT9H forward tcp:8022 tcp:8022');
    _log('  2. sshd 未在 Termux 中運行');
    _log('  3. 密碼不正確（默認: termux）');
    _log('  4. 用戶名不正確（當前使用: u0_a1258）');
  } finally {
    if (client != null) {
      client.close();
      _log('\n👋 已斷開 SSH 連接');
    }
  }

  exit(0);
}

void _log(String message) {
  final timestamp = DateTime.now().toIso8601String().substring(11, 19);
  print('[$timestamp] $message');
}
