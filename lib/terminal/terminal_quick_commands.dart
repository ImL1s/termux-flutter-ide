import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import 'terminal_session.dart';

/// Quick command definition
class QuickCommand {
  final String label;
  final IconData icon;
  final Color color;
  final String command;
  final String? tooltip;

  const QuickCommand({
    required this.label,
    required this.icon,
    required this.color,
    required this.command,
    this.tooltip,
  });
}

/// Predefined quick commands
const List<QuickCommand> _defaultCommands = [
  QuickCommand(
    label: 'run',
    icon: Icons.play_arrow,
    color: Color(0xFFA6E3A1), // Green
    command: 'flutter run',
    tooltip: 'flutter run',
  ),
  QuickCommand(
    label: 'pub get',
    icon: Icons.download,
    color: Color(0xFF89B4FA), // Blue
    command: 'flutter pub get',
    tooltip: 'flutter pub get',
  ),
  QuickCommand(
    label: 'clean',
    icon: Icons.cleaning_services,
    color: Color(0xFFF9E2AF), // Yellow
    command: 'flutter clean',
    tooltip: 'flutter clean',
  ),
  QuickCommand(
    label: 'build',
    icon: Icons.build,
    color: Color(0xFFCBA6F7), // Mauve
    command: 'flutter build apk',
    tooltip: 'flutter build apk',
  ),
  QuickCommand(
    label: 'test',
    icon: Icons.bug_report,
    color: Color(0xFFF38BA8), // Red/Pink
    command: 'flutter test',
    tooltip: 'flutter test',
  ),
];

/// Terminal quick commands bar widget
class TerminalQuickCommands extends ConsumerWidget {
  const TerminalQuickCommands({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 48,
      color: const Color(0xFF181825),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // Project path indicator
            Consumer(
              builder: (context, ref, _) {
                final projectPath = ref.watch(projectPathProvider);
                if (projectPath == null) return const SizedBox.shrink();

                final projectName = projectPath.split('/').last;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF313244),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.folder,
                          size: 14, color: Color(0xFFF9E2AF)),
                      const SizedBox(width: 6),
                      Text(
                        projectName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFBAC2DE),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Divider
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: const Color(0xFF45475A),
            ),

            // Quick command buttons
            ..._defaultCommands.map((cmd) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _QuickCommandButton(
                    command: cmd,
                    onPressed: () => _executeCommand(context, ref, cmd),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _executeCommand(BuildContext context, WidgetRef ref, QuickCommand cmd) {
    final projectPath = ref.read(projectPathProvider);

    if (projectPath == null) {
      // Try to report to terminal first for better visibility
      final activeSession = ref.read(terminalSessionsProvider).activeSession;
      if (activeSession != null) {
        activeSession.onDataReceived(
            '\x1B[31m[IDE] Error: No project open. Please open a project folder first.\x1B[0m\r\n');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先開啟專案 (Please open a project first)'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Send command to terminal
    ref.read(terminalCommandProvider.notifier).run(
          'cd "$projectPath" && ${cmd.command}',
        );
  }
}

class _QuickCommandButton extends StatelessWidget {
  final QuickCommand command;
  final VoidCallback onPressed;

  const _QuickCommandButton({
    required this.command,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: command.tooltip ?? command.command,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: command.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: command.color.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(command.icon, size: 16, color: command.color),
                const SizedBox(width: 6),
                Text(
                  command.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: command.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact version for inline use
class CompactQuickCommands extends ConsumerWidget {
  final Function(String command)? onCommandSelected;

  const CompactQuickCommands({super.key, this.onCommandSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _defaultCommands
          .take(4)
          .map((cmd) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: IconButton(
                  icon: Icon(cmd.icon, size: 18),
                  color: cmd.color,
                  tooltip: cmd.tooltip ?? cmd.command,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    if (onCommandSelected != null) {
                      onCommandSelected!(cmd.command);
                    } else {
                      final projectPath = ref.read(projectPathProvider);
                      if (projectPath != null) {
                        ref.read(terminalCommandProvider.notifier).run(
                              'cd "$projectPath" && ${cmd.command}',
                            );
                      }
                    }
                  },
                ),
              ))
          .toList(),
    );
  }
}
