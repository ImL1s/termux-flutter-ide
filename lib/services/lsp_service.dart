import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:json_rpc_2/json_rpc_2.dart' as json_rpc;
import 'package:async/async.dart';
import 'package:stream_channel/stream_channel.dart';
import '../termux/ssh_service.dart';
import '../editor/diagnostics_provider.dart';

/// Manages the connection to the Dart Analysis Server via LSP over SSH.
class LspService {
  final Ref ref;
  json_rpc.Peer? _peer;
  SSHSession? _session;
  bool _isStarted = false;
  bool get isStarted => _isStarted;
  
  // Track current project path
  String? _currentRootPath;

  LspService(this.ref);

  Future<bool> start(String rootPath) async {
    if (_isStarted && _currentRootPath == rootPath) return true;
    if (_isStarted) await stop(); // Restart if path changed

    final ssh = ref.read(sshServiceProvider);
    if (!ssh.isConnected) {
      await ssh.connect();
    }
    if (!ssh.isConnected) return false;

    print('LSP: Starting dart language-server for $rootPath...');
    try {
      // Use execute to avoid PTY/echo issues, but command usage is key.
      // dart language-server is usually the way.
      _session = await ssh.client!.execute('dart language-server --client-id=termux-flutter-ide');
      
      final msgStream = _session!.stdout
          .cast<List<int>>()
          .transform(_LspPacketDecoder());

      final msgSink = StreamSinkTransformer<String, List<int>>.fromHandlers(
        handleData: (data, sink) {
          final encoded = utf8.encode(data);
          final header = 'Content-Length: ${encoded.length}\r\n\r\n';
          sink.add(utf8.encode(header));
          sink.add(encoded);
        },
      ).bind(_session!.stdin);

      final channel = StreamChannel(msgStream, msgSink);

      _peer = json_rpc.Peer(channel, onUnhandledError: (e, stack) {
        print('LSP Peer Error: $e');
      });

      // Register notifications
      _peer!.registerMethod('window/logMessage', (json_rpc.Parameters params) {
        // final type = params['type'].asInt;
        // final message = params['message'].asString;
        // print('LSP Log: $message');
      });

      _peer!.registerMethod('textDocument/publishDiagnostics', (json_rpc.Parameters params) {
         _handleDiagnostics(params.value as Map<String, dynamic>);
      });

      _peer!.listen();
      
      await _initialize(rootPath);
      _currentRootPath = rootPath;
      _isStarted = true;
      return true;
    } catch (e) {
      print('LSP Start Error: $e');
      return false;
    }
  }

  Future<void> _initialize(String rootPath) async {
    final params = {
      'processId': null,
      'rootUri': 'file://$rootPath',
      'capabilities': {
        'textDocument': {
          'synchronization': {
            'dynamicRegistration': true,
            'willSave': false,
            'willSaveWaitUntil': false,
            'didSave': true,
          },
          'completion': {
            'dynamicRegistration': true,
            'completionItem': {
              'snippetSupport': true,
              'resolveSupport': {'properties': ['documentation', 'detail']}
            }
          },
          'hover': {
            'dynamicRegistration': true,
            'contentFormat': ['markdown', 'plaintext']
          }
        },
         'workspace': {
            'configuration': true,
         }
      },
      'trace': 'off' 
    };

    await _peer!.sendRequest('initialize', params);
    _peer!.sendNotification('initialized', {});
  }

  Future<void> stop() async {
    _peer?.close();
    _session?.close(); // This kills the remote process
    _isStarted = false;
    _currentRootPath = null;
  }

  // --- Notification Methods ---

  Future<void> notifyDidOpen(String filePath, String content) async {
    if (!_isStarted) return;
    _peer!.sendNotification('textDocument/didOpen', {
      'textDocument': {
        'uri': 'file://$filePath',
        'languageId': 'dart',
        'version': 1,
        'text': content,
      },
    });
  }

  Future<void> notifyDidChange(String filePath, String content) async {
    if (!_isStarted) return;
    _peer!.sendNotification('textDocument/didChange', {
      'textDocument': {
        'uri': 'file://$filePath',
        'version': DateTime.now().millisecondsSinceEpoch,
      },
      'contentChanges': [
        {'text': content},
      ],
    });
  }

  // --- Request Methods ---

  Future<List<Map<String, dynamic>>> getCompletions(
      String filePath, int line, int column) async {
    if (!_isStarted) return [];
    
    try {
      final response = await _peer!.sendRequest('textDocument/completion', {
        'textDocument': {'uri': 'file://$filePath'},
        'position': {'line': line, 'character': column},
      });

      if (response == null) return [];

      if (response is List) {
        return response.cast<Map<String, dynamic>>();
      } else if (response is Map && response.containsKey('items')) {
        return (response['items'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('LSP Completion Error: $e');
      return [];
    }
  }

  Future<String?> formatDocument(String filePath) async {
    if (!_isStarted) return null;
    try {
      final response = await _peer!.sendRequest('textDocument/formatting', {
        'textDocument': {'uri': 'file://$filePath'},
        'options': {'tabSize': 2, 'insertSpaces': true}
      });
      
      if (response is List && response.isNotEmpty) {
        return response.first['newText'] as String;
      }
      return null;
    } catch (e) {
      print('LSP Format Error: $e');
      return null;
    }
  }

  // --- Diagnostics Implementation ---

  void _handleDiagnostics(Map<String, dynamic> params) {
    final uri = params['uri'] as String;
    final diagnosticsJson = params['diagnostics'] as List;
    
    final diagnostics = diagnosticsJson.map((j) {
      final range = j['range'];
      final start = range['start'];
      final end = range['end'];
      
      // Default to hint if severity is missing or unknown
      DiagnosticSeverity severity = DiagnosticSeverity.hint;
      if (j['severity'] != null) {
         final s = j['severity'] as int;
         if (s == 1) severity = DiagnosticSeverity.error;
         else if (s == 2) severity = DiagnosticSeverity.warning;
         else if (s == 3) severity = DiagnosticSeverity.information;
      }

      return LspDiagnostic(
        range: LspRange(
          startLine: start['line'],
          startColumn: start['character'],
          endLine: end['line'],
          endColumn: end['character'],
        ),
        severity: severity,
        message: j['message'] ?? '',
        code: j['code']?.toString(),
        source: j['source'],
      );
    }).toList();

    ref.read(diagnosticsProvider.notifier).updateDiagnostics(uri, diagnostics);
  }
}

/// Decodes LSP headers and yields JSON strings
class _LspPacketDecoder extends StreamTransformerBase<List<int>, String> {
  @override
  Stream<String> bind(Stream<List<int>> stream) async* {
    final buffer = <int>[];
    int? contentLength;
    
    await for (final chunk in stream) {
      buffer.addAll(chunk);

      while (true) {
        if (contentLength == null) {
          final headerEnd = _indexOfDoubleCRLF(buffer);
          if (headerEnd == -1) break;

          final headerString = utf8.decode(buffer.sublist(0, headerEnd));
          final lines = headerString.split('\r\n');
          for (final line in lines) {
             final lower = line.toLowerCase();
             if (lower.startsWith('content-length:')) {
               contentLength = int.parse(line.substring(15).trim());
             }
          }
          buffer.removeRange(0, headerEnd + 4);
        }

        if (contentLength != null) {
          if (buffer.length >= contentLength!) {
            final bodyBytes = buffer.sublist(0, contentLength!);
            final bodyString = utf8.decode(bodyBytes);
            
            buffer.removeRange(0, contentLength!);
            contentLength = null; 
            yield bodyString;
          } else {
            break;
          }
        }
      }
    }
  }

  int _indexOfDoubleCRLF(List<int> bytes) {
    for (int i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == 13 && bytes[i+1] == 10 && bytes[i+2] == 13 && bytes[i+3] == 10) {
        return i;
      }
    }
    return -1;
  }
}

final lspServiceProvider = Provider<LspService>((ref) => LspService(ref));
