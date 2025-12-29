# 開發指南

## 專案結構

```
termux-flutter-ide/
├── lib/
│   ├── main.dart              # 應用入口
│   ├── theme/
│   │   └── app_theme.dart     # 主題配置
│   ├── core/
│   │   └── providers.dart     # Riverpod Notifiers
│   ├── editor/
│   │   ├── editor_page.dart   # 主編輯器頁面
│   │   ├── code_editor_widget.dart
│   │   └── file_tabs_widget.dart
│   ├── file_manager/
│   │   └── file_tree_widget.dart
│   ├── terminal/
│   │   └── terminal_widget.dart
│   └── analyzer/              # TODO: Dart 分析器
│       └── ...
├── pubspec.yaml
└── .fvm/                      # FVM 配置
```

---

## 可用資源

### 程式碼編輯器選項

| 方案 | 說明 | 連結 |
|------|------|------|
| flutter_code_editor | ✅ 採用 - 100+ 語言支援 | [GitHub](https://github.com/akvelon/flutter-code-editor) |
| Re-Editor | 輕量級替代方案 | [pub.dev](https://pub.dev/packages/re_editor) |
| Monaco (WebView) | VS Code 核心 | 需 WebView 整合 |

### Termux 整合方案

1. **Intent 通訊** - 與 Termux 互傳指令
2. **Plugin 機制** - 深度整合
3. **Socket IPC** - 本地通訊

### Dart 分析器整合

```dart
// 使用 dart analysis_server
// 位置: $DART_SDK/bin/snapshots/analysis_server.dart.snapshot
```

---

## 代辦任務

### 高優先級
- [ ] Termux Intent 通訊實作
- [ ] 真實檔案系統讀寫
- [ ] flutter run 整合

### 中優先級
- [ ] Dart Analysis Server 整合
- [ ] 自動完成增強
- [ ] 搜尋功能

### 低優先級
- [ ] Git 整合
- [ ] 多主題支援
- [ ] 鍵盤快捷鍵

---

## 參考資料

- [flutter_code_editor 範例](https://github.com/akvelon/flutter-code-editor/tree/main/example)
- [xterm.dart 文檔](https://pub.dev/packages/xterm)
- [Termux Plugin API](https://github.com/nicklockwood/termux-api)
- [Dart Analysis Server Protocol](https://github.com/nicklockwood/sdk/blob/main/pkg/analysis_server/doc/api.md)
