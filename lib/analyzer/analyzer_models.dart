import 'dart:convert';

class FileMetric {
  final String path;
  final int loc; // Lines of code
  final int methodCount;
  final int averageComplexity;
  final List<String> antiPatterns;

  FileMetric({
    required this.path,
    required this.loc,
    required this.methodCount,
    required this.averageComplexity,
    this.antiPatterns = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'loc': loc,
      'methodCount': methodCount,
      'averageComplexity': averageComplexity,
      'antiPatterns': antiPatterns,
    };
  }

  factory FileMetric.fromMap(Map<String, dynamic> map) {
    return FileMetric(
      path: map['path'] ?? '',
      loc: map['loc'] ?? 0,
      methodCount: map['methodCount'] ?? 0,
      averageComplexity: map['averageComplexity'] ?? 0,
      antiPatterns: List<String>.from(map['antiPatterns'] ?? []),
    );
  }
}

class AnalysisReport {
  final DateTime timestamp;
  final int totalLoc;
  final double maintainabilityScore; // 0-100
  final List<FileMetric> topComplexFiles;
  final int totalWarnings;
  final int totalTodos;

  AnalysisReport({
    required this.timestamp,
    required this.totalLoc,
    required this.maintainabilityScore,
    required this.topComplexFiles,
    required this.totalWarnings,
    required this.totalTodos,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'totalLoc': totalLoc,
      'maintainabilityScore': maintainabilityScore,
      'topComplexFiles': topComplexFiles.map((x) => x.toMap()).toList(),
      'totalWarnings': totalWarnings,
      'totalTodos': totalTodos,
    };
  }

  factory AnalysisReport.fromMap(Map<String, dynamic> map) {
    return AnalysisReport(
      timestamp:
          DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      totalLoc: map['totalLoc'] ?? 0,
      maintainabilityScore: (map['maintainabilityScore'] ?? 0).toDouble(),
      topComplexFiles: (map['topComplexFiles'] as List? ?? [])
          .map((x) => FileMetric.fromMap(x))
          .toList(),
      totalWarnings: map['totalWarnings'] ?? 0,
      totalTodos: map['totalTodos'] ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory AnalysisReport.fromJson(String source) =>
      AnalysisReport.fromMap(json.decode(source));
}
