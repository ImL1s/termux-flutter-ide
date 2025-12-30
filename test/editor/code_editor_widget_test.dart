import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/code_editor_widget.dart';
import 'package:termux_flutter_ide/file_manager/file_operations.dart';
import 'package:termux_flutter_ide/core/providers.dart';

// Mock FileOperations
class MockFileOperations implements FileOperations {
  final Map<String, String> fs = {};

  @override
  Future<String?> readFile(String path) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return fs[path];
  }

  @override
  Future<bool> writeFile(String path, String content) async {
    await Future.delayed(const Duration(milliseconds: 10));
    fs[path] = content;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

// Mock CurrentFileNotifier
class MockCurrentFileNotifier extends CurrentFileNotifier {
  @override
  String? build() => '/test/main.dart';
}

void main() {
  late MockFileOperations mockOps;

  setUp(() {
    mockOps = MockFileOperations();
    mockOps.fs['/test/main.dart'] = 'void main() {}';
  });

  testWidgets('CodeEditorWidget loads file content from FileOperations',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileOperationsProvider.overrideWithValue(mockOps),
          currentFileProvider.overrideWith(MockCurrentFileNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CodeEditorWidget()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // CodeField renders text in multiple places (RichText + EditableText)
    expect(find.text('void main() {}'), findsAtLeastNWidgets(1));

    // Clean up any pending timers
    await tester.pumpAndSettle();
  });

  testWidgets('CodeEditorWidget shows error when file read fails',
      (tester) async {
    // Setup mock to return null (failed read)
    mockOps.fs.clear(); // No file exists

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileOperationsProvider.overrideWithValue(mockOps),
          currentFileProvider.overrideWith(MockCurrentFileNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CodeEditorWidget()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Should show error message
    expect(find.textContaining('Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Clean up any pending timers
    await tester.pumpAndSettle();
  });

  // Note:
  // - Testing loading indicator causes Timer pending issues due to flutter_code_editor internals
  // - Text input and save tests are unreliable because enterText() doesn't work with CodeController
  // - The core dirty state and save logic are well-covered by unit tests in editor_providers_test.dart
}
