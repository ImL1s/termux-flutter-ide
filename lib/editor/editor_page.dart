import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'code_editor_widget.dart';
import 'file_tabs_widget.dart';
import '../file_manager/file_tree_widget.dart';
import '../terminal/terminal_widget.dart';
import '../termux/termux_providers.dart';
import '../ai/ai_chat_widget.dart';
import '../ai/ai_providers.dart';
import '../search/search_widget.dart';
import 'activity_bar.dart';
import 'package:flutter_resizable_container/flutter_resizable_container.dart';
import 'command_palette.dart';
import '../git/git_widget.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  bool _showTerminal = true;
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
    
    registry.register(Command(
      id: 'flutter.run',
      title: 'Run Flutter App',
      category: 'Flutter',
      icon: Icons.play_arrow,
      action: _runFlutter,
    ));

    registry.register(Command(
      id: 'flutter.build.apk',
      title: 'Build APK',
      category: 'Flutter',
      icon: Icons.build,
      action: _buildApk,
    ));

    registry.register(Command(
      id: 'view.toggleTerminal',
      title: 'Toggle Terminal',
      category: 'View',
      icon: Icons.terminal,
      action: () {
        setState(() => _showTerminal = !_showTerminal);
      },
    ));

    registry.register(Command(
      id: 'view.toggleAI',
      title: 'Toggle AI Assistant',
      category: 'View',
      icon: Icons.psychology,
      action: () {
        ref.read(aiPanelVisibleProvider.notifier).toggle();
      },
    ));
    
    registry.register(Command(
      id: 'file.newFile',
      title: 'New File',
      category: 'File',
      icon: Icons.note_add,
      action: () {
         // TODO: Trigger new file dialog from FileTree
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final selectedActivity = ref.watch(selectedActivityProvider);
    // 預設 terminal 高度狀態 (如果需要可以移到 Riverpod)

    return Scaffold(
      appBar: AppBar(
        title: const Text('Termux Flutter IDE'),
        automaticallyImplyLeading: false, // 移除預設 back button
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
      ),
      body: Row(
        children: [
          // 1. Activity Bar (Always visible)
          const ActivityBar(),
          
          // 2. Left Sidebar (Dynamic)
          if (selectedActivity != ActivityItem.none) ...[
            const VerticalDivider(width: 1, thickness: 1),
            SizedBox(
              width: 250,
              child: _buildSidebarContent(selectedActivity),
            ),
          ],
          
          const VerticalDivider(width: 1, thickness: 1),
          
          // 3. Main Content (Editor + Terminal)
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
                        size: ResizableSize.pixels(_initialTerminalHeight, min: 50),
                        child: Column(
                          children: [
                            // Terminal Header
                            Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              color: const Color(0xFF181825),
                              child: Row(
                                children: [
                                  const Text('TERMINAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                    onPressed: () => setState(() => _showTerminal = false),
                                    tooltip: 'Hide Terminal',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () => setState(() => _showTerminal = false),
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
          
          // 4. Right Sidebar (AI Chat)
          Consumer(builder: (context, ref, child) {
            final showAI = ref.watch(aiPanelVisibleProvider);
            if (!showAI) return const SizedBox.shrink();
            
            return Row(
              children: [
                const VerticalDivider(width: 1, thickness: 1),
                const SizedBox(
                  width: 300,
                  child: AIChatWidget(),
                ),
              ],
            );
          }),
        ],
      ),
      // 新增底部按鈕來顯示終端機 (如果隱藏的話)
      bottomNavigationBar: !_showTerminal
          ? Container(
              height: 24,
              color: const Color(0xFF1E1E2E), // Catppuccin Base (Status Bar)
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => setState(() => _showTerminal = true),
                    child: const Row(
                      children: [
                         Icon(Icons.terminal, size: 14, color: Colors.white70),
                         SizedBox(width: 4),
                         Text('Terminal', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
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
      case ActivityItem.extensions:
        return const Center(child: Text('Settings not implemented yet'));
      default:
        return const SizedBox.shrink();
    }
  }

  void _runFlutter() async {
    final bridge = ref.read(termuxBridgeProvider);
    
    // 開啟終端機面板
    if (!_showTerminal) {
      setState(() => _showTerminal = true);
    }
    
    // 透過 Termux 執行 flutter run
    final result = await bridge.flutterRun();
    
    if (!result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Termux 錯誤: ${result.stderr}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _buildApk() async {
    final bridge = ref.read(termuxBridgeProvider);
    
    // 開啟終端機面板
    if (!_showTerminal) {
      setState(() => _showTerminal = true);
    }
    
    // 透過 Termux 執行 flutter build apk
    final result = await bridge.flutterBuildApk();
    
    if (result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('APK 建置指令已發送到 Termux'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Termux 錯誤: ${result.stderr}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
