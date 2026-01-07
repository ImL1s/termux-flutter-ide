import 'package:dartssh2/dartssh2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:termux_flutter_ide/settings/settings_providers.dart';
import 'termux_bridge.dart';
import 'ssh_key_manager.dart';

/// SSH 連線憑證
class SSHCredentials {
  final List<SSHKeyPair> keyPairs;
  final String password;

  SSHCredentials({
    required this.keyPairs,
    required this.password,
  });

  bool get hasKeys => keyPairs.isNotEmpty;
}

/// 統一的 SSH 連線工廠
///
/// 負責：
/// - 解析 Termux username
/// - 管理認證憑證（金鑰 + 密碼）
/// - 創建已配置的 SSHClient
///
/// 這消除了 SSHService 和 TerminalSession 之間的重複邏輯
class SSHConnectionFactory {
  final TermuxBridge _bridge;
  final SSHKeyManager _keyManager;

  /// 統一的密碼常數
  static const defaultPassword = 'termux';

  /// 快取的 username
  String? _cachedUsername;

  SSHConnectionFactory(this._bridge, this._keyManager);

  /// 解析 Termux UID 並轉換為用戶名
  ///
  /// 優先順序：
  /// 1. 用戶手動設定的 username
  /// 2. 從 Termux UID 計算 (u0_a{uid-10000})
  /// 3. 預設值 u0_a251
  Future<String> resolveUsername() async {
    // 使用快取避免重複解析
    if (_cachedUsername != null) return _cachedUsername!;

    // 1. 檢查用戶手動設定的 username
    String? username;
    try {
      final prefs = await SharedPreferences.getInstance();
      username = prefs.getString(kTermuxUsernameKey);
      if (username != null && username.isNotEmpty) {
        print('SSHConnectionFactory: Using stored username: $username');
        _cachedUsername = username;
        return username;
      }
    } catch (e) {
      print('SSHConnectionFactory: Failed to read stored username: $e');
    }

    // 2. 從 UID 計算
    username = 'u0_a251'; // 預設值
    try {
      print('SSHConnectionFactory: Resolving Termux username via UID...');
      final uid = await _bridge.getTermuxUid();
      if (uid != null && uid >= 10000) {
        username = 'u0_a${uid - 10000}';
        print(
            'SSHConnectionFactory: Calculated username from UID ($uid) -> $username');
      } else {
        print(
            'SSHConnectionFactory: getTermuxUid returned null, using fallback: $username');
      }
    } catch (e) {
      print(
          'SSHConnectionFactory: Failed to get UID: $e, using fallback: $username');
    }

    _cachedUsername = username;
    return username!;
  }

  /// 取得認證憑證 (金鑰 + 密碼)
  Future<SSHCredentials> getCredentials() async {
    final keyPairs = await _keyManager.getKeyPairs();
    return SSHCredentials(
      keyPairs: keyPairs,
      password: defaultPassword,
    );
  }

  /// 建立已配置的 SSHClient
  ///
  /// 自動處理：
  /// - Username 解析
  /// - 金鑰認證（優先）
  /// - 密碼認證（備援）
  /// - keyboard-interactive 認證
  Future<SSHClient> createClient(SSHSocket socket) async {
    final username = await resolveUsername();
    final credentials = await getCredentials();

    if (credentials.hasKeys) {
      print('SSHConnectionFactory: Using key-based authentication (primary)');
    } else {
      print('SSHConnectionFactory: No SSH key found, using password auth only');
    }

    return SSHClient(
      socket,
      username: username,
      identities: credentials.keyPairs,
      // Keep connection alive during long-running commands (e.g., Flutter installation)
      keepAliveInterval: const Duration(seconds: 10),
      onPasswordRequest: () => credentials.password,
      onUserInfoRequest: (request) async {
        print(
            'SSHConnectionFactory: Handling keyboard-interactive (prompts: ${request.prompts.length})');
        return request.prompts.map((_) => credentials.password).toList();
      },
    );
  }

  /// 清除快取的 username（用於用戶修改設定後）
  void clearCache() {
    _cachedUsername = null;
  }
}
