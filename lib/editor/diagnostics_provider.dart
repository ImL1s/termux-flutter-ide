import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DiagnosticSeverity {
  error,
  warning,
  information,
  hint,
}

class LspRange {
  final int startLine;
  final int startColumn;
  final int endLine;
  final int endColumn;

  const LspRange({
    required this.startLine,
    required this.startColumn,
    required this.endLine,
    required this.endColumn,
  });

  factory LspRange.fromJson(Map<String, dynamic> json) {
    return LspRange(
      startLine: json['start']['line'],
      startColumn: json['start']['character'],
      endLine: json['end']['line'],
      endColumn: json['end']['character'],
    );
  }
}

class LspDiagnostic {
  final LspRange range;
  final DiagnosticSeverity severity;
  final String? code;
  final String? source;
  final String message;

  const LspDiagnostic({
    required this.range,
    required this.severity,
    this.code,
    this.source,
    required this.message,
  });

  factory LspDiagnostic.fromJson(Map<String, dynamic> json) {
    final severityInt = json['severity'] as int?;
    final severity = _mapSeverity(severityInt);
    
    final rangeJson = json['range'] as Map<String, dynamic>? ?? {};
    final start = rangeJson['start'] as Map<String, dynamic>? ?? {};
    final end = rangeJson['end'] as Map<String, dynamic>? ?? {};

    return LspDiagnostic(
      range: LspRange(
        startLine: start['line'] as int? ?? 0,
        startColumn: start['character'] as int? ?? 0,
        endLine: end['line'] as int? ?? 0,
        endColumn: end['character'] as int? ?? 0,
      ),
      severity: severity,
      code: json['code']?.toString(),
      source: json['source'] as String?,
      message: json['message'] as String? ?? '',
    );
  }

  static DiagnosticSeverity _mapSeverity(int? severity) {
    switch (severity) {
      case 1:
        return DiagnosticSeverity.error;
      case 2:
        return DiagnosticSeverity.warning;
      case 3:
        return DiagnosticSeverity.information;
      case 4:
        return DiagnosticSeverity.hint;
      default:
        return DiagnosticSeverity.information;
    }
  }
}

class DiagnosticsState {
  // Map of file URI to list of diagnostics
  final Map<String, List<LspDiagnostic>> fileDiagnostics;

  const DiagnosticsState({this.fileDiagnostics = const {}});

  DiagnosticsState copyWith(
      {Map<String, List<LspDiagnostic>>? fileDiagnostics}) {
    return DiagnosticsState(
      fileDiagnostics: fileDiagnostics ?? this.fileDiagnostics,
    );
  }

  List<LspDiagnostic> get allDiagnostics {
    return fileDiagnostics.values.expand((element) => element).toList();
  }
}

class DiagnosticsNotifier extends Notifier<DiagnosticsState> {
  @override
  DiagnosticsState build() {
    return const DiagnosticsState();
  }

  void updateDiagnostics(String uri, List<LspDiagnostic> diagnostics) {
    final newMap = Map<String, List<LspDiagnostic>>.from(state.fileDiagnostics);
    if (diagnostics.isEmpty) {
      newMap.remove(uri);
    } else {
      newMap[uri] = diagnostics;
    }
    state = state.copyWith(fileDiagnostics: newMap);
  }

  void clear() {
    state = const DiagnosticsState();
  }
}

final diagnosticsProvider =
    NotifierProvider<DiagnosticsNotifier, DiagnosticsState>(
  DiagnosticsNotifier.new,
);
