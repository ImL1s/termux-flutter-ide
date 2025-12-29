import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';

class FileTabsWidget extends ConsumerWidget {
  const FileTabsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openFiles = ref.watch(openFilesProvider);
    final currentFile = ref.watch(currentFileProvider);

    return Container(
      height: 40,
      color: const Color(0xFF181825),
      child: openFiles.isEmpty
          ? const Center(
              child: Text(
                'No files open',
                style: TextStyle(color: Colors.grey),
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
                  onTap: () => ref.read(currentFileProvider.notifier).select(file),
                  onClose: () => ref.read(openFilesProvider.notifier).remove(file),
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

  const _FileTab({
    required this.fileName,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E1E2E) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF00D4AA) : Colors.transparent,
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
              color: isActive ? const Color(0xFF00D4AA) : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              fileName,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onClose,
              child: Icon(
                Icons.close,
                size: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    if (fileName.endsWith('.dart')) return Icons.flutter_dash;
    if (fileName.endsWith('.yaml') || fileName.endsWith('.yml')) return Icons.settings;
    if (fileName.endsWith('.json')) return Icons.data_object;
    if (fileName.endsWith('.md')) return Icons.description;
    return Icons.insert_drive_file;
  }
}
