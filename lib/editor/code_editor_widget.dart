import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
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
import '../file_manager/file_operations.dart';
import 'editor_providers.dart';
import '../core/providers.dart';
import 'coding_toolbar.dart';
import 'editor_request_provider.dart'; // Import Request Provider

class CodeEditorWidget extends ConsumerStatefulWidget {
  const CodeEditorWidget({super.key});

  @override
  ConsumerState<CodeEditorWidget> createState() => _CodeEditorWidgetState();
}

class _CodeEditorWidgetState extends ConsumerState<CodeEditorWidget> {
  CodeController? _controller;
  String? _currentFilePath;
  bool _isLoading = false;
  String? _error;
  Timer? _autoSaveTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Create a microtask to allow other potential focus events to settle
      // effectively saving when truly lost focus
      saveFile();
    }
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

    // Listen for save trigger
    ref.listen(saveTriggerProvider, (previous, next) {
      if (next > (previous ?? 0)) {
        saveFile();
      }
    });

    // Listen for editor requests (Jump to line)
    ref.listen(editorRequestProvider, (previous, next) {
      if (next is JumpToLineRequest) {
        if (next.filePath == currentFile) {
          // We might need to wait for controller to be ready if file just switched
          if (_controller != null) {
            _jumpToLine(next.lineNumber);
          }
        }
      }
    });

    // If file path changed, load file content
    if (_currentFilePath != currentFile) {
      _currentFilePath = currentFile;
      _loadFileContent(currentFile!);
    }

    // If controller is null but we have a file, and not loading, try loading
    if (_controller == null &&
        currentFile != null &&
        !_isLoading &&
        _error == null) {
      // This handles case where initial build happens before provider update?
      // Actually _loadFileContent is async, so controller will be null initially.
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading file: $_error',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadFileContent(currentFile!),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_controller == null) {
      return const Center(
        child: Text('No file selected', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF1E1E2E),
            child: CodeTheme(
              data: CodeThemeData(styles: _getThemeStyles(editorTheme)),
              child: SingleChildScrollView(
                child: CodeField(
                  focusNode: _focusNode,
                  controller: _controller!,
                  textStyle: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: fontSize,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (MediaQuery.of(context).viewInsets.bottom > 0)
          CodingToolbar(controller: _controller!),
      ],
    );
  }

  Future<void> _loadFileContent(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ops = ref.read(fileOperationsProvider);
      final content = await ops.readFile(path);

      if (content != null) {
        _controller?.dispose();
        _controller = CodeController(
          text: content,
          language: _getLanguageForFile(path),
        );

        // Listen for changes to update dirty state
        _controller!.addListener(_onCodeChanged);

        // Cache original content for dirty checking
        ref.read(originalContentProvider.notifier).set(path, content);
      } else {
        _error = 'Could not read file';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onCodeChanged() {
    if (_currentFilePath == null || _controller == null) return;

    final currentContent = _controller!.text;
    final originalContent = ref.read(
      originalContentProvider,
    )[_currentFilePath!];

    if (currentContent != originalContent) {
      ref.read(dirtyFilesProvider.notifier).markDirty(_currentFilePath!);
    } else {
      ref.read(dirtyFilesProvider.notifier).markClean(_currentFilePath!);
    }

    // Debounce auto-save
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        saveFile();
      }
    });
  }

  /// Save the current file content
  Future<void> saveFile() async {
    if (_currentFilePath == null || _controller == null) return;

    // Check if dirty
    final isDirty =
        ref.read(dirtyFilesProvider.notifier).isDirty(_currentFilePath!);
    if (!isDirty) return; // Nothing to save

    ref.read(isSavingProvider.notifier).set(true);
    try {
      final content = _controller!.text;
      final ops = ref.read(fileOperationsProvider);
      final success = await ops.writeFile(_currentFilePath!, content);

      if (success) {
        // Update original content to match saved content
        ref
            .read(originalContentProvider.notifier)
            .set(_currentFilePath!, content);
        ref.read(dirtyFilesProvider.notifier).markClean(_currentFilePath!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File saved'),
              duration: Duration(milliseconds: 1000),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save file'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(isSavingProvider.notifier).set(false);
    }
  }

  void _jumpToLine(int lineNumber) {
    if (_controller == null) return;

    // Line is 1-based, convert to 0-based index
    final lineIndex = lineNumber - 1;
    final text = _controller!.text;
    final lines = text.split('\n');

    if (lineIndex < 0 || lineIndex >= lines.length) return;

    // Calculate offset
    int offset = 0;
    for (int i = 0; i < lineIndex; i++) {
      offset += lines[i].length + 1; // +1 for newline
    }

    _controller!.selection = TextSelection.collapsed(offset: offset);
    _focusNode.requestFocus();

    // Scroll to make sure it's visible is tricky with SingleChildScrollView + CodeField
    // CodeField might not expose ScrollController easily or might handle it via selection,
    // but standard TextField doesn't auto-scroll to center selection always.
    // However, focusing and setting selection usually brings it into view.
    // For better scrolling, we might need Scrollable.ensureVisible or similar if we had keys.
    // But let's rely on selection behavior for now.
  }
}
