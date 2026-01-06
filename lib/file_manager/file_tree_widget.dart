import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../theme/app_theme.dart';

import 'file_operations.dart';
import '../core/scrollable_with_scrollbar.dart';

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

    return ListViewWithScrollbar(
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
        DragTarget<FileItem>(
          onWillAcceptWithDetails: (details) => _canMove(details.data, item),
          onAcceptWithDetails: (details) => _moveFile(details.data, item),
          builder: (context, candidates, rejects) {
            final isHovered = candidates.isNotEmpty;
            return Container(
              color: isHovered ? AppTheme.primary.withValues(alpha: 0.2) : null,
              child: _buildItemRow(
                item: item,
                isExpanded: isExpanded,
                onTap: () => _toggleFolder(item.path),
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
                      color: AppTheme.syntaxType,
                    ),
                  ],
                ),
              ),
            );
          },
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
    required Widget leading,
    required double indent,
    bool isExpanded = false,
  }) {
    return _HoverableFileItem(
      item: item,
      onTap: onTap,
      onDoubleTap: item.isDirectory ? null : () => _openFile(item),
      onContextMenu: () => _showContextMenu(item),
      onDelete: () => _confirmDelete(item),
      leading: leading,
      indent: indent,
    );
  }

  bool _canMove(FileItem? src, FileItem dest) {
    if (src == null) return false;
    if (src.path == dest.path) return false; // Self
    if (!dest.isDirectory) return false; // Dest must be dir

    final srcDir = src.path.substring(0, src.path.lastIndexOf('/'));
    if (srcDir == dest.path) return false; // Already in dest

    if (dest.path.startsWith(src.path)) {
      return false; // Can't move parent to child
    }

    return true;
  }

  Future<void> _moveFile(FileItem src, FileItem dest) async {
    final ops = ref.read(fileOperationsProvider);
    final newPath = '${dest.path}/${src.name}';
    final success = await ops.rename(src.path, newPath);

    if (success) {
      final srcDir = src.path.substring(0, src.path.lastIndexOf('/'));
      // Refresh both source parent and destination
      _cachedContents.remove(srcDir);
      _cachedContents.remove(dest.path);
      // If we moved a directory that was expanded, update expanded set
      if (src.isDirectory && _expandedDirs.contains(src.path)) {
        _expandedDirs.remove(src.path);
      }
      if (mounted) {
        // Use Future.wait to load both
        await Future.wait([
          _loadDirectory(srcDir),
          _loadDirectory(dest.path),
        ]);
      }
    }
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

  Future<bool> _confirmDelete(FileItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
                if (mounted) {
                  _loadDirectory(parentPath);
                }
              }

              if (mounted && navigator.canPop()) {
                navigator.pop(success);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _openFile(FileItem item) {
    ref.read(openFilesProvider.notifier).add(item.path);
    ref.read(currentFileProvider.notifier).select(item.path);
  }

  void _openProject() {
    try {
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
    } catch (e) {
      print('Error opening project browser: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open folder browser: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          _errorMessage = e.toString();
        });
        print('DirectoryBrowser error: $e');
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

  void _retry() {
    _loadDirectory();
  }

  Widget _buildErrorView() {
    final err = _errorMessage?.toLowerCase() ?? '';
    final isPermissionError = err.contains('permission denied') ||
        err.contains('permission not granted');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPermissionError ? Icons.lock_outline : Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              isPermissionError ? 'Access Denied' : 'Error Loading Directory',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                if (isPermissionError) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Trigger Termux setup storage or fix permissions
                      // For now, retry is the best options or guide user
                      _retry();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Fix Permissions'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
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
                      : ScrollableWithScrollbar(
                          child: ListView.builder(
                            itemCount: _items!.length,
                            itemBuilder: (context, index) {
                              final item = _items![index];
                              return ListTile(
                                key: Key('folder_item_${item.name}'),
                                leading: const Icon(Icons.folder,
                                    color: AppTheme.syntaxType),
                                title: Text(item.name),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _navigateTo(item.path),
                              );
                            },
                          ),
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
                  key: const Key('directory_browser_cancel'),
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
                  key: const Key('directory_browser_select'),
                  child: const Text('Select This Folder'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A file tree item with hover effects, double-click, and right-click support
class _HoverableFileItem extends StatefulWidget {
  final FileItem item;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback onContextMenu;
  final Future<bool?> Function() onDelete;
  final Widget leading;
  final double indent;

  const _HoverableFileItem({
    required this.item,
    required this.onTap,
    this.onDoubleTap,
    required this.onContextMenu,
    required this.onDelete,
    required this.leading,
    required this.indent,
  });

  @override
  State<_HoverableFileItem> createState() => _HoverableFileItemState();
}

class _HoverableFileItemState extends State<_HoverableFileItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final content = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTap: widget.onContextMenu,
        onLongPress: widget.onContextMenu,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: _isHovering
              ? AppTheme.surfaceVariant.withValues(alpha: 0.5)
              : Colors.transparent,
          padding: EdgeInsets.only(
              left: widget.indent + 8, right: 0, top: 4, bottom: 4),
          child: Row(
            children: [
              widget.leading,
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.item.name,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Context Menu Button (visible on hover)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: _isHovering ? 1.0 : 0.0,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert,
                        size: 16, color: Colors.grey),
                    onPressed: widget.onContextMenu,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: Key(widget.item.path),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => widget.onDelete(),
      child: LongPressDraggable<FileItem>(
        data: widget.item,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.background.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.surfaceVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.insert_drive_file,
                    size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(widget.item.name,
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.5, child: content),
        child: content,
      ),
    );
  }
}
