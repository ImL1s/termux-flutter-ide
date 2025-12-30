import 'package:flutter/services.dart';

/// Termux Bridge - 與 Termux 應用程式通訊的服務
/// 
/// 使用 Android Intent 透過 Termux:API 或 RunCommandService 執行指令
class TermuxBridge {
  static const MethodChannel _channel = MethodChannel('termux_flutter_ide/termux');
  
  static final TermuxBridge _instance = TermuxBridge._internal();
  
  factory TermuxBridge() => _instance;
  
  TermuxBridge._internal();
  
  /// 檢查 Termux 是否已安裝
  Future<bool> isTermuxInstalled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTermuxInstalled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 執行 Termux 指令
  /// 
  /// [command] - 要執行的指令
  /// [workingDirectory] - 工作目錄（可選）
  /// [background] - 是否在背景執行
  Future<TermuxResult> executeCommand(
    String command, {
    String? workingDirectory,
    bool background = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'executeCommand',
        {
          'command': command,
          'workingDirectory': workingDirectory,
          'background': background,
        },
      );
      
      return TermuxResult.fromMap(result ?? {});
    } on PlatformException catch (e) {
      return TermuxResult(
        success: false,
        exitCode: -1,
        stdout: '',
        stderr: e.message ?? 'Unknown error',
      );
    }
  }
  
  /// 執行 Flutter 指令
  Future<TermuxResult> runFlutterCommand(String subCommand) {
    return executeCommand('flutter $subCommand');
  }
  
  /// 執行 flutter run
  Future<TermuxResult> flutterRun({String? target}) {
    final cmd = target != null ? 'flutter run -t $target' : 'flutter run';
    return executeCommand(cmd, background: true);
  }
  
  /// 執行 flutter build apk
  Future<TermuxResult> flutterBuildApk({bool release = true}) {
    final mode = release ? '--release' : '--debug';
    return executeCommand('flutter build apk $mode');
  }
  
  /// 執行 flutter doctor
  Future<TermuxResult> flutterDoctor() {
    return executeCommand('flutter doctor');
  }
  
  /// 開啟 Termux 終端機
  Future<bool> openTermux() async {
    try {
      final result = await _channel.invokeMethod<bool>('openTermux');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 發送指令到 Termux 並取得串流輸出
  Stream<String> executeCommandStream(String command) async* {
    // TODO: 實作串流輸出
    // 需要使用 EventChannel 接收持續的輸出
    final result = await executeCommand(command);
    yield result.stdout;
    if (result.stderr.isNotEmpty) {
      yield 'ERROR: ${result.stderr}';
    }
  }
}

/// Termux 指令執行結果
class TermuxResult {
  final bool success;
  final int exitCode;
  final String stdout;
  final String stderr;
  
  const TermuxResult({
    required this.success,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
  
  factory TermuxResult.fromMap(Map<dynamic, dynamic> map) {
    return TermuxResult(
      success: map['success'] as bool? ?? false,
      exitCode: map['exitCode'] as int? ?? -1,
      stdout: map['stdout'] as String? ?? '',
      stderr: map['stderr'] as String? ?? '',
    );
  }
  
  @override
  String toString() {
    return 'TermuxResult(success: $success, exitCode: $exitCode, stdout: $stdout, stderr: $stderr)';
  }
}
