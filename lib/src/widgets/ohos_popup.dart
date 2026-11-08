import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// 气泡的官方几何，取自参考文档 `ts-universal-attributes-popup.md` 的
/// `PopupOptions` 参数表与设计规范《气泡提示》。
class OhosPopupMetrics {
  const OhosPopupMetrics._();

  /// 圆角（`PopupOptions.radius` 默认 **20vp**）。
  ///
  /// 老实现取 `OhosGeometry.radiusMedium = 16` —— 那是卡片的圆角档，气泡
  /// 官方比它大一档。
  static const double radius = 20;

  /// 箭头宽（`PopupOptions.arrowWidth` 默认 **16vp**）。
  static const double arrowWidth = 16;

  /// 箭头高（`PopupOptions.arrowHeight` 默认 **8vp**）。
  static const double arrowHeight = 8;

  /// 气泡与宿主节点的间距（`PopupOptions.targetSpace` 默认 **8vp**）。
  static const double targetSpace = 8;

  /// 气泡最大宽度上限（设计规范：「最大拉伸到 **400vp** 宽度时不再跟随放大」）。
  ///
  /// 老实现写死 260 —— 那个数官方规格里没有。
  static const double maxWidth = 400;

  /// 气泡到屏幕边缘的最小距离（设计规范：「气泡到屏幕边缘最小可以到 **6vp**，
  /// 以保证尖角与点击元素可以对齐」）。
  static const double edgeMargin = 6;

  /// 箭头到气泡左右边缘的默认间距（设计规范：「箭头的边缘距离气泡边缘的
  /// 默认间距为 **20vp**」）。
  static const double arrowEdgeGap = 20;

  /// 气泡内边距。
  ///
  /// 官方参数表没有这一项（`messageOptions` 只管字体与颜色），取 16 / 10 ——
  /// 与「气泡内文字到框边」的常规留白一致，且和 [radius] 20 相配。
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 10,
  );

  /// 实际可用的最大宽度：`min(400, 窗口宽 − 两侧 edgeMargin)`。
  ///
  /// 与 `OhosAlertDialog` 同一个道理 —— **400 是上限，不是必然值**。360vp
  /// 屏上直接给 400 会让气泡贴住（甚至溢出）屏幕两侧。
  static double maxWidthFor(Size screen) =>
      math.min(maxWidth, screen.width - edgeMargin * 2);
}

/// 气泡相对宿主的朝向。
enum OhosPopupPlacement {
  /// 气泡在宿主下方，箭头朝上（官方默认 `Placement.Bottom`）。
  bottom,

  /// 气泡在宿主上方，箭头朝下。
  top,
}

/// Shows a pointing bubble popup anchored to a widget (气泡提示 in the
/// HarmonyOS guideline).
///
/// ```dart
/// showOhosPopup(
///   context: context,
///   content: '长按扫码支付',
///   targetKey: myButtonKey,
/// );
/// ```
///
/// 与老实现（无箭头浮层）的差别，全部有官方出处（见 [OhosPopupMetrics]）：
///
/// * **有箭头** —— `enableArrow` 默认 `true`、`arrowWidth 16`、`arrowHeight 8`。
///   箭头是「指向型气泡」的定义特征：没有它，气泡就只是浮在附近的另一个字块，
///   用户读不出「它在说哪个控件」。
/// * **圆角 20 而不是 16**、**最大宽 400 而不是 260**；
/// * **`targetSpace` 8vp**（老实现用 `anchor.dy - 12` 加 `Offset(0,-52)` 两个
///   魔数拼出来的偏移，既不是 8 也不跟随宿主体积）；
/// * **`placement: bottom` 默认**（老实现固定在上方）。
///
/// 箭头位置由「宿主中心投影到气泡上」决定，再夹进 `[arrowEdgeGap, 宽 −
/// arrowEdgeGap]`（设计规范：箭头到气泡边缘默认 20vp，官方 `arrowOffset` 为 0
/// 时箭头落在边缘）。
Future<void> showOhosPopup({
  required BuildContext context,
  required String content,
  required GlobalKey targetKey,
  Duration duration = const Duration(seconds: 2),
  OhosPopupPlacement placement = OhosPopupPlacement.bottom,
  bool showArrow = true,
  double? maxWidth,
}) {
  final OverlayState overlay = Overlay.of(context);
  final OhosThemeData theme = OhosTheme.of(context);
  final RenderBox box =
      targetKey.currentContext!.findRenderObject()! as RenderBox;
  final Offset position = box.localToGlobal(Offset.zero);
  final Size size = box.size;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) {
      return Positioned(
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: IgnorePointer(
          child: CustomSingleChildLayout(
            delegate: _OhosPopupLayout(
              anchor: position,
              anchorSize: size,
              placement: placement,
              showArrow: showArrow,
              theme: theme,
              maxWidth: maxWidth,
            ),
            child: _OhosPopupBody(
              content: content,
              theme: theme,
              showArrow: showArrow,
              placement: placement,
              anchor: position,
              anchorSize: size,
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
  return Future<void>.delayed(duration);
}

/// 把气泡摆到宿主旁边，并算出箭头落点。
class _OhosPopupLayout extends SingleChildLayoutDelegate {
  _OhosPopupLayout({
    required this.anchor,
    required this.anchorSize,
    required this.placement,
    required this.showArrow,
    required this.theme,
    required this.maxWidth,
  });

  final Offset anchor;
  final Size anchorSize;
  final OhosPopupPlacement placement;
  final bool showArrow;
  final OhosThemeData theme;
  final double? maxWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final double cap =
        maxWidth ?? OhosPopupMetrics.maxWidthFor(constraints.biggest);
    return BoxConstraints(
      maxWidth: math.max(0, cap),
      maxHeight: math.max(0, constraints.maxHeight),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double space = OhosPopupMetrics.targetSpace;
    final double arrow = showArrow ? OhosPopupMetrics.arrowHeight : 0;
    // 水平：气泡中心对齐宿主中心，再夹进窗口（留 edgeMargin 余量）。
    double dx = anchor.dx + anchorSize.width / 2 - childSize.width / 2;
    final double margin = OhosPopupMetrics.edgeMargin;
    dx = dx.clamp(margin, math.max(margin, size.width - childSize.width - margin));
    double dy;
    switch (placement) {
      case OhosPopupPlacement.bottom:
        dy = anchor.dy + anchorSize.height + space + arrow;
        // 下方放不下就翻到上方 —— 官方「如果开发者设置的位置上无法完整
        // 显示气泡，气泡会自动避让至可以完整显示的位置」。
        if (dy + childSize.height > size.height - margin) {
          dy = anchor.dy - space - arrow - childSize.height;
        }
      case OhosPopupPlacement.top:
        dy = anchor.dy - space - arrow - childSize.height;
        if (dy < margin) {
          dy = anchor.dy + anchorSize.height + space + arrow;
        }
    }
    return Offset(dx, dy);
  }

  /// 箭头相对气泡的水平位置。
  ///
  /// 设计规范「箭头的边缘距离气泡边缘的默认间距为 20vp」，所以落点夹在
  /// `[20, 宽 − 20]`；宿主中心恰好投影到气泡上时箭头指向它。
  double arrowX(Size childSize) {
    final double center = anchor.dx + anchorSize.width / 2;
    final double local = center - getPositionForChild(
      Size.zero,
      childSize,
    ).dx;
    final double gap = OhosPopupMetrics.arrowEdgeGap;
    final double upper = math.max(gap, childSize.width - gap);
    return local.clamp(gap, upper);
  }

  @override
  bool shouldRelayout(_OhosPopupLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      anchorSize != oldDelegate.anchorSize ||
      placement != oldDelegate.placement ||
      showArrow != oldDelegate.showArrow;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;
}

/// 气泡本体：圆角矩形 + 一个真正画出来的尖角。
class _OhosPopupBody extends StatelessWidget {
  const _OhosPopupBody({
    required this.content,
    required this.theme,
    required this.showArrow,
    required this.placement,
    required this.anchor,
    required this.anchorSize,
  });

  final String content;
  final OhosThemeData theme;
  final bool showArrow;
  final OhosPopupPlacement placement;

  /// 宿主左上角（全局坐标）与尺寸，用于算箭头落点。
  final Offset anchor;
  final Size anchorSize;

  @override
  Widget build(BuildContext context) {
    final double arrowW = OhosPopupMetrics.arrowWidth;
    final double arrowH = showArrow ? OhosPopupMetrics.arrowHeight : 0;
    // 尖角用 `CustomPaint` 画在圆角框的顶上（或底下）：用 `ClipPath` 裁一个
    // 三角形会连带把圆角框的边裁掉，而且在墨水屏上三角形内部是「填色」，
    // 与主题的 `usesOutlines` 一脉不通。这里让三角形与底板同色，墨屏时再补
    // 一条轮廓线，与框体一致。
    final Widget bubble = Container(
      padding: OhosPopupMetrics.padding,
      decoration: BoxDecoration(
        color: theme.popupColor,
        borderRadius: BorderRadius.circular(OhosPopupMetrics.radius),
        // 墨水屏上浅阴影在白底上等于没有，改 1px 实线托住边界。
        border: theme.usesOutlines
            ? Border.all(
                color: theme.dividerColor,
                width: ohosStrokeWidth(context, theme.outlineWidth),
              )
            : null,
        boxShadow: !theme.policy.allowsShadow
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Text(
        content,
        // 这条提示挂在根 Overlay 上，没有 `Material` 祖先，
        // `MaterialApp` 的兜底 `DefaultTextStyle` 会带来黄色双下划线与
        // monospace 字体。`inherit: false` 断掉继承，字体族仍跟随主题。
        style:
            (theme.typography.bodySmall ?? const TextStyle(fontSize: 14))
                .copyWith(
                  color: theme.textPrimaryColor,
                  decoration: TextDecoration.none,
                  inherit: false,
                ),
      ),
    );
    if (!showArrow) {
      return bubble;
    }
    final bool arrowOnTop = placement == OhosPopupPlacement.bottom;
    // 箭头落点要靠「气泡最终宽度」才能算准，而宽度又是内容决定的 ——
    // `crossAxisAlignment.stretch` 让每个子节点拿到**紧**宽度约束，于是
    // `LayoutBuilder` 里读到的就是气泡真实宽度，与 `_OhosPopupLayout`
    // 摆位用的那一个一致（两处都按「居中 + 夹边」算，公式必须相同）。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (arrowOnTop)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) =>
                _arrow(context, c.maxWidth, arrowW, arrowH, theme),
          ),
        bubble,
        if (!arrowOnTop)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) =>
                _arrow(context, c.maxWidth, arrowW, arrowH, theme),
          ),
      ],
    );
  }

  /// 一条与气泡等宽的箭头带，三角形画在 [arrowX] 处。
  Widget _arrow(
    BuildContext context,
    double bubbleWidth,
    double arrowWidth,
    double arrowHeight,
    OhosThemeData theme,
  ) {
    final bool up = placement == OhosPopupPlacement.bottom;
    return SizedBox(
      height: arrowHeight,
      width: bubbleWidth,
      child: CustomPaint(
        painter: _OhosPopupArrowPainter(
          color: theme.popupColor,
          pointingUp: up,
          arrowWidth: arrowWidth,
          arrowX: _arrowX(bubbleWidth, arrowWidth, context),
          outline: theme.usesOutlines ? theme.dividerColor : null,
          outlineWidth: theme.outlineWidth,
        ),
      ),
    );
  }

  /// 箭头中心相对气泡左沿的位置。
  ///
  /// 先按「气泡居中于宿主」的假设算气泡左沿，再夹边到屏幕 —— 与
  /// `_OhosPopupLayout.getPositionForChild` 完全同一个公式（改一处必须改
  /// 另一处，否则箭头会指偏）。最后把落点夹进 `[arrowEdgeGap, 宽 − gap]`，
  /// 对应设计规范「箭头的边缘距离气泡边缘的默认间距为 20vp」。
  double _arrowX(double bubbleWidth, double arrowWidth, BuildContext context) {
    final double screenW = MediaQuery.sizeOf(context).width;
    final double center = anchor.dx + anchorSize.width / 2;
    double left = center - bubbleWidth / 2;
    final double margin = OhosPopupMetrics.edgeMargin;
    left = left.clamp(
      margin,
      math.max(margin, screenW - bubbleWidth - margin),
    );
    final double gap = math.max(
      OhosPopupMetrics.arrowEdgeGap + arrowWidth / 2,
      math.min(
        OhosPopupMetrics.arrowEdgeGap + arrowWidth / 2,
        bubbleWidth / 2,
      ),
    );
    final double upper = math.max(gap, bubbleWidth - gap);
    return (center - left).clamp(gap, upper);
  }
}

class _OhosPopupArrowPainter extends CustomPainter {
  _OhosPopupArrowPainter({
    required this.color,
    required this.pointingUp,
    required this.arrowWidth,
    required this.arrowX,
    required this.outline,
    required this.outlineWidth,
  });

  final Color color;
  final bool pointingUp;

  /// 三角形宽（官方 `arrowWidth` 16vp）。
  final double arrowWidth;

  /// 三角形中心距本带左沿的距离。
  final double arrowX;

  final Color? outline;
  final double outlineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();
    final double l = arrowX - arrowWidth / 2;
    final double r = arrowX + arrowWidth / 2;
    if (pointingUp) {
      path
        ..moveTo(l, size.height)
        ..lineTo(arrowX, 0)
        ..lineTo(r, size.height);
    } else {
      path
        ..moveTo(l, 0)
        ..lineTo(arrowX, size.height)
        ..lineTo(r, 0);
    }
    canvas.drawPath(path, Paint()..color = color);
    final Color? line = outline;
    if (line != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth,
      );
    }
  }

  @override
  bool shouldRepaint(_OhosPopupArrowPainter oldDelegate) =>
      color != oldDelegate.color ||
      pointingUp != oldDelegate.pointingUp ||
      arrowX != oldDelegate.arrowX ||
      arrowWidth != oldDelegate.arrowWidth ||
      outline != oldDelegate.outline;
}
