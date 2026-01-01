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
- `busybox`: Provides critical utilities missing from Android/Termux default shell (like `chpasswd`).
- `termux-auth`: Provides password authentication mechanisms.

## 2. SSH Authentication Bootstrap
To enable SSH connections programmatically without user interaction (non-interactive login), we must set a password.

### Problem: Interactive `passwd`
The standard `passwd` command is interactive and requires TTY, which Intention-based command execution does not provide.

### Solution: `busybox chpasswd`
`chpasswd` allows setting passwords via STDIN in batch mode.
**Note**: `chpasswd` is NOT installed by default. It must be accessed via `busybox`.

**Correct Bootstrap Command**:
```bash
pkg install -y openssh busybox termux-auth && \
echo "$(whoami):termux" | busybox chpasswd && \
sshd
```

- Installs `openssh` (server), `busybox` (utils), `termux-auth` (auth system).
- Pipes `username:password` to `busybox chpasswd`.
- Starts `sshd`.

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
1. **Check Packages**: Ensure `busybox` and `termux-auth` are installed.
2. **Check Password**: Manually run `echo "$(whoami):termux" | busybox chpasswd`.
3. **Restart Service**: `pkill sshd; sshd`.

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

## 10. System Permissions (Android 10+)
To Execute commands from the IDE (background) reliably, Termux requires the **"Display over other apps"** (Overlay) permission.
- **Why?**: Android 10+ blocks background apps from starting services/activities. Termux needs this to effectively receive and execute Intents sent by the IDE.
- **Action**: When prompted by Termux ("Allow display over other apps"), users **MUST** select **Allow**.
- **Without this**: Bootstrap commands may be silently blocked by Android OS, causing SSH connection failures.


