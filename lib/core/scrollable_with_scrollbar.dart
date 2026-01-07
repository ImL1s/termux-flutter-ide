import 'package:flutter/material.dart';

/// A wrapper widget that ensures a consistent scrollbar experience across platforms.
/// It enforces visibility on desktop/web and allows for customization of scrollbar appearance.
class ScrollableWithScrollbar extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final bool alwaysShown;
  final Axis axis;

  const ScrollableWithScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.alwaysShown = true,
    this.axis = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars:
            false, // Disable default scrollbars to use our own controlled one
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: alwaysShown,
        trackVisibility: alwaysShown, // Show track for better UX on desktop
        interactive: true,
        thickness: 10,
        radius: const Radius.circular(5),
        child: child,
      ),
    );
  }
}

/// A convenience widget for a ListView with a consistent scrollbar.
class ListViewWithScrollbar extends StatefulWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final Axis scrollDirection;

  const ListViewWithScrollbar({
    super.key,
    required this.children,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<ListViewWithScrollbar> createState() => _ListViewWithScrollbarState();
}

class _ListViewWithScrollbarState extends State<ListViewWithScrollbar> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollableWithScrollbar(
      controller: _controller,
      child: ListView(
        controller: _controller,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        scrollDirection: widget.scrollDirection,
        children: widget.children,
      ),
    );
  }
}
