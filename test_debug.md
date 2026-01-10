00:00 +0: loading D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart
test/editor/lsp_service_test.dart:27:22: Error: The method 'MockSSHClient.execute' has fewer named arguments than those of overridden method 'SSHClient.execute'.
  Future<SSHSession> execute(String command) async {
                     ^
/C:/Users/aa223/AppData/Local/Pub/Cache/hosted/pub.dev/dartssh2-2.11.0/lib/src/ssh_client.dart:296:22: Context: This is the overridden method ('execute').
  Future<SSHSession> execute(
                     ^
test/editor/lsp_service_test.dart:41:29: Error: The return type of the method 'MockSSHSession.stdin' is 'StreamSink<List<int>>', which does not match the return type, 'StreamSink<Uint8List>', of the overridden method, 'SSHSession.stdin'.
 - 'StreamSink' is from 'dart:async'.
 - 'List' is from 'dart:core'.
 - 'Uint8List' is from 'dart:typed_data'.
Change to a subtype of 'StreamSink<Uint8List>'.
  StreamSink<List<int>> get stdin => _stdinSinkController.sink;
                            ^
/C:/Users/aa223/AppData/Local/Pub/Cache/hosted/pub.dev/dartssh2-2.11.0/lib/src/ssh_session.dart:11:29: Context: This is the overridden method ('stdin').
  StreamSink<Uint8List> get stdin => _stdinController.sink;
                            ^
lib/services/lsp_service.dart:45:23: Error: The getter 'StreamSinkTransformer' isn't defined for the class 'LspService'.
 - 'LspService' is from 'package:termux_flutter_ide/services/lsp_service.dart' ('lib/services/lsp_service.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'StreamSinkTransformer'.
      final msgSink = StreamSinkTransformer.fromHandlers<String, List<int>>(
                      ^^^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: loading D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart [E]
  Failed to load "D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart": Compilation failed for testPath=D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart
00:00 +0 -1: Some tests failed.
