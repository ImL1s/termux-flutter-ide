import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the native terminal service
final nativeTerminalServiceProvider = Provider<NativeTerminalService>((ref) {
  return NativeTerminalService();
});

/// Service for managing native PTY terminal sessions via TermuxTerminalManager.
/// Provides true persistent shell sessions with full interactive support (vim, less, etc).
class NativeTerminalService {
  static const _channel = MethodChannel('termux_flutter_ide/native_terminal');

  final _outputController = StreamController<TerminalOutputEvent>.broadcast();
  final _titleController = StreamController<TerminalTitleEvent>.broadcast();
  final _finishedController =
      StreamController<TerminalFinishedEvent>.broadcast();
  final _bellController = StreamController<String>.broadcast();

  Stream<TerminalOutputEvent> get onOutput => _outputController.stream;
  Stream<TerminalTitleEvent> get onTitleChanged => _titleController.stream;
  Stream<TerminalFinishedEvent> get onSessionFinished =>
      _finishedController.stream;
  Stream<String> get onBell => _bellController.stream;

  NativeTerminalService() {
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    switch (call.method) {
      case 'onTerminalOutput':
        final sessionId = call.arguments['sessionId'] as String;
        final output = call.arguments['output'] as String;
        _outputController.add(TerminalOutputEvent(sessionId, output));
        break;
      case 'onTitleChanged':
        final sessionId = call.arguments['sessionId'] as String;
        final title = call.arguments['title'] as String;
        _titleController.add(TerminalTitleEvent(sessionId, title));
        break;
      case 'onSessionFinished':
        final sessionId = call.arguments['sessionId'] as String;
        final exitCode = call.arguments['exitCode'] as int;
        _finishedController.add(TerminalFinishedEvent(sessionId, exitCode));
        break;
      case 'onBell':
        final sessionId = call.arguments['sessionId'] as String;
        _bellController.add(sessionId);
        break;
      case 'onCopyToClipboard':
        final text = call.arguments['text'] as String;
        await Clipboard.setData(ClipboardData(text: text));
        break;
      case 'onPasteFromClipboard':
        final sessionId = call.arguments['sessionId'] as String;
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null) {
          await writeToSession(sessionId, data!.text!);
        }
        break;
    }
  }

  /// Create a new native terminal session with PTY support.
  Future<String> createSession({String? cwd, String? shellPath}) async {
    final sessionId = await _channel.invokeMethod<String>('createSession', {
      'cwd': cwd,
      'shellPath': shellPath,
    });
    return sessionId!;
  }

  /// Initialize session with terminal dimensions.
  Future<bool> initializeSession(String sessionId,
      {int columns = 80, int rows = 24}) async {
    final result = await _channel.invokeMethod<bool>('initializeSession', {
      'sessionId': sessionId,
      'columns': columns,
      'rows': rows,
    });
    return result ?? false;
  }

  /// Write data (keystrokes, commands) to a session.
  Future<bool> writeToSession(String sessionId, String data) async {
    final result = await _channel.invokeMethod<bool>('writeToSession', {
      'sessionId': sessionId,
      'data': data,
    });
    return result ?? false;
  }

  /// Resize terminal dimensions.
  Future<bool> resizeSession(String sessionId,
      {required int columns, required int rows}) async {
    final result = await _channel.invokeMethod<bool>('resizeSession', {
      'sessionId': sessionId,
      'columns': columns,
      'rows': rows,
    });
    return result ?? false;
  }

  /// Get current working directory.
  Future<String?> getSessionCwd(String sessionId) async {
    return await _channel.invokeMethod<String>('getSessionCwd', {
      'sessionId': sessionId,
    });
  }

  /// Check if session is still running.
  Future<bool> isSessionRunning(String sessionId) async {
    final result = await _channel.invokeMethod<bool>('isSessionRunning', {
      'sessionId': sessionId,
    });
    return result ?? false;
  }

  /// Close a terminal session.
  Future<bool> closeSession(String sessionId) async {
    final result = await _channel.invokeMethod<bool>('closeSession', {
      'sessionId': sessionId,
    });
    return result ?? false;
  }

  /// Get list of active session IDs.
  Future<List<String>> getActiveSessions() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('getActiveSessions');
    return result?.cast<String>() ?? [];
  }

  /// Get count of active sessions.
  Future<int> getSessionCount() async {
    final result = await _channel.invokeMethod<int>('getSessionCount');
    return result ?? 0;
  }

  void dispose() {
    _outputController.close();
    _titleController.close();
    _finishedController.close();
    _bellController.close();
  }
}

/// Event emitted when terminal output is received.
class TerminalOutputEvent {
  final String sessionId;
  final String output;
  TerminalOutputEvent(this.sessionId, this.output);
}

/// Event emitted when terminal title changes.
class TerminalTitleEvent {
  final String sessionId;
  final String title;
  TerminalTitleEvent(this.sessionId, this.title);
}

/// Event emitted when a terminal session finishes.
class TerminalFinishedEvent {
  final String sessionId;
  final int exitCode;
  TerminalFinishedEvent(this.sessionId, this.exitCode);
}
