import 'package:flutter/material.dart';

/// SSH 連線進度階段
enum ConnectionStage {
  socket,
  auth,
  shell,
}

/// SSH 連線進度視覺化組件
///
/// 顯示連線過程的各個階段及當前進度
class SSHConnectionProgress extends StatelessWidget {
  final ConnectionStage currentStage;
  final String? errorMessage;
  final bool isComplete;

  const SSHConnectionProgress({
    super.key,
    required this.currentStage,
    this.errorMessage,
    this.isComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF313244)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 進度指示
          Row(
            children: [
              _buildStageIndicator(
                ConnectionStage.socket,
                '建立連線',
                Icons.cable,
              ),
              _buildConnector(ConnectionStage.socket),
              _buildStageIndicator(
                ConnectionStage.auth,
                '驗證身份',
                Icons.lock_outline,
              ),
              _buildConnector(ConnectionStage.auth),
              _buildStageIndicator(
                ConnectionStage.shell,
                '取得終端',
                Icons.terminal,
              ),
            ],
          ),

          // 當前狀態文字
          const SizedBox(height: 16),
          Text(
            _getStageMessage(),
            style: TextStyle(
              color: errorMessage != null
                  ? const Color(0xFFF38BA8)
                  : const Color(0xFFBAC2DE),
              fontSize: 13,
            ),
          ),

          // 錯誤訊息
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF38BA8).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFF38BA8),
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStageIndicator(
    ConnectionStage stage,
    String label,
    IconData icon,
  ) {
    final isPast = stage.index < currentStage.index || isComplete;
    final isCurrent = stage == currentStage && !isComplete;
    final isFailed = isCurrent && errorMessage != null;

    Color bgColor;
    Color iconColor;
    Widget child;

    if (isPast || isComplete) {
      bgColor = const Color(0xFFA6E3A1);
      iconColor = const Color(0xFF1E1E2E);
      child = Icon(Icons.check, color: iconColor, size: 16);
    } else if (isFailed) {
      bgColor = const Color(0xFFF38BA8);
      iconColor = const Color(0xFF1E1E2E);
      child = Icon(Icons.close, color: iconColor, size: 16);
    } else if (isCurrent) {
      bgColor = const Color(0xFF89B4FA);
      iconColor = const Color(0xFF1E1E2E);
      child = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(iconColor),
        ),
      );
    } else {
      bgColor = const Color(0xFF313244);
      iconColor = const Color(0xFF6C7086);
      child = Icon(icon, color: iconColor, size: 16);
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Center(child: child),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isCurrent || isPast
                  ? const Color(0xFFCDD6F4)
                  : const Color(0xFF6C7086),
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(ConnectionStage afterStage) {
    final isPast = afterStage.index < currentStage.index || isComplete;

    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isPast ? const Color(0xFFA6E3A1) : const Color(0xFF313244),
    );
  }

  String _getStageMessage() {
    if (isComplete) return '✓ 連線成功';
    if (errorMessage != null) return '連線失敗';

    switch (currentStage) {
      case ConnectionStage.socket:
        return '正在建立 Socket 連線...';
      case ConnectionStage.auth:
        return '正在驗證 SSH 憑證...';
      case ConnectionStage.shell:
        return '正在取得終端 Shell...';
    }
  }
}
