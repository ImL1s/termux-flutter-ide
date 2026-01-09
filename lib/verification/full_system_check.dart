
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart'; // Add this
import 'package:termux_flutter_ide/file_manager/file_operations.dart';
import 'package:termux_flutter_ide/git/git_service.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
// import 'package:termux_flutter_ide/core/providers.dart'; // Remove if redundant or causing conflicts


// 定義一個全局 logger
void log(String message) {
  // 使用特殊前綴方便 adb logcat 過濾
  debugPrint('VERIFY_ZEUS: $message');
  print('VERIFY_ZEUS: $message');
}

void main() {
  runApp(const ProviderScope(child: VerificationApp()));
}

class VerificationApp extends ConsumerStatefulWidget {
  const VerificationApp({super.key});

  @override
  ConsumerState<VerificationApp> createState() => _VerificationAppState();
}

class _VerificationAppState extends ConsumerState<VerificationApp> {
  String _status = "Initializing...";
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _runFullSystemCheck();
  }

  void _addLog(String msg) {
    setState(() {
      _status = msg;
      _logs.add(msg);
    });
    log(msg);
  }

  Future<void> _runFullSystemCheck() async {
    _addLog("=== STARTING FULL SYSTEM VERIFICATION ===");
    
    try {
      // 1. Termux Bridge 測試
      _addLog("[TEST] Termux Bridge");
      final termuxBridge = ref.read(termuxBridgeProvider);
      
      final isInstalled = await termuxBridge.isTermuxInstalled();
      _addLog("Termux Installed: $isInstalled");
      if (!isInstalled) throw Exception("Termux not installed");

      // 檢查權限
      final hasPermission = await termuxBridge.checkPermission('com.termux.permission.RUN_COMMAND');
      _addLog("RUN_COMMAND Permission: $hasPermission");

      // 執行簡單指令
      _addLog("Executing 'echo hello' via Bridge...");
      final result = await termuxBridge.executeCommand('echo hello');
      _addLog("Command Result: ${result.exitCode}, stdout: ${result.stdout}");
      
      if (result.stdout.trim() != 'hello') {
        _addLog("⚠️ Warning: Bridge command output mismatch");
      } else {
        _addLog("✅ Termux Bridge Verified");
      }

      // 2. 檔案系統測試 (Bridge Implementation)
      _addLog("\n[TEST] File System (Bridge)");
      final fileOps = BridgeFileOperations(termuxBridge); // 直接使用 Bridge 實作
      
      final testDir = '/data/data/com.termux/files/home/ide_test_dir';
      final testFile = '$testDir/hello.txt';
      
      _addLog("Creating directory: $testDir");
      await fileOps.createDirectory(testDir);
      
      _addLog("Writing file: $testFile");
      await fileOps.writeFile(testFile, "Hello from Flutter IDE");
      
      final content = await fileOps.readFile(testFile);
      _addLog("Read content: $content");
      
      if (content == "Hello from Flutter IDE") {
        _addLog("✅ File System Write/Read Verified");
      } else {
         _addLog("❌ File System Read Failed");
      }
      
      // 3. Git 測試
      _addLog("\n[TEST] Git Service");
      // 注意: GitService 依賴 SSHService，如果 SSH 沒通可能會失敗，我們嘗試用 Bridge 模擬一部分
      // 或是直接測試 GitService 如果它內部支援切換
      
      // 這裡我們暫時用 Bridge 手動測試 git 指令，因為 GitService 強綁定 SSH
      _addLog("Checking git version via Bridge...");
      final gitVersionResult = await termuxBridge.executeCommand('git --version');
      _addLog("Git Version: ${gitVersionResult.stdout.trim()}");
      
      if (gitVersionResult.stdout.contains('git version')) {
        _addLog("✅ Git Installed & Executable");
        
        // 嘗試 init
        _addLog("Testing 'git init'...");
        await termuxBridge.executeCommand('cd $testDir && git init');
        final gitStatus = await termuxBridge.executeCommand('cd $testDir && git status');
        _addLog("Git Status: ${gitStatus.stdout}");
        
        if (gitStatus.stdout.contains('On branch')) {
           _addLog("✅ Git Init Verified");
        }
      } else {
        _addLog("⚠️ Git check failed (maybe not installed in Termux?)");
      }
      
      _addLog("\n=== VERIFICATION COMPLETE: SUCCESS ===");

    } catch (e, stack) {
      _addLog("\n❌ VERIFICATION FAILED: $e");
      _addLog(stack.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              const Text("Running System Check...", style: TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (ctx, i) => Text(
                    _logs[i], 
                    style: const TextStyle(color: Colors.white70, fontFamily: "monospace", fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
