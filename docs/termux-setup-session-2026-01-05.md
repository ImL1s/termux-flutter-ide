# Termux Flutter 環境設定 Session 記錄

**日期**: 2026-01-05  
**目標**: 重新安裝 Termux 環境並配置 termux-flutter-wsl SDK

---

## 執行摘要

這次 session 的目標是完整重建 Termux 環境，專門用於 Flutter 開發。主要工作包括：

1. **清除舊環境並重新安裝 Termux**
2. **安裝 termux-flutter-wsl SDK**
3. **驗證環境配置**

---

## 完成的步驟

### Phase 1: Clean Termux Setup ✅

- 卸載現有的 Termux 應用程式
- 從 GitHub Releases 下載並安裝 Termux v0.118.3
- 啟動 Termux 並完成初始設定
- 在 `~/.termux/termux.properties` 中啟用 `allow-external-apps=true`

### Phase 2: Install termux-flutter-wsl ✅

執行了完整安裝腳本：

```bash
curl -sSL https://raw.githubusercontent.com/ImL1s/termux-flutter-wsl/master/install_flutter_complete.sh | bash
```

此腳本完成了：
- Flutter SDK 安裝（透過 `.deb` 套件）
- Android SDK 安裝
- ARM64 NDK 配置
- 環境變數設定（`ANDROID_HOME`, `PATH`）
- 測試 APK 建置驗證

**安裝時間**: 約 15-20 分鐘（在 ARM64 硬體上）

---

## IDE 程式碼修改

為確保 IDE 嚴格使用 `termux-flutter-wsl` SDK，進行了以下修改：

### 1. `lib/termux/termux_paths.dart`
- 將 `flutterHome` 設定為 `~/.termux_ide/flutter`
- 移除了 `/usr/opt/flutter` 的 fallback

### 2. `lib/run/launch_config.dart`
- 移除系統 Flutter 自動偵測邏輯
- 將 `userFlutterPath` 硬編碼為 `~/.termux_ide/flutter/bin/flutter`
- 配置名稱改為 'Flutter (Termux-WSL)'

### 3. `lib/termux/termux_bridge.dart`
- `executeCommand` 中的 `PATH` 注入更新為優先使用 `~/.termux_ide/flutter/bin`
- `isFlutterInstalled` 改為檢查 `~/.termux_ide/flutter/bin/flutter`
- `executeCommandStream` 也加入了 PATH 注入

---

## 待完成的步驟

### Phase 3: Configure X11

- [ ] 手動安裝 Termux:X11 APK
- [ ] 在 Termux 中執行 `pkg install termux-x11-nightly`
- [ ] 設定 `DISPLAY=:0` 環境變數
- [ ] 啟動 termux-x11 server
- [ ] 啟動 Termux:X11 app

### Phase 4: Verify Builds

- [ ] 建立測試 Flutter 專案：`flutter create test_app`
- [ ] 驗證 Linux 建置：`flutter build linux`
- [ ] 驗證 APK 建置：`flutter build apk --release`
- [ ] 記錄結果

---

## 重要路徑

| 項目 | 路徑 |
|------|------|
| Flutter SDK | `/data/data/com.termux/files/usr/opt/flutter` |
| Flutter symlink (IDE 使用) | `~/.termux_ide/flutter` |
| Android SDK | `$HOME/android-sdk` |
| NDK | `$HOME/android-sdk/ndk/27.0.12077973` |

---

## 驗證指令

```bash
# 檢查 Flutter 路徑
which flutter
readlink -f $(which flutter)

# 檢查 symlink
ls -ld ~/.termux_ide/flutter

# 驗證環境
flutter doctor

# 驗證 Android SDK
echo $ANDROID_HOME
```

---

## 注意事項

1. **終端機輸入問題**: 自動化輸入有時會疊在一起，需要手動按 Enter 或 Ctrl+C 清除
2. **建置時間**: 首次 Gradle 建置在 ARM64 硬體上需要較長時間（5-10 分鐘）
3. **X11 必要性**: Linux 桌面應用程式需要 X11 顯示伺服器才能執行
