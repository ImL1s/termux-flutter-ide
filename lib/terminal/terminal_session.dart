import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xterm/xterm.dart';
import '../termux/termux_bridge.dart';

enum SessionState { connecting, connected, disconnected, failed }

class TerminalSession {
  final String id;
  final String name;
  final String? initialDirectory;
  final Terminal terminal;
  bool isConnected = false;
  SessionState state = SessionState.disconnected;
  String? lastError;

  String _receivedBuffer = '';
  final List<String> _logHistory = [];
  String? _filter;
  final String _partialLine = '';
  final List<String> _pendingCommands = [];

  // Data stream for log interception
  final _dataController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  // Reference to TermuxBridge for command execution
  TermuxBridge? bridge;

  // Input buffer for command line
  String _inputBuffer = '';
  bool _isProcessingInput = false;

  Future<void> write(String data) async {
    if (state != SessionState.connected || bridge == null) {
      _pendingCommands.add(data);
      terminal.write('\x1B[1;30m[IDE] Command queued: $data\x1B[0m\r\n');
      return;
    }

    if (_isProcessingInput) {
      // Very basic queueing - in real app we'd use a more robust queue
      await Future.delayed(const Duration(milliseconds: 50));
      return write(data);
    }

    _isProcessingInput = true;

    try {
      // Process each character
      for (int i = 0; i < data.length; i++) {
        final char = data[i];
        final codeUnit = char.codeUnitAt(0);

        if (char == '\r' || char == '\n') {
          // Deduplicate \r\n or \n\r within the same batch
          if (i + 1 < data.length &&
              (data[i + 1] == '\r' || data[i + 1] == '\n') &&
              data[i] != data[i + 1]) {
            i++;
          }

          terminal.write('\r\n');
          final cmd = _inputBuffer.trim();
          _inputBuffer = '';

          if (cmd.isNotEmpty) {
            await _executeCommand(cmd);
            _showPrompt();
          } else {
            // Just showed a new line for empty enter, show prompt again
            _showPrompt();
          }
        } else if (codeUnit == 127 || codeUnit == 8) {
          // Backspace (127 = DEL, 8 = BS)
          if (_inputBuffer.isNotEmpty) {
            _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
            terminal.write('\b \b'); // Move back, clear, move back
          }
        } else if (codeUnit == 9) {
          // Tab - add spaces (basic tab support)
          _inputBuffer += '    ';
          terminal.write('    ');
        } else if (codeUnit >= 32) {
          // Printable character (including space which is 32)
          _inputBuffer += char;
          terminal.write(char);
        }
        // Ignore other control characters
      }
    } finally {
      _isProcessingInput = false;
    }
  }

  void _showPrompt() {
    terminal.write('\$ ');
  }

  Future<void> _executeCommand(String command) async {
    if (bridge == null) return;

    // Echo local command immediately? No, we already typed it.
    // terminal.write(command + '\r\n');

    // Run via bridge
    try {
      // If we have an initial directory, we might want to prepend "cd <dir> &&"
      // BUT for a persistent session simulation, we should track CWD.
      // For now, let's just attempt global execution.
      // If we are implementing a 'shell', we need to track state.
      // Since TermuxBridge is stateless individually, each command runs in fresh shell.
      // To simulate session, we might need a complex wrapper.
      // simple approach: just run it. directory won't persist between commands unless we chain them.
      // This is a known limitation of 'run command' intent vs SSH.
      // But we can improve by maintaining a CWD variable in Dart and prepending it.

      // Attempt to leverage CWD if we have one
      String finalCmd = command;
      // Note: Updating CWD based on 'cd' command is tricky without shell feedback.
      // Let's keep it simple: execute.

      var workingDir = initialDirectory;

      await for (final output in bridge!
          .executeCommandStream(finalCmd, workingDirectory: workingDir)) {
        onDataReceived(output);
      }
    } catch (e) {
      onDataReceived('Error: $e\r\n');
    }
  }

  void _flushPending() {
    if (_pendingCommands.isNotEmpty) {
      for (final cmd in _pendingCommands) {
        _executeCommand(cmd.trim());
      }
      _pendingCommands.clear();
    }
  }

  void setFilter(String query) {
    if (_filter == query) return;
    _filter = query;
    _refreshTerminal();
  }

  void _refreshTerminal() {
    terminal.buffer.clear();
    terminal.setCursor(0, 0);

    // Replay logs with filter
    // We treat log history as lines for filtering purposes
    for (final line in _logHistory) {
      if (_matchesFilter(line)) {
        terminal.write('$line\r\n');
      }
    }
    // Re-add partial line if it matches
    if (_partialLine.isNotEmpty && _matchesFilter(_partialLine)) {
      terminal.write(_partialLine);
    }
  }

  bool _matchesFilter(String line) {
    if (_filter == null || _filter!.isEmpty) return true;

    final isNegative = _filter!.startsWith('!');
    final query = isNegative ? _filter!.substring(1) : _filter!;

    if (query.isEmpty) return true;

    final matches = line.toLowerCase().contains(query.toLowerCase());
    return isNegative ? !matches : matches;
  }

  /// Custom write that handles logging and filtering
  void onDataReceived(String data) {
    // Debug print to ensure data is flowing
    // print('TerminalSession ${id} received: ${data.length} bytes');

    // Always append to log history for filtering/search
    // We append raw data to a buffer and split by lines
    _receivedBuffer += data;
    if (_receivedBuffer.contains('\n')) {
      final lines = _receivedBuffer.split('\n');
      // Keep the last part in buffer (it might be incomplete)
      _receivedBuffer = lines.last;
      // Add all complete lines to history
      for (var i = 0; i < lines.length - 1; i++) {
        _logHistory.add(lines[i]);
      }
    }

    // If no filter, write directly to terminal (FAST PATH)
    if (_filter == null || _filter!.isEmpty) {
      // Safely ensure \r\n for xterm.dart
      final normalized = data.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');
      terminal.write(normalized);
      return;
    }

    // If filter is active, we need to re-process the display
    // This is expensive, but necessary for filtering.
    // For now, if we are filtering, we only update based on lines.
    // Real-time filtering of partial lines is complex.
    _refreshTerminal();

    // Notify listeners
    _dataController.add(data);
  }

  TerminalSession({required this.id, required this.name, this.initialDirectory})
      : terminal = Terminal(maxLines: 10000),
        controller = TerminalController();

  final TerminalController controller;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'initialDirectory': initialDirectory,
    };
  }

  factory TerminalSession.fromJson(Map<String, dynamic> json) {
    return TerminalSession(
      id: json['id'] as String,
      name: json['name'] as String,
      initialDirectory: json['initialDirectory'] as String?,
    );
  }

  void dispose() {
    bridge = null;
    isConnected = false;
    state = SessionState.disconnected;
    _dataController.close();
  }
}

class TerminalSessionsState {
  final List<TerminalSession> sessions;
  final String? activeSessionId;

  TerminalSessionsState({this.sessions = const [], this.activeSessionId});

  TerminalSession? get activeSession {
    if (activeSessionId == null) return null;
    return sessions.firstWhere((s) => s.id == activeSessionId);
  }

  TerminalSessionsState copyWith({
    List<TerminalSession>? sessions,
    String? activeSessionId,
  }) {
    return TerminalSessionsState(
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
    );
  }
}

class TerminalSessionNotifier extends Notifier<TerminalSessionsState> {
  @override
  TerminalSessionsState build() {
    // Attempt restoration on init
    Future.microtask(() => restoreSessions());
    return TerminalSessionsState();
  }

  void addSession(TerminalSession session) {
    state = state.copyWith(
      sessions: [...state.sessions, session],
      activeSessionId: session.id,
    );
    saveSessions();
  }

  Future<String> createSession({String? name, String? initialDirectory}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = TerminalSession(
      id: id,
      name: name ?? 'Session ${state.sessions.length + 1}',
      initialDirectory: initialDirectory,
    );

    addSession(session);

    await connectSession(session);
    return id;
  }

  void selectSession(String id) {
    state = state.copyWith(activeSessionId: id);
  }

  void closeSession(String id) {
    final session = state.sessions.firstWhere((s) => s.id == id);
    session.dispose();

    final newSessions = state.sessions.where((s) => s.id != id).toList();
    String? newActiveId = state.activeSessionId;

    if (newActiveId == id) {
      newActiveId = newSessions.isNotEmpty ? newSessions.last.id : null;
    }

    state = state.copyWith(sessions: newSessions, activeSessionId: newActiveId);
    saveSessions();
  }

  Future<void> connectSession(TerminalSession session) async {
    session.state = SessionState.connecting;
    state = state.copyWith(); // Trigger rebuild

    // Small delay to ensure UI is ready to show the terminal
    await Future.delayed(const Duration(milliseconds: 100));
    session.onDataReceived(
        '\x1B[1;36mConnecting to Termux via Bridge...\x1B[0m\r\n');

    try {
      // Create TermuxBridge instance
      final bridge = TermuxBridge();
      session.bridge = bridge;

      session.onDataReceived(
          '\x1B[32m✔ Connected to Termux (via RUN_COMMAND)\x1B[0m\r\n');

      // Show initial directory
      final homeDir =
          session.initialDirectory ?? '/data/data/com.termux/files/home';
      session
          .onDataReceived('\x1B[1;34mWorking directory: $homeDir\x1B[0m\r\n');
      session.onDataReceived('\r\n\x1B[1;33m\$ \x1B[0m');

      // Wire up terminal input
      session.terminal.onOutput = (data) {
        session.write(data);
      };

      // Flush any pending commands
      session._flushPending();

      session.isConnected = true;
      session.state = SessionState.connected;
      state = state.copyWith();
    } catch (e) {
      session.terminal.write('\x1B[31mBridge Error: $e\x1B[0m\r\n');
      session.state = SessionState.failed;
      session.lastError = e.toString();
      state = state.copyWith();
    }
  }

  // [Persistence]
  Future<void> saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = state.sessions.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList('terminal_sessions', list);
    } catch (e) {
      print('Failed to save terminal sessions: $e');
    }
  }

  Future<void> restoreSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('terminal_sessions');
      if (list != null && list.isNotEmpty) {
        final sessions = list.map((s) => TerminalSession.fromJson(jsonDecode(s))).toList();
        state = state.copyWith(sessions: sessions, activeSessionId: sessions.isNotEmpty ? sessions.first.id : null);
        
        // Reconnect all restored sessions
        for (final session in sessions) {
           // Don't await individually to speed up UI
           connectSession(session);
        }
      }
    } catch (e) {
      print('Failed to restore terminal sessions: $e');
    }
  }
}

final terminalSessionsProvider =
    NotifierProvider<TerminalSessionNotifier, TerminalSessionsState>(
  TerminalSessionNotifier.new,
);
