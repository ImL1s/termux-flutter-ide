import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import '../termux/termux_providers.dart';

enum SessionState { connecting, connected, disconnected, failed }

class TerminalSession {
  final String id;
  final String name;
  final String? initialDirectory;
  final Terminal terminal;
  SSHClient? client;
  SSHSession? shell;
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

  void write(String data) {
    if (state == SessionState.connected && shell != null) {
      shell!.write(Uint8List.fromList(utf8.encode(data)));
    } else {
      _pendingCommands.add(data);
      terminal.write('\x1B[1;30m[IDE] Command queued: $data\x1B[0m\r\n');
    }
  }

  void _flushPending() {
    if (shell != null) {
      for (final cmd in _pendingCommands) {
        terminal.write('\x1B[1;33m[IDE] Executing queued: $cmd\x1B[0m\r\n');
        shell!.write(Uint8List.fromList(utf8.encode('$cmd\n')));
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

  void dispose() {
    client?.close();
    client = null;
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
    // Start with one session
    return TerminalSessionsState();
  }

  void addSession(TerminalSession session) {
    state = state.copyWith(
      sessions: [...state.sessions, session],
      activeSessionId: session.id,
    );
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
  }

  Future<void> connectSession(TerminalSession session) async {
    session.state = SessionState.connecting;
    state = state.copyWith(); // Trigger rebuild

    // Small delay to ensure UI is ready to show the terminal
    await Future.delayed(const Duration(milliseconds: 100));
    session.onDataReceived(
      '\x1B[1;36mConnecting to Termux via SSH...\x1B[0m\r\n',
    );

    try {
      final socket = await SSHSocket.connect(
        '127.0.0.1',
        8022,
      ).timeout(const Duration(seconds: 3));

      session.onDataReceived('Connected! Authenticating...\r\n');

      final bridge = ref.read(termuxBridgeProvider);
      final uid = await bridge.getTermuxUid();
      String username = 'u0_a251';

      if (uid != null && uid >= 10000) {
        username = 'u0_a${uid - 10000}';
      }

      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => '123456',
      );
      session.client = client;

      final width = session.terminal.viewWidth > 0
          ? session.terminal.viewWidth
          : 80;
      final height = session.terminal.viewHeight > 0
          ? session.terminal.viewHeight
          : 24;

      final shell = await client.shell(
        pty: SSHPtyConfig(width: width, height: height, type: 'xterm-256color'),
      );
      session.shell = shell;
      // Note: state remains .connecting during initial setup (cd)

      session.onDataReceived(
        '\x1B[32m✔ Connected to Termux\x1B[0m\r\n',
      ); // Listen for data

      shell.stdout.listen((data) {
        session.onDataReceived(utf8.decode(data, allowMalformed: true));
      });

      shell.stderr.listen((data) {
        session.onDataReceived(utf8.decode(data, allowMalformed: true));
      });

      // Wire up terminal input
      session.terminal.onOutput = (data) {
        if (session.shell != null) {
          session.shell!.write(Uint8List.fromList(utf8.encode(data)));
        }
      };

      // Handle terminal resize
      session.terminal.onResize = (w, h, pw, ph) {
        if (session.shell != null) {
          session.shell!.resizeTerminal(w, h);
        }
      };

      // Handle session termination
      shell.done.then((_) {
        session.state = SessionState.disconnected;
        state = state.copyWith();
      });

      // 4. Send initial working directory if set
      if (session.initialDirectory != null) {
        shell.write(
          Uint8List.fromList(utf8.encode('cd "${session.initialDirectory}"\n')),
        );
      }

      // 5. Flush any commands sent while connecting
      // We do this AFTER initial directory setup to avoid collisions
      session._flushPending();

      session.state = SessionState.connected;
      state = state.copyWith();
    } catch (e) {
      session.terminal.write('\x1B[31mSSH Error: $e\x1B[0m\r\n');
      session.state = SessionState.failed;
      session.lastError = e.toString();
      state = state.copyWith();
    }
  }
}

final terminalSessionsProvider =
    NotifierProvider<TerminalSessionNotifier, TerminalSessionsState>(
      TerminalSessionNotifier.new,
    );
