00:00 +0: loading D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart
Running Gradle task 'assembleDebug'...                             30.2s
??Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk...          17.4s
00:00 +0: LSP UI Integration Test: Auto-completion appears (Mocked)
Starting Termux Environment Fix...
Termux Environment Fix Completed.
CodeEditorWidget found. File should be loaded via MockCurrentFileNotifier.
MockLspService: getCompletions called for /mock_project/main.dart at 0:4
MockLspService: getCompletions called for /mock_project/main.dart at 0:4
????EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ??????????????????????????????????????????????????????The following TestFailure was thrown running a test:
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "MockLspItem": []>
   Which: means none were found but one was expected

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart:145:7)
<asynchronous suspension>
#5      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:189:15)
<asynchronous suspension>
#6      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1027:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

This was caught by the test expectation on the following line:
  file:///D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart line 145
The test description was:
  LSP UI Integration Test: Auto-completion appears (Mocked)
????????????????????????????????????????????????????????????????????????????????????????????????????
00:04 +0 -1: LSP UI Integration Test: Auto-completion appears (Mocked) [E]
  Test failed. See exception logs above.
  The test description was: LSP UI Integration Test: Auto-completion appears (Mocked)
  
00:04 +0 -1: (tearDownAll)
00:04 +0 -1: Some tests failed.
