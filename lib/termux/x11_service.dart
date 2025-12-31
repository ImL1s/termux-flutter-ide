import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/ssh_service.dart';

/// X11 installation and runtime state
enum X11State {
  unknown,
  notInstalled,
  installed,
  running,
  error,
}

/// X11 Service for managing Termux X11 environment
class X11Service {
  final SSHService _sshService;

  X11Service(this._sshService);

  /// Check if termux-x11 package is installed
  Future<bool> isInstalled() async {
    if (!_sshService.isConnected) return false;

    try {
      final result = await _sshService.execute('which termux-x11');
      return result.trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if x11-repo is installed
  Future<bool> isX11RepoInstalled() async {
    if (!_sshService.isConnected) return false;

    try {
      final result = await _sshService
          .execute('pkg list-installed 2>/dev/null | grep x11-repo');
      return result.trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if X11 server is running (DISPLAY is set and responding)
  Future<bool> isRunning() async {
    if (!_sshService.isConnected) return false;

    try {
      // Check if termux-x11 process exists
      final result = await _sshService.execute(
          'pgrep -x Xwayland 2>/dev/null || pgrep termux-x11 2>/dev/null');
      return result.trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get comprehensive X11 state
  Future<X11State> getState() async {
    try {
      final installed = await isInstalled();
      if (!installed) return X11State.notInstalled;

      final running = await isRunning();
      if (running) return X11State.running;

      return X11State.installed;
    } catch (e) {
      return X11State.error;
    }
  }

  /// Start termux-x11 server in background
  Future<bool> startX11Server() async {
    if (!_sshService.isConnected) return false;

    try {
      // Start termux-x11 in background
      await _sshService.execute('nohup termux-x11 :0 >/dev/null 2>&1 &');

      // Wait a moment for it to start
      await Future.delayed(const Duration(seconds: 2));

      return await isRunning();
    } catch (e) {
      return false;
    }
  }

  /// Get the flutter run command with proper X11 setup
  String getFlutterRunCommand(
    String flutterPath,
    String projectPath, {
    String? deviceId,
    String? mode,
    List<String>? args,
  }) {
    final buffer = StringBuffer();

    // Set DISPLAY environment variable
    buffer.write('export DISPLAY=:0 && ');

    // Change to project directory
    buffer.write('cd "$projectPath" && ');

    // Flutter command
    buffer.write(flutterPath);
    buffer.write(' run');

    // Device (force linux for X11)
    buffer.write(' -d ${deviceId ?? "linux"}');

    // Mode
    if (mode != null) {
      buffer.write(' --$mode');
    }

    // Additional args
    if (args != null) {
      for (final arg in args) {
        buffer.write(' $arg');
      }
    }

    return buffer.toString();
  }
}

/// Provider for X11 service
final x11ServiceProvider = Provider<X11Service>((ref) {
  final sshService = ref.watch(sshServiceProvider);
  return X11Service(sshService);
});

/// Provider for X11 state (async)
final x11StateProvider = FutureProvider<X11State>((ref) async {
  final x11Service = ref.watch(x11ServiceProvider);
  return await x11Service.getState();
});

/// Installation commands for X11
class X11InstallCommands {
  /// Step 1: Install x11-repo
  static const String installX11Repo = 'pkg install x11-repo -y';

  /// Step 2: Install termux-x11-nightly
  static const String installTermuxX11 = 'pkg install termux-x11-nightly -y';

  /// Combined command
  static const String installAll = '''
pkg install x11-repo -y && \\
pkg install termux-x11-nightly -y
''';

  /// Full setup script including starting the server
  static const String fullSetup = '''
# Install X11 packages
pkg install x11-repo -y
pkg install termux-x11-nightly -y

# Start X11 server (run this before flutter run)
termux-x11 :0 &

# Set DISPLAY for this session
export DISPLAY=:0
''';
}
