import 'package:flutter/material.dart';
import '../termux/termux_bridge.dart';
import '../termux/ssh_service.dart';

/// 獨立的 Termux 測試運行器 - 可在真實設備上運行測試所有核心服務
class TermuxTestRunner extends StatefulWidget {
  const TermuxTestRunner({super.key});

  @override
  State<TermuxTestRunner> createState() => _TermuxTestRunnerState();
}

class _TermuxTestRunnerState extends State<TermuxTestRunner> {
  final _bridge = TermuxBridge();
  late final SSHService _ssh;
  final _logs = <String>[];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _ssh = SSHService(_bridge);
  }

  @override
  void dispose() {
    _ssh.disconnect();
    super.dispose();
  }

  void _log(String message) {
    setState(() => _logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message'));
    debugPrint(message);
  }

  Future<void> _runAllTests() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      await _testTermuxBridge();
      await _testAutoSetup();
      await _testSSH();
      await _testCommands();

      _log('\n🎉 所有測試完成！');
    } catch (e, stack) {
      _log('❌ 測試失敗: $e');
      _log('Stack: $stack');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  Future<void> _testTermuxBridge() async {
    _log('\n【測試 1】TermuxBridge 基本功能');

    // 1.1 檢查安裝
    _log('📱 檢查 Termux 安裝...');
    final isInstalled = await _bridge.isTermuxInstalled();
    _log(isInstalled ? '✅ Termux 已安裝' : '❌ Termux 未安裝');

    // 1.2 獲取 UID
    _log('🔢 獲取 UID...');
    final uid = await _bridge.getTermuxUid();
    _log('✅ UID: $uid');

    // 1.3 檢查權限
    _log('🔍 檢查 external apps 權限...');
    final status = await _bridge.checkExternalAppsAllowed();
    _log('  狀態: $status');

    if (status != ExternalAppsStatus.allowed) {
      _log('⚠️ 需要啟用 allow-external-apps');
      _log('📱 打開 Termux...');
      await _bridge.openTermux();
      _log('💡 請在 Termux 設置中啟用 "Allow external apps"');
      _log('⏳ 等待 10 秒...');
      await Future.delayed(const Duration(seconds: 10));
    }

    // 1.4 測試簡單命令
    _log('👤 執行 whoami...');
    final whoami = await _bridge.executeCommand('whoami');
    if (whoami.success) {
      _log('✅ whoami: ${whoami.stdout.trim()}');
    } else {
      _log('❌ whoami 失敗: exitCode=${whoami.exitCode}');
    }
  }

  Future<void> _testAutoSetup() async {
    _log('\n【測試 2】自動設置 SSH');

    _log('📱 打開 Termux...');
    await _bridge.openTermux();
    await Future.delayed(const Duration(seconds: 2));

    _log('⚙️ 執行 setupTermuxSSH...');
    final result = await _bridge.setupTermuxSSH();

    if (result.success) {
      _log('✅ SSH 設置成功');
    } else {
      _log('⚠️ 自動設置失敗，嘗試手動命令...');

      _log('📦 安裝 openssh...');
      final install = await _bridge.executeCommand('pkg install openssh -y');
      _log(install.success ? '  ✓ 安裝成功' : '  ✗ 安裝失敗');

      _log('🔐 啟動 sshd...');
      final sshd = await _bridge.executeCommand('sshd');
      _log(sshd.success ? '  ✓ 啟動成功' : '  ✗ 啟動失敗');
    }

    _log('⏳ 等待 5 秒讓 sshd 準備好...');
    await Future.delayed(const Duration(seconds: 5));
  }

  Future<void> _testSSH() async {
    _log('\n【測試 3】SSH 連接');

    _log('🔐 嘗試連接...');
    try {
      await _ssh.connect();

      if (_ssh.isConnected) {
        _log('✅ SSH 連接成功！');

        final result = await _ssh.executeWithDetails('whoami');
        _log('  用戶: ${result.stdout.trim()}');
      } else {
        _log('❌ SSH 連接失敗');
      }
    } catch (e) {
      _log('❌ SSH 錯誤: $e');

      // 診斷
      _log('🔍 診斷...');
      final check = await _bridge.executeCommand(
        'pgrep sshd && echo "running" || echo "not running"'
      );
      _log('  sshd: ${check.stdout.trim()}');

      // 重試
      _log('🔄 重啟 sshd 並重試...');
      await _bridge.executeCommand('pkill sshd');
      await Future.delayed(const Duration(seconds: 1));
      await _bridge.executeCommand('sshd');
      await Future.delayed(const Duration(seconds: 3));

      await _ssh.connect();
      _log(_ssh.isConnected ? '✅ 重試成功' : '❌ 重試失敗');
    }
  }

  Future<void> _testCommands() async {
    _log('\n【測試 4】命令執行');

    // TermuxBridge 測試
    _log('1️⃣ TermuxBridge:');
    final echo = await _bridge.executeCommand('echo "Hello Bridge"');
    _log(echo.success ? '  ✅ ${echo.stdout.trim()}' : '  ❌ 失敗');

    final pwd = await _bridge.executeCommand('pwd');
    _log(pwd.success ? '  ✅ pwd: ${pwd.stdout.trim()}' : '  ❌ pwd 失敗');

    // SSH 測試
    if (_ssh.isConnected) {
      _log('2️⃣ SSH:');
      final sshEcho = await _ssh.executeWithDetails('echo "Hello SSH"');
      _log(sshEcho.exitCode == 0 ? '  ✅ ${sshEcho.stdout.trim()}' : '  ❌ 失敗');

      final home = await _ssh.executeWithDetails('echo \$HOME');
      _log('  ✅ HOME: ${home.stdout.trim()}');
    }

    // 文件操作測試
    _log('3️⃣ 文件操作:');
    final file = '~/test_${DateTime.now().millisecondsSinceEpoch}.txt';
    final content = 'Test ${DateTime.now()}';

    final write = await _bridge.executeCommand('echo "$content" > $file');
    final read = await _bridge.executeCommand('cat $file');
    final clean = await _bridge.executeCommand('rm -f $file');

    _log(write.success && read.stdout.trim() == content && clean.success
        ? '  ✅ 寫入/讀取/刪除成功'
        : '  ❌ 文件操作失敗');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termux 核心服務測試'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runAllTests,
              icon: Icon(_isRunning ? Icons.hourglass_empty : Icons.play_arrow),
              label: Text(_isRunning ? '測試運行中...' : '運行所有測試'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepPurple, width: 2),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  Color color = Colors.white;
                  if (log.contains('✅')) color = Colors.green;
                  if (log.contains('❌')) color = Colors.red;
                  if (log.contains('⚠️')) color = Colors.orange;
                  if (log.contains('🎉')) color = Colors.yellow;

                  return Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                      color: color,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
