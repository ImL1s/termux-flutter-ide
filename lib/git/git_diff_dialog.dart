import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'git_service.dart';
import '../theme/app_theme.dart';

class GitDiffDialog extends ConsumerWidget {
  final String path;
  final String filePath;

  const GitDiffDialog({
    super.key,
    required this.path,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.difference, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    filePath,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: AppTheme.surfaceVariant),
            Expanded(
              child: FutureBuilder<String>(
                future: ref.read(gitServiceProvider).diff(path, filePath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final diff = snapshot.data ?? 'No changes';

                  final lines = diff.split('\n');
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: lines.map((line) {
                        Color color = AppTheme.textSecondary;
                        if (line.startsWith('+')) color = Colors.greenAccent;
                        if (line.startsWith('-')) color = Colors.redAccent;
                        if (line.startsWith('@@')) color = AppTheme.primary;

                        return Text(
                          line,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: color,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showGitDiff(BuildContext context, String path, String filePath) {
  showDialog(
    context: context,
    builder: (context) => GitDiffDialog(path: path, filePath: filePath),
  );
}
