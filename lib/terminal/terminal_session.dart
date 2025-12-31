import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import '../termux/termux_providers.dart';

enum SessionState {
  connecting,
  connected,
  disconnected,
  failed,
}

class TerminalSession {
  final String id;
  final String name;
  final Terminal terminal;
  final TerminalController controller;
  SSHClient? client;
  SSHSession? shell;
  SessionState state = SessionState.disconnected;
  String? lastError;

  TerminalSession({
    required this.id,
    required this.name,
  })  : terminal = Terminal(maxLines: 10000),
        controller = TerminalController();

  void dispose() {
    controller.dispose();
    client?.close();
  }
}

class TerminalSessionsState {
  final List<TerminalSession> sessions;
  final String? activeSessionId;

  TerminalSessionsState({
    this.sessions = const [],
    this.activeSessionId,
  });

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

  Future<void> createSession({String? name}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = TerminalSession(
      id: id,
      name: name ?? 'Session ${state.sessions.length + 1}',
    );

    state = state.copyWith(
      sessions: [...state.sessions, session],
      activeSessionId: id,
    );

    await connectSession(session);
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

    state = state.copyWith(
      sessions: newSessions,
      activeSessionId: newActiveId,
    );
  }

  Future<void> connectSession(TerminalSession session) async {
    session.state = SessionState.connecting;
    state = state.copyWith(); // Trigger rebuild

    session.terminal.write('Connecting to Termux via SSH...\r\n');

    try {
      final socket = await SSHSocket.connect('127.0.0.1', 8022)
          .timeout(const Duration(seconds: 3));

      session.terminal.write('Connected! Authenticating...\r\n');

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

      final width =
          session.terminal.viewWidth > 0 ? session.terminal.viewWidth : 80;
      final height =
          session.terminal.viewHeight > 0 ? session.terminal.viewHeight : 24;

      final shell = await client.shell(
        pty: SSHPtyConfig(
          width: width,
          height: height,
          type: 'xterm-256color',
        ),
      );
      session.shell = shell;
      session.state = SessionState.connected;
      state = state.copyWith(); // Rebuild UI

      session.terminal.write('\x1B[32m✔ Connected to Termux\x1B[0m\r\n');

      shell.stdout.listen((data) {
        session.terminal.write(String.fromCharCodes(data));
      });

      shell.stderr.listen((data) {
        session.terminal.write(String.fromCharCodes(data));
      });

      session.terminal.onOutput = (data) {
        if (!client.isClosed) {
          shell.write(Uint8List.fromList(utf8.encode(data)));
        }
      };

      session.terminal.onResize = (w, h, pw, ph) {
        shell.resizeTerminal(w, h);
      };

      await shell.done;
      session.terminal.write('\r\nSession closed.\r\n');
      session.state = SessionState.disconnected;
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
