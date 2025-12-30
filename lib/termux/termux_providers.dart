import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'termux_bridge.dart';

/// Termux Bridge Provider
final termuxBridgeProvider = Provider<TermuxBridge>((ref) {
  return TermuxBridge();
});

/// Termux 安裝狀態
final termuxInstalledProvider = FutureProvider<bool>((ref) async {
  final bridge = ref.watch(termuxBridgeProvider);
  return bridge.isTermuxInstalled();
});

/// 命令執行狀態
enum CommandStatus { idle, running, completed, failed }

/// 命令執行狀態 Notifier
class CommandStateNotifier extends Notifier<CommandState> {
  @override
  CommandState build() => const CommandState();
  
  void startCommand(String command) {
    state = CommandState(
      status: CommandStatus.running,
      command: command,
    );
  }
  
  void completeCommand(TermuxResult result) {
    state = CommandState(
      status: result.success ? CommandStatus.completed : CommandStatus.failed,
      command: state.command,
      result: result,
    );
  }
  
  void reset() {
    state = const CommandState();
  }
}

/// 命令執行狀態
class CommandState {
  final CommandStatus status;
  final String? command;
  final TermuxResult? result;
  
  const CommandState({
    this.status = CommandStatus.idle,
    this.command,
    this.result,
  });
  
  bool get isRunning => status == CommandStatus.running;
  bool get isCompleted => status == CommandStatus.completed;
  bool get isFailed => status == CommandStatus.failed;
}

/// 命令執行狀態 Provider
final commandStateProvider = NotifierProvider<CommandStateNotifier, CommandState>(
  CommandStateNotifier.new,
);

/// 執行 Termux 命令的 Action Provider
final executeCommandProvider = Provider.family<Future<TermuxResult>, String>((ref, command) async {
  final bridge = ref.read(termuxBridgeProvider);
  final notifier = ref.read(commandStateProvider.notifier);
  
  notifier.startCommand(command);
  
  try {
    final result = await bridge.executeCommand(command);
    notifier.completeCommand(result);
    return result;
  } catch (e) {
    final errorResult = TermuxResult(
      success: false,
      exitCode: -1,
      stdout: '',
      stderr: e.toString(),
    );
    notifier.completeCommand(errorResult);
    return errorResult;
  }
});
