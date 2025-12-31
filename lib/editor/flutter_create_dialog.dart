import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../file_manager/file_operations.dart';
import '../core/providers.dart';
import 'flutter_missing_dialog.dart';

class FlutterCreateDialog extends ConsumerStatefulWidget {
  final String initialPath;

  const FlutterCreateDialog({super.key, required this.initialPath});

  @override
  ConsumerState<FlutterCreateDialog> createState() =>
      _FlutterCreateDialogState();
}

class _FlutterCreateDialogState extends ConsumerState<FlutterCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _orgController = TextEditingController(text: 'com.example');
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _orgController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final name = _nameController.text.trim();
      final org = _orgController.text.trim();
      final ops = ref.read(fileOperationsProvider);

      final result = await ops.createFlutterProjectWithError(
        widget.initialPath,
        name,
        org: org,
      );

      if (mounted) {
        if (result.success) {
          final newPath = '${widget.initialPath}/$name'.replaceAll('//', '/');
          ref.read(projectPathProvider.notifier).set(newPath);
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('專案創建成功')),
          );
        } else {
          // Check if error is Flutter not found
          final error = result.error ?? '未知錯誤';
          if (isFlutterNotFoundError(error)) {
            Navigator.of(context).pop(false);
            if (mounted) {
              showFlutterMissingDialog(context, error);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('創建專案失敗: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('錯誤: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title:
          const Text('創建新 Flutter 專案', style: TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '專案名稱 (snake_case)',
                labelStyle: TextStyle(color: Color(0xFFBAC2DE)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF313244)),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '請輸入名稱';
                if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value)) {
                  return '名稱必須是小寫字母開頭，僅含數字與下劃線';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _orgController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '組織標記 (Organization ID)',
                labelStyle: TextStyle(color: Color(0xFFBAC2DE)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF313244)),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return '請輸入 Organization ID';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              '位置: ${widget.initialPath}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (_isCreating) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text('正在創建中...', style: TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: Color(0xFFF38BA8))),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _handleCreate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF89B4FA),
            foregroundColor: const Color(0xFF1E1E2E),
          ),
          child: const Text('開始創建'),
        ),
      ],
    );
  }
}

Future<bool?> showFlutterCreateDialog(
    BuildContext context, String initialPath) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => FlutterCreateDialog(initialPath: initialPath),
  );
}
