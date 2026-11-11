import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_light_material.dart';
import 'ohos_press_feedback.dart';

/// 标题栏显示模式 —— 对应官方 `HdsNavigationTitleMode`。
///
/// 官方四个值 `FREE` / `FULL` / `MINI` / `MODAL` 里，[auto]（对应 `FREE`）
/// 是「随内容滚动在 FULL ↔ MINI 之间连续变化」，本组件没做滚动联动，因此
/// 不收进来 —— **不提供半吊子的枚举值**，调用方需要那种效果时自己在外层
/// 驱动 [OhosNavTitleMode] 即可。
enum OhosNavTitleMode {
  /// 小标题（官方 `MINI`，值 2）：标题栏固定 **56vp**，标题居中，返回键有效。
  mini,

  /// 大标题（官方 `FULL`，值 1）：仅主标题时 **112vp**，带副标题时
  /// **138vp**，标题在底部左对齐，副标题在其下。
  full,

  /// 半模态（官方 `MODAL`，值 3，起始版本 6.0.0(20)）。
  ///
  /// 官方原文给的是「背板」与「标题栏」两个高度，两者的差就是标题栏的
  /// **上 padding 8vp**：
  ///
  /// | 内容 | 背板高 | 标题栏高 |
  /// |---|---|---|
  /// | 只有主标题 | 64vp | 56vp |
  /// | 主标题 + 副标题 | 80vp | 72vp |
  ///
  /// 三种形态里只有它在标题栏**左侧**放图标（官方 `subIcon`，配图是一个
  /// 40vp 的浅灰圆形背板 + 24vp 图标）、右侧菜单默认渲染成**关闭按钮**
  /// （官方：`IconStyleMode.SMALL` 且不设图标资源时默认显示关闭按钮）。
  modal,
}

/// 双栏模式 —— 对应官方 `NavigationMode`。
enum OhosNavMode {
  /// 自适应（官方 `Auto`，默认值）：按组件宽度在单栏与双栏之间自动切换。
  ///
  /// **只有给了 [OhosNavigationScaffold.splitPlaceholder] 才会真的分栏。**
  /// 没有右侧占位内容时，官方让首页内容铺满整个组件（见
  /// [OhosNavigationScaffold.resolvesToSplit]），所以此时保持单栏 —— 避免
  /// 既有调用方在宽屏上被默认值挤进 240vp 导航栏列。
  auto,

  /// 强制单栏（官方 `Stack`）：导航栏的内容区占满整个宽度。
  stack,

  /// 强制双栏（官方 `Split`）：左导航栏 + 右内容区。
  split,
}

/// 导航栏在双栏里的位置 —— 对应官方 `NavBarPosition`。
enum OhosNavBarPosition {
  /// 导航栏在起始端（`Start`，默认值；中文环境即左侧）。
  start,

  /// 导航栏在结束端（`End`）。
  end,
}

/// 底部工具栏的一项 —— 对应官方 `ToolbarItem`。
class OhosNavToolbarItem {
  const OhosNavToolbarItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  /// 工具栏图标。
  final Widget icon;

  /// 图标下方文字。
  final String label;

  /// 点击回调。
  final VoidCallback? onTap;

  /// 是否可点。
  final bool enabled;
}

/// 组件导航的根视图容器 —— 对应官方 `HdsNavigation`。
///
/// 官方 `HdsNavigation` 是路由导航的根容器，内部默认包含**标题栏、内容区、
/// 工具栏**，并默认支持标题栏随内容滚动的动态模糊。它的路由栈（`NavPathStack`）
/// 在 Flutter 里由框架自身的 [Navigator] / 路由体系承担，本组件不重复实现一套
/// 路由，而是提供 `HdsNavigation` 的**视觉外壳与布局骨架**。
///
/// ## 已实现的能力（逐项对应官方属性）
///
/// * [titleMode]：三种固定形态 —— 小标题 56vp / 大标题 112·138vp /
///   半模态 64·80vp 背板（见 [OhosNavTitleMode]）。
/// * [hideTitleBar] / [hideToolBar]：显隐标题栏与工具栏，[animated] 控制
///   显隐过程是否走过渡。
/// * [hideBackButton]：隐藏返回键，**只在 [OhosNavTitleMode.mini] 下生效**
///   （官方原文：「返回键仅针对 titleMode 为 HdsNavigationTitleMode.MINI
///   时才生效」）。
/// * [toolbarItems]：底部工具栏均分，官方**上限 5 项**。
/// * [mode] / [navBarWidth] / [navBarPosition] / [navBarMinWidth] /
///   [navBarMaxWidth] / [minContentWidth] / [splitPlaceholder] /
///   [showDivider]：双栏布局。
/// * [blurredBackground]：标题栏的动态模糊背板。
///
/// ## 刻意没有实现的
///
/// 官方的 `recoverable`（页面栈恢复）、`systemBarStyle`（系统状态栏样式）、
/// `customNavContentTransition`（自定义转场）、`withTheme`、`dynamicHideTitleBar`
/// + `bindToScrollable`（标题栏跟随滚动动态显隐）都依赖 ArkUI 的窗口 / 路由
/// 栈能力，Flutter 侧没有等价的单一接口。这些**不做占位参数** —— 放一个永远
/// 不生效的 `recoverable: bool` 比不放更糟。
class OhosNavigationScaffold extends StatelessWidget {
  const OhosNavigationScaffold({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.subtitleTrailing,
    this.leading,
    this.actions,
    this.onClose,
    this.toolbarItems,
    this.titleMode = OhosNavTitleMode.mini,
    this.automaticallyImplyLeading = true,
    this.hideTitleBar = false,
    this.hideToolBar = false,
    this.hideBackButton = false,
    this.animated = false,
    this.blurredBackground = false,
    this.backgroundColor,
    this.mode = OhosNavMode.auto,
    this.navBarWidth = defaultNavBarWidth,
    this.navBarPosition = OhosNavBarPosition.start,
    this.navBarMinWidth = defaultNavBarWidth,
    this.navBarMaxWidth,
    this.minContentWidth = defaultMinContentWidth,
    this.splitPlaceholder,
    this.showDivider = true,
  }) : assert(
         toolbarItems == null || toolbarItems.length <= maxToolbarItems,
         '官方 toolbarConfiguration 最多显示 $maxToolbarItems 个图标，'
         '多余的会被收进自动生成的「更多」—— 本组件不做那个浮层，'
         '按官方上限拦住比悄悄丢掉更清楚。',
       );

  /// 内容区。
  ///
  /// 单栏（含 [OhosNavMode.auto] 未给 [splitPlaceholder] 的情形）下铺满标题栏
  /// 与工具栏之间的整个宽度；双栏下它是**左侧导航栏列**的内容，右侧由
  /// [splitPlaceholder] 承担。
  final Widget child;

  /// 主标题（官方 `mainTitle`）。
  final String? title;

  /// 副标题（官方 `subTitle`）。
  ///
  /// 大标题模式下画在主标题下方；**半模态模式下与主标题同一行**（配图里
  /// `SubTitle` 就在 `MainTitle` 右侧稍低一点的位置，两者共用一行的高度）。
  final String? subtitle;

  /// 副标题尾部的自定义区（官方 `subTitleBuilder`，6.0.0(20)）。
  ///
  /// 官方明确「该配置只在标题栏模式为 `MODAL` 时生效」—— 其它模式下传了
  /// 也不渲染，与官方一致。
  final Widget? subtitleTrailing;

  /// 标题栏左侧自定义控件。
  ///
  /// 默认（为空）时：半模态渲染官方 `subIcon` 的浅灰圆，其余模式在可返回时
  /// 渲染返回键。注意半模态的左侧是**子图标**而不是返回键，这一点两种形态
  /// 的默认内容不同，不是同一个按钮换了个位置。
  final Widget? leading;

  /// 标题栏右侧菜单区。半模态下默认渲染关闭按钮（见 [OhosNavTitleMode.modal]）。
  final List<Widget>? actions;

  /// 半模态关闭按钮的点击回调（官方默认关闭按钮的 `action`）。
  ///
  /// 只在 [OhosNavTitleMode.modal] 且 [actions] 为空时生效 —— [actions] 一旦
  /// 给了，右侧就是调用方自己的菜单，这里的回调没有按钮可以挂。
  final VoidCallback? onClose;

  /// 底部工具栏项；为空或 null、或 [hideToolBar] 为 true 时不显示。
  final List<OhosNavToolbarItem>? toolbarItems;

  /// 标题栏模式。
  final OhosNavTitleMode titleMode;

  /// 是否在能返回时自动显示返回键。
  final bool automaticallyImplyLeading;

  /// 是否隐藏标题栏（官方 `hideTitleBar`，默认 false）。
  final bool hideTitleBar;

  /// 是否隐藏工具栏（官方 `hideToolBar`，默认 false）。
  final bool hideToolBar;

  /// 是否隐藏标题栏里的返回键（官方 `hideBackButton`，默认 false）。
  ///
  /// **只在 [OhosNavTitleMode.mini] 下生效**，这是官方写明的限制，不是本组件
  /// 的取舍。大标题与半模态下这个参数会被忽略。
  final bool hideBackButton;

  /// 标题栏 / 工具栏显隐时是否走过渡（官方 `animated`，默认 false）。
  ///
  /// 官方的 `hideTitleBar` 与 `hideToolBar` 各带一个 `animated`，含义相同，
  /// 本组件合并成一个参数 —— 两处用同一个时长与曲线，分成两个反而容易配错。
  final bool animated;

  /// 标题栏是否使用动态模糊背景板。
  final bool blurredBackground;

  /// 标题栏 / 工具栏背景色，默认卡片色。
  final Color? backgroundColor;

  /// 双栏模式。
  final OhosNavMode mode;

  /// 导航栏宽度（官方 `navBarWidth`，默认 240vp）。
  ///
  /// 官方原文「仅在 HdsNavigation 组件分栏时生效」，本组件同样只在双栏下读它。
  final double navBarWidth;

  /// 导航栏在双栏里的位置（官方 `navBarPosition`，默认 `Start`）。
  final OhosNavBarPosition navBarPosition;

  /// 导航栏最小宽度（官方 `navBarWidthRange.minWidth`，默认 240vp）。
  final double navBarMinWidth;

  /// 导航栏最大宽度（官方 `navBarWidthRange.maxWidth`）。
  ///
  /// 为空时按官方默认算法：**组件宽度的 40%，且不大于 432vp**。
  final double? navBarMaxWidth;

  /// 内容区最小宽度（官方 `minContentWidth`，默认 360vp）。
  final double minContentWidth;

  /// 双栏时右侧内容区的占位内容（官方 `splitPlaceholder`）。
  ///
  /// 为空时右侧是一块空白（官方示例的「分栏模式占位页」也是调用方自己给的，
  /// 组件本身不画任何装饰）。
  ///
  /// **它同时是 [OhosNavMode.auto] 的开关**：为空时 `auto` 不分栏（[child]
  /// 铺满）；给了它，`auto` 才在宽度 ≥ `navBarMinWidth + minContentWidth` 时
  /// 切双栏。强制 [OhosNavMode.split] 不受此限制 —— 那是调用方明确要双栏。
  final Widget? splitPlaceholder;

  /// 双栏时两列之间是否画分割线（官方 `divider`，传 null 即隐藏）。
  final bool showDivider;

  /// 官方小标题栏高度（MINI）。
  static const double miniHeight = 56;

  /// 官方大标题栏高度（FULL，仅主标题）。
  static const double fullHeight = 112;

  /// 官方大标题栏高度（FULL，主 + 副标题）。
  static const double fullWithSubtitleHeight = 138;

  /// 官方半模态背板高度（MODAL，仅主标题）。
  static const double modalHeight = 64;

  /// 官方半模态背板高度（MODAL，主 + 副标题）。
  static const double modalWithSubtitleHeight = 80;

  /// 半模态标题栏的上 padding（官方给的 8vp）。
  ///
  /// 它不是一个独立参数而是一个**推导值**：`背板 64 − 标题栏 56 = 8`，
  /// 主副标题两种形态都是 8。写成常量是为了让「背板 = 标题栏 + 本值」这条
  /// 关系在代码里显式成立，改一处就自洽。
  static const double modalTopPadding = 8;

  /// 半模态副标题行的固定高度。
  ///
  /// 副标题 14vp、行高 1.5 ⇒ 21vp，向上取整到 22 留 1vp 余量给字体的
  /// 上下突起（`harmony_icons` 之类自定义字形也在这个框里）。
  ///
  /// **必须钉死。** 背板高度 80 / 72 是官方硬值，副标题区一旦允许被内容撑高，
  /// [subtitleTrailing] 里的任意 widget 就能把整条标题栏顶穿。见 `_modalTitleBar`
  /// 里那段说明。
  static const double modalSubtitleLineHeight = 22;

  /// 工具栏高度。
  static const double toolbarHeight = 56;

  /// 工具栏最多项数（官方：最多 5 个图标）。
  static const int maxToolbarItems = 5;

  /// 导航栏默认宽度（官方 `navBarWidth` 默认值 240vp）。
  static const double defaultNavBarWidth = 240;

  /// 导航栏默认最大宽度上限（官方：组件宽度的 40% 且不大于 432vp）。
  static const double navBarMaxWidthCap = 432;

  /// 内容区默认最小宽度（官方 `minContentWidth` 默认值 360vp）。
  static const double defaultMinContentWidth = 360;

  /// 官方 `Auto` 模式的判据：组件宽度 ≥ `minNavBarWidth + minContentWidth`
  /// 时走双栏。
  ///
  /// 用默认值时正好是 `240 + 360 = 600vp` —— ArkUI 文档里那句「Navigation
  /// 宽度 >= 600vp 时采用 Split 模式」就是这么来的，**不是另一个魔数**。
  /// 所以这里按两个可用参数现算，调用方改窄了 `minContentWidth`，断点跟着动。
  bool resolvesToSplit(double width) {
    switch (mode) {
      case OhosNavMode.stack:
        return false;
      case OhosNavMode.split:
        return true;
      case OhosNavMode.auto:
        // **没有 `splitPlaceholder` 就不分栏。** 官方：「如果内容区没有
        // HdsNavDestination，则遵从 HdsNavigation 首页的设置」—— 右侧没有
        // 被 push 出来的 destination 时，首页内容（[child]）应当铺满整个组件，
        // 而不是被挤进 240vp 的导航栏列、右边留一大片空白。所以 `auto` 只在
        // 调用方真的给了右侧占位内容时才按宽度切双栏；否则保持单栏。
        //
        // 这一条同时是向后兼容的护栏：`auto` 是默认值，若只看宽度，任何既有
        // 的 `OhosNavigationScaffold(child: ...)` 在平板 / 横屏（≥600vp）上
        // 都会突然只剩 240vp 宽 —— 那是默认参数变化带来的功能回归。
        return splitPlaceholder != null &&
            width >= navBarMinWidth + minContentWidth;
    }
  }

  /// 双栏时导航栏的实际宽度。
  ///
  /// 官方给的是「显示范围缩小顺序」：先缩内容区到 [minContentWidth]，再缩
  /// 导航栏到 `navBarWidthRange` 的下限，都不够就裁切。前两步的净效果就是
  /// 「导航栏宽度取 `navBarWidth`，但内容区至少留 [minContentWidth]」——
  /// 第三步的裁切在 Flutter 里表现为溢出报错，所以最后再夹一次 `0`，
  /// 宁可让窄屏下导航栏比下限还窄（等价于「裁掉的是导航栏的右边缘」）。
  double resolvedNavBarWidth(double available) {
    final double upper = _resolvedNavBarMaxWidth(available);
    final double lower = math.min(navBarMinWidth, upper);
    final double preferred = navBarWidth < lower
        ? lower
        : (navBarWidth > upper ? upper : navBarWidth);
    // 再让内容区至少拿到 `minContentWidth`。
    final double leftover = available - minContentWidth;
    if (preferred <= leftover) {
      return preferred;
    }
    return leftover > 0 ? leftover : 0;
  }

  double _resolvedNavBarMaxWidth(double available) {
    final double byRatio = available * 0.4;
    return navBarMaxWidth ?? math.min(byRatio, navBarMaxWidthCap);
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color background = backgroundColor ?? theme.cardColor;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        if (!resolvesToSplit(width)) {
          return _singleColumn(context, theme, background);
        }
        return _split(context, theme, background, width);
      },
    );
  }

  /// 单栏：标题栏 + 内容 + 工具栏纵向排列。
  Widget _singleColumn(
    BuildContext context,
    OhosThemeData theme,
    Color background,
  ) {
    return Column(
      children: <Widget>[
        _visibility(
          context,
          theme,
          visible: !hideTitleBar,
          child: _titleBar(context, theme, background),
        ),
        Expanded(child: child),
        // **没有工具栏内容时整段不建。** `_visibility` 的 `child` 是普通
        // 参数，即使 `visible` 为 false 也会被求值 —— 而 `_toolbar` 内部读
        // `toolbarItems!`，没有工具栏时直接抛空指针。所以用 `_hasToolbar`
        // 守住「有没有内容」；至于「显不显示」由下面的 `visible: !hideToolBar`
        // 决定，隐藏时仍保留节点，`animated` 才有可插值的高度。
        if (_hasToolbar)
          _visibility(
            context,
            theme,
            visible: !hideToolBar,
            child: _toolbar(context, theme, background),
          ),
      ],
    );
  }

  /// 双栏：导航栏（标题栏 + 内容 + 工具栏）与右侧内容区并排。
  ///
  /// 右侧是被 push 出来的 destination 的位置，本组件不实现路由栈，所以那里
  /// 放 [splitPlaceholder] 或空白。官方在 `Split` 下「如果内容区没有
  /// HdsNavDestination，则遵从 HdsNavigation 首页的设置」—— 也就是说右侧
  /// 没有标题栏，符合这里的排布。
  Widget _split(
    BuildContext context,
    OhosThemeData theme,
    Color background,
    double width,
  ) {
    final double barWidth = resolvedNavBarWidth(width);
    final Widget navBar = SizedBox(
      width: barWidth,
      child: _singleColumn(context, theme, background),
    );
    final Widget pane = Expanded(
      child: splitPlaceholder ?? const SizedBox.expand(),
    );
    final List<Widget> columns = navBarPosition == OhosNavBarPosition.start
        ? <Widget>[navBar, pane]
        : <Widget>[pane, navBar];
    if (!showDivider) {
      return Row(children: columns);
    }
    // 分割线宽度不能参与 `Row` 的分配：1px 的分隔线若写成第三个 flex 孩子，
    // 两列的比例会随它变（尤其是 `Expanded` 之外混进固定宽度时）。用
    // `DecoratedBox` 的 `Border` 画在导航栏自己身上，宽度就不占位。
    //
    // **必须 `foreground`。** 默认的 `background` 先画装饰再画 child，而导航栏
    // 的标题栏 / 工具栏都是不透明 `cardColor` 且撑满栏宽 —— 那条 1px 线在它们
    // 的高度范围内会被整个盖住，`showDivider` 默认 true 却几乎看不见。画在
    // 内容之上（foreground）才真的可见，仍不占 Row 宽度。
    final bool dividerOnRight = navBarPosition == OhosNavBarPosition.start;
    return Row(
      children: <Widget>[
        for (int i = 0; i < columns.length; i++)
          if (i == (dividerOnRight ? 1 : 0))
            // 内容区那一侧不画线，线只属于导航栏。
            columns[i]
          else
            DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border(
                  right: dividerOnRight
                      ? ohosBorderSide(
                          context,
                          theme.dividerColor,
                          width: theme.outlineWidth,
                        )
                      : BorderSide.none,
                  left: dividerOnRight
                      ? BorderSide.none
                      : ohosBorderSide(
                          context,
                          theme.dividerColor,
                          width: theme.outlineWidth,
                        ),
                ),
              ),
              child: columns[i],
            ),
      ],
    );
  }

  /// 是否有工具栏**内容**。注意这里**不含** `!hideToolBar` —— 隐藏与否交给
  /// `_visibility(visible: !hideToolBar)` 承担。早先把 `!hideToolBar` 并进
  /// 这个判据，`hideToolBar` 一为 true 连 `_visibility` 节点都不再生成，工具栏
  /// 直接从树里消失，`animated` 的过渡对工具栏完全不起作用（只有标题栏能动）。
  bool get _hasToolbar => toolbarItems != null && toolbarItems!.isNotEmpty;

  /// 按 [animated] 决定显隐是否走过渡。
  ///
  /// [AnimatedSize] 在不可见时用 `height: 0` 而不是直接换成一个空 `SizedBox`
  /// —— 后者会让 `AnimatedSize` 从「有尺寸」跳到「没有尺寸」，中间没有任何
  /// 可插值的高度。
  Widget _visibility(
    BuildContext context,
    OhosThemeData theme, {
    required bool visible,
    required Widget child,
  }) {
    if (!animated) {
      return visible ? child : const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: theme.policy.scaleMotion(OhosGeometry.durationShort),
      curve: OhosGeometry.easeOut,
      alignment: Alignment.topCenter,
      child: visible
          ? child
          : const SizedBox(width: double.infinity, height: 0),
    );
  }

  Widget _titleBar(
    BuildContext context,
    OhosThemeData theme,
    Color background,
  ) {
    final Widget content = switch (titleMode) {
      OhosNavTitleMode.mini => _miniTitleBar(context, theme),
      OhosNavTitleMode.full => _fullTitleBar(context, theme),
      OhosNavTitleMode.modal => _modalTitleBar(context, theme),
    };

    // 背景板：动态模糊材质 or 实色 + 底部 1px 分割线。
    Widget result;
    if (blurredBackground) {
      result = OhosLightMaterial(
        level: OhosLightMaterialLevel.ultraThin,
        showShadow: false,
        gradientFade: OhosLightFade.top,
        child: content,
      );
    } else {
      result = DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border(
            bottom: theme.usesOutlines
                ? ohosBorderSide(
                    context,
                    theme.dividerColor,
                    width: theme.outlineWidth,
                  )
                : BorderSide.none,
          ),
        ),
        child: content,
      );
    }
    // 小标题 / 大标题的内容避开状态栏，背景仍铺到最顶端。
    //
    // **半模态不在这里避让**：官方的 64 / 80 背板是**不含状态栏**的，它自己
    // 就长在状态栏下面（半模态通常挂在 `bindSheet` 里，根本没有状态栏）。给
    // 它再套一层 `SafeArea` 会凭空多出一整个状态栏高度，背板从 80 变成
    // 80 + 状态栏。半模态的 8vp 上 padding 是背板内部的事，与安全区无关。
    if (titleMode == OhosNavTitleMode.modal) {
      return result;
    }
    return SafeArea(bottom: false, child: result);
  }

  /// 返回键是否真的渲染。
  ///
  /// 官方限制：`hideBackButton` 只对 MINI 生效。大标题下返回键照常显示 ——
  /// 这不是漏判，是刻意对齐官方那一句。
  bool _backButtonVisible() {
    if (hideBackButton && titleMode == OhosNavTitleMode.mini) {
      return false;
    }
    return automaticallyImplyLeading;
  }

  /// 小标题栏：返回键（左）、居中标题、菜单（右）。
  Widget _miniTitleBar(BuildContext context, OhosThemeData theme) {
    return SizedBox(
      height: miniHeight,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 4,
            top: 8,
            bottom: 8,
            child: leading ?? _defaultLeading(context, theme),
          ),
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 56),
                child: Text(
                  title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (theme.typography.titleMedium ??
                              const TextStyle(fontSize: 17))
                          .copyWith(color: theme.textPrimaryColor),
                ),
              ),
            ),
          ),
          if (actions != null)
            Positioned(
              right: 8,
              top: 8,
              bottom: 8,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
            ),
        ],
      ),
    );
  }

  /// 大标题栏：顶部一行返回键 + 菜单，底部左对齐主标题（+ 副标题）。
  Widget _fullTitleBar(BuildContext context, OhosThemeData theme) {
    final double height = subtitle != null
        ? fullWithSubtitleHeight
        : fullHeight;
    return SizedBox(
      height: height,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: miniHeight,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 4,
                  top: 8,
                  bottom: 8,
                  child: leading ?? _defaultLeading(context, theme),
                ),
                if (actions != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    bottom: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (theme.typography.headlineMedium ??
                                const TextStyle(fontSize: 28))
                            .copyWith(
                              color: theme.textPrimaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (theme.typography.bodyMedium ??
                                  const TextStyle(fontSize: 14))
                              .copyWith(color: theme.textSecondaryColor),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 半模态标题栏：左侧子图标圆、中间主标题 + 副标题、右侧关闭按钮。
  ///
  /// 排布按官方配图逐项对齐：
  ///
  /// * 背板 64 / 80vp，其中顶部 [modalTopPadding]（8vp）留白，标题栏 56 / 72vp；
  /// * 左图标是 **40vp 浅灰圆**（`comp_background_gray`），图标 24vp，在标题栏
  ///   内垂直居中；
  /// * 主标题 20vp 加粗，副标题 14vp 次色，**同一个横向块内上下两行**（配图里
  ///   `MainTitle` 在上、`SubTitle` 在下一行稍偏左），副标题右侧接
  ///   [subtitleTrailing]；
  /// * 右侧关闭按钮 40vp 圆（官方：`IconStyleMode.SMALL` 且不设图标资源时
  ///   默认显示关闭按钮）。
  Widget _modalTitleBar(BuildContext context, OhosThemeData theme) {
    final double barHeight = subtitle != null
        ? modalWithSubtitleHeight - modalTopPadding
        : modalHeight - modalTopPadding;
    final Color iconPlate = theme.compBackgroundGrayColor ?? theme.dividerColor;
    return Padding(
      padding: const EdgeInsets.only(top: modalTopPadding),
      child: SizedBox(
        height: barHeight,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 16),
            leading ??
                _plateIcon(
                  context,
                  theme,
                  color: iconPlate,
                  child: Icon(
                    Icons.wifi_rounded,
                    size: 24,
                    color: theme.textPrimaryColor,
                  ),
                ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (theme.typography.titleLarge ??
                                const TextStyle(fontSize: 20))
                            .copyWith(
                              color: theme.textPrimaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  if (subtitle != null)
                    // **副标题区只能是单行，这是背板高度决定的，不是排版偏好。**
                    // 背板 80vp 是官方硬值（`背板 80 − 上 padding 8 = 标题栏
                    // 72`），里面要塞「主标题 28 + 副标题 21」。
                    //
                    // 早先这里只写了 `maxLines: 1`，那只管住了副标题**文字**，
                    // 管不住 [subtitleTrailing] —— 它是调用方传进来的任意
                    // widget，宽度一窄里面的 `Text` 就自己折行，整行高度从 21
                    // 涨到 47，`Column` 当场溢出 26px，渲染出黑黄条纹。现在用
                    // 定高 + `ClipRect` 兜住，并把「谁该让步」写清楚：见下面
                    // `LayoutBuilder` 的注释。
                    SizedBox(
                      height: modalSubtitleLineHeight,
                      child: ClipRect(
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints c) {
                            // **尾部优先，副标题文字让步。**
                            //
                            // 两个 `Flexible` 会平分剩余宽度 —— 实测尾部
                            // 只拿到一半，`click to share` 在窄屏上折成
                            // 三行。但尾部通常是「分享 / 查看全部」这类
                            // 短动作词，被压扁就读不懂了；副标题本来就
                            // 该省略号收尾。所以给尾部一个「自然宽、最多
                            // 六成」的上限，副标题吃剩下的。
                            final double trailingCap = c.maxWidth.isFinite
                                ? c.maxWidth * 0.6
                                : double.infinity;
                            return Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        (theme.typography.bodySmall ??
                                                const TextStyle(fontSize: 14))
                                            .copyWith(
                                              color: theme.textSecondaryColor,
                                            ),
                                  ),
                                ),
                                if (subtitleTrailing != null) ...<Widget>[
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: trailingCap,
                                    ),
                                    child: subtitleTrailing!,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children:
                    actions ??
                    <Widget>[
                      _plateIcon(
                        context,
                        theme,
                        color: iconPlate,
                        onTap: onClose,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.textPrimaryColor,
                        ),
                      ),
                    ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 半模态标题栏里的 40vp 圆形图标背板。
  ///
  /// 直径 40 是配图量出来的（左右两个圆在 525px 宽的截图里都是 41px，
  /// 按 1.0 DPR 折算即 40vp 左右），比标题栏 56vp 矮一档、留得出上下呼吸。
  /// [onTap] 为空时不注册手势 —— 左侧的网络图标在官方示例里也只是个状态
  /// 展示，给它挂一个空回调会让它变成可聚焦的假按钮。
  Widget _plateIcon(
    BuildContext context,
    OhosThemeData theme, {
    required Color color,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final Widget plate = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // 墨屏上灰阶背板会与白底糊在一起，描边由主题统一给。
        color: color,
        shape: BoxShape.circle,
        border: theme.usesOutlines
            ? Border.all(
                color: theme.dividerColor,
                width: ohosStrokeWidth(context, theme.outlineWidth),
              )
            : null,
      ),
      child: child,
    );
    if (onTap == null) {
      return plate;
    }
    return OhosPressFeedback(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: plate,
    );
  }

  /// 默认返回键：圆形按压、无 Material 水波纹。
  Widget _defaultLeading(BuildContext context, OhosThemeData theme) {
    if (!_backButtonVisible()) {
      return const SizedBox.shrink();
    }
    final bool canPop = Navigator.of(context).canPop();
    if (!canPop) {
      return const SizedBox.shrink();
    }
    return OhosPressFeedback(
      onTap: () => Navigator.maybePop(context),
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: theme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context, OhosThemeData theme, Color background) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: theme.usesOutlines
              ? ohosBorderSide(
                  context,
                  theme.dividerColor,
                  width: theme.outlineWidth,
                )
              : BorderSide.none,
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: toolbarHeight,
          child: Row(
            children: <Widget>[
              for (final OhosNavToolbarItem item in toolbarItems!)
                Expanded(child: _toolbarItem(theme, item)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarItem(OhosThemeData theme, OhosNavToolbarItem item) {
    final Color color = item.enabled
        ? theme.textPrimaryColor
        : theme.textTertiaryColor;
    return OhosPressFeedback(
      onTap: item.enabled ? item.onTap : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconTheme.merge(
            data: IconThemeData(color: color, size: 22),
            child: item.icon,
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (theme.typography.labelSmall ?? const TextStyle(fontSize: 11))
                      .copyWith(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
