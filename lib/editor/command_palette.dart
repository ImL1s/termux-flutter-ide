import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Command Model
class Command {
  final String id;
  final String title;
  final IconData? icon;
  final VoidCallback action;
  final String? category;

  Command({
    required this.id,
    required this.title,
    required this.action,
    this.icon,
    this.category,
  });
}

/// Command Registry Service
class CommandService {
  final Map<String, Command> _commands = {};

  void register(Command command) {
    _commands[command.id] = command;
  }

  void unregister(String id) {
    _commands.remove(id);
  }

  List<Command> search(String query) {
    if (query.isEmpty) return _commands.values.toList();
    
    final lowerQuery = query.toLowerCase();
    return _commands.values.where((cmd) {
      return cmd.title.toLowerCase().contains(lowerQuery) ||
             (cmd.category?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}

/// Command Palette Provider
final commandServiceProvider = Provider<CommandService>((ref) => CommandService());

/// Helper to show command palette
void showCommandPalette(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E2E), // Catppuccin Base
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const CommandPaletteWidget(),
  );
}

class CommandPaletteWidget extends ConsumerStatefulWidget {
  const CommandPaletteWidget({super.key});

  @override
  ConsumerState<CommandPaletteWidget> createState() => _CommandPaletteWidgetState();
}

class _CommandPaletteWidgetState extends ConsumerState<CommandPaletteWidget> {
  final _controller = TextEditingController();
  List<Command> _results = [];

  @override
  void initState() {
    super.initState();
    _updateResults();
  }

  void _updateResults() {
    setState(() {
      _results = ref.read(commandServiceProvider).search(_controller.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type a command...',
                  prefixIcon: const Icon(Icons.code, color: Color(0xFFCBA6F7)),
                  filled: true,
                  fillColor: const Color(0xFF313244),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (_) => _updateResults(),
              ),
            ),
            const Divider(color: Color(0xFF45475A)),
            // Results List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final command = _results[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF313244),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(command.icon ?? Icons.code, size: 20, color: Colors.grey[400]),
                    ),
                    title: Text(
                      command.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    subtitle: command.category != null
                        ? Text(
                            command.category!,
                            style: const TextStyle(color: Colors.grey),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      command.action();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
