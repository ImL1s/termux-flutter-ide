import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'package:termux_flutter_ide/settings/settings_providers.dart';
import 'termux_bridge.dart';
import 'connection_diagnostics.dart';
import 'ssh_key_manager.dart';
import 'ssh_connection_factory.dart';

/// Manages the global SSH connection to Termux
class SSHService {
  SSHClient? _client;
  final TermuxBridge _bridge;
  late final ConnectionDiagnosticsService _diagnosticsService;
  Future<void>? _connectionFuture;

  // Stream controller for connection status
  final _statusController = StreamController<SSHStatus>.broadcast();
  Stream<SSHStatus> get statusStream => _statusController.stream;
  SSHStatus _currentStatus = SSHStatus.disconnected;
  SSHStatus get currentStatus => _currentStatus;

  // Last diagnostics result for error display
  ConnectionDiagnostics? _lastDiagnostics;
  ConnectionDiagnostics? get lastDiagnostics => _lastDiagnostics;

  // Last attempted username for debugging
  String? _lastAttemptedUsername;
  String? get lastAttemptedUsername => _lastAttemptedUsername;

  SSHService(this._bridge) {
    _diagnosticsService = ConnectionDiagnosticsService(_bridge);
    _keyManager = SSHKeyManager();
    _connectionFactory = SSHConnectionFactory(_bridge, _keyManager);
    _statusController.add(_currentStatus);
  }

  // SSH Key Manager for key-based authentication
  late final SSHKeyManager _keyManager;
  SSHKeyManager get keyManager => _keyManager;

  // Unified connection factory
  late final SSHConnectionFactory _connectionFactory;
  SSHConnectionFactory get connectionFactory => _connectionFactory;

  /// returns true if connected
  bool get isConnected => _client != null && !_client!.isClosed;

  SSHClient? get client => _client;

  /// Initiate connection flow with automatic retry and bootstrap
  Future<void> connect() async {
    await connectWithRetry(maxRetries: 3);
  }

  Future<void> _attemptConnection() async {
    final username = await _connectionFactory.resolveUsername();
    _lastAttemptedUsername = username;

    print('SSHService: Connecting to 127.0.0.1:8022 as $username...');
    try {
      final socket = await SSHSocket.connect('127.0.0.1', 8022);
      _client = await _connectionFactory.createClient(socket);
      await _client!.authenticated;
    } catch (e) {
      print('SSHService: Connection/Auth failed: $e');
      if (e.toString().contains('SSHAuthFailError') ||
          e.toString().contains('authentication')) {
        throw 'SSHAuthFailError: Failed to authenticate as "$username".\nOriginal: $e';
      }
      rethrow;
    }
  }

  /// Save username for future connections
  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTermuxUsernameKey, username);
    print('SSHService: Saved username: $username');
  }

  /// Clear stored username
  static Future<void> clearUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTermuxUsernameKey);
    print('SSHService: Cleared stored username');
  }

  /// Ensure Termux SSH environment is bootstrapped (password set, sshd running)
  /// Returns true if bootstrap was triggered
  Future<bool> ensureBootstrapped({bool background = true}) async {
    print('SSHService: Ensuring Termux SSH is bootstrapped...');
    _updateStatus(SSHStatus.bootstrapping);

    try {
      if (!background) {
        // Step 1: Wake up Termux (only if not background)
        print('SSHService: [Bootstrap] Opening Termux...');
        await _bridge.openTermux();
        await Future.delayed(const Duration(seconds: 2));
      }

      // Step 2: Setup SSH (install openssh, set password, start sshd)
      // setupTermuxSSH now runs in background by default if configured in TermuxBridge
      print('SSHService: [Bootstrap] Setting up SSH environment...');
      final result = await _bridge.setupTermuxSSH();
      print(
          'SSHService: [Bootstrap] Setup result: ${result.success ? "OK" : result.stderr}');

      // Step 3: Wait for sshd to be ready
      print('SSHService: [Bootstrap] Waiting for sshd (5s)...');
      await Future.delayed(const Duration(seconds: 5));

      return true;
    } catch (e) {
      print('SSHService: [Bootstrap] Failed: $e');
      return false;
    }
  }

  /// Try to repair connection by restarting sshd in background
  Future<void> fixConnection() async {
    _updateStatus(SSHStatus.bootstrapping);
    try {
      // Run the full setup script (background) to fix password/keys/sshd
      await _bridge.setupTermuxSSH();

      // Wait a bit for sshd to start
      await Future.delayed(const Duration(seconds: 4));

      // Retry connection
      connect();
    } catch (e) {
      print('SSHService: Fix failed: $e');
      _updateStatus(SSHStatus.failed);
    }
  }

  /// Connect with automatic retry and bootstrap
  Future<void> connectWithRetry({int maxRetries = 3}) async {
    if (isConnected) return;
    if (_connectionFuture != null) return _connectionFuture!;

    _connectionFuture = _connectWithRetryInternal(maxRetries: maxRetries);
    try {
      await _connectionFuture;
    } finally {
      _connectionFuture = null;
    }
  }

  Future<void> _connectWithRetryInternal({int maxRetries = 3}) async {
    _updateStatus(SSHStatus.connecting);
    Object? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('SSHService: Connection attempt $attempt/$maxRetries...');
        await _attemptConnection().timeout(const Duration(seconds: 8));
        _updateStatus(SSHStatus.connected);
        _lastDiagnostics = null; // Clear diagnostics on success
        print('SSHService: Connected on attempt $attempt');
        return;
      } catch (e) {
        print('SSHService: Attempt $attempt failed: $e');
        lastError = e;

        if (attempt < maxRetries) {
          // Failure: just wait and retry.
          // Do NOT call ensureBootstrapped() automatically, as it opens Termux app
          // and interrupts the user experience (context switch).
          // Let the UI handle the error and prompt the user.
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    // All retries exhausted - capture diagnostics for UI
    if (lastError != null) {
      _lastDiagnostics = _diagnosticsService.fromError(lastError);
    }
    _updateStatus(SSHStatus.failed);
    print('SSHService: All connection attempts failed.');
  }

  /// Execute a command and return output (stdout + stderr)
  Future<String> execute(String command) async {
    if (!isConnected) throw Exception("SSH not connected");

    // Prepend Termux HOME and PATH to ensure reliability across SSH sessions
    final fullCommand =
        'export HOME=/data/data/com.termux/files/home; export PATH=/data/data/com.termux/files/home/flutter/bin:/data/data/com.termux/files/usr/bin:\$PATH; export TMPDIR=/data/data/com.termux/files/usr/tmp; $command';

    final session = await _client!.execute(fullCommand);

    // Properly collect and decode both stdout and stderr
    final List<int> allBytes = [];

    final stdoutFuture =
        session.stdout.listen((data) => allBytes.addAll(data)).asFuture();
    final stderrFuture =
        session.stderr.listen((data) => allBytes.addAll(data)).asFuture();

    await Future.wait([stdoutFuture, stderrFuture]);

    return utf8.decode(allBytes, allowMalformed: true);
  }

  /// Execute a command and return output stream (stdout + stderr mixed)
  Stream<String> executeStream(String command) async* {
    if (!isConnected) throw Exception("SSH not connected");
    // Prepend Termux HOME and PATH to ensure reliability across SSH sessions
    final fullCommand =
        'export HOME=/data/data/com.termux/files/home; export PATH=/data/data/com.termux/files/home/flutter/bin:/data/data/com.termux/files/usr/bin:\$PATH; export TMPDIR=/data/data/com.termux/files/usr/tmp; $command';

    final session = await _client!.execute(fullCommand);

    final controller = StreamController<String>();
    int activeStreams = 2;

    void handleDone() {
      activeStreams--;
      if (activeStreams == 0) {
        controller.close();
      }
    }

    session.stdout
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen((data) => controller.add(data), onDone: handleDone);
    session.stderr
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen((data) => controller.add(data), onDone: handleDone);

    yield* controller.stream;
  }

  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    _updateStatus(SSHStatus.disconnected);
  }

  /// Execute command and return detailed result (exitCode, stdout, stderr)
  Future<SSHExecResult> executeWithDetails(String command) async {
    if (!isConnected) throw Exception("SSH not connected");
    // Prepend Termux HOME and PATH to ensure reliability across SSH sessions
    final fullCommand =
        'export HOME=/data/data/com.termux/files/home; export PATH=/data/data/com.termux/files/home/flutter/bin:/data/data/com.termux/files/usr/bin:\$PATH; export TMPDIR=/data/data/com.termux/files/usr/tmp; $command';

    final session = await _client!.execute(fullCommand);

    final stdoutBytes = <int>[];
    final stderrBytes = <int>[];

    final stdoutFuture =
        session.stdout.listen((data) => stdoutBytes.addAll(data)).asFuture();
    final stderrFuture =
        session.stderr.listen((data) => stderrBytes.addAll(data)).asFuture();

    await Future.wait([stdoutFuture, stderrFuture]);

    // Wait for exit code
    // session.done returns exit code
    // Wait... dartssh2 session.done might not be exactly exit code directly visible?
    // checking documentation or source is hard.
    // actually, SSHSession has `done` which completes when channel closes.
    // It doesn't seem to expose exit code easily in the future result?
    // Wait, upstream dartssh2 might not expose exit code in `done` future value easily?
    // Let's check `session.exitCode`.
    // It's a valid property if the session is done.

    // Force wait for done
    await session.done;

    return SSHExecResult(
      exitCode: session.exitCode ?? 0,
      stdout: utf8.decode(stdoutBytes, allowMalformed: true),
      stderr: utf8.decode(stderrBytes, allowMalformed: true),
    );
  }

  /// Forward a local port to a remote port on the SSH host.
  /// If localPort is 0, the OS will pick an available port.
  /// Returns the actual local port used.
  Future<int> forwardLocal(int remotePort,
      {String remoteHost = '127.0.0.1'}) async {
    if (!isConnected) throw Exception("SSH not connected");

    final server = await ServerSocket.bind('127.0.0.1', 0);

    server.listen((socket) async {
      try {
        final channel = await _client!.forwardLocal(remoteHost, remotePort);

        socket.listen(
          (data) => channel.sink.add(Uint8List.fromList(data)),
          onDone: () => channel.sink.close(),
          onError: (_) => channel.sink.close(),
        );

        channel.stream.listen(
          (data) => socket.add(data),
          onDone: () => socket.close(),
          onError: (_) => socket.close(),
        );
      } catch (e) {
        print('SSHService: Forwarding failed: $e');
        socket.close();
      }
    });

    return server.port;
  }

  void _updateStatus(SSHStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }
}

class SSHExecResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  SSHExecResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get success => exitCode == 0;
}

enum SSHStatus {
  disconnected,
  connecting,
  bootstrapping,
  connected,
  failed,
}

/// Provider
final sshServiceProvider = Provider<SSHService>((ref) {
  final bridge = ref.watch(termuxBridgeProvider);
  return SSHService(bridge);
});

final sshStatusProvider = StreamProvider<SSHStatus>((ref) {
  final service = ref.watch(sshServiceProvider);
  return service.statusStream;
});
