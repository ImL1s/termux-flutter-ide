00:00 +0: loading D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart
test/editor/lsp_service_test.dart:27:87: Error: The parameter 'pty' of the method 'MockSSHClient.execute' has type 'bool?', which does not match the corresponding type, 'SSHPtyConfig?', in the overridden method, 'SSHClient.execute'.
 - 'SSHPtyConfig' is from 'package:dartssh2/src/ssh_client.dart' ('/C:/Users/aa223/AppData/Local/Pub/Cache/hosted/pub.dev/dartssh2-2.11.0/lib/src/ssh_client.dart').
Change to a supertype of 'SSHPtyConfig?', or, for a covariant parameter, a subtype.
  Future<SSHSession> execute(String command, {Map<String, String>? environment, bool? pty, Stream<Uint8List>? stdin,}) async {
                                                                                      ^
/C:/Users/aa223/AppData/Local/Pub/Cache/hosted/pub.dev/dartssh2-2.11.0/lib/src/ssh_client.dart:296:22: Context: This is the overridden method ('execute').
  Future<SSHSession> execute(
                     ^
lib/services/lsp_service.dart:46:45: Error: A constructor invocation can't have type arguments after the constructor name.
Try removing the type arguments or placing them after the class name.
      final msgSink = StreamSinkTransformer.fromHandlers<String, List<int>>(
                                            ^^^^^^^^^^^^
00:00 +0 -1: loading D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart [E]
  Failed to load "D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart": Compilation failed for testPath=D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart
00:00 +0 -1: Some tests failed.
