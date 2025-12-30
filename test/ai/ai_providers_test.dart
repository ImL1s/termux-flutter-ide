import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/ai/ai_providers.dart';

void main() {
  group('AIPanelVisibilityNotifier', () {
    test('starts visible by default', () {
      final container = ProviderContainer();
      expect(container.read(aiPanelVisibleProvider), isTrue);
    });

    test('toggle changes visibility', () {
      final container = ProviderContainer();
      container.read(aiPanelVisibleProvider.notifier).toggle();
      expect(container.read(aiPanelVisibleProvider), isFalse);

      container.read(aiPanelVisibleProvider.notifier).toggle();
      expect(container.read(aiPanelVisibleProvider), isTrue);
    });
  });

  group('ChatHistoryNotifier', () {
    test('starts with welcome message', () {
      final container = ProviderContainer();
      final history = container.read(chatHistoryProvider);

      expect(history.length, 1);
      expect(history.first.isUser, isFalse);
      expect(history.first.content, contains('AI'));
    });

    test('addUserMessage adds message', () {
      final container = ProviderContainer();
      container.read(chatHistoryProvider.notifier).addUserMessage('Hello');

      final history = container.read(chatHistoryProvider);
      expect(history.last.content, 'Hello');
      expect(history.last.isUser, isTrue);
    });

    test('addAIMessage adds message', () {
      final container = ProviderContainer();
      container.read(chatHistoryProvider.notifier).addAIMessage('Response');

      final history = container.read(chatHistoryProvider);
      expect(history.last.content, 'Response');
      expect(history.last.isUser, isFalse);
    });

    test('clear empties history', () {
      final container = ProviderContainer();
      container.read(chatHistoryProvider.notifier).addUserMessage('Test');
      container.read(chatHistoryProvider.notifier).clear();

      expect(container.read(chatHistoryProvider), isEmpty);
    });
  });

  group('ChatMessage', () {
    test('creates with current timestamp if not provided', () {
      final before = DateTime.now();
      final msg = ChatMessage(content: 'Test', isUser: true);
      final after = DateTime.now();

      expect(
          msg.timestamp.isAfter(before) ||
              msg.timestamp.isAtSameMomentAs(before),
          isTrue);
      expect(
          msg.timestamp.isBefore(after) ||
              msg.timestamp.isAtSameMomentAs(after),
          isTrue);
    });

    test('uses provided timestamp', () {
      final ts = DateTime(2024, 1, 1);
      final msg = ChatMessage(content: 'Test', isUser: true, timestamp: ts);

      expect(msg.timestamp, ts);
    });
  });

  group('AIService', () {
    test('sendMessage returns simulated response', () async {
      final service = AIService();
      final response = await service.sendMessage('Hello');

      expect(response, contains('AI'));
      expect(response, contains('Hello'));
    });
  });
}
