import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dartssh2/dartssh2.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  Future<SSHClient> connectSsh() async {
    // We try to mimic the app's connection logic
    // Using 127.0.0.1 for local device or localhost
    final socket = await SSHSocket.connect('127.0.0.1', 8022);

    // We need to determine the username dynamically or use a likely one
    // In many cases it is u0_a464 or similar.
    // Let's try to get it from a common location or use the fallback.
    final client = SSHClient(
      socket,
      username: 'u0_a464', // This should match the user's current environment
      onPasswordRequest: () => 'termux',
    );

    await client.authenticated;
    return client;
  }

  test('LSP Feasibility: Spawn Dart Language Server', () async {
    SSHClient? client;
    try {
      client = await connectSsh();
      print('SSH Connected as ${client.username}');
    } catch (e) {
      print('SSH Connect failed: $e. Try fallback username...');
      try {
        final socket = await SSHSocket.connect('127.0.0.1', 8022);
        client = SSHClient(socket,
            username: 'u0_a251', onPasswordRequest: () => 'termux');
        await client.authenticated;
      } catch (e2) {
        print('Fallback also failed: $e2');
        return;
      }
    }

    // 1. Find dart
    String dartPath = await exec(client!, 'which dart');
    if (dartPath.isEmpty) {
      print('Searching for dart in known locations...');
      final commonPaths = [
        '/data/data/com.termux/files/home/flutter/bin/cache/dart-sdk/bin/dart',
        '/data/data/com.termux/files/usr/bin/dart',
        '/data/data/com.termux/files/usr/lib/dart-sdk/bin/dart',
        '/data/data/com.termux/files/home/flutter-ide/flutter/bin/cache/dart-sdk/bin/dart',
      ];

      for (final path in commonPaths) {
        final exists = await exec(client, 'ls $path');
        if (exists.contains('dart')) {
          dartPath = path;
          break;
        }
      }
    }

    print('Dart path: "$dartPath"');

    if (dartPath.isEmpty) {
      print('Dart not found. Skipping LSP test.');
      return;
    }

    // 2. Try to run 'dart language-server --help' to verify it works
    final helpOutput = await exec(client, '$dartPath language-server --help');
    expect(helpOutput, contains('Analysis Server'));

    // 3. Test JSON-RPC Handshake
    print('Testing LSP JSON-RPC Handshake...');
    final session = await client.execute('$dartPath language-server');

    final initRequest = jsonEncode({
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {
        "processId": null,
        "rootUri": "file:///data/data/com.termux/files/home/git_test",
        "capabilities": {},
      }
    });

    // In LSP, each message is preceded by Content-Length header
    final header = 'Content-Length: ${initRequest.length}\r\n\r\n';
    session.stdin.add(utf8.encode(header + initRequest));

    // Wait for response
    // We expect a response starting with Content-Length
    final completer = Completer<String>();
    session.stdout.cast<List<int>>().transform(utf8.decoder).listen((data) {
      if (!completer.isCompleted) {
        completer.complete(data);
      }
    });

    try {
      final response =
          await completer.future.timeout(const Duration(seconds: 5));
      print('LSP Response received: ${response.substring(0, 50)}...');
      expect(response, contains('capabilities'));
      expect(response, contains('jsonrpc'));
    } catch (e) {
      print('LSP Handshake failed or timed out: $e');
      rethrow;
    } finally {
      session.close();
    }
  });

  test('Git Feasibility: Parse Status', () async {
    SSHClient? client;
    try {
      client = await connectSsh();
    } catch (e) {
      print('SSH Connect failed in Git test: $e');
      return;
    }

    // Create a dummy git repo
    await exec(client!, 'mkdir -p ~/git_test');
    await exec(client, 'cd ~/git_test && git init');
    await exec(client, 'cd ~/git_test && touch test.txt');

    // Run status
    final status =
        await exec(client, 'cd ~/git_test && git status --porcelain');
    print('Git Status Output: "[$status]"');

    // Parse
    // content should be "?? test.txt"
    expect(status, contains('?? test.txt'));

    // Cleanup
    await exec(client, 'rm -rf ~/git_test');
    client.close();
  });
}
