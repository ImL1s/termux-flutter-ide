import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';

class FileTreeWidget extends ConsumerStatefulWidget {
  const FileTreeWidget({super.key});

  @override
  ConsumerState<FileTreeWidget> createState() => _FileTreeWidgetState();
}

class _FileTreeWidgetState extends ConsumerState<FileTreeWidget> {
  final Set<String> _expandedDirs = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF181825),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.folder_open, size: 16, color: Color(0xFF00D4AA)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'PROJECT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 16),
                  onPressed: _openProject,
                  tooltip: 'Open Project',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: () => setState(() {}),
                  tooltip: 'Refresh',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // File tree
          Expanded(
            child: _buildDemoTree(),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoTree() {
    // Demo file structure
    return ListView(
      children: [
        _buildFolderItem('lib', [
          _buildFileItem('lib/main.dart'),
          _buildFolderItem('lib/editor', [
            _buildFileItem('lib/editor/editor_page.dart'),
            _buildFileItem('lib/editor/code_editor_widget.dart'),
          ]),
          _buildFolderItem('lib/core', [
            _buildFileItem('lib/core/providers.dart'),
          ]),
        ]),
        _buildFileItem('pubspec.yaml'),
        _buildFileItem('README.md'),
      ],
    );
  }

  Widget _buildFolderItem(String path, List<Widget> children) {
    final isExpanded = _expandedDirs.contains(path);
    final name = path.split('/').last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedDirs.remove(path);
              } else {
                _expandedDirs.add(path);
              }
            });
          },
          child: Padding(
            padding: EdgeInsets.only(left: _getIndent(path), top: 4, bottom: 4, right: 8),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 16,
                  color: Colors.grey,
                ),
                Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  size: 16,
                  color: const Color(0xFFF9E2AF),
                ),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...children,
      ],
    );
  }

  Widget _buildFileItem(String path) {
    final name = path.split('/').last;
    
    return InkWell(
      onTap: () => _openFile(path),
      child: Padding(
        padding: EdgeInsets.only(left: _getIndent(path) + 16, top: 4, bottom: 4, right: 8),
        child: Row(
          children: [
            Icon(
              _getFileIcon(name),
              size: 16,
              color: _getFileColor(name),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  double _getIndent(String path) {
    final depth = path.split('/').length - 1;
    return 8.0 + depth * 16.0;
  }

  IconData _getFileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.flutter_dash;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
    if (name.endsWith('.md')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String name) {
    if (name.endsWith('.dart')) return const Color(0xFF89B4FA);
    if (name.endsWith('.yaml')) return const Color(0xFFF9E2AF);
    if (name.endsWith('.md')) return const Color(0xFFA6E3A1);
    return Colors.grey;
  }

  void _openFile(String path) {
    ref.read(openFilesProvider.notifier).add(path);
    ref.read(currentFileProvider.notifier).select(path);
  }

  void _openProject() {
    // TODO: Implement file picker for project selection
  }
}
