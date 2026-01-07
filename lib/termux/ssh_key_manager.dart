import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages SSH key pair for Termux authentication.
///
/// Strategy: Generate keys IN Termux using ssh-keygen, then read and store
/// the private key securely on the Android side. This avoids complex in-app
/// crypto and leverages Termux's native OpenSSH.
class SSHKeyManager {
  static const _privateKeyKey = 'termux_ssh_private_key';
  static const _publicKeyKey = 'termux_ssh_public_key';
  static const _keyGenerated = 'termux_ssh_key_generated';

  final FlutterSecureStorage _storage;

  // Cached key pair to avoid repeated storage reads
  List<SSHKeyPair>? _cachedKeyPairs;
  String? _cachedPublicKey;

  SSHKeyManager({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  /// Check if SSH keys have been set up
  Future<bool> hasKeys() async {
    final privateKey = await _storage.read(key: _privateKeyKey);
    return privateKey != null && privateKey.isNotEmpty;
  }

  /// Generate the command to create SSH keys in Termux
  /// This command should be executed via TermuxBridge
  String getKeyGenerationCommand() {
    return '''
# Generate Ed25519 key pair for IDE authentication
mkdir -p ~/.ssh && \\
chmod 700 ~/.ssh && \\
ssh-keygen -t ed25519 -f ~/.ssh/termux_ide_key -N "" -q && \\
cat ~/.ssh/termux_ide_key.pub >> ~/.ssh/authorized_keys && \\
chmod 600 ~/.ssh/authorized_keys && \\
sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys && \\
echo "TERMUX_IDE_KEY_START" && \\
cat ~/.ssh/termux_ide_key && \\
echo "TERMUX_IDE_KEY_END" && \\
echo "TERMUX_IDE_PUBKEY_START" && \\
cat ~/.ssh/termux_ide_key.pub && \\
echo "TERMUX_IDE_PUBKEY_END"
''';
  }

  /// Parse the key generation output and store keys
  Future<bool> parseAndStoreKeys(String output) async {
    try {
      // Extract private key
      final privateKeyMatch = RegExp(
        r'TERMUX_IDE_KEY_START\n(.*?)\nTERMUX_IDE_KEY_END',
        dotAll: true,
      ).firstMatch(output);

      // Extract public key
      final publicKeyMatch = RegExp(
        r'TERMUX_IDE_PUBKEY_START\n(.*?)\nTERMUX_IDE_PUBKEY_END',
        dotAll: true,
      ).firstMatch(output);

      if (privateKeyMatch == null || publicKeyMatch == null) {
        print('SSHKeyManager: Failed to parse keys from output');
        return false;
      }

      final privateKey = privateKeyMatch.group(1)!.trim();
      final publicKey = publicKeyMatch.group(1)!.trim();

      // Validate private key format
      if (!privateKey.contains('-----BEGIN') ||
          !privateKey.contains('-----END')) {
        print('SSHKeyManager: Invalid private key format');
        return false;
      }

      // Store securely
      await _storage.write(key: _privateKeyKey, value: privateKey);
      await _storage.write(key: _publicKeyKey, value: publicKey);
      await _storage.write(key: _keyGenerated, value: 'true');

      // Clear cache to force reload
      _cachedKeyPairs = null;
      _cachedPublicKey = null;

      print('SSHKeyManager: Keys stored successfully');
      return true;
    } catch (e) {
      print('SSHKeyManager: Error parsing/storing keys: $e');
      return false;
    }
  }

  /// Get the key pairs for SSH authentication
  /// Returns a list since SSHClient.identities expects List<SSHKeyPair>
  Future<List<SSHKeyPair>> getKeyPairs() async {
    if (_cachedKeyPairs != null) return _cachedKeyPairs!;

    final privatePem = await _storage.read(key: _privateKeyKey);
    if (privatePem == null || privatePem.isEmpty) {
      print('SSHKeyManager: No private key found');
      return [];
    }

    try {
      final keyPairs = SSHKeyPair.fromPem(privatePem);
      _cachedKeyPairs = keyPairs;
      return _cachedKeyPairs!;
    } catch (e) {
      print('SSHKeyManager: Failed to parse private key: $e');
      return [];
    }
  }

  /// Get the public key in OpenSSH authorized_keys format
  Future<String?> getPublicKey() async {
    if (_cachedPublicKey != null) return _cachedPublicKey;

    _cachedPublicKey = await _storage.read(key: _publicKeyKey);
    return _cachedPublicKey;
  }

  /// Delete stored keys (for regeneration or cleanup)
  Future<void> deleteKeys() async {
    await _storage.delete(key: _privateKeyKey);
    await _storage.delete(key: _publicKeyKey);
    await _storage.delete(key: _keyGenerated);
    _cachedKeyPairs = null;
    _cachedPublicKey = null;
    print('SSHKeyManager: Keys deleted');
  }

  /// Check if key generation was previously attempted
  Future<bool> wasKeyGenerationAttempted() async {
    final generated = await _storage.read(key: _keyGenerated);
    return generated == 'true';
  }
}
