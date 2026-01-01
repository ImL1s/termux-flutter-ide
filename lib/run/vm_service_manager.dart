import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart';
import 'package:termux_flutter_ide/run/breakpoint_service.dart';

enum VMServiceStatus {
  disconnected,
  connecting,
  connected,
  paused,
  error,
}

class VMServiceManager {
  vm.VmService? _service;
  VMServiceStatus _status = VMServiceStatus.disconnected;
  final Ref _ref;
  ProviderSubscription? _breakpointSub;

  // Variables state (can be a separate provider later)
  final _variablesController =
      StreamController<List<vm.BoundVariable>>.broadcast();
  Stream<List<vm.BoundVariable>> get variablesStream =>
      _variablesController.stream;

  VMServiceManager(this._ref);

  vm.VmService? get service => _service;
  VMServiceStatus get status => _status;

  final _statusController = StreamController<VMServiceStatus>.broadcast();
  Stream<VMServiceStatus> get statusStream => _statusController.stream;

  void _updateStatus(VMServiceStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  @visibleForTesting
  void debugSetStatus(VMServiceStatus status) {
    _updateStatus(status);
  }

  Future<void> connect(String wsUri) async {
    _updateStatus(VMServiceStatus.connecting);
    try {
      _service = await vmServiceConnectUri(wsUri);

      // Listen for pause events
      _service!.onDebugEvent.listen((vm.Event event) {
        if (event.kind == vm.EventKind.kPauseStart ||
            event.kind == vm.EventKind.kPauseExit ||
            event.kind == vm.EventKind.kPauseBreakpoint ||
            event.kind == vm.EventKind.kPauseInterrupted ||
            event.kind == vm.EventKind.kPauseException) {
          _updateStatus(VMServiceStatus.paused);
          _fetchVariables(event.isolate!.id!, event.topFrame!.index!);
        } else if (event.kind == vm.EventKind.kResume) {
          _updateStatus(VMServiceStatus.connected);
          _variablesController.add([]); // Clear variables on resume
        }
      });

      await _service!.streamListen(vm.EventStreams.kDebug);
      _updateStatus(VMServiceStatus.connected);

      // Sync existing breakpoints
      _syncInitialBreakpoints();

      // Listen for future breakpoint changes
      _breakpointSub = _ref.listen(breakpointsProvider, (previous, next) {
        _handleBreakpointChanges(previous?.breakpoints ?? [], next.breakpoints);
      });
    } catch (e) {
      print('VMServiceManager: Connection failed: $e');
      _updateStatus(VMServiceStatus.error);
    }
  }

  Future<void> pause() async {
    if (_service == null) return;
    final vmData = await _service!.getVM();
    for (final isolateRef in vmData.isolates!) {
      await _service!.pause(isolateRef.id!);
    }
  }

  Future<void> resume() async {
    if (_service == null) return;
    final vmData = await _service!.getVM();
    for (final isolateRef in vmData.isolates!) {
      await _service!.resume(isolateRef.id!);
    }
  }

  void disconnect() {
    _breakpointSub?.close();
    _service?.dispose();
    _service = null;
    _updateStatus(VMServiceStatus.disconnected);
    _variablesController.add([]);
  }

  Future<void> _syncInitialBreakpoints() async {
    final bps = _ref.read(breakpointsProvider).breakpoints;
    for (final bp in bps) {
      await _addVmBreakpoint(bp);
    }
  }

  void _handleBreakpointChanges(
      List<Breakpoint> previous, List<Breakpoint> next) {
    // Diff breakpoints and update VM
    final added = next.where((b) => !previous.contains(b)).toList();
    final removed = previous.where((b) => !next.contains(b)).toList();

    for (final bp in added) {
      _addVmBreakpoint(bp);
    }

    for (final bp in removed) {
      _removeVmBreakpoint(bp);
    }
  }

  Future<void> _addVmBreakpoint(Breakpoint bp) async {
    if (_service == null) return;
    try {
      // Find main isolate (simplified)
      final vmData = await _service!.getVM();
      final isolateId = vmData.isolates!.first.id!;

      // Use file:/// URI for Termux absolute paths
      final uri = 'file://${bp.path}';
      final result =
          await _service!.addBreakpointWithScriptUri(isolateId, uri, bp.line);

      _ref
          .read(breakpointsProvider.notifier)
          .updateVmId(bp.path, bp.line, result.id);
    } catch (e) {
      print('VMServiceManager: Failed to add breakpoint: $e');
    }
  }

  Future<void> _removeVmBreakpoint(Breakpoint bp) async {
    if (_service == null || bp.id == null) return;
    try {
      final vmData = await _service!.getVM();
      final isolateId = vmData.isolates!.first.id!;
      await _service!.removeBreakpoint(isolateId, bp.id!);
    } catch (e) {
      print('VMServiceManager: Failed to remove breakpoint: $e');
    }
  }

  // Call Stack state
  final _callStackController = StreamController<List<vm.Frame>>.broadcast();
  Stream<List<vm.Frame>> get callStackStream => _callStackController.stream;

  // State tracking for context-aware operations
  String? _currentIsolateId;
  // ignore: unused_field
  int? _currentFrameIndex;

  // Execution Control
  Future<void> stepOver() async {
    if (_service == null) return;
    try {
      final vmData = await _service!.getVM();
      for (final isolateRef in vmData.isolates!) {
        // Resume with StepOption.kOver
        await _service!.resume(isolateRef.id!, step: vm.StepOption.kOver);
      }
      _updateStatus(VMServiceStatus.connected); // Briefly resume to connected
    } catch (e) {
      print('VMServiceManager: Failed to Step Over: $e');
    }
  }

  Future<void> stepInto() async {
    if (_service == null) return;
    try {
      final vmData = await _service!.getVM();
      for (final isolateRef in vmData.isolates!) {
        await _service!.resume(isolateRef.id!, step: vm.StepOption.kInto);
      }
      _updateStatus(VMServiceStatus.connected);
    } catch (e) {
      print('VMServiceManager: Failed to Step Into: $e');
    }
  }

  Future<void> stepOut() async {
    if (_service == null) return;
    try {
      final vmData = await _service!.getVM();
      for (final isolateRef in vmData.isolates!) {
        await _service!.resume(isolateRef.id!, step: vm.StepOption.kOut);
      }
      _updateStatus(VMServiceStatus.connected);
    } catch (e) {
      print('VMServiceManager: Failed to Step Out: $e');
    }
  }

  // Expression Evaluation
  Future<String> evaluateExpression(String expression) async {
    if (_service == null) return 'Error: Not connected';
    if (_currentIsolateId == null)
      return 'Error: No active execution context (not paused?)';

    try {
      // Evaluate in the context of the current isolate's top frame (or library if no frame?)
      // We usually want to evaluate in the current frame context.
      // But vm_service 'evaluate' takes targetId which is library or class or instance.
      // To evaluate in frame scope, we use 'evaluateInFrame'.

      final result = await _service!.evaluateInFrame(
          _currentIsolateId!, _currentFrameIndex ?? 0, expression);

      if (result is vm.InstanceRef) {
        return result.valueAsString ?? result.classRef?.name ?? 'Instance';
      } else if (result is vm.ErrorRef) {
        return 'Error: ${result.message}';
      }
      return result.toString();
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<void> _fetchVariables(String isolateId, int frameIndex) async {
    if (_service == null) return;

    _currentIsolateId = isolateId;
    _currentFrameIndex = frameIndex;

    try {
      final stack = await _service!.getStack(isolateId);

      // Update Call Stack
      if (stack.frames != null) {
        _callStackController.add(stack.frames!);
      }

      if (frameIndex < (stack.frames?.length ?? 0)) {
        final frame = stack.frames![frameIndex];
        final List<vm.BoundVariable> vars = [];

        for (final variable in frame.vars!) {
          vars.add(variable);
        }
        _variablesController.add(vars);
      }
    } catch (e) {
      print('VMServiceManager: Failed to fetch variables and stack: $e');
    }
  }
}

final vmServiceManagerProvider = Provider<VMServiceManager>((ref) {
  return VMServiceManager(ref);
});

final vmServiceStatusProvider = StreamProvider<VMServiceStatus>((ref) {
  final manager = ref.watch(vmServiceManagerProvider);
  return manager.statusStream;
});
