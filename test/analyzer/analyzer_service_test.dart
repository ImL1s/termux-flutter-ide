import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/analyzer/analyzer_service.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';
import 'package:termux_flutter_ide/core/providers.dart';

// Manual Mock for SSHService
class MockSSHService implements SSHService {
  bool isConnectedValue = false;
  String? executeOutput;
  String? lastCommand;
  bool connectCalled = false;

  @override
  bool get isConnected => isConnectedValue;

  @override
  Future<void> connect() async {
    connectCalled = true;
    isConnectedValue = true;
  }

  @override
  Future<String> execute(String command) async {
    lastCommand = command;
    if (executeOutput == null) throw Exception('Command failed');
    return executeOutput!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Simple MockRef that returns a fixed value for projectPathProvider
class MockRef extends Fake implements Ref {
  final String? projectPath;
  MockRef(this.projectPath);

  @override
  T read<T>(ProviderListenable<T> provider) {
    if (provider == projectPathProvider) {
      return projectPath as T;
    }
    throw UnimplementedError();
  }
}

void main() {
  late MockSSHService mockSSH;

  setUp(() {
    mockSSH = MockSSHService();
  });

  group('AnalyzerService', () {
    test('analyzeProject returns null when projectPath is null', () async {
      final service = AnalyzerService(mockSSH, MockRef(null));
      final result = await service.analyzeProject();

      expect(result, isNull);
    });

    test('analyzeProject connects SSH if not connected', () async {
      mockSSH.isConnectedValue = false;
      mockSSH.executeOutput =
          '{"totalLoc": 100, "maintainabilityScore": 90, "topComplexFiles": [], "totalWarnings": 0, "totalTodos": 5}';

      final service = AnalyzerService(mockSSH, MockRef('/test/project'));
      await service.analyzeProject();

      expect(mockSSH.connectCalled, isTrue);
    });

    test('analyzeProject handles invalid JSON gracefully', () async {
      mockSSH.isConnectedValue = true;
      mockSSH.executeOutput = 'invalid-json';

      final service = AnalyzerService(mockSSH, MockRef('/test/project'));
      final result = await service.analyzeProject();

      expect(result, isNull);
    });

    test('analyzeProject parses valid report correctly', () async {
      mockSSH.isConnectedValue = true;
      mockSSH.executeOutput = '''
      {
        "timestamp": "2024-01-01T00:00:00.000Z",
        "totalLoc": 500,
        "maintainabilityScore": 85.5,
        "topComplexFiles": [],
        "totalWarnings": 2,
        "totalTodos": 10
      }
      ''';

      final service = AnalyzerService(mockSSH, MockRef('/test/project'));
      final result = await service.analyzeProject();

      expect(result, isNotNull);
      expect(result!.totalLoc, 500);
      expect(result.maintainabilityScore, 85.5);
    });
  });
}
