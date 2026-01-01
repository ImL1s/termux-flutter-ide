import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';

Future<void> main() async {
  print('--- Host-side Feasibility Test ---');

  Future<SSHClient> connectSsh(String username) async {
    final socket = await SSHSocket.connect('localhost', 8822);
    final client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => 'termux',
    );
    await client.authenticated;
    return client;
  }

  Future<String> exec(SSHClient client, String command) async {
    final session = await client.execute(command);
    final stdout = utf8.decode(
        await session.stdout.fold<List<int>>([], (p, e) => p..addAll(e)));
    final stderr = utf8.decode(
        await session.stderr.fold<List<int>>([], (p, e) => p..addAll(e)));
    await session.done;
    if (stderr.isNotEmpty) {
      print('CMD: $command | STDERR: ${stderr.trim()}');
    }
    return stdout.trim();
  }

  SSHClient? client;
  try {
    client = await connectSsh('u0_a464');
    print('SSH Connected as ${client.username}');
  } catch (e) {
    print('SSH Connect (u0_a464) failed: $e. Try u0_a251...');
    try {
      client = await connectSsh('u0_a251');
      print('SSH Connected as ${client.username}');
    } catch (e2) {
      print('Fallback also failed: $e2');
      return;
    }
  }

  // Git Test
  print('\n[Git Integration Test]');
  await exec(client, 'mkdir -p ~/git_test');
  await exec(client, 'cd ~/git_test && git init');
  await exec(client, 'cd ~/git_test && touch test.txt');
  final status = await exec(client, 'cd ~/git_test && git status --porcelain');
  print('Git Status Output: "[$status]"');
  if (status.contains('?? test.txt')) {
    print('✅ Git Feasibility PASSED');
  } else {
    print('❌ Git Feasibility FAILED');
  }
  await exec(client, 'rm -rf ~/git_test');

  // LSP Test
  print('\n[LSP Integration Test]');

  // Real path found in logs
  String dartPath =
      '/data/data/com.termux/files/usr/opt/flutter/bin/cache/dart-sdk/bin/dart';
  final exists = await exec(client, 'ls $dartPath');
  if (!exists.contains('dart')) {
    dartPath = await exec(client,
        'find /data/data/com.termux/files -name dart -type f 2>/dev/null | head -n 1');
  }

  if (dartPath.isEmpty) {
    print('❌ Dart not found. Skipping LSP test.');
  } else {
    print('Dart path: "$dartPath"');

    // Test help
    final help = await exec(client, '$dartPath language-server --help');
    if (help.contains('Analysis Server')) {
      print('✅ LSP Binary Execution PASSED');
    }

    // Test JSON-RPC
    print('Testing LSP JSON-RPC Handshake (Direct Snapshot)...');
    final snapshotPath = dartPath.replaceAll(
        '/bin/dart', '/bin/snapshots/analysis_server.dart.snapshot');
    final session = await client.execute('$dartPath $snapshotPath --lsp');

    final initRequest = jsonEncode({
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {
        "processId": null,
        "rootUri": "file:///data/data/com.termux/files/home",
        "capabilities": {},
      }
    });
    final header = 'Content-Length: ${initRequest.length}\r\n\r\n';
    print('Sending Request: $initRequest');
    session.stdin.add(utf8.encode(header + initRequest));

    final completer = Completer<String>();
    final buffer = StringBuffer();
    session.stdout.cast<List<int>>().transform(utf8.decoder).listen((data) {
      print('RAW LSP DATA: $data');
      buffer.write(data);
      if (data.contains('capabilities') && !completer.isCompleted) {
        completer.complete(buffer.toString());
      }
    });

    // Also listen to stderr
    session.stderr.cast<List<int>>().transform(utf8.decoder).listen((data) {
      print('LSP STDERR: $data');
    });

    try {
      final response = await completer.future.timeout(Duration(seconds: 15));
      if (response.contains('capabilities')) {
        print('✅ LSP JSON-RPC Handshake PASSED');
      }
    } catch (e) {
      print('❌ LSP Handshake failed: $e');
      print('Buffer so far: ${buffer.toString()}');
    } finally {
      session.close();
    }
  }

  client.close();
  print('\n--- Feasibility Test Complete ---');
}
