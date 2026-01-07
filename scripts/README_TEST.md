# UI 測試腳本使用指南

## 概述

`test_ide_ui.sh` 是一個自動化 UI 測試腳本，通過 ADB 命令對 Termux Flutter IDE 進行功能測試。

## 前置條件

1. **ADB 已安裝並配置**
   ```bash
   # 檢查 ADB 是否可用
   which adb
   ```

2. **設備已連接**
   ```bash
   # 查看已連接的設備
   adb devices
   ```

3. **Flutter 環境 (使用 fvm)**
   ```bash
   # 確認 fvm 可用
   fvm flutter --version
   ```

4. **Termux 已安裝在測試設備上**

## 快速開始

### 運行完整測試

```bash
cd /Users/iml1s/Documents/mine/termux-flutter-ide
./scripts/test_ide_ui.sh
```

### 指定設備 ID

```bash
DEVICE_ID=YOUR_DEVICE_ID ./scripts/test_ide_ui.sh
```

## 測試流程

腳本將自動執行以下步驟：

### 1. Setup Phase (設置階段)
- ✓ 檢查設備連接
- ✓ 設置 Termux SSH 密碼
- ✓ 授予 RUN_COMMAND 權限
- ✓ 構建並安裝 APK
- ✓ 創建測試項目

### 2. Testing Phase (測試階段)
- ✓ 測試 IDE 啟動
- ✓ 測試導航抽屜
- ✓ 測試 Explorer 標籤
- ✓ 測試 Terminal 標籤
- ✓ 測試 Search 標籤
- ✓ 測試 Open Folder 功能

### 3. Cleanup Phase (清理階段)
- ✓ 關閉 IDE 應用
- ✓ 生成測試報告

## 輸出文件

### 截圖目錄
```
/tmp/ide_test_screenshots/
├── 01_ide_launched.png
├── 02_drawer_opened.png
├── 03_explorer_tab.png
├── 04_terminal_tab.png
├── 05_search_tab.png
├── 06_open_folder.png
└── test_report.md
```

### 日誌文件
```
/tmp/ide_ui_test.log
```

## 腳本配置

可通過環境變量自定義配置：

```bash
# 設備 ID（默認: RFCNC0WNT9H）
export DEVICE_ID="YOUR_DEVICE_ID"

# 截圖保存目錄（默認: /tmp/ide_test_screenshots）
export SCREENSHOT_DIR="/custom/path/screenshots"

# 日誌文件路徑（默認: /tmp/ide_ui_test.log）
export LOG_FILE="/custom/path/test.log"
```

## 測試函數說明

### 核心函數

#### `check_device()`
檢查 ADB 設備連接狀態

#### `setup_ssh_password()`
在 Termux 中設置 SSH 密碼為 "termux"

#### `grant_permissions()`
授予 IDE 應用 Termux RUN_COMMAND 權限

#### `install_apk()`
構建 Debug APK 並安裝到設備

#### `launch_ide()`
啟動 IDE 應用

#### `test_ide_launch()`
驗證 IDE 成功啟動

#### `test_drawer_menu()`
測試側邊導航抽屜

#### `test_explorer_tab()`
測試 Explorer 標籤功能

#### `test_terminal_tab()`
測試 Terminal 標籤功能

#### `test_search_tab()`
測試 Search 標籤功能

#### `test_open_folder()`
測試 Open Folder 功能

#### `create_test_project()`
在 Termux 中創建測試項目結構

### 工具函數

#### `log(message)`
記錄訊息到日誌文件

#### `success(message)`
顯示成功訊息（綠色）

#### `fail(message)`
顯示失敗訊息（紅色）

#### `info(message)`
顯示信息訊息（黃色）

#### `take_screenshot(name)`
捕獲螢幕截圖並保存

#### `tap(x, y, description)`
模擬點擊操作

## 座標參考

測試腳本使用以下螢幕座標（基於 1080x2400 解析度）：

```
UI Element          X      Y
────────────────────────────
Hamburger Menu     50    100
Folder Icon       476    119
Explorer Tab      117   1481
Terminal Tab      352   1481
Search Tab        588   1481
Open Folder       280    967
New Project       237   1013
Settings          160   1379
```

## 故障排除

### 問題: 設備未連接
```bash
# 檢查 USB 調試是否啟用
adb devices

# 重新連接設備
adb kill-server
adb start-server
```

### 問題: 權限被拒絕
```bash
# 手動授予權限
adb shell pm grant com.iml1s.termux_flutter_ide com.termux.permission.RUN_COMMAND
```

### 問題: APK 構建失敗
```bash
# 清理並重新構建
fvm flutter clean
fvm flutter pub get
fvm flutter build apk --debug
```

### 問題: Termux SSH 設置失敗
```bash
# 手動進入 Termux 設置密碼
adb shell
run-as com.termux
passwd
# 輸入: termux
```

## 擴展測試

### 添加新測試函數

```bash
test_my_feature() {
    info "Testing my feature..."

    # 執行操作
    tap 100 200 "My button"
    sleep 1

    # 捕獲結果
    take_screenshot "my_feature"

    # 驗證
    if [ some_condition ]; then
        success "My feature works"
    else
        fail "My feature failed"
    fi
}
```

### 在 main() 中調用

```bash
main() {
    # ... existing tests ...
    test_my_feature
    # ...
}
```

## 持續集成

### 在 CI/CD 中使用

```yaml
# .github/workflows/ui-test.yml
name: UI Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Android SDK
        uses: android-actions/setup-android@v2
      - name: Run UI Tests
        run: ./scripts/test_ide_ui.sh
```

## 相關文檔

- [測試報告範例](../docs/ide-ui-test-report-2026-01-07.md)
- [IDE 開發指南](../README.md)
- [ADB 官方文檔](https://developer.android.com/studio/command-line/adb)

## 貢獻

歡迎改進測試腳本！請遵循以下指南：

1. 保持函數簡潔，單一職責
2. 添加適當的錯誤處理
3. 記錄所有操作到日誌
4. 為新功能添加截圖
5. 更新此 README

## 授權

與主項目相同的授權協議。
