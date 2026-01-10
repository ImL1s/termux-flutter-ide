00:00 +0: loading D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart
Running Gradle task 'assembleDebug'...                          
integration_test/editor_lsp_test.dart:81:7: Error: The non-abstract class 'MockFileOperations' is missing implementations for these members:
 - FileOperations.createDirectory
 - FileOperations.createFile
 - FileOperations.createFlutterProject
 - FileOperations.createFlutterProjectWithError
 - FileOperations.deleteDirectory
 - FileOperations.deleteFile
 - FileOperations.exists
 - FileOperations.isDirectory
 - FileOperations.rename
 - FileOperations.writeFile
Try to either
 - provide an implementation,
 - inherit an implementation from a superclass or mixin,
 - mark the class as abstract, or
 - provide a 'noSuchMethod' implementation.

class MockFileOperations extends FileOperations {
      ^^^^^^^^^^^^^^^^^^
lib/file_manager/file_operations.dart:26:16: Context: 'FileOperations.createDirectory' is defined here.
  Future<bool> createDirectory(String path);
               ^^^^^^^^^^^^^^^
lib/file_manager/file_operations.dart:25:16: Context: 'FileOperations.createFile' is defined here.
  Future<bool> createFile(String path);
               ^^^^^^^^^^
lib/file_manager/file_operations.dart:33:16: Context: 'FileOperations.createFlutterProject' is defined here.
  Future<bool> createFlutterProject(String parentDir, String name,
               ^^^^^^^^^^^^^^^^^^^^
lib/file_manager/file_operations.dart:35:43: Context: 'FileOperations.createFlutterProjectWithError' is defined here.
  Future<({bool success, String? error})> createFlutterProjectWithError(
                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
lib/file_manager/file_operations.dart:29:16: Context: 'FileOperations.deleteDirectory' is defined here.
  Future<bool> deleteDirectory(String path);
               ^^^^^^^^^^^^^^^
lib/file_manager/file_operations.dart:28:16: Context: 'FileOperations.deleteFile' is defined here.
  Future<bool> deleteFile(String path);
               ^^^^^^^^^^
lib/file_manager/file_operations.dart:23:16: Context: 'FileOperations.exists' is defined here.
  Future<bool> exists(String path);
               ^^^^^^
lib/file_manager/file_operations.dart:24:16: Context: 'FileOperations.isDirectory' is defined here.
  Future<bool> isDirectory(String path);
               ^^^^^^^^^^^
lib/file_manager/file_operations.dart:27:16: Context: 'FileOperations.rename' is defined here.
  Future<bool> rename(String oldPath, String newPath);
               ^^^^^^
lib/file_manager/file_operations.dart:32:16: Context: 'FileOperations.writeFile' is defined here.
  Future<bool> writeFile(String path, String content);
               ^^^^^^^^^
integration_test/editor_lsp_test.dart:22:16: Error: The return type of the method 'MockLspService.start' is 'Future<void>', which does not match the return type, 'Future<bool>', of the overridden method, 'LspService.start'.
 - 'Future' is from 'dart:async'.
Change to a subtype of 'Future<bool>'.
  Future<void> start(String projectPath) async {
               ^
lib/services/lsp_service.dart:27:16: Context: This is the overridden method ('start').
  Future<bool> start(String rootPath) async {
               ^
integration_test/editor_lsp_test.dart:32:8: Error: The return type of the method 'MockLspService.notifyDidOpen' is 'void', which does not match the return type, 'Future<void>', of the overridden method, 'LspService.notifyDidOpen'.
 - 'Future' is from 'dart:async'.
Change to a subtype of 'Future<void>'.
  void notifyDidOpen(String filePath, String content) {
       ^
lib/services/lsp_service.dart:129:16: Context: This is the overridden method ('notifyDidOpen').
  Future<void> notifyDidOpen(String filePath, String content) async {
               ^
integration_test/editor_lsp_test.dart:37:8: Error: The return type of the method 'MockLspService.notifyDidChange' is 'void', which does not match the return type, 'Future<void>', of the overridden method, 'LspService.notifyDidChange'.
 - 'Future' is from 'dart:async'.
Change to a subtype of 'Future<void>'.
  void notifyDidChange(String filePath, String content) {
       ^
lib/services/lsp_service.dart:141:16: Context: This is the overridden method ('notifyDidChange').
  Future<void> notifyDidChange(String filePath, String content) async {
               ^
integration_test/editor_lsp_test.dart:93:23: Error: Required named parameter 'name' must be provided.
      return [FileItem(path: '/mock_project/main.dart', isDirectory: false)];
                      ^
lib/file_manager/file_operations.dart:14:3: Context: Found this candidate, but the arguments don't match.
  FileItem({
  ^^^^^^^^
integration_test/editor_lsp_test.dart:17:7: Error: The superclass, 'LspService', has no unnamed constructor that takes no arguments.
class MockLspService extends LspService {
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

BUILD FAILED in 21s
Running Gradle task 'assembleDebug'...                             22.2s
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
