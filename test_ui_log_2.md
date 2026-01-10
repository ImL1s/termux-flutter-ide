00:00 +0: loading D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart
Running Gradle task 'assembleDebug'...                             17.0s
??Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk...          16.9s
00:00 +0: LSP UI Integration Test: Auto-completion appears
Starting Termux Environment Fix...
Warning: main.dart not found in tree
????EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ??????????????????????????????????????????????????????The following assertion was thrown running a test:
The finder "Found 0 widgets with type "CodeField": []" (used in a call to "tap()") could not find
any matching widgets.

When the exception was thrown, this was the stack:
#0      WidgetController._getElementPoint (package:flutter_test/src/controller.dart:1895:7)
#1      WidgetController.getCenter (package:flutter_test/src/controller.dart:1795:12)
#2      WidgetController.tap (package:flutter_test/src/controller.dart:1043:18)
#3      main.<anonymous closure> (file:///D:/SideProject/termux-flutter-ide/integration_test/editor_lsp_test.dart:40:18)
<asynchronous suspension>
#4      testWidgets.<anonymous closure>.<anonymous closure> (package:flutter_test/src/widget_tester.dart:189:15)
<asynchronous suspension>
#5      TestWidgetsFlutterBinding._runTestBody (package:flutter_test/src/binding.dart:1027:5)
<asynchronous suspension>
<asynchronous suspension>
(elided one frame from package:stack_trace)

The test description was:
  LSP UI Integration Test: Auto-completion appears
????????????????????????????????????????????????????????????????????????????????????????????????????
00:05 +0 -1: LSP UI Integration Test: Auto-completion appears [E]
  Test failed. See exception logs above.
  The test description was: LSP UI Integration Test: Auto-completion appears
  
00:05 +0 -1: (tearDownAll)
00:05 +0 -1: LSP UI Integration Test: Auto-completion appears
Termux Environment Fix Completed.
00:06 +0 -1: Some tests failed.
