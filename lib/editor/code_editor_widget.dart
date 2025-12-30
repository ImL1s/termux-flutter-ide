import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_highlight/themes/github-gist.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/highlight.dart' show Mode;
import '../settings/settings_providers.dart';
import '../core/providers.dart';

class CodeEditorWidget extends ConsumerStatefulWidget {
  const CodeEditorWidget({super.key});

  @override
  ConsumerState<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends ConsumerState<CodeEditorWidget> {
  CodeController? _controller;
  String? _currentFilePath;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Get highlight language mode based on file extension
  Mode _getLanguageForFile(String? filePath) {
    if (filePath == null) return dart;
    
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
        return dart;
      case 'js':
        return javascript;
      case 'ts':
      case 'tsx':
        return typescript;
      case 'py':
        return python;
      case 'json':
        return json;
      case 'yaml':
      case 'yml':
        return yaml;
      case 'md':
        return markdown;
      case 'xml':
      case 'html':
        return xml;
      default:
        return dart; // Default to dart
    }
  }

  /// Get theme styles based on EditorTheme enum
  Map<String, TextStyle> _getThemeStyles(EditorTheme theme) {
    switch (theme) {
      case EditorTheme.monokai:
        return monokaiSublimeTheme;
      case EditorTheme.vsDark:
        return vs2015Theme;
      case EditorTheme.githubDark:
        return githubGistTheme;
      case EditorTheme.atomOneDark:
        return atomOneDarkTheme;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(fontSizeProvider);
    final editorTheme = ref.watch(editorThemeProvider);
    final currentFile = ref.watch(currentFileProvider);

    // If file path changed, recreate controller
    if (_currentFilePath != currentFile || _controller == null) {
      _controller?.dispose();
      _controller = CodeController(
        text: _sampleCode,
        language: _getLanguageForFile(currentFile),
      );
      _currentFilePath = currentFile;
    }

    return Container(
      color: const Color(0xFF1E1E2E),
      child: CodeTheme(
        data: CodeThemeData(styles: _getThemeStyles(editorTheme)),
        child: SingleChildScrollView(
          child: CodeField(
            controller: _controller!,
            textStyle: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  static const String _sampleCode = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '\$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
''';
}
