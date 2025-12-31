import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'flutter_runner_service.dart';

/// Floating Hot Reload control bar
class HotReloadControls extends ConsumerWidget {
  const HotReloadControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runnerState = ref.watch(runnerStateProvider);
    final runnerService = ref.watch(flutterRunnerServiceProvider);

    // Only show when running
    if (runnerState != RunnerState.running) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFF45475A),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hot Reload Button
              _ControlButton(
                icon: Icons.bolt,
                label: 'Hot Reload',
                color: const Color(0xFFF9E2AF), // Yellow
                onPressed: () => runnerService.hotReload(),
                shortcut: 'r',
              ),

              const SizedBox(width: 4),

              // Hot Restart Button
              _ControlButton(
                icon: Icons.refresh,
                label: 'Restart',
                color: const Color(0xFF89B4FA), // Blue
                onPressed: () => runnerService.hotRestart(),
                shortcut: 'R',
              ),

              const SizedBox(width: 4),

              // Stop Button
              _ControlButton(
                icon: Icons.stop,
                label: 'Stop',
                color: const Color(0xFFF38BA8), // Red
                onPressed: () => runnerService.stop(),
                shortcut: 'q',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final String shortcut;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    required this.shortcut,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label ($shortcut)',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

/// Compact inline controls for embedding in headers
class InlineHotReloadControls extends ConsumerWidget {
  const InlineHotReloadControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runnerState = ref.watch(runnerStateProvider);
    final runnerService = ref.watch(flutterRunnerServiceProvider);

    if (runnerState != RunnerState.running) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.bolt, size: 20),
          color: const Color(0xFFF9E2AF),
          tooltip: 'Hot Reload (r)',
          onPressed: () => runnerService.hotReload(),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          color: const Color(0xFF89B4FA),
          tooltip: 'Hot Restart (R)',
          onPressed: () => runnerService.hotRestart(),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.stop, size: 20),
          color: const Color(0xFFF38BA8),
          tooltip: 'Stop (q)',
          onPressed: () => runnerService.stop(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// Status indicator chip showing current run state
class RunStateIndicator extends ConsumerWidget {
  const RunStateIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runnerState = ref.watch(runnerStateProvider);

    if (runnerState == RunnerState.idle) {
      return const SizedBox.shrink();
    }

    final (icon, color, label) = switch (runnerState) {
      RunnerState.connecting => (
          Icons.hourglass_empty,
          const Color(0xFFF9E2AF),
          '連線中...'
        ),
      RunnerState.running => (Icons.play_arrow, const Color(0xFFA6E3A1), '執行中'),
      RunnerState.stopped => (
          Icons.stop_circle,
          const Color(0xFFBAC2DE),
          '已停止'
        ),
      RunnerState.error => (Icons.error, const Color(0xFFF38BA8), '錯誤'),
      _ => (Icons.help, Colors.grey, '未知'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
