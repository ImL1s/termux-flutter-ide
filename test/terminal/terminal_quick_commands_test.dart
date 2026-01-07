import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:termux_flutter_ide/terminal/terminal_quick_commands.dart';
import 'package:termux_flutter_ide/core/providers.dart';
import 'package:termux_flutter_ide/terminal/terminal_session.dart';

// Mock classes
class MockTerminalSession extends Mock implements TerminalSession {
  bool dataReceivedCalled = false;
  String? receivedData;

  @override
  String get id => 'mock_session_id'; // Match the ID used in state

  @override
  void onDataReceived(String data) {
    dataReceivedCalled = true;
    receivedData = data;
  }

  @override
  Future<void> write(String data) async {
    // Not used in this test case
  }
}

class MockTerminalSessionNotifier extends TerminalSessionNotifier {
  final MockTerminalSession mockSession;

  MockTerminalSessionNotifier(this.mockSession);

  @override
  TerminalSessionsState build() {
    return TerminalSessionsState(
      sessions: [mockSession],
      activeSessionId: 'mock_session_id',
    );
  }
}

void main() {
  testWidgets(
      'TerminalQuickCommands shows error in terminal when projectPath is null',
      (WidgetTester tester) async {
    final mockSession = MockTerminalSession();

    // Create a container with overrides
    final container = ProviderContainer(
      overrides: [
        projectPathProvider
            .overrideWith(() => ProjectPathNotifier()), // Default is null
        terminalSessionsProvider
            .overrideWith(() => MockTerminalSessionNotifier(mockSession)),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: TerminalQuickCommands(),
          ),
        ),
      ),
    );

    // Tap the clean button
    await tester.tap(find.text('clean'));
    await tester.pumpAndSettle();

    // Verify SnackBar is shown
    expect(find.textContaining('請先開啟專案'), findsOneWidget);

    // Verify terminal onDataReceived was called with error message
    expect(mockSession.dataReceivedCalled, isTrue,
        reason: 'Terminal onDataReceived should be called');
    expect(mockSession.receivedData, contains('No project open'),
        reason: 'Should output error message to terminal');
  });
}
