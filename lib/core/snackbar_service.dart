import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global SnackBar types
enum SnackType { success, error, info, warning }

/// SnackBar message model
class SnackMessage {
  final String message;
  final SnackType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  const SnackMessage({
    required this.message,
    this.type = SnackType.info,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 3),
  });
}

/// Global scaffold messenger key for showing SnackBars
final scaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>(
  (ref) => GlobalKey<ScaffoldMessengerState>(),
);

/// SnackBar Service for showing notifications
class SnackBarService {
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  SnackBarService(this.messengerKey);

  void show(SnackMessage snack) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(_buildSnackBar(snack));
  }

  void success(String message) {
    show(SnackMessage(message: message, type: SnackType.success));
  }

  void error(String message) {
    show(SnackMessage(
      message: message,
      type: SnackType.error,
      duration: const Duration(seconds: 5),
    ));
  }

  void info(String message) {
    show(SnackMessage(message: message, type: SnackType.info));
  }

  void warning(String message) {
    show(SnackMessage(message: message, type: SnackType.warning));
  }

  SnackBar _buildSnackBar(SnackMessage snack) {
    final colors = _getColors(snack.type);

    return SnackBar(
      content: Row(
        children: [
          Icon(
            _getIcon(snack.type),
            color: colors.foreground,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              snack.message,
              style: TextStyle(
                color: colors.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: colors.background,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      margin: const EdgeInsets.all(16),
      duration: snack.duration,
      action: snack.actionLabel != null
          ? SnackBarAction(
              label: snack.actionLabel!,
              textColor: colors.foreground,
              onPressed: snack.onAction ?? () {},
            )
          : null,
    );
  }

  IconData _getIcon(SnackType type) {
    switch (type) {
      case SnackType.success:
        return Icons.check_circle;
      case SnackType.error:
        return Icons.error;
      case SnackType.warning:
        return Icons.warning;
      case SnackType.info:
        return Icons.info;
    }
  }

  _SnackColors _getColors(SnackType type) {
    switch (type) {
      case SnackType.success:
        return const _SnackColors(
          background: Color(0xFF1E3A2F), // Dark green
          foreground: Color(0xFFA6E3A1), // Catppuccin Green
        );
      case SnackType.error:
        return const _SnackColors(
          background: Color(0xFF3D1F1F), // Dark red
          foreground: Color(0xFFF38BA8), // Catppuccin Red
        );
      case SnackType.warning:
        return const _SnackColors(
          background: Color(0xFF3D3520), // Dark yellow
          foreground: Color(0xFFF9E2AF), // Catppuccin Yellow
        );
      case SnackType.info:
        return const _SnackColors(
          background: Color(0xFF1E2D3D), // Dark blue
          foreground: Color(0xFF89B4FA), // Catppuccin Blue
        );
    }
  }
}

class _SnackColors {
  final Color background;
  final Color foreground;

  const _SnackColors({required this.background, required this.foreground});
}

/// Provider for SnackBar service
final snackBarServiceProvider = Provider<SnackBarService>((ref) {
  return SnackBarService(ref.watch(scaffoldMessengerKeyProvider));
});
