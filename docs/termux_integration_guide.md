# Termux Integration Guide

This document serves as the authoritative reference for all Termux interactions within the Termux Flutter IDE project.

## 1. Package Management (`pkg`)
Termux uses `apt` and `dpkg` but provides a wrapper `pkg` which should be used for all package operations.

- **Update**: `pkg update -y`
- **Install**: `pkg install -y <package_name>`
- **Upgrade**: `pkg upgrade -y`

### Critical Dependencies
The following packages are **mandatory** for the IDE's SSH functionality:
- `openssh`: Provides `sshd` server and `ssh` client.

## 2. SSH Authentication Bootstrap
To enable SSH connections, you must set a password in Termux.

### Problem: Interactive `passwd`
The standard `passwd` command is interactive and requires TTY.

### Solution: Manual Password Setup
Since `busybox chpasswd` is **NOT available** in modern Termux, users must set their password manually.

**Setup Steps**:
```bash
# Step 1: Install openssh
pkg install -y openssh

# Step 2: Set your password (type 'termux' when prompted)
passwd

# Step 3: Start sshd
sshd
```

The IDE expects the password to be `termux` by default.

## 3. Command Execution
Termux commands are executed via Android Intents (`RunCommandService`).

### Asynchronous Nature
- `startService(intent)` is **asynchronous**.
- The default `RunCommandService` does NOT return exit codes or stdout/stderr to the caller synchronously.
- **Implication**: When running setup commands (like bootstrap), code must **wait** (e.g., `Future.delayed`) sufficiently for the background process to complete, as we lack a direct callback.

## 4. SSH Connection Parameters
- **Host**: `127.0.0.1` (Localhost)
- **Port**: `8022` (Default Termux SSH port)
- **User**: Result of `whoami` command.
- **Password**: `termux` (Hardcoded for local development convenience).

## 5. Troubleshooting
If `SSHAuthFailError` occurs:
1. **Check OpenSSH**: Run `pkg install openssh` in Termux.
2. **Set Password**: Run `passwd` in Termux and enter `termux` as the password.
3. **Restart SSHD**: Run `pkill sshd; sshd`.

## 6. Storage Access & Permissions
Termux runs in a sandboxed environment. To access shared storage (like `/sdcard`), explicit permission must be granted.

### `termux-setup-storage`
This command triggers the Android System Permission dialog.
- **Run**: `termux-setup-storage`
- **Effect**: Creates `~/storage` directory with symlinks to standard Android folders (`dcim`, `downloads`, `shared`, etc.).
- **Troubleshooting**: If files are not visible, ensure the Android Permission for "Storage" is granted to the Termux app in System Settings.

## 7. Performance Management (Wake Locks)
Android aggressively kills background processes to save battery.
- **Problem**: SSH sessions or Flutter builds may be terminated if the screen turns off.
- **Solution**: Use `termux-wake-lock`.
- **Command**: `termux-wake-lock` (Acquire), `termux-wake-unlock` (Release).
- **Usage**: The IDE automatically acquires a wake lock during Bootstrap and Installation phases.

## 8. Real-time Output (Socket Bridge)
To stream command output (stdout/stderr) from Termux to Flutter in real-time, we use a **TCP Socket Bridge**.

### Architecture
1.  **Flutter (Server)**: Binds a random available port on `127.0.0.1`.
2.  **Termux (Client)**: Executes shell command wrapping.
3.  **Redirection**:
    ```bash
    sh -c "(<command>) > /dev/tcp/127.0.0.1/<port> 2>&1"
    ```
    - `> /dev/tcp/...`: Bash feature to Redirect output to a TCP socket.
    - `2>&1`: Redirects stderr to stdout.
- **Benefit**: Bypasses the need for Termux to bind ports (which can fail due to permissions) and avoids slow file polling.

## 9. Flutter Environment
Flutter in Termux is custom-installed via `termux-flutter-wsl`.

### Dependencies
- `git`: Required for `flutter pub get`.
- `curl`: Required for installation script.
- `unzip`: Required for Dart SDK extraction.

### Path Configuration
- **Location**: `~/flutter` (Default)
- **Path**: `export PATH=$HOME/flutter/bin:$PATH`
## 11. 進階功能整合 (Feasibility Findings)

### 11.1 Dart & Flutter 路徑
在 Termux 環境中，`dart` 執行檔可能不在 `PATH` 中。
- **偵測到的主要路徑**: `/data/data/com.termux/files/usr/opt/flutter/bin/cache/dart-sdk/bin/dart`
- **備用搜尋指令**: `find /data/data/com.termux/files -name dart -type f`

### 11.2 LSP (Dart Language Server) 執行
直接執行 `dart language-server` 可能會因為 `dartaotruntime` 錯誤而失敗。
- **解決方案**: 直接執行 JIT Snapshot。
- **指令**: 
  ```bash
  /data/data/com.termux/files/usr/opt/flutter/bin/cache/dart-sdk/bin/dart \
  /data/data/com.termux/files/usr/opt/flutter/bin/cache/dart-sdk/bin/snapshots/analysis_server.dart.snapshot \
  --lsp
  ```

### 11.3 Git 整合
- **指令**: 使用 `git status --porcelain` 進行機器可讀的解析。
- **認證**: 直接復用 Termux 內已配置的 Git 帳號與 SSH Key，無需在 Flutter 端重新實作。
## 10. System Permissions (Android 10+)
To Execute commands from the IDE (background) reliably, Termux requires the **"Display over other apps"** (Overlay) permission.
- **Why?**: Android 10+ blocks background apps from starting services/activities. Termux needs this to effectively receive and execute Intents sent by the IDE.
- **Action**: When prompted by Termux ("Allow display over other apps"), users **MUST** select **Allow**.
- **Without this**: Bootstrap commands may be silently blocked by Android OS, causing SSH connection failures.
