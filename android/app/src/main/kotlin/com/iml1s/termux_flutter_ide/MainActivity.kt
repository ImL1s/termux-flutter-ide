package com.iml1s.termux_flutter_ide

import android.content.Intent
import android.util.Log
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
                "getTermuxUid" -> {
                    result.success(getTermuxUid())
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

    private fun getTermuxUid(): Int? {
        return try {
            val uid = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                packageManager.getPackageUid(TERMUX_PACKAGE, 0)
            } else {
                packageManager.getApplicationInfo(TERMUX_PACKAGE, 0).uid
            }
            Log.d("MainActivity", "Termux UID = $uid")
            uid
        } catch (e: Exception) {
            Log.d("MainActivity", "Failed to get Termux UID: ${e.message}")
            null
        }
    }
    
    private fun executeTermuxCommand(
        command: String,
        workingDirectory: String?,
        background: Boolean,
        result: MethodChannel.Result
    ) {
        val permission = "com.termux.permission.RUN_COMMAND"
        if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(permission), 1001)
            // Save pending command to execute after permission granted?
            // For now, just return error asking user to retry
            result.error("PERMISSION_DENIED", "Permission not granted. Please retry allow the permission.", null)
            return
        }

        try {
            // 使用 Termux RunCommandService 執行指令
            val intent = Intent().apply {
                setClassName(TERMUX_PACKAGE, TERMUX_RUN_COMMAND_SERVICE)
                action = TERMUX_RUN_COMMAND_ACTION
                
                // 為了支援複雜指令（包含管道、重導向、引號等），我們透過 Termux 的 shell 執行
                val termuxSh = "/data/data/com.termux/files/usr/bin/sh"
                putExtra(EXTRA_COMMAND_PATH, termuxSh)
                putExtra(EXTRA_ARGUMENTS, arrayOf("-c", command))
                
                // 設定工作目錄
                workingDirectory?.let {
                    putExtra(EXTRA_WORKDIR, it)
                }
                
                // 設定是否背景執行
                putExtra(EXTRA_BACKGROUND, background)
                
                // 設定 session 行為：
                // "0" = RUN_AND_SWITCH_TO_NEW_SESSION (新分頁並顯示) - 這是前台執行
                // "1" = RUN_AND_KEEP_CURRENT_SESSION (背景執行) - 這是後台執行
                // 注意：這必須是 String 類型
                putExtra(EXTRA_SESSION_ACTION, if (background) "1" else "0")
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
