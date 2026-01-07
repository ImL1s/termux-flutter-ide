import 'package:flutter/material.dart';
import 'termux_test_runner.dart';

/// 獨立的測試 App - 直接在設備上運行測試
void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Termux 測試',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TermuxTestRunner(),
    );
  }
}
