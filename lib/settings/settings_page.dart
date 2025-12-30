import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_providers.dart';
import '../theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(fontSizeProvider);
    final editorTheme = ref.watch(editorThemeProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('設定'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Font Size Section
          _buildSectionTitle('字體大小'),
          Card(
            color: AppTheme.surfaceVariant,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${fontSize.toInt()} px',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: fontSize > FontSizeNotifier.minSize
                                ? () => ref
                                      .read(fontSizeProvider.notifier)
                                      .setFontSize(fontSize - 1)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: fontSize < FontSizeNotifier.maxSize
                                ? () => ref
                                      .read(fontSizeProvider.notifier)
                                      .setFontSize(fontSize + 1)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Slider(
                    value: fontSize,
                    min: FontSizeNotifier.minSize,
                    max: FontSizeNotifier.maxSize,
                    divisions:
                        (FontSizeNotifier.maxSize - FontSizeNotifier.minSize)
                            .toInt(),
                    label: '${fontSize.toInt()} px',
                    onChanged: (value) {
                      ref.read(fontSizeProvider.notifier).setFontSize(value);
                    },
                  ),
                  // Preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'void main() {\n  print("Hello, World!");\n}',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: fontSize,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Editor Theme Section
          _buildSectionTitle('編輯器主題'),
          Card(
            color: AppTheme.surfaceVariant,
            child: Column(
              children: EditorTheme.values.map((theme) {
                return RadioListTile<EditorTheme>(
                  title: Text(theme.displayName),
                  value: theme,
                  groupValue: editorTheme,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(editorThemeProvider.notifier).setTheme(value);
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          _buildSectionTitle('關於'),
          Card(
            color: AppTheme.surfaceVariant,
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Termux Flutter IDE'),
              subtitle: Text('v0.1.0'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
