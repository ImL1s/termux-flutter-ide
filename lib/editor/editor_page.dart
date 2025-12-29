import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'code_editor_widget.dart';
import 'file_tabs_widget.dart';
import '../file_manager/file_tree_widget.dart';
import '../terminal/terminal_widget.dart';

class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  bool _showFileTree = true;
  bool _showTerminal = true;
  double _terminalHeight = 200;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termux Flutter IDE'),
        actions: [
          IconButton(
            icon: Icon(_showFileTree ? Icons.folder_open : Icons.folder),
            onPressed: () => setState(() => _showFileTree = !_showFileTree),
            tooltip: 'Toggle File Tree',
          ),
          IconButton(
            icon: Icon(_showTerminal ? Icons.terminal : Icons.terminal_outlined),
            onPressed: () => setState(() => _showTerminal = !_showTerminal),
            tooltip: 'Toggle Terminal',
          ),
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
      body: Column(
        children: [
          // Main content area
          Expanded(
            child: Row(
              children: [
                // File Tree Panel
                if (_showFileTree)
                  const SizedBox(
                    width: 250,
                    child: FileTreeWidget(),
                  ),
                if (_showFileTree)
                  const VerticalDivider(width: 1, thickness: 1),
                
                // Editor Area
                Expanded(
                  child: Column(
                    children: [
                      // File tabs
                      const FileTabsWidget(),
                      const Divider(height: 1),
                      // Code editor
                      const Expanded(child: CodeEditorWidget()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Terminal Panel
          if (_showTerminal) ...[
            GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  _terminalHeight = (_terminalHeight - details.delta.dy)
                      .clamp(100.0, 400.0);
                });
              },
              child: Container(
                height: 8,
                color: Theme.of(context).dividerColor,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: _terminalHeight,
              child: const TerminalWidget(),
            ),
          ],
        ],
      ),
    );
  }

  void _runFlutter() {
    // TODO: Implement flutter run via Termux
  }

  void _buildApk() {
    // TODO: Implement flutter build apk via Termux
  }
}
