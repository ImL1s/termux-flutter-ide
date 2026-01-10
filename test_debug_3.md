00:00 +0: loading D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart
test/editor/lsp_service_test.dart:86:56: Error: The argument type 'Utf8Decoder' can't be assigned to the parameter type 'StreamTransformer<Uint8List, dynamic>'.
 - 'Utf8Decoder' is from 'dart:convert'.
 - 'StreamTransformer' is from 'dart:async'.
 - 'Uint8List' is from 'dart:typed_data'.
    final sub = mockSession.stdinStream.transform(utf8.decoder).listen((data) {
                                                       ^
test/editor/lsp_service_test.dart:118:56: Error: The argument type 'Utf8Decoder' can't be assigned to the parameter type 'StreamTransformer<Uint8List, dynamic>'.
 - 'Utf8Decoder' is from 'dart:convert'.
 - 'StreamTransformer' is from 'dart:async'.
 - 'Uint8List' is from 'dart:typed_data'.
    final sub = mockSession.stdinStream.transform(utf8.decoder).listen((data) {
                                                       ^
test/editor/lsp_service_test.dart:166:56: Error: The argument type 'Utf8Decoder' can't be assigned to the parameter type 'StreamTransformer<Uint8List, dynamic>'.
 - 'Utf8Decoder' is from 'dart:convert'.
 - 'StreamTransformer' is from 'dart:async'.
 - 'Uint8List' is from 'dart:typed_data'.
    final sub = mockSession.stdinStream.transform(utf8.decoder).listen((data) {
                                                       ^
00:00 +0 -1: loading D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart [E]
  Failed to load "D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart": Compilation failed for testPath=D:/SideProject/termux-flutter-ide/test/editor/lsp_service_test.dart
00:00 +0 -1: Some tests failed.
