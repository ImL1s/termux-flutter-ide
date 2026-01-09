import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'package:go_router/go_router.dart';

import 'code_editor_widget.dart';
import 'file_tabs_widget.dart';
import '../file_manager/file_tree_widget.dart';
import '../file_manager/file_operations.dart';
import '../terminal/terminal_widget.dart';
import '../termux/termux_providers.dart';
import '../termux/termux_bridge.dart';
import '../termux/ssh_service.dart';
import '../termux/ssh_error_dialog.dart';
import '../ai/ai_chat_widget.dart';
import '../ai/ai_providers.dart';
import '../search/search_widget.dart';
import '../analyzer/analysis_dashboard.dart';
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

import 'flutter_create_dialog.dart';
import 'package_search_dialog.dart';
import 'problems_view.dart';
import 'diagnostics_provider.dart';
import '../services/lsp_service.dart';
import 'editor_request_provider.dart';
import 'references_dialog.dart';
import 'rename_dialog.dart';
import '../core/responsive.dart';
import 'workspace_symbol_dialog.dart';
import 'recent_files_dialog.dart';
import 'keyboard_shortcuts_dialog.dart';

import '../core/keyboard_shortcuts.dart';
import '../core/input_adaptive.dart';

enum BottomPanelTab { terminal, problems }

final bottomPanelTabProvider =
    StateProvider<BottomPanelTab>((ref) => BottomPanelTab.terminal);

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage>
    with WidgetsBindingObserver {
  bool _showTerminal = false;
  final double _initialTerminalHeight = 250;

  @override
  void initState() {
    super.initState();
    // Register observer for fold state changes
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerCommands();
      // Ensure Termux environment is robust
      TermuxBridge().fixTermuxEnvironment();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when device metrics change (fold/unfold, rotation, etc.)
  /// This ensures UI updates when transitioning between fold states
  @override
  void didChangeMetrics() {
    // Force rebuild to adapt to new fold state
    if (mounted) {
      setState(() {});
    }
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

    registry.register(
      Command(
        id: 'editor.rename',
        title: 'Rename Symbol',
        category: 'Editor',
        icon: Icons.edit,
        action: _renameSymbol,
      ),
    );

    registry.register(
      Command(
        id: 'editor.workspaceSymbol',
        title: 'Search Symbols',
        category: 'Editor',
        icon: Icons.account_tree,
        action: _showWorkspaceSymbolSearch,
      ),
    );

    registry.register(
      Command(
        id: 'editor.recentFiles',
        title: 'Recent Files',
        category: 'Navigation',
        icon: Icons.history,
        action: _showRecentFiles,
      ),
    );

    registry.register(
      Command(
        id: 'flutter.verify',
        title: 'Verify Flutter Toolchain',
        category: 'Flutter',
        icon: Icons.fact_check,
        action: _verifyFlutter,
      ),
    );

    registry.register(
      Command(
        id: 'editor.keyboardShortcuts',
        title: 'Keyboard Shortcuts',
        category: 'Help',
        icon: Icons.keyboard,
        action: () => showKeyboardShortcutsDialog(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Setup keyboard actions mapping
    final actions = buildActions(ref);

    // Get the core scaffold
    Widget scaffold = _buildScaffoldContent();

    // Wrap with comprehensive input handling
    return PopScope(
      canPop: !_showTerminal,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showTerminal) {
          setState(() => _showTerminal = false);
        }
      },
      child: KeyboardShortcutsWrapper(
        child: Actions(
          actions: actions,
          child: FocusTraversalGroup(
            // Enable Tab navigation
            policy: ReadingOrderTraversalPolicy(),
            child: InputAdaptiveWrapper(
              // Unified input handling
              enableHoverEffect: false, // Don't hover the whole page
              enableRipple: false,
              child: scaffold,
            ),
          ),
        ),
      ),
    );
  }

  // ... (existing code)

  Widget _buildScaffoldContent() {
    Widget content;

    // Prioritize flexible/foldable logic
    if (Responsive.isFlexMode(context)) {
      content = _buildFlexModeScaffold();
    } else if (Responsive.getHingeBounds(context) != null &&
        !Responsive.isCoverScreen(context)) {
      // Unfolded state on dual-screen/foldable device
      content = _buildFoldableScaffold();
    } else if (Responsive.isCoverScreen(context)) {
      content = _buildMobileScaffold(); // Re-use mobile layout for cover screen
    } else if (Responsive.isDesktop(context) || Responsive.isTablet(context)) {
      content = _buildDesktopScaffold();
    } else {
      content = _buildMobileScaffold();
    }

    // Smooth transition between layouts
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: KeyedSubtree(
        key: ValueKey(
            '${Responsive.getFormFactor(context)}-${Responsive.isFlexMode(context)}'),
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              // SSH Status Banner - DISABLED: We now use TermuxBridge, SSH is optional
              // The SSH error banner was confusing users since SSH is no longer required
              const SizedBox.shrink(),
              Expanded(
                child: content,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Flex Mode layout: Upper half = Editor, Lower half = Control Panel
  /// Used when device is in half-opened (laptop-like) posture
  Widget _buildFlexModeScaffold() {
    final splitY = Responsive.getFlexModeSplitPosition(context) ??
        MediaQuery.of(context).size.height / 2;
    final foldHeight = Responsive.getFoldHeight(context);

    // Calculate available heights
    final topHeight = splitY - foldHeight / 2;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ===== TOP HALF: Editor =====
            SizedBox(
              height: topHeight - 48, // Account for AppBar
              child: Column(
                children: [
                  // Compact AppBar
                  _buildFlexModeAppBar(),
                  // File Tabs
                  const FileTabsWidget(),
                  const Divider(height: 1),
                  // Code Editor
                  const Expanded(child: CodeEditorWidget()),
                ],
              ),
            ),

            // ===== FOLD GAP =====
            SizedBox(height: foldHeight + 8),

            // ===== BOTTOM HALF: Control Panel =====
            Expanded(
              child: _buildFlexModeControlPanel(),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact AppBar for Flex Mode
  PreferredSizeWidget _buildFlexModeAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(40),
      child: AppBar(
        toolbarHeight: 40,
        title: Consumer(
          builder: (context, ref, _) {
            final projectPath = ref.watch(projectPathProvider);
            final projectName = projectPath?.split('/').last ?? 'IDE';
            return Text(
              projectName,
              style: const TextStyle(fontSize: 14),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow,
                color: Color(0xFFCBA6F7), size: 20),
            onPressed: _runFlutter,
            tooltip: 'Run',
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFFCBA6F7), size: 20),
            onPressed: () => ref.read(saveTriggerProvider.notifier).trigger(),
            tooltip: 'Save',
          ),
        ],
      ),
    );
  }

  /// Control Panel for Flex Mode bottom half
  /// Optimized for touch accessibility and keyboard handling
  Widget _buildFlexModeControlPanel() {
    // Handle keyboard insets to avoid bottom panel being obscured
    final keyboardInsets = MediaQuery.of(context).viewInsets.bottom;
    final hasKeyboard = keyboardInsets > 0;

    return Container(
      color: const Color(0xFF181825),
      child: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            // Tab Bar - Minimum 48px height for touch accessibility
            Container(
              color: const Color(0xFF11111B),
              constraints: const BoxConstraints(minHeight: 48),
              child: const TabBar(
                labelPadding: EdgeInsets.symmetric(horizontal: 12),
                indicatorWeight: 3,
                tabs: [
                  Tab(icon: Icon(Icons.terminal, size: 20), text: 'Terminal'),
                  Tab(
                      icon: Icon(Icons.warning_amber, size: 20),
                      text: 'Problems'),
                  Tab(icon: Icon(Icons.bug_report, size: 20), text: 'Debug'),
                  Tab(icon: Icon(Icons.play_circle, size: 20), text: 'Runner'),
                ],
              ),
            ),
            // Tab Content with PageStorageKey for scroll preservation
            Expanded(
              child: hasKeyboard
                  ? const SizedBox
                      .shrink() // Hide content when keyboard is open
                  : const TabBarView(
                      children: [
                        TerminalWidget(key: PageStorageKey('flex_terminal')),
                        ProblemsView(key: PageStorageKey('flex_problems')),
                        DebugPanelWidget(key: PageStorageKey('flex_debug')),
                        FlutterRunnerWidget(key: PageStorageKey('flex_runner')),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Foldable-specific layout with TwoPane design avoiding the hinge
  Widget _buildFoldableScaffold() {
    final hingeBounds = Responsive.getHingeBounds(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate pane widths avoiding hinge
    final leftPaneWidth =
        hingeBounds != null ? hingeBounds.left : screenWidth * 0.4;
    final hingeWidth = hingeBounds?.width ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Consumer(
          builder: (context, ref, _) {
            final projectPath = ref.watch(projectPathProvider);
            final projectName = projectPath?.split('/').last ?? 'IDE';
            return Text(
              projectPath != null
                  ? '$projectName - Termux IDE'
                  : 'Termux Foldable IDE',
              style: const TextStyle(fontSize: 16),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Color(0xFFCBA6F7)),
            onPressed: _runFlutter,
            tooltip: 'Run',
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFFCBA6F7)),
            onPressed: () => ref.read(saveTriggerProvider.notifier).trigger(),
            tooltip: 'Save',
          ),
          IconButton(
            icon: const Icon(Icons.psychology),
            onPressed: _showAIMobile,
            tooltip: 'AI Assistant',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Pane: Sidebar
          SizedBox(
            width: leftPaneWidth,
            child: Column(
              children: [
                // Activity Bar (simplified horizontal for foldable)
                Container(
                  color: const Color(0xFF11111B),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFoldableActivityIcon(ActivityItem.explorer,
                          Icons.folder_outlined, 'Explorer'),
                      _buildFoldableActivityIcon(
                          ActivityItem.search, Icons.search, 'Search'),
                      _buildFoldableActivityIcon(ActivityItem.sourceControl,
                          Icons.source_outlined, 'Git'),
                      _buildFoldableActivityIcon(ActivityItem.debug,
                          Icons.bug_report_outlined, 'Debug'),
                      _buildFoldableActivityIcon(ActivityItem.analyzer,
                          Icons.analytics_outlined, 'Health'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Sidebar Content
                Expanded(
                  child:
                      _buildSidebarContent(ref.watch(selectedActivityProvider)),
                ),
              ],
            ),
          ),

          // Hinge Spacing (avoid fold crease)
          if (hingeWidth > 0) SizedBox(width: hingeWidth + 8),

          // Right Pane: Editor
          Expanded(
            child: Column(
              children: [
                const FileTabsWidget(),
                const Divider(height: 1),
                const Expanded(child: CodeEditorWidget()),
                // Terminal Toggle
                if (_showTerminal) ...[
                  const Divider(height: 1),
                  SizedBox(
                    height: 200,
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          Container(
                            color: const Color(0xFF181825),
                            child: const TabBar(
                              tabs: [
                                Tab(text: 'Terminal'),
                                Tab(text: 'Problems'),
                              ],
                            ),
                          ),
                          const Expanded(
                            child: TabBarView(
                              children: [
                                TerminalWidget(),
                                ProblemsView(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Helper for foldable activity bar icons
  Widget _buildFoldableActivityIcon(
      ActivityItem item, IconData icon, String tooltip) {
    final isSelected = ref.watch(selectedActivityProvider) == item;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? const Color(0xFFCBA6F7) : Colors.grey,
        size: 22,
      ),
      onPressed: () => ref.read(selectedActivityProvider.notifier).toggle(item),
      tooltip: tooltip,
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
            icon: const Icon(Icons.fact_check, color: Color(0xFFA6E3A1)),
            key: const Key('appbar_verify_action'),
            onPressed: _verifyFlutter,
            tooltip: 'Verify Flutter',
          ),
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
            leading: const Icon(Icons.settings_suggest, color: Color(0xFFA6E3A1)),
            title: const Text('Setup Wizard'),
            onTap: () {
              Navigator.pop(context);
              context.push('/setup');
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
        height: MediaQuery.of(context).size.height * 0.9,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF181825),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: TabBar(
                          isScrollable: true,
                          labelColor: Color(0xFFCBA6F7),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Color(0xFFCBA6F7),
                          tabs: [
                            Tab(
                                text: 'TERMINAL',
                                icon: Icon(Icons.terminal, size: 16)),
                            Tab(
                                text: 'PROBLEMS',
                                icon: Icon(Icons.error_outline, size: 16)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const Expanded(
                  child: TabBarView(
                    children: [
                      TerminalWidget(),
                      ProblemsView(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
      case ActivityItem.analyzer:
        return const AnalysisDashboard();
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

  void _verifyFlutter() async {
    final bridge = ref.read(termuxBridgeProvider);
    if (!_showTerminal) setState(() => _showTerminal = true);

    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在執行 flutter doctor...')),
    );

    // Run stable diagnostic command
    final result = await bridge.executeCommand(
        'bash -c "source /data/data/com.termux/files/usr/etc/profile.d/flutter.sh 2>/dev/null; '
        'flutter --version && flutter doctor"');

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Flutter Toolchain Verification'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Success: ${result.success}'),
                Text('Exit Code: ${result.exitCode}'),
                const Divider(),
                const Text('Output:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(result.stdout.isEmpty ? '(Empty)' : result.stdout),
                if (result.stderr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Error:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  Text(result.stderr,
                      style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _runFlutter() {
    final projectPath = ref.read(projectPathProvider);
    if (projectPath == null) {
    if (projectPath == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Project Open'),
          content: const Text(
              'Running Flutter requires an open project context.\n\nPlease open a project folder via the Explorer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Project Folder'),
              onPressed: () {
                Navigator.pop(context);
                // Trigger Open Folder flow (same as drawer)
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFF1E1E2E),
                  builder: (context) => SizedBox(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: DirectoryBrowser(
                      initialPath: ref.read(currentDirectoryProvider),
                      onSelect: (path) {
                        ref.read(currentDirectoryProvider.notifier).setPath(path);
                        ref.read(projectPathProvider.notifier).set(path);
                        Navigator.pop(context);
                        
                        // Proceed to Runner?
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) _runFlutter();
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
      return;
    }
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

      // Automatically open Explorer to show the new project
      if (MediaQuery.of(context).size.width < 600) {
        _showExplorerMobile();
      } else {
        // Desktop/Tablet: Switch sidebar to explorer
        ref
            .read(selectedActivityProvider.notifier)
            .select(ActivityItem.explorer);
      }
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

  void _renameSymbol() {
    final currentFile = ref.read(currentFileProvider);
    if (currentFile == null) return;
    showRenameDialog(context, ref, currentFile);
  }

  void _showWorkspaceSymbolSearch() {
    showWorkspaceSymbolDialog(context, ref);
  }

  void _showRecentFiles() {
    showRecentFilesDialog(context, ref);
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
