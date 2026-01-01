import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RunnerActionType {
  missingX11,
}

class RunnerAction {
  final RunnerActionType type;
  final Map<String, dynamic>? payload;

  const RunnerAction(this.type, {this.payload});
}

/// Provider for side-effects from the Runner Service to the UI
final runnerActionProvider =
    NotifierProvider<RunnerActionNotifier, RunnerAction?>(
  RunnerActionNotifier.new,
);

class RunnerActionNotifier extends Notifier<RunnerAction?> {
  @override
  RunnerAction? build() => null;

  void setAction(RunnerAction? action) {
    state = action;
  }
}
