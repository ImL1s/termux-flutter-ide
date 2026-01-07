import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../termux/termux_bridge.dart';
import '../termux/termux_providers.dart';
import '../termux/android_compatibility.dart';
import '../core/clipboard_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// 環境檢查項目狀態
enum CheckStatus {
  checking,
  passed,
  failed,
  warning,
}

/// 單一檢查項目的結果
class CheckItem {
  final String title;
  final String description;
  final CheckStatus status;
  final String? fixAction;
  final VoidCallback? onFix;
  final VoidCallback? onCopy;

  const CheckItem({
    required this.title,
    required this.description,
    required this.status,
    this.fixAction,
    this.onFix,
    this.onCopy,
  });

  CheckItem copyWith({CheckStatus? status}) {
    return CheckItem(
      title: title,
      description: description,
      status: status ?? this.status,
      fixAction: fixAction,
      onFix: onFix,
      onCopy: onCopy,
    );
  }
}

/// 環境檢查步驟 Widget
///
/// 在 Setup Wizard 開始前顯示所有前置條件的狀態，
/// 讓用戶一眼看完缺少什麼設定
class EnvironmentCheckStep extends ConsumerStatefulWidget {
  final VoidCallback onAllPassed;
  final VoidCallback onContinueAnyway;

  const EnvironmentCheckStep({
    super.key,
    required this.onAllPassed,
    required this.onContinueAnyway,
  });

  @override
  ConsumerState<EnvironmentCheckStep> createState() =>
      _EnvironmentCheckStepState();
}

class _EnvironmentCheckStepState extends ConsumerState<EnvironmentCheckStep>
    with WidgetsBindingObserver {
  List<CheckItem> _checks = [];
  bool _isChecking = true;
  bool _hasLaunchedTermux = false; // 追蹤是否剛從 Termux 回來

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 當 App 從背景恢復，且之前有開過 Termux，自動重新檢查
    if (state == AppLifecycleState.resumed && _hasLaunchedTermux) {
      _hasLaunchedTermux = false; // 重置標記
      _runChecks();
    }
  }

  Future<void> _runChecks() async {
    setState(() => _isChecking = true);

    final bridge = ref.read(termuxBridgeProvider);
    final checks = <CheckItem>[];

    // 1. Termux 安裝檢查
    bool termuxInstalled = await bridge.isTermuxInstalled();
    String? installSource;

    if (termuxInstalled) {
      installSource = await bridge.getTermuxPackageInstaller();
      // "com.android.vending" 是 Google Play Store
      if (installSource == 'com.android.vending') {
        checks.add(CheckItem(
          title: 'Termux 版本不相容',
          description:
              '偵測到 Google Play 版本。此版本已停止維護且不支援外部指令。\n請解除安裝後，改用 GitHub 或 F-Droid 版本。',
          status: CheckStatus.failed,
          fixAction: '下載最新版 (GitHub)',
          onFix: () => _openGitHubReleases(),
        ));
        termuxInstalled = false; // 視為未安裝/不可用，阻止後續檢查
      } else {
        checks.add(CheckItem(
          title: 'Termux 已安裝',
          description: 'Termux 應用程式已偵測到',
          status: CheckStatus.passed,
        ));
      }
    } else {
      checks.add(CheckItem(
        title: 'Termux 已安裝',
        description: '請先安裝 Termux 應用程式 (推薦 GitHub 或 F-Droid 版)',
        status: CheckStatus.failed,
        fixAction: '下載最新版 (GitHub)',
        onFix: () => _openGitHubReleases(),
      ));
    }

    // 2. RUN_COMMAND 權限檢查 (Android 11+ 必要)
    if (termuxInstalled) {
      final runCommandPermission = 'com.termux.permission.RUN_COMMAND';
      final hasPermission = await bridge.checkPermission(runCommandPermission);
      checks.add(CheckItem(
        title: 'RUN_COMMAND 權限',
        description: hasPermission
            ? '已授權執行指令權限'
            : '請務必手動授權「執行指令」權限 (App 資訊 -> 權限 -> 更多)',
        status: hasPermission ? CheckStatus.passed : CheckStatus.failed,
        fixAction: hasPermission ? null : '重新檢查',
        onFix: hasPermission ? null : () => _runChecks(),
      ));

      // 3. allow-external-apps 檢查
      final extApps = await bridge.checkExternalAppsAllowed();
      checks.add(CheckItem(
        title: 'allow-external-apps',
        description: extApps == ExternalAppsStatus.allowed
            ? '已允許外部應用執行指令'
            : (hasPermission
                ? '已偵測到權限但 Termux 拒絕執行。請完成指令後點擊「重新檢查」'
                : '請先在上方授權 RUN_COMMAND 權限'),
        status: extApps == ExternalAppsStatus.allowed
            ? CheckStatus.passed
            : (extApps == ExternalAppsStatus.notAllowed
                ? CheckStatus.failed
                : CheckStatus.warning),
        fixAction:
            extApps == ExternalAppsStatus.allowed ? null : '複製並開啟 Termux',
        onFix: extApps == ExternalAppsStatus.allowed
            ? null
            : () async {
                await ClipboardService.copyToClipboard(context,
                    'echo "allow-external-apps = true" >> ~/.termux/termux.properties && termux-reload-settings',
                    message: '已複製！正在開啟 Termux...');
                _hasLaunchedTermux = true; // 標記已開啟 Termux，回來時自動重新檢查
                await ref.read(termuxBridgeProvider).launchTermux();
              },
      ));
    }

    // 3. Draw Over Apps 權限 (只有 Termux 已安裝才需要)
    if (termuxInstalled) {
      final canOverlay = await bridge.canDrawOverlays();
      checks.add(CheckItem(
        title: 'Draw Over Apps 權限',
        description: canOverlay ? '已授權懸浮視窗權限' : 'Android 10+ 需要此權限才能自動啟動前台終端',
        status: canOverlay ? CheckStatus.passed : CheckStatus.warning,
        fixAction: canOverlay ? null : '前往設定',
        onFix: canOverlay ? null : () => bridge.openTermuxSettings(),
      ));

      // 4. Termux Prefix 檢查
      try {
        final prefixOk = await bridge.checkTermuxPrefix();
        checks.add(CheckItem(
          title: 'Termux 環境變數',
          description: prefixOk ? 'PREFIX 設定正確' : '無法存取 \$PREFIX/usr/bin',
          status: prefixOk ? CheckStatus.passed : CheckStatus.failed,
          fixAction: prefixOk ? null : '修復',
          onFix: prefixOk ? null : () => _showPrefixHelp(),
        ));
      } catch (_) {
        // 忽略檢查錯誤，避免卡住
      }

      // 5. SSH 服務狀態
      try {
        final sshOk = await bridge.checkSSHServiceStatus();
        checks.add(CheckItem(
          title: 'SSH 服務狀態',
          description: sshOk ? 'sshd 正在執行 (Port 8022)' : '未偵測到 sshd 服務',
          status: sshOk ? CheckStatus.passed : CheckStatus.warning,
          fixAction: sshOk ? null : '啟動',
          // 啟動會嘗試執行 setupTermuxSSH
          onFix: sshOk ? null : () => _startSSHService(bridge),
          onCopy: sshOk
              ? null
              : () => ClipboardService.copyToClipboard(
                  context, 'pkg update && pkg install -y openssh && sshd'),
        ));
      } catch (_) {}

      // 6. 電池優化（OEM 特定檢查）
      final oem = AndroidCompatibilityService.detectOemVendor();
      final isKnownRestrictedOem =
          oem != OemVendor.other && oem != OemVendor.google;

      checks.add(CheckItem(
        title: isKnownRestrictedOem
            ? '電池優化 (${oem.name.toUpperCase()})'
            : '電池優化豁免',
        description: isKnownRestrictedOem
            ? '偵測到 ${oem.name} 設備，請務必手動關閉電池限制以防止 Termux 斷線'
            : '建議豁免 Termux 電池優化，避免服務被系統終止',
        status:
            isKnownRestrictedOem ? CheckStatus.warning : CheckStatus.warning,
        fixAction: '前往設定',
        onFix: () {
          // 對於特定廠商，我們可以顯示更詳細的指引對話框
          if (isKnownRestrictedOem) {
            _showOemGuidance(oem, bridge);
          } else {
            bridge.openBatteryOptimizationSettings();
          }
        },
      ));
    } // end of if (termuxInstalled)

    if (!mounted) return;

    setState(() {
      _checks = checks;
      _isChecking = false;
    });

    // 檢查是否全部通過
    final allPassed = checks.every((c) =>
        c.status == CheckStatus.passed || c.status == CheckStatus.warning);
    final hasCriticalFail = checks.any((c) => c.status == CheckStatus.failed);

    if (allPassed && !hasCriticalFail) {
      // 延遲一下讓用戶看到結果
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 800), widget.onAllPassed);
      }
    }
  }

  void _showOemGuidance(OemVendor vendor, TermuxBridge bridge) {
    final guidance = AndroidCompatibilityService.getOemGuidance(vendor);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${vendor.name.toUpperCase()} 設定指引'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('請依照以下步驟防止後台殺殺：'),
            const SizedBox(height: 8),
            Text(guidance.steps.join('\n')),
            const SizedBox(height: 16),
            Text('設定路徑: ${guidance.settingsPath}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ClipboardService.copyToClipboard(
                  context, guidance.steps.join('\n'),
                  message: '已複製指引');
            },
            child: const Text('複製指引'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              bridge.openBatteryOptimizationSettings();
            },
            child: const Text('打開電池設定'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍後'),
          ),
        ],
      ),
    );
  }

  Future<void> _openGitHubReleases() async {
    final uri = Uri.parse('https://github.com/termux/termux-app/releases');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to copy if launch fails
      await ClipboardService.copyToClipboard(context, uri.toString(),
          message: '無法開啟瀏覽器，已複製 GitHub 下載連結');
    }
  }

  void _showPrefixHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termux 環境異常'),
        content: const Text('無法存取 \$PREFIX/usr/bin。\n\n'
            '這可能是因為 Termux 未正確安裝，或者儲存空間權限未開啟。\n\n'
            '請嘗試重新安裝 Termux 或執行 termux-setup-storage。'),
        actions: [
          TextButton(
            onPressed: () {
              ClipboardService.copyToClipboard(context, 'termux-setup-storage',
                  message: '已複製修復指令');
            },
            child: const Text('複製修復指令 (termux-setup-storage)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Future<void> _startSSHService(TermuxBridge bridge) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在嘗試啟動 SSH 服務...')),
    );
    await bridge.setupTermuxSSH();
    // 等待啟動
    if (mounted) {
      Future.delayed(const Duration(seconds: 2), _runChecks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.checklist_rtl, size: 56, color: Color(0xFF89B4FA)),
        const SizedBox(height: 16),
        const Text(
          '環境檢查',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFCDD6F4),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '正在檢查 Termux 環境設定...',
          style: TextStyle(color: Color(0xFFBAC2DE), fontSize: 14),
        ),
        const SizedBox(height: 24),

        // 檢查項目列表
        Expanded(
          child: _isChecking
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: _checks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildCheckItem(_checks[index]),
                ),
        ),

        const SizedBox(height: 16),

        // 操作按鈕
        if (!_isChecking) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _runChecks,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新檢查'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBAC2DE),
                  side: const BorderSide(color: Color(0xFF313244)),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: widget.onContinueAnyway,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('繼續設定'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF89B4FA),
                  foregroundColor: const Color(0xFF1E1E2E),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCheckItem(CheckItem item) {
    final IconData icon;
    final Color iconColor;

    switch (item.status) {
      case CheckStatus.checking:
        icon = Icons.hourglass_empty;
        iconColor = const Color(0xFF6C7086);
      case CheckStatus.passed:
        icon = Icons.check_circle;
        iconColor = const Color(0xFFA6E3A1);
      case CheckStatus.failed:
        icon = Icons.error;
        iconColor = const Color(0xFFF38BA8);
      case CheckStatus.warning:
        icon = Icons.warning_amber;
        iconColor = const Color(0xFFF9E2AF);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF313244),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.status == CheckStatus.failed
              ? const Color(0xFFF38BA8).withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Color(0xFFCDD6F4),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: Color(0xFFA6ADC8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (item.onCopy != null)
            IconButton(
              onPressed: item.onCopy,
              icon: const Icon(Icons.copy, size: 18, color: Color(0xFFBAC2DE)),
              tooltip: '複製指令',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (item.fixAction != null && item.onFix != null)
            TextButton(
              onPressed: item.onFix,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF89B4FA),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(item.fixAction!),
            ),
        ],
      ),
    );
  }
}
