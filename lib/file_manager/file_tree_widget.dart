import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../theme/app_theme.dart';
import '../termux/termux_providers.dart';
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
  void initState() {
    super.initState();
    // Expand project root by default if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final projectPath = ref.read(projectPathProvider);
      if (projectPath != null) {
        setState(() {
          _expandedDirs.add(projectPath);
        });
        _loadDirectory(projectPath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectPath = ref.watch(projectPathProvider);

    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: projectPath == null
                ? _buildNoProjectView()
                : _buildFileTree(projectPath),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Text(
        'EXPLORER',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNoProjectView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No folder opened',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openProject,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Open Folder'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTree(String projectPath) {
    final projectName = projectPath.split('/').last;
    final isExpanded = _expandedDirs.contains(projectPath);
    final items = _cachedContents[projectPath];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Root Project Folder Node
        _buildRootNode(projectName, projectPath, isExpanded),

        if (isExpanded) ...[
          if (items == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 32, top: 8),
              child: Text(
                'No files',
                style: TextStyle(fontSize: 12, color: AppTheme.textDisabled),
              ),
            )
          else
            ...items.map((item) {
              if (item.isDirectory) {
                return _buildFolderItem(item, indent: 16);
              } else {
                return _buildFileItem(item, indent: 16);
              }
            }),
        ],
      ],
    );
  }

  Widget _buildRootNode(String name, String path, bool isExpanded) {
    return InkWell(
      onTap: () => _toggleFolder(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: isExpanded ? Colors.transparent : Colors.black12,
        child: Row(
          children: [
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 16,
              color: Colors.grey,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.note_add_outlined, size: 16),
              onPressed: () => _showCreateDialog(path, isDirectory: false),
              tooltip: 'New File',
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.create_new_folder_outlined, size: 16),
              onPressed: () => _showCreateDialog(path, isDirectory: true),
              tooltip: 'New Folder',
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: _refresh,
              tooltip: 'Refresh',
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderItem(FileItem item, {double indent = 0}) {
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
          indent: indent,
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
          Column(
            children: children.map((child) {
              if (child.isDirectory) {
                return _buildFolderItem(child, indent: indent + 12);
              } else {
                return _buildFileItem(child, indent: indent + 12);
              }
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildFileItem(FileItem item, {double indent = 0}) {
    return _buildItemRow(
      item: item,
      onTap: () => _openFile(item),
      onLongPress: () => _showContextMenu(item),
      indent: indent,
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
    required double indent,
    bool isExpanded = false,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.only(left: indent + 8, right: 8, top: 2, bottom: 2),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: DirectoryBrowser(
          initialPath: ref.read(currentDirectoryProvider),
          onSelect: (path) {
            ref.read(currentDirectoryProvider.notifier).setPath(path);
            ref.read(projectPathProvider.notifier).set(path);
            _refresh();
            // Close both the dialog and the drawer (if in mobile mode)
            Navigator.pop(context);
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
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

/// Directory browser widget for selecting project folder
class DirectoryBrowser extends ConsumerStatefulWidget {
  final String initialPath;
  final void Function(String path) onSelect;

  const DirectoryBrowser({
    super.key,
    required this.initialPath,
    required this.onSelect,
  });

  @override
  ConsumerState<DirectoryBrowser> createState() => _DirectoryBrowserState();
}

class _DirectoryBrowserState extends ConsumerState<DirectoryBrowser> {
  late String _currentPath;
  List<FileItem>? _items;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final ops = ref.read(fileOperationsProvider);
      final items = await ops.listDirectory(_currentPath);
      // Filter only directories
      final dirs = items.where((i) => i.isDirectory).toList();
      dirs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) {
        setState(() {
          _items = dirs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().contains('Permission denied')
              ? 'Permission Denied'
              : 'Error: $e';
        });
      }
    }
  }

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path;
      _items = null;
      _errorMessage = null;
    });
    _loadDirectory();
  }

  void _goUp() {
    final parent = _currentPath.substring(0, _currentPath.lastIndexOf('/'));
    if (parent.isNotEmpty) {
      _navigateTo(parent);
    } else if (_currentPath != '/') {
      _navigateTo('/');
    }
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
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
              final path = '$_currentPath/$name';

              final success = await ops.createDirectory(path);

              if (success) {
                // Refresh list
                _loadDirectory();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Project Folder',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: _currentPath != '/' ? _goUp : null,
                    tooltip: 'Go up',
                  ),
                  Expanded(
                    child: Text(
                      _currentPath,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.create_new_folder),
                    onPressed: _showCreateFolderDialog,
                    tooltip: 'New Folder',
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Directory list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorView()
                  : _items == null || _items!.isEmpty
                      ? const Center(child: Text('No subdirectories'))
                      : ListView.builder(
                          itemCount: _items!.length,
                          itemBuilder: (context, index) {
                            final item = _items![index];
                            return ListTile(
                              leading: const Icon(Icons.folder,
                                  color: AppTheme.syntaxType),
                              title: Text(item.name),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _navigateTo(item.path),
                            );
                          },
                        ),
        ),
        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.surfaceVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => widget.onSelect(_currentPath),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Select This Folder'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    final isPermissionDenied = _errorMessage == 'Permission Denied';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionDenied ? Icons.lock_outline : Icons.error_outline,
              size: 48,
              color: isPermissionDenied ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (isPermissionDenied) ...[
              const SizedBox(height: 24),
              const Text(
                'Termux needs shared storage permission to access /sdcard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(termuxBridgeProvider).setupStorage();
                  // Show tooltip or snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Launched setup in Termux. Please allow permission there.')),
                  );
                },
                icon: const Icon(Icons.storage),
                label: const Text('Setup Storage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
