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
import '../core/snackbar_service.dart';
import 'coding_toolbar.dart';
import 'editor_request_provider.dart'; // Import Request Provider
import 'completion/completion_service.dart';
import 'package:termux_flutter_ide/run/breakpoint_service.dart';

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
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: CodeField(
                      focusNode: _focusNode,
                      controller: _controller!,
                      textStyle: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: fontSize,
                      ),
                    ),
                  ),
                  // Breakpoint Interaction Layer
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 45, // Match gutterWidth in _BreakpointLayer
                    child: _BreakpointLayer(
                      controller: _controller!,
                      fontSize: fontSize,
                      filePath: _currentFilePath!,
                    ),
                  ),
                ],
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
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ops = ref.read(fileOperationsProvider);
      final content = await ops.readFile(path);

      if (content != null) {
        if (!mounted) return;
        setState(() {
          _controller?.dispose();
          _controller = CodeController(
            text: content,
            language: _getLanguageForFile(path),
          );
          _isLoading = false;
        });

        // Initialize completion with file keywords
        ref.read(completionProvider.notifier).updateFileContent(content);

        // Listen for changes to update dirty state
        _controller!.addListener(_onCodeChanged);

        // Cache original content to track unsaved changes
        ref.read(originalContentProvider.notifier).set(path, content);
      } else {
        if (mounted) {
          setState(() {
            _error = 'Could not read file';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onCodeChanged() {
    if (_currentFilePath == null || _controller == null) return;

    // 1. Dirty check
    final currentContent = _controller!.text;
    final originalContent = ref.read(
      originalContentProvider,
    )[_currentFilePath!];

    if (currentContent != originalContent) {
      ref.read(dirtyFilesProvider.notifier).markDirty(_currentFilePath!);
    } else {
      ref.read(dirtyFilesProvider.notifier).markClean(_currentFilePath!);
    }

    // 2. Auto-completion trigger
    _updateCompletion();

    // 3. Debounce auto-save
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        saveFile();
      }
    });
  }

  void _updateCompletion() {
    final selection = _controller!.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      ref.read(completionProvider.notifier).clear();
      return;
    }

    final text = _controller!.text;
    final cursor = selection.baseOffset;
    if (cursor == 0) return;

    // Get current line
    // Find last newline before cursor
    int lineStart = text.lastIndexOf('\n', cursor - 1);
    lineStart = lineStart == -1 ? 0 : lineStart + 1;

    // Find next newline after cursor
    int lineEnd = text.indexOf('\n', cursor);
    lineEnd = lineEnd == -1 ? text.length : lineEnd;

    final fullLine = text.substring(lineStart, lineEnd);

    // Get word before cursor
    int wordStart = cursor - 1;
    while (wordStart >= 0) {
      final char = text[wordStart];
      // Allow letters, numbers, underscores
      if (!RegExp(r'[a-zA-Z0-9_]').hasMatch(char)) {
        break;
      }
      wordStart--;
    }
    wordStart++; // Move back to first char

    final currentWord = text.substring(wordStart, cursor);

    if (currentWord.isNotEmpty) {
      ref
          .read(completionProvider.notifier)
          .updateSuggestions(currentWord, fullLine);
    } else {
      ref.read(completionProvider.notifier).clear();
    }
  }

  /// Save the current file content
  Future<void> saveFile() async {
    if (_currentFilePath == null || _controller == null) return;

    // Check if dirty
    final isDirty =
        ref.read(dirtyFilesProvider.notifier).isDirty(_currentFilePath!);
    if (!isDirty) return; // Nothing to save

    final snackBar = ref.read(snackBarServiceProvider);
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

        // Use global SnackBar service
        snackBar.success('已儲存: ${_currentFilePath!.split('/').last}');
      } else {
        snackBar.error('儲存失敗');
      }
    } catch (e) {
      snackBar.error('儲存錯誤: $e');
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

class _BreakpointLayer extends ConsumerWidget {
  final CodeController controller;
  final double fontSize;
  final String filePath;

  const _BreakpointLayer({
    required this.controller,
    required this.fontSize,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakpoints = ref.watch(breakpointsProvider).getByPath(filePath);

    // Line height is usually around 1.4 * fontSize depending on the font
    final lineHeight = fontSize * 1.5; // Heuristic for JetBrains Mono
    // Gutter width in flutter_code_editor is usually dynamic.
    // Let's assume a safe area for clicking (first 40-50 pixels)
    const gutterWidth = 45.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        if (details.localPosition.dx <= gutterWidth) {
          final effectiveTapY = details.localPosition.dy +
              (Scrollable.maybeOf(context)?.position.pixels ?? 0);
          final line = (effectiveTapY / lineHeight).floor() + 1;

          ref
              .read(breakpointsProvider.notifier)
              .toggleBreakpoint(filePath, line);
        }
      },
      onLongPressStart: (details) async {
        if (details.localPosition.dx <= gutterWidth) {
          final effectiveTapY = details.localPosition.dy +
              (Scrollable.maybeOf(context)?.position.pixels ?? 0);
          final line = (effectiveTapY / lineHeight).floor() + 1;

          final controller = TextEditingController();
          final currentBp =
              ref.read(breakpointsProvider).breakpoints.firstWhere(
                    (b) => b.path == filePath && b.line == line,
                    orElse: () => Breakpoint(path: filePath, line: line),
                  );

          if (currentBp.condition != null) {
            controller.text = currentBp.condition!;
          }

          final condition = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Edit Breakpoint at Line $line'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Condition (optional)',
                  hintText: 'e.g. i > 5',
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text('Save')),
              ],
            ),
          );

          if (condition != null) {
            // Update breakpoint with condition (or remove condition if empty string?)
            // If empty string, maybe treat as null?
            final finalCondition = condition.trim().isEmpty ? null : condition;

            // Note: toggleBreakpoint logic toggles if exists.
            // If we are editing, we probably want to FORCE set or update.
            // But our notifier only has toggle.
            // Let's modify toggle logic: if it exists, remove it first?
            // Or better, just call toggle to add/update if we pass condition.

            // If it already exists, toggle removes it.
            // We should probably check existence.
            final exists = ref
                .read(breakpointsProvider)
                .breakpoints
                .any((b) => b.path == filePath && b.line == line);

            if (exists) {
              // Remove old one first
              ref
                  .read(breakpointsProvider.notifier)
                  .toggleBreakpoint(filePath, line);
            }
            // Add new one with condition
            ref
                .read(breakpointsProvider.notifier)
                .toggleBreakpoint(filePath, line, condition: finalCondition);
          }
        }
      },
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _BreakpointPainter(
            breakpoints: breakpoints,
            lineHeight: lineHeight,
            gutterWidth: gutterWidth,
            scrollOffset: Scrollable.maybeOf(context)?.position.pixels ?? 0,
          ),
        ),
      ),
    );
  }
}

class _BreakpointPainter extends CustomPainter {
  final List<Breakpoint> breakpoints;
  final double lineHeight;
  final double gutterWidth;
  final double scrollOffset;

  _BreakpointPainter({
    required this.breakpoints,
    required this.lineHeight,
    required this.gutterWidth,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    for (final bp in breakpoints) {
      final y = (bp.line - 1) * lineHeight - scrollOffset + (lineHeight / 2);

      // Only draw if within visible vertical area
      if (y >= -lineHeight && y <= size.height + lineHeight) {
        paint.color = (bp.condition != null && bp.condition!.isNotEmpty)
            ? Colors.orange.withValues(alpha: 0.8)
            : Colors.red.withValues(alpha: 0.8);

        canvas.drawCircle(
          Offset(gutterWidth / 2 - 8, y), // Offset slightly to the left
          6,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BreakpointPainter oldDelegate) {
    return oldDelegate.breakpoints != breakpoints ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.lineHeight != lineHeight;
  }
}
