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
    // Determine error type
    final isAuthError = errorMessage.contains('SSHAuthFailError') ||
        errorMessage.contains('authentication');
    final isConnectionRefused = errorMessage.contains('Connection refused');
    final isNetworkError = errorMessage.contains('Network is unreachable') ||
        errorMessage.contains('No route to host');

    String titleText = 'SSH 連線失敗';
    String explanation = '發生未知的連線錯誤，請嘗試以下修復步驟：';
    List<Widget> steps = [];

    // --- CASE 1: Authentication Error ---
    if (isAuthError) {
      titleText = '驗證失敗 (Authentication Failed)';
      explanation = 'Termux 密碼錯誤或是尚未設定。App 預設使用 "termux" 作為密碼。\n請按照以下步驟重設密碼：';
      steps = [
        _buildStep(
          number: '1',
          title: '開啟 Termux',
          description: '點擊下方按鈕開啟 Termux 終端機',
        ),
        _buildStep(
          number: '2',
          title: '執行 passwd 指令',
          description: '輸入 passwd 並按 Enter',
        ),
        _buildStep(
          number: '3',
          title: '設定密碼為 "termux"',
          description: '輸入 termux (畫面不會顯示) 並按 Enter，然後再次輸入 termux 確認',
        ),
      ];
    }
    // --- CASE 2: Connection Refused (SSHD not running) ---
    else if (isConnectionRefused) {
      titleText = '連線被拒 (Connection Refused)';
      explanation = 'Termux SSH 服務 (sshd) 可能未啟動。\n請按照以下步驟啟動服務：';
      steps = [
        _buildStep(
          number: '1',
          title: '開啟 Termux',
          description: '點擊下方按鈕開啟 Termux 終端機',
        ),
        _buildStep(
          number: '2',
          title: '啟動 SSHD',
          description: '輸入 sshd 指令並按 Enter',
        ),
        _buildStep(
          number: '3',
          title: '檢查服務',
          description: '如果顯示找不到指令，請輸入 pkg install openssh 安裝',
        ),
      ];
    }
    // --- CASE 3: Network Error (Process not running/dozing) ---
    else if (isNetworkError) {
      titleText = '無法連線 (Network Unreachable)';
      explanation = '無法連線到 Termux，請確保 Termux 正在背景執行。\n請嘗試喚醒 Termux：';
      steps = [
        _buildStep(
          number: '1',
          title: '開啟 Termux',
          description: '點擊下方按鈕，確保 Termux 視窗已開啟',
        ),
        _buildStep(
          number: '2',
          title: '防止休眠',
          description: '建議在 Termux 通知列中點擊 "Acquire wakelock"',
        ),
      ];
    }
    // --- CASE 4: Default / Complex Error ---
    else {
      explanation = '若您是第一次使用，或上述方法無效，請執行完整修復指令：';
      steps = [
        _buildStep(
          number: '1',
          title: '開啟 Termux',
          description: '點擊下方按鈕開啟 Termux 終端機',
        ),
        _buildStep(
          number: '2',
          title: '執行完整修復指令',
          description: '複製並貼上以下指令 (密碼請設定為 termux)：',
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
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
      ];
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titleText,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message box
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: SelectableText(
                errorMessage,
                style: TextStyle(
                  color: Colors.red[300],
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Explanation
            Text(
              explanation,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Steps
            ...steps
                .expand((step) => [step, const SizedBox(height: 12)])
                .toList(),

            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        // Open Termux Button
        OutlinedButton.icon(
          onPressed: () {
            ref.read(termuxBridgeProvider).openTermux();
          },
          icon: const Icon(Icons.terminal),
          label: const Text('開啟 Termux'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
          ),
        ),
        const SizedBox(width: 8),

        // Settings Button (Optional)
        OutlinedButton.icon(
          onPressed: () {
            // TODO: Navigate to settings to change port/user if needed
          },
          icon: const Icon(Icons.settings),
          label: const Text('權限設定'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white24),
          ),
        ),
        const SizedBox(width: 8),

        // Retry Button
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onRetry();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('重試連線'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
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
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
