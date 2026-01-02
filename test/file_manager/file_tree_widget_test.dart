import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/file_manager/file_tree_widget.dart';
import 'package:termux_flutter_ide/file_manager/file_operations.dart';
import 'package:termux_flutter_ide/core/providers.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';

class MockProjectPathNotifier extends ProjectPathNotifier {
  final String? _initialPath;
  MockProjectPathNotifier(this._initialPath);
  @override
  String? build() => _initialPath;
}

class MockFileOperations extends Fake implements FileOperations {
  final Map<String, List<FileItem>> _listings;
  MockFileOperations(this._listings);

  @override
  Future<List<FileItem>> listDirectory(String path) async {
    return _listings[path] ?? [];
  }
}

class MockSSHService extends Fake implements SSHService {
  @override
  bool get isConnected => true;
}

void main() {
  testWidgets('FileTreeWidget shows no project view initially', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        overrides: [],
        child: MaterialApp(home: Scaffold(body: FileTreeWidget())),
      ),
    );

    expect(find.text('No folder opened'), findsOneWidget);
    expect(find.text('Open Folder'), findsOneWidget);
  });

  testWidgets('FileTreeWidget renders project root when path is set',
      (tester) async {
    final projectPath = '/data/data/com.termux/files/home/my_project';
    final mockListings = {
      projectPath: [
        FileItem(name: 'lib', path: '$projectPath/lib', isDirectory: true),
        FileItem(
            name: 'pubspec.yaml',
            path: '$projectPath/pubspec.yaml',
            isDirectory: false),
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sshServiceProvider.overrideWithValue(MockSSHService()),
          fileOperationsProvider
              .overrideWithValue(MockFileOperations(mockListings)),
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(projectPath)),
        ],
        child: const MaterialApp(home: Scaffold(body: FileTreeWidget())),
      ),
    );

    // Initial build
    await tester.pump();
    // After initState callback
    await tester.pumpAndSettle();

    // Verify root node name
    expect(find.text('my_project'), findsOneWidget);

    // Verify children
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('pubspec.yaml'), findsOneWidget);
  });

  testWidgets('FileTreeWidget handles expansion (logic check)', (tester) async {
    final projectPath = '/home/project';
    final mockListings = {
      projectPath: [
        FileItem(
            name: 'folder', path: '$projectPath/folder', isDirectory: true),
      ],
      '$projectPath/folder': [
        FileItem(
            name: 'subfile.dart',
            path: '$projectPath/folder/subfile.dart',
            isDirectory: false),
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sshServiceProvider.overrideWithValue(MockSSHService()),
          fileOperationsProvider
              .overrideWithValue(MockFileOperations(mockListings)),
          projectPathProvider
              .overrideWith(() => MockProjectPathNotifier(projectPath)),
        ],
        child: const MaterialApp(home: Scaffold(body: FileTreeWidget())),
      ),
    );

    await tester.pumpAndSettle();

    // Tap to toggle (it's expanded by default if it's the root, but let's test a subfolder)
    // Actually, in our test, 'folder' is a child of the root. Root is 'project'.

    // The root is expanded by default in initState if path is set.
    // So 'folder' should be visible.
    expect(find.text('folder'), findsOneWidget);

    // Expand 'folder'
    await tester.tap(find.text('folder'));
    await tester.pumpAndSettle();

    // Verify sub-item appeared
    expect(find.text('subfile.dart'), findsOneWidget);
  });
}
