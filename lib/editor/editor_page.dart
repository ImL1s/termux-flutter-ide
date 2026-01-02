import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';

import 'code_editor_widget.dart';
import 'file_tabs_widget.dart';
import '../file_manager/file_tree_widget.dart';
import '../file_manager/file_operations.dart';
import '../terminal/terminal_widget.dart';
import '../termux/termux_providers.dart';
import '../termux/ssh_service.dart';
import '../ai/ai_chat_widget.dart';
import '../ai/ai_providers.dart';
import '../search/search_widget.dart';
import 'activity_bar.dart';
import 'command_palette.dart';
import 'debug_panel_widget.dart';
import 'package:flutter/services.dart'; // For LogicalKeyboardKey
import '../git/git_widget.dart';
import 'editor_providers.dart';
import '../settings/settings_page.dart';
import '../git/git_clone_dialog.dart';
import '../core/providers.dart';
import '../run/flutter_runner_widget.dart';
import '../run/vm_service_manager.dart';
import '../run/flutter_runner_service.dart';
import 'flutter_create_dialog.dart';
import 'package_search_dialog.dart';
import 'problems_view.dart';
import 'diagnostics_provider.dart';
import '../services/lsp_service.dart';
import 'editor_request_provider.dart';
import 'references_dialog.dart';

enum BottomPanelTab { terminal, problems }

final bottomPanelTabProvider =
    StateProvider<BottomPanelTab>((ref) => BottomPanelTab.terminal);

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  bool _showTerminal = false;
  final double _initialTerminalHeight = 250;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerCommands();
    });
  }

  void _registerCommands() {
    final registry = ref.read(commandServiceProvider);

    registry.register(
      Command(
        id: 'flutter.run',
        title: 'Run Flutter App',
        category: 'Flutter',
        icon: Icons.play_arrow,
        action: _runFlutter,
      ),
    );

    registry.register(
      Command(
        id: 'flutter.build.apk',
        title: 'Build APK',
        category: 'Flutter',
        icon: Icons.build,
        action: _buildApk,
      ),
    );

    registry.register(
      Command(
        id: 'view.toggleTerminal',
        title: 'Toggle Terminal',
        category: 'View',
        icon: Icons.terminal,
        action: () {
          setState(() => _showTerminal = !_showTerminal);
        },
      ),
    );

    registry.register(
      Command(
        id: 'view.toggleAI',
        title: 'Toggle AI Assistant',
        category: 'View',
        icon: Icons.psychology,
        action: () {
          ref.read(aiPanelVisibleProvider.notifier).toggle();
        },
      ),
    );

    registry.register(
      Command(
        id: 'file.save',
        title: 'Save File',
        category: 'File',
        icon: Icons.save,
        action: () {
          ref.read(saveTriggerProvider.notifier).trigger();
        },
      ),
    );

    registry.register(
      Command(
        id: 'flutter.create',
        title: 'New Flutter Project',
        category: 'Flutter',
        icon: Icons.add_circle_outline,
        action: _createNewProject,
      ),
    );

    registry.register(
      Command(
        id: 'flutter.pub.add',
        title: 'Add Dependency (Pubspec Assist)',
        category: 'Flutter',
        icon: Icons.library_add,
        action: () => showPackageSearchDialog(context),
      ),
    );

    registry.register(
      Command(
        id: 'editor.goToDefinition',
        title: 'Go to Definition',
        category: 'Editor',
        icon: Icons.search,
        action: _goToDefinition,
      ),
    );

    registry.register(
      Command(
        id: 'editor.findReferences',
        title: 'Find References',
        category: 'Editor',
        icon: Icons.link,
        action: _findReferences,
      ),
    );

    registry.register(
      Command(
        id: 'editor.format',
        title: 'Format Document',
        category: 'Editor',
        icon: Icons.format_align_left,
        action: _formatDocument,
      ),
    );

    registry.register(
      Command(
        id: 'editor.find',
        title: 'Find in File',
        category: 'Editor',
        icon: Icons.search,
        action: _openFindReplace,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hot Reload on Save Listener
    ref.listen(saveTriggerProvider, (previous, next) {
      if (previous != next) {
        // Trigger Hot Reload if a session is active
        ref.read(flutterRunnerServiceProvider).hotReload();
      }
    });

    final isMobile = MediaQuery.of(context).size.width < 600;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            ref.read(saveTriggerProvider.notifier).trigger(),
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            ref.read(saveTriggerProvider.notifier).trigger(),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
            showCommandPalette(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () =>
            showCommandPalette(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _openFindReplace();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          _openFindReplace();
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            // SSH Status Banner
            Consumer(
              builder: (context, ref, _) {
                final status = ref.watch(sshStatusProvider).asData?.value ??
                    SSHStatus.disconnected;
                if (status == SSHStatus.failed) {
                  return Container(
                    color: Colors.red.shade900,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Termux SSH Connection Failed. Please ensure Termux is installed and SSHD is running.',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.read(sshServiceProvider).connect(),
                          child: const Text('RETRY',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }
                if (status == SSHStatus.bootstrapping) {
                  return Container(
                    color: Colors.blue.shade900,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Bootstrapping Termux SSH Environment...',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child:
                  isMobile ? _buildMobileScaffold() : _buildDesktopScaffold(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopScaffold() {
    return Scaffold(
      appBar: _buildDesktopAppBar(),
      body: _buildDesktopLayout(),
    );
  }

  PreferredSizeWidget _buildDesktopAppBar() {
    return AppBar(
      title: const Text('Termux Flutter IDE'),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.play_arrow),
          onPressed: _runFlutter,
          tooltip: 'Flutter Run',
        ),
        IconButton(
          icon: const Icon(Icons.build),
          onPressed: _buildApk,
          tooltip: 'Build APK',
        ),
      ],
    );
  }

  Widget _buildMobileScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: Consumer(
          builder: (context, ref, _) {
            final projectPath = ref.watch(projectPathProvider);
            final projectName = projectPath?.split('/').last ?? 'IDE';
            return Text(
              projectPath != null ? '$projectName - Termux IDE' : 'Termux IDE',
              style: const TextStyle(fontSize: 16),
            );
          },
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            key: const Key('main_drawer_button'),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Color(0xFFCBA6F7)),
            key: const Key('appbar_run_action'),
            onPressed: _runFlutter,
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFFCBA6F7)),
            onPressed: () => ref.read(saveTriggerProvider.notifier).trigger(),
            tooltip: 'Save',
          ),
          IconButton(
            icon: const Icon(Icons.psychology, size: 28),
            onPressed: _showAIMobile,
            tooltip: 'AI Assistant',
          ),
        ],
      ),
      drawer: _buildMobileDrawer(),
      body: const Column(
        children: [
          FileTabsWidget(),
          Divider(height: 1),
          Expanded(child: CodeEditorWidget()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF181825),
        selectedItemColor: const Color(0xFFCBA6F7),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Explorer'),
          BottomNavigationBarItem(
              icon: Icon(Icons.terminal), label: 'Terminal'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        ],
        onTap: (index) {
          if (index == 0) _showExplorerMobile();
          if (index == 1) _showTerminalMobile();
          if (index == 2) _showSearchMobile();
        },
      ),
      floatingActionButton: Consumer(
        builder: (context, ref, _) {
          final vmStatus = ref.watch(vmServiceStatusProvider);
          final status = vmStatus.asData?.value ?? VMServiceStatus.disconnected;
          // Show if connected or paused
          if (status == VMServiceStatus.connected ||
              status == VMServiceStatus.paused) {
            return const FloatingDebugToolbar();
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showExplorerMobile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: const FileTreeWidget(),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E2E),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF181825)),
            margin: EdgeInsets.zero,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.code, size: 48, color: Color(0xFFCBA6F7)),
                  const SizedBox(height: 8),
                  const Text('Termux Flutter IDE',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Explorer'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1E1E2E),
                isScrollControlled: true,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const FileTreeWidget(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search'),
            onTap: () {
              Navigator.pop(context);
              _showSearchMobile();
            },
          ),
          ListTile(
            leading: const Icon(Icons.source_outlined),
            title: const Text('Source Control'),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1E1E2E),
                isScrollControlled: true,
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.9, // Taller
                  child: const GitWidget(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Run and Debug'),
            onTap: () {
              final container = ProviderScope.containerOf(context);
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1E1E2E),
                isScrollControlled: true,
                builder: (context) => UncontrolledProviderScope(
                  container: container,
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const DebugPanelWidget(),
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Open Folder'),
            key: const Key('drawer_open_folder'),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(0xFF1E1E2E), // Match theme
                builder: (context) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: DirectoryBrowser(
                    initialPath: ref.read(currentDirectoryProvider),
                    onSelect: (path) {
                      ref.read(currentDirectoryProvider.notifier).setPath(path);
                      ref.read(projectPathProvider.notifier).set(path);
                      Navigator.pop(context);

                      // Automatically open Explorer after folder selection
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFF1E1E2E),
                        isScrollControlled: true,
                        builder: (context) => SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: const FileTreeWidget(),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Clone from GitHub'),
            onTap: () {
              Navigator.pop(context);
              showGitCloneDialog(context, ref);
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.add_circle_outline, color: Color(0xFF89B4FA)),
            title: const Text('New Flutter Project'),
            onTap: () {
              Navigator.pop(context);
              _createNewProject();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Run Project'),
            key: const Key('drawer_run_project'),
            onTap: () {
              Navigator.pop(context);

              final projectPath = ref.read(projectPathProvider);
              if (projectPath == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No project open')),
                );
                return;
              }

              // Run flutter run in terminal
              ref
                  .read(terminalCommandProvider.notifier)
                  .run('cd "$projectPath" && flutter run');

              // Show Terminal after a short delay to let drawer close
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _showTerminalMobile();
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('Command Palette'),
            onTap: () {
              Navigator.pop(context);
              showCommandPalette(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTerminalMobile() {
    // Close any existing modals (like the File Explorer or Drawer)
    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.9, // 90% Height
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Keyboard
          ),
          child: Column(
            children: [
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('TERMINAL',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Expanded(child: TerminalWidget()),
            ],
          ),
        ), // Close Padding
      ),
    );
  }

  void _showAIMobile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: const AIChatWidget(),
      ),
    );
  }

  void _showSearchMobile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: const SearchWidget(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final selectedActivity = ref.watch(selectedActivityProvider);

    return Row(
      children: [
        const ActivityBar(),
        if (selectedActivity != ActivityItem.none) ...[
          const VerticalDivider(width: 1, thickness: 1),
          SizedBox(width: 250, child: _buildSidebarContent(selectedActivity)),
        ],
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: _showTerminal
              ? ResizableContainer(
                  direction: Axis.vertical,
                  children: [
                    ResizableChild(
                      child: Column(
                        children: [
                          const FileTabsWidget(),
                          const Expanded(child: CodeEditorWidget()),
                        ],
                      ),
                      size: const ResizableSize.expand(min: 100),
                    ),
                    ResizableChild(
                      size: ResizableSize.pixels(
                        _initialTerminalHeight,
                        min: 50,
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 35,
                            color: const Color(0xFF181825),
                            child: Row(
                              children: [
                                _buildBottomTab(
                                    ref, BottomPanelTab.terminal, 'TERMINAL'),
                                _buildBottomTab(
                                    ref, BottomPanelTab.problems, 'PROBLEMS'),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_down,
                                      size: 16),
                                  onPressed: () =>
                                      setState(() => _showTerminal = false),
                                  tooltip: 'Hide Panel',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () =>
                                      setState(() => _showTerminal = false),
                                  tooltip: 'Close Panel',
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final activeTab =
                                    ref.watch(bottomPanelTabProvider);
                                return activeTab == BottomPanelTab.terminal
                                    ? const TerminalWidget()
                                    : const ProblemsView();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const FileTabsWidget(),
                    const Divider(height: 1),
                    const Expanded(child: CodeEditorWidget()),
                  ],
                ),
        ),
        Consumer(
          builder: (context, ref, child) {
            final showAI = ref.watch(aiPanelVisibleProvider);
            if (!showAI) return const SizedBox.shrink();

            return Row(
              children: [
                const VerticalDivider(width: 1, thickness: 1),
                const SizedBox(width: 300, child: AIChatWidget()),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSidebarContent(ActivityItem item) {
    switch (item) {
      case ActivityItem.explorer:
        return const FileTreeWidget();
      case ActivityItem.search:
        return const SearchWidget();
      case ActivityItem.sourceControl:
        return const GitWidget();
      case ActivityItem.debug:
        return const DebugPanelWidget();
      default:
        return const SizedBox.shrink();
    }
  }

  void _runFlutter() {
    final projectPath = ref.read(projectPathProvider);
    if (projectPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please open a Flutter project first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E), // Match theme
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const FlutterRunnerWidget(),
      ),
    );
  }

  void _buildApk() async {
    final bridge = ref.read(termuxBridgeProvider);
    if (!_showTerminal) setState(() => _showTerminal = true);
    final result = await bridge.flutterBuildApk();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success ? 'Build Started' : 'Error: ${result.stderr}',
          ),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _createNewProject() async {
    final currentDir = ref.read(currentDirectoryProvider);
    final result = await showFlutterCreateDialog(context, currentDir);
    if (result == true && mounted) {
      // Refresh the file tree for the new project folder
      // The dialog already updates projectPathProvider
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在準備專案環境...')),
      );
    }
  }

  void _goToDefinition() async {
    final currentFile = ref.read(currentFileProvider);
    final position = ref.read(cursorPositionProvider);
    if (currentFile == null || position == null) return;

    final lsp = ref.read(lspServiceProvider);
    final location =
        await lsp.getDefinition(currentFile, position.line, position.column);

    if (location != null) {
      final uri = location['uri'] as String;
      final range = location['range'] as Map<String, dynamic>;
      final start = range['start'] as Map<String, dynamic>;
      final line = start['line'] as int;

      final filePath = uri.replaceAll('file://', '');
      ref.read(editorRequestProvider.notifier).jumpToLine(filePath, line + 1);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No definition found')),
      );
    }
  }

  void _findReferences() async {
    final currentFile = ref.read(currentFileProvider);
    final position = ref.read(cursorPositionProvider);
    if (currentFile == null || position == null) return;

    final lsp = ref.read(lspServiceProvider);
    final references =
        await lsp.getReferences(currentFile, position.line, position.column);

    if (!mounted) return;
    showReferencesDialog(context, ref, references, 'Symbol');
  }

  void _formatDocument() {
    final currentFile = ref.read(currentFileProvider);
    if (currentFile == null) return;

    ref
        .read(editorRequestProvider.notifier)
        .request(FormatRequest(currentFile));
  }

  void _openFindReplace() {
    ref.read(editorRequestProvider.notifier).request(FindReplaceRequest());
  }

  Widget _buildBottomTab(WidgetRef ref, BottomPanelTab tab, String label) {
    final activeTab = ref.watch(bottomPanelTabProvider);
    final isActive = activeTab == tab;

    return InkWell(
      onTap: () => ref.read(bottomPanelTabProvider.notifier).state = tab,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFFCBA6F7) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : Colors.grey,
              ),
            ),
            if (tab == BottomPanelTab.problems) ...[
              const SizedBox(width: 4),
              Consumer(
                builder: (context, ref, _) {
                  final count =
                      ref.watch(diagnosticsProvider).allDiagnostics.length;
                  if (count == 0) return const SizedBox.shrink();
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF313244),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
