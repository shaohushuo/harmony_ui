import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_light_material.dart';

/// Destination model of an [OhosNavigationBar].
class OhosNavigationDestination {
  const OhosNavigationDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge,
  });

  /// Icon shown while the destination is selected.
  final Widget icon;

  /// Icon shown when the destination is not selected.
  final Widget? selectedIcon;

  /// The label below the icon.
  final String label;

  /// Optional widget overlaying the icon corner (e.g. [OhosBadge]).
  final Widget? badge;
}

/// Presentation style of an [OhosNavigationBar] (HarmonyOS 6.1+ rule).
enum OhosNavigationBarType {
  /// 平铺式: fills the bottom edge of the window, default height 48vp.
  tile,

  /// 悬浮式: a rounded capsule floating above the content, default height
  /// 56vp, typically combined with the immersive light material.
  float,
}

/// A HarmonyOS bottom navigation bar, the counterpart of Material's
/// [NavigationBar].
///
/// Follows the official「底部页签」spec:
///
/// - 平铺式 height 48vp / 悬浮式 height 56vp (3-5 destinations, icon 24x24vp).
/// - The active destination gets a 20% brand highlight
///   (`comp_emphasize_secondary`) pill behind its icon (平铺) or behind the
///   inline icon+label (悬浮).
/// - In 悬浮式 + [lightMaterial] mode the bar uses the immersive-light
///   backplate; with [glow] enabled the light pools travel to the selected
///   destination and a bright lens follows the finger while pressing —
///   the 「光感交互」 behavior from the bottom-tab guideline.
class OhosNavigationBar extends StatefulWidget {
  const OhosNavigationBar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
    this.backgroundColor,
    this.height,
    this.type = OhosNavigationBarType.tile,
    this.lightMaterial = false,
    this.lightLevel = OhosLightMaterialLevel.thin,
    this.iconSize = 24,
    this.glow = true,
    this.enablePressGlow = true,
  });

  /// Destinations of the bar.
  final List<OhosNavigationDestination> destinations;

  /// Index of the active destination.
  final int currentIndex;

  /// Called with the index of the tapped destination.
  final ValueChanged<int> onDestinationSelected;

  /// Bar background color; defaults to the theme component background.
  final Color? backgroundColor;

  /// Logical height of the bar; defaults to 48 (tile) or 56 (float).
  final double? height;

  /// 平铺式 or 悬浮式 presentation.
  final OhosNavigationBarType type;

  /// Whether the bar is backed by the immersive light material.
  final bool lightMaterial;

  /// Immersive-light level when [lightMaterial] is true.
  final OhosLightMaterialLevel lightLevel;

  /// Icon size of a destination (official default 24x24vp).
  final double iconSize;

  /// When true (悬浮式 + [lightMaterial]) the material light pools follow the
  /// selected destination and the bar paints a bright press lens + caustics
  /// at the touch point while the finger is down.
  final bool glow;

  /// Whether the press lens is painted at the touch point. Only applies when
  /// [glow] is true.
  final bool enablePressGlow;

  @override
  State<OhosNavigationBar> createState() => _OhosNavigationBarState();
}

class _OhosNavigationBarState extends State<OhosNavigationBar>
    with TickerProviderStateMixin {
  final GlobalKey _barKey = GlobalKey();
  late final AnimationController _selectionController;
  late final AnimationController _pressController;
  late Animation<double> _indexAnimation;
  late double _selectedIndex;
  Offset? _pointerLocal;
  bool _pointerDown = false;

  double get _defaultHeight => widget.type == OhosNavigationBarType.float
      ? 56
      : 48;

  double get _effectiveHeight => widget.height ?? _defaultHeight;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex.toDouble();
    _selectionController = AnimationController(
      vsync: this,
      duration: OhosGeometry.durationMedium,
    )..value = 1;
    _pressController = AnimationController(
      vsync: this,
      duration: OhosGeometry.durationShort,
    );
    _indexAnimation = AlwaysStoppedAnimation<double>(_selectedIndex);
  }

  @override
  void didUpdateWidget(covariant OhosNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      final double begin = _indexAnimation.value.clamp(
        0.0,
        (widget.destinations.length - 1).toDouble(),
      );
      _indexAnimation = Tween<double>(
        begin: begin,
        end: widget.currentIndex.toDouble(),
      ).animate(
        CurvedAnimation(parent: _selectionController, curve: OhosGeometry.easeOut),
      );
      _selectedIndex = widget.currentIndex.toDouble();
      _selectionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  void _beginInteraction(PointerDownEvent event) {
    if (!widget.glow || !widget.enablePressGlow) {
      return;
    }
    final RenderBox? box =
        _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    setState(() {
      _pointerDown = true;
      _pointerLocal = box.globalToLocal(event.position);
    });
    _pressController.forward(from: 0);
  }

  void _updateInteraction(PointerMoveEvent event) {
    if (!_pointerDown) {
      return;
    }
    final RenderBox? box =
        _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    setState(() => _pointerLocal = box.globalToLocal(event.position));
  }

  void _endInteraction() {
    if (!_pointerDown) {
      return;
    }
    setState(() => _pointerDown = false);
    _pressController.reverse();
  }

  double _glowX() {
    final int count = widget.destinations.length;
    if (count <= 1) {
      return 0;
    }
    final double visual = _indexAnimation.value
        .clamp(0.0, (count - 1).toDouble())
        .toDouble();
    return (visual / (count - 1)) * 2 - 1;
  }

  Widget _buildBar(BuildContext context) {
    final Widget bar = SizedBox(
      height: _effectiveHeight,
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < widget.destinations.length; i++)
              Expanded(
                child: _OhosNavItem(
                  destination: widget.destinations[i],
                  selected: i == widget.currentIndex,
                  onTap: () => widget.onDestinationSelected(i),
                  inline: widget.type == OhosNavigationBarType.float,
                  iconSize: widget.iconSize,
                ),
              ),
          ],
        ),
      ),
    );
    final OhosThemeData theme = OhosTheme.of(context);
    final Color background =
        widget.backgroundColor ??
        (theme.compBackgroundPrimaryColor ?? theme.cardColor);

    if (widget.type == OhosNavigationBarType.float) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            key: _barKey,
            height: _effectiveHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_effectiveHeight / 2),
            ),
            child: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[
                _selectionController,
                _pressController,
              ]),
              builder: (BuildContext context, Widget? child) {
                final double press = _pressController.value;
                final Alignment glowAlignment =
                    widget.glow ? Alignment(_glowX(), .1) : Alignment.center;
                final Widget surface = OhosLightMaterial(
                  level: widget.lightLevel,
                  gradientFade: OhosLightFade.bottom,
                  gradientExtent: 24,
                  glowAlignment: glowAlignment,
                  animationValue: .5 + press * .5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      if (widget.glow &&
                          widget.enablePressGlow &&
                          _pointerDown &&
                          _pointerLocal != null)
                        CustomPaint(
                          painter: _OhosNavGlowPainter(
                            pointer: _pointerLocal!,
                            progress: press,
                            glowColors: const <Color>[
                              Color(0xFF5EA9FF),
                              Color(0xFF7C8DF7),
                              Color(0xFF62E0C9),
                            ],
                          ),
                        ),
                      bar,
                    ],
                  ),
                );
                return Listener(
                  onPointerDown: _beginInteraction,
                  onPointerMove: _updateInteraction,
                  onPointerUp: (_) => _endInteraction(),
                  onPointerCancel: (_) => _endInteraction(),
                  child: surface,
                );
              },
            ),
          ),
        ),
      );
    }
    if (widget.lightMaterial) {
      return OhosLightMaterial(
        level: widget.lightLevel,
        gradientFade: OhosLightFade.bottom,
        gradientExtent: 24,
        child: Material(color: Colors.transparent, child: bar),
      );
    }
    return Material(color: background, child: bar);
  }

  @override
  Widget build(BuildContext context) => _buildBar(context);
}

/// Paints the press lens and colored caustics at the touch point while the
/// finger is down (光感交互：指尖光晕).
class _OhosNavGlowPainter extends CustomPainter {
  const _OhosNavGlowPainter({
    required this.pointer,
    required this.progress,
    required this.glowColors,
  });

  final Offset pointer;
  final double progress;
  final List<Color> glowColors;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (progress <= 0) {
      return;
    }
    // Colored caustics around the pointer.
    for (int i = 0; i < glowColors.length; i++) {
      final Offset offset = Offset(
        (i - 1) * 14,
        (i.isEven ? -1 : 1) * 8,
      );
      final Rect causticRect = Rect.fromCenter(
        center: pointer + offset,
        width: 72 + i * 10,
        height: canvasSize.height * .5,
      );
      canvas.drawOval(
        causticRect,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              glowColors[i].withValues(alpha: (.18 * progress).clamp(0.0, 1.0)),
              glowColors[i].withValues(alpha: (.06 * progress).clamp(0.0, 1.0)),
              Colors.transparent,
            ],
            stops: const <double>[0, .45, 1],
          ).createShader(causticRect)
          ..blendMode = BlendMode.plus,
      );
    }
    // Bright white lens at the touch point.
    final Rect lensRect = Rect.fromCenter(
      center: pointer,
      width: 64,
      height: canvasSize.height * .6,
    );
    canvas.drawOval(
      lensRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: (.30 * progress).clamp(0.0, 1.0)),
            Colors.white.withValues(alpha: (.08 * progress).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
        ).createShader(lensRect)
        ..blendMode = BlendMode.screen,
    );
  }

  @override
  bool shouldRepaint(covariant _OhosNavGlowPainter oldDelegate) {
    return oldDelegate.pointer != pointer ||
        oldDelegate.progress != progress ||
        oldDelegate.glowColors != glowColors;
  }
}

class _OhosNavItem extends StatelessWidget {
  const _OhosNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.inline,
    required this.iconSize,
  });

  final OhosNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool inline;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color highlight = theme.highlightColor;
    final Color labelColor = selected ? highlight : theme.textSecondaryColor;
    final Color pillColor = selected
        ? (theme.emphasizeSecondaryColor ??
              highlight.withValues(alpha: 0.20))
        : Colors.transparent;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IconTheme.merge(
              data: IconThemeData(color: labelColor, size: iconSize),
              child: selected
                  ? (destination.selectedIcon ?? destination.icon)
                  : destination.icon,
            ),
            if (destination.badge != null)
              Positioned(top: -6, right: -8, child: destination.badge!),
          ],
        ),
        if (inline && selected)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              destination.label,
              style: theme.typography.labelSmall?.copyWith(
                color: highlight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
    if (inline) {
      return InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: OhosGeometry.durationShort,
          curve: OhosGeometry.spring,
          padding: EdgeInsets.symmetric(
            horizontal: selected ? 14 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: content,
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: OhosGeometry.durationShort,
            curve: OhosGeometry.spring,
            width: 56,
            height: selected ? 32 : 26,
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(selected ? 16 : 13),
            ),
            child: Center(child: content),
          ),
          const SizedBox(height: 1),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (theme.typography.labelSmall ??
                    const TextStyle(fontSize: 10))
                .copyWith(color: labelColor, fontSize: 10, height: 1.2),
          ),
        ],
      ),
    );
  }
}
