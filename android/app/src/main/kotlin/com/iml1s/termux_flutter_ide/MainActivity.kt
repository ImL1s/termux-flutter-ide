package com.iml1s.termux_flutter_ide

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

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
        const val EXTRA_PENDING_INTENT = "com.termux.RUN_COMMAND_PENDING_INTENT"

        // Termux result extras
        const val RESULT_STDOUT = "stdout"
        const val RESULT_STDERR = "stderr"
        const val RESULT_EXIT_CODE = "exitCode"
        
        const val ACTION_RECEIVE_RESULT = "com.iml1s.termux_flutter_ide.ACTION_RECEIVE_RESULT"
    }
    
    private val pendingResults = mutableMapOf<String, MethodChannel.Result>()
    
    private val resultReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            Log.d("MainActivity", "onReceive: Bridge broadcast received!")
            
            // Log all extras for debugging
            intent.extras?.keySet()?.forEach { key ->
                Log.d("MainActivity", "Extra: $key = ${intent.extras?.get(key)}")
            }

            var bundle = intent.getBundleExtra("com.termux.execute.result")
            if (bundle == null) {
                // Some versions/actions might use just "result"
                bundle = intent.getBundleExtra("result")
            }

            if (bundle != null) {
                Log.d("MainActivity", "Result Bundle found")
                bundle.keySet().forEach { key ->
                    Log.d("MainActivity", "Bundle Extra: $key = ${bundle.get(key)}")
                }
            }

            val requestId = intent.getStringExtra("requestId")
            if (requestId == null) {
                Log.e("MainActivity", "onReceive: requestId is NULL!")
                return
            }
            
            val result = pendingResults.remove(requestId)
            if (result == null) {
                Log.e("MainActivity", "onReceive: No pending result found for $requestId")
                // Log all pending request IDs for debugging
                Log.d("MainActivity", "Pending IDs: ${pendingResults.keys}")
                return
            }
            
            val stdout = bundle?.getString(RESULT_STDOUT) ?: intent.getStringExtra(RESULT_STDOUT) ?: ""
            val stderr = bundle?.getString(RESULT_STDERR) ?: intent.getStringExtra(RESULT_STDERR) ?: ""
            val exitCode = bundle?.getInt(RESULT_EXIT_CODE) ?: intent.getIntExtra(RESULT_EXIT_CODE, -1)
            
            Log.d("MainActivity", "Received result for $requestId: exitCode=$exitCode")
            Log.d("MainActivity", "STDOUT: $stdout")
            Log.d("MainActivity", "STDERR: $stderr")
            
            result.success(mapOf(
                "success" to (exitCode == 0),
                "exitCode" to exitCode,
                "stdout" to stdout,
                "stderr" to stderr
            ))
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(resultReceiver)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register receiver for Termux results
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            registerReceiver(resultReceiver, IntentFilter(ACTION_RECEIVE_RESULT), Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(resultReceiver, IntentFilter(ACTION_RECEIVE_RESULT))
        }
        
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
                "openTermuxSettings" -> {
                    result.success(openTermuxSettings())
                }
                "openBatteryOptimizationSettings" -> {
                    result.success(openBatteryOptimizationSettings())
                }
                "canDrawOverlays" -> {
                    result.success(canDrawOverlays())
                }
                "getTermuxPackageInstaller" -> {
                    result.success(getTermuxPackageInstaller())
                }
                "checkPermission" -> {
                    val permission = call.argument<String>("permission")
                    if (permission != null) {
                        result.success(checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED)
                    } else {
                        result.error("INVALID_ARGUMENT", "Permission name is required", null)
                    }
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

    private fun getTermuxPackageInstaller(): String? {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                packageManager.getInstallSourceInfo(TERMUX_PACKAGE).installingPackageName
            } else {
                @Suppress("DEPRECATION")
                packageManager.getInstallerPackageName(TERMUX_PACKAGE)
            }
        } catch (e: Exception) {
            Log.d("MainActivity", "Failed to get Termux installer: ${e.message}")
            null
        }
    }
    
    private fun executeTermuxCommand(
        command: String,
        workingDirectory: String?,
        background: Boolean,
        result: MethodChannel.Result
    ) {
        Log.d("MainActivity", "Executing Termux command: $command (background=$background)")
        val permission = "com.termux.permission.RUN_COMMAND"
        if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(permission), 1001)
            // Save pending command to execute after permission granted?
            // For now, just return error asking user to retry
            result.error("PERMISSION_DENIED", "Permission not granted. Please retry allow the permission.", null)
            return
        }

        try {
            val requestId = UUID.randomUUID().toString()
            pendingResults[requestId] = result
            
            // Create PendingIntent for result
            val resultIntent = Intent(ACTION_RECEIVE_RESULT).apply {
                setPackage(packageName)
                putExtra("requestId", requestId)
            }
            
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                this, requestId.hashCode(), resultIntent, pendingIntentFlags
            )

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
                
                // 加入回傳 Result 的 PendingIntent
                putExtra(EXTRA_PENDING_INTENT, pendingIntent)
            }
            
            // 啟動服務 - Android 12+ 需要處理背景服務限制
            Log.d("MainActivity", "Starting RunCommandService for requestId: $requestId")
            try {
                // Android 12+ 在背景時需要使用 startForegroundService
                // 但 Termux RunCommandService 可能不支援 foreground service
                // 所以我們嘗試普通 startService，若失敗則捕獲例外
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    // Android 12+: 先嘗試普通方式，若失敗會拋出例外
                    startService(intent)
                } else {
                    startService(intent)
                }
                Log.d("MainActivity", "Intent sent to Termux")
            } catch (e: Exception) {
                Log.e("MainActivity", "Failed to start Termux service", e)
                pendingResults.remove(requestId)
                
                // 判斷是否為背景服務限制錯誤
                val isBackgroundRestriction = e.javaClass.simpleName.contains("BackgroundService")
                val errorMessage = if (isBackgroundRestriction) {
                    "無法在背景啟動 Termux 服務。請確保 App 在前台時執行指令。"
                } else {
                    e.message ?: "Unknown error starting Termux service"
                }
                
                result.success(mapOf(
                    "success" to false,
                    "exitCode" to -1,
                    "stdout" to "",
                    "stderr" to errorMessage
                ))
                return
            }
            
            // 加入超時機制：15秒後如果還沒收到結果，就自動回傳失敗並清理
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                val leftover = pendingResults.remove(requestId)
                if (leftover != null) {
                    Log.e("MainActivity", "Command timeout for $requestId")
                    leftover.success(mapOf(
                        "success" to false,
                        "exitCode" to -1,
                        "stdout" to "",
                        "stderr" to "Command timed out in Native layer"
                    ))
                }
            }, 15000)
            
            // Note: success is now returned via BroadCastReceiver or this timeout handler            
        } catch (e: Exception) {
            Log.e("MainActivity", "Error executing Termux command", e)
            result.success(mapOf(
                "success" to false,
                "exitCode" to -1,
                "stdout" to "",
                "stderr" to (e.message ?: "Unknown error")
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

    private fun openTermuxSettings(): Boolean {
        return try {
            // ACTION_MANAGE_OVERLAY_PERMISSION
            val intent = Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                data = android.net.Uri.parse("package:$TERMUX_PACKAGE")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to open overlay settings", e)
            try {
                // Fallback to generic settings if overlay specific fails
                 val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = android.net.Uri.parse("package:$TERMUX_PACKAGE")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                true
            } catch (ex: Exception) {
                false
            }
        }
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val intent = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to open battery optimization settings", e)
            false
        }
    }

    private fun canDrawOverlays(): Boolean {
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            android.provider.Settings.canDrawOverlays(this)
        } else {
            true // Pre-M doesn't need this permission
        }
    }
}
