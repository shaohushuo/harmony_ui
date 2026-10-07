import 'package:flutter/material.dart';
import 'dart:async';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// Dots indicator of an [OhosSwiper] (导航点 in the HarmonyOS guideline).
class OhosPageIndicator extends StatelessWidget {
  const OhosPageIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    this.activeColor,
    this.inactiveColor,
    this.dotSize = 8,
    this.spacing = 6,
  });

  /// Number of pages.
  final int count;

  /// Index of the active dot.
  final int currentIndex;

  /// Color of the active dot; defaults to the theme highlight color.
  final Color? activeColor;

  /// Color of the inactive dots.
  final Color? inactiveColor;

  /// Diameter of each dot.
  final double dotSize;

  /// Gap between dots.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: OhosGeometry.durationShort,
            curve: OhosGeometry.spring,
            width: i == currentIndex ? dotSize * 2 : dotSize,
            height: dotSize,
            margin: EdgeInsets.symmetric(horizontal: spacing / 2),
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? (activeColor ?? theme.highlightColor)
                  : (inactiveColor ??
                        theme.textTertiaryColor.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(dotSize / 2),
            ),
          ),
      ],
    );
  }
}

/// A page swiper with navigation dots, matching the "轮播/导航点" control in
/// the HarmonyOS design guideline.
class OhosSwiper extends StatefulWidget {
  const OhosSwiper({
    super.key,
    required this.children,
    this.height,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.loop = true,
    this.indicator = true,
    this.onPageChanged,
    this.controller,
  });

  /// Page widgets.
  final List<Widget> children;

  /// Height of the swiper; defaults to the tallest child.
  final double? height;

  /// Automatically advance pages.
  final bool autoPlay;

  /// Interval between auto-play pages.
  final Duration autoPlayInterval;

  /// Whether the swiper loops back to the first page.
  final bool loop;

  /// Whether to show the page dots.
  final bool indicator;

  /// Called when the active page changes.
  final ValueChanged<int>? onPageChanged;

  /// Optional page controller.
  final PageController? controller;

  @override
  State<OhosSwiper> createState() => _OhosSwiperState();
}

class _OhosSwiperState extends State<OhosSwiper> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        PageController(initialPage: widget.loop ? 50000 : 0);
    if (widget.autoPlay && widget.children.length > 1) {
      _timer = Timer.periodic(widget.autoPlayInterval, (_) => _tick());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(OhosSwiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay != oldWidget.autoPlay ||
        widget.autoPlayInterval != oldWidget.autoPlayInterval) {
      _timer?.cancel();
      _timer = widget.autoPlay && widget.children.length > 1
          ? Timer.periodic(widget.autoPlayInterval, (_) => _tick())
          : null;
    }
  }

  void _tick() {
    if (!mounted || widget.children.isEmpty) return;
    final int next = (_index + 1) % widget.children.length;
    _controller.animateToPage(
      widget.loop ? (_controller.page ?? 0).round() + 1 : next,
      duration: OhosGeometry.durationMedium,
      curve: OhosGeometry.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = widget.children;
    if (pages.isEmpty && !widget.indicator) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.loop ? null : pages.length,
            onPageChanged: (int index) {
              setState(() => _index = index % pages.length);
              widget.onPageChanged?.call(index % pages.length);
            },
            itemBuilder: (BuildContext context, int index) {
              return pages[index % pages.length];
            },
          ),
        ),
        if (widget.indicator)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OhosPageIndicator(count: pages.length, currentIndex: _index),
          ),
      ],
    );
  }
}
