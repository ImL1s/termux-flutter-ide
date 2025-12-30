import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../core/providers.dart';
import 'editor_providers.dart';

class FileTabsWidget extends ConsumerWidget {
  const FileTabsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openFiles = ref.watch(openFilesProvider);
    final currentFile = ref.watch(currentFileProvider);

    return Container(
      height: 40,
      color: AppTheme.sideBarBg, // Themed Background
      child: openFiles.isEmpty
          ? const Center(
              child: Text(
                'No files open',
                style: TextStyle(color: AppTheme.textDisabled),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: openFiles.length,
              itemBuilder: (context, index) {
                final file = openFiles[index];
                final isActive = file == currentFile;

                return _FileTab(
                  fileName: _getFileName(file),
                  isActive: isActive,
                  onTap: () =>
                      ref.read(currentFileProvider.notifier).select(file),
                  onClose: () =>
                      ref.read(openFilesProvider.notifier).remove(file),
                  isDirty: ref.watch(dirtyFilesProvider).contains(file),
                );
              },
            ),
    );
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }
}

class _FileTab extends StatelessWidget {
  final String fileName;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final bool isDirty;

  const _FileTab({
    required this.fileName,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    required this.isDirty,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.tabActiveBg
              : AppTheme.tabInactiveBg, // Themed Tab BG
          border: Border(
            bottom: BorderSide(
              color: isActive
                  ? AppTheme.tabBorder
                  : Colors.transparent, // Themed Active Border
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFileIcon(fileName),
              size: 16,
              color: isActive
                  ? AppTheme.secondary
                  : AppTheme.textDisabled, // Themed Icon
            ),
            const SizedBox(width: 8),
            Text(
              fileName,
              style: TextStyle(
                color: isActive
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary, // Themed Text
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onClose,
              child: isDirty
                  ? const Icon(
                      Icons.circle,
                      size: 10,
                      color: AppTheme.textPrimary,
                    ) // Dirty Indicator
                  : Icon(
                      Icons.close,
                      size: 14,
                      color: AppTheme.textDisabled, // Themed Close Icon
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    if (fileName.endsWith('.dart')) return Icons.flutter_dash;
    if (fileName.endsWith('.yaml') || fileName.endsWith('.yml')) {
      return Icons.settings;
    }
    if (fileName.endsWith('.json')) return Icons.data_object;
    if (fileName.endsWith('.md')) return Icons.description;
    return Icons.insert_drive_file;
  }
}
