import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:termux_flutter_ide/theme/app_theme.dart';
import 'package:termux_flutter_ide/editor/editor_page.dart';

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
  ],
);

class TermuxFlutterIDE extends StatelessWidget {
  const TermuxFlutterIDE({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Termux Flutter IDE',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
