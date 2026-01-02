import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';

/// Dialog shown when SSH authentication fails
/// Provides user with clear instructions to fix the issue
class SSHErrorDialog extends ConsumerWidget {
  final VoidCallback onRetry;
  final String errorMessage;

  const SSHErrorDialog({
    super.key,
    required this.onRetry,
    required this.errorMessage,
  });

  static const String _fixCommand = 'pkg install -y openssh && passwd && sshd';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bridge = ref.read(termuxBridgeProvider);

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'SSH 連線失敗',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                errorMessage,
                style: TextStyle(
                  color: Colors.red[300],
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Explanation
            const Text(
              '這通常是因為 Termux SSH 密碼尚未設定。\n請按照以下步驟修復：',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Step 1
            _buildStep(
              number: '1',
              title: '開啟 Termux',
              description: '點擊下方按鈕開啟 Termux 終端機',
            ),
            const SizedBox(height: 8),

            // Step 2
            _buildStep(
              number: '2',
              title: '執行修復指令',
              description: '在 Termux 中輸入以下指令：',
            ),
            const SizedBox(height: 8),

            // Command to copy
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _fixCommand,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    color: Colors.white54,
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: _fixCommand));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('指令已複製'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: '複製指令',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Step 3
            _buildStep(
              number: '3',
              title: '返回並重試',
              description: '執行完成後，點擊「重試連線」',
            ),
          ],
        ),
      ),
      actions: [
        // Cancel
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),

        // Open Termux
        OutlinedButton.icon(
          onPressed: () async {
            await bridge.openTermux();
          },
          icon: const Icon(Icons.terminal, size: 18),
          label: const Text('開啟 Termux'),
        ),

        // Permission Settings
        OutlinedButton.icon(
          onPressed: () async {
            await bridge.openTermuxSettings();
          },
          icon: const Icon(Icons.settings, size: 18),
          label: const Text('權限設定'),
        ),

        // Retry
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onRetry();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('重試連線'),
        ),
      ],
    );
  }

  Widget _buildStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shows the SSH error dialog
void showSSHErrorDialog(
  BuildContext context, {
  required String errorMessage,
  required VoidCallback onRetry,
}) {
  showDialog(
    context: context,
    builder: (context) => SSHErrorDialog(
      errorMessage: errorMessage,
      onRetry: onRetry,
    ),
  );
}
