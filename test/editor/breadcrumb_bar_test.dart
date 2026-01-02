import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/breadcrumb_bar.dart';
import 'package:termux_flutter_ide/core/providers.dart';

void main() {
  testWidgets('BreadcrumbBar displays formatted path', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Setup state
    container.read(projectPathProvider.notifier).set('/home/user/project');
    container
        .read(currentFileProvider.notifier)
        .select('/home/user/project/lib/main.dart');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Should show relative path segments: lib, main.dart
    expect(find.text('lib'), findsOneWidget);
    expect(find.text('main.dart'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('BreadcrumbBar handles root file', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Setup state
    container.read(projectPathProvider.notifier).set('/home/user/project');
    container
        .read(currentFileProvider.notifier)
        .select('/home/user/project/pubspec.yaml');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('pubspec.yaml'), findsOneWidget);
    // Should NOT have 'lib' or chevrons if it's top level in project
    expect(find.text('lib'), findsNothing);
  });

  testWidgets('BreadcrumbBar hidden if no file selected', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: BreadcrumbBar(),
          ),
        ),
      ),
    );

    expect(find.byType(Row), findsNothing);
  });
}
