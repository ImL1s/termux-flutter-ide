import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'x11_service.dart';

/// Shows the X11 setup dialog
Future<bool?> showX11SetupDialog(
    BuildContext context, WidgetRef ref, X11State state) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => X11SetupDialog(state: state),
  );
}

/// X11 Setup Dialog
class X11SetupDialog extends ConsumerStatefulWidget {
  final X11State state;

  const X11SetupDialog({super.key, required this.state});

  @override
  ConsumerState<X11SetupDialog> createState() => _X11SetupDialogState();
}

class _X11SetupDialogState extends ConsumerState<X11SetupDialog> {
  bool _isInstalling = false;
  String? _installStatus;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            widget.state == X11State.notInstalled
                ? Icons.warning_amber_rounded
                : Icons.info_outline,
            color: widget.state == X11State.notInstalled
                ? const Color(0xFFF9E2AF)
                : const Color(0xFF89B4FA),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'X11 環境設置',
              style: TextStyle(
                color: Color(0xFFCDD6F4),
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.state == X11State.notInstalled) ...[
              _buildSection(
                '步驟 1：在 Termux 中安裝 X11',
                '請在 Termux 終端執行以下命令：',
              ),
              const SizedBox(height: 8),
              _buildCodeBlock(X11InstallCommands.installAll),
              const SizedBox(height: 16),
              _buildSection(
                '步驟 2：安裝 Termux:X11 App',
                '從 GitHub 下載並安裝 Termux:X11 Android 應用：',
              ),
              const SizedBox(height: 8),
              _buildLinkButton(
                'Termux:X11 GitHub Releases',
                'https://github.com/termux/termux-x11/releases',
              ),
            ] else if (widget.state == X11State.installed) ...[
              _buildSection(
                'X11 已安裝，但服務未運行',
                '請執行以下操作：',
              ),
              const SizedBox(height: 12),
              _buildStep(1, '開啟 Termux:X11 App'),
              const SizedBox(height: 8),
              _buildStep(2, '在 Termux 中執行：'),
              const SizedBox(height: 8),
              _buildCodeBlock('termux-x11 :0 &'),
              const SizedBox(height: 8),
              _buildStep(3, '返回 IDE 重新執行 Run'),
            ],
            if (_installStatus != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF313244),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_isInstalling)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.check_circle,
                          color: Color(0xFFA6E3A1), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _installStatus!,
                        style: const TextStyle(
                          color: Color(0xFFBAC2DE),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        if (widget.state == X11State.installed)
          ElevatedButton.icon(
            onPressed: _isInstalling ? null : _tryStartX11,
            icon: _isInstalling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 18),
            label: const Text('嘗試啟動 X11'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA6E3A1),
              foregroundColor: const Color(0xFF1E1E2E),
            ),
          ),
        if (widget.state == X11State.notInstalled)
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('我已安裝'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89B4FA),
              foregroundColor: const Color(0xFF1E1E2E),
            ),
          ),
      ],
    );
  }

  Future<void> _tryStartX11() async {
    setState(() {
      _isInstalling = true;
      _installStatus = '正在啟動 X11 服務...';
    });

    final x11Service = ref.read(x11ServiceProvider);
    final success = await x11Service.startX11Server();

    if (mounted) {
      if (success) {
        setState(() {
          _isInstalling = false;
          _installStatus = 'X11 服務已啟動！';
        });
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isInstalling = false;
          _installStatus = '啟動失敗。請手動開啟 Termux:X11 App。';
        });
      }
    }
  }

  Widget _buildSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFCDD6F4),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            color: Color(0xFFBAC2DE),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildStep(int number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFCBA6F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF1E1E2E),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFCDD6F4),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeBlock(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11111B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF313244)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              code.trim(),
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                color: Color(0xFFA6E3A1),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            color: const Color(0xFF6C7086),
            tooltip: '複製',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code.trim()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已複製到剪貼板'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton(String label, String url) {
    return OutlinedButton.icon(
      onPressed: () {
        launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      },
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF89B4FA),
        side: const BorderSide(color: Color(0xFF89B4FA)),
      ),
    );
  }
}
