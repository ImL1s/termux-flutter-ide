import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized paths for Termux environment
/// Based on termux_integration_guide.md and install_termux_flutter.sh
class TermuxPaths {
  static const String prefix = '/data/data/com.termux/files';
  static const String usr = '$prefix/usr';
  static const String bin = '$usr/bin';
  static const String home = '$prefix/home';

  // Flutter/Dart specific paths
  // Installation dir usually in $usr/opt/flutter
  static const String flutterHome = '$usr/opt/flutter';
  static const String flutterBin = '$flutterHome/bin';
  static const String flutterExecutable = '$flutterBin/flutter';

  static const String dartSdk = '$flutterBin/cache/dart-sdk';
  static const String dartBin = '$dartSdk/bin';
  static const String dartExecutable = '$dartBin/dart';

  static const String snapshots = '$dartBin/snapshots';
  static const String analysisServerSnapshot =
      '$snapshots/analysis_server.dart.snapshot';
}

final termuxPathsProvider = Provider((ref) => TermuxPaths());
