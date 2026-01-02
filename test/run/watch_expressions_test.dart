import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/run/watch_expressions_provider.dart';

void main() {
  group('WatchExpressionsProvider', () {
    test('initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final watches = container.read(watchExpressionsProvider);
      expect(watches, isEmpty);
    });

    test('add() inserts new expression', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(watchExpressionsProvider.notifier).add('myVar');

      final watches = container.read(watchExpressionsProvider);
      expect(watches.length, 1);
      expect(watches.first.expression, 'myVar');
      expect(watches.first.value, isNull);
      expect(watches.first.isError, isFalse);
    });

    test('add() ignores duplicates', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(watchExpressionsProvider.notifier).add('myVar');
      container.read(watchExpressionsProvider.notifier).add('myVar');

      final watches = container.read(watchExpressionsProvider);
      expect(watches.length, 1);
    });

    test('add() ignores empty strings', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(watchExpressionsProvider.notifier).add('   ');

      final watches = container.read(watchExpressionsProvider);
      expect(watches, isEmpty);
    });

    test('remove() deletes expression', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(watchExpressionsProvider.notifier).add('var1');
      container.read(watchExpressionsProvider.notifier).add('var2');
      container.read(watchExpressionsProvider.notifier).remove('var1');

      final watches = container.read(watchExpressionsProvider);
      expect(watches.length, 1);
      expect(watches.first.expression, 'var2');
    });

    test('updateValue() updates result', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(watchExpressionsProvider.notifier).add('x');
      container.read(watchExpressionsProvider.notifier).updateValue('x', '42');

      final watches = container.read(watchExpressionsProvider);
      expect(watches.first.value, '42');
      expect(watches.first.isError, isFalse);
    });

    test('updateValue() handles errors', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(watchExpressionsProvider.notifier).add('y');
      container
          .read(watchExpressionsProvider.notifier)
          .updateValue('y', 'Error', isError: true);

      final watches = container.read(watchExpressionsProvider);
      expect(watches.first.value, 'Error');
      expect(watches.first.isError, isTrue);
    });
  });
}
