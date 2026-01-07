import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class ClipboardService {
  static Future<void> copyToClipboard(BuildContext context, String text,
      {String? message}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? '已複製指令到剪貼簿'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }
}
