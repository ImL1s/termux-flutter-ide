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
    // Use Future.microtask or just unawaited async to ensure UI renders first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initApp();
    });
  }

  Future<void> _initApp() async {
    // 1. Connect SSH (don't block UI if it hangs)
    try {
      ref
          .read(sshServiceProvider)
          .connect(); // Fire and forget (internal state handles status)
    } catch (e) {
      print('Init SSH failed: $e');
    }

    // 2. Check Environment
    try {
      await ref.read(setupServiceProvider.notifier).checkEnvironment();
      final newSetupState = ref.read(setupServiceProvider);

      // Redirect if needed
      if ((!newSetupState.isSSHConnected ||
              !newSetupState.isFlutterInstalled) &&
          mounted) {
        // Only redirect if we are sure
        if (mounted) _router.push('/setup');
      }
    } catch (e) {
      print('Init CheckEnvironment failed: $e');
    }
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
