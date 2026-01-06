import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers.dart'; // For projectPathProvider
import '../file_manager/file_operations.dart';

/// Represents a launch configuration for running Flutter apps
class LaunchConfiguration {
  final String name;
  final String type; // 'flutter'
  final String request; // 'launch'
  final String? program; // 'lib/main.dart'
  final List<String> args; // ['--flavor', 'dev']
  final Map<String, String> env; // Environment variables
  final String? cwd; // Working directory
  final String? flutterPath; // Custom flutter executable path
  final String? deviceId; // '-d device_id'
  final String? mode; // 'debug', 'profile', 'release'

  const LaunchConfiguration({
    required this.name,
    this.type = 'flutter',
    this.request = 'launch',
    this.program,
    this.args = const [],
    this.env = const {},
    this.cwd,
    this.flutterPath,
    this.deviceId,
    this.mode,
  });

  factory LaunchConfiguration.fromJson(Map<String, dynamic> json) {
    return LaunchConfiguration(
      name: json['name'] as String,
      type: json['type'] as String? ?? 'flutter',
      request: json['request'] as String? ?? 'launch',
      program: json['program'] as String?,
      args:
          (json['args'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      env: (json['env'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
      cwd: json['cwd'] as String?,
      flutterPath: json['flutterPath'] as String?,
      deviceId: json['deviceId'] as String? ??
          json['device'] as String?, // 'device' is alias
      mode: json['mode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'request': request,
      if (program != null) 'program': program,
      if (args.isNotEmpty) 'args': args,
      if (env.isNotEmpty) 'env': env,
      if (cwd != null) 'cwd': cwd,
      if (flutterPath != null) 'flutterPath': flutterPath,
      if (deviceId != null) 'device': deviceId,
      if (mode != null) 'mode': mode,
    };
  }
}

/// Provider for the list of available launch configurations
final launchConfigurationsProvider =
    FutureProvider<List<LaunchConfiguration>>((ref) async {
  final projectPath = ref.watch(projectPathProvider);
  if (projectPath == null) return [];

  final configs = <LaunchConfiguration>[];
  final ops = ref.watch(fileOperationsProvider);
  // We need to access the SSH service status directly to avoid blocking
  // We can't access ref.watch(sshServiceProvider).isConnected easily because of provider scope,
  // but ops.exists() will try to connect.
  // Instead, let's just return defaults if we catch an error or timeout.

  try {
    // 1. Try to load from .termux-ide/launch.json
    // We set a short timeout so we don't block the UI for too long if SSH is slow
    final configPath = '$projectPath/.termux-ide/launch.json';

    // We use a helper to wrap the async check with a timeout
    final hasConfig =
        await ops.exists(configPath).timeout(const Duration(milliseconds: 500));

    if (hasConfig) {
      final content = await ops
          .readFile(configPath)
          .timeout(const Duration(milliseconds: 500));
      if (content != null) {
        final json = jsonDecode(content);
        if (json['configurations'] is List) {
          for (final item in json['configurations']) {
            configs.add(LaunchConfiguration.fromJson(item));
          }
        }
      }
    }

    // 2. Add Auto-Detected Configurations

    // Check for FVM
    if (await ops
        .exists('$projectPath/.fvm/flutter_sdk')
        .timeout(const Duration(milliseconds: 2000), onTimeout: () => false)) {
      configs.add(const LaunchConfiguration(
        name: 'Flutter (FVM)',
        flutterPath: 'fvm flutter',
        args: [],
      ));
    }

    // Check for User Custom Flutter (Standard termux-flutter-wsl path)
    const userFlutterPath =
        '/data/data/com.termux/files/home/flutter/bin/flutter';
    if (await ops
        .exists(userFlutterPath)
        .timeout(const Duration(milliseconds: 2000), onTimeout: () => false)) {
      configs.add(const LaunchConfiguration(
        name: 'Flutter (User)',
        flutterPath: userFlutterPath,
      ));
    }

    // Check for System Flutter (Standard pkg install path)
    const systemFlutterPath = '/data/data/com.termux/files/usr/bin/flutter';
    if (await ops
        .exists(systemFlutterPath)
        .timeout(const Duration(milliseconds: 2000), onTimeout: () => false)) {
      configs.add(const LaunchConfiguration(
        name: 'Flutter (System)',
        flutterPath: systemFlutterPath,
      ));
    }
  } catch (e) {
    print('Error loading specific launch configs: $e');
    // Fallthrough to add default config
  }

  // 3. Always add Default system Flutter if list is empty or just as an option
  // Only add if we don't have it yet (by name)
  if (!configs.any((c) => c.name == 'Flutter (Default)')) {
    configs.add(const LaunchConfiguration(
      name: 'Flutter (Default)',
      flutterPath: 'flutter',
    ));
  }

  return configs;
});

/// Provider for the currently selected configuration
final selectedLaunchConfigProvider =
    NotifierProvider<SelectedLaunchConfigNotifier, LaunchConfiguration?>(
  SelectedLaunchConfigNotifier.new,
);

class SelectedLaunchConfigNotifier extends Notifier<LaunchConfiguration?> {
  @override
  LaunchConfiguration? build() => null;

  void select(LaunchConfiguration? config) {
    state = config;
  }
}

/// Default launch.json template
const String defaultLaunchJsonTemplate = '''{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Flutter (Debug)",
            "request": "launch",
            "type": "flutter",
            "args": []
        },
        {
            "name": "Flutter (Profile)",
            "request": "launch",
            "type": "flutter",
            "mode": "profile"
        },
        {
            "name": "Flutter (Release)",
            "request": "launch",
            "type": "flutter",
            "mode": "release"
        }
    ]
}''';

/// Helper to create default launch.json using specific FileOperations
Future<void> createDefaultLaunchConfig(
    String projectPath, FileOperations ops) async {
  final configDir = '$projectPath/.termux-ide';
  if (!await ops.exists(configDir)) {
    await ops.createDirectory(configDir);
  }

  final configFile = '$configDir/launch.json';
  if (!await ops.exists(configFile)) {
    await ops.writeFile(configFile, defaultLaunchJsonTemplate);
  }
}
