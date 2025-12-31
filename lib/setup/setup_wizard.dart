import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../termux/termux_providers.dart';
import 'setup_service.dart';

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
              if (step != SetupStep.x11) // Last step before complete
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

  Widget _buildStepContent(SetupState state) {
    switch (state.currentStep) {
      case SetupStep.welcome:
        return _buildWelcomeStep();
      case SetupStep.termux:
        return _buildTermuxStep(state);
      case SetupStep.ssh:
        return _buildSSHStep(state);
      case SetupStep.termuxPermission:
        return _buildTermuxPermissionStep();
      case SetupStep.flutter:
        return _buildFlutterStep(state);
      case SetupStep.x11:
        // If we added X11 step UI
        return const SizedBox();
      case SetupStep.complete:
        return _buildCompleteStep();
    }
  }

  Widget _buildTermuxPermissionStep() {
    const command =
        'echo "allow-external-apps=true" >> ~/.termux/termux.properties && termux-reload-settings';

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
                  '💡 提示：執行後需重啟 Termux 或執行 termux-reload-settings',
                  style: TextStyle(
                    color: Color(0xFF6C7086),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          state.isSSHConnected ? Icons.link : Icons.link_off,
          size: 64,
          color: state.isSSHConnected
              ? const Color(0xFFA6E3A1)
              : const Color(0xFFF9E2AF),
        ),
        const SizedBox(height: 24),
        Text(
          state.isSSHConnected ? 'SSH 已連線' : '尚未連線到 Termux',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFCDD6F4),
          ),
        ),
        const SizedBox(height: 16),
        if (!state.isSSHConnected) ...[
          const Text(
            '請在 Termux App 中執行以下命令以開啟 SSH 服務：',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBAC2DE)),
          ),
          const SizedBox(height: 16),
          _buildCodeBlock('pkg install openssh -y && sshd'),
          const SizedBox(height: 16),
          const Text(
            '並確認已設定密碼 (執行 passwd)',
            style: TextStyle(color: Color(0xFFBAC2DE), fontSize: 12),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(termuxBridgeProvider).setupTermuxSSH();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已發送安裝指令，請查看 Termux')),
              );
            },
            icon: const Icon(Icons.build),
            label: const Text('嘗試自動配置 SSH'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF89B4FA),
              foregroundColor: const Color(0xFF1E1E2E),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ],
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
        ],
      );
    }

    // Not installed yet - show install options
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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

          // Secondary action - Check again
          TextButton.icon(
            onPressed: () =>
                ref.read(setupServiceProvider.notifier).checkEnvironment(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重新檢測'),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFBAC2DE)),
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
                      'curl -sL https://raw.githubusercontent.com/ImL1s/termux-flutter-wsl/main/install_termux_flutter.sh | bash',
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
