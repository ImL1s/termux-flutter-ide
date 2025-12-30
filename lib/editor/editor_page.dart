import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';

import 'code_editor_widget.dart';
import 'file_tabs_widget.dart';
import '../file_manager/file_tree_widget.dart';
import '../terminal/terminal_widget.dart';
import '../termux/termux_providers.dart';
import '../ai/ai_chat_widget.dart';
import '../ai/ai_providers.dart';
import '../search/search_widget.dart';
import 'activity_bar.dart';
import 'command_palette.dart';
import 'package:flutter/services.dart'; // For LogicalKeyboardKey
import '../git/git_widget.dart';
import 'editor_providers.dart';
import '../settings/settings_page.dart';

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
  }

  @override
  Widget build(BuildContext context) {
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
          if (isMobile) {
            _showSearchMobile();
          } else {
            ref
                .read(selectedActivityProvider.notifier)
                .select(ActivityItem.search);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          if (isMobile) {
            _showSearchMobile();
          } else {
            ref
                .read(selectedActivityProvider.notifier)
                .select(ActivityItem.search);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: isMobile ? _buildMobileScaffold() : _buildDesktopScaffold(),
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
        title: const Text('Termux IDE', style: TextStyle(fontSize: 18)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Color(0xFFCBA6F7)),
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
      body: Column(
        children: [
          const FileTabsWidget(),
          const Divider(height: 1),
          const Expanded(child: CodeEditorWidget()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF181825),
        selectedItemColor: const Color(0xFFCBA6F7),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.terminal), label: 'Terminal'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        ],
        onTap: (index) {
          if (index == 0) _showTerminalMobile();
          if (index == 1) _showSearchMobile();
        },
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
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const GitWidget(),
                ),
              );
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
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
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            color: const Color(0xFF181825),
                            child: Row(
                              children: [
                                const Text(
                                  'TERMINAL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_down,
                                      size: 16),
                                  onPressed: () =>
                                      setState(() => _showTerminal = false),
                                  tooltip: 'Hide Terminal',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () =>
                                      setState(() => _showTerminal = false),
                                  tooltip: 'Close Terminal',
                                ),
                              ],
                            ),
                          ),
                          const Expanded(child: TerminalWidget()),
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
      default:
        return const SizedBox.shrink();
    }
  }

  void _runFlutter() async {
    final bridge = ref.read(termuxBridgeProvider);
    if (!_showTerminal) setState(() => _showTerminal = true);
    final result = await bridge.flutterRun();
    if (!result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${result.stderr}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
}
