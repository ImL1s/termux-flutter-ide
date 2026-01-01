import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/ssh_service.dart';

class LspService {
  final Ref ref;
  SSHClient? _client;
  SSHSession? _session;

  final _responseController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get responses => _responseController.stream;

  LspService(this.ref);

  Future<bool> start() async {
    final ssh = ref.read(sshServiceProvider);
    if (!ssh.isConnected) {
      await ssh.connect();
    }

    if (!ssh.isConnected) return false;
    _client = ssh.client;

    // Detect Dart path or use hardcoded from PoC
    const dartPath =
        '/data/data/com.termux/files/usr/opt/flutter/bin/cache/dart-sdk/bin/dart';
    const snapshotPath =
        '/data/data/com.termux/files/usr/opt/flutter/bin/cache/dart-sdk/bin/snapshots/analysis_server.dart.snapshot';

    _session = await _client!.execute('$dartPath $snapshotPath --lsp');

    // Listen to output
    _listenToOutput();

    // Send initialize
    await sendRequest('initialize', {
      'processId': null,
      'rootUri': 'file:///data/data/com.termux/files/home',
      'capabilities': {},
    });

    return true;
  }

  void _listenToOutput() {
    String buffer = '';
    _session?.stdout.cast<List<int>>().transform(utf8.decoder).listen((data) {
      buffer += data;
      _processBuffer(buffer);
    });
  }

  void _processBuffer(String data) {
    // Basic LSP framing:
    // Content-Length: XXX\r\n\r\n{...}

    final regex = RegExp(r'Content-Length: (\d+)\r\n\r\n');
    final match = regex.firstMatch(data);

    if (match != null) {
      final length = int.parse(match.group(1)!);
      final startIndex = match.end;
      if (data.length >= startIndex + length) {
        final content = data.substring(startIndex, startIndex + length);
        try {
          final json = jsonDecode(content);
          _responseController.add(json);
        } catch (e) {
          print('LSP Decode Error: $e');
        }
        // Recursively process remaining data
        _processBuffer(data.substring(startIndex + length));
      }
    }
  }

  Future<void> sendRequest(String method, Map<String, dynamic> params) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    final request = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });

    final header = 'Content-Length: ${request.length}\r\n\r\n';
    _session?.stdin.add(utf8.encode(header + request));
  }

  void stop() {
    _session?.close();
    _session = null;
  }
}

final lspServiceProvider = Provider<LspService>((ref) => LspService(ref));
