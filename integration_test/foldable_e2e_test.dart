import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/editor/editor_page.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'package:termux_flutter_ide/termux/termux_bridge.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/run/flutter_runner_service.dart';
import 'package:termux_flutter_ide/editor/command_palette.dart';
import 'package:mockito/mockito.dart';

// === Mocks ===
class MockBridge extends Fake implements TermuxBridge {
  @override
  Future<bool> isTermuxInstalled() async => true;
  @override
  Future<TermuxResult> executeCommand(String command,
          {String? workingDirectory, bool background = false}) async =>
      TermuxResult(success: true, exitCode: 0, stdout: 'success', stderr: '');
  @override
  Future<bool> openTermux() async => true;
  @override
  Future<TermuxResult> setupTermuxSSH() async =>
      TermuxResult(success: true, exitCode: 0, stdout: '', stderr: '');
  @override
  Future<int?> getTermuxUid() async => 10001;
}

class MockSSHService extends Mock implements SSHService {}

class MockFlutterRunnerService extends Mock implements FlutterRunnerService {}

class MockCommandService extends Mock implements CommandService {
  @override
  void register(Command command) {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final mockOverrides = [
    termuxBridgeProvider.overrideWithValue(MockBridge()),
    sshStatusProvider.overrideWith((ref) => Stream.value(SSHStatus.connected)),
    sshServiceProvider.overrideWith((ref) => MockSSHService()),
    flutterRunnerServiceProvider
        .overrideWith((ref) => MockFlutterRunnerService()),
    commandServiceProvider.overrideWith((ref) => MockCommandService()),
  ];

  // === Flex Mode Test ===
  testWidgets('E2E: Flex Mode layout shows Top/Bottom split', (tester) async {
    // ignore: subtype_of_sealed_class
    const flexFeature = DisplayFeature(
      bounds: Rect.fromLTWH(0, 400, 800, 20),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: mockOverrides,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 900),
              displayFeatures: [flexFeature],
            ),
            child: const EditorPage(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    // Verify Flex Mode Control Panel tabs
    expect(find.byIcon(Icons.terminal), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.byIcon(Icons.bug_report), findsOneWidget);
    expect(find.byIcon(Icons.play_circle), findsOneWidget);

    // Verify AppBar shows 'IDE'
    expect(find.text('IDE'), findsOneWidget);

    // Tap on Terminal tab
    await tester.tap(find.text('Terminal'));
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on Problems tab
    await tester.tap(find.text('Problems'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify we can switch tabs without crashing
    expect(find.text('Problems'), findsOneWidget);
  });

  // === Cover Screen Test ===
  testWidgets('E2E: Cover Screen layout shows Mobile UI', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mockOverrides,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 900), // Narrow, tall (aspect ratio > 2)
              displayFeatures: [],
            ),
            child: const EditorPage(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    // In Mobile mode, the Flex Mode TabBar should NOT be present
    expect(find.byIcon(Icons.play_circle), findsNothing);

    // Mobile mode should have a Drawer or BottomNavigationBar
    // Let's verify the EditorPage rendered without Flex Mode elements
    expect(find.byType(EditorPage), findsOneWidget);
  });

  // === Unfolded (Flat) Test ===
  testWidgets('E2E: Unfolded Flat layout shows TwoPane', (tester) async {
    // ignore: subtype_of_sealed_class
    const flatHinge = DisplayFeature(
      bounds: Rect.fromLTWH(490, 0, 20, 800),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureFlat,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: mockOverrides,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(1000, 800),
              displayFeatures: [flatHinge],
            ),
            child: const EditorPage(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    // In TwoPane (Unfolded), Activity Bar should be visible
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

    // Tap on Activity Bar item (Project Health)
    await tester.tap(find.byIcon(Icons.analytics_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify we can interact with the sidebar
    expect(find.text('PROJECT HEALTH'), findsOneWidget);
  });
}
