import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../termux/termux_providers.dart';
import '../core/providers.dart';
import 'terminal_session.dart';

class TerminalWidget extends ConsumerStatefulWidget {
  const TerminalWidget({super.key});

  @override
  ConsumerState<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends ConsumerState<TerminalWidget> {
  @override
  void initState() {
    super.initState();
    // Initialize first session if none exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSession();
    });
  }

  Future<void> _ensureSession() async {
    final sessions = ref.read(terminalSessionsProvider).sessions;
    if (sessions.isEmpty) {
      final installed = await ref.read(termuxInstalledProvider.future);
      if (installed) {
        ref.read(terminalSessionsProvider.notifier).createSession();
      }
    }
  }

  void _sendCommand(String cmd) {
    final activeSession = ref.read(terminalSessionsProvider).activeSession;
    if (activeSession != null &&
        activeSession.shell != null &&
        activeSession.client != null &&
        !activeSession.client!.isClosed) {
      activeSession.shell!.write(Uint8List.fromList(utf8.encode('$cmd\r')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsState = ref.watch(terminalSessionsProvider);
    final activeSession = sessionsState.activeSession;

    // Listen for external commands (like from Run button)
    ref.listen(terminalCommandProvider, (previous, next) {
      if (next != null) {
        _sendCommand(next);
        ref.read(terminalCommandProvider.notifier).clear();
      }
    });

    // Check if termux is installed
    return ref.watch(termuxInstalledProvider).when(
          data: (installed) {
            if (!installed) return _buildTermuxMissingUI();
            if (sessionsState.sessions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return Container(
              color: AppTheme.editorBg,
              child: Column(
                children: [
                  _buildTabBar(sessionsState),
                  Expanded(
                    child: activeSession == null
                        ? const Center(child: Text('No active session'))
                        : _buildSessionView(activeSession),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        );
  }

  Widget _buildTabBar(TerminalSessionsState state) {
    return Container(
      height: 40,
      color: AppTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.sessions.length,
              itemBuilder: (context, index) {
                final session = state.sessions[index];
                final isActive = session.id == state.activeSessionId;

                return GestureDetector(
                  onTap: () => ref
                      .read(terminalSessionsProvider.notifier)
                      .selectSession(session.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.editorBg : Colors.transparent,
                      border: Border(
                        right: const BorderSide(color: AppTheme.surfaceVariant),
                        bottom: BorderSide(
                          color: isActive
                              ? AppTheme.secondary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.terminal : Icons.terminal_outlined,
                          size: 14,
                          color: isActive ? AppTheme.secondary : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          session.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive ? Colors.white : Colors.grey,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isActive && state.sessions.length > 1)
                          GestureDetector(
                            onTap: () => ref
                                .read(terminalSessionsProvider.notifier)
                                .closeSession(session.id),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () =>
                ref.read(terminalSessionsProvider.notifier).createSession(),
            tooltip: 'New Session',
          ),
        ],
      ),
    );
  }

  Widget _buildSessionView(TerminalSession session) {
    if (session.state == SessionState.connecting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Connecting to ${session.name}...'),
          ],
        ),
      );
    }

    if (session.state == SessionState.failed) {
      return _buildSSHFailedUI(session);
    }

    return TerminalView(
      session.terminal,
      controller: session.controller,
      autofocus: true,
      backgroundOpacity: 0,
      textStyle: const TerminalStyle(
        fontSize: 13,
        fontFamily: 'JetBrains Mono',
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
              onPressed: () => ref.invalidate(termuxInstalledProvider),
              child: const Text('I have installed it, Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSSHFailedUI(TerminalSession session) {
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
              Text(
                'Connection Failed: ${session.name}',
                style: const TextStyle(
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
              if (session.lastError != null) ...[
                const SizedBox(height: 8),
                Text(
                  session.lastError!.length > 80
                      ? '${session.lastError!.substring(0, 80)}...'
                      : session.lastError!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.read(termuxBridgeProvider).openTermux(),
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
                  ref
                      .read(terminalSessionsProvider.notifier)
                      .connectSession(session);
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
