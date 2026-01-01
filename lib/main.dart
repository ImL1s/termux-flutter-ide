// Triggering hot reload for test
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:termux_flutter_ide/theme/app_theme.dart';
import 'package:termux_flutter_ide/editor/editor_page.dart';
import 'package:termux_flutter_ide/settings/settings_page.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/core/snackbar_service.dart';
import 'package:termux_flutter_ide/setup/setup_service.dart';
import 'package:termux_flutter_ide/setup/setup_wizard.dart';

void main() {
  runApp(const ProviderScope(child: TermuxFlutterIDE()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const EditorPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/setup',
      builder: (context, state) => const SetupWizardPage(),
    ),
  ],
);

class TermuxFlutterIDE extends ConsumerStatefulWidget {
  const TermuxFlutterIDE({super.key});

  @override
  ConsumerState<TermuxFlutterIDE> createState() => _TermuxFlutterIDEState();
}

class _TermuxFlutterIDEState extends ConsumerState<TermuxFlutterIDE> {
  @override
  void initState() {
    super.initState();
    // Start SSH connection globally on app launch
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(sshServiceProvider).connect();

      // Check if setup is needed
      await ref.read(setupServiceProvider.notifier).checkEnvironment();

      final newSetupState = ref.read(setupServiceProvider);

      // Redirect if SSH failed OR Flutter is missing
      if (!newSetupState.isSSHConnected || !newSetupState.isFlutterInstalled) {
        if (mounted) _router.push('/setup');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messengerKey = ref.watch(scaffoldMessengerKeyProvider);

    return MaterialApp.router(
      title: 'Termux Flutter IDE',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
    );
  }
}
