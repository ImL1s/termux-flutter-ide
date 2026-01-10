import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import '../termux/termux_providers.dart';
import '../termux/connection_diagnostics.dart';
import '../termux/ssh_service.dart';
import 'setup_service.dart';
import 'environment_check_step.dart';

class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  @override
  void initState() {
    super.initState();
    print('SetupWizardPage initialized! Checking environment...');
    // Only check environment if step is still at welcome (allows goToFlutterStep to bypass)
    Future.microtask(() {
      final currentStep = ref.read(setupServiceProvider).currentStep;
      if (currentStep == SetupStep.welcome) {
        ref.read(setupServiceProvider.notifier).checkEnvironment();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setupServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E), // Catppuccin Base
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF181825), // Mantle
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF313244)), // Surface0
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildStepper(state.currentStep),
              const SizedBox(height: 32),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStepContent(state),
                ),
              ),
              const SizedBox(height: 32),
              _buildActions(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper(SetupStep current) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children:
            SetupStep.values.where((s) => s != SetupStep.complete).map((step) {
          final isActive = step == current;
          final isCompleted = step.index < current.index;

          return Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive || isCompleted
                      ? const Color(0xFF89B4FA)
                      : const Color(0xFF313244),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check,
                          size: 16, color: Color(0xFF1E1E2E))
                      : Text(
                          '${step.index + 1}',
                          style: TextStyle(
                            color: isActive
                                ? const Color(0xFF1E1E2E)
                                : const Color(0xFFA6ADC8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (step != SetupStep.complete) // Last step before complete
                Container(
                  width: 40,
                  height: 2,
                  color: isCompleted
                      ? const Color(0xFF89B4FA)
                      : const Color(0xFF313244),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

// ... (skipping unchanged parts) ...

  Widget _buildCodeBlock(String code) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11111B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF313244)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 14,
                  color: Color(0xFFA6E3A1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            color: const Color(0xFF6C7086),
            tooltip: '複製',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已複製')),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Show diagnostics dialog with error-specific guidance
  void _showDiagnosticsDialog(
      BuildContext context, ConnectionDiagnostics diag) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Row(
          children: [
            Icon(
              diag.errorType == ConnectionErrorType.authenticationFailed
                  ? Icons.lock_outline
                  : Icons.error_outline,
              color: const Color(0xFFF38BA8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                diag.errorTitle,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                diag.explanation,
                style: const TextStyle(color: Color(0xFFBAC2DE), fontSize: 14),
              ),
              if (diag.fixCommand.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  '請在 Termux 執行：',
                  style: TextStyle(
                    color: Color(0xFFA6ADC8),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
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
                          diag.fixCommand,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: Color(0xFFA6E3A1),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        color: const Color(0xFF6C7086),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: diag.fixCommand));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('已複製'),
                                duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF89B4FA).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF89B4FA).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF89B4FA), size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '執行後請返回這裡點擊「重試連線」',
                        style:
                            TextStyle(color: Color(0xFF89B4FA), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(termuxBridgeProvider).openTermux();
            },
            child: const Text('開啟 Termux'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF89B4FA),
              foregroundColor: const Color(0xFF1E1E2E),
            ),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  /// Builds a username preview section with edit capability
  Widget _buildUsernamePreviewSection() {
    return FutureBuilder<int?>(
      future: ref.read(termuxBridgeProvider).getTermuxUid(),
      builder: (context, snapshot) {
        String? detectedUsername;
        int? uid;

        if (snapshot.hasData && snapshot.data != null) {
          uid = snapshot.data!;
          detectedUsername = 'u0_a${uid - 10000}';
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF313244),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: detectedUsername != null
                  ? const Color(0xFFA6E3A1).withOpacity(0.5)
                  : const Color(0xFFF9E2AF).withOpacity(0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    detectedUsername != null
                        ? Icons.person
                        : Icons.person_search,
                    color: detectedUsername != null
                        ? const Color(0xFFA6E3A1)
                        : const Color(0xFFF9E2AF),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    detectedUsername != null ? '偵測到的 SSH 用戶名' : '無法自動偵測用戶名',
                    style: TextStyle(
                      color: detectedUsername != null
                          ? const Color(0xFFA6E3A1)
                          : const Color(0xFFF9E2AF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (uid != null)
                    Text(
                      'UID: $uid',
                      style: const TextStyle(
                        color: Color(0xFF6C7086),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        detectedUsername ?? '請手動輸入',
                        style: TextStyle(
                          color: detectedUsername != null
                              ? Colors.white
                              : const Color(0xFF6C7086),
                          fontFamily: 'JetBrains Mono',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () =>
                        _showUsernameEditDialog(context, detectedUsername),
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('修改'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF89B4FA),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '💡 如果連線失敗，請在 Termux 執行 whoami 確認用戶名',
                style: TextStyle(
                  color: Color(0xFF6C7086),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show dialog to edit username manually
  void _showUsernameEditDialog(BuildContext context, String? currentUsername) {
    final controller = TextEditingController(text: currentUsername);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('設定 SSH 用戶名', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '請輸入您在 Termux 執行 whoami 顯示的用戶名：',
              style: TextStyle(color: Color(0xFFBAC2DE), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'JetBrains Mono'),
              decoration: InputDecoration(
                hintText: '例如: u0_a1192',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF313244),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final username = controller.text.trim();
              if (username.isNotEmpty) {
                await SSHService.saveUsername(username);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已儲存用戶名: $username')),
                  );
                  // Force rebuild
                  setState(() {});
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF89B4FA),
              foregroundColor: const Color(0xFF1E1E2E),
            ),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(SetupState state) {
    switch (state.currentStep) {
      case SetupStep.welcome:
        return _buildWelcomeStep();
      case SetupStep.environmentCheck:
        return _buildEnvironmentCheckStep();
      case SetupStep.termux:
        return _buildTermuxStep(state);
      case SetupStep.ssh:
        return _buildSSHStep(state);
      case SetupStep.termuxPermission:
        return _buildTermuxPermissionStep();
      case SetupStep.dependencies:
        return _buildDependenciesStep(state);
      case SetupStep.flutter:
        return _buildFlutterStep(state);
      case SetupStep.x11:
        return _buildX11Step(state);
      case SetupStep.complete:
        return _buildCompleteStep();
    }
  }

  Widget _buildTermuxPermissionStep() {
    return Consumer(
      builder: (context, ref, child) {
        final state = ref.watch(setupServiceProvider);
        
        if (state.isInstalling && state.currentStep == SetupStep.termuxPermission) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF89B4FA)),
              const SizedBox(height: 24),
              const Text(
                '正在設定權限...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFCDD6F4),
                ),
              ),
              const SizedBox(height: 16),
              _buildLogWindow(state.installLog ?? ''),
            ],
          );
        }

        const command =
            'echo "allow-external-apps = true" >> ~/.termux/termux.properties && termux-reload-settings';

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security, size: 64, color: Color(0xFFF9E2AF)),
          const SizedBox(height: 24),
          const Text(
            '啟用外部應用權限',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '為了讓 IDE 能夠在 Termux 中執行指令，\n需要在 Termux 中啟用外部應用權限。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBAC2DE), height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF11111B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF313244)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '請在 Termux 中執行以下指令：',
                  style: TextStyle(color: Color(0xFFBAC2DE), fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildCodeBlock(command),
                const SizedBox(height: 16),
                const Text(
                  '💡 提示：此權限只能手動設定，無法自動完成。\n設定後請繼續下一步。',
                  style: TextStyle(
                    color: Color(0xFFF9E2AF),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Test Connection Button
          ElevatedButton.icon(
            onPressed: () => ref.read(setupServiceProvider.notifier).verifyTermuxConnection(),
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('測試連線 (設定完成後點擊)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9E2AF),
              foregroundColor: const Color(0xFF1E1E2E),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: command));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已複製指令到剪貼簿')),
              );
              ref.read(termuxBridgeProvider).openTermux();
            },
            icon: const Icon(Icons.terminal, size: 20),
            label: const Text('複製指令並開啟 Termux'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89B4FA),
              foregroundColor: const Color(0xFF1E1E2E),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => ref.read(setupServiceProvider.notifier).nextStep(),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('我已完成設定，繼續'),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFBAC2DE)),
          ),
        ],
      ),
    );
      },
    );
  }


  Widget _buildLogWindow(String log) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11111B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF313244)),
      ),
      height: 120,
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 500),
      child: SingleChildScrollView(
        reverse: true,
        child: Text(
          log,
          style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11,
              color: Color(0xFFA6ADC8)),
        ),
      ),
    );
  }

  Widget _buildDependenciesStep(SetupState state) {
    if (state.isInstalling) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF89B4FA)),
          const SizedBox(height: 24),
          const Text(
            '正在修復環境與安裝依賴...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
          const SizedBox(height: 16),
          _buildLogWindow(state.installLog ?? ''),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.build_circle, size: 64, color: Color(0xFFA6E3A1)),
          const SizedBox(height: 24),
          const Text(
            '環境依賴檢查',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '為了確保 IDE 正常運作，我們需要檢查並安裝以下組件：\n\n• Git (版本控制)\n• 編譯器 (Clang, CMake, Ninja)\n• GUI 函式庫 (GTK3)\n• Dart SDK (LSP 語言服務支援)\n• 系統套件更新 (pkg upgrade)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBAC2DE), height: 1.5),
          ),
          const SizedBox(height: 32),
          if (state.isGitInstalled) ...[
             Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA6E3A1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                   Icon(Icons.check_circle, color: Color(0xFFA6E3A1)),
                   SizedBox(width: 12),
                   Text(
                    'Git 已安裝且環境正常',
                    style: TextStyle(color: Color(0xFFA6E3A1), fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => ref.read(setupServiceProvider.notifier).nextStep(),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('繼續下一步'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA),
                foregroundColor: const Color(0xFF1E1E2E),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ] else ...[
             const Text(
              '檢測到 Git 缺失或環境依賴未滿足',
              style: TextStyle(color: Color(0xFFF38BA8), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(setupServiceProvider.notifier).installDependencies(),
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('一鍵修復環境 (推薦)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA6E3A1),
                foregroundColor: const Color(0xFF1E1E2E),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
             const SizedBox(height: 16),
             TextButton(
              onPressed: () => ref.read(setupServiceProvider.notifier).nextStep(),
              child: const Text('略過 (不推薦)'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF6C7086)),
            ),
          ],
        ],
      ),
    );
  }

  /// Build the environment check step
  Widget _buildEnvironmentCheckStep() {
    return EnvironmentCheckStep(
      onAllPassed: () {
        // All checks passed, proceed to next step
        ref.read(setupServiceProvider.notifier).nextStep();
      },
      onContinueAnyway: () {
        // User wants to continue despite warnings
        ref.read(setupServiceProvider.notifier).nextStep();
      },
    );
  }

  Widget _buildTermuxStep(SetupState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.android, size: 64, color: Color(0xFFF9E2AF)),
        const SizedBox(height: 24),
        const Text(
          '未檢測到 Termux',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFCDD6F4),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '本應用需要 Termux 環境才能運行。\n請先安裝 Termux (推薦 F-Droid 版本)。',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFBAC2DE)),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => launchUrl(
              Uri.parse('https://f-droid.org/en/packages/com.termux/')),
          icon: const Icon(Icons.download),
          label: const Text('前往 F-Droid 下載'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF89B4FA),
            foregroundColor: const Color(0xFF1E1E2E),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => ref.read(setupServiceProvider.notifier).nextStep(),
          child: const Text('我已安裝，繼續下一步'),
        ),
      ],
    );
  }

  Widget _buildX11Step(SetupState state) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.desktop_windows, size: 64, color: Color(0xFFCBA6F7)),
          const SizedBox(height: 24),
          const Text(
            '圖形介面 (X11) 設定',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '為了顯示 Flutter 應用程式的畫面，\n需要安裝 X11 顯示伺服器。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBAC2DE), height: 1.5),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF313244)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  '1. 必需的依賴套件',
                  '請在 Termux 中執行：',
                ),
                const SizedBox(height: 8),
                _buildCodeBlock(
                    'pkg install x11-repo && pkg install termux-x11-nightly pulseaudio -y'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: state.isInstalling
                        ? null
                        : () {
                            ref
                                .read(setupServiceProvider.notifier)
                                .installX11();
                          },
                    icon: state.isInstalling 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('一鍵安裝 X11 (自動修復)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCBA6F7),
                      foregroundColor: const Color(0xFF1E1E2E),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  '2. 安裝 Termux:X11 App',
                  '請下載並安裝配套的 Android 應用程式：',
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => launchUrl(
                      Uri.parse(
                          'https://github.com/termux/termux-x11/releases'),
                      mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.download),
                  label: const Text('前往 GitHub 下載'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF89B4FA),
                    foregroundColor: const Color(0xFF1E1E2E),
                  ),
                ),
                if (state.isInstalling) ...[
                  const SizedBox(height: 24),
                  const LinearProgressIndicator(color: Color(0xFFCBA6F7)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF11111B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF313244)),
                    ),
                    height: 100,
                    width: double.infinity,
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Text(
                        state.installLog ?? '',
                        style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            color: Color(0xFFA6ADC8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: state.isInstalling 
                  ? null 
                  : () => ref.read(setupServiceProvider.notifier).nextStep(),
                child: const Text('略過 (僅命令列)'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: state.isInstalling
                  ? null
                  : () => ref.read(setupServiceProvider.notifier).nextStep(),
                icon: const Icon(Icons.check),
                label: const Text('我已完成設定，下一步'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA6E3A1),
                  foregroundColor: const Color(0xFF1E1E2E),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFFBAC2DE),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.rocket_launch, size: 64, color: Color(0xFF89B4FA)),
        const SizedBox(height: 24),
        const Text(
          '歡迎使用 Termux Flutter IDE',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFCDD6F4),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '此嚮導將協助您在 Termux 環境中配置 Flutter 開發環境。\n我們將檢查 SSH 連線並安裝必要的工具。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFFBAC2DE),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSSHStep(SetupState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            state.isSSHConnected ? Icons.link : Icons.link_off,
            size: 56,
            color: state.isSSHConnected
                ? const Color(0xFFA6E3A1)
                : const Color(0xFFF9E2AF),
          ),
          const SizedBox(height: 16),
          Text(
            state.isSSHConnected ? 'SSH 已連線' : '尚未連線到 Termux',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
          const SizedBox(height: 24),
          if (!state.isSSHConnected) ...[
            // Main Action Area
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF313244)),
              ),
              child: Column(
                children: [
                  const Text(
                    '1. 在 Termux 執行指令 (Port: 8022)',
                    style: TextStyle(
                        color: Color(0xFFBAC2DE), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildCodeBlock('pkg install openssh -y && passwd && sshd'),
                  const SizedBox(height: 12),
                  const Text(
                    '注意：若手動設定，請將密碼設為 termux',
                    style: TextStyle(
                        color: Color(0xFFF38BA8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Username Preview/Edit Section
                  _buildUsernamePreviewSection(),

                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: state.isInstalling
                        ? null
                        : () async {
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('開始自動配置'),
                                content: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('IDE 將在背景嘗試設定 Termux SSH 環境。'),
                                    SizedBox(height: 12),
                                    Text('請留意通知列，若有 Termux 權限請求請允許。',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('開始配置'),
                                  ),
                                ],
                              ),
                            );

                            if (proceed != true) return;

                            ref
                                .read(setupServiceProvider.notifier)
                                .setInstalling(true);

                            // Step 1: Send setup command (fire-and-forget)
                            await ref
                                .read(termuxBridgeProvider)
                                .setupTermuxSSH();

                            // Step 2: Wait for sshd to start
                            await Future.delayed(const Duration(seconds: 4));

                            // Step 3: VERIFY by actually trying SSH connection
                            final sshService = ref.read(sshServiceProvider);
                            try {
                              await sshService.connect();

                              // Step 4: Generate and deploy SSH keys for future connections
                              try {
                                final keyManager = sshService.keyManager;
                                if (!await keyManager.hasKeys()) {
                                  // Generate keys in Termux and retrieve them
                                  final keyGenCmd =
                                      keyManager.getKeyGenerationCommand();
                                  final output =
                                      await sshService.execute(keyGenCmd);

                                  // Parse and store the keys
                                  final stored = await keyManager
                                      .parseAndStoreKeys(output);
                                  if (stored) {
                                    print(
                                        'SetupWizard: SSH keys generated and stored successfully');
                                  } else {
                                    print(
                                        'SetupWizard: Key generation output parsing failed, password auth will be used');
                                  }
                                }
                              } catch (keyError) {
                                print(
                                    'SetupWizard: Key generation failed: $keyError, password auth will be used');
                              }

                              // SUCCESS!
                              ref
                                  .read(setupServiceProvider.notifier)
                                  .setInstalling(false);
                              await ref
                                  .read(setupServiceProvider.notifier)
                                  .checkEnvironment();

                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E2E),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Color(0xFFA6E3A1)),
                                        SizedBox(width: 12),
                                        Text('連線成功！',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                    content: const Text(
                                      'SSH 環境已成功設定，您可以繼續下一步。',
                                      style:
                                          TextStyle(color: Color(0xFFBAC2DE)),
                                    ),
                                    actions: [
                                      FilledButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFA6E3A1),
                                          foregroundColor:
                                              const Color(0xFF1E1E2E),
                                        ),
                                        child: const Text('太好了'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              // FAILED - show diagnostics
                              ref
                                  .read(setupServiceProvider.notifier)
                                  .setInstalling(false);

                              final diagService = ConnectionDiagnosticsService(
                                  ref.read(termuxBridgeProvider));
                              final diag = diagService.fromError(e);

                              if (context.mounted) {
                                _showDiagnosticsDialog(context, diag);
                              }
                            }
                          },
                    icon: state.isInstalling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF1E1E2E)))
                        : const Icon(Icons.build_circle, size: 20),
                    label:
                        Text(state.isInstalling ? '正在配置中...' : '2. 嘗試自動配置 SSH'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF89B4FA),
                      foregroundColor: const Color(0xFF1E1E2E),
                      minimumSize: const Size(double.infinity, 48),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Secondary Actions (Troubleshooting)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text(
                  '遇到問題？(權限與密碼)',
                  style: TextStyle(
                    color: Color(0xFF6C7086),
                    fontSize: 14,
                  ),
                ),
                iconColor: const Color(0xFF6C7086),
                collapsedIconColor: const Color(0xFF6C7086),
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    '若 "自動配置 SSH" 無反應：',
                    style: TextStyle(
                        color: Color(0xFFBAC2DE), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '請確認已在「權限設定」步驟中執行指令並啟用 "Allow external apps"，否則 Ide 無法控制 Termux。',
                    style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '若遇到 "Display over other apps" 錯誤：',
                    style: TextStyle(color: Color(0xFF7F849C), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      const termuxPackage = 'com.termux';
                      final intent = AndroidIntent(
                        action:
                            'android.settings.action.MANAGE_OVERLAY_PERMISSION',
                        package: termuxPackage,
                        data: 'package:$termuxPackage',
                      );
                      await intent.launch();
                    },
                    icon: const Icon(Icons.layers_outlined, size: 18),
                    label: const Text('授權懸浮視窗'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFBAC2DE),
                      side: const BorderSide(color: Color(0xFF45475A)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '手動設定提醒：',
                    style: TextStyle(
                        color: Color(0xFFBAC2DE), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '如果自動配置失敗，請在 Termux 執行 passwd 並將密碼設為 termux，然後執行 sshd 啟動服務。',
                    style: TextStyle(color: Color(0xFFA6ADC8), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlutterStep(SetupState state) {
    if (state.isFlutterInstalled) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Color(0xFFA6E3A1)),
          const SizedBox(height: 24),
          const Text(
            'Flutter 已安裝',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '您的開發環境已準備就緒！',
            style: TextStyle(color: Color(0xFFBAC2DE)),
          ),
        ],
      );
    }

    if (state.isInstalling) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF89B4FA)),
          const SizedBox(height: 24),
          const Text(
            '正在安裝 Flutter...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '安裝過程可能需要 10-20 分鐘\n請確保網路連線穩定，並保持 Termux 在前台',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBAC2DE), height: 1.5),
          ),
          const SizedBox(height: 16),
          if (state.installLog != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF11111B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF313244)),
              ),
              height: 120,
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  state.installLog!,
                  style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: Color(0xFFA6ADC8)),
                ),
              ),
            ),
          const SizedBox(height: 24),
          // Add a button to manually trigger check, especially useful for Bridge flow
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(setupServiceProvider.notifier).checkEnvironment(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('我已在 Termux 完成安裝，點此檢測'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF89B4FA),
              side: const BorderSide(color: Color(0xFF89B4FA)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      );
    }

    // Not installed yet - show install options
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.installLog != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF11111B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFF38BA8)), // Red border for error
              ),
              height: 100,
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  state.installLog!,
                  style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: Color(0xFFF38BA8)), // Red text
                ),
              ),
            ),
          const Icon(Icons.flutter_dash, size: 64, color: Color(0xFF89B4FA)),
          const SizedBox(height: 24),
          const Text(
            '安裝 Flutter SDK',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFCDD6F4),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '點擊下方按鈕將自動安裝 Flutter 開發環境\n(使用 termux-flutter-wsl 腳本)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBAC2DE), height: 1.5),
          ),
          const SizedBox(height: 32),

          // Primary action - Install Flutter
          ElevatedButton.icon(
            onPressed: () {
              // Use SetupService method to install Flutter
              ref.read(setupServiceProvider.notifier).installFlutter();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已開始安裝，請查看 Termux 應用程式'),
                  duration: Duration(seconds: 5),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text('一鍵安裝 Flutter', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89B4FA),
              foregroundColor: const Color(0xFF1E1E2E),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Secondary actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () =>
                    ref.read(setupServiceProvider.notifier).checkEnvironment(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新檢測'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFBAC2DE)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () =>
                    ref.read(setupServiceProvider.notifier).nextStep(),
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('我已安裝 (跳過)'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFBAC2DE)),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Manual install instructions (collapsed by default)
          ExpansionTile(
            title: const Text(
              '進階選項：手動安裝',
              style: TextStyle(color: Color(0xFF6C7086), fontSize: 14),
            ),
            iconColor: const Color(0xFF6C7086),
            collapsedIconColor: const Color(0xFF6C7086),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF11111B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF313244)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '在 Termux 中執行以下指令：',
                      style: TextStyle(color: Color(0xFFBAC2DE), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    _buildCodeBlock(
                      'curl -sL https://raw.githubusercontent.com/ImL1s/termux-flutter-wsl/master/install_termux_flutter.sh | bash',
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(termuxBridgeProvider).openTermux();
                      },
                      icon: const Icon(Icons.terminal, size: 16),
                      label: const Text('開啟 Termux'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF89B4FA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.celebration, size: 64, color: Color(0xFFA6E3A1)),
        const SizedBox(height: 24),
        const Text(
          '設置完成！',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFCDD6F4),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '您現在可以開始使用 Termux Flutter IDE 開發應用程式了。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFFBAC2DE),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(SetupState state) {
    if (state.currentStep == SetupStep.welcome) {
      return ElevatedButton(
        onPressed: () => ref.read(setupServiceProvider.notifier).nextStep(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF89B4FA),
          foregroundColor: const Color(0xFF1E1E2E),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        child: const Text('開始設置'),
      );
    }

    if (state.currentStep == SetupStep.termuxPermission) {
      return ElevatedButton(
        onPressed: () => ref.read(setupServiceProvider.notifier).nextStep(),
        child: const Text('我已啟用，下一步'),
      );
    }

    if (state.currentStep == SetupStep.ssh) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: () =>
                ref.read(setupServiceProvider.notifier).retryConnection(),
            child: const Text('重試連線'),
          ),
          const SizedBox(width: 16),
          if (state.isSSHConnected)
            ElevatedButton(
              onPressed: () =>
                  ref.read(setupServiceProvider.notifier).nextStep(),
              child: const Text('下一步'),
            )
          else
            TextButton(
              onPressed: () =>
                  ref.read(setupServiceProvider.notifier).nextStep(),
              child: const Text('跳過 (使用 Bridge)'),
            ),
        ],
      );
    }

    if (state.currentStep == SetupStep.flutter) {
      if (state.isFlutterInstalled) {
        return ElevatedButton(
          onPressed: () => ref.read(setupServiceProvider.notifier).nextStep(),
          child: const Text('下一步'),
        );
      }
      return const SizedBox
          .shrink(); // Action is inside content (install button)
    }

    if (state.currentStep == SetupStep.complete) {
      return ElevatedButton(
        onPressed: () {
          // Close wizard
          Navigator.of(context).pop();
          // In a real app routing, we might configure GoRouter to redirect
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFA6E3A1),
          foregroundColor: const Color(0xFF1E1E2E),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        child: const Text('開始 Coding'),
      );
    }

    return const SizedBox.shrink();
  }
}
