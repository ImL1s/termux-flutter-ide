import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'launch_config.dart';
import 'flutter_runner_service.dart';
import 'runner_actions.dart';
import 'x11_missing_dialog.dart';
import '../terminal/terminal_session.dart';
import '../core/providers.dart';
import '../file_manager/file_operations.dart';
import '../termux/ssh_error_dialog.dart';

// VS Code Dark+ Theme Colors
class VSCodeTerminalTheme {
  static const theme = TerminalTheme(
    cursor: Color(0xFFAEAFAD),
    selection: Color(0xFF264F78),
    foreground: Color(0xFFCCCCCC),
    background: Color(0xFF1E1E1E),
    black: Color(0xFF000000),
    red: Color(0xFFCD3131),
    green: Color(0xFF0DBC79),
    yellow: Color(0xFFE5E510),
    blue: Color(0xFF2472C8),
    magenta: Color(0xFFBC3FBC),
    cyan: Color(0xFF11A8CD),
    white: Color(0xFFE5E5E5),
    brightBlack: Color(0xFF666666),
    brightRed: Color(0xFFF14C4C),
    brightGreen: Color(0xFF23D18B),
    brightYellow: Color(0xFFF5F543),
    brightBlue: Color(0xFF3B8EEA),
    brightMagenta: Color(0xFFD670D6),
    brightCyan: Color(0xFF29B8DB),
    brightWhite: Color(0xFFE5E5E5),
    searchHitBackground: Color(0xFF515C6A),
    searchHitBackgroundCurrent: Color(0xFFEA5C00),
    searchHitForeground: Color(0xFFE5E5E5),
  );
}

class FlutterRunnerWidget extends ConsumerWidget {
  const FlutterRunnerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(launchConfigurationsProvider);
    final selectedConfig = ref.watch(selectedLaunchConfigProvider);
    final activeSessionId = ref.watch(activeRunnerSessionIdProvider);
    final sessionsState = ref.watch(terminalSessionsProvider);
    final runnerState = ref.watch(runnerStateProvider);
    final runnerError = ref.watch(runnerErrorProvider);

    // Listen for actions from Service
    ref.listen(runnerActionProvider, (previous, next) {
      print('FlutterRunnerWidget: Action received: ${next?.type}');
      if (next != null) {
        if (next.type == RunnerActionType.missingX11) {
          print('FlutterRunnerWidget: Showing Dialog...');
          showDialog(
            context: context,
            builder: (context) => const X11MissingDialog(),
          );
        }
        // Consume action
        ref.read(runnerActionProvider.notifier).setAction(null);
      }
    });

    // Listen for SSH authentication errors to show helpful dialog
    ref.listen(runnerErrorProvider, (previous, next) {
      if (next != null &&
          next.contains('SSH') &&
          (next.contains('認證') ||
              next.contains('連線失敗') ||
              next.contains('auth'))) {
        // Show SSH error dialog with fix instructions
        showSSHErrorDialog(
          context,
          errorMessage: next,
          onRetry: () {
            // Clear error and retry connection
            ref.read(runnerErrorProvider.notifier).setError(null);
            final selectedConfig = ref.read(selectedLaunchConfigProvider);
            if (selectedConfig != null) {
              ref.read(flutterRunnerServiceProvider).run(selectedConfig);
            }
          },
        );
      }
    });

    final activeSession =
        sessionsState.sessions.cast<TerminalSession?>().firstWhere(
              (s) => s?.id == activeSessionId,
              orElse: () => null,
            );

    return Column(
      children: [
        // Error Banner
        if (runnerError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.red.withOpacity(0.2),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    runnerError,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 16),
                  onPressed: () =>
                      ref.read(runnerErrorProvider.notifier).setError(null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 16,
                ),
              ],
            ),
          ),

        // Toolbar
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          color: const Color(0xFF1E1E2E), // Match theme
          child: Row(
            children: [
              // Config Selector
              Expanded(
                child: configsAsync.when(
                  data: (configs) {
                    if (configs.isEmpty) {
                      return const Text('No Configurations',
                          style: TextStyle(color: Colors.grey));
                    }
                    // Select first if none selected
                    final current = selectedConfig ?? configs.first;
                    if (selectedConfig == null) {
                      // Schedule update
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref
                            .read(selectedLaunchConfigProvider.notifier)
                            .select(configs.first);
                      });
                    }

                    return DropdownButton<LaunchConfiguration>(
                      value:
                          configs.contains(current) ? current : configs.first,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2E2E3E),
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      icon:
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      items: configs.map((config) {
                        return DropdownMenuItem<LaunchConfiguration>(
                          value: config,
                          child: Text(config.name),
                        );
                      }).toList(),
                      onChanged: (config) {
                        ref
                            .read(selectedLaunchConfigProvider.notifier)
                            .select(config);
                      },
                    );
                  },
                  loading: () => const SizedBox(
                      width: 100, child: LinearProgressIndicator()),
                  error: (e, _) =>
                      const Icon(Icons.error_outline, color: Colors.red),
                ),
              ),
              const SizedBox(width: 8),

              // Edit Config
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 20, color: Colors.grey),
                onPressed: () async {
                  final projectPath = ref.read(projectPathProvider);
                  if (projectPath != null) {
                    final configPath = '$projectPath/.termux-ide/launch.json';
                    final fileOps = ref.read(fileOperationsProvider);

                    try {
                      // Check if config exists via SSH
                      final existingContent =
                          await fileOps.readFile(configPath);
                      if (existingContent == null) {
                        // Create directory and default config via SSH
                        await fileOps
                            .createDirectory('$projectPath/.termux-ide');
                        await fileOps.writeFile(
                            configPath, defaultLaunchJsonTemplate);
                        // Force refresh providers (result intentionally ignored)
                        // ignore: unused_result
                        ref.refresh(launchConfigurationsProvider);
                      }

                      ref.read(openFilesProvider.notifier).add(configPath);
                      ref.read(currentFileProvider.notifier).select(configPath);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to open config: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No project open'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                tooltip: 'Edit Configurations',
              ),

              // ADB Connect Helper
              IconButton(
                icon: const Icon(Icons.wifi_tethering,
                    size: 20, color: Colors.grey),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      final ipController = TextEditingController();
                      return AlertDialog(
                        title: const Text('ADB Wireless Connect'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Enter IP:Port (e.g. 192.168.1.5:5555)'),
                            TextField(
                              controller: ipController,
                              decoration:
                                  const InputDecoration(hintText: 'IP:Port'),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              final target = ipController.text.trim();
                              if (target.isNotEmpty) {
                                ref
                                    .read(terminalCommandProvider.notifier)
                                    .run('adb connect $target');
                              }
                              Navigator.pop(context);
                            },
                            child: const Text('Connect'),
                          ),
                        ],
                      );
                    },
                  );
                },
                tooltip: 'ADB Connect',
              ),

              const VerticalDivider(
                  width: 20, thickness: 1, color: Colors.white10),

              // Run / Stop Controls
              if (runnerState != RunnerState.running &&
                  runnerState != RunnerState.connecting)
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                  onPressed: selectedConfig != null
                      ? () {
                          ref
                              .read(flutterRunnerServiceProvider)
                              .run(selectedConfig);
                        }
                      : null,
                  tooltip: 'Run',
                  key: const Key('run_app_button'),
                )
              else if (runnerState == RunnerState.connecting)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                IconButton(
                  icon: const Icon(Icons.flash_on, color: Colors.amber),
                  onPressed: () =>
                      ref.read(flutterRunnerServiceProvider).hotReload(),
                  tooltip: 'Hot Reload (r)',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.green),
                  onPressed: () =>
                      ref.read(flutterRunnerServiceProvider).hotRestart(),
                  tooltip: 'Hot Restart (R)',
                ),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.red),
                  onPressed: () =>
                      ref.read(flutterRunnerServiceProvider).stop(),
                  tooltip: 'Stop',
                ),
              ],
            ],
          ),
        ),
        const Divider(
            height: 1, color: Color(0xFF2B2B2B)), // VS Code border color

        // VS Code Style Header
        Container(
          height: 44, // Comfortable touch target height
          color: const Color(0xFF1E1E1E),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Debug Console',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              // Filter Bar
              Expanded(
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C3C3C),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFF3C3C3C)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 6),
                      const Icon(Icons.filter_list,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          textAlignVertical: TextAlignVertical.center,
                          decoration: const InputDecoration(
                            hintText: 'Filter',
                            hintStyle: TextStyle(
                                color: Color(0xFFAAAAAA), fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.zero, // Let align center handle it
                            isCollapsed: true, // Specific for tight spaces
                          ),
                          onChanged: (value) {
                            if (activeSession != null) {
                              activeSession.setFilter(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Header Actions
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Colors.grey),
                onPressed: () => activeSession?.terminal.buffer.clear(),
                tooltip: 'Clear Console',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        // Terminal View
        Expanded(
          child: activeSession != null
              ? TerminalView(
                  activeSession.terminal,
                  key: const Key('runner_terminal_view'),
                  controller: activeSession.controller,
                  theme: VSCodeTerminalTheme.theme,
                  textStyle: const TerminalStyle(fontSize: 12),
                )
              : Center(
                  child: InkWell(
                    onTap: selectedConfig != null
                        ? () {
                            ref
                                .read(flutterRunnerServiceProvider)
                                .run(selectedConfig);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline,
                              key: const Key('run_app_center_button'),
                              size: 48,
                              color: selectedConfig != null
                                  ? Colors.green.withOpacity(0.8)
                                  : Colors.white24),
                          const SizedBox(height: 16),
                          Text(
                            selectedConfig != null
                                ? 'Run ${selectedConfig.name}'
                                : 'Select a configuration and press Run',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
