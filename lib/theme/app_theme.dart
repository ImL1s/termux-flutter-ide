import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00D4AA),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF181825),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF181825),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF313244),
        thickness: 1,
      ),
      fontFamily: 'JetBrains Mono',
    );
  }

  // VS Code Dark Modern / Catppuccin Mocha Palette
  static const Color background = Color(0xFF1E1E2E); // Main BG
  static const Color surface = Color(0xFF181825); // Sidebars, Panels
  static const Color surfaceVariant = Color(0xFF313244); // Borders, Dividers

  static const Color primary = Color(0xFFCBA6F7); // Accents (Purple)
  static const Color secondary = Color(0xFF89B4FA); // Secondary (Blue)
  static const Color tertiary = Color(0xFFA6E3A1); // Success/Strings (Green)
  static const Color error = Color(0xFFF38BA8); // Error (Red)

  // Component Specific
  static const Color activityBarBg = Color(0xFF11111B); // Darker than sidebar
  static const Color sideBarBg = Color(0xFF181825);
  static const Color editorBg = Color(0xFF1E1E2E);
  static const Color statusBarBg = Color(0xFF1F1F28); // Bottom bar (Blueish)

  static const Color tabActiveBg = Color(0xFF1E1E2E);
  static const Color tabInactiveBg = Color(0xFF181825);
  static const Color tabBorder = Color(0xFFCBA6F7); // Active Tab Top Border

  // Text Colors
  static const Color textPrimary = Color(0xFFCDD6F4);
  static const Color textSecondary = Color(0xFFA6ADC8);
  static const Color textDisabled = Color(0xFF6C7086);

  // Editor Syntax
  static const Color syntaxKeyword = Color(0xFFCBA6F7);
  static const Color syntaxString = Color(0xFFA6E3A1);
  static const Color syntaxNumber = Color(0xFFFAB387);
  static const Color syntaxComment = Color(0xFF6C7086);
  static const Color syntaxFunction = Color(0xFF89B4FA);
  static const Color syntaxVariable = Color(0xFFF5E0DC);
  static const Color syntaxType = Color(0xFFF9E2AF);
}
