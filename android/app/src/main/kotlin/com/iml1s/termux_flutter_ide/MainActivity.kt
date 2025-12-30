package com.iml1s.termux_flutter_ide

import android.content.Intent
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "termux_flutter_ide/termux"
    
    companion object {
        const val TERMUX_PACKAGE = "com.termux"
        const val TERMUX_RUN_COMMAND_SERVICE = "com.termux.app.RunCommandService"
        const val TERMUX_RUN_COMMAND_ACTION = "com.termux.RUN_COMMAND"
        
        // Termux intent extras
        const val EXTRA_COMMAND_PATH = "com.termux.RUN_COMMAND_PATH"
        const val EXTRA_ARGUMENTS = "com.termux.RUN_COMMAND_ARGUMENTS"
        const val EXTRA_WORKDIR = "com.termux.RUN_COMMAND_WORKDIR"
        const val EXTRA_BACKGROUND = "com.termux.RUN_COMMAND_BACKGROUND"
        const val EXTRA_SESSION_ACTION = "com.termux.RUN_COMMAND_SESSION_ACTION"
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTermuxInstalled" -> {
                    result.success(isTermuxInstalled())
                }
                "executeCommand" -> {
                    val command = call.argument<String>("command")
                    val workingDirectory = call.argument<String>("workingDirectory")
                    val background = call.argument<Boolean>("background") ?: false
                    
                    if (command != null) {
                        executeTermuxCommand(command, workingDirectory, background, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Command is required", null)
                    }
                }
                "openTermux" -> {
                    result.success(openTermux())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun isTermuxInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo(TERMUX_PACKAGE, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }
    
    private fun executeTermuxCommand(
        command: String,
        workingDirectory: String?,
        background: Boolean,
        result: MethodChannel.Result
    ) {
        try {
            // 使用 Termux RunCommandService 執行指令
            val intent = Intent().apply {
                setClassName(TERMUX_PACKAGE, TERMUX_RUN_COMMAND_SERVICE)
                action = TERMUX_RUN_COMMAND_ACTION
                
                // 將指令拆分為可執行檔和參數
                val parts = command.split(" ", limit = 2)
                val executable = parts[0]
                val args = if (parts.size > 1) parts[1].split(" ").toTypedArray() else emptyArray()
                
                // 設定執行路徑（使用 Termux 的 bin 目錄）
                putExtra(EXTRA_COMMAND_PATH, "/data/data/com.termux/files/usr/bin/$executable")
                putExtra(EXTRA_ARGUMENTS, args)
                
                // 設定工作目錄
                workingDirectory?.let {
                    putExtra(EXTRA_WORKDIR, it)
                }
                
                // 設定是否背景執行
                putExtra(EXTRA_BACKGROUND, background)
                
                // 設定 session 行為：0 = 不做任何事, 1 = 聚焦, 2 = 新分頁
                putExtra(EXTRA_SESSION_ACTION, if (background) "0" else "1")
            }
            
            // 啟動服務
            startService(intent)
            
            // 注意：這種方式無法直接取得輸出
            // 需要更進階的實作（使用 Termux:API 或 Socket）才能取得結果
            result.success(mapOf(
                "success" to true,
                "exitCode" to 0,
                "stdout" to "Command sent to Termux: $command",
                "stderr" to ""
            ))
            
        } catch (e: Exception) {
            result.success(mapOf(
                "success" to false,
                "exitCode" to -1,
                "stdout" to "",
                "stderr" to e.message
            ))
        }
    }
    
    private fun openTermux(): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(TERMUX_PACKAGE)
            if (intent != null) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
