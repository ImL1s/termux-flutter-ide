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
    // Reset state after a short delay so the same request can be triggered again if needed
    // or just rely on the consumer handling it immediately.
    // Ideally, we want to pulse this.
  }
}

final editorRequestProvider =
    NotifierProvider<EditorRequestNotifier, EditorRequest?>(
  EditorRequestNotifier.new,
);
