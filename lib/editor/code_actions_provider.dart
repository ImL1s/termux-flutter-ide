import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/lsp_service.dart';
import 'diagnostics_provider.dart';

/// Represents a single code action returned by LSP
class CodeAction {
  final String title;
  final String? kind; // e.g., 'quickfix', 'refactor'
  final Map<String, dynamic>? edit; // WorkspaceEdit
  final Map<String, dynamic>? command; // Command to execute
  final bool isPreferred;

  const CodeAction({
    required this.title,
    this.kind,
    this.edit,
    this.command,
    this.isPreferred = false,
  });

  factory CodeAction.fromJson(Map<String, dynamic> json) {
    return CodeAction(
      title: json['title'] ?? 'Unknown Action',
      kind: json['kind'],
      edit: json['edit'],
      command: json['command'],
      isPreferred: json['isPreferred'] ?? false,
    );
  }

  bool get isQuickFix => kind?.startsWith('quickfix') ?? false;
  bool get isRefactor => kind?.startsWith('refactor') ?? false;
}

/// State for code actions at the current cursor position
class CodeActionsState {
  final List<CodeAction> actions;
  final bool isLoading;
  final String? error;

  const CodeActionsState({
    this.actions = const [],
    this.isLoading = false,
    this.error,
  });

  CodeActionsState copyWith({
    List<CodeAction>? actions,
    bool? isLoading,
    String? error,
  }) {
    return CodeActionsState(
      actions: actions ?? this.actions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get hasActions => actions.isNotEmpty;
}

/// Notifier to manage code actions state
class CodeActionsNotifier extends Notifier<CodeActionsState> {
  @override
  CodeActionsState build() => const CodeActionsState();

  /// Fetch code actions for a specific position
  Future<void> fetchCodeActions({
    required String filePath,
    required int line,
    required int column,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final lsp = ref.read(lspServiceProvider);
      if (!lsp.isStarted) {
        state = state.copyWith(isLoading: false, actions: []);
        return;
      }

      // Get diagnostics for this file to pass to the request
      final diagnosticsState = ref.read(diagnosticsProvider);
      final fileUri = 'file://$filePath';
      final fileDiagnostics = diagnosticsState.fileDiagnostics[fileUri] ?? [];

      final rawActions = await lsp.getCodeActions(
        filePath,
        line,
        column,
        fileDiagnostics,
      );

      final actions = rawActions.map((j) => CodeAction.fromJson(j)).toList();

      // Sort: preferred first, then quickfixes, then refactorings
      actions.sort((a, b) {
        if (a.isPreferred && !b.isPreferred) return -1;
        if (!a.isPreferred && b.isPreferred) return 1;
        if (a.isQuickFix && !b.isQuickFix) return -1;
        if (!a.isQuickFix && b.isQuickFix) return 1;
        return a.title.compareTo(b.title);
      });

      state = state.copyWith(actions: actions, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        actions: [],
      );
    }
  }

  /// Clear actions (e.g., when cursor moves)
  void clear() {
    state = const CodeActionsState();
  }
}

/// Provider for code actions
final codeActionsProvider =
    NotifierProvider<CodeActionsNotifier, CodeActionsState>(
  CodeActionsNotifier.new,
);
