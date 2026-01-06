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

// === New Intents ===

class GoToDefinitionIntent extends Intent {
  const GoToDefinitionIntent();
}

class FindReferencesIntent extends Intent {
  const FindReferencesIntent();
}

class RunIntent extends Intent {
  const RunIntent();
}

class ToggleBreakpointIntent extends Intent {
  const ToggleBreakpointIntent();
}

class FindIntent extends Intent {
  const FindIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

class FormatDocumentIntent extends Intent {
  const FormatDocumentIntent();
}

/// Action callbacks that will be set by the EditorPage
class KeyboardShortcutCallbacks {
  final VoidCallback? onSave;
  final VoidCallback? onQuickOpen;
  final VoidCallback? onCommandPalette;
  final VoidCallback? onCloseTab;
  final VoidCallback? onNewTerminal;
  final VoidCallback? onToggleSidebar;
  // New callbacks
  final VoidCallback? onGoToDefinition;
  final VoidCallback? onFindReferences;
  final VoidCallback? onRun;
  final VoidCallback? onToggleBreakpoint;
  final VoidCallback? onFind;
  final VoidCallback? onEscape;
  final VoidCallback? onFormatDocument;

  const KeyboardShortcutCallbacks({
    this.onSave,
    this.onQuickOpen,
    this.onCommandPalette,
    this.onCloseTab,
    this.onNewTerminal,
    this.onToggleSidebar,
    this.onGoToDefinition,
    this.onFindReferences,
    this.onRun,
    this.onToggleBreakpoint,
    this.onFind,
    this.onEscape,
    this.onFormatDocument,
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
    // === Original Shortcuts ===
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

    // === New Shortcuts ===
    // Go to Definition: F12
    const SingleActivator(LogicalKeyboardKey.f12): const GoToDefinitionIntent(),

    // Find References: Shift+F12
    const SingleActivator(LogicalKeyboardKey.f12, shift: true):
        const FindReferencesIntent(),

    // Run: F5
    const SingleActivator(LogicalKeyboardKey.f5): const RunIntent(),

    // Toggle Breakpoint: F9
    const SingleActivator(LogicalKeyboardKey.f9):
        const ToggleBreakpointIntent(),

    // Find: Ctrl+F
    const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const FindIntent(),

    // Escape: Cancel/Close
    const SingleActivator(LogicalKeyboardKey.escape): const EscapeIntent(),

    // Format Document: Alt+Shift+F
    const SingleActivator(LogicalKeyboardKey.keyF, alt: true, shift: true):
        const FormatDocumentIntent(),
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
    // === New Actions ===
    GoToDefinitionIntent: CallbackAction<GoToDefinitionIntent>(
      onInvoke: (_) {
        callbacks.onGoToDefinition?.call();
        return null;
      },
    ),
    FindReferencesIntent: CallbackAction<FindReferencesIntent>(
      onInvoke: (_) {
        callbacks.onFindReferences?.call();
        return null;
      },
    ),
    RunIntent: CallbackAction<RunIntent>(
      onInvoke: (_) {
        callbacks.onRun?.call();
        return null;
      },
    ),
    ToggleBreakpointIntent: CallbackAction<ToggleBreakpointIntent>(
      onInvoke: (_) {
        callbacks.onToggleBreakpoint?.call();
        return null;
      },
    ),
    FindIntent: CallbackAction<FindIntent>(
      onInvoke: (_) {
        callbacks.onFind?.call();
        return null;
      },
    ),
    EscapeIntent: CallbackAction<EscapeIntent>(
      onInvoke: (_) {
        callbacks.onEscape?.call();
        return null;
      },
    ),
    FormatDocumentIntent: CallbackAction<FormatDocumentIntent>(
      onInvoke: (_) {
        callbacks.onFormatDocument?.call();
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
