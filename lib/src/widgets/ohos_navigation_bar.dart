import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_light_material.dart';
import 'ohos_press_feedback.dart';

/// Destination model of an [OhosNavigationBar].
class OhosNavigationDestination {
  const OhosNavigationDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge,
    this.bleedIcon,
  });

  /// Icon shown while the destination is selected.
  final Widget icon;

  /// Icon shown when the destination is not selected.
  final Widget? selectedIcon;

  /// The label below the icon.
  final String label;

  /// Optional widget overlaying the icon corner (e.g. [OhosBadge]).
  final Widget? badge;

  /// 运营位内容（官方 `bleedIconStyle(builder)`）。
  ///
  /// 非空时这一项不再渲染常规的 `icon + label`，改为渲染运营位 —— 也就是
  /// 官方「自定义运营页签样式」（4 个基础页签 + 1 个运营页签的 4+1 形态）。
  /// 两条官方原文：
  ///
  /// - 悬浮式：「图标居中对齐显示，运营资源**可向上出血 4 vp**」；
  /// - 平铺式：「图标居中对齐显示，保证**上下安全间距为 4vp**」。
  ///
  /// 官方 API 里这个 builder 拿到的是一整块**自定义内容**（示例给的是
  /// `Image().width(48).height(48).borderRadius(24)`），所以这里同样不做
  /// 任何「圆底 + 图标」的拆解：调用方自己决定画什么、谁是圆底、谁探出去。
  ///
  /// 组件只负责给这块内容一个**上限**并居中，不规定必须画多大：
  ///
  /// - 悬浮式：上限 `栏高 + 2×4`（56 → 64），画满时上下各越界 4vp，也就是
  ///   「可向上出血 4 vp」；
  /// - 平铺式：上限 `栏高 − 2×4`（48 → 40），保证上下各留 4vp 安全间距。
  ///
  /// 上限由 [OhosNavigationBar.bleedExtentOf] 给出。**内容可以画到上限之外**
  /// —— 组件这层不裁，只要宿主没把栏包进 `ClipRect`（悬浮栏自己就不裁，见
  /// [OhosNavigationBar.bleedOverflow]）。
  final Widget? bleedIcon;

  /// 是否为运营位（有 [bleedIcon]）。
  bool get isBleed => bleedIcon != null;
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
/// - 平铺式 height 48vp / 悬浮式 height 56vp (3-5 destinations, icon 24x24vp,
///   label 10vp).
/// - **两种形态的排布完全一致：图标在上、文字在下，每一项都带文字。** 这一点
///   两张官方默认态配图都画得很清楚（`平铺式默认页签样式` / `悬浮式默认页签
///   样式` 各四个页签，四个都带 `Tab` 文字）。早先悬浮式按「图标 + 文字横排」
///   做、且只给选中项渲染文字，于是同一栏里选中项是「横向一组」、其余是
///   单个图标 —— 两侧留白天然不等，看起来就是「图标不对称」。横排布局确实
///   存在，但它是 `LayoutMode.HORIZONTAL`（横屏 / 短高场景）的独立形态，
///   不是悬浮式的默认排布。
/// - **激活态只有换色，没有药丸背板。** 官方规范原文：「被激活的页签应有明确
///   的视觉反馈，如使用品牌高亮色显示，或增加激活动效」，配图里选中项也只是
///   图标与文字转成品牌蓝。早先画了一块 `borderRadius: 22` 的高亮块、还按
///   选中与否改水平内边距（14 / 10），既偏离官方，又让选中项的内容宽度随
///   状态变化 —— 这正是「背景色和边框连在一起」的直接来源。
/// - In 悬浮式 + [lightMaterial] mode the bar uses the immersive-light
///   backplate; with [glow] enabled the light pools travel to the selected
///   destination and a bright lens follows the finger while pressing —
///   the 「光感交互」 behavior from the bottom-tab guideline.
/// - 运营位（[OhosNavigationDestination.bleedIcon]）按官方「自定义运营页签
///   样式」渲染：固定尺寸框 + 不裁剪，内容可向上出血 4vp。
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
    this.maxTextScaleFactor = 1.15,
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

  /// Upper bound of the system text scale applied to the 平铺式 label.
  ///
  /// The tile label is a fixed 10vp design size and the bar is 48vp tall, so
  /// the 1.3x accessibility scale would overflow it by 1vp; the label is
  /// therefore clamped to 1.15x (Mate 60 Pro 出厂档) by default.
  ///
  /// Pass `null` to stop clamping and let the label follow the system scale
  /// (`TextOverflow.ellipsis` still applies) — combine it with a taller
  /// [height] so the label has room, e.g. `height: 64`. Ignored for
  /// [OhosNavigationBarType.float], whose label sits inline and already scales.
  final double? maxTextScaleFactor;

  /// 运营位资源允许越出栏体的距离（官方 4 vp）。
  ///
  /// **官方**：`bottomtab` 规范
  ///
  /// - 悬浮式：「图标居中对齐显示，运营资源**可向上出血 4 vp**」；
  /// - 平铺式：「图标居中对齐显示，保证**上下安全间距为 4vp**」。
  ///
  /// 两条规则的**方向相反**，官方两张标注图逐像素核对也印证了这一点：
  ///
  /// - `bleed_float.png`：56vp 标注线 = 114px（DPR 2.036）即栏体，运营位的
  ///   圆底直径 127px ≈ 62vp、书顶比栏顶高 8px ≈ 4vp —— 资源**可以**画到
  ///   栏体之外，上下各最多 4vp。
  /// - `bleed_tile.png`：48vp 标注线 = 112px，资源图上下各留 7px ≈ 4vp ——
  ///   资源**必须**留在栏内，上下各留 4vp 安全间距。
  ///
  /// 所以悬浮式的可绘制范围是 `栏高 + 2×4`，平铺式是 `栏高 − 2×4`，见
  /// [bleedExtentOf]。这也是**不能**把两者写成同一个数的原因。
  static const double bleedOverflow = 4;

  /// 运营位资源的最大可绘制边长。
  ///
  /// - 悬浮式：`栏高 + 2 × bleedOverflow`（56 → 64），资源允许上下各越界 4vp；
  /// - 平铺式：`栏高 − 2 × bleedOverflow`（48 → 40），上下各留 4vp 安全间距。
  ///
  /// **不要把它当成布局尺寸**：悬浮式那 64 比栏体还高，布局仍按栏高走，
  /// 越界部分靠不裁剪的 `OverflowBox` 画出去（[OhosNavigationBar] 内部处理）。
  static double bleedExtentOf(double barHeight, OhosNavigationBarType type) =>
      type == OhosNavigationBarType.float
      ? barHeight + 2 * bleedOverflow
      : barHeight - 2 * bleedOverflow;

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

  double get _defaultHeight =>
      widget.type == OhosNavigationBarType.float ? 56 : 48;

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
      _indexAnimation =
          Tween<double>(
            begin: begin,
            end: widget.currentIndex.toDouble(),
          ).animate(
            CurvedAnimation(
              parent: _selectionController,
              curve: OhosGeometry.easeOut,
            ),
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
    // 页签内容层。**它和背板是两层**：背板要按胶囊裁剪（模糊、高光、亮线都
    // 只在圆角内有效），而运营位的内容要能画到栏体之外（官方「出血 4vp」）。
    // 早先两者是同一层 —— 材质内部的 `ClipRRect` 会把出血连根削平，看起来就是
    // 资源被压平了顶。分开之后背板照旧裁，内容层 `Clip.none`。
    final Widget content = SizedBox(
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
                  barHeight: _effectiveHeight,
                  iconSize: widget.iconSize,
                  maxTextScaleFactor: widget.maxTextScaleFactor,
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
      // 栏体左右 16vp 是官方 `barSideMargin` 在 <600vp 宽度下的默认值。
      //
      // **不要在栏内再加竖向内边距。** 官方标注图里 `56` 指的是栏体本身
      // 的高度，图标 24 与文字在栏内垂直居中，页签因此占满 56vp 全高。早先
      // 想让选中块离上下边远一点而给 `Padding(vertical: 4)`，结果页签只剩
      // 48vp —— 那是把「选中块该内缩」错当成「所有页签都该内缩」。真正要
      // 内缩的只有选中块那一层（见 `_OhosNavItem` 里的 `Positioned.fill` +
      // `Padding(all: 4)`），内容层保持占满，大字号下才不会溢出。
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[
              _selectionController,
              _pressController,
            ]),
            builder: (BuildContext context, Widget? child) {
              final double press = _pressController.value;
              final Alignment glowAlignment = widget.glow
                  ? Alignment(_glowX(), .1)
                  : Alignment.center;
              final Widget backplate = OhosLightMaterial(
                level: widget.lightLevel,
                // 胶囊半径必须交给材质：内部模糊背板、漫射层、边缘高光与
                // 顶部亮线都按 `borderRadius` 算形状，漏传就退化成直角矩形，
                // 高光会在圆角处被硬切。
                borderRadius: BorderRadius.circular(_effectiveHeight / 2),
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
                  ],
                ),
              );
              return Listener(
                onPointerDown: _beginInteraction,
                onPointerMove: _updateInteraction,
                onPointerUp: (_) => _endInteraction(),
                onPointerCancel: (_) => _endInteraction(),
                child: SizedBox(
                  key: _barKey,
                  height: _effectiveHeight,
                  // `Clip.none` 是运营位出血能画出去的唯一前提 —— 见
                  // [OhosNavigationDestination.bleedIcon] 的说明。
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: <Widget>[backplate, content],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    if (widget.lightMaterial) {
      return OhosLightMaterial(
        level: widget.lightLevel,
        gradientFade: OhosLightFade.bottom,
        gradientExtent: 24,
        child: Material(color: Colors.transparent, child: content),
      );
    }
    return Material(color: background, child: content);
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
      final Offset offset = Offset((i - 1) * 14, (i.isEven ? -1 : 1) * 8);
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
    required this.barHeight,
    required this.iconSize,
    required this.maxTextScaleFactor,
  });

  final OhosNavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  /// 是否为悬浮式。**只影响字号与间距，不影响排布方向** —— 两种形态都是
  /// 「图标在上、文字在下」，见 [OhosNavigationBar] 的类注释。
  final bool inline;

  /// 栏体的实际高度（含调用方自定义的 [OhosNavigationBar.height]）。
  ///
  /// 运营位的可绘制上限由它推出来（[OhosNavigationBar.bleedExtentOf]），
  /// **不能写死 56 / 48** —— 那是默认栏高，调用方改高栏体后出血余量要跟着动。
  final double barHeight;
  final double iconSize;
  final double? maxTextScaleFactor;

  /// 悬浮式栏高 56vp，比平铺式多 8vp，可以给文字一档更大的字号。
  ///
  /// **自拟**：官方只给「图标 24×24vp」和「默认文字 10vp」（那是平铺式的值），
  /// 悬浮式配图的文字明显更大，但三张资源表里没有对应令牌，参考文档也只给
  /// 「横屏左右布局时文字 10 → 12vp」这一条换算法。取 11vp：比平铺大一档、
  /// 又不至于在 56vp 里和图标挤在一起。
  static const double _floatLabelSize = 11;

  static const double _tileLabelSize = 10;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    if (destination.isBleed) {
      return _buildBleed(context, theme);
    }
    final OhosSelectionMark mark = theme.policy.selectionMark;
    // 反白：墨屏里「品牌色」与正文色都是纯黑，换色表达不出选中；改为实底
    // 高亮 + `onHighlightColor` 的字，靠明度反差立住。彩屏 `tint` 走换色。
    final bool inverse = selected && mark == OhosSelectionMark.inverse;
    final Color highlight = theme.highlightColor;
    final Color fgColor = !selected
        ? theme.textSecondaryColor
        : (inverse ? theme.onHighlightColor : highlight);

    final Widget glyph = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconTheme.merge(
          data: IconThemeData(color: fgColor, size: iconSize),
          child: selected
              ? (destination.selectedIcon ?? destination.icon)
              : destination.icon,
        ),
        if (destination.badge != null)
          Positioned(top: -6, right: -8, child: destination.badge!),
      ],
    );

    final double labelSize = inline ? _floatLabelSize : _tileLabelSize;
    final Text label = Text(
      destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style:
          (theme.typography.labelSmall ??
                  TextStyle(fontSize: labelSize, height: 1.2))
              .copyWith(
                color: fgColor,
                fontSize: labelSize,
                height: 1.2,
                // 加粗只在高对比策略下用：`emphasis` 的语义是「形状与线宽
                // 变化，不依赖色相」，彩屏上再多加一档粗体反而偏离官方配图。
                fontWeight: selected && mark == OhosSelectionMark.emphasis
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
    );

    // 内容宽度必须**与选中态无关**。早先悬浮式按 `selected ? 14 : 10` 改水平
    // 内边距，选中项的内容整体被撑宽，图标相对栏中心就偏了 —— 「两侧图标不
    // 对称」的观感一半来自这里。
    final Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        glyph,
        // 官方标注图里图标与文字的间距写的就是 `2`（`float_default.png` 与
        // `tile_default.png` 的下半部分标注区都标了这一项），两种形态同值。
        const SizedBox(height: 2),
        // Flexible 让长文案在窄项里被压缩并省略，而不是把栏顶宽。
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: label,
          ),
        ),
      ],
    );

    // 选中态：反白画实底胶囊，其余只换色。
    //
    // 实底必须画在**背景层**（`Positioned.fill` + 内缩），不能靠 `Padding`
    // 收窄内容区：一收窄，`Icon(24) + 间距 + 单行标签` 在大字号下就撑破，
    // 而未选中项仍占满整条 —— 于是只有选中项溢出。这个坑在悬浮页签栏里已经
    // 踩过一轮，结论一致。
    final double radius = inline ? 22 : 16;
    const double inset = 4;
    Widget tapTarget = OhosPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Center(child: content),
    );
    if (inverse) {
      tapTarget = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(inset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: highlight,
                  borderRadius: BorderRadius.circular(
                    (radius - inset).clamp(0.0, double.infinity),
                  ),
                ),
              ),
            ),
          ),
          tapTarget,
        ],
      );
    }
    if (inline) {
      return tapTarget;
    }
    // 平铺式：40vp 高的栏体里，48vp 系统最小触控热区由外层 `Expanded` 撑满
    // 高度给出，这里不额外加内边距，否则 1.3x 字号下会溢出。
    //
    // 标签是固定 10vp 的设计字号，系统字体放大后行高会涨，48vp 的平铺栏装不
    // 下（1.3x 时溢出 1vp）。默认限制最大放大倍数我们交给外层
    // `MediaQuery.withClampedTextScaling`，标签自身仍可被压缩。
    final Widget tile = tapTarget;
    if (maxTextScaleFactor == null) {
      return tile;
    }
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScaleFactor!,
      child: tile,
    );
  }

  /// 运营位（官方「自定义运营页签样式」）。
  ///
  /// 布局意图只有一句：**给资源一块带上限的框，并保证这块框能画到框外**。
  ///
  /// - 框的边长上限见 [OhosNavigationBar.bleedExtentOf]：默认栏高下悬浮 64
  ///   （56 + 上下各 4vp）、平铺 40（48 − 上下各 4vp）；栏高被调用方改过时
  ///   上限跟着 [barHeight] 走，不是写死的 64 / 40。
  /// - 框**不裁剪**（`OverflowBox` + `Clip.none`），所以内容只要画得比框高就会
  ///   溢出到框外 —— 悬浮式那 4vp 的上余量正是官方标注图里「出血 4vp」的位置。
  /// - **不要在这里画圆底。** 官方的 `bleedIconStyle` 交给开发者的是一个 builder，
  ///   示例内容是 `Image().width(48).height(48).borderRadius(24)` —— 圆底属于
  ///   资源内容本身（`borderRadius` 裁的是那张图），不是组件提供的底板。早先
  ///   想过「组件画圆 + 资源叠在上面」，那样调用方放正方形插画时圆底会露出来
  ///   一圈，而官方配图里没有那一圈。
  Widget _buildBleed(BuildContext context, OhosThemeData theme) {
    // 用实际栏高推上限：默认悬浮 64（56 + 上下各 4vp）、平铺 40（48 − 上下各
    // 4vp）；调用方自定义了 `height` 时余量仍按官方 4vp，但基数跟着栏体走。
    final double extent = OhosNavigationBar.bleedExtentOf(
      barHeight,
      inline ? OhosNavigationBarType.float : OhosNavigationBarType.tile,
    );
    // **`OverflowBox` 是出血能真的画出去的前提。** 页签格只有 `栏高` 这么高，
    // 直接放内容会拿到「最大 56」的约束 —— 64 的资源被压回 56，出血就没了。
    // `OverflowBox` 给子节点无界约束，自身仍占 `栏高`，于是 64 的内容居中后
    // 自然地向上下各画出去 4vp。
    //
    // 里面再套 `ConstrainedBox` 而不是 `SizedBox`：官方只说「最多能画多大」，
    // 没说必须画满。用 `SizedBox` 会给紧约束，一张 24 的小图会被硬撑成 64，
    // 运营图就糊了。
    final Widget artwork = OverflowBox(
      minWidth: 0,
      maxWidth: double.infinity,
      minHeight: 0,
      maxHeight: double.infinity,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: extent, maxHeight: extent),
        child: destination.bleedIcon,
      ),
    );
    return OhosPressFeedback(
      onTap: onTap,
      semanticLabel: destination.label,
      // 热区仍是整个页签格（和普通页签一致），只是里面的内容小一圈。
      borderRadius: BorderRadius.circular(extent / 2),
      // 资源要能画到框外（悬浮式的 4vp 出血），本组件那层 `Stack` 不能裁。
      clipBehavior: Clip.none,
      child: Center(child: artwork),
    );
  }
}
