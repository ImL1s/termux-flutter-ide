import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../termux/termux_providers.dart';

enum TerminalConnectionState {
  checking,
  termuxMissing,
  sshConnecting,
  sshFailed,
  connected,
}

class TerminalWidget extends ConsumerStatefulWidget {
  const TerminalWidget({super.key});

  @override
  ConsumerState<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends ConsumerState<TerminalWidget> {
  late final Terminal _terminal;
  final _terminalController = TerminalController();

  SSHClient? _client;
  TerminalConnectionState _connectionState = TerminalConnectionState.checking;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndConnect();
    });
  }

  Future<void> _checkAndConnect() async {
    setState(() {
      _connectionState = TerminalConnectionState.checking;
      _lastError = null;
    });

    final installed = await ref.read(termuxInstalledProvider.future);
    if (!installed) {
      if (mounted) {
        setState(() {
          _connectionState = TerminalConnectionState.termuxMissing;
        });
      }
      return;
    }

    _connectToTermux();
  }

  Future<void> _connectToTermux() async {
    setState(() {
      _connectionState = TerminalConnectionState.sshConnecting;
    });

    _terminal.write('Connecting to Termux via SSH...\\r\\n');

    try {
      final socket = await SSHSocket.connect('127.0.0.1', 8022)
          .timeout(const Duration(seconds: 3));

      _terminal.write('Connected! Authenticating...\\r\\n');

      final bridge = ref.read(termuxBridgeProvider);
      final uid = await bridge.getTermuxUid();
      String username = 'u0_a251';

      if (uid != null && uid >= 10000) {
        username = 'u0_a${uid - 10000}';
      }

      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => '123456',
      );

      final width = _terminal.viewWidth > 0 ? _terminal.viewWidth : 80;
      final height = _terminal.viewHeight > 0 ? _terminal.viewHeight : 24;

      final session = await _client!.shell(
        pty: SSHPtyConfig(
          width: width,
          height: height,
          type: 'xterm-256color',
        ),
      );

      setState(() {
        _connectionState = TerminalConnectionState.connected;
      });

      _terminal
          .write('\\x1B[32m✔ Connected to Termux Environment\\x1B[0m\\r\\n');
      _terminal.write('Type "exit" to close session.\\r\\n\\r\\n');

      session.stdout.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      session.stderr.listen((data) {
        _terminal.write(String.fromCharCodes(data));
      });

      _terminal.onOutput = (data) {
        if (_client != null && !_client!.isClosed) {
          session.write(Uint8List.fromList(utf8.encode(data)));
        }
      };

      _terminal.onResize = (w, h, pw, ph) {
        session.resizeTerminal(w, h);
      };

      await session.done;
      _terminal.write('\\r\\nSession closed.\\r\\n');
    } catch (e) {
      _terminal.write('\\x1B[31mSSH Error: $e\\x1B[0m\\r\\n');
      if (mounted) {
        setState(() {
          _connectionState = TerminalConnectionState.sshFailed;
          _lastError = e.toString();
        });
      }
    }
  }

  Future<void> _launchTermux() async {
    final bridge = ref.read(termuxBridgeProvider);
    await bridge.openTermux();
  }

  @override
  void dispose() {
    _terminalController.dispose();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show Termux missing state
    if (_connectionState == TerminalConnectionState.termuxMissing) {
      return _buildTermuxMissingUI();
    }

    // Show SSH failed state with Launch Termux button
    if (_connectionState == TerminalConnectionState.sshFailed) {
      return _buildSSHFailedUI();
    }

    return Container(
      color: AppTheme.editorBg,
      child: Column(
        children: [
          _buildHeader(),
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

  Widget _buildHeader() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceVariant),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 14, color: AppTheme.secondary),
          const SizedBox(width: 8),
          Text(
            _connectionState == TerminalConnectionState.sshConnecting
                ? 'CONNECTING...'
                : 'TERMINAL (Termux SSH)',
            style: const TextStyle(
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
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            color: AppTheme.textDisabled,
          ),
        ],
      ),
    );
  }

  Widget _buildTermuxMissingUI() {
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
                fontWeight: FontWeight.bold,
              ),
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
                  mode: LaunchMode.externalApplication,
                );
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
              onPressed: _checkAndConnect,
              child: const Text('I have installed it, Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSSHFailedUI() {
    return Container(
      color: AppTheme.editorBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'SSH Connection Failed',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Termux needs to be running with SSH server started.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (_lastError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _lastError!.length > 80
                      ? '${_lastError!.substring(0, 80)}...'
                      : _lastError!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _launchTermux,
                icon: const Icon(Icons.launch),
                label: const Text('Open Termux App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Open Termux\n2. Type "sshd" and press Enter\n3. Come back here and clicking Retry',
                style: TextStyle(color: AppTheme.textDisabled, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _terminal.eraseDisplay();
                  _connectToTermux();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Connection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.secondary,
                  side: const BorderSide(color: AppTheme.secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
