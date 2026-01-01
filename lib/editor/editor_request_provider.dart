import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class EditorRequest {}

class JumpToLineRequest extends EditorRequest {
  final String filePath;
  final int lineNumber;

  JumpToLineRequest(this.filePath, this.lineNumber);
}

class EditorRequestNotifier extends Notifier<EditorRequest?> {
  @override
  EditorRequest? build() {
    return null;
  }

  void request(EditorRequest req) {
    state = req;
  }

  void jumpToLine(String filePath, int lineNumber) {
    state = JumpToLineRequest(filePath, lineNumber);
  }
}

final editorRequestProvider =
    NotifierProvider<EditorRequestNotifier, EditorRequest?>(
  EditorRequestNotifier.new,
);
