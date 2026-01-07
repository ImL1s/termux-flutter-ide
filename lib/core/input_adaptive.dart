import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A unified wrapper widget that provides consistent input handling
/// for keyboard, mouse, and touch interactions.
///
/// This widget combines:
/// - MouseRegion (hover effects, cursor changes)
/// - GestureDetector (tap, double-tap, long-press, secondary tap)
/// - Tooltip (accessibility hints)
/// - InkWell (touch ripple effects)
/// - Focus handling (keyboard navigation)
class InputAdaptiveWrapper extends StatefulWidget {
  final Widget child;

  /// Callbacks
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final ValueChanged<Offset>? onSecondaryTapDown;

  /// Tooltip text (shows on hover and long-press)
  final String? tooltip;

  /// Mouse cursor to show on hover
  final MouseCursor cursor;

  /// Whether to show hover background effect
  final bool enableHoverEffect;

  /// Custom hover color (defaults to surfaceVariant)
  final Color? hoverColor;

  /// Whether to show InkWell ripple effect on tap
  final bool enableRipple;

  /// Whether this widget can receive focus
  final bool canRequestFocus;

  /// Border radius for ripple and hover effects
  final BorderRadius? borderRadius;

  /// Padding around the child
  final EdgeInsetsGeometry? padding;

  const InputAdaptiveWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.tooltip,
    this.cursor = SystemMouseCursors.basic,
    this.enableHoverEffect = true,
    this.hoverColor,
    this.enableRipple = true,
    this.canRequestFocus = true,
    this.borderRadius,
    this.padding,
  });

  @override
  State<InputAdaptiveWrapper> createState() => _InputAdaptiveWrapperState();
}

class _InputAdaptiveWrapperState extends State<InputAdaptiveWrapper> {
  bool _isHovering = false;
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _buildCore();

    // Wrap with Tooltip if provided
    if (widget.tooltip != null) {
      result = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: result,
      );
    }

    // Wrap with Focus for keyboard navigation
    if (widget.canRequestFocus) {
      result = Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: result,
      );
    }

    return result;
  }

  Widget _buildCore() {
    // Determine background color based on state
    Color? backgroundColor;
    if (widget.enableHoverEffect) {
      if (_isHovering || _isFocused) {
        backgroundColor =
            widget.hoverColor ?? AppTheme.surfaceVariant.withValues(alpha: 0.5);
      }
    }

    // Build the interactive content
    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
        border: _isFocused
            ? Border.all(
                color: AppTheme.primary.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      padding: widget.padding,
      child: widget.child,
    );

    // Wrap with InkWell for ripple effect
    if (widget.enableRipple && widget.onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          onLongPress: widget.onLongPress,
          onSecondaryTap: widget.onSecondaryTap,
          onSecondaryTapDown: widget.onSecondaryTapDown != null
              ? (details) => widget.onSecondaryTapDown!(details.globalPosition)
              : null,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          hoverColor: Colors.transparent, // We handle hover ourselves
          splashColor: AppTheme.primary.withValues(alpha: 0.2),
          highlightColor: AppTheme.primary.withValues(alpha: 0.1),
          child: content,
        ),
      );
    } else {
      // Use GestureDetector for non-ripple interactions
      content = GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onSecondaryTap,
        onSecondaryTapDown: widget.onSecondaryTapDown != null
            ? (details) => widget.onSecondaryTapDown!(details.globalPosition)
            : null,
        child: content,
      );
    }

    // Wrap with MouseRegion for hover and cursor
    return MouseRegion(
      cursor: widget.onTap != null ? widget.cursor : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: content,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Enter or Space to activate
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}

/// A hover-aware list tile for file trees and lists
class HoverListTile extends StatefulWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSecondaryTap;
  final ValueChanged<Offset>? onSecondaryTapDown;
  final bool selected;
  final EdgeInsetsGeometry? contentPadding;

  const HoverListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.selected = false,
    this.contentPadding,
  });

  @override
  State<HoverListTile> createState() => _HoverListTileState();
}

class _HoverListTileState extends State<HoverListTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.selected
        ? AppTheme.primary.withValues(alpha: 0.15)
        : _isHovering
            ? AppTheme.surfaceVariant.withValues(alpha: 0.5)
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTap: widget.onSecondaryTap,
        onSecondaryTapDown: widget.onSecondaryTapDown != null
            ? (details) => widget.onSecondaryTapDown!(details.globalPosition)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          color: backgroundColor,
          padding: widget.contentPadding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.title,
                    if (widget.subtitle != null) widget.subtitle!,
                  ],
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrollable container with visible scrollbar for desktop
class ScrollableWithScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final Axis scrollDirection;
  final bool thumbVisibility;
  final EdgeInsetsGeometry? padding;

  const ScrollableWithScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.thumbVisibility = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget scrollable = SingleChildScrollView(
      controller: controller,
      scrollDirection: scrollDirection,
      padding: padding,
      child: child,
    );

    return Scrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility,
      child: scrollable,
    );
  }
}

/// A ListView with visible scrollbar
class ListViewWithScrollbar extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool thumbVisibility;

  const ListViewWithScrollbar({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    this.thumbVisibility = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: controller,
      thumbVisibility: thumbVisibility,
      child: ListView.builder(
        controller: controller,
        itemCount: itemCount,
        padding: padding,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// Extension for detecting input type
extension InputTypeDetector on BuildContext {
  /// Returns true if the device likely has a mouse
  bool get hasMouse {
    // On desktop platforms, assume mouse is available
    final platform = Theme.of(this).platform;
    return platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
  }

  /// Returns true if the device is touch-primary
  bool get isTouchPrimary {
    final platform = Theme.of(this).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }
}
