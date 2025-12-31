import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/run/flutter_runner_widget.dart';
import 'package:termux_flutter_ide/run/flutter_runner_service.dart';
import 'package:termux_flutter_ide/run/launch_config.dart';
import 'package:termux_flutter_ide/terminal/terminal_session.dart';
import 'package:termux_flutter_ide/core/providers.dart';

// Mock ProjectPathNotifier
class MockProjectPathNotifier extends ProjectPathNotifier {
  @override
  String? build() => '/test/project';
}

// Mock LaunchConfigurations - returns test configs
class MockLaunchConfigurationsProvider {
  static Future<List<LaunchConfiguration>> get configs async {
    return [
      const LaunchConfiguration(name: 'Debug', mode: 'debug'),
      const LaunchConfiguration(name: 'Release', mode: 'release'),
    ];
  }
}

void main() {
  group('FlutterRunnerWidget UI Tests', () {
    testWidgets('shows configuration dropdown with configs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectPathProvider.overrideWith(MockProjectPathNotifier.new),
            launchConfigurationsProvider.overrideWith((ref) async {
              return [
                const LaunchConfiguration(name: 'Debug', mode: 'debug'),
                const LaunchConfiguration(name: 'Release', mode: 'release'),
              ];
            }),
            runnerStateProvider.overrideWith(RunnerStateNotifier.new),
            runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
            activeRunnerSessionIdProvider
                .overrideWith(ActiveRunnerSessionIdNotifier.new),
            terminalSessionsProvider.overrideWith(TerminalSessionNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FlutterRunnerWidget()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show dropdown with config name
      expect(find.text('Debug'), findsOneWidget);
    });

    testWidgets('shows play button when idle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectPathProvider.overrideWith(MockProjectPathNotifier.new),
            launchConfigurationsProvider.overrideWith((ref) async {
              return [const LaunchConfiguration(name: 'Test')];
            }),
            runnerStateProvider.overrideWith(RunnerStateNotifier.new),
            runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
            activeRunnerSessionIdProvider
                .overrideWith(ActiveRunnerSessionIdNotifier.new),
            terminalSessionsProvider.overrideWith(TerminalSessionNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FlutterRunnerWidget()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show play button (green arrow)
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows loading indicator when connecting', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectPathProvider.overrideWith(MockProjectPathNotifier.new),
            launchConfigurationsProvider.overrideWith((ref) async {
              return [const LaunchConfiguration(name: 'Test')];
            }),
            runnerStateProvider.overrideWith(() {
              final notifier = RunnerStateNotifier();
              return notifier;
            }),
            runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
            activeRunnerSessionIdProvider
                .overrideWith(ActiveRunnerSessionIdNotifier.new),
            terminalSessionsProvider.overrideWith(TerminalSessionNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FlutterRunnerWidget()),
          ),
        ),
      );

      // Set state to connecting
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FlutterRunnerWidget)),
      );
      container
          .read(runnerStateProvider.notifier)
          .setState(RunnerState.connecting);

      await tester.pump();

      // Should show circular progress indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error banner when error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectPathProvider.overrideWith(MockProjectPathNotifier.new),
            launchConfigurationsProvider.overrideWith((ref) async {
              return [const LaunchConfiguration(name: 'Test')];
            }),
            runnerStateProvider.overrideWith(RunnerStateNotifier.new),
            runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
            activeRunnerSessionIdProvider
                .overrideWith(ActiveRunnerSessionIdNotifier.new),
            terminalSessionsProvider.overrideWith(TerminalSessionNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FlutterRunnerWidget()),
          ),
        ),
      );

      // Set error
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FlutterRunnerWidget)),
      );
      container
          .read(runnerErrorProvider.notifier)
          .setError('SSH connection failed');

      await tester.pump();

      // Should show error banner with message
      expect(find.text('SSH connection failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows placeholder when no session active', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectPathProvider.overrideWith(MockProjectPathNotifier.new),
            launchConfigurationsProvider.overrideWith((ref) async {
              return [const LaunchConfiguration(name: 'Test')];
            }),
            runnerStateProvider.overrideWith(RunnerStateNotifier.new),
            runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
            activeRunnerSessionIdProvider
                .overrideWith(ActiveRunnerSessionIdNotifier.new),
            terminalSessionsProvider.overrideWith(TerminalSessionNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FlutterRunnerWidget()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show placeholder text
      expect(find.text('Select a configuration and press Run'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('shows edit and ADB connect buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectPathProvider.overrideWith(MockProjectPathNotifier.new),
            launchConfigurationsProvider.overrideWith((ref) async {
              return [const LaunchConfiguration(name: 'Test')];
            }),
            runnerStateProvider.overrideWith(RunnerStateNotifier.new),
            runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
            activeRunnerSessionIdProvider
                .overrideWith(ActiveRunnerSessionIdNotifier.new),
            terminalSessionsProvider.overrideWith(TerminalSessionNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FlutterRunnerWidget()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show edit and ADB icons
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.wifi_tethering), findsOneWidget);
    });

    testWidgets('ADB connect button opens dialog', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            projectPathProvider.overrideWith(MockProjectPathNotifier.new),
            launchConfigurationsProvider.overrideWith((ref) async {
              return [const LaunchConfiguration(name: 'Test')];
            }),
            runnerStateProvider.overrideWith(RunnerStateNotifier.new),
            runnerErrorProvider.overrideWith(RunnerErrorNotifier.new),
            activeRunnerSessionIdProvider
                .overrideWith(ActiveRunnerSessionIdNotifier.new),
            terminalSessionsProvider.overrideWith(TerminalSessionNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FlutterRunnerWidget()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap ADB button
      await tester.tap(find.byIcon(Icons.wifi_tethering));
      await tester.pumpAndSettle();

      // Should show dialog
      expect(find.text('ADB Wireless Connect'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
    });
  });
}
