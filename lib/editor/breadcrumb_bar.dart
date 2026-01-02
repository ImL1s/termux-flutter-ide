import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../theme/app_theme.dart';

/// A mobile-friendly breadcrumb widget that shows the current file's path.
class BreadcrumbBar extends ConsumerWidget {
  const BreadcrumbBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFile = ref.watch(currentFileProvider);
    if (currentFile == null) return const SizedBox.shrink();

    final projectPath = ref.watch(projectPathProvider) ?? '';
    final relativePath = currentFile.startsWith(projectPath)
        ? currentFile.substring(projectPath.length)
        : currentFile;

    final parts = relativePath.split('/').where((p) => p.isNotEmpty).toList();

    return Container(
      height: 28,
      color: AppTheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.folder_outlined,
                size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            for (int i = 0; i < parts.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right,
                      size: 14, color: AppTheme.textSecondary),
                ),
              GestureDetector(
                onTap: () {
                  // Could navigate to folder in file tree - for now just show
                },
                child: Text(
                  parts[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: i == parts.length - 1
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontWeight: i == parts.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
