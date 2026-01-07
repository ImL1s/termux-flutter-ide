# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Termux Flutter IDE** is a Flutter-based IDE running on Android via Termux, enabling complete Flutter development on mobile devices without requiring a computer, emulator, or cloud services. The app integrates with [termux-flutter-wsl](https://github.com/ImL1s/termux-flutter-wsl) to provide a native Android development environment.

## Common Development Commands

### Setup & Dependencies
```bash
# Use FVM for Flutter version consistency
fvm use 3.38.5

# Install dependencies
fvm flutter pub get

# Generate code (Riverpod, Mockito mocks)
fvm dart run build_runner build --delete-conflicting-outputs
```

### Running the App
```bash
# Development mode
fvm flutter run

# Build APK
fvm flutter build apk

# Build for release
fvm flutter build apk --release
```

### Testing
```bash
# Run all unit & widget tests
fvm flutter test

# Run specific test file
fvm flutter test test/termux/ssh_service_test.dart

# Run integration tests (requires device/emulator)
fvm flutter test integration_test/edit_run_flow_e2e_test.dart

# Run with coverage
fvm flutter test --coverage

# Generate mocks (when adding new @GenerateMocks)
fvm dart run build_runner build --delete-conflicting-outputs
```

### Code Quality
```bash
# Analyze code (follows analysis_options.yaml)
fvm flutter analyze

# Format code
fvm dart format lib/ test/ integration_test/
```

### UI Testing (Maestro)
```bash
# Requires Maestro installed (maestro.mobile.dev)
maestro test test_flow.yaml
```

## Architecture Overview

### Multi-Layered Architecture

The app follows a strict layered architecture:

```
UI Layer (Widgets)
    ↓ observes
Riverpod State Layer (Providers & Notifiers)
    ↓ calls
Service Layer (TermuxBridge, SSHService, FlutterRunner, LSP, Git)
    ↓ executes via
Native Layer (Android Intent IPC) ←→ Termux Environment
```

### Key Architectural Patterns

**1. State Management: Riverpod Notifier Pattern**

All state uses `flutter_riverpod` with the Notifier pattern (NOT deprecated StateProvider):

```dart
// Define provider with NotifierProvider
final dirtyFilesProvider = NotifierProvider<DirtyFilesNotifier, Set<String>>(
  DirtyFilesNotifier.new,
);

// Implement Notifier with build() and mutation methods
class DirtyFilesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void markDirty(String path) {
    state = {...state, path};
  }
}
```

**2. Dual-Path Command Execution**

Two mechanisms for executing commands in Termux:

- **TermuxBridge (Primary)**: Direct Android Intent IPC via `RUN_COMMAND`
  - Faster, no connection state, works in background
  - Uses Base64 encoding to avoid shell escaping issues
  - Best for quick operations and background tasks

- **SSHService (Fallback)**: Traditional SSH tunnel to Termux on port 8022
  - Reliable for long operations with streaming output
  - Used for LSP, Git, and operations requiring detailed output
  - Implements retry logic with connection diagnostics

**3. Provider Dependency Graph**

The app has a clear provider hierarchy:

```
termuxBridgeProvider
  ↓
sshServiceProvider
  ↓
fileOperationsProvider
  ↓
setupServiceProvider, flutterRunnerProvider, lspServiceProvider, gitServiceProvider
  ↓
UI Widgets
```

### Critical Implementation Details

**Base64 Command Encoding (lib/termux/termux_bridge.dart:51-57)**

All Termux commands are Base64-encoded to avoid shell quoting issues:

```dart
final encodedCommand = base64.encode(utf8.encode(command));
final envCommand = "/data/data/com.termux/files/usr/bin/bash -l -c 'eval \$(echo $encodedCommand | base64 -d)'";
```

This pattern prevents injection vulnerabilities and handles complex shell syntax reliably.

**SSH Authentication Flow (lib/termux/ssh_connection_factory.dart)**

1. Resolves username via `whoami` or UID mapping: `u0_a{uid-10000}`
2. Attempts SSH key-based auth (prefer ed25519)
3. Falls back to password auth (default: "termux")
4. Implements retry logic with connection diagnostics

**Flutter Runner & Debugging (lib/run/flutter_runner_service.dart)**

- Validates project structure before launching
- Executes `flutter run` via TermuxBridge or SSH
- Connects to Dart VM Service on port 54321 for debugging
- Manages breakpoints via VMServiceManager
- Streams console output to terminal widget

**LSP Integration (lib/services/lsp_service.dart)**

- Starts `dart analysis_server --lsp` via SSH
- Implements LSP 3.0 protocol with Content-Length framing
- Matches async responses via `_pendingRequests` map
- Publishes diagnostics to editor in real-time

### File Organization

**Core Architecture:**
- `lib/main.dart` - App entry, GoRouter configuration
- `lib/core/providers.dart` - Global Riverpod providers
- `lib/editor/editor_page.dart` - Main IDE layout
- `lib/editor/editor_providers.dart` - Editor-specific state

**Termux Integration:**
- `lib/termux/termux_bridge.dart` - Android Intent IPC (484 lines)
- `lib/termux/ssh_service.dart` - SSH client (362 lines)
- `lib/termux/ssh_connection_factory.dart` - SSH connection abstraction
- `lib/termux/termux_paths.dart` - Termux filesystem constants
- `android/app/src/main/kotlin/.../MainActivity.kt` - Native bridge

**Services:**
- `lib/run/flutter_runner_service.dart` - Flutter execution orchestration
- `lib/run/vm_service_manager.dart` - Dart VM debugging
- `lib/services/lsp_service.dart` - Language server protocol
- `lib/git/git_service.dart` - Git operations via SSH
- `lib/setup/setup_service.dart` - Environment setup wizard

**UI Components:**
- `lib/file_manager/file_tree_widget.dart` - File browser
- `lib/editor/code_editor_widget.dart` - Code editor (flutter_code_editor)
- `lib/editor/file_tabs_widget.dart` - Tab management
- `lib/terminal/terminal_widget.dart` - Terminal emulator (xterm)

## Testing Patterns

### Unit Tests

Use Mockito for external dependencies:

```dart
@GenerateMocks([TermuxBridge, SSHService])
void main() {
  late MockTermuxBridge mockBridge;

  setUp(() {
    mockBridge = MockTermuxBridge();
    when(mockBridge.executeCommand(any)).thenAnswer(
      (_) async => TermuxResult.success(stdout: 'output'),
    );
  });

  test('should execute command', () async {
    final result = await mockBridge.executeCommand('test');
    expect(result.success, true);
  });
}
```

### Widget Tests

Override providers with mocks in ProviderScope:

```dart
testWidgets('should show status', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        termuxBridgeProvider.overrideWithValue(mockBridge),
      ],
      child: MaterialApp(home: MyWidget()),
    ),
  );

  await tester.pumpAndSettle(); // Wait for async operations
  expect(find.text('Status'), findsOneWidget);
});
```

### Integration Tests

Mock only system boundaries (file ops, Termux), test full flows:

```dart
testWidgets('full edit-run flow', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fileOperationsProvider.overrideWithValue(mockFileOps),
        projectPathProvider.overrideWith((_) => '/test/project'),
      ],
      child: MyApp(),
    ),
  );

  // Test complete user flow
  await tester.tap(find.byIcon(Icons.play_arrow));
  await tester.pumpAndSettle();
  expect(find.text('Running'), findsOneWidget);
});
```

## Termux Integration Reference

**SSH Connection Parameters:**
- Host: `127.0.0.1`
- Port: `8022` (default Termux SSH)
- User: Result of `whoami` command
- Password: `termux` (default for local dev)

**Critical Termux Paths:**
- Termux home: `/data/data/com.termux/files/home`
- Termux bin: `/data/data/com.termux/files/usr/bin`
- Flutter: `~/flutter` (installed via termux-flutter-wsl)
- Dart SDK: `~/flutter/bin/cache/dart-sdk`

**Required Termux Packages:**
```bash
pkg install -y openssh git curl unzip
```

**Bootstrap SSH:**
```bash
# In Termux
pkg install -y openssh
passwd  # Set to 'termux'
sshd    # Start SSH server
```

**Android Permissions Required:**
- "Display over other apps" - Required for Termux to receive RUN_COMMAND intents
- Storage access - For accessing project files (via `termux-setup-storage`)

## Common Development Scenarios

### Adding a New Riverpod Provider

1. Define provider in appropriate file (e.g., `lib/core/providers.dart`)
2. Create Notifier class extending `Notifier<T>`
3. Override `build()` for initialization
4. Add mutation methods
5. Consume in widgets via `ref.watch()` or `ref.read()`

### Adding SSH Command Operations

1. Add method to `SSHService` (lib/termux/ssh_service.dart)
2. Use `executeCommand()` for simple ops, `executeStream()` for long-running
3. Wrap paths in quotes: `'cd "$path" && command'`
4. Return typed `SSHExecResult` with exitCode, stdout, stderr
5. Handle connection errors with retry logic

### Adding TermuxBridge Commands

1. Add method to `TermuxBridge` (lib/termux/termux_bridge.dart)
2. Use Base64 encoding for complex commands
3. Use `executeCommand()` for quick ops, `executeCommandStream()` for streaming
4. Add corresponding handler in MainActivity.kt if needed
5. Test with real Termux environment

### Working with the Editor

- Editor uses `flutter_code_editor` package (100+ language support)
- Code highlighting via `flutter_highlight` with Catppuccin Mocha theme
- Tab state managed in `openFilesProvider` and `currentFileProvider`
- Dirty file tracking via `dirtyFilesProvider`
- File content cached in `originalContentProvider` for change detection

### Debugging Tips

- Check `lib/termux/connection_diagnostics.dart` for SSH troubleshooting
- Enable verbose logging by checking `SSHService._statusController.stream`
- Use `flutter run --verbose` to see detailed Termux command output
- Monitor Android logcat for Intent/BroadcastReceiver issues
- Test SSH manually: `ssh -p 8022 termux@127.0.0.1` (password: termux)

## Important Constraints

- **No `busybox chpasswd`** - Not available in modern Termux, use interactive `passwd`
- **Async Intent execution** - Termux RUN_COMMAND is fire-and-forget, use delays for setup
- **Android 10+ restrictions** - Background apps need "Display over other apps" permission
- **ARM64 only** - Flutter builds require ARM64 architecture
- **Base64 all shell commands** - Avoids escaping issues and injection vulnerabilities
- **Default password is "termux"** - For local development convenience, change for production
