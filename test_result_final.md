00:00 +0: loading D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart
Running Gradle task 'assembleDebug'...                          
integration_test/editor_lsp_test.dart:109:21: Error: Method not found: 'EditorPage'.
          home: app.EditorPage(),
                    ^^^^^^^^^^
integration_test/editor_lsp_test.dart:106:44: Error: The argument type 'MockProjectPathNotifier Function(dynamic)' can't be assigned to the parameter type 'ProjectPathNotifier Function()'.
 - 'MockProjectPathNotifier' is from 'integration_test/editor_lsp_test.dart'.
 - 'ProjectPathNotifier' is from 'package:termux_flutter_ide/core/providers.dart' ('lib/core/providers.dart').
          projectPathProvider.overrideWith((ref) => MockProjectPathNotifier()),
                                           ^
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildDebug'.
> Process 'command 'C:\Users\aa223\fvm\default\bin\flutter.bat'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.

BUILD FAILED in 22s
Running Gradle task 'assembleDebug'...                             22.7s
00:00 +0 -1: loading D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart [E]
  Failed to load "D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart": Gradle task assembleDebug failed with exit code 1
  package:flutter_tools/src/base/common.dart 10:3                    throwToolExit
  package:flutter_tools/src/android/gradle.dart 514:9                AndroidGradleBuilder.buildGradleApp
  ===== asynchronous gap ===========================
  package:flutter_tools/src/android/gradle.dart 233:5                AndroidGradleBuilder.buildApk
  ===== asynchronous gap ===========================
  package:flutter_tools/src/android/android_device.dart 584:7        AndroidDevice.startApp
  ===== asynchronous gap ===========================
  package:flutter_tools/src/test/integration_test_device.dart 55:39  IntegrationTestTestDevice.start
  ===== asynchronous gap ===========================
  package:flutter_tools/src/test/flutter_platform.dart 546:49        FlutterPlatform._startTest.<fn>
  ===== asynchronous gap ===========================
  package:flutter_tools/src/base/async_guard.dart 111:24             asyncGuard.<fn>
  
00:00 +0 -1: Some tests failed.
