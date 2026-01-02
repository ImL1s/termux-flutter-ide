import 'dart:io';
import 'dart:convert';

/// Standalone Analyzer Agent for Termux
/// This script scans a directory and calculates code metrics without requiring external packages
/// (Uses raw file parsing for speed/simplicity in MVP, can be upgraded to use package:analyzer)

void main(List<String> args) {
  if (args.isEmpty) {
    print(jsonEncode({'error': 'No path provided'}));
    return;
  }

  final rootPath = args[0];
  final directory = Directory(rootPath);

  if (!directory.existsSync()) {
    print(jsonEncode({'error': 'Directory does not exist'}));
    return;
  }

  final files = directory.listSync(recursive: true);
  final dartFiles =
      files.whereType<File>().where((f) => f.path.endsWith('.dart'));

  int totalLoc = 0;
  int totalMethods = 0;
  int totalComplexity = 0;
  int totalTodos = 0;
  List<Map<String, dynamic>> fileMetrics = [];

  for (final file in dartFiles) {
    // Skip generated files
    if (file.path.contains('.g.dart') || file.path.contains('.freezed.dart'))
      continue;

    final lines = file.readAsLinesSync();
    totalLoc += lines.length;

    int methodCount = 0;
    int complexity = 0;
    int fileTodos = 0;

    for (final line in lines) {
      final trimmed = line.trim();

      // Basic Method detection (heuristic: contains '(' and ends with '{')
      if (trimmed.contains('(') &&
          trimmed.endsWith('{') &&
          !trimmed.contains('if') &&
          !trimmed.contains('for') &&
          !trimmed.contains('while') &&
          !trimmed.contains('switch')) {
        methodCount++;
      }

      // Basic Complexity detection (Cyclomatic: if, for, while, catch, etc.)
      final complexityKeywords = [
        'if ',
        'for ',
        'while ',
        'case ',
        'catch ',
        '&& ',
        '|| ',
        '? '
      ];
      for (final kw in complexityKeywords) {
        if (trimmed.contains(kw)) complexity++;
      }

      if (trimmed.toLowerCase().contains('todo:')) {
        fileTodos++;
      }
    }

    totalMethods += methodCount;
    totalComplexity += complexity;
    totalTodos += fileTodos;

    fileMetrics.add({
      'path': file.path.replaceFirst(rootPath, ''),
      'loc': lines.length,
      'methodCount': methodCount,
      'averageComplexity':
          methodCount > 0 ? (complexity / methodCount).round() : 0,
    });
  }

  // Sort by complexity
  fileMetrics.sort((a, b) =>
      (b['averageComplexity'] as int).compareTo(a['averageComplexity'] as int));

  final report = {
    'timestamp': DateTime.now().toIso8601String(),
    'totalLoc': totalLoc,
    'maintainabilityScore':
        _calculateScore(totalLoc, totalComplexity, totalMethods),
    'topComplexFiles': fileMetrics.take(10).toList(),
    'totalWarnings': 0, // Would need full analyzer for this
    'totalTodos': totalTodos,
  };

  print(jsonEncode(report));
}

double _calculateScore(int loc, int complexity, int methods) {
  if (loc == 0 || methods == 0) return 100.0;

  // Very rough Halstead-inspired maintainability index
  final avgComplexityPerMethod = complexity / methods;
  double score = 100.0 - (avgComplexityPerMethod * 5.0);

  if (score < 0) score = 0;
  return double.parse(score.toStringAsFixed(2));
}
