import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../services/lsp_service.dart';
import 'editor_request_provider.dart';

/// Shows a mobile-friendly workspace symbol search dialog.
Future<void> showWorkspaceSymbolDialog(
    BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  List<Map<String, dynamic>> results = [];

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E2E),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
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
              // Search Input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search symbols: class, function...',
                    prefixIcon: const Icon(Icons.account_tree, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF313244),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (query) async {
                    if (query.length < 2) {
                      setState(() => results = []);
                      return;
                    }
                    final lsp = ref.read(lspServiceProvider);
                    final symbols = await lsp.workspaceSymbol(query);
                    setState(() => results = symbols);
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Results
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          controller.text.isEmpty
                              ? 'Type to search workspace symbols'
                              : 'No symbols found',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final symbol = results[index];
                          final name = symbol['name'] ?? '';
                          final kind = symbol['kind'] ?? 0;
                          final location =
                              symbol['location'] as Map<String, dynamic>?;
                          final uri = location?['uri'] as String? ?? '';
                          final filePath = uri.replaceFirst('file://', '');

                          return ListTile(
                            leading: Icon(
                              _getSymbolIcon(kind),
                              color: _getSymbolColor(kind),
                              size: 20,
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontFamily: 'JetBrains Mono')),
                            subtitle: Text(
                              filePath.split('/').last,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              // Navigate to file and line
                              final range =
                                  location?['range'] as Map<String, dynamic>?;
                              final startLine =
                                  (range?['start']?['line'] as int? ?? 0) + 1;

                              ref
                                  .read(openFilesProvider.notifier)
                                  .add(filePath);
                              ref
                                  .read(currentFileProvider.notifier)
                                  .select(filePath);

                              // Request jump to line
                              ref
                                  .read(editorRequestProvider.notifier)
                                  .jumpToLine(filePath, startLine);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

IconData _getSymbolIcon(int kind) {
  switch (kind) {
    case 5: // Class
      return Icons.class_outlined;
    case 6: // Method
    case 12: // Function
      return Icons.functions;
    case 8: // Field
    case 13: // Variable
      return Icons.abc;
    case 10: // Enum
      return Icons.format_list_numbered;
    case 11: // Interface
      return Icons.extension;
    case 14: // Constant
      return Icons.lock;
    default:
      return Icons.code;
  }
}

Color _getSymbolColor(int kind) {
  switch (kind) {
    case 5: // Class
      return const Color(0xFFF9E2AF); // Yellow
    case 6: // Method
    case 12: // Function
      return const Color(0xFF89B4FA); // Blue
    case 8: // Field
    case 13: // Variable
      return const Color(0xFF94E2D5); // Teal
    case 10: // Enum
      return const Color(0xFFF38BA8); // Pink
    default:
      return Colors.grey;
  }
}
