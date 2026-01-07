import 'package:flutter/services.dart';

/// Bridge to native Android Termux terminal-view library.
/// Provides true PTY sessions with persistent shell state.
class NativeTerminalBridge {
  static const _channel = MethodChannel('termux_flutter_ide/native_terminal');

  // Callbacks for terminal events
  Function(String sessionId, String output)? onTerminalOutput;
  Function(String sessionId, String title)? onTitleChanged;
  Function(String sessionId, int exitCode)? onSessionFinished;
  Function(String sessionId, int pid)? onShellStarted;
  Function(String sessionId)? onBell;
  Function(String sessionId, String text)? onCopyToClipboard;
  Function(String sessionId)? onPasteFromClipboard;

  NativeTerminalBridge() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final args = call.arguments as Map<dynamic, dynamic>?;
    final sessionId = args?['sessionId'] as String? ?? '';

    switch (call.method) {
      case 'onTerminalOutput':
        onTerminalOutput?.call(sessionId, args?['output'] as String? ?? '');
        break;
      case 'onTitleChanged':
        onTitleChanged?.call(sessionId, args?['title'] as String? ?? '');
        break;
      case 'onSessionFinished':
        onSessionFinished?.call(sessionId, args?['exitCode'] as int? ?? -1);
        break;
      case 'onShellStarted':
        onShellStarted?.call(sessionId, args?['pid'] as int? ?? -1);
        break;
      case 'onBell':
        onBell?.call(sessionId);
        break;
      case 'onCopyToClipboard':
        onCopyToClipboard?.call(sessionId, args?['text'] as String? ?? '');
        break;
      case 'onPasteFromClipboard':
        onPasteFromClipboard?.call(sessionId);
        break;
    }
  }

  /// Create a new native terminal session with true PTY support.
  /// Returns the session ID.
  Future<String> createSession({String? cwd, String? shellPath}) async {
    final result = await _channel.invokeMethod<String>('createSession', {
      'cwd': cwd,
      'shellPath': shellPath,
    });
    return result ?? '';
  }

  /// Initialize the terminal emulator for a session.
  /// Must be called after createSession.
  Future<bool> initializeSession(String sessionId,
      {int columns = 80, int rows = 24}) async {
    final result = await _channel.invokeMethod<bool>('initializeSession', {
      'sessionId': sessionId,
      'columns': columns,
      'rows': rows,
    });
    return result ?? false;
  }

  /// Write data to a terminal session (user input).
  Future<bool> writeToSession(String sessionId, String data) async {
    final result = await _channel.invokeMethod<bool>('writeToSession', {
      'sessionId': sessionId,
      'data': data,
    });
    return result ?? false;
  }

  /// Resize a terminal session.
  Future<bool> resizeSession(String sessionId,
      {required int columns, required int rows}) async {
    final result = await _channel.invokeMethod<bool>('resizeSession', {
      'sessionId': sessionId,
      'columns': columns,
      'rows': rows,
    });
    return result ?? false;
  }

  /// Get current working directory of a session.
  Future<String?> getSessionCwd(String sessionId) async {
    return _channel.invokeMethod<String>('getSessionCwd', {
      'sessionId': sessionId,
    });
  }

  /// Check if a session is still running.
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

  /// Get the number of active sessions.
  Future<int> getSessionCount() async {
    final result = await _channel.invokeMethod<int>('getSessionCount');
    return result ?? 0;
  }

  /// Dispose and cleanup.
  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}
