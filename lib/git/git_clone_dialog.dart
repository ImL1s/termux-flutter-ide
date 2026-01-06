import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../file_manager/file_operations.dart';
import '../core/providers.dart';
import 'git_service.dart';

/// Shows a dialog to clone a GitHub repository
Future<void> showGitCloneDialog(BuildContext context, WidgetRef ref) async {
  final urlController = TextEditingController();
  bool isCloning = false;
  String? error;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: AppTheme.background,
        title: const Row(
          children: [
            Icon(Icons.download, color: AppTheme.secondary),
            SizedBox(width: 8),
            Text('Clone from GitHub'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: urlController,
              enabled: !isCloning,
              decoration: const InputDecoration(
                hintText: 'https://github.com/user/repo.git',
                labelText: 'Repository URL',
                prefixIcon: Icon(Icons.link),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Will clone to: ${ref.read(currentDirectoryProvider)}',
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            if (isCloning) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Cloning repository...'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isCloning
                ? null
                : () async {
                    final url = urlController.text.trim();
                    if (url.isEmpty) {
                      setState(() => error = 'Please enter a repository URL');
                      return;
                    }

                    setState(() {
                      isCloning = true;
                      error = null;
                    });

                    try {
                      final gitService = ref.read(gitServiceProvider);
                      final targetDir = ref.read(currentDirectoryProvider);
                      final clonedPath = await gitService.clone(url, targetDir);

                      if (clonedPath != null) {
                        // Success - update directory and close
                        ref
                            .read(currentDirectoryProvider.notifier)
                            .setPath(clonedPath);
                        ref.read(projectPathProvider.notifier).set(clonedPath);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cloned to $clonedPath'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        setState(() {
                          isCloning = false;
                          error = 'Clone failed. Check the URL and try again.';
                        });
                      }
                    } catch (e) {
                      setState(() {
                        isCloning = false;
                        error = 'Error: $e';
                      });
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Clone'),
          ),
        ],
      ),
    ),
  );
}
