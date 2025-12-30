import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_providers.dart';
import '../theme/app_theme.dart';

class AIChatWidget extends ConsumerStatefulWidget {
  const AIChatWidget({super.key});

  @override
  ConsumerState<AIChatWidget> createState() => _AIChatWidgetState();
}

class _AIChatWidgetState extends ConsumerState<AIChatWidget> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    ref.read(sendMessageProvider(text));
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(chatHistoryProvider);

    return Container(
      color: AppTheme.editorBg, // Themed
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.surface, // Themed
              border: Border(
                bottom: BorderSide(color: AppTheme.surfaceVariant),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.psychology,
                  size: 16,
                  color: AppTheme.primary,
                ), // Themed
                const SizedBox(width: 8),
                const Text(
                  'AI ASSISTANT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary, // Themed
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  onPressed: () =>
                      ref.read(chatHistoryProvider.notifier).clear(),
                  tooltip: 'Clear Chat',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  color: AppTheme.textDisabled,
                ),
              ],
            ),
          ),

          // Chat List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final msg = history[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.surfaceVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Ask AI anything...',
                      hintStyle: TextStyle(color: AppTheme.textDisabled),
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    cursorColor: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: msg.isUser ? AppTheme.surfaceVariant : AppTheme.surface,
          borderRadius: BorderRadius.circular(12).copyWith(
            bottomRight: msg.isUser ? const Radius.circular(0) : null,
            bottomLeft: !msg.isUser ? const Radius.circular(0) : null,
          ),
        ),
        child: SelectableText(
          msg.content,
          style: TextStyle(
            color: msg.isUser ? AppTheme.textPrimary : AppTheme.textPrimary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
