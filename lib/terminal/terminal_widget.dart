import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart'; // Import DartSSH2
import 'dart:convert'; // Import Convert
import 'dart:typed_data'; // For Uint8List
import 'package:url_launcher/url_launcher.dart'; // For launching F-Droid
import '../theme/app_theme.dart';
import '../termux/termux_providers.dart';

class TerminalWidget extends ConsumerStatefulWidget {
  const TerminalWidget({super.key});

  @override
  ConsumerState<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends ConsumerState<TerminalWidget> {
  late final Terminal _terminal;
  final _terminalController = TerminalController();

  SSHClient? _client;
  bool _isTermuxMissing = false;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
    );

    // Initialize SSH
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndConnect();
    });
  }

  Future<void> _checkAndConnect() async {
    final installed = await ref.read(termuxInstalledProvider.future);
    // DEBUG: Always write status to terminal
    _terminal.write('Debug: Termux Installed Check = $installed\r\n');

    if (!installed) {
      if (mounted) {
        setState(() {
          _isTermuxMissing = true;
        });
      }
      return;
    }

    _connectToTermux();
  }

  Future<void> _connectToTermux({int retryCount = 0}) async {
    _terminal.write('Connecting to Termux via SSH...\r\n');

    try {
      // Connect to localhost:8022 (Standard Termux SSH port)
      // Timeout is crucial here to detect if SSHD is not running quickly
      final socket = await SSHSocket.connect('127.0.0.1', 8022)
          .timeout(const Duration(seconds: 2));

      _terminal.write('Connected! Authenticating...\r\n');

      _client = SSHClient(
        socket,
        username: 'u0_a251', // Termux user
        onPasswordRequest: () {
          return 'termux'; // Auto-filled password from our bootstrap script
        },
      );

      _terminal.write('Starting shell...\r\n');

      final session = await _client!.shell(
        pty: SSHPtyConfig(
          width: _terminal.viewWidth,
          height: _terminal.viewHeight,
          type: 'xterm-256color',
        ),
      );

      _terminal.write('\x1B[32m✔ Connected to Termux Environment\x1B[0m\r\n');
      _terminal.write('Type "exit" to close session.\r\n\r\n');

      // Pipe output
      session.stdout.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      session.stderr.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      // Write input to SSH
      _terminal.onOutput = (data) {
        if (_client != null && !_client!.isClosed) {
          session.write(Uint8List.fromList(utf8.encode(data)));
        }
      };

      // Handle resize
      _terminal.onResize = (w, h, pw, ph) {
        session.resizeTerminal(w, h);
      };

      await session.done;
      _terminal.write('\r\nSession Connection Closed.\r\n');
    } catch (e) {
      if (retryCount == 0) {
        _terminal.write(
            '\x1B[33mConnection failed. Attempting Auto-Bootstrap...\x1B[0m\r\n');
        _terminal.write(
            '(This may take a minute to install OpenSSH in background)\r\n');

        // Trigger Auto-Setup
        final bridge = ref.read(termuxBridgeProvider);
        await bridge.setupTermuxSSH();

        _terminal.write('Waiting for Termux setup (10s)...\r\n');
        await Future.delayed(const Duration(seconds: 10));

        // Retry
        _connectToTermux(retryCount: 1);
      } else {
        _terminal.write(
            '\r\n\x1B[31mError: Could not connect to Termux.\x1B[0m\r\n');
        _terminal
            .write('Make sure Termux app is running in the background.\r\n');
      }
    }
  }

  @override
  void dispose() {
    _terminalController.dispose();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isTermuxMissing) {
      return Container(
        color: AppTheme.editorBg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 16),
              const Text(
                'Termux Not Installed',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This IDE requires Termux to provide a Linux environment.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  launchUrl(
                      Uri.parse('https://f-droid.org/packages/com.termux/'),
                      mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.download),
                label: const Text('Install Termux (F-Droid)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isTermuxMissing = false;
                  });
                  _checkAndConnect();
                },
                child: const Text('I have installed it, Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: AppTheme.editorBg,
      child: Column(
        children: [
          // Terminal header
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.surfaceVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal,
                  size: 14,
                  color: AppTheme.secondary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'TERMINAL (Termux SSH)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () {
                    _client?.close();
                    _terminal.eraseDisplay();
                    _checkAndConnect();
                  },
                  tooltip: 'Reconnect',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  color: AppTheme.textDisabled,
                ),
              ],
            ),
          ),
          // Terminal content
          Expanded(
            child: TerminalView(
              _terminal,
              controller: _terminalController,
              autofocus: true,
              backgroundOpacity: 0,
              textStyle: const TerminalStyle(
                fontSize: 13,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
