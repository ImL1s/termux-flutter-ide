import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/ssh_service.dart';
import '../editor/diagnostics_provider.dart';
import '../termux/termux_paths.dart';

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

    try {
      _session = await _client!.execute(
          '${TermuxPaths.dartExecutable} ${TermuxPaths.analysisServerSnapshot} --lsp');
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
      'rootPath': TermuxPaths.home,
      'rootUri': 'file://${TermuxPaths.home}',
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

    // Handle notifications
    if (json.containsKey('method')) {
      final method = json['method'];
      if (method == 'textDocument/publishDiagnostics') {
        _handleDiagnostics(json['params']);
      }
    }

    _responseController.add(json);
  }

  void _handleDiagnostics(Map<String, dynamic> params) {
    final uri = params['uri'] as String;
    final diagnosticsJson = params['diagnostics'] as List;
    final diagnostics = diagnosticsJson
        .map((j) => LspDiagnostic.fromJson(j as Map<String, dynamic>))
        .toList();

    ref.read(diagnosticsProvider.notifier).updateDiagnostics(uri, diagnostics);
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

  Future<Map<String, dynamic>?> getDefinition(
      String filePath, int line, int column) async {
    final uri = 'file://$filePath';
    final response = await sendRequest('textDocument/definition', {
      'textDocument': {'uri': uri},
      'position': {'line': line, 'character': column},
    });

    if (response.containsKey('result')) {
      final result = response['result'];
      if (result == null) return null;

      // result can be Location | List<Location> | List<LocationLink>
      if (result is List && result.isNotEmpty) {
        return result.first as Map<String, dynamic>;
      } else if (result is Map) {
        return result as Map<String, dynamic>;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getReferences(
      String filePath, int line, int column) async {
    final uri = 'file://$filePath';
    final response = await sendRequest('textDocument/references', {
      'textDocument': {'uri': uri},
      'position': {'line': line, 'character': column},
      'context': {'includeDeclaration': true},
    });

    if (response.containsKey('result')) {
      final result = response['result'];
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
    }
    return [];
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

  Future<String?> formatDocument(String filePath) async {
    final uri = 'file://$filePath';
    final response = await sendRequest('textDocument/formatting', {
      'textDocument': {'uri': uri},
      'options': {
        'tabSize': 2,
        'insertSpaces': true,
      },
    });

    if (response.containsKey('result')) {
      final result = response['result'];
      if (result is List && result.isNotEmpty) {
        // Result is a list of TextEdit
        // For simplicity, we assume it's one large edit or we'd need to apply them in order
        // Dart formatting usually returns one large edit replacing the whole file.
        // Actually, let's just return the first one's newText if it covers the whole document.
        // Better: just use the results.
        return result.first['newText'] as String;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getCodeActions(String filePath, int line,
      int column, List<LspDiagnostic> diagnostics) async {
    final uri = 'file://$filePath';
    final response = await sendRequest('textDocument/codeAction', {
      'textDocument': {'uri': uri},
      'range': {
        'start': {'line': line, 'character': column},
        'end': {'line': line, 'character': column},
      },
      'context': {
        'diagnostics': diagnostics
            .map((d) => {
                  'range': {
                    'start': {
                      'line': d.range.startLine,
                      'character': d.range.startColumn
                    },
                    'end': {
                      'line': d.range.endLine,
                      'character': d.range.endColumn
                    },
                  },
                  'severity': _severityToInt(d.severity),
                  'message': d.message,
                  'code': d.code,
                  'source': d.source,
                })
            .toList(),
      },
    });

    if (response.containsKey('result')) {
      final result = response['result'];
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  int _severityToInt(DiagnosticSeverity severity) {
    switch (severity) {
      case DiagnosticSeverity.error:
        return 1;
      case DiagnosticSeverity.warning:
        return 2;
      case DiagnosticSeverity.information:
        return 3;
      case DiagnosticSeverity.hint:
        return 4;
    }
  }

  /// Rename Symbol
  Future<Map<String, dynamic>?> renameSymbol(
      String filePath, int line, int column, String newName) async {
    final uri = 'file://$filePath';
    final response = await sendRequest('textDocument/rename', {
      'textDocument': {'uri': uri},
      'position': {'line': line, 'character': column},
      'newName': newName,
    });

    if (response.containsKey('result')) {
      return response['result'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// Workspace Symbol Search
  Future<List<Map<String, dynamic>>> workspaceSymbol(String query) async {
    final response = await sendRequest('workspace/symbol', {
      'query': query,
    });

    if (response.containsKey('result')) {
      final result = response['result'];
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
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
