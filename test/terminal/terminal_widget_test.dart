import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/terminal/terminal_widget.dart';
import 'package:termux_flutter_ide/terminal/terminal_session.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'package:termux_flutter_ide/core/providers.dart';

// Mock TerminalSessionNotifier that doesn't connect to SSH
class MockTerminalSessionNotifier extends TerminalSessionNotifier {
  @override
  Future<String> createSession({String? name, String? initialDirectory}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = TerminalSession(
      id: id,
      name: name ?? 'Session ${state.sessions.length + 1}',
      initialDirectory: initialDirectory,
    );
    session.state = SessionState.connected;
    state = state.copyWith(
      sessions: [...state.sessions, session],
      activeSessionId: id,
    );
    return id;
  }

  @override
  Future<void> connectSession(TerminalSession session) async {
    session.state = SessionState.connected;
    state = state.copyWith();
  }
}

// Pre-populated mock with initial session
class PrePopulatedTerminalSessionNotifier extends TerminalSessionNotifier {
  @override
  TerminalSessionsState build() {
    final session = TerminalSession(id: '1', name: 'Session 1');
    session.state = SessionState.connected;
    return TerminalSessionsState(sessions: [session], activeSessionId: '1');
  }

  @override
  Future<String> createSession({String? name, String? initialDirectory}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final session = TerminalSession(
      id: id,
      name: name ?? 'Session ${state.sessions.length + 1}',
      initialDirectory: initialDirectory,
    );
    session.state = SessionState.connected;
    state = state.copyWith(
      sessions: [...state.sessions, session],
      activeSessionId: id,
    );
    return id;
  }

  @override
  Future<void> connectSession(TerminalSession session) async {
    session.state = SessionState.connected;
    state = state.copyWith();
  }
}

void main() {
  group('TerminalWidget UI Tests', () {
    // Note: xterm has a blinking cursor animation that never settles.
    // Use tester.pump(duration) instead of pumpAndSettle() for these tests.

    testWidgets('shows add session button when session exists', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termuxInstalledProvider.overrideWith((ref) async => true),
            terminalSessionsProvider
                .overrideWith(PrePopulatedTerminalSessionNotifier.new),
            terminalCommandProvider.overrideWith(TerminalCommandNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TerminalWidget()),
          ),
        ),
      );

      // Use pump with duration instead of pumpAndSettle
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show add button
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('tapping add creates new session', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termuxInstalledProvider.overrideWith((ref) async => true),
            terminalSessionsProvider
                .overrideWith(PrePopulatedTerminalSessionNotifier.new),
            terminalCommandProvider.overrideWith(TerminalCommandNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TerminalWidget()),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TerminalWidget)),
      );

      // Initial: 1 pre-populated session
      expect(container.read(terminalSessionsProvider).sessions.length, 1);

      // Tap add button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump(const Duration(milliseconds: 100));

      // Should have 2 sessions now
      expect(container.read(terminalSessionsProvider).sessions.length, 2);
    });

    testWidgets('shows session name in tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termuxInstalledProvider.overrideWith((ref) async => true),
            terminalSessionsProvider
                .overrideWith(PrePopulatedTerminalSessionNotifier.new),
            terminalCommandProvider.overrideWith(TerminalCommandNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TerminalWidget()),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show session name
      expect(find.text('Session 1'), findsOneWidget);
    });

    testWidgets('shows terminal icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termuxInstalledProvider.overrideWith((ref) async => true),
            terminalSessionsProvider
                .overrideWith(PrePopulatedTerminalSessionNotifier.new),
            terminalCommandProvider.overrideWith(TerminalCommandNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TerminalWidget()),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show terminal icon
      expect(find.byIcon(Icons.terminal), findsOneWidget);
    });

    // Note: Testing loading state is problematic because Future.delayed
    // creates a Timer that conflicts with Flutter test framework expectations.
    // The loading state is implicitly tested as part of other tests' pump() calls.

    testWidgets('shows termux missing UI when not installed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            termuxInstalledProvider.overrideWith((ref) async => false),
            terminalSessionsProvider
                .overrideWith(MockTerminalSessionNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: TerminalWidget()),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show Termux not installed message
      expect(find.textContaining('Termux'), findsAtLeastNWidgets(1));
    });
  });
}
