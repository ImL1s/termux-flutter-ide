import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/editor_page.dart';
import 'package:termux_flutter_ide/core/providers.dart';
import 'package:termux_flutter_ide/editor/editor_providers.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'package:termux_flutter_ide/ai/ai_providers.dart';
import 'package:termux_flutter_ide/editor/activity_bar.dart';
import 'package:termux_flutter_ide/run/flutter_runner_service.dart';
import 'package:termux_flutter_ide/editor/command_palette.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/editor/file_tabs_widget.dart';

// Mocks
class MockSSHService extends Mock implements SSHService {}

class MockFlutterRunnerService extends Mock implements FlutterRunnerService {}

class MockCommandService extends Mock implements CommandService {
  @override
  void register(Command command) {}
}

void main() {
  // Common overrides
  final overrides = [
    // Override StreamProvider with a stream
    sshStatusProvider.overrideWith((ref) => Stream.value(SSHStatus.connected)),

    // Override Providers with Mocks
    sshServiceProvider.overrideWith((ref) => MockSSHService()),
    flutterRunnerServiceProvider
        .overrideWith((ref) => MockFlutterRunnerService()),
    commandServiceProvider.overrideWith((ref) => MockCommandService()),
  ];

  setUp(() {
    // Mock termux channel to prevent TermuxBridge timeouts (pending timers)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('termux_flutter_ide/termux'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'isTermuxInstalled') {
          return true;
        }
        if (methodCall.method == 'executeCommand') {
          return {'success': true, 'exitCode': 0, 'stdout': '', 'stderr': ''};
        }
        return null;
      },
    );
  });
  const flexDisplayFeature = DisplayFeature(
    bounds: Rect.fromLTWH(0, 400, 800, 20),
    type: DisplayFeatureType.fold,
    state: DisplayFeatureState.postureHalfOpened,
  );

  testWidgets('EditorPage shows Flex Mode layout (Top/Bottom split)',
      (tester) async {
    // Large screen with Flex Mode fold
    const screenSize = Size(800, 900);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: screenSize,
              displayFeatures: [flexDisplayFeature],
            ),
            child: const EditorPage(),
          ),
        ),
      ),
    );

    // Use pump instead of pumpAndSettle to avoid timeouts with blinking cursors
    await tester.pumpAndSettle();

    // Verify TabBar with 4 specific tabs (Terminal, Problems, Debug, Runner)
    expect(find.byIcon(Icons.terminal), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.warning_amber), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.bug_report), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.play_circle), findsAtLeastNWidgets(1));

    // Verify top bar for Flex Mode (compact)
    // Default project name when path is null is 'IDE' (see editor_page.dart)
    expect(find.text('IDE'), findsOneWidget);
  });

  testWidgets('EditorPage shows Cover Screen layout (Mobile fallback)',
      (tester) async {
    // Narrow Cover Screen
    const screenSize = Size(400, 900); // Ratio > 2.0

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: screenSize,
              displayFeatures: [], // No fold
            ),
            child: const EditorPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The simplified Flex Mode control panel with 4 tabs should NOT be present
    expect(find.byIcon(Icons.play_circle), findsNothing);
  });

  testWidgets('EditorPage shows Unfolded Flat layout (TwoPane)',
      (tester) async {
    const screenSize = Size(1000, 800);
    // ignore: subtype_of_sealed_class
    const flatHinge = DisplayFeature(
      bounds: Rect.fromLTWH(490, 0, 20, 800),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureFlat,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: screenSize,
              displayFeatures: [flatHinge],
            ),
            child: const EditorPage(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // In TwoPane (foldable open), we have the vertical Activity Bar on the left
    // ActivityBar contains Icons.analytics_outlined (Project Health)
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

    // Also we should see the FileTabsWidget
    expect(find.byType(FileTabsWidget), findsOneWidget);
  });
}
