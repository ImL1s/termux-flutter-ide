import 'dart:io';

/// Android 裝置相容性服務
///
/// 提供 Android 系統和 OEM 廠商特定問題的偵測和解決方案
class AndroidCompatibilityService {
  /// Android 版本
  static int get androidVersion {
    // Platform.version 不適用於 Android SDK 版本
    // 我們通過 MethodChannel 獲取或使用預設值
    return 12; // 預設假設 Android 12+
  }

  /// 偵測 OEM 廠商
  static OemVendor detectOemVendor() {
    final brand = _getBrand().toLowerCase();
    final manufacturer = _getManufacturer().toLowerCase();

    if (brand.contains('xiaomi') ||
        brand.contains('redmi') ||
        brand.contains('poco')) {
      return OemVendor.xiaomi;
    } else if (brand.contains('huawei') || brand.contains('honor')) {
      return OemVendor.huawei;
    } else if (brand.contains('oppo') ||
        brand.contains('realme') ||
        brand.contains('oneplus')) {
      return OemVendor.oppo;
    } else if (brand.contains('samsung')) {
      return OemVendor.samsung;
    } else if (brand.contains('vivo')) {
      return OemVendor.vivo;
    } else if (brand.contains('asus')) {
      return OemVendor.asus;
    } else if (brand.contains('google') || brand.contains('pixel')) {
      return OemVendor.google;
    }

    return OemVendor.other;
  }

  static String _getBrand() {
    // 在實際 Android 環境中這會通過 MethodChannel 獲取
    // 這裡提供 fallback
    try {
      return Platform.environment['BRAND'] ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  static String _getManufacturer() {
    try {
      return Platform.environment['MANUFACTURER'] ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// 獲取 OEM 廠商特定的省電設定指引
  static OemGuidance getOemGuidance(OemVendor vendor) {
    switch (vendor) {
      case OemVendor.xiaomi:
        return const OemGuidance(
          vendorName: '小米/Redmi/POCO',
          hasAggressiveBatteryManagement: true,
          steps: [
            '設定 → 應用設定 → 應用管理 → Termux',
            '關閉「省電策略」- 選擇「無限制」',
            '啟用「自動啟動」',
            '鎖定 Termux 在最近任務列表（向下拖動）',
          ],
          settingsPath: '設定 → 電池與性能 → 場景配置',
          dontkillmyappUrl: 'https://dontkillmyapp.com/xiaomi',
        );
      case OemVendor.huawei:
        return const OemGuidance(
          vendorName: '華為/榮耀',
          hasAggressiveBatteryManagement: true,
          steps: [
            '設定 → 應用 → 應用啟動管理',
            '找到 Termux → 切換為「手動管理」',
            '啟用所有三個選項（自動啟動、關聯啟動、背景活動）',
            '設定 → 電池 → 啟動管理 → 允許 Termux 背景運行',
          ],
          settingsPath: '設定 → 電池 → 應用啟動管理',
          dontkillmyappUrl: 'https://dontkillmyapp.com/huawei',
        );
      case OemVendor.oppo:
        return const OemGuidance(
          vendorName: 'OPPO/realme/OnePlus',
          hasAggressiveBatteryManagement: true,
          steps: [
            '設定 → 電池 → 更多電池設定',
            '關閉「優化電池使用」for Termux',
            '設定 → 應用管理 → Termux → 省電',
            '選擇「允許背景活動」',
          ],
          settingsPath: '設定 → 電池',
          dontkillmyappUrl: 'https://dontkillmyapp.com/oppo',
        );
      case OemVendor.samsung:
        return const OemGuidance(
          vendorName: '三星',
          hasAggressiveBatteryManagement: true,
          steps: [
            '設定 → 電池與裝置維護 → 電池',
            '背景使用限制 → 「永不休眠的應用程式」',
            '添加 Termux',
            '(可選) 關閉「自動優化」',
          ],
          settingsPath: '設定 → 電池',
          dontkillmyappUrl: 'https://dontkillmyapp.com/samsung',
        );
      case OemVendor.vivo:
        return const OemGuidance(
          vendorName: 'Vivo',
          hasAggressiveBatteryManagement: true,
          steps: [
            '設定 → 更多設定 → 應用程式 → 高耗電',
            '將 Termux 設為「允許」',
            '設定 → 電池 → 高耗電管理',
          ],
          settingsPath: '設定 → 電池',
          dontkillmyappUrl: 'https://dontkillmyapp.com/vivo',
        );
      case OemVendor.asus:
        return const OemGuidance(
          vendorName: 'ASUS',
          hasAggressiveBatteryManagement: true,
          steps: [
            '設定 → 電池 → PowerMaster',
            '自動啟動管理器 → 啟用 Termux',
          ],
          settingsPath: '設定 → 電池',
          dontkillmyappUrl: 'https://dontkillmyapp.com/asus',
        );
      case OemVendor.google:
        return const OemGuidance(
          vendorName: 'Google Pixel',
          hasAggressiveBatteryManagement: false,
          steps: [
            '設定 → 應用程式 → Termux → 電池',
            '選擇「無限制」',
          ],
          settingsPath: '設定 → 電池',
          dontkillmyappUrl: 'https://dontkillmyapp.com/google',
        );
      case OemVendor.other:
        return const OemGuidance(
          vendorName: '其他',
          hasAggressiveBatteryManagement: false,
          steps: [
            '設定 → 應用程式 → Termux → 電池',
            '選擇「無限制」或「不優化」',
          ],
          settingsPath: '設定 → 電池',
          dontkillmyappUrl: 'https://dontkillmyapp.com',
        );
    }
  }

  /// 檢測是否是 Phantom Process Killer 導致的問題
  static bool isPhantomProcessKillerIssue(String errorMessage) {
    // Signal 9 (SIGKILL) 通常是 Phantom Process Killer 的標誌
    final patterns = [
      'signal 9',
      'SIGKILL',
      'Process completed (signal 9)',
      'Killed',
    ];

    final lowerError = errorMessage.toLowerCase();
    return patterns.any((p) => lowerError.contains(p.toLowerCase()));
  }

  /// 獲取 Phantom Process Killer 修復指南
  static String getPhantomProcessKillerFix() {
    return '''
Android 12+ 的「Phantom Process Killer」正在終止 Termux 進程。

修復方法：

方法 1：開發者選項（推薦）
1. 設定 → 關於手機 → 點擊「版本號碼」7 次啟用開發者選項
2. 設定 → 開發者選項 → 停用子程序限制

方法 2：ADB 指令（需連接電腦）
\$ adb shell "settings put global settings_enable_monitor_phantom_procs false"

方法 3：保持 Termux 前景運行
執行 termux-wake-lock 指令
''';
  }
}

/// OEM 廠商枚舉
enum OemVendor {
  xiaomi,
  huawei,
  oppo,
  samsung,
  vivo,
  asus,
  google,
  other,
}

/// OEM 指引資料類
class OemGuidance {
  final String vendorName;
  final bool hasAggressiveBatteryManagement;
  final List<String> steps;
  final String settingsPath;
  final String dontkillmyappUrl;

  const OemGuidance({
    required this.vendorName,
    required this.hasAggressiveBatteryManagement,
    required this.steps,
    required this.settingsPath,
    required this.dontkillmyappUrl,
  });
}
