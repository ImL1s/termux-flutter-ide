import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Watch Expression model
class WatchExpression {
  final String expression;
  final String? value;
  final bool isError;

  const WatchExpression({
    required this.expression,
    this.value,
    this.isError = false,
  });

  WatchExpression copyWith({String? expression, String? value, bool? isError}) {
    return WatchExpression(
      expression: expression ?? this.expression,
      value: value ?? this.value,
      isError: isError ?? this.isError,
    );
  }
}

/// Watch Expressions Notifier
class WatchExpressionsNotifier extends Notifier<List<WatchExpression>> {
  @override
  List<WatchExpression> build() => [];

  void add(String expression) {
    if (expression.trim().isEmpty) return;
    if (state.any((w) => w.expression == expression)) return;

    state = [...state, WatchExpression(expression: expression.trim())];
  }

  void remove(String expression) {
    state = state.where((w) => w.expression != expression).toList();
  }

  void clear() {
    state = [];
  }

  void updateValue(String expression, String value, {bool isError = false}) {
    state = state.map((w) {
      if (w.expression == expression) {
        return w.copyWith(value: value, isError: isError);
      }
      return w;
    }).toList();
  }

  /// Evaluate all watch expressions (called when debugger pauses)
  Future<void> evaluateAll(
      Future<String?> Function(String expr) evaluator) async {
    for (final watch in state) {
      try {
        final result = await evaluator(watch.expression);
        updateValue(watch.expression, result ?? '<null>');
      } catch (e) {
        updateValue(watch.expression, e.toString(), isError: true);
      }
    }
  }
}

final watchExpressionsProvider =
    NotifierProvider<WatchExpressionsNotifier, List<WatchExpression>>(
  WatchExpressionsNotifier.new,
);
