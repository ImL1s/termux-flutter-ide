import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/services/lsp_service.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/editor/diagnostics_provider.dart';

class MockSSHService extends Fake implements SSHService {
  final MockSSHClient mockClient;
  @override
  bool get isConnected => true;
  @override
  SSHClient? get client => mockClient;

  MockSSHService(this.mockClient);
}

class MockSSHClient extends Fake implements SSHClient {
  final MockSSHSession mockSession;
  MockSSHClient(this.mockSession);

  @override
  Future<SSHSession> execute(String command, {Map<String, String>? environment, SSHPtyConfig? pty, Stream<Uint8List>? stdin,}) async {
    return mockSession;
  }
}

class MockSSHSession extends Fake implements SSHSession {
  // Service reads from this (Server output)
  final StreamController<Uint8List> _stdoutController = StreamController(); 
  @override
  Stream<Uint8List> get stdout => _stdoutController.stream;

  final StreamController<Uint8List> _stdinSinkController = StreamController<Uint8List>.broadcast();
  @override
  StreamSink<Uint8List> get stdin => _stdinSinkController.sink;

  // Test reads from this to see what Service sent
  Stream<Uint8List> get stdinStream => _stdinSinkController.stream;

  // Helper to push to stdout (Simulate Server sending data to Client)
  void pushLspMessage(Map<String, dynamic> json) {
    final enc = utf8.encode(jsonEncode(json));
    final header = 'Content-Length: ${enc.length}\r\n\r\n';
    _stdoutController.add(Uint8List.fromList(utf8.encode(header)));
    _stdoutController.add(Uint8List.fromList(enc));
  }
  
  @override
  void close() {
    _stdoutController.close();
    _stdinSinkController.close();
  }
}

void main() {
  late ProviderContainer container;
  late MockSSHSession mockSession;
  late LspService service;

  setUp(() {
    mockSession = MockSSHSession();
    final mockClient = MockSSHClient(mockSession);
    final mockSSH = MockSSHService(mockClient);

    container = ProviderContainer(overrides: [
      sshServiceProvider.overrideWithValue(mockSSH),
    ]);
    service = container.read(lspServiceProvider);
  });

  tearDown(() {
    service.stop();
    mockSession.close();
    container.dispose();
  });

  test('LspService startup handshake', () async {
    final handshakeCompleter = Completer<void>();
    
    // Listen to client messages
    final sub = mockSession.stdinStream.cast<List<int>>().transform(utf8.decoder).listen((data) {
       print('TEST DEBUG: Received data: $data');
       if (data.contains('"method":"initialize"')) {
          final id = int.parse(RegExp(r'"id":(\d+)').firstMatch(data)!.group(1)!);
          
          // Reply with capabilities
          mockSession.pushLspMessage({
            "jsonrpc": "2.0", 
            "id": id, 
            "result": {
              "capabilities": {
                "textDocumentSync": 1,
              }
            }
          });
       }
       
       if (data.contains('"method":"initialized"')) {
         if (!handshakeCompleter.isCompleted) handshakeCompleter.complete();
       }
    });

    await service.start('/home/project');
    
    await handshakeCompleter.future.timeout(Duration(seconds: 2));
    expect(service.isStarted, isTrue);
    
    await sub.cancel();
  });

  test('LspService handles Diagnostics', () async {
    // 1. Setup handshake
    final sub = mockSession.stdinStream.cast<List<int>>().transform(utf8.decoder).listen((data) {
       if (data.contains('"method":"initialize"')) {
          final id = int.parse(RegExp(r'"id":(\d+)').firstMatch(data)!.group(1)!);
          mockSession.pushLspMessage({
            "jsonrpc": "2.0", "id": id, "result": {"capabilities": {}}
          });
       }
    });

    await service.start('/home/project');
    
    // 2. Push Diagnostics
    mockSession.pushLspMessage({
      "jsonrpc": "2.0",
      "method": "textDocument/publishDiagnostics",
      "params": {
        "uri": "file:///home/project/main.dart",
        "diagnostics": [
          {
            "range": {
              "start": {"line": 0, "character": 0},
              "end": {"line": 0, "character": 5}
            },
            "severity": 1,
            "message": "Test Error"
          }
        ]
      }
    });
    
    // 3. Verify Provider update
    // We need to wait a bit for the event loop
    await Future.delayed(Duration(milliseconds: 50));
    
    final diagnostics = container.read(diagnosticsProvider).fileDiagnostics;
    final fileDiags = diagnostics['file:///home/project/main.dart'];
    
    expect(fileDiags, isNotNull);
    expect(fileDiags!.first.message, equals('Test Error'));
    expect(fileDiags.first.severity, equals(DiagnosticSeverity.error));

    await sub.cancel();
  });
  
  test('LspService Completion Request', () async {
    final startCompleter = Completer<void>();
    
    // 1. Setup handshake & Request Handler
    final sub = mockSession.stdinStream.cast<List<int>>().transform(utf8.decoder).listen((data) {
       if (data.contains('"method":"initialize"')) {
          final id = int.parse(RegExp(r'"id":(\d+)').firstMatch(data)!.group(1)!);
          mockSession.pushLspMessage({
            "jsonrpc": "2.0", "id": id, "result": {"capabilities": {}}
          });
          startCompleter.complete();
       }
       
       if (data.contains('"method":"textDocument/completion"')) {
          final id = int.parse(RegExp(r'"id":(\d+)').firstMatch(data)!.group(1)!);
          // Reply with suggestions
          mockSession.pushLspMessage({
            "jsonrpc": "2.0", 
            "id": id, 
            "result": {
              "items": [
                {"label": "foo", "kind": 1}
              ]
            }
          });
       }
    });

    await service.start('/home/project');
    await startCompleter.future; // Ensure initialized
    
    final results = await service.getCompletions('/home/project/main.dart', 0, 0);
    
    expect(results, isNotEmpty);
    expect(results.first['label'], equals('foo'));
    
    await sub.cancel();
  });
}
