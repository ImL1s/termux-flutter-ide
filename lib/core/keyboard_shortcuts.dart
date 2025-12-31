import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../editor/editor_providers.dart';

/// Keyboard shortcuts intent definitions
class SaveFileIntent extends Intent {
  const SaveFileIntent();
}

class QuickOpenIntent extends Intent {
  const QuickOpenIntent();
}

class CommandPaletteIntent extends Intent {
  const CommandPaletteIntent();
}

class CloseTabIntent extends Intent {
  const CloseTabIntent();
}

class NewTerminalIntent extends Intent {
  const NewTerminalIntent();
}

class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

/// Action callbacks that will be set by the EditorPage
class KeyboardShortcutCallbacks {
  final VoidCallback? onSave;
  final VoidCallback? onQuickOpen;
  final VoidCallback? onCommandPalette;
  final VoidCallback? onCloseTab;
  final VoidCallback? onNewTerminal;
  final VoidCallback? onToggleSidebar;

  const KeyboardShortcutCallbacks({
    this.onSave,
    this.onQuickOpen,
    this.onCommandPalette,
    this.onCloseTab,
    this.onNewTerminal,
    this.onToggleSidebar,
  });
}

/// Provider for keyboard shortcut callbacks
final keyboardCallbacksProvider =
    NotifierProvider<KeyboardCallbacksNotifier, KeyboardShortcutCallbacks>(
  KeyboardCallbacksNotifier.new,
);

class KeyboardCallbacksNotifier extends Notifier<KeyboardShortcutCallbacks> {
  @override
  KeyboardShortcutCallbacks build() => const KeyboardShortcutCallbacks();

  void set(KeyboardShortcutCallbacks callbacks) => state = callbacks;
}

/// Build keyboard shortcuts map
Map<ShortcutActivator, Intent> buildShortcuts() {
  return {
    // Save: Ctrl+S
    const SingleActivator(LogicalKeyboardKey.keyS, control: true):
        const SaveFileIntent(),

    // Quick Open: Ctrl+P
    const SingleActivator(LogicalKeyboardKey.keyP, control: true):
        const QuickOpenIntent(),

    // Command Palette: Ctrl+Shift+P
    const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true):
        const CommandPaletteIntent(),

    // Close Tab: Ctrl+W
    const SingleActivator(LogicalKeyboardKey.keyW, control: true):
        const CloseTabIntent(),

    // New Terminal: Ctrl+`
    const SingleActivator(LogicalKeyboardKey.backquote, control: true):
        const NewTerminalIntent(),

    // Toggle Sidebar: Ctrl+B
    const SingleActivator(LogicalKeyboardKey.keyB, control: true):
        const ToggleSidebarIntent(),
  };
}

/// Build actions map for the shortcuts
Map<Type, Action<Intent>> buildActions(WidgetRef ref) {
  final callbacks = ref.read(keyboardCallbacksProvider);

  return {
    SaveFileIntent: CallbackAction<SaveFileIntent>(
      onInvoke: (_) {
        callbacks.onSave?.call();
        // Also trigger through provider
        ref.read(saveTriggerProvider.notifier).trigger();
        return null;
      },
    ),
    QuickOpenIntent: CallbackAction<QuickOpenIntent>(
      onInvoke: (_) {
        callbacks.onQuickOpen?.call();
        return null;
      },
    ),
    CommandPaletteIntent: CallbackAction<CommandPaletteIntent>(
      onInvoke: (_) {
        callbacks.onCommandPalette?.call();
        return null;
      },
    ),
    CloseTabIntent: CallbackAction<CloseTabIntent>(
      onInvoke: (_) {
        callbacks.onCloseTab?.call();
        return null;
      },
    ),
    NewTerminalIntent: CallbackAction<NewTerminalIntent>(
      onInvoke: (_) {
        callbacks.onNewTerminal?.call();
        return null;
      },
    ),
    ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
      onInvoke: (_) {
        callbacks.onToggleSidebar?.call();
        return null;
      },
    ),
  };
}

/// Wrapper widget that adds keyboard shortcuts
class KeyboardShortcutsWrapper extends ConsumerWidget {
  final Widget child;

  const KeyboardShortcutsWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: buildShortcuts(),
      child: Actions(
        actions: buildActions(ref),
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

/// Helper widget for showing keyboard shortcut hints
class ShortcutHint extends StatelessWidget {
  final String shortcut;

  const ShortcutHint({super.key, required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF45475A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        shortcut,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'JetBrains Mono',
          color: Color(0xFFBAC2DE),
        ),
      ),
    );
  }
}
