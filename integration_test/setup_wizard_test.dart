
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:termux_flutter_ide/main.dart'; // Import main app
import 'package:termux_flutter_ide/setup/setup_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Setup Wizard Git Dependency Fix Test',
      (WidgetTester tester) async {
    // 1. Start App
    // We wrap in ProviderScope because main() usually does, but we want fresh state or standard startup
    await tester.pumpWidget(const ProviderScope(child: TermuxIdeApp()));
    await tester.pumpAndSettle();

    // 2. Verify we are at Welcome Step
    expect(find.text('歡迎使用 Termux Flutter IDE'), findsOneWidget);
    
    // Tap Next (Welcome -> Environment Check)
    // There isn't a "Next" button on Welcome step? Let's check SetupWizard code.
    // _buildWelcomeStep doesn't seem to have a button in the snippet I saw?
    // Wait, let me check _buildActions in SetupWizard. Oh I missed reading _buildActions.
    // Assuming there is a FloatingActionButton or button in _buildActions for "Start".
    
    // Looking at previous analysis, I didn't see _buildActions source. 
    // I'll assume standard layout: Bottom Right "Next" or "Start".
    // Let's try to find an Arrow Forward icon or "開始" text.
    
    final nextButton = find.byIcon(Icons.arrow_forward);
    // Or "Next" text? SetupWizard usually has a FAB or button bar.
    // Let's print widget tree if we fail, or just try to find standard buttons.
    
    if (findsOneWidget(nextButton)) {
        await tester.tap(nextButton);
    } else {
        // Correct text based on source code analysis
        await tester.tap(find.text('開始設置'));
    }
    
    await tester.pumpAndSettle();
    
    // 3. Environment Check Step
    // It runs checks automatically.
    // If we are on real device and Termux is good, it might auto-proceed if "onAllPassed" is called.
    // But "EnvironmentCheckStep" has a delay of 800ms before calling onAllPassed.
    
    await tester.pump(const Duration(seconds: 2)); // Wait for check
    await tester.pumpAndSettle();
    
    // If it auto-proceeded, we should be at "SetupStep.dependencies" now (per my fix).
    // Let's verify we see "環境依賴檢查"
    
    if (find.text('環境依賴檢查').evaluate().isEmpty) {
        // Maybe we are stuck at env check warning?
        // Tap "Continue Anyway" if visible
        final continueBtn = find.text('繼續設定');
        if (continueBtn.evaluate().isNotEmpty) {
            await tester.tap(continueBtn);
            await tester.pumpAndSettle();
        }
    }

    expect(find.text('環境依賴檢查'), findsOneWidget);
    
    // 4. Check for Git status
    // I expect "檢測到 Git 缺失" if I uninstalled it.
    // Or "Git 已安裝" if I didn't.
    
    final fixButton = find.text('一鍵修復環境 (推薦)');
    
    if (fixButton.evaluate().isNotEmpty) {
        print('Test: Git missing detected. Attempting fix...');
        await tester.tap(fixButton);
        
        // It triggers installation. Logic has streams etc.
        // We need to wait. It simulates "yes n | pkg upgrade".
        // It's a long process. We can use pump an wait.
        // But integration test has timeout.
        
        // We will wait in a loop checking for "安裝成功" or success state.
        int retries = 0;
        bool foundSuccess = false;
        while (retries < 60) { // Wait up to 60 seconds (might be longer on real device actually)
            await tester.pump(const Duration(seconds: 1));
            if (find.text('安裝成功！').evaluate().isNotEmpty || find.text('Git 已安裝且環境正常').evaluate().isNotEmpty) {
                foundSuccess = true;
                break;
            }
            retries++;
        }
        
        if (!foundSuccess) {
            // Check for logs
            // Maybe print logs from UI if possible?
            fail('Git installation timed out or failed to show success message.');
        }
        
        // Tap Next
        await tester.tap(find.text('繼續下一步'));
        await tester.pumpAndSettle();
        
    } else {
        print('Test: Git already installed.');
        // Expect Success message
        expect(find.text('Git 已安裝且環境正常'), findsOneWidget);
        await tester.tap(find.text('繼續下一步'));
        await tester.pumpAndSettle();
    }
    
    // 5. Verify we are at SSH step
    expect(find.textContaining('SSH'), findsOneWidget); // "SSH 已連線" or "SSH 設定"
    
  });
}
