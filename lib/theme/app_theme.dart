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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF313244),
        thickness: 1,
      ),
      fontFamily: 'JetBrains Mono',
    );
  }

  // Editor color scheme (Catppuccin Mocha inspired)
  static const Color editorBackground = Color(0xFF1E1E2E);
  static const Color editorLineNumbers = Color(0xFF6C7086);
  static const Color editorSelection = Color(0xFF45475A);
  static const Color editorCurrentLine = Color(0xFF313244);
  
  // Syntax colors
  static const Color syntaxKeyword = Color(0xFFCBA6F7);
  static const Color syntaxString = Color(0xFFA6E3A1);
  static const Color syntaxNumber = Color(0xFFFAB387);
  static const Color syntaxComment = Color(0xFF6C7086);
  static const Color syntaxFunction = Color(0xFF89B4FA);
  static const Color syntaxVariable = Color(0xFFF5E0DC);
  static const Color syntaxType = Color(0xFFF9E2AF);
}
