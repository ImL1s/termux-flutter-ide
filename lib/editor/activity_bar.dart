import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../ai/ai_providers.dart';
import '../theme/app_theme.dart';
import 'command_palette.dart';

enum ActivityItem { explorer, search, sourceControl, extensions, none }

/// Selected Activity Item Notifier
class SelectedActivityNotifier extends Notifier<ActivityItem> {
  @override
  ActivityItem build() => ActivityItem.none;

  void select(ActivityItem item) {
    state = item;
  }

  void toggle(ActivityItem item) {
    if (state == item) {
      state = ActivityItem.none;
    } else {
      state = item;
    }
  }
}

/// Selected Activity Item Provider (Left Sidebar)
final selectedActivityProvider =
    NotifierProvider<SelectedActivityNotifier, ActivityItem>(
      SelectedActivityNotifier.new,
    );

class ActivityBar extends ConsumerWidget {
  const ActivityBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedActivityProvider);
    final aiVisible = ref.watch(aiPanelVisibleProvider);

    return Container(
      width: 48,
      color: AppTheme.activityBarBg, // Themed
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildActivityIcon(
            context,
            ref,
            icon: Icons.copy_all_outlined,
            tooltip: 'Explorer',
            isSelected: selected == ActivityItem.explorer,
            onTap: () => ref
                .read(selectedActivityProvider.notifier)
                .toggle(ActivityItem.explorer),
          ),
          _buildActivityIcon(
            context,
            ref,
            icon: Icons.search,
            tooltip: 'Search',
            isSelected: selected == ActivityItem.search,
            onTap: () => ref
                .read(selectedActivityProvider.notifier)
                .toggle(ActivityItem.search),
          ),
          _buildActivityIcon(
            context,
            ref,
            icon: Icons.source_outlined,
            tooltip: 'Source Control',
            isSelected: selected == ActivityItem.sourceControl,
            onTap: () => ref
                .read(selectedActivityProvider.notifier)
                .toggle(ActivityItem.sourceControl),
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
                    left: BorderSide(
                      color: AppTheme.primary,
                      width: 2,
                    ), // Themed Border
                  )
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected
                ? AppTheme.textPrimary
                : AppTheme.textDisabled, // Themed Icons
            size: 24,
          ),
        ),
      ),
    );
  }
}
