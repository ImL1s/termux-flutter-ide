import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:termux_flutter_ide/run/x11_missing_dialog.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? launchedUrl;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrl = url;
    return true;
  }

  @override
  Future<bool> canLaunch(String url) async {
    return true;
  }
}

void main() {
  testWidgets('X11MissingDialog Download button launches correct URL',
      (tester) async {
    // 1. Setup Mock
    final mockLauncher = MockUrlLauncher();
    UrlLauncherPlatform.instance = mockLauncher;

    // 2. Pump Widget
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: X11MissingDialog(),
        ),
      ),
    );

    // 3. Find Download Button
    final downloadBtn = find.text('前往下載');
    expect(downloadBtn, findsOneWidget);

    // 4. Tap Verify
    await tester.tap(downloadBtn);
    await tester.pump();

    // 5. Assert URL launched
    expect(mockLauncher.launchedUrl,
        'https://github.com/termux/termux-x11/releases');
  });
}
