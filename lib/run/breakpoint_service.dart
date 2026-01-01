import 'package:flutter_riverpod/flutter_riverpod.dart';

class Breakpoint {
  final String path;
  final int line; // 1-based
  final String? id; // VM side ID
  final String? condition; // Conditional breakpoint expression

  Breakpoint({
    required this.path,
    required this.line,
    this.id,
    this.condition,
  });

  Breakpoint copyWith({
    String? path,
    int? line,
    String? id,
    String? condition,
  }) {
    return Breakpoint(
      path: path ?? this.path,
      line: line ?? this.line,
      id: id ?? this.id,
      condition: condition ?? this.condition,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Breakpoint &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          line == other.line &&
          condition == other.condition;

  @override
  int get hashCode => path.hashCode ^ line.hashCode ^ condition.hashCode;
}

class BreakpointsState {
  final List<Breakpoint> breakpoints;

  BreakpointsState({this.breakpoints = const []});

  List<Breakpoint> getByPath(String path) {
    return breakpoints.where((b) => b.path == path).toList();
  }
}

class BreakpointsNotifier extends Notifier<BreakpointsState> {
  @override
  BreakpointsState build() => BreakpointsState();

  void toggleBreakpoint(String path, int line, {String? condition}) {
    print(
        'BreakpointsNotifier.toggleBreakpoint CALLED: path=$path, line=$line, condition=$condition');
    final existing =
        state.breakpoints.indexWhere((b) => b.path == path && b.line == line);

    if (existing != -1) {
      // Remove
      state = BreakpointsState(
        breakpoints: [...state.breakpoints]..removeAt(existing),
      );
      print(
          'BreakpointsNotifier: REMOVED breakpoint. Total: ${state.breakpoints.length}');
    } else {
      // Add
      state = BreakpointsState(
        breakpoints: [
          ...state.breakpoints,
          Breakpoint(path: path, line: line, condition: condition)
        ],
      );
      print(
          'BreakpointsNotifier: ADDED breakpoint. Total: ${state.breakpoints.length}');
    }
  }

  void updateVmId(String path, int line, String? vmId) {
    state = BreakpointsState(
      breakpoints: state.breakpoints.map((b) {
        if (b.path == path && b.line == line) {
          return b.copyWith(id: vmId);
        }
        return b;
      }).toList(),
    );
  }

  void clear() {
    state = BreakpointsState();
  }
}

final breakpointsProvider =
    NotifierProvider<BreakpointsNotifier, BreakpointsState>(
  BreakpointsNotifier.new,
);
