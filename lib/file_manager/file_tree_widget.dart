import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../theme/app_theme.dart';
import 'file_operations.dart';

class FileTreeWidget extends ConsumerStatefulWidget {
  const FileTreeWidget({super.key});

  @override
  ConsumerState<FileTreeWidget> createState() => _FileTreeWidgetState();
}

class _FileTreeWidgetState extends ConsumerState<FileTreeWidget> {
  final Set<String> _expandedDirs = {};
  final Map<String, List<FileItem>> _cachedContents = {};

  @override
  Widget build(BuildContext context) {
    final currentDir = ref.watch(currentDirectoryProvider);

    return Container(
      color: AppTheme.surface, // Themed
      child: Column(
        children: [
          // Header
          _buildHeader(currentDir),
          const Divider(height: 1),
          // File tree
          Expanded(child: _buildFileTree(currentDir)),
        ],
      ),
    );
  }

  Widget _buildHeader(String currentDir) {
    final projectName = currentDir.split('/').last;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.folder_open,
            size: 16,
            color: AppTheme.secondary,
          ), // Themed
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              projectName.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary, // Themed
                letterSpacing: 1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder, size: 16),
            onPressed: () => _showCreateDialog(currentDir, isDirectory: true),
            tooltip: 'New Folder',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
          IconButton(
            icon: const Icon(Icons.note_add, size: 16),
            onPressed: () => _showCreateDialog(currentDir, isDirectory: false),
            tooltip: 'New File',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
            onPressed: _refresh,
            tooltip: 'Refresh',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTree(String rootPath) {
    final items = _cachedContents[rootPath];

    if (items == null) {
      _loadDirectory(rootPath);
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Empty folder',
          style: TextStyle(color: AppTheme.textDisabled),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isDirectory) {
          return _buildFolderItem(item);
        } else {
          return _buildFileItem(item);
        }
      },
    );
  }

  Widget _buildFolderItem(FileItem item) {
    final isExpanded = _expandedDirs.contains(item.path);
    final children = _cachedContents[item.path] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildItemRow(
          item: item,
          isExpanded: isExpanded,
          onTap: () => _toggleFolder(item.path),
          onLongPress: () => _showContextMenu(item),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 16,
                color: Colors.grey,
              ),
              Icon(
                isExpanded ? Icons.folder_open : Icons.folder,
                size: 16,
                color: AppTheme.syntaxType, // Themed Folder Icon
              ),
            ],
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: children.map((child) {
                if (child.isDirectory) {
                  return _buildFolderItem(child);
                } else {
                  return _buildFileItem(child);
                }
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildFileItem(FileItem item) {
    return _buildItemRow(
      item: item,
      onTap: () => _openFile(item),
      onLongPress: () => _showContextMenu(item),
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Icon(
          _getFileIcon(item.name),
          size: 16,
          color: _getFileColor(item.name),
        ),
      ),
    );
  }

  Widget _buildItemRow({
    required FileItem item,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    required Widget leading,
    bool isExpanded = false,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFolder(String path) {
    setState(() {
      if (_expandedDirs.contains(path)) {
        _expandedDirs.remove(path);
      } else {
        _expandedDirs.add(path);
        _loadDirectory(path);
      }
    });
  }

  Future<void> _loadDirectory(String path) async {
    if (_cachedContents.containsKey(path)) return;

    final ops = ref.read(fileOperationsProvider);
    final items = await ops.listDirectory(path);

    // Sort: directories first, then alphabetically
    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    setState(() {
      _cachedContents[path] = items;
    });
  }

  void _refresh() {
    setState(() {
      _cachedContents.clear();
      _expandedDirs.clear();
    });
  }

  void _showContextMenu(FileItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background, // Themed
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(item);
              },
            ),
            if (item.isDirectory) ...[
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('New File'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateDialog(item.path, isDirectory: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text('New Folder'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateDialog(item.path, isDirectory: true);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(String parentPath, {required bool isDirectory}) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDirectory ? 'New Folder' : 'New File'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isDirectory ? 'Folder name' : 'File name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              final navigator = Navigator.of(context);

              final ops = ref.read(fileOperationsProvider);
              final path = '$parentPath/$name';

              bool success;
              if (isDirectory) {
                success = await ops.createDirectory(path);
              } else {
                success = await ops.createFile(path);
              }

              if (success) {
                _cachedContents.remove(parentPath);
                _loadDirectory(parentPath);
              }

              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(FileItem item) {
    final controller = TextEditingController(text: item.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == item.name) return;
              final navigator = Navigator.of(context);

              final ops = ref.read(fileOperationsProvider);
              final parentPath = item.path.substring(
                0,
                item.path.lastIndexOf('/'),
              );
              final newPath = '$parentPath/$newName';

              final success = await ops.rename(item.path, newPath);
              if (success) {
                _cachedContents.remove(parentPath);
                _loadDirectory(parentPath);
              }

              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(FileItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final ops = ref.read(fileOperationsProvider);

              bool success;
              if (item.isDirectory) {
                success = await ops.deleteDirectory(item.path);
              } else {
                success = await ops.deleteFile(item.path);
              }

              if (success) {
                final parentPath = item.path.substring(
                  0,
                  item.path.lastIndexOf('/'),
                );
                _cachedContents.remove(parentPath);
                _loadDirectory(parentPath);
              }

              if (!mounted) return;
              navigator.pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openFile(FileItem item) {
    ref.read(openFilesProvider.notifier).add(item.path);
    ref.read(currentFileProvider.notifier).select(item.path);
  }

  void _openProject() {
    // TODO: Use file picker to select project folder
    // For now, show a dialog to enter path manually
    final controller = TextEditingController(
      text: ref.read(currentDirectoryProvider),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Project'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '/path/to/project'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final path = controller.text.trim();
              if (path.isNotEmpty) {
                ref.read(currentDirectoryProvider.notifier).setPath(path);
                _refresh();
              }
              Navigator.pop(context);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String name) {
    if (name.endsWith('.dart')) return Icons.flutter_dash;
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return Icons.settings;
    if (name.endsWith('.md')) return Icons.description;
    if (name.endsWith('.json')) return Icons.data_object;
    if (name.endsWith('.kt') || name.endsWith('.java')) return Icons.android;
    if (name.endsWith('.swift')) return Icons.apple;
    if (name.endsWith('.xml')) return Icons.code;
    if (name.endsWith('.gradle')) return Icons.build;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String name) {
    if (name.endsWith('.dart')) return const Color(0xFF89B4FA);
    if (name.endsWith('.yaml')) return const Color(0xFFF9E2AF);
    if (name.endsWith('.md')) return const Color(0xFFA6E3A1);
    if (name.endsWith('.json')) return const Color(0xFFF5C2E7);
    if (name.endsWith('.kt')) return const Color(0xFFCBA6F7);
    if (name.endsWith('.java')) return const Color(0xFFFAB387);
    return Colors.grey;
  }
}
