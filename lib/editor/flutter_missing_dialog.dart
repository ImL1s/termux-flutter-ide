import 'package:flutter/material.dart';
import '../setup/setup_wizard.dart';
import '../setup/setup_service.dart';
import '../termux/termux_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 當 Flutter 未安裝時顯示的引導對話框
class FlutterMissingDialog extends ConsumerWidget {
  final String errorMessage;

  const FlutterMissingDialog({
    super.key,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFF9E2AF), size: 28),
          SizedBox(width: 12),
          Text(
            'Flutter 尚未安裝',
            style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '要創建 Flutter 專案，需要先在 Termux 中安裝 Flutter SDK。',
            style: TextStyle(color: Color(0xFFBAC2DE), height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF11111B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF313244)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFF38BA8), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage.length > 100
                        ? '${errorMessage.substring(0, 100)}...'
                        : errorMessage,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: Color(0xFFA6ADC8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('稍後再說', style: TextStyle(color: Color(0xFF6C7086))),
        ),
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            // Open Termux and show install command
            ref.read(termuxBridgeProvider).openTermux();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('請在 Termux 中執行安裝指令'),
                duration: Duration(seconds: 5),
              ),
            );
          },
          icon: const Icon(Icons.terminal, size: 16),
          label: const Text('手動安裝'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFBAC2DE)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            // Set state to Flutter step before navigation
            ref.read(setupServiceProvider.notifier).goToFlutterStep();
            // Navigate to Setup Wizard
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SetupWizardPage()),
            );
          },
          icon: const Icon(Icons.download, size: 16),
          label: const Text('前往安裝'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF89B4FA),
            foregroundColor: const Color(0xFF1E1E2E),
          ),
        ),
      ],
    );
  }
}

/// 顯示 Flutter 未安裝對話框
Future<void> showFlutterMissingDialog(
  BuildContext context,
  String errorMessage,
) {
  return showDialog(
    context: context,
    builder: (context) => FlutterMissingDialog(errorMessage: errorMessage),
  );
}

/// 檢查錯誤訊息是否表示 Flutter 未安裝
bool isFlutterNotFoundError(String error) {
  final lowerError = error.toLowerCase();
  return lowerError.contains('flutter: command not found') ||
      lowerError.contains('flutter: not found') ||
      lowerError.contains('no such file or directory') &&
          lowerError.contains('flutter') ||
      lowerError.contains('command not found: flutter');
}
