import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'termux_bridge.dart';

/// Manages the global SSH connection to Termux
class SSHService {
  SSHClient? _client;
  final TermuxBridge _bridge;

  // Stream controller for connection status
  final _statusController = StreamController<SSHStatus>.broadcast();
  Stream<SSHStatus> get statusStream => _statusController.stream;
  SSHStatus _currentStatus = SSHStatus.disconnected;
  SSHStatus get currentStatus => _currentStatus;

  SSHService(this._bridge) {
    _statusController.add(_currentStatus);
  }

  /// returns true if connected
  bool get isConnected => _client != null && !_client!.isClosed;

  SSHClient? get client => _client;

  /// Initiate connection flow
  Future<void> connect() async {
    if (isConnected) return;

    _updateStatus(SSHStatus.connecting);
    print('SSHService: Initiating connection...');

    try {
      await _attemptConnection().timeout(const Duration(seconds: 5));
      _updateStatus(SSHStatus.connected);
      print('SSHService: Connected successfully on first try');
    } catch (e) {
      print(
          'SSHService: Initial connection failed ($e). Starting bootstrap...');
      _updateStatus(SSHStatus.bootstrapping);

      // Auto-Bootstrap: First, wake up Termux by opening its main activity
      try {
        print('SSHService: Opening Termux to wake it up...');
        await _bridge.openTermux();

        // Wait for Termux to fully start
        await Future.delayed(const Duration(seconds: 3));

        // Now send the SSH setup command
        print('SSHService: Sending SSH setup command...');
        await _bridge.setupTermuxSSH();

        // Wait for SSHD to start
        print('SSHService: Waiting for SSHD...');
        await Future.delayed(const Duration(seconds: 8));

        // Retry
        print('SSHService: Retrying connection...');
        await _attemptConnection().timeout(const Duration(seconds: 10));
        _updateStatus(SSHStatus.connected);
        print('SSHService: Connected successfully after bootstrap');
      } catch (e2) {
        print('SSHService: Connection/Bootstrap failed: $e2');
        _updateStatus(SSHStatus.failed);
        // Do not rethrow here to prevent app crash at startup.
        // The UI should handle the failed status.
      }
    }
  }

  Future<void> _attemptConnection() async {
    final uid = await _bridge.getTermuxUid();
    final username = uid != null ? 'u0_a${uid - 10000}' : 'u0_a251'; // Fallback

    print('SSHService: Connecting to 127.0.0.1:8022 as $username...');
    final socket = await SSHSocket.connect('127.0.0.1', 8022);
    _client = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => 'termux',
    );

    await _client!.authenticated;
  }

  /// Execute a command and return output (stdout + stderr)
  Future<String> execute(String command) async {
    if (!isConnected) throw Exception("SSH not connected");

    final session = await _client!.execute(command);

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

    final session = await _client!.execute(command);

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

  void _updateStatus(SSHStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }
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
