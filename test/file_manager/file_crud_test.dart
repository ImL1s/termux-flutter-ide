import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/file_manager/file_tree_widget.dart';
import 'package:termux_flutter_ide/file_manager/file_operations.dart';
import 'package:termux_flutter_ide/core/providers.dart';

class MockFileOperations implements FileOperations {
  Map<String, List<FileItem>> listings;
  List<String> createdFiles = [];
  List<(String, String)> renamedItems = [];
  List<String> deletedFiles = [];
  List<String> deletedDirs = [];

  MockFileOperations(this.listings);

  @override
  Future<bool> createFile(String path) async {
    createdFiles.add(path);
    return true;
  }

  @override
  Future<bool> createDirectory(String path) async {
    return true;
  }

  @override
  Future<bool> deleteFile(String path) async {
    deletedFiles.add(path);
    return true;
  }

  @override
  Future<bool> deleteDirectory(String path) async {
    deletedDirs.add(path);
    return true;
  }

  @override
  Future<List<FileItem>> listDirectory(String path) async {
    return listings[path] ?? [];
  }

  @override
  Future<bool> rename(String oldPath, String newPath) async {
    renamedItems.add((oldPath, newPath));
    return true;
  }

  @override
  Future<bool> exists(String path) async => true;
  @override
  Future<bool> isDirectory(String path) async => false;
  @override
  Future<String?> readFile(String path) async => null;
  @override
  Future<bool> writeFile(String path, String content) async => true;
  @override
  Future<bool> createFlutterProject(String parentDir, String name, {String? org}) async => true;
  @override
  Future<({bool success, String? error})> createFlutterProjectWithError(String parentDir, String name, {String? org}) async => (success: true, error: null);
}

class MockProjectPathNotifier extends ProjectPathNotifier {
  final String? _path;
  MockProjectPathNotifier(this._path);
  @override
  String? build() => _path;
}

void main() {
  const projectPath = '/home/project';
  late MockFileOperations mockOps;

  setUp(() {
    mockOps = MockFileOperations({
      projectPath: [
        FileItem(name: 'main.dart', path: '$projectPath/main.dart', isDirectory: false),
        FileItem(name: 'lib', path: '$projectPath/lib', isDirectory: true),
      ],
    });
  });

  testWidgets('Create File calls backend and refreshes', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        projectPathProvider.overrideWith(() => MockProjectPathNotifier(projectPath)),
        fileOperationsProvider.overrideWithValue(mockOps),
      ],
      child: const MaterialApp(home: Scaffold(body: FileTreeWidget())),
    ));
    await tester.pumpAndSettle();

    // Find "New File" button on root node
    final newFileBtn = find.byTooltip('New File');
    expect(newFileBtn, findsOneWidget);
    await tester.tap(newFileBtn);
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('New File'), findsWidgets); // Title and button
    
    // Type name
    await tester.enterText(find.byType(TextField), 'new_file.dart');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Verify mock call
    expect(mockOps.createdFiles, contains('$projectPath/new_file.dart'));
  });

  testWidgets('Rename File syncs with openFilesProvider', (tester) async {
    final container = ProviderContainer(overrides: [
      fileOperationsProvider.overrideWithValue(mockOps),
      projectPathProvider.overrideWith(() => MockProjectPathNotifier(projectPath)),
    ]);
    
    // Predicate current active file and open files
    final openFiles = container.read(openFilesProvider.notifier);
    openFiles.add('$projectPath/main.dart');
    
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: FileTreeWidget())),
    ));
    await tester.pumpAndSettle();

    // Verify main.dart is visible
    expect(find.text('main.dart'), findsOneWidget);

    // Open context menu for main.dart
    await tester.longPress(find.text('main.dart'));
    await tester.pumpAndSettle();

    // Tap Rename
    final renameBtn = find.text('Rename');
    expect(renameBtn, findsOneWidget);
    await tester.tap(renameBtn);
    await tester.pumpAndSettle();

    // Enter new name
    await tester.enterText(find.byType(TextField), 'renamed.dart');
    await tester.tap(find.widgetWithText(TextButton, 'Rename'));
    await tester.pumpAndSettle();

    // Verify mock call
    expect(mockOps.renamedItems.any((e) => e.$1 == '$projectPath/main.dart' && e.$2 == '$projectPath/renamed.dart'), isTrue);

    // Verify provider sync
    expect(container.read(openFilesProvider), contains('$projectPath/renamed.dart'));
    expect(container.read(openFilesProvider), isNot(contains('$projectPath/main.dart')));
  });

  testWidgets('Delete File syncs with openFilesProvider', (tester) async {
    final container = ProviderContainer(overrides: [
      fileOperationsProvider.overrideWithValue(mockOps),
      projectPathProvider.overrideWith(() => MockProjectPathNotifier(projectPath)),
    ]);
    
    final openFiles = container.read(openFilesProvider.notifier);
    openFiles.add('$projectPath/main.dart');
    
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: FileTreeWidget())),
    ));
    await tester.pumpAndSettle();

    // Verify main.dart is visible
    expect(find.text('main.dart'), findsOneWidget);

    // Long press main.dart
    await tester.longPress(find.text('main.dart'));
    await tester.pumpAndSettle();

    // Tap Delete
    final deleteBtn = find.text('Delete');
    expect(deleteBtn, findsWidgets); // Might find title and button
    await tester.tap(deleteBtn.first);
    await tester.pumpAndSettle();

    // Confirm Delete
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify mock call
    expect(mockOps.deletedFiles, contains('$projectPath/main.dart'));

    // Verify provider sync
    expect(container.read(openFilesProvider), isNot(contains('$projectPath/main.dart')));
  });
}
