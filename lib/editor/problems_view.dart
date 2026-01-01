import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'diagnostics_provider.dart';
import 'editor_request_provider.dart';

class ProblemsView extends ConsumerWidget {
  const ProblemsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnosticsState = ref.watch(diagnosticsProvider);
    final allDiagnostics = diagnosticsState.allDiagnostics;

    if (allDiagnostics.isEmpty) {
      return const Center(
        child: Text(
          'No problems detected',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Group diagnostics by file
    return ListView.builder(
      itemCount: diagnosticsState.fileDiagnostics.length,
      itemBuilder: (context, index) {
        final uri = diagnosticsState.fileDiagnostics.keys.elementAt(index);
        final fileDiagnostics = diagnosticsState.fileDiagnostics[uri]!;
        final fileName = uri.split('/').last;

        return ExpansionTile(
          initiallyExpanded: true,
          title: Text(
            '$fileName (${fileDiagnostics.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCBA6F7),
            ),
          ),
          subtitle: Text(
            uri.replaceAll('file://', ''),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          children: fileDiagnostics.map((diagnostic) {
            return ListTile(
              dense: true,
              leading: _getSeverityIcon(diagnostic.severity),
              title: Text(
                diagnostic.message,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              subtitle: Text(
                'Line ${diagnostic.range.startLine + 1}, Column ${diagnostic.range.startColumn + 1}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              onTap: () {
                final filePath = uri.replaceAll('file://', '');
                ref.read(editorRequestProvider.notifier).jumpToLine(
                      filePath,
                      diagnostic.range.startLine + 1,
                    );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _getSeverityIcon(DiagnosticSeverity severity) {
    switch (severity) {
      case DiagnosticSeverity.error:
        return const Icon(Icons.error, color: Colors.red, size: 16);
      case DiagnosticSeverity.warning:
        return const Icon(Icons.warning, color: Colors.orange, size: 16);
      case DiagnosticSeverity.information:
        return const Icon(Icons.info, color: Colors.blue, size: 16);
      case DiagnosticSeverity.hint:
        return const Icon(Icons.lightbulb_outline,
            color: Colors.grey, size: 16);
    }
  }
}
