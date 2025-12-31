import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Context menu for code editor
class EditorContextMenu extends StatelessWidget {
  final Offset position;
  final TextEditingController? textController;
  final VoidCallback? onDismiss;
  final VoidCallback? onCut;
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;
  final VoidCallback? onSelectAll;
  final VoidCallback? onFormat;

  const EditorContextMenu({
    super.key,
    required this.position,
    this.textController,
    this.onDismiss,
    this.onCut,
    this.onCopy,
    this.onPaste,
    this.onSelectAll,
    this.onFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 160,
          maxWidth: 200,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF45475A),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuItem(
              icon: Icons.content_cut,
              label: '剪下',
              shortcut: 'Ctrl+X',
              onTap: onCut,
            ),
            _MenuItem(
              icon: Icons.content_copy,
              label: '複製',
              shortcut: 'Ctrl+C',
              onTap: onCopy,
            ),
            _MenuItem(
              icon: Icons.content_paste,
              label: '貼上',
              shortcut: 'Ctrl+V',
              onTap: onPaste,
            ),
            const _Divider(),
            _MenuItem(
              icon: Icons.select_all,
              label: '全選',
              shortcut: 'Ctrl+A',
              onTap: onSelectAll,
            ),
            const _Divider(),
            _MenuItem(
              icon: Icons.auto_fix_high,
              label: '格式化',
              shortcut: 'Shift+Alt+F',
              onTap: onFormat,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? shortcut;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.shortcut,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return InkWell(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  isEnabled ? const Color(0xFFBAC2DE) : const Color(0xFF585B70),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isEnabled
                      ? const Color(0xFFCDD6F4)
                      : const Color(0xFF585B70),
                ),
              ),
            ),
            if (shortcut != null)
              Text(
                shortcut!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6C7086),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFF45475A),
    );
  }
}

/// Helper function to show context menu
void showEditorContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required VoidCallback? onCut,
  required VoidCallback? onCopy,
  required VoidCallback? onPaste,
  required VoidCallback? onSelectAll,
  VoidCallback? onFormat,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        // Backdrop to dismiss
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => entry.remove(),
            child: Container(color: Colors.transparent),
          ),
        ),
        // Menu
        Positioned(
          left: globalPosition.dx,
          top: globalPosition.dy,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 150),
            tween: Tween(begin: 0.8, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                alignment: Alignment.topLeft,
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: EditorContextMenu(
              position: globalPosition,
              onCut: () {
                entry.remove();
                onCut?.call();
              },
              onCopy: () {
                entry.remove();
                onCopy?.call();
              },
              onPaste: () {
                entry.remove();
                onPaste?.call();
              },
              onSelectAll: () {
                entry.remove();
                onSelectAll?.call();
              },
              onFormat: onFormat != null
                  ? () {
                      entry.remove();
                      onFormat.call();
                    }
                  : null,
            ),
          ),
        ),
      ],
    ),
  );

  overlay.insert(entry);
}
