import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'native_terminal_service.dart';

/// A terminal widget backed by a native PTY session for full interactive support.
/// Supports vim, less, htop, and other interactive CLI programs.
class NativeTerminalWidget extends ConsumerStatefulWidget {
  final String? initialCwd;
  final String? shellPath;
  final VoidCallback? onSessionEnded;

  const NativeTerminalWidget({
    super.key,
    this.initialCwd,
    this.shellPath,
    this.onSessionEnded,
  });

  @override
  ConsumerState<NativeTerminalWidget> createState() =>
      _NativeTerminalWidgetState();
}

class _NativeTerminalWidgetState extends ConsumerState<NativeTerminalWidget> {
  final _terminal = Terminal(maxLines: 10000);
  final _terminalController = TerminalController();

  String? _sessionId;
  String _title = 'Terminal';
  bool _isRunning = false;

  StreamSubscription<TerminalOutputEvent>? _outputSub;
  StreamSubscription<TerminalTitleEvent>? _titleSub;
  StreamSubscription<TerminalFinishedEvent>? _finishedSub;
  StreamSubscription<String>? _bellSub;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final service = ref.read(nativeTerminalServiceProvider);

    // Listen to events
    _outputSub = service.onOutput.listen(_handleOutput);
    _titleSub = service.onTitleChanged.listen(_handleTitleChange);
    _finishedSub = service.onSessionFinished.listen(_handleSessionFinished);
    _bellSub = service.onBell.listen(_handleBell);

    // Create native session
    try {
      _sessionId = await service.createSession(
        cwd: widget.initialCwd,
        shellPath: widget.shellPath,
      );

      // Initialize with default size, will be updated on layout
      await service.initializeSession(_sessionId!, columns: 80, rows: 24);

      setState(() {
        _isRunning = true;
      });

      // Set up terminal input handler
      _terminal.onOutput = (data) {
        if (_sessionId != null) {
          service.writeToSession(_sessionId!, data);
        }
      };
    } catch (e) {
      _terminal.write('Failed to create native terminal session: $e\r\n');
    }
  }

  void _handleOutput(TerminalOutputEvent event) {
    if (event.sessionId == _sessionId) {
      // The native layer sends full screen buffer, we need to handle this smartly
      // For now, write as received - in production you'd sync with emulator state
      _terminal.write(event.output);
    }
  }

  void _handleTitleChange(TerminalTitleEvent event) {
    if (event.sessionId == _sessionId) {
      setState(() {
        _title = event.title;
      });
    }
  }

  void _handleSessionFinished(TerminalFinishedEvent event) {
    if (event.sessionId == _sessionId) {
      setState(() {
        _isRunning = false;
      });
      _terminal.write(
          '\r\n[Process completed with exit code ${event.exitCode}]\r\n');
      widget.onSessionEnded?.call();
    }
  }

  void _handleBell(String sessionId) {
    if (sessionId == _sessionId) {
      // Play haptic feedback or audio bell
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _outputSub?.cancel();
    _titleSub?.cancel();
    _finishedSub?.cancel();
    _bellSub?.cancel();

    // Close native session
    if (_sessionId != null) {
      ref.read(nativeTerminalServiceProvider).closeSession(_sessionId!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFF1E1E2E),
          child: Row(
            children: [
              Icon(
                _isRunning ? Icons.terminal : Icons.terminal_outlined,
                size: 16,
                color: _isRunning
                    ? const Color(0xFFA6E3A1)
                    : const Color(0xFFF38BA8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _title,
                  style: const TextStyle(
                    color: Color(0xFFCDD6F4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_isRunning)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  color: const Color(0xFF89B4FA),
                  onPressed: () {
                    // Clear screen using ANSI escape sequence
                    _terminal.write('\x1b[2J\x1b[H');
                    _initSession();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Restart Session',
                ),
            ],
          ),
        ),
        // Terminal view
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Update terminal size on layout change
              _updateTerminalSize(constraints);

              return TerminalView(
                _terminal,
                controller: _terminalController,
                autofocus: true,
                backgroundOpacity: 1.0,
                padding: const EdgeInsets.all(4),
                theme: const TerminalTheme(
                  cursor: Color(0xFFF5E0DC),
                  selection: Color(0x40F5E0DC),
                  foreground: Color(0xFFCDD6F4),
                  background: Color(0xFF1E1E2E),
                  black: Color(0xFF45475A),
                  red: Color(0xFFF38BA8),
                  green: Color(0xFFA6E3A1),
                  yellow: Color(0xFFF9E2AF),
                  blue: Color(0xFF89B4FA),
                  magenta: Color(0xFFCBA6F7),
                  cyan: Color(0xFF94E2D5),
                  white: Color(0xFFBAC2DE),
                  brightBlack: Color(0xFF585B70),
                  brightRed: Color(0xFFF38BA8),
                  brightGreen: Color(0xFFA6E3A1),
                  brightYellow: Color(0xFFF9E2AF),
                  brightBlue: Color(0xFF89B4FA),
                  brightMagenta: Color(0xFFCBA6F7),
                  brightCyan: Color(0xFF94E2D5),
                  brightWhite: Color(0xFFA6ADC8),
                  searchHitBackground: Color(0xFFF9E2AF),
                  searchHitBackgroundCurrent: Color(0xFFFAB387),
                  searchHitForeground: Color(0xFF1E1E2E),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateTerminalSize(BoxConstraints constraints) {
    if (_sessionId == null || !_isRunning) return;

    // Estimate character dimensions based on typical monospace font
    const charWidth = 8.0;
    const charHeight = 16.0;

    final cols = (constraints.maxWidth / charWidth).floor().clamp(40, 300);
    final rows = (constraints.maxHeight / charHeight).floor().clamp(10, 100);

    // Debounce resize calls
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_sessionId != null && _isRunning) {
        ref.read(nativeTerminalServiceProvider).resizeSession(
              _sessionId!,
              columns: cols,
              rows: rows,
            );
      }
    });
  }
}
