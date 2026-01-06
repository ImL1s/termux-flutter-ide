import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../termux/termux_providers.dart';
import '../core/providers.dart';
import 'terminal_session.dart';
import 'terminal_quick_commands.dart';
import '../core/scrollable_with_scrollbar.dart';

/// Auto-scroll toggle for terminal output
final _autoScrollProvider = StateProvider<bool>((ref) => true);

class TerminalWidget extends ConsumerStatefulWidget {
  const TerminalWidget({super.key});

  @override
  ConsumerState<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends ConsumerState<TerminalWidget> {
  final ScrollController _tabBarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize first session if none exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSession();
    });
  }

  @override
  void dispose() {
    _tabBarScrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureSession() async {
    final sessions = ref.read(terminalSessionsProvider).sessions;
    if (sessions.isEmpty) {
      final installed = await ref.read(termuxInstalledProvider.future);
      if (installed) {
        final projectPath = ref.read(projectPathProvider);
        ref
            .read(terminalSessionsProvider.notifier)
            .createSession(initialDirectory: projectPath);
      }
    }

    // Check for pending commands manually on first build since ref.listen
    // might miss the initial change if the widget wasn't mounted.
    final cmd = ref.read(terminalCommandProvider);
    if (cmd != null) {
      _sendCommand(cmd);
      ref.read(terminalCommandProvider.notifier).clear();
    }
  }

  void _sendCommand(String cmd) {
    final activeSession = ref.read(terminalSessionsProvider).activeSession;
    if (activeSession != null) {
      activeSession.write('$cmd\n');
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
                  // Quick commands bar
                  const TerminalQuickCommands(),
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
            child: ScrollableWithScrollbar(
              controller: _tabBarScrollController,
              axis: Axis.horizontal,
              child: ListView.builder(
                controller: _tabBarScrollController,
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
                        color:
                            isActive ? AppTheme.editorBg : Colors.transparent,
                        border: Border(
                          right:
                              const BorderSide(color: AppTheme.surfaceVariant),
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
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
          ),
          // Auto-Scroll Toggle
          Consumer(
            builder: (context, ref, _) {
              final autoScroll = ref.watch(_autoScrollProvider);
              return IconButton(
                icon: Icon(
                  autoScroll ? Icons.vertical_align_bottom : Icons.pause,
                  size: 18,
                  color: autoScroll ? AppTheme.tertiary : Colors.grey,
                ),
                onPressed: () =>
                    ref.read(_autoScrollProvider.notifier).state = !autoScroll,
                tooltip: autoScroll ? 'Auto-Scroll On' : 'Auto-Scroll Off',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            onPressed: () {
              final projectPath = ref.read(projectPathProvider);
              ref
                  .read(terminalSessionsProvider.notifier)
                  .createSession(initialDirectory: projectPath);
            },
            tooltip: 'New Session',
          ),
        ],
      ),
    );
  }

  Widget _buildSessionView(TerminalSession session) {
    return Stack(
      children: [
        Padding(
          padding:
              const EdgeInsets.all(8.0), // Add padding for better readability
          child: TerminalView(
            session.terminal,
            controller: session.controller,
            autofocus: true,
            backgroundOpacity: 0,
            cursorType: TerminalCursorType.verticalBar,
            textStyle: const TerminalStyle(
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (session.state == SessionState.connecting)
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        if (session.state == SessionState.failed)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () => ref
                  .read(terminalSessionsProvider.notifier)
                  .connectSession(session),
              label: const Text('Retry Connection'),
              icon: const Icon(Icons.refresh),
              backgroundColor: AppTheme.error,
            ),
          ),
      ],
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
}
