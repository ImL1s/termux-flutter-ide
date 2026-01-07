import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('termux_flutter_ide/termux');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      if (methodCall.method == 'executeCommand') {
        return {
          'success': true,
          'exitCode': 0,
          'stdout': 'mock output',
          'stderr': ''
        };
      }
      return null;
    });
    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setupTermuxSSH sends executeCommand with background: true', () async {
    final bridge = TermuxBridge();
    await bridge.setupTermuxSSH();

    expect(log, hasLength(1));
    final call = log.first;
    expect(call.method, 'executeCommand');

    final args = call.arguments as Map;
    expect(args['background'], isTrue,
        reason: 'Must be background execution to avoid context switch');

    final command = args['command'] as String;
    // Command should be wrapped in bash with base64 decoding
    expect(command, startsWith('/data/data/com.termux/files/usr/bin/bash'));

    // Extract base64 part: echo BASE64 | base64 -d
    final RegExp regex = RegExp(r'echo\s+([a-zA-Z0-9+/=]+)\s+\|\s+base64\s+-d');
    final match = regex.firstMatch(command);
    expect(match, isNotNull,
        reason: 'Command should use base64 encoding wrapper');

    if (match != null) {
      final decoded = utf8.decode(base64.decode(match.group(1)!));
      expect(decoded, contains('pkg install'),
          reason: 'Should install packages');
      expect(decoded, contains('openssh'), reason: 'Should install openssh');
    }
  });
}
