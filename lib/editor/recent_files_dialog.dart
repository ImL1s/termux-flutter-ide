import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/recent_files_provider.dart';
import '../core/providers.dart';
import '../theme/app_theme.dart';

/// Shows a mobile-friendly recent files dialog.
Future<void> showRecentFilesDialog(BuildContext context, WidgetRef ref) async {
  final recentFilesAsync = ref.read(recentFilesProvider);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history,
                        color: AppTheme.textSecondary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Recent Files',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(recentFilesProvider.notifier).clear();
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // List
          Expanded(
            child: recentFilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (files) {
                if (files.isEmpty) {
                  return const Center(
                    child: Text(
                      'No recent files',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final filePath = files[index];
                    final fileName = filePath.split('/').last;
                    final directory = filePath
                        .split('/')
                        .reversed
                        .skip(1)
                        .take(2)
                        .toList()
                        .reversed
                        .join('/');

                    return ListTile(
                      leading: Icon(
                        _getFileIcon(fileName),
                        color: _getFileColor(fileName),
                        size: 20,
                      ),
                      title: Text(
                        fileName,
                        style: const TextStyle(fontFamily: 'JetBrains Mono'),
                      ),
                      subtitle: Text(
                        directory,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          ref
                              .read(recentFilesProvider.notifier)
                              .remove(filePath);
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(openFilesProvider.notifier).add(filePath);
                        ref.read(currentFileProvider.notifier).select(filePath);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

IconData _getFileIcon(String name) {
  if (name.endsWith('.dart')) return Icons.code;
  if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
  if (name.endsWith('.json')) return Icons.data_object;
  if (name.endsWith('.md')) return Icons.article;
  return Icons.insert_drive_file;
}

Color _getFileColor(String name) {
  if (name.endsWith('.dart')) return const Color(0xFF89B4FA); // Blue
  if (name.endsWith('.yaml') || name.endsWith('.yml')) {
    return const Color(0xFFF38BA8); // Pink
  }
  if (name.endsWith('.json')) return const Color(0xFFF9E2AF); // Yellow
  if (name.endsWith('.md')) return const Color(0xFF94E2D5); // Teal
  return AppTheme.textSecondary;
}
