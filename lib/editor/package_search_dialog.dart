import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pub_dev_service.dart';
import '../services/pubspec_service.dart';
import '../theme/app_theme.dart';
import '../core/snackbar_service.dart';

class PackageSearchDialog extends ConsumerStatefulWidget {
  const PackageSearchDialog({super.key});

  @override
  ConsumerState<PackageSearchDialog> createState() =>
      _PackageSearchDialogState();
}

class _PackageSearchDialogState extends ConsumerState<PackageSearchDialog> {
  final _searchController = TextEditingController();
  final _pubDevService = PubDevService();
  List<String> _searchResults = [];
  bool _isLoading = false;

  void _search(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    final results = await _pubDevService.searchPackages(query);
    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }

  void _addPackage(String name) async {
    setState(() => _isLoading = true);
    final details = await _pubDevService.getPackageDetails(name);
    if (details != null) {
      final success = await ref.read(pubspecServiceProvider).addDependency(
            details.name,
            details.version,
          );
      if (success) {
        if (mounted) {
          ref
              .read(snackBarServiceProvider)
              .success('Added ${details.name} ^${details.version}');
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ref.read(snackBarServiceProvider).error('Failed to add package');
        }
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Add Dependency',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search packages on pub.dev...',
                hintStyle: const TextStyle(color: AppTheme.textDisabled),
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _search,
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final name = _searchResults[index];
                  return ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                    trailing: const Icon(Icons.add_circle_outline,
                        color: AppTheme.primary),
                    onTap: () => _addPackage(name),
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

void showPackageSearchDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const PackageSearchDialog(),
  );
}
