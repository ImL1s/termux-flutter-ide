import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/ssh_service.dart';
import '../core/providers.dart';
import 'analyzer_models.dart';

/// Analyzer Service - Manages project-wide health analysis
class AnalyzerService {
  final SSHService _ssh;
  final Ref _ref;

  AnalyzerService(this._ssh, this._ref);

  /// Run project analysis
  Future<AnalysisReport?> analyzeProject() async {
    final projectPath = _ref.read(projectPathProvider);
    if (projectPath == null) return null;

    if (!_ssh.isConnected) {
      await _ssh.connect();
    }

    // 1. Prepare the agent script
    // We can either upload the file or send it as a heredoc.
    // For simplicity and speed, let's use a heredoc to run the logic directly.

    // Note: In a real app, you might bundle this script and use SFTP to upload it once.
    // For this implementation, we'll use a string-based approach.

    final agentScript = _getAgentScript();
    final tempScriptPath = '~/.termux_ide_analyzer.dart';

    try {
      // Write script to remote
      await _ssh.execute('cat << \'EOF\' > $tempScriptPath\n$agentScript\nEOF');

      // Execute script
      final result = await _ssh.execute('dart $tempScriptPath "$projectPath"');

      if (result.isEmpty) return null;

      return AnalysisReport.fromJson(result);
    } catch (e) {
      print('Analysis failed: $e');
      return null;
    }
  }

  String _getAgentScript() {
    // This is a copy of analyzer_agent.dart content for self-containment
    return r'''
import 'dart:io';
import 'dart:convert';

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
  final dartFiles = files.whereType<File>().where((f) => f.path.endsWith('.dart'));

  int totalLoc = 0;
  int totalMethods = 0;
  int totalComplexity = 0;
  int totalTodos = 0;
  List<Map<String, dynamic>> fileMetrics = [];

  for (final file in dartFiles) {
    if (file.path.contains('.g.dart') || file.path.contains('.freezed.dart') || file.path.contains('/.dart_tool/')) continue;

    try {
      final lines = file.readAsLinesSync();
      totalLoc += lines.length;

      int methodCount = 0;
      int complexity = 0;
      int fileTodos = 0;

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.contains('(') && trimmed.endsWith('{') && !trimmed.contains('if') && !trimmed.contains('for') && !trimmed.contains('while') && !trimmed.contains('switch')) {
          methodCount++;
        }
        final complexityKeywords = ['if ', 'for ', 'while ', 'case ', 'catch ', '&& ', '|| ', '? '];
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
        'averageComplexity': methodCount > 0 ? (complexity / methodCount).round() : 0,
      });
    } catch (e) {
      // Skip files that can't be read
    }
  }

  fileMetrics.sort((a, b) => (b['averageComplexity'] as int).compareTo(a['averageComplexity'] as int));

  final report = {
    'timestamp': DateTime.now().toIso8601String(),
    'totalLoc': totalLoc,
    'maintainabilityScore': _calculateScore(totalLoc, totalComplexity, totalMethods),
    'topComplexFiles': fileMetrics.take(10).toList(),
    'totalWarnings': 0,
    'totalTodos': totalTodos,
  };

  print(jsonEncode(report));
}

double _calculateScore(int loc, int complexity, int methods) {
  if (loc == 0 || methods == 0) return 100.0;
  final avgComplexityPerMethod = complexity / methods;
  double score = 100.0 - (avgComplexityPerMethod * 5.0);
  if (score < 0) score = 0;
  return double.parse(score.toStringAsFixed(2));
}
''';
  }
}

/// Analyzer Service Provider
final analyzerServiceProvider = Provider<AnalyzerService>((ref) {
  final ssh = ref.watch(sshServiceProvider);
  return AnalyzerService(ssh, ref);
});

/// Analysis Report Provider
final analysisReportProvider = FutureProvider<AnalysisReport?>((ref) async {
  final service = ref.watch(analyzerServiceProvider);
  return service.analyzeProject();
});
