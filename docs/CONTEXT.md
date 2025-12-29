# 專案背景與資源研究

## 📋 專案起源

此專案旨在結合以下兩個專案，打造 Android 上完整的 Flutter IDE：

1. **[termux-app](https://github.com/termux/termux-app)** - Android 終端模擬器
2. **[termux-flutter-wsl](https://github.com/ImL1s/termux-flutter-wsl)** - 世界首個完整的 Termux Flutter 開發環境

### termux-flutter-wsl 能力

```
📱 Android 設備
    ↓
🖥️ Termux 終端
    ↓
✍️ 編寫程式碼 (vim/nano/code-server)
    ↓
🔥 flutter run → Hot Reload!
    ↓
📦 flutter build apk → 產出 APK
    ↓
📲 直接安裝測試
```

**特點：**
- Flutter 3.35.0+ 完整支援
- `flutter build apk` 在 ARM64 原生運行
- Hot Reload 支援
- 不需要電腦、模擬器或雲端服務

---

## 🔍 可用資源研究結果

### 方案一：Flutter 原生編輯器（✅ 採用）

直接用 Flutter 建構 IDE 介面：

| 套件 | 功能 | 連結 |
|------|------|------|
| **flutter_code_editor** | 100+ 語言語法高亮、程式碼摺疊、自動完成、主題 | [akvelon/flutter-code-editor](https://github.com/akvelon/flutter-code-editor) |
| **Re-Editor** | 輕量級文字/程式碼編輯器 | [pub.dev](https://pub.dev/packages/re_editor) |
| **syntax_highlight** | TextMate 規則語法高亮 | [pub.dev](https://pub.dev/packages/syntax_highlight) |
| **xterm** | 終端機模擬器 | [pub.dev](https://pub.dev/packages/xterm) |

### 方案二：Web 編輯器整合

| 工具 | 說明 | 適用場景 |
|------|------|----------|
| **code-server** | VS Code Web 版，可在 Termux 運行 | 需要完整 VS Code 體驗 |
| **Monaco Editor** | VS Code 核心編輯器 | 透過 WebView 嵌入 |

### 方案三：現有 Android 編輯器

| 應用 | 說明 | 連結 |
|------|------|------|
| **Acode** | 開源 Android 程式碼編輯器，支援 Dart | [acode.app](https://acode.app) |
| **Acode Dart Plugin** | Dart 語言支援、自動完成、格式化 | [acode.app/plugin](https://acode.app/plugin/acode.dart) |

---

## 🏗️ 技術決策

### 為什麼選擇 Flutter 原生 IDE？

1. ✅ 可直接使用 `flutter_code_editor` 提供完整編輯功能
2. ✅ 與 Termux 深度整合（透過 Intent 或 Plugin）
3. ✅ 原生 UI 效能最佳
4. ✅ 可搭配 `termux-flutter-wsl` 無縫運作
5. ✅ 未來可擴展到其他平台

### 採用的套件版本（2024-12 最新）

| 套件 | 版本 | 說明 |
|------|------|------|
| flutter_code_editor | 0.3.5 | 2025-09 發布 |
| flutter_riverpod | 3.1.0 | 2025-12 發布，使用新 Notifier API |
| go_router | 17.0.1 | 2025 最新 |
| xterm | 4.0.0 | 2024-02 發布 |
| file_picker | 10.3.8 | 2025 最新 |

---

## 🔗 Termux 整合方案

### 方案 A：Intent 通訊

```dart
// 發送指令到 Termux
Intent intent = Intent();
intent.setClassName("com.termux", "com.termux.app.RunCommandService");
intent.setAction("com.termux.RUN_COMMAND");
intent.putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/flutter");
intent.putExtra("com.termux.RUN_COMMAND_ARGUMENTS", ["run"]);
```

### 方案 B：Termux:API 整合

使用 [termux-api](https://github.com/termux/termux-api) 套件進行更深度的系統整合。

### 方案 C：Socket IPC

本地 Unix Socket 通訊，適合複雜的雙向資料交換。

---

## 📚 參考專案

### 核心依賴
- [flutter_code_editor](https://github.com/akvelon/flutter-code-editor) - 程式碼編輯器套件
- [xterm.dart](https://github.com/nicklockwood/xterm.dart) - 終端機模擬
- [riverpod](https://riverpod.dev) - 狀態管理

### 相關專案
- [termux-flutter-wsl](https://github.com/ImL1s/termux-flutter-wsl) - Termux Flutter 環境
- [termux-app](https://github.com/termux/termux-app) - Android 終端模擬器
- [termux-api](https://github.com/termux/termux-api) - Termux API 套件
- [code-server](https://github.com/coder/code-server) - VS Code Web 版

### 靈感來源
- [Acode](https://github.com/nicklockwood/Acode) - Android 開源程式碼編輯器
- [DartPad](https://dartpad.dev) - 線上 Dart/Flutter 編輯器

---

## 📝 開發筆記

### 2024-12-30 初始建立

- 建立 Flutter 專案，使用 FVM 3.38.5
- 整合 flutter_code_editor 0.3.5
- 實作基礎 UI：編輯器、檔案樹、終端機
- 使用 Riverpod 3.x NotifierProvider（StateProvider 已棄用）
- APK 建置成功

### TODO

1. **Termux Bridge** - 實作與 Termux 的通訊
2. **檔案系統** - 真實檔案讀寫
3. **Dart 分析器** - 整合 Analysis Server
4. **專案管理** - 開啟/建立專案功能
