import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AI Service Provider
final aiServiceProvider = Provider((ref) => AIService());

/// AI Chat History Provider
final chatHistoryProvider = NotifierProvider<ChatHistoryNotifier, List<ChatMessage>>(
  ChatHistoryNotifier.new,
);

/// AI Panel Visibility Notifier
class AIPanelVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  
  void toggle() => state = !state;
  
  set visible(bool value) => state = value;
}

/// AI Panel Visibility Provider
final aiPanelVisibleProvider = NotifierProvider<AIPanelVisibilityNotifier, bool>(
  AIPanelVisibilityNotifier.new,
);

class AIService {
  Future<String> sendMessage(String message) async {
    // 模擬 AI 回應延遲
    await Future.delayed(const Duration(seconds: 1));
    return '這是 AI 的模擬回應。\n你說了: "$message"\n\n我可以協助你寫程式、解釋代碼或除錯。';
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatHistoryNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => [
    ChatMessage(
      content: '你好！我是你的 AI 程式助手。有什麼我可以幫你的嗎？',
      isUser: false,
    ),
  ];

  void addUserMessage(String content) {
    state = [...state, ChatMessage(content: content, isUser: true)];
  }

  void addAIMessage(String content) {
    state = [...state, ChatMessage(content: content, isUser: false)];
  }
  
  void clear() {
    state = [];
  }
}

/// 發送訊息 Action
final sendMessageProvider = FutureProvider.family<void, String>((ref, message) async {
  final history = ref.read(chatHistoryProvider.notifier);
  final service = ref.read(aiServiceProvider);
  
  // 新增用戶訊息
  history.addUserMessage(message);
  
  try {
    // 獲取 AI 回應
    final response = await service.sendMessage(message);
    history.addAIMessage(response);
  } catch (e) {
    history.addAIMessage('發生錯誤: $e');
  }
});
