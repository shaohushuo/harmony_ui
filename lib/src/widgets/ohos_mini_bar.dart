import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_tabs_width.dart';

/// 页签栏 / 迷你栏的样式状态 —— 对应官方 `HdsBarStyle`（`COLLAPSE` / `EXPAND`）。
enum OhosBarStyle {
  /// 折叠样式（官方 `COLLAPSE = 0`）。
  collapse,

  /// 展开样式（官方 `EXPAND = 1`）。
  expand,
}

/// 页签栏 / 迷你栏的隐藏、显示动效模式 —— 对应官方 `HdsAnimationMode`。
///
/// 它不是「动画曲线」也不是「时长档位」，而是**由谁触发**：`SCROLL_ANIMATION`
/// 是内容区滚动带出来的，`CLICK_ANIMATION` 是用户点页签带出来的。两者的时长
/// 官方均未给出数值，本库取同一个短时长（[OhosGeometry.durationShort]）——
/// 这只是**自拟**，不要当成官方值转述。
enum OhosAnimationMode {
  /// 滚动动效（官方 `SCROLL_ANIMATION = 0`）。
  scroll,

  /// 点击动效（官方 `CLICK_ANIMATION = 1`）。
  click,
}

/// 迷你栏与页签栏的控制器 —— 对应官方 `HdsTabsController`。
///
/// 官方把这个控制器做的事分成两类：**折叠 / 展开状态**（`applyMiniBarStyle`、
/// `applyHideAnimation`、`applyShowAnimation`）与**滚动联动**（`bindScroller` /
/// `unbindScroller`）。两者机制完全不同，别混成一个「状态机」：
///
/// - 折叠 / 展开是一次**离散跳变**，动效只是它的附庸；
/// - 滚动联动是**连续位置**，绑定的是内容区那个滚动体，与栏的折叠状态无关
///   （官方原话：「跟手滑动效果依赖 HdsTabs 控制器绑定需要设置的 list 滑动控制器」）。
///
/// 容器侧监听 [addListener]，重绘时读 [miniBarStyle] / [tabBarStyle]。
class OhosTabsController extends ChangeNotifier {
  OhosTabsController({
    OhosBarStyle miniBarStyle = OhosBarStyle.collapse,
    OhosBarStyle tabBarStyle = OhosBarStyle.expand,
  }) : _miniBarStyle = miniBarStyle,
       _tabBarStyle = tabBarStyle;

  OhosBarStyle _miniBarStyle;
  OhosBarStyle _tabBarStyle;

  /// 最近一次 [applyShowAnimation] / [applyHideAnimation] 用的模式。
  ///
  /// 留这个记录是因为官方两个方法都收 `mode` 却只描述「调用显示/隐藏动效」，
  /// 没说它影响别的什么。如果哪天要按触发源分档时长，这里是唯一的线索。
  OhosAnimationMode? _lastAnimationMode;

  /// 页签索引 → 内容区滚动控制器。
  final Map<int, _BoundsScroller> _scrollers = <int, _BoundsScroller>{};

  OhosBarStyle get miniBarStyle => _miniBarStyle;

  OhosBarStyle get tabBarStyle => _tabBarStyle;

  OhosAnimationMode? get lastAnimationMode => _lastAnimationMode;

  /// 更新迷你栏样式（官方 `applyMiniBarStyle`）。
  ///
  /// 状态不变时不通知 —— 否则每次滚动回调都写一遍同样的值，
  /// 整棵子树会跟着重建，而肉眼什么都没发生。
  void applyMiniBarStyle(OhosBarStyle style) {
    if (_miniBarStyle == style) {
      return;
    }
    _miniBarStyle = style;
    notifyListeners();
  }

  /// 更新页签栏样式。
  ///
  /// **官方没有这个方法**：`applyMiniBarStyle` 只管迷你栏，页签栏的折叠是
  /// 用户点它自己触发的。本库补一个是因为容器要能同时接住两边的状态；
  /// 命名上与官方对齐，别误以为是官方 API。
  void applyTabBarStyle(OhosBarStyle style) {
    if (_tabBarStyle == style) {
      return;
    }
    _tabBarStyle = style;
    notifyListeners();
  }

  /// 隐藏动效（官方 `applyHideAnimation`）。折叠二者。
  void applyHideAnimation(OhosAnimationMode mode) {
    _lastAnimationMode = mode;
    final bool changed =
        _miniBarStyle != OhosBarStyle.collapse ||
        _tabBarStyle != OhosBarStyle.collapse;
    _miniBarStyle = OhosBarStyle.collapse;
    _tabBarStyle = OhosBarStyle.collapse;
    if (changed) {
      notifyListeners();
    }
  }

  /// 显示动效（官方 `applyShowAnimation`）。展开二者。
  void applyShowAnimation(OhosAnimationMode mode) {
    _lastAnimationMode = mode;
    final bool changed =
        _miniBarStyle != OhosBarStyle.expand ||
        _tabBarStyle != OhosBarStyle.expand;
    _miniBarStyle = OhosBarStyle.expand;
    _tabBarStyle = OhosBarStyle.expand;
    if (changed) {
      notifyListeners();
    }
  }

  /// 把某个页签的内容区滚动控制器绑进来（官方 `bindScroller`）。
  ///
  /// 官方第 3 个参数 `parentScroller` 是「滚动组件的父控制器」—— 用于内容区
  /// 本身还嵌在更大的滚动体里的情形（整页 `Scroll` 里套列表）。Flutter 侧的
  /// `ScrollPosition` 相互独立、没有等价的父子层级，所以这里**只登记、不参与
  /// 计算**：留字段是为了让调用方能照官方签名写，而不是悄悄吞掉一个官方参数。
  ///
  /// 绑定后本控制器会记录**每个页签的滚动位置**，供栏做「跟手」判断 ——
  /// 官方的跟手语义是「内容往上滚、栏跟着收」，那是**读位置**的事，不是去
  /// 接管滚动。所以这里只挂一个只读监听，**绝不 `hold()` 或改写 position** ——
  /// 那会让内容区在滚动时卡住不动。
  void bindScroller(
    int index,
    ScrollController scroller, {
    ScrollController? parentScroller,
  }) {
    unbindScroller(scroller);
    _scrollers[index] = _BoundsScroller.attach(
      controller: scroller,
      parent: parentScroller,
    );
  }

  /// 解除绑定（官方 `unbindScroller`）。
  void unbindScroller(ScrollController scroller) {
    for (final MapEntry<int, _BoundsScroller> e
        in _scrollers.entries.toList()) {
      if (e.value.controller == scroller) {
        e.value.detach();
        _scrollers.remove(e.key);
      }
    }
  }

  /// 当前已绑定的页签索引。
  Iterable<int> get boundIndexes => _scrollers.keys;

  /// 某个页签绑的滚动控制器。
  ScrollController? scrollerFor(int index) => _scrollers[index]?.controller;

  /// 某个页签的滚动位置（未绑定时为 `null`）。
  double? offsetFor(int index) => _scrollers[index]?.offset;

  @override
  void dispose() {
    for (final _BoundsScroller b in _scrollers.values) {
      b.detach();
    }
    _scrollers.clear();
    super.dispose();
  }
}

/// 滚动控制器的**只读**观测器：记位置与父控制器，不接管滚动。
class _BoundsScroller {
  _BoundsScroller._(this.controller, this.parent);

  factory _BoundsScroller.attach({
    required ScrollController controller,
    ScrollController? parent,
  }) {
    final _BoundsScroller b = _BoundsScroller._(controller, parent);
    controller.addListener(b._onScroll);
    b._offset = controller.hasClients ? controller.offset : 0;
    return b;
  }

  final ScrollController controller;

  /// 官方 `parentScroller`，仅登记。
  final ScrollController? parent;

  double _offset = 0;

  double get offset => controller.hasClients ? controller.offset : _offset;

  void _onScroll() {
    if (controller.hasClients) {
      _offset = controller.offset;
    }
  }

  void detach() => controller.removeListener(_onScroll);
}

/// 迷你栏与页签栏的布局模式 —— 对应官方 `HdsBarLayoutMode`（6.1.1(24) 起）。
enum OhosBarLayoutMode {
  /// 水平左右布局（官方 `HORIZONTAL = 0`），也是**未设置时的默认值**。
  horizontal,

  /// 垂直上下布局（官方 `VERTICAL = 1`）。
  vertical,
}

/// 两者同一时刻只有一方展开时，谁负责居中 —— 官方按宽度分了两套规则。
///
/// 这不是「对齐方式」的选项，而是**规格本身在 440vp 处换了口径**：
///
/// - <440vp：「页签栏和迷你栏将**整体**底部居中显示」—— 折叠的那个跟着走，
///   两者作为一个整体居中。
/// - 440–600vp：「**展开的**页签栏或迷你栏将底部居中显示」—— 折叠的那个
///   留在边上，只有展开者居中。
///
/// 写成单一「都居中」会在这两档之间出现 20vp 级别的偏移，而两档宽度只差
/// 几十 vp，肉眼很难判断是「规格如此」还是「算错了」。
enum OhosMiniBarAlign {
  /// 两者作为一个整体居中（<440vp，或两者同时展开）。
  group,

  /// 只有展开的那一个居中（440–600vp）。
  expandedOnly,
}

/// 迷你栏的几何与观感参数。
@immutable
class OhosMiniBarStyle {
  const OhosMiniBarStyle({
    this.collapsedWidth = 56,
    this.radius,
    this.background = true,
    this.clip = true,
  });

  /// 折叠态宽度。**自拟**：官方只给了展开态的分档宽度（`miniBarWidth`），
  /// 折叠态宽度全文未给。取 56 是为了和栏高一致 —— 配上 `radius = 高度/2`
  /// 正好是个正圆，这与官方示例里迷你栏折叠后呈圆形观感一致。
  final double collapsedWidth;

  /// 圆角。为空时取「展开态高度的一半」做成胶囊。
  final double? radius;

  /// 是否画背景。官方 `enableMiniBarBackground` 默认 `true`：
  /// true 跟随页签栏背景，false 则无色透明。
  final bool background;

  /// 是否裁剪内容。官方 `enableMiniBarClip` 默认 `true`。
  final bool clip;

  OhosMiniBarStyle copyWith({
    double? collapsedWidth,
    double? radius,
    bool? background,
    bool? clip,
  }) {
    return OhosMiniBarStyle(
      collapsedWidth: collapsedWidth ?? this.collapsedWidth,
      radius: radius ?? this.radius,
      background: background ?? this.background,
      clip: clip ?? this.clip,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OhosMiniBarStyle &&
      other.collapsedWidth == collapsedWidth &&
      other.radius == radius &&
      other.background == background &&
      other.clip == clip;

  @override
  int get hashCode => Object.hash(collapsedWidth, radius, background, clip);
}

/// 迷你栏 —— 对应官方 `HdsTabs` 的 `barFloatingStyle.miniBar`。
///
/// 它与页签栏是**两个独立的栏**，不是页签栏的一个装饰：官方把它单列成
/// `HdsTabsMiniBar`，有自己的宽度分档（`miniBarWidth`）、自己的折叠展开状态
/// （`miniBarStyle`）与自己的动效回调。所以这里也落成独立组件。
///
/// 尺寸由 [style]（折叠态）与 [widthRange]（展开态）共同决定，展开态的默认
/// 算法**复用**页签栏那一套（[OhosTabsWidthDefaults.compute]）—— 官方原文
/// 是「页签栏或迷你栏的分档宽度」，同一套断点、同一个上限 328vp。
class OhosMiniBar extends StatelessWidget {
  const OhosMiniBar({
    super.key,
    required this.builder,
    this.controller,
    this.barStyle = OhosBarStyle.collapse,
    this.style = const OhosMiniBarStyle(),
    this.widthRange,
    this.height = 56,
    this.tabCountForWidth,
    this.motionDuration = OhosGeometry.durationShort,
  });

  /// 自定义内容区（官方 `miniBarBuilder`）。
  final WidgetBuilder builder;

  /// 控制器。给了就跟着它走（含折叠动效），此时忽略 [barStyle]。
  final OhosTabsController? controller;

  /// 当前折叠 / 展开状态（官方 `miniBarStyle`；[controller] 为空时生效）。
  final OhosBarStyle barStyle;

  /// 几何与观感参数。
  final OhosMiniBarStyle style;

  /// 展开态的分档宽度（官方 `miniBarWidth`）。
  final OhosTabsBarWidthRange? widthRange;

  /// 栏高。与页签栏对齐，官方未单独给出迷你栏高度。
  final double height;

  /// 参与展开态宽度计算的页签个数；为空时按 1 个算。
  final int? tabCountForWidth;

  /// 折叠 / 展开的过渡时长。**自拟**：官方未给数值。
  ///
  /// 会被 `policy.scaleMotion` 再缩一次 —— 墨水屏上是零（见 [build]）。
  final Duration motionDuration;

  /// 首次创建时的折叠 / 展开状态。
  ///
  /// 官方两条原文合起来才完整：
  /// ①「首次创建迷你栏时，默认是折叠样式」；
  /// ②「`miniBarStyle` 仅 HdsTabs 宽度小于 600vp 生效设置」+「如果 HdsTabs
  ///    宽度大于 600vp 则为展开样式」。
  ///
  /// 即 **>600vp 时调用方传什么都不作数，强制展开**。写成
  /// `requested ?? (width > 600 ? expand : collapse)` 是错的 —— 那会让显式
  /// 传入的 `collapse` 在大屏上生效，与官方第 ② 条相反。
  static OhosBarStyle initialStyle({
    required double containerWidth,
    OhosBarStyle? requested,
  }) {
    if (containerWidth > OhosTabsWidthDefaults.breakpointMedium) {
      return OhosBarStyle.expand;
    }
    return requested ?? OhosBarStyle.collapse;
  }

  /// 只有一方展开时，谁居中（见 [OhosMiniBarAlign] 的说明）。
  static OhosMiniBarAlign alignFor({
    required double containerWidth,
    required OhosBarStyle miniStyle,
    required OhosBarStyle tabStyle,
  }) {
    final bool miniExpanded = miniStyle == OhosBarStyle.expand;
    final bool tabExpanded = tabStyle == OhosBarStyle.expand;
    // 两方状态相同（同折叠 / 同展开）→ 整体居中。官方在 >600vp 同时展开的
    // 情形明写「整体底部居中」；同折叠时文献未提，按整体居中更自然。
    if (miniExpanded == tabExpanded) {
      return OhosMiniBarAlign.group;
    }
    // 一展一折：<440vp 整体居中，440–600vp 只有展开者居中。
    if (containerWidth < OhosTabsWidthDefaults.breakpointSmall) {
      return OhosMiniBarAlign.group;
    }
    return OhosMiniBarAlign.expandedOnly;
  }

  /// 展开态宽度：先按分档算，再夹到可用宽度。
  ///
  /// 与页签栏同一条坑：328vp 是**绝对上限**，不是「一定等于 328」。
  static double expandedWidthFor({
    required double containerWidth,
    required double containerHeight,
    OhosTabsBarWidthRange? range,
    int? tabCount,
  }) {
    final OhosTabsWidthTier tier = OhosTabsWidthDefaults.tierOf(
      containerWidth: containerWidth,
      containerHeight: containerHeight,
    );
    double width;
    final double? override = range == null
        ? null
        : switch (tier) {
            OhosTabsWidthTier.small => range.smallWidth,
            OhosTabsWidthTier.medium => range.mediumWidth,
            OhosTabsWidthTier.large => range.largeWidth,
          };
    if (override != null) {
      width = override;
    } else {
      width = OhosTabsWidthDefaults.compute(
        tabCount: tabCount ?? 1,
        containerWidth: containerWidth,
        containerHeight: containerHeight,
      );
    }
    return width.clamp(0.0, containerWidth);
  }

  @override
  Widget build(BuildContext context) {
    final OhosTabsController? c = controller;
    if (c != null) {
      return AnimatedBuilder(
        animation: c,
        builder: (BuildContext context, Widget? _) =>
            _sized(context, c.miniBarStyle),
      );
    }
    return _sized(context, barStyle);
  }

  Widget _sized(BuildContext context, OhosBarStyle effectiveStyle) {
    final OhosThemeData theme = OhosTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double containerWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final double containerHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final bool expanded = effectiveStyle == OhosBarStyle.expand;
        final double width = expanded
            ? expandedWidthFor(
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                range: widthRange,
                tabCount: tabCountForWidth,
              )
            : style.collapsedWidth;
        final double radius = style.radius ?? height / 2;
        final Widget shell = _shell(context, theme, radius, expanded);
        // 折叠 / 展开是一次**离散跳变**，动效只是它的附庸 —— 所以这里是
        // 对宽度的隐式过渡，不是「动画驱动状态」。
        //
        // 时长走 `policy.scaleMotion` 而不是写死 200ms：墨水屏上前者返回
        // `Duration.zero`，栏直接换尺寸。灰阶屏上的宽度过渡会拖出一条
        // 中间灰带，真机上看起来像「栏没画完」，只能立刻定格。
        final Duration duration = theme.policy.scaleMotion(motionDuration);
        if (duration == Duration.zero) {
          return SizedBox(width: width, height: height, child: shell);
        }
        return AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          child: shell,
        );
      },
    );
  }

  Widget _shell(
    BuildContext context,
    OhosThemeData theme,
    double radius,
    bool expanded,
  ) {
    Widget content = builder(context);
    if (style.clip) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    } else if (expanded) {
      content = OverflowBox(
        alignment: Alignment.center,
        minWidth: 0,
        maxWidth: double.infinity,
        child: content,
      );
    }

    // 背景为 false 时「无色透明」是字面意思：不画底、也不画描边。
    if (!style.background) {
      return content;
    }

    final BorderRadius shape = BorderRadius.circular(radius);
    if (!theme.policy.allowsBlur) {
      // 与悬浮页签栏同一条墨屏退化：不建模糊层（真机表现为拖尾或留灰块
      // 且慢），改实底 + 整数像素描边，形体才立得住。
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.policy.quantize(theme.popupColor),
          borderRadius: shape,
          border: Border.all(
            color: theme.policy.line(theme.dividerColor, 1),
            width: ohosStrokeWidth(context, theme.outlineWidth),
          ),
        ),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.policy.quantize(theme.popupColor),
        borderRadius: shape,
      ),
      child: content,
    );
  }
}

/// 迷你栏 + 页签栏的底部组合 —— 承担官方那三条「居中」规则。
///
/// 官方把这条规则写在 `HdsTabsMiniBar` 的说明里，但它约束的是**两个栏的
/// 相对位置**，所以不能由 [OhosMiniBar] 自己决定，需要一个外部容器。
class OhosMiniBarScaffold extends StatelessWidget {
  const OhosMiniBarScaffold({
    super.key,
    required this.miniBar,
    required this.tabBar,
    this.controller,
    this.miniStyle,
    this.tabStyle,
    this.layoutMode = OhosBarLayoutMode.horizontal,
    this.gap = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// 迷你栏。
  final Widget miniBar;

  /// 页签栏。
  final Widget tabBar;

  /// 控制器。给了就跟着它走（含动效），此时忽略 [miniStyle] / [tabStyle]。
  ///
  /// 两个入口都留的原因是**测试与静态展示**要能不给控制器就把状态钉死 ——
  /// 拿控制器驱动的话，每个布局用例都得先 pump 到动画结束，测的就不再是
  /// 布局而是动画了。
  final OhosTabsController? controller;

  /// 迷你栏折叠状态（[controller] 为空时生效）。
  final OhosBarStyle? miniStyle;

  /// 页签栏折叠状态（[controller] 为空时生效）。
  final OhosBarStyle? tabStyle;

  /// 布局模式（官方 `barLayoutMode`，默认左右）。
  final OhosBarLayoutMode layoutMode;

  /// 两个栏之间的间距。**自拟**：官方未给。
  final double gap;

  /// 容器内边距。
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final OhosTabsController? c = controller;
    if (c != null) {
      // 控制器驱动：状态由它给，这一层只负责摆位置。
      return AnimatedBuilder(
        animation: c,
        builder: (BuildContext context, Widget? _) => _layout(
          context,
          miniStyle: c.miniBarStyle,
          tabStyle: c.tabBarStyle,
        ),
      );
    }
    return _layout(
      context,
      miniStyle: miniStyle ?? OhosBarStyle.collapse,
      tabStyle: tabStyle ?? OhosBarStyle.expand,
    );
  }

  Widget _layout(
    BuildContext context, {
    required OhosBarStyle miniStyle,
    required OhosBarStyle tabStyle,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double containerWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final OhosMiniBarAlign align = OhosMiniBar.alignFor(
          containerWidth: containerWidth,
          miniStyle: miniStyle,
          tabStyle: tabStyle,
        );
        final bool miniExpanded = miniStyle == OhosBarStyle.expand;

        if (layoutMode == OhosBarLayoutMode.vertical) {
          // 垂直上下：官方只描述了左右布局的居中规则，这里按「整体居中」
          // 处理 —— 上下布局没有「左右边」的概念，expandedOnly 无从表达。
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  miniBar,
                  SizedBox(height: gap),
                  tabBar,
                ],
              ),
            ),
          );
        }

        if (align == OhosMiniBarAlign.group) {
          // 两个栏都用 `Flexible` 兜住：它们的宽度各自独立算出，**合计可能
          // 超过容器**（320vp 屏上迷你栏 200 + 间距 8 + 页签栏 220 = 428）。
          // `Row` 不会自己折行，只会把右边那截挤出去 —— 静态分析看不见，
          // 真机上就是「页签栏少了一半」。
          return Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: padding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(child: miniBar),
                  SizedBox(width: gap),
                  Flexible(child: tabBar),
                ],
              ),
            ),
          );
        }
        // expandedOnly：展开者居中、折叠者贴边。
        //
        // **不能用 Row + Spacer**：折叠者会占掉流式布局的一段空间，展开者
        // 的中心就被推偏了（520 宽、折叠 56 展开 200 时偏 28vp）。「居中」
        // 在这里是**相对容器**的，所以两者必须在同一个坐标系里各自定位。
        final Widget collapsing = miniExpanded ? tabBar : miniBar;
        final Widget expanding = miniExpanded ? miniBar : tabBar;
        return Padding(
          padding: padding,
          child: SizedBox(
            width: containerWidth - padding.horizontal,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Align(alignment: Alignment.centerLeft, child: collapsing),
                expanding,
              ],
            ),
          ),
        );
      },
    );
  }
}
