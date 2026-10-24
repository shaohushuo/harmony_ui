import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_magnifier_position.dart';

/// A floating bubble that magnifies whatever is under the finger — the
/// 放大镜 of the HarmonyOS index strip and, later, of text selection.
///
/// The widget only draws the bubble; where it goes is
/// [OhosMagnifierPosition]'s job, and showing it above other content is
/// [OhosMagnifierController]'s. Everything is wrapped in [IgnorePointer], so a
/// bubble can never steal a gesture from the widget it belongs to.
///
/// Two ways to fill it:
///
/// * [text] — the common case (one letter or a short word), drawn with a size
///   derived from [size];
/// * [child] — anything else, for example a `Text` with a selection highlight
///   or a small preview.
class OhosMagnifier extends StatelessWidget {
  const OhosMagnifier({
    super.key,
    this.text,
    this.child,
    this.size = const Size.square(48),
    this.textStyle,
    this.backgroundColor,
    this.borderColor,
    this.animate = true,
  }) : assert(
         text != null || child != null,
         'OhosMagnifier 需要 text 或 child 之一',
       );

  /// Convenience content: a single letter / short word, auto-sized to [size].
  final String? text;

  /// Arbitrary content; wins over [text] when both are given.
  final Widget? child;

  /// Diameter of the circular bubble.
  final Size size;

  /// Overrides the style used for [text].
  final TextStyle? textStyle;

  /// Overrides the bubble background (defaults to the theme's card color).
  final Color? backgroundColor;

  /// Overrides the 1px border.
  final Color? borderColor;

  /// Fade + scale-in when the bubble first appears.
  ///
  /// Ignored on monochrome (e-ink) themes, where every animation leaves a
  /// smear; the bubble then shows up at once.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool ink = theme.monochrome;
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(size.height / 2),
    );
    final TextStyle style =
        textStyle ??
        (theme.typography.titleLarge ?? const TextStyle()).copyWith(
          fontSize: size.height * 0.55,
          height: 1,
          fontWeight: FontWeight.w600,
          color: ink ? theme.textPrimaryColor : theme.highlightColor,
        );
    final Widget content =
        child ??
        Text(
          text!,
          style: style,
          maxLines: 1,
          textAlign: TextAlign.center,
        );
    final Widget bubble = Container(
      width: size.width,
      height: size.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (ink ? theme.backgroundColor : theme.cardColor),
        borderRadius: radius,
        // 单色主题靠 1px 纯黑描边划出边界（墨水屏没有阴影可用），彩色主题
        // 用一条很淡的 hairline，避免与卡片面糊在一起。
        border: Border.all(
          color:
              borderColor ??
              (ink
                  ? Colors.black
                  : theme.textTertiaryColor.withValues(alpha: 0.3)),
        ),
      ),
      // 大字号（textScale 1.3）时内容会比泡泡高，缩下来而不是溢出。
      child: FittedBox(fit: BoxFit.scaleDown, child: content),
    );
    final Widget body = animate && !ink
        ? TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: OhosGeometry.durationShort,
            curve: OhosGeometry.spring,
            builder: (BuildContext context, double t, Widget? child) {
              // spring 曲线会过冲到 1 以上：缩放可以让它过冲（更有弹性），
              // 但 Opacity 必须夹在 [0, 1]。
              final double fade = t < 0 ? 0 : (t > 1 ? 1 : t);
              return Opacity(
                opacity: fade,
                child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
              );
            },
            child: bubble,
          )
        : bubble;
    return IgnorePointer(child: ExcludeSemantics(child: body));
  }
}

/// Shows one [OhosMagnifier] above the rest of the UI and keeps it under the
/// finger.
///
/// Typical use is a drag: [show] on drag start, [update] on every move, [hide]
/// on release. The bubble lives in the nearest [Overlay], so it can paint
/// outside its host's bounds — an index strip inside a clipping list, for
/// instance — and it never takes part in hit testing.
class OhosMagnifierController {
  _MagnifierRequest? _request;
  OverlayEntry? _entry;

  /// Whether the bubble is currently mounted.
  bool get isShowing => _entry != null;

  /// Shows the bubble at [anchor] (global coordinates).
  ///
  /// Returns false when there is no [Overlay] above [context] — a bare widget
  /// tree outside `MaterialApp` / `WidgetsApp`; nothing is shown then.
  bool show(
    BuildContext context, {
    required Offset anchor,
    String? text,
    Widget? child,
    Size bubble = const Size.square(48),
    OhosMagnifierSide side = OhosMagnifierSide.auto,
    EdgeInsets safeInset = EdgeInsets.zero,
    double gap = 12,
  }) {
    assert(text != null || child != null, 'OhosMagnifierController 需要 text 或 child');
    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      debugPrint(
        'OhosMagnifierController: 当前树没有 Overlay（MaterialApp / WidgetsApp '
        '会提供），放大镜不显示。',
      );
      return false;
    }
    _request = _MagnifierRequest(
      anchor: anchor,
      text: text,
      child: child,
      bubble: bubble,
      side: side,
      safeInset: safeInset,
      gap: gap,
      theme: OhosTheme.of(context),
    );
    if (_entry == null) {
      _entry = OverlayEntry(builder: _build);
      overlay.insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
    return true;
  }

  /// Moves the bubble to [anchor], optionally swapping what it shows.
  void update(Offset anchor, {String? text, Widget? child}) {
    final _MagnifierRequest? request = _request;
    if (request == null) {
      return;
    }
    _request = request.copyWith(
      anchor: anchor,
      text: text ?? request.text,
      child: child ?? request.child,
    );
    _entry?.markNeedsBuild();
  }

  /// Removes the bubble; safe to call when nothing is shown.
  void hide() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  /// Releases the overlay entry; call it from `State.dispose`.
  void dispose() => hide();

  Widget _build(BuildContext context) {
    final _MagnifierRequest? request = _request;
    if (request == null) {
      return const SizedBox.shrink();
    }
    final MediaQueryData media = MediaQuery.of(context);
    final OhosMagnifierPlacement placement = OhosMagnifierPosition.resolve(
      anchor: request.anchor,
      bubble: request.bubble,
      safe: media.padding + request.safeInset,
      screen: media.size,
      side: request.side,
      gap: request.gap,
    );
    return Positioned(
      left: placement.offset.dx,
      top: placement.offset.dy,
      child: OhosTheme(
        // Overlay 不一定在 OhosTheme 之下（主题可能只包住页面），捕获一次
        // 调用方的主题，保证墨主题下泡泡也是墨的。
        data: request.theme,
        child: OhosMagnifier(
          size: placement.size,
          text: request.text,
          child: request.child,
        ),
      ),
    );
  }
}

@immutable
class _MagnifierRequest {
  const _MagnifierRequest({
    required this.anchor,
    required this.text,
    required this.child,
    required this.bubble,
    required this.side,
    required this.safeInset,
    required this.gap,
    required this.theme,
  });

  final Offset anchor;
  final String? text;
  final Widget? child;
  final Size bubble;
  final OhosMagnifierSide side;
  final EdgeInsets safeInset;
  final double gap;
  final OhosThemeData theme;

  _MagnifierRequest copyWith({
    Offset? anchor,
    String? text,
    Widget? child,
  }) {
    return _MagnifierRequest(
      anchor: anchor ?? this.anchor,
      text: text ?? this.text,
      child: child ?? this.child,
      bubble: bubble,
      side: side,
      safeInset: safeInset,
      gap: gap,
      theme: theme,
    );
  }
}
