import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

Future<void> main() async {
  // 1. Setup ADB Forwarding
  print('Setting up ADB forwarding...');
  final adbResult = await Process.run('adb', ['forward', 'tcp:8022', 'tcp:8022']);
  if (adbResult.exitCode != 0) {
    print('Failed to forward port: ${adbResult.stderr}');
    return;
  }

  // 2. Connect to SSH
  print('Connecting to Termux SSH...');
  final socket = await SSHSocket.connect('127.0.0.1', 8022);
  final client = SSHClient(
    socket,
    username: 'u0_a223', // Hardcoded for probe, or we can parse from check_tools
    onPasswordRequest: () => 'termux', // Default password
  );

  print('Authenticating...');
  await client.authenticated;
  print('Connected!');

  // 3. Spawn language server
  print('Spawning dart language-server...');
  final session = await client.execute('/data/data/com.termux/files/usr/bin/dart language-server --client-id=probe');

  // 4. Send Initialize Request
  final request = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "processId": null,
      "rootUri": "file:///data/data/com.termux/files/home",
      "capabilities": {},
      "trace": "verbose"
    }
  };

  final jsonReq = jsonEncode(request);
  final header = 'Content-Length: ${utf8.encode(jsonReq).length}\r\n\r\n';
  
  session.stdin.add(utf8.encode('$header$jsonReq'));

  // 5. Read output
  print('Waiting for response...');
  final buffer = <int>[];
  
  session.stdout.listen((data) {
    buffer.addAll(data);
    final String response = utf8.decode(buffer, allowMalformed: true);
    if (response.contains('Content-Length:')) {
      print('\n--- Raw Response ---\n$response\n--------------------');
      if (response.contains('"id":1')) {
        print('SUCCESS: Received response to initialize request!');
        exit(0);
      }
    }
  });

  session.stderr.listen((data) {
    print('STDERR: ${utf8.decode(data)}');
  });
  
  // Timeout
  await Future.delayed(const Duration(seconds: 10));
  print('Timeout waiting for response.');
  exit(1);
}
