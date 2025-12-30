import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../ai/ai_providers.dart';
import 'command_palette.dart';

enum ActivityItem {
  explorer,
  search,
  sourceControl,
  extensions,
  none,
}

/// Selected Activity Item Notifier
class SelectedActivityNotifier extends Notifier<ActivityItem> {
  @override
  ActivityItem build() => ActivityItem.explorer;
  
  void select(ActivityItem item) {
    state = item;
  }
}

/// Selected Activity Item Provider (Left Sidebar)
final selectedActivityProvider = NotifierProvider<SelectedActivityNotifier, ActivityItem>(SelectedActivityNotifier.new);

/// Action to toggle left sidebar activity item
final toggleActivityProvider = Provider.family<void, ActivityItem>((ref, item) {
  final current = ref.read(selectedActivityProvider);
  if (current == item) {
    ref.read(selectedActivityProvider.notifier).select(ActivityItem.none);
  } else {
    ref.read(selectedActivityProvider.notifier).select(item);
  }
});

class ActivityBar extends ConsumerWidget {
  const ActivityBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedActivityProvider);
    final aiVisible = ref.watch(aiPanelVisibleProvider);

    return Container(
      width: 48,
      color: const Color(0xFF181825), // Catppuccin Mantle
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildActivityIcon(
            context,
            ref,
            icon: Icons.copy_all_outlined,
            tooltip: 'Explorer',
            isSelected: selected == ActivityItem.explorer,
            onTap: () => ref.read(toggleActivityProvider(ActivityItem.explorer)),
          ),
          _buildActivityIcon(
            context,
            ref,
            icon: Icons.search,
            tooltip: 'Search',
            isSelected: selected == ActivityItem.search,
            onTap: () => ref.read(toggleActivityProvider(ActivityItem.search)),
          ),
          _buildActivityIcon(
            context,
            ref,
            icon: Icons.source_outlined,
            tooltip: 'Source Control',
            isSelected: selected == ActivityItem.sourceControl,
            onTap: () => ref.read(toggleActivityProvider(ActivityItem.sourceControl)),
          ),
          const SizedBox(height: 16),
          _buildActivityIcon(
            context,
            ref,
            icon: Icons.terminal,
            tooltip: 'Command Palette',
            isSelected: false,
            onTap: () => showCommandPalette(context, ref),
          ),
          const Spacer(),
          _buildActivityIcon(
            context,
            ref,
            icon: aiVisible ? Icons.psychology : Icons.psychology_outlined,
            tooltip: 'AI Assistant',
            isSelected: aiVisible,
            onTap: () => ref.read(aiPanelVisibleProvider.notifier).toggle(),
          ),
          _buildActivityIcon(
            context,
            ref,
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            isSelected: false,
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActivityIcon(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(
                    left: BorderSide(color: Color(0xFFCBA6F7), width: 2),
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? const Color(0xFFCBA6F7) : Colors.grey[600],
            size: 24,
          ),
        ),
      ),
    );
  }
}
