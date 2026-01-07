import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'termux_bridge.dart';
import 'termux_providers.dart';

/// Diagnostic result severity
enum DiagnosticSeverity { ok, warning, error }

/// Specific error types for targeted guidance
enum ConnectionErrorType {
  none,
  termuxNotInstalled,
  permissionDenied,
  sshdNotRunning,
  authenticationFailed,
  connectionTimeout,
  phantomProcessKiller, // Android 12+ signal 9
  unknownError,
}

/// Comprehensive connection diagnostics result
class ConnectionDiagnostics {
  final bool termuxInstalled;
  final bool sshdResponding;
  final bool authenticationValid;
  final String? detectedUsername;
  final int? termuxUid;
  final ConnectionErrorType errorType;
  final String? rawErrorMessage;
  final DateTime timestamp;

  const ConnectionDiagnostics({
    required this.termuxInstalled,
    required this.sshdResponding,
    required this.authenticationValid,
    this.detectedUsername,
    this.termuxUid,
    this.errorType = ConnectionErrorType.none,
    this.rawErrorMessage,
    required this.timestamp,
  });

  /// Overall status
  DiagnosticSeverity get severity {
    if (!termuxInstalled) return DiagnosticSeverity.error;
    if (!sshdResponding) return DiagnosticSeverity.error;
    if (!authenticationValid) return DiagnosticSeverity.warning;
    return DiagnosticSeverity.ok;
  }

  /// User-friendly error title
  String get errorTitle {
    switch (errorType) {
      case ConnectionErrorType.none:
        return '連線正常';
      case ConnectionErrorType.termuxNotInstalled:
        return 'Termux 未安裝';
      case ConnectionErrorType.permissionDenied:
        return '權限被拒絕';
      case ConnectionErrorType.sshdNotRunning:
        return 'SSH 服務未啟動';
      case ConnectionErrorType.authenticationFailed:
        return '密碼驗證失敗';
      case ConnectionErrorType.connectionTimeout:
        return '連線逾時';
      case ConnectionErrorType.phantomProcessKiller:
        return 'Phantom Process Killer (進程被終止)';
      case ConnectionErrorType.unknownError:
        return '未知錯誤';
    }
  }

  /// Detailed user-friendly explanation
  String get explanation {
    switch (errorType) {
      case ConnectionErrorType.none:
        return '已成功連線到 Termux SSH 服務。';
      case ConnectionErrorType.termuxNotInstalled:
        return 'IDE 需要 Termux 應用程式才能運作。請從 F-Droid 安裝 Termux。';
      case ConnectionErrorType.permissionDenied:
        return 'Termux 未授權給外部應用程式執行指令。需要在 Termux 中啟用此權限。';
      case ConnectionErrorType.sshdNotRunning:
        return 'SSH 服務 (sshd) 未在 Termux 中執行。需要安裝 OpenSSH 並啟動服務。';
      case ConnectionErrorType.authenticationFailed:
        return 'SSH 密碼不正確。IDE 使用 "termux" 作為預設密碼，請在 Termux 中重設密碼。';
      case ConnectionErrorType.connectionTimeout:
        return 'Termux 可能處於休眠狀態或未在背景執行。請開啟 Termux 並取得 WakeLock。';
      case ConnectionErrorType.phantomProcessKiller:
        return 'Android 12+ 的 Phantom Process Killer 終止了 Termux 進程 (signal 9)。需要停用此功能。';
      case ConnectionErrorType.unknownError:
        return '發生未預期的錯誤。請查看詳細錯誤訊息或嘗試完整修復指令。';
    }
  }

  /// One-line fix command for this specific error
  String get fixCommand {
    switch (errorType) {
      case ConnectionErrorType.none:
        return '';
      case ConnectionErrorType.termuxNotInstalled:
        return '# 請從 F-Droid 安裝 Termux';
      case ConnectionErrorType.permissionDenied:
        return 'echo "allow-external-apps=true" >> ~/.termux/termux.properties && termux-reload-settings';
      case ConnectionErrorType.sshdNotRunning:
        return 'pkg install -y openssh && ssh-keygen -A && sshd';
      case ConnectionErrorType.authenticationFailed:
        // Use the full fix command because auth failure can be due to:
        // 1. Password disabled in config (requires config rewrite)
        // 2. Wrong password (requires passwd)
        // 3. User mismatch (requires correct user/passwd combo)
        // The full fix handles all of these aggressively.
        return _fullFixCommand;
      case ConnectionErrorType.connectionTimeout:
        return 'termux-wake-lock';
      case ConnectionErrorType.phantomProcessKiller:
        return '# 設定 → 開發者選項 → 停用子程序限制';
      case ConnectionErrorType.unknownError:
        return _fullFixCommand;
    }
  }

  /// Complete fix command that handles all scenarios
  static const String _fullFixCommand =
      // 1. Ensure external apps allowed
      'grep -q "allow-external-apps=true" ~/.termux/termux.properties 2>/dev/null || '
      'echo "allow-external-apps=true" >> ~/.termux/termux.properties; '
      'termux-reload-settings; '
      // 2. Install/Reinstall OpenSSH
      'pkg install -y openssh; '
      // 3. NUCLEAR OPTION: Overwrite sshd_config with known good state
      // We explicitly enable EVERYTHING to ensure connection works
      'echo "Port 8022" > \$PREFIX/etc/ssh/sshd_config; '
      'echo "ListenAddress 127.0.0.1" >> \$PREFIX/etc/ssh/sshd_config; '
      'echo "PermitRootLogin yes" >> \$PREFIX/etc/ssh/sshd_config; '
      'echo "PasswordAuthentication yes" >> \$PREFIX/etc/ssh/sshd_config; '
      'echo "ChallengeResponseAuthentication yes" >> \$PREFIX/etc/ssh/sshd_config; '
      'echo "PubkeyAuthentication yes" >> \$PREFIX/etc/ssh/sshd_config; '
      'echo "Subsystem sftp \$PREFIX/libexec/sftp-server" >> \$PREFIX/etc/ssh/sshd_config; '
      'echo "PrintMotd yes" >> \$PREFIX/etc/ssh/sshd_config; '
      // 4. Generate Host Keys
      'ssh-keygen -A; '
      // 5. Hard Reset Password
      'printf "termux\\ntermux\\n" | passwd; '
      // 6. Ensure WakeLock
      'termux-wake-lock; '
      // 7. Restart SSHD (Kill all instances first)
      'pkill sshd; sleep 1; sshd';

  /// Get the full fix command (static access)
  static String get fullFixCommand => _fullFixCommand;

  /// Whether a fix can be attempted automatically
  bool get canAutoFix {
    return errorType == ConnectionErrorType.sshdNotRunning ||
        errorType == ConnectionErrorType.connectionTimeout;
  }

  /// Whether manual intervention is required
  bool get requiresManualAction {
    return errorType == ConnectionErrorType.termuxNotInstalled ||
        errorType == ConnectionErrorType.permissionDenied ||
        errorType == ConnectionErrorType.authenticationFailed;
  }
}

/// Service to perform connection diagnostics
class ConnectionDiagnosticsService {
  final TermuxBridge _bridge;

  ConnectionDiagnosticsService(this._bridge);

  /// Run full diagnostics
  Future<ConnectionDiagnostics> runDiagnostics() async {
    final timestamp = DateTime.now();

    // Step 1: Check if Termux is installed
    final termuxInstalled = await _bridge.isTermuxInstalled();
    if (!termuxInstalled) {
      return ConnectionDiagnostics(
        termuxInstalled: false,
        sshdResponding: false,
        authenticationValid: false,
        errorType: ConnectionErrorType.termuxNotInstalled,
        timestamp: timestamp,
      );
    }

    // Step 2: Get Termux UID for username calculation
    int? uid;
    String? username;
    try {
      uid = await _bridge.getTermuxUid();
      if (uid != null) {
        username = 'u0_a${uid - 10000}';
      }
    } catch (e) {
      // UID retrieval failed, will use fallback
    }

    // Step 3: Try to connect to SSH
    // We can't directly test SSH from here without the SSH service,
    // so we return a partial result that will be completed by SSHService
    return ConnectionDiagnostics(
      termuxInstalled: true,
      sshdResponding: true, // Will be updated by actual connection attempt
      authenticationValid: true, // Will be updated by actual connection attempt
      detectedUsername: username,
      termuxUid: uid,
      errorType: ConnectionErrorType.none,
      timestamp: timestamp,
    );
  }

  /// Create diagnostics from a connection error
  ConnectionDiagnostics fromError(Object error, {int? uid, String? username}) {
    final errorString = error.toString();
    ConnectionErrorType errorType;

    if (errorString.contains('Connection refused')) {
      errorType = ConnectionErrorType.sshdNotRunning;
    } else if (errorString.contains('SSHAuthFailError') ||
        errorString.contains('authentication') ||
        errorString.contains('Auth')) {
      errorType = ConnectionErrorType.authenticationFailed;
    } else if (errorString.contains('timeout') ||
        errorString.contains('Timeout') ||
        errorString.contains('timed out')) {
      errorType = ConnectionErrorType.connectionTimeout;
    } else if (errorString.contains('permission') ||
        errorString.contains('Permission')) {
      errorType = ConnectionErrorType.permissionDenied;
    } else {
      errorType = ConnectionErrorType.unknownError;
    }

    return ConnectionDiagnostics(
      termuxInstalled: true,
      sshdResponding: errorType != ConnectionErrorType.sshdNotRunning,
      authenticationValid:
          errorType != ConnectionErrorType.authenticationFailed,
      detectedUsername: username,
      termuxUid: uid,
      errorType: errorType,
      rawErrorMessage: errorString,
      timestamp: DateTime.now(),
    );
  }
}

/// Provider for diagnostics service
final connectionDiagnosticsServiceProvider =
    Provider<ConnectionDiagnosticsService>((ref) {
  final bridge = ref.watch(termuxBridgeProvider);
  return ConnectionDiagnosticsService(bridge);
});

/// Provider for current diagnostics state
final connectionDiagnosticsProvider =
    StateProvider<ConnectionDiagnostics?>((ref) => null);
