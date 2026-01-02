import 'dart:io';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart';
import '../termux/ssh_service.dart';
import '../termux/termux_paths.dart';

class PubspecService {
  final Ref ref;

  PubspecService(this.ref);

  Future<bool> addDependency(String packageName, String version) async {
    final projectPath = ref.read(projectPathProvider);
    if (projectPath == null) return false;

    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!await pubspecFile.exists()) return false;

    try {
      final content = await pubspecFile.readAsString();
      final editor = YamlEditor(content);

      // Add or update dependency
      // We assume it goes into 'dependencies'
      editor.update(['dependencies', packageName], '^$version');

      await pubspecFile.writeAsString(editor.toString());

      // Trigger pub get
      _triggerPubGet(projectPath);

      return true;
    } catch (e) {
      print('PubspecService error: $e');
      return false;
    }
  }

  void _triggerPubGet(String projectPath) {
    final ssh = ref.read(sshServiceProvider);
    if (ssh.isConnected) {
      // We can use terminalCommandProvider to show it in terminal
      ref
          .read(terminalCommandProvider.notifier)
          .run('cd $projectPath && ${TermuxPaths.flutterExecutable} pub get');
    }
  }
}

final pubspecServiceProvider =
    Provider<PubspecService>((ref) => PubspecService(ref));
