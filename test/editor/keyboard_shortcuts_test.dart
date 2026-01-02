import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/editor/keyboard_shortcuts_dialog.dart';

void main() {
  testWidgets('Keyboard Shortcuts Dialog shows categories and items',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () => showKeyboardShortcutsDialog(context),
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Check Title
    expect(find.text('Keyboard Shortcuts'), findsOneWidget);

    // Check visible content (First category)
    expect(find.text('編輯器'), findsOneWidget);
    expect(find.text('Ctrl + F'), findsOneWidget);
    expect(find.text('搜尋'), findsOneWidget);

    // Note: Other categories might be off-screen and require scrolling to find
    // so we skip verifying them to keep the test robust against screen size.
  });
}
