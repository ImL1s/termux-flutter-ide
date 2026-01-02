import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'editor_request_provider.dart';
import '../theme/app_theme.dart';

/// Dialog to display LSP references results
class ReferencesDialog extends ConsumerWidget {
  final List<Map<String, dynamic>> references;
  final String symbolName;

  const ReferencesDialog({
    super.key,
    required this.references,
    required this.symbolName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'References: $symbolName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${references.length} found',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.surfaceVariant),
            // List
            Flexible(
              child: references.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No references found',
                          style: TextStyle(color: AppTheme.textDisabled),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: references.length,
                      itemBuilder: (context, index) {
                        final refItem = references[index];
                        final uri = refItem['uri'] as String;
                        final range = refItem['range'] as Map<String, dynamic>;
                        final start = range['start'] as Map<String, dynamic>;
                        final line = (start['line'] as int) + 1;
                        final column = (start['character'] as int) + 1;
                        final fileName = uri.split('/').last;
                        final filePath = uri.replaceAll('file://', '');

                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.code,
                            size: 18,
                            color: AppTheme.textSecondary,
                          ),
                          title: Text(
                            fileName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Line $line, Column $column',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textDisabled,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: AppTheme.textDisabled,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            ref
                                .read(editorRequestProvider.notifier)
                                .jumpToLine(filePath, line);
                          },
                        );
                      },
                    ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showReferencesDialog(
  BuildContext context,
  WidgetRef ref,
  List<Map<String, dynamic>> references,
  String symbolName,
) {
  showDialog(
    context: context,
    builder: (context) => ReferencesDialog(
      references: references,
      symbolName: symbolName,
    ),
  );
}
