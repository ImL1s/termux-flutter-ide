import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:termux_flutter_ide/termux/termux_providers.dart';
import 'package:termux_flutter_ide/termux/ssh_service.dart';

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

  static const String _fixCommand =
      'echo "allow-external-apps=true" >> ~/.termux/termux.properties && '
      'termux-reload-settings && '
      'pkg install -y openssh && '
      'echo -e "termux\\ntermux" | passwd && '
      'sshd';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine error type
    final isAuthError =
        errorMessage.contains('SSHAuthFailError') ||
        errorMessage.contains('authentication');
    final isConnectionRefused = errorMessage.contains('Connection refused');
    final isNetworkError =
        errorMessage.contains('Network is unreachable') ||
        errorMessage.contains('No route to host');

    String titleText = 'SSH 連線失敗';
    String explanation = '發生未知的連線錯誤，請嘗試以下修復步驟：';
    List<Widget> steps = [];

    // --- CASE 1: Authentication Error ---
    if (isAuthError) {
      titleText = '驗證失敗 (Authentication Failed)';
      explanation = 'Termux 配置可能未完成 (例如密碼驗證被停用)。\n您可以嘗試「自動修復」或手動設定：';
      steps = [
        // Auto Fix Option
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF313244),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFA6E3A1).withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_fix_high, color: Color(0xFFA6E3A1), size: 20),
                  SizedBox(width: 8),
                  Text(
                    '推薦：自動修復配置',
                    style: TextStyle(
                      color: Color(0xFFA6E3A1),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                ' IDE 將自動嘗試：\n • 啟用 sshd_config 密碼驗證\n • 重設密碼為 "termux"\n • 重啟 SSH 服務',
                style:
                    TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Show processing snackbar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('正在修復 SSH 配置... 請留意 Termux 權限請求'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Run comprehensive setup
                    await ref.read(termuxBridgeProvider).setupTermuxSSH();

                    // Trigger retry after short delay
                    Future.delayed(const Duration(seconds: 3), onRetry);
                  },
                  icon: const Icon(Icons.build_circle, size: 18),
                  label: const Text('執行自動修復'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA6E3A1),
                    foregroundColor: const Color(0xFF1E1E2E),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Text('或手動排查：',
            style: TextStyle(color: Colors.white54, fontSize: 12)),

        // Manual Steps (Collapsed/Simplified)
        _buildStep(
          number: '1',
          title: '檢查用戶名',
          description: 'Termux 執行 whoami (若非自動偵測值，請下方手動輸入)',
        ),
        // Username input section
        _buildUsernameInputSection(context, ref),
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
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(76)),
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
            ...steps.expand((step) => [step, const SizedBox(height: 12)]),

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
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a username input section for manual override
  Widget _buildUsernameInputSection(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF313244),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF89B4FA).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, color: Color(0xFF89B4FA), size: 18),
              SizedBox(width: 8),
              Text(
                '手動輸入用戶名 (選填)',
                style: TextStyle(
                  color: Color(0xFF89B4FA),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '例如: u0_a1192',
                    hintStyle: const TextStyle(color: Colors.white38),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFF1E1E2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final username = controller.text.trim();
                  if (username.isNotEmpty) {
                    await SSHService.saveUsername(username);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已儲存用戶名: $username，正在重試連線...')),
                      );
                      onRetry();
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF89B4FA),
                  foregroundColor: const Color(0xFF1E1E2E),
                ),
                child: const Text('儲存並重試'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
