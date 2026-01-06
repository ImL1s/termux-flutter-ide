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

class _FileTab extends StatefulWidget {
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
  State<_FileTab> createState() => _FileTabState();
}

class _FileTabState extends State<_FileTab> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        // Middle-click to close (common convention)
        onTertiaryTapUp: (_) => widget.onClose(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppTheme.tabActiveBg
                : _isHovering
                    ? AppTheme.surfaceVariant.withValues(alpha: 0.3)
                    : AppTheme.tabInactiveBg,
            border: Border(
              bottom: BorderSide(
                color:
                    widget.isActive ? AppTheme.tabBorder : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(widget.fileName),
                size: 16,
                color: widget.isActive
                    ? AppTheme.secondary
                    : AppTheme.textDisabled,
              ),
              const SizedBox(width: 8),
              Text(
                widget.fileName,
                style: TextStyle(
                  color: widget.isActive
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              // Close button with hover visibility
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 100),
                    opacity: widget.isDirty || _isHovering || widget.isActive
                        ? 1.0
                        : 0.3,
                    child: widget.isDirty
                        ? const Icon(
                            Icons.circle,
                            size: 10,
                            color: AppTheme.textPrimary,
                          )
                        : const Icon(
                            Icons.close,
                            size: 14,
                            color: AppTheme.textDisabled,
                          ),
                  ),
                ),
              ),
            ],
          ),
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
