import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/termux_bridge.dart';
import '../termux/termux_providers.dart';

/// Termux 互動測試頁面
///
/// 這個頁面可以單獨測試每一個 Termux Bridge 的功能，
/// 確認所有交互都正常運作。
///
/// 使用方式：在 App 中導航到這個頁面即可開始測試。
class TermuxDebugPage extends ConsumerStatefulWidget {
  const TermuxDebugPage({super.key});

  @override
  ConsumerState<TermuxDebugPage> createState() => _TermuxDebugPageState();
}

class _TermuxDebugPageState extends ConsumerState<TermuxDebugPage> {
  final List<_TestResult> _results = [];
  bool _isRunning = false;
  String _customCommand = '';
  String _customOutput = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        title: const Text('🔧 Termux Debug'),
        backgroundColor: const Color(0xFF181825),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _isRunning ? null : _runAllTests,
            tooltip: '執行所有測試',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => setState(() => _results.clear()),
            tooltip: '清除結果',
          ),
        ],
      ),
      body: Column(
        children: [
          // 自訂指令輸入區
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF181825),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(
                        color: Colors.white, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: '輸入自訂指令...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => _customCommand = v,
                    onSubmitted: (_) => _runCustomCommand(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _runCustomCommand,
                  child: const Text('執行'),
                ),
              ],
            ),
          ),
          // 自訂指令輸出
          if (_customOutput.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF11111B),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📤 輸出:', style: TextStyle(color: Colors.amber)),
                  const SizedBox(height: 4),
                  SelectableText(
                    _customOutput,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: Colors.grey),
          // 測試結果列表
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      '點擊右上角 ▶ 執行所有測試\n或輸入自訂指令測試',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) =>
                        _buildResultTile(_results[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(_TestResult result) {
    final icon = result.status == _TestStatus.pass
        ? const Icon(Icons.check_circle, color: Colors.green)
        : result.status == _TestStatus.fail
            ? const Icon(Icons.error, color: Colors.red)
            : result.status == _TestStatus.warning
                ? const Icon(Icons.warning, color: Colors.orange)
                : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2));

    return ExpansionTile(
      leading: icon,
      title: Text(result.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(result.summary,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
      children: [
        if (result.details.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF11111B),
            child: SelectableText(
              result.details,
              style: const TextStyle(
                  color: Colors.white70, fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _runCustomCommand() async {
    if (_customCommand.isEmpty) return;

    final bridge = ref.read(termuxBridgeProvider);
    setState(() => _customOutput = '執行中...');

    final result =
        await bridge.executeCommand(_customCommand, background: true);

    setState(() {
      _customOutput = '''exitCode: ${result.exitCode}
success: ${result.success}
stdout:
${result.stdout}
stderr:
${result.stderr}''';
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    final bridge = ref.read(termuxBridgeProvider);

    // Test 1: isTermuxInstalled
    await _runTest('1. Termux 安裝檢查', () async {
      final installed = await bridge.isTermuxInstalled();
      return _TestResult(
        name: '1. Termux 安裝檢查',
        status: installed ? _TestStatus.pass : _TestStatus.fail,
        summary: installed ? '✅ 已安裝' : '❌ 未安裝',
        details: 'isTermuxInstalled() = $installed',
      );
    });

    // Test 2: checkExternalAppsAllowed
    await _runTest('2. allow-external-apps', () async {
      final status = await bridge.checkExternalAppsAllowed();
      return _TestResult(
        name: '2. allow-external-apps',
        status: status == ExternalAppsStatus.allowed
            ? _TestStatus.pass
            : _TestStatus.fail,
        summary:
            status == ExternalAppsStatus.allowed ? '✅ 已啟用' : '❌ 未啟用 ($status)',
        details: 'checkExternalAppsAllowed() = $status',
      );
    });

    // Test 3: canDrawOverlays
    await _runTest('3. 懸浮視窗權限', () async {
      final canOverlay = await bridge.canDrawOverlays();
      return _TestResult(
        name: '3. 懸浮視窗權限',
        status: canOverlay ? _TestStatus.pass : _TestStatus.warning,
        summary: canOverlay ? '✅ 已授權' : '⚠️ 未授權',
        details: 'canDrawOverlays() = $canOverlay',
      );
    });

    // Test 4: checkTermuxPrefix
    await _runTest('4. Termux 環境變數', () async {
      final prefixOk = await bridge.checkTermuxPrefix();
      return _TestResult(
        name: '4. Termux 環境變數',
        status: prefixOk ? _TestStatus.pass : _TestStatus.fail,
        summary: prefixOk ? '✅ 正常' : '❌ 異常',
        details: 'checkTermuxPrefix() = $prefixOk',
      );
    });

    // Test 5: checkSSHServiceStatus
    await _runTest('5. SSH 服務狀態', () async {
      final sshOk = await bridge.checkSSHServiceStatus();
      return _TestResult(
        name: '5. SSH 服務狀態',
        status: sshOk ? _TestStatus.pass : _TestStatus.warning,
        summary: sshOk ? '✅ 運作中' : '⚠️ 未啟動',
        details: 'checkSSHServiceStatus() = $sshOk',
      );
    });

    // Test 6: executeCommand (echo)
    await _runTest('6. 基本指令 (echo)', () async {
      final result =
          await bridge.executeCommand('echo "Hello Termux"', background: true);
      return _TestResult(
        name: '6. 基本指令 (echo)',
        status: result.success && result.stdout.contains('Hello Termux')
            ? _TestStatus.pass
            : _TestStatus.fail,
        summary: result.success ? '✅ 成功' : '❌ 失敗 (exit ${result.exitCode})',
        details: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
      );
    });

    // Test 7: executeCommand (ls)
    await _runTest('7. 檔案系統 (ls)', () async {
      final result = await bridge.executeCommand(
          'ls -la /data/data/com.termux/files/home',
          background: true);
      return _TestResult(
        name: '7. 檔案系統 (ls)',
        status: result.success ? _TestStatus.pass : _TestStatus.fail,
        summary: result.success ? '✅ 成功' : '❌ 失敗',
        details: result.stdout,
      );
    });

    // Test 8: executeCommand (which)
    await _runTest('8. PATH 檢查', () async {
      final result =
          await bridge.executeCommand('echo \$PATH', background: true);
      final hasPath = result.stdout.contains('/data/data/com.termux');
      return _TestResult(
        name: '8. PATH 檢查',
        status: hasPath ? _TestStatus.pass : _TestStatus.warning,
        summary: hasPath ? '✅ 正確' : '⚠️ 可能異常',
        details: 'PATH = ${result.stdout}',
      );
    });

    // Test 9: isFlutterInstalled
    await _runTest('9. Flutter 安裝', () async {
      final flutterOk = await bridge.isFlutterInstalled();
      return _TestResult(
        name: '9. Flutter 安裝',
        status: flutterOk ? _TestStatus.pass : _TestStatus.warning,
        summary: flutterOk ? '✅ 已安裝' : '⚠️ 未安裝',
        details: 'isFlutterInstalled() = $flutterOk',
      );
    });

    setState(() => _isRunning = false);
  }

  Future<void> _runTest(
      String name, Future<_TestResult> Function() test) async {
    // Add loading state
    setState(() {
      _results.add(_TestResult(
        name: name,
        status: _TestStatus.running,
        summary: '執行中...',
        details: '',
      ));
    });

    try {
      final result = await test();
      setState(() {
        _results[_results.length - 1] = result;
      });
    } catch (e) {
      setState(() {
        _results[_results.length - 1] = _TestResult(
          name: name,
          status: _TestStatus.fail,
          summary: '❌ 例外錯誤',
          details: e.toString(),
        );
      });
    }
  }
}

enum _TestStatus { running, pass, fail, warning }

class _TestResult {
  final String name;
  final _TestStatus status;
  final String summary;
  final String details;

  const _TestResult({
    required this.name,
    required this.status,
    required this.summary,
    required this.details,
  });
}
