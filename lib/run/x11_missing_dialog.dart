import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class X11MissingDialog extends StatelessWidget {
  const X11MissingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Text('需要 Termux:X11', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Termux 無法直接顯示圖形介面，需要配合 Termux:X11 在 Android 上顯示視窗。',
            style: TextStyle(color: Colors.white70),
          ),
          SizedBox(height: 16),
          Text(
            '檢測到您的裝置尚未安裝 Termux:X11。',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: Colors.grey)),
        ),
        TextButton.icon(
          onPressed: () async {
            final url =
                Uri.parse('https://github.com/termux/termux-x11/releases');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          icon: const Icon(Icons.download, size: 16),
          label: const Text('前往下載'),
          style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            // User can try running again manually
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('我已安裝 (重試)', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
