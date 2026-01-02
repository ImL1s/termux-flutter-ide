import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shows a keyboard shortcuts help dialog.
void showKeyboardShortcutsDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.keyboard, size: 20, color: AppTheme.textSecondary),
                SizedBox(width: 8),
                Text(
                  'Keyboard Shortcuts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.surfaceVariant),
          // Shortcuts List
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: const [
                _ShortcutCategory(
                  title: '編輯器',
                  shortcuts: [
                    _ShortcutItem('Ctrl + F', '搜尋'),
                    _ShortcutItem('Ctrl + H', '搜尋與取代'),
                    _ShortcutItem('Ctrl + G', '跳至行號'),
                    _ShortcutItem('Ctrl + /', '切換註解'),
                    _ShortcutItem('Ctrl + S', '儲存檔案'),
                    _ShortcutItem('Ctrl + Z', '復原'),
                    _ShortcutItem('Ctrl + Shift + Z', '重做'),
                  ],
                ),
                SizedBox(height: 16),
                _ShortcutCategory(
                  title: '導航',
                  shortcuts: [
                    _ShortcutItem('Ctrl + P', '快速開啟檔案'),
                    _ShortcutItem('Ctrl + Shift + P', '指令面板'),
                    _ShortcutItem('F12', '跳至定義'),
                    _ShortcutItem('Shift + F12', '尋找參照'),
                    _ShortcutItem('Ctrl + Tab', '切換分頁'),
                  ],
                ),
                SizedBox(height: 16),
                _ShortcutCategory(
                  title: '除錯',
                  shortcuts: [
                    _ShortcutItem('F5', '啟動/繼續除錯'),
                    _ShortcutItem('F9', '切換中斷點'),
                    _ShortcutItem('F10', '步過'),
                    _ShortcutItem('F11', '步入'),
                    _ShortcutItem('Shift + F11', '步出'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ShortcutCategory extends StatelessWidget {
  final String title;
  final List<_ShortcutItem> shortcuts;

  const _ShortcutCategory({required this.title, required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...shortcuts,
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String keys;
  final String description;

  const _ShortcutItem(this.keys, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.surfaceVariant),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 11,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
