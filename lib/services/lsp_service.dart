import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/ssh_service.dart';

class LspService {
  final Ref ref;
  SSHClient? _client;
  SSHSession? _session;
  int _requestId = 0;
  bool _isStarted = false;
  bool get isStarted => _isStarted;
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};

  final _responseController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get responses => _responseController.stream;

  LspService(this.ref);

  Future<bool> start() async {
    if (_isStarted) return true;

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

    try {
      _session = await _client!.execute('$dartPath $snapshotPath --lsp');
      _isStarted = true;
    } catch (e) {
      print('LSP Start Error: $e');
      return false;
    }

    // Listen to output
    _listenToOutput();

    // Send initialize
    await sendRequest('initialize', {
      'processId': null,
      'rootPath': '/data/data/com.termux/files/home',
      'rootUri': 'file:///data/data/com.termux/files/home',
      'capabilities': {
        'textDocument': {
          'completion': {
            'completionItem': {'snippetSupport': true}
          }
        }
      },
    });

    await sendRequest('initialized', {});

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
          _handleMessage(json);
        } catch (e) {
          print('LSP Decode Error: $e');
        }
        // Recursively process remaining data
        _processBuffer(data.substring(startIndex + length));
      }
    }
  }

  void _handleMessage(Map<String, dynamic> json) {
    if (json.containsKey('id')) {
      final id = json['id'];
      if (_pendingRequests.containsKey(id)) {
        _pendingRequests[id]!.complete(json);
        _pendingRequests.remove(id);
      }
    }
    _responseController.add(json);
  }

  Future<Map<String, dynamic>> sendRequest(
      String method, Map<String, dynamic> params) async {
    final id = ++_requestId;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    final request = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });

    final header = 'Content-Length: ${request.length}\r\n\r\n';
    _session?.stdin.add(utf8.encode(header + request));

    // Special case for notifications (no response expected)
    if (method == 'initialized' || method.startsWith(r'$/')) {
      _pendingRequests.remove(id);
      return {};
    }

    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      _pendingRequests.remove(id);
      return {
        'error': {'message': 'Request timeout'}
      };
    });
  }

  Future<void> notifyDidOpen(String filePath, String content) async {
    await sendNotification('textDocument/didOpen', {
      'textDocument': {
        'uri': 'file://$filePath',
        'languageId': 'dart',
        'version': 1,
        'text': content,
      },
    });
  }

  Future<void> notifyDidChange(String filePath, String content) async {
    await sendNotification('textDocument/didChange', {
      'textDocument': {
        'uri': 'file://$filePath',
        'version': DateTime.now().millisecondsSinceEpoch,
      },
      'contentChanges': [
        {'text': content},
      ],
    });
  }

  Future<Map<String, dynamic>> sendNotification(
      String method, Map<String, dynamic> params) async {
    final request = jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
    });

    final header = 'Content-Length: ${request.length}\r\n\r\n';
    _session?.stdin.add(utf8.encode(header + request));
    return {};
  }

  Future<List<Map<String, dynamic>>> getCompletions(
      String filePath, int line, int column) async {
    final uri = 'file://$filePath';
    final response = await sendRequest('textDocument/completion', {
      'textDocument': {'uri': uri},
      'position': {'line': line, 'character': column},
    });

    if (response.containsKey('result')) {
      final result = response['result'];
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      } else if (result is Map && result.containsKey('items')) {
        return (result['items'] as List).cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  void stop() {
    _session?.close();
    _session = null;
  }
}

final lspServiceProvider = Provider<LspService>((ref) => LspService(ref));
