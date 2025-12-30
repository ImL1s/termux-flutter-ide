import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../termux/termux_providers.dart';

class TerminalWidget extends ConsumerStatefulWidget {
  const TerminalWidget({super.key});

  @override
  ConsumerState<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends ConsumerState<TerminalWidget> {
  late Terminal _terminal;
  final _terminalController = TerminalController();
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(
      maxLines: 10000,
    );
    _terminal.write('Welcome to Termux Flutter IDE Terminal\r\n');
    _terminal.write('\$ ');
  }

  @override
  void dispose() {
    _terminalController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: Column(
        children: [
          // Terminal header
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF181825),
              border: Border(
                bottom: BorderSide(color: Color(0xFF313244)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 14, color: Color(0xFF00D4AA)),
                const SizedBox(width: 8),
                const Text(
                  'TERMINAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all, size: 16),
                  onPressed: _clearTerminal,
                  tooltip: 'Clear',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
          // Terminal content
          Expanded(
            child: TerminalView(
              _terminal,
              controller: _terminalController,
              autofocus: false,
              backgroundOpacity: 0,
              textStyle: const TerminalStyle(
                fontSize: 13,
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF181825),
              border: Border(
                top: BorderSide(color: Color(0xFF313244)),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  '\$ ',
                  style: TextStyle(
                    color: Color(0xFF00D4AA),
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Enter command...',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    onSubmitted: _executeCommand,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, size: 16),
                  onPressed: () => _executeCommand(_inputController.text),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _executeCommand(String command) async {
    if (command.trim().isEmpty) return;
    
    _terminal.write('$command\r\n');
    _inputController.clear();
    
    // 使用 Termux Bridge 執行指令
    final bridge = ref.read(termuxBridgeProvider);
    
    if (command == 'clear') {
      _terminal.eraseDisplay();
      _terminal.write('\$ ');
      _focusNode.requestFocus();
      return;
    }
    
    if (command == 'help') {
      _terminal.write('Available commands:\r\n');
      _terminal.write('  flutter run       - Run Flutter app via Termux\r\n');
      _terminal.write('  flutter build apk - Build APK via Termux\r\n');
      _terminal.write('  flutter doctor    - Check Flutter setup\r\n');
      _terminal.write('  clear             - Clear terminal\r\n');
      _terminal.write('\r\n');
      _terminal.write('\$ ');
      _focusNode.requestFocus();
      return;
    }
    
    // 檢查 Termux 是否已安裝
    final isInstalled = await bridge.isTermuxInstalled();
    if (!isInstalled) {
      _terminal.write('\x1B[31mError: Termux is not installed.\x1B[0m\r\n');
      _terminal.write('Please install Termux from F-Droid or GitHub.\r\n');
      _terminal.write('\$ ');
      _focusNode.requestFocus();
      return;
    }
    
    // 執行指令
    _terminal.write('Executing via Termux: $command\r\n');
    final result = await bridge.executeCommand(command);
    
    if (result.success) {
      _terminal.write('\x1B[32m${result.stdout}\x1B[0m\r\n');
    } else {
      _terminal.write('\x1B[31m${result.stderr}\x1B[0m\r\n');
    }
    
    _terminal.write('\$ ');
    _focusNode.requestFocus();
  }

  void _clearTerminal() {
    _terminal.eraseDisplay();
    _terminal.write('Welcome to Termux Flutter IDE Terminal\r\n');
    _terminal.write('\$ ');
  }
}
