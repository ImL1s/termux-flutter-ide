import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized paths for Termux environment
/// Based on termux_integration_guide.md and install_termux_flutter.sh
class TermuxPaths {
  static const String prefix = '/data/data/com.termux/files';
  static const String usr = '$prefix/usr';
  static const String bin = '$usr/bin';
  static const String home = '$prefix/home';

  // Flutter/Dart specific paths
  // Installation dir usually in $home/flutter or $usr/opt/flutter
  static String get flutterHome => '$home/.termux_ide/flutter';

  static String get flutterBin => '$flutterHome/bin';
  static String get flutterExecutable => '$flutterBin/flutter';

  static String get dartSdk => '$flutterBin/cache/dart-sdk';
  static String get dartBin => '$dartSdk/bin';
  static String get dartExecutable => '$dartBin/dart';

  static String get snapshots => '$dartBin/snapshots';
  static String get analysisServerSnapshot =>
      '$snapshots/analysis_server.dart.snapshot';
}

final termuxPathsProvider = Provider((ref) => TermuxPaths());
