import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';

/// 按压阴影类型 of [OhosPressShadow], mirroring
/// `hdsEffect.PressShadowType`:
/// - [blendWhite]: the surface blends toward white while pressed.
/// - [blendGradient]: a dark radial gradient follows the touch point.
enum OhosPressShadowType {
  /// No press feedback.
  none,

  /// White blend overlay while the pointer is down.
  blendWhite,

  /// Radial dark gradient centered at the touch point.
  blendGradient,
}

/// Wraps [child] with the HDS press-shadow (按压阴影) interaction:
/// `visualEffect(new HdsEffectBuilder().pressShadow(type))`.
///
/// While the pointer is down the surface shows a white blend (BLEND_WHITE) or
/// a radial gradient centered at the finger (BLEND_GRADIENT); releasing or
/// cancelling fades it back out. Add it around any HDS control to get the
/// official press look without depending on Ink ripples.
class OhosPressShadow extends StatefulWidget {
  const OhosPressShadow({
    super.key,
    required this.child,
    this.type = OhosPressShadowType.blendWhite,
    this.borderRadius = BorderRadius.zero,
    this.blendOpacity = 0.32,
  });

  /// The control that receives the press effect.
  final Widget child;

  /// Press shadow style.
  final OhosPressShadowType type;

  /// Corner radius used both to clip the overlay and to round the gradient.
  final BorderRadius borderRadius;

  /// Peak opacity of the white blend / dark gradient.
  final double blendOpacity;

  @override
  State<OhosPressShadow> createState() => _OhosPressShadowState();
}

class _OhosPressShadowState extends State<OhosPressShadow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset _pointer = Offset.zero;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OhosGeometry.durationPress,
      reverseDuration: OhosGeometry.durationShort,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDown(PointerDownEvent event) {
    if (widget.type == OhosPressShadowType.none) {
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    setState(() {
      _down = true;
      _pointer = box.globalToLocal(event.position);
    });
    _controller.forward(from: 0);
  }

  void _onMove(PointerMoveEvent event) {
    if (!_down) {
      return;
    }
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    setState(() => _pointer = box.globalToLocal(event.position));
  }

  void _onUp() {
    if (!_down) {
      return;
    }
    setState(() => _down = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: (_) => _onUp(),
      onPointerCancel: (_) => _onUp(),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: <Widget>[
            widget.child,
            if (widget.type != OhosPressShadowType.none)
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    return CustomPaint(
                      painter: _PressShadowPainter(
                        type: widget.type,
                        progress: Curves.easeOut.transform(_controller.value),
                        pointer: _pointer,
                        opacity: widget.blendOpacity,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PressShadowPainter extends CustomPainter {
  const _PressShadowPainter({
    required this.type,
    required this.progress,
    required this.pointer,
    required this.opacity,
  });

  final OhosPressShadowType type;
  final double progress;
  final Offset pointer;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }
    switch (type) {
      case OhosPressShadowType.none:
        return;
      case OhosPressShadowType.blendWhite:
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = Colors.white.withValues(alpha: opacity * progress),
        );
      case OhosPressShadowType.blendGradient:
        final double radius = size.longestSide * 0.75;
        final Rect rect = Rect.fromCircle(center: pointer, radius: radius);
        canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                Colors.black.withValues(alpha: opacity * progress),
                Colors.black.withValues(alpha: opacity * progress * 0.5),
                Colors.transparent,
              ],
              stops: const <double>[0, 0.5, 1],
            ).createShader(rect),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _PressShadowPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.progress != progress ||
        oldDelegate.pointer != pointer ||
        oldDelegate.opacity != opacity;
  }
}
