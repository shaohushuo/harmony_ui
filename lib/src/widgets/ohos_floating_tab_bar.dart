import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_badge.dart';
import 'ohos_light_material.dart';
import 'ohos_tabs_width.dart';

/// 悬浮页签栏里的一项。
///
/// 与 [BottomNavigationBarItem] / `Tab` 的差别：官方 `BottomTabBarStyle` 允许
/// 「只有图标」「图标 + 文字」「只有文字」三种形态，且图标有选中 / 未选中两套
/// （`icon` / `text` 里也可以直接塞 `SymbolGlyphModifier` 做双态）。这里保留同样
/// 的三态，不做「必须有文字」的强制。
@immutable
class OhosFloatingTabItem {
  const OhosFloatingTabItem({
    this.icon,
    this.activeIcon,
    this.label,
    this.badge,
    this.enabled = true,
  });

  /// 未选中时的图标。
  final Widget? icon;

  /// 选中时的图标；为空则回落到 [icon]。
  ///
  /// 「切一下就掉图标」不是双态而是缺陷 —— 与 `OhosActionBarButton.altIcon`、
  /// `OhosChipItem.selectedIcon` 同一条规则。
  final Widget? activeIcon;

  /// 文字标签。三者全为空时这一项不渲染（官方也没有「纯空白页签」）。
  final String? label;

  /// 角标文字，如 `99+`。为空不画。
  final String? badge;

  /// 是否可点。禁用项仍占位，只是不响应、降一档明度。
  final bool enabled;

  OhosFloatingTabItem copyWith({
    Widget? icon,
    Widget? activeIcon,
    String? label,
    String? badge,
    bool? enabled,
  }) {
    return OhosFloatingTabItem(
      icon: icon ?? this.icon,
      activeIcon: activeIcon ?? this.activeIcon,
      label: label ?? this.label,
      badge: badge ?? this.badge,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OhosFloatingTabItem &&
      other.icon == icon &&
      other.activeIcon == activeIcon &&
      other.label == label &&
      other.badge == badge &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(icon, activeIcon, label, badge, enabled);
}

/// 悬浮页签栏的几何与观感参数。
///
/// **绝大多数数值是自拟的，而且这一点必须说清。** HDS 闭源套件
/// （`HdsTabs` / `barFloatingStyle`）在系统资源表 `pattern.json` /
/// `float_sys.json` / `float.json` 里搜 `hds` / `floating` **零命中**，参考文档
/// 只给规则不给数值 —— 与 `HdsActionBar` 完全同型。下面每个数都标了来源：
///
/// - 标「官方」的：文档里写明的默认值，可核对；
/// - 标「自拟」的：文档没给，按设计规范「悬浮于内容之上」的定性描述 + 本库
///   既有组件的比例自定，**不能当成官方默认值转述**。
@immutable
class OhosFloatingTabBarStyle {
  const OhosFloatingTabBarStyle({
    this.height = 56,
    this.radius = 28,
    this.sideMargin,
    this.bottomMargin = 0,
    this.maskHeight = 16,
    this.maskColor,
    this.barOpacity = 1,
    this.blurLevel = OhosLightMaterialLevel.thin,
    this.showMask = true,
  });

  /// 栏高。**官方**：`barHeight` 默认值 —— 悬浮样式下 56vp
  /// （平铺是 48vp，见 `hds-hdstabs.md` 的 `barHeight` 说明）。
  final double height;

  /// 圆角。**自拟**：取高度的一半做成胶囊。官方未给数值，只说「悬浮」。
  final double radius;

  /// 与容器左右边距。**官方**：`barSideMargin` 默认值按宽度分三档 ——
  /// <600vp 取 16vp、600–840vp 取 24vp、>840vp 取 32vp。
  ///
  /// **这里默认是 `null`，意思是「按宽度自动分档」**（见 [sideMarginFor]）。
  /// 不写成 `= 16`：那样就和「调用方显式要 16」无法区分了 —— 值相等不等于
  /// 意图相同，用 `sideMargin == 16` 去反推「他有没有改过」是个会在下一块屏
  /// 上出错的写法。
  final double? sideMargin;

  /// 与容器底部距离。**官方**：默认 0vp（`barBottomMargin`）。
  final double bottomMargin;

  /// 蒙层在栏体之外额外扩展的高度。**官方**：`gradientMask` 的高度等于
  /// 「页签栏默认高度 + 16vp」，即额外 16vp。
  final double maskHeight;

  /// 蒙层颜色。**官方**：`gradientMask.maskColor` 浅色 `#CCF1F3F5`、
  /// 深色 `#99000000`。为空时按主题明暗取。
  ///
  /// **注意别和 `barBackgroundStyle` 搞混**：那个是「渐变模糊」，浅色
  /// `#CCFFFFFF` / 深色 `#CC000000`、高度 = 栏高 + **32vp**。两者共用
  /// `HdsTabsBackgroundStyle` 类型但默认值不同 —— 按属性读，别按类型读。
  final Color? maskColor;

  /// 栏体不透明度。**官方**：`barOpacity` 默认 1。
  final double barOpacity;

  /// 模糊档位。官方 `blurStrategy` 默认 `ADAPTIVE`（依赖厂商性能分档，
  /// Flutter 读不到，见 `OhosBlurStrategy` 的说明）。这里默认 [thin] ——
  /// 官方文档在 `OhosLightMaterialLevel` 的对应说明里把 THIN 定位成
  /// 「推荐给浮在页面底部的组件」，正好是悬浮页签栏的场景。
  final OhosLightMaterialLevel blurLevel;

  /// 是否画蒙层。
  final bool showMask;

  /// 官方 `barSideMargin` 的三档默认值。
  ///
  /// 断点与 [OhosTabsWidthDefaults] 一致（600 / 840），但**注意 440 不参与** ——
  /// 边距只分三档、宽度分三档，两套断点不是同一个东西。
  static double sideMarginFor(double containerWidth) {
    if (containerWidth >= OhosTabsWidthDefaults.breakpointLarge) {
      return 32;
    }
    if (containerWidth >= OhosTabsWidthDefaults.breakpointMedium) {
      return 24;
    }
    return 16;
  }

  OhosFloatingTabBarStyle copyWith({
    double? height,
    double? radius,
    double? sideMargin,
    double? bottomMargin,
    double? maskHeight,
    Color? maskColor,
    double? barOpacity,
    OhosLightMaterialLevel? blurLevel,
    bool? showMask,
  }) {
    return OhosFloatingTabBarStyle(
      height: height ?? this.height,
      radius: radius ?? this.radius,
      sideMargin: sideMargin ?? this.sideMargin,
      bottomMargin: bottomMargin ?? this.bottomMargin,
      maskHeight: maskHeight ?? this.maskHeight,
      maskColor: maskColor ?? this.maskColor,
      barOpacity: barOpacity ?? this.barOpacity,
      blurLevel: blurLevel ?? this.blurLevel,
      showMask: showMask ?? this.showMask,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OhosFloatingTabBarStyle &&
      other.height == height &&
      other.radius == radius &&
      other.sideMargin == sideMargin &&
      other.bottomMargin == bottomMargin &&
      other.maskHeight == maskHeight &&
      other.maskColor == maskColor &&
      other.barOpacity == barOpacity &&
      other.blurLevel == blurLevel &&
      other.showMask == showMask;

  @override
  int get hashCode => Object.hash(
    height,
    radius,
    sideMargin,
    bottomMargin,
    maskHeight,
    maskColor,
    barOpacity,
    blurLevel,
    showMask,
  );
}

/// 悬浮页签栏 —— 对应官方 `HdsTabs` 的 `barFloatingStyle`。
///
/// **这不是 [OhosTabBar] 的一个变体，是另一个形态。** 官方把「三档宽度」
/// `HdsBarWidthRangeOptions`、蒙层 `gradientMask`、迷你栏 `miniBar` 全部挂在
/// `barFloatingStyle` 之下，而它有三个平铺栏一条都不满足的前置条件：
/// `barOverlap=true`（栏叠在内容之上）、`vertical=false`、`barPosition=End`。
/// 所以这些能力放进独立组件，而不是往 [OhosTabBar] 上堆参数。
///
/// 用法上它必须叠在内容之上：把页签内容与它放进 [Stack]，栏摆在底部。
class OhosFloatingTabBar extends StatelessWidget {
  const OhosFloatingTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.style = const OhosFloatingTabBarStyle(),
    this.widthRange,
    this.tabCount,
  });

  /// 页签项。
  final List<OhosFloatingTabItem> items;

  /// 当前选中项。
  final int selectedIndex;

  /// 选中回调。
  final ValueChanged<int> onSelected;

  /// 几何与观感参数。
  final OhosFloatingTabBarStyle style;

  /// 三档宽度的调用方覆盖值；为空时按 [OhosTabsWidthDefaults] 的默认算法。
  final OhosTabsBarWidthRange? widthRange;

  /// 参与宽度计算的页签个数；为空时用 `items.length`。
  ///
  /// 之所以留这个口子：官方算法里的「页签个数」指**页签栏里的页签数**，
  /// 迷你栏展开时它和 `items.length` 可能不一致。
  final int? tabCount;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double containerWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final double containerHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final double side =
            style.sideMargin ??
            OhosFloatingTabBarStyle.sideMarginFor(containerWidth);
        // 边距先吃掉可用宽度，栏宽再在其中取「算出来的值，但不超过可用宽」。
        //
        // 这里有个真实坑：三档宽度的上限 328vp 是**绝对值**，容器只有 340 宽
        // 时「16 + 328 + 16 = 360」直接溢出 20vp。官方原文的 328 是「最大宽度
        // 不超过 328」，不是「一定等于 328」，所以必须再夹一次可用宽度。
        final double available = (containerWidth - side * 2).clamp(
          0.0,
          double.infinity,
        );
        final double barWidth = _resolveBarWidth(
          containerWidth: containerWidth,
          containerHeight: containerHeight,
        ).clamp(0.0, available);
        return Padding(
          padding: EdgeInsets.only(bottom: style.bottomMargin),
          // **居中，不是靠左。** 官方在「迷你栏和页签栏处于左右布局场景时」
          // 的说明里反复写「整体底部居中显示」；边距约束的是栏与容器边界的
          // 最小间隙，不是栏的定位锚点。用 `Padding(left/right)` 强行定位会
          // 变成左对齐 —— 栏一窄就贴在左边，肉眼像是漏了一半。
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: barWidth,
              child: _bar(context, theme, containerWidth),
            ),
          ),
        );
      },
    );
  }

  /// 三档宽度解析。调用方给了就用，没给按默认算法（≥4 个直接取 328）。
  ///
  /// 档位判定用**容器的真实约束**，不是屏幕尺寸 —— 分栏场景下两者不等，
  /// 读 `MediaQuery` 会把窄栏判成大屏。
  double _resolveBarWidth({
    required double containerWidth,
    required double containerHeight,
  }) {
    final int count = tabCount ?? items.length;
    final OhosTabsBarWidthRange? range = widthRange;
    final OhosTabsWidthTier tier = OhosTabsWidthDefaults.tierOf(
      containerWidth: containerWidth,
      containerHeight: containerHeight,
    );
    if (range != null) {
      final double? override = switch (tier) {
        OhosTabsWidthTier.small => range.smallWidth,
        OhosTabsWidthTier.medium => range.mediumWidth,
        OhosTabsWidthTier.large => range.largeWidth,
      };
      if (override != null) {
        return override;
      }
    }
    return OhosTabsWidthDefaults.compute(
      tabCount: count,
      containerWidth: containerWidth,
      containerHeight: containerHeight,
    );
  }

  Widget _bar(
    BuildContext context,
    OhosThemeData theme,
    double containerWidth,
  ) {
    final Widget row = SizedBox(
      height: style.height,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: _item(
                context: context,
                theme: theme,
                item: items[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );

    // 墨屏：`allowsBlur` 为 false 时不能用 `BackdropFilter`（真机表现为拖尾
    // 或留灰块且慢），且 `tint` 会返回透明 —— 半透明的栏体在灰阶屏上直接
    // 消失。改为「实色底 + 1px 描边」，形体才立得住。
    if (!theme.policy.allowsBlur) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.policy.quantize(theme.popupColor),
          borderRadius: BorderRadius.circular(style.radius),
          border: Border.all(
            color: theme.policy.line(theme.dividerColor, 1),
            width: ohosStrokeWidth(context, theme.outlineWidth),
          ),
        ),
        // 栏体内裁一刀：`DecoratedBox` 的圆角只裁背景、不裁子级，选中项那块
        // 实底只要敢碰到边缘就会画到栏的圆弧外面去。裁在背景之内，描边不受
        // 影响（它画在盒子的边上，被裁的是 row）。
        child: ClipRRect(
          borderRadius: BorderRadius.circular(style.radius),
          child: row,
        ),
      );
    }

    final Widget material = OhosLightMaterial(
      level: style.blurLevel,
      borderRadius: BorderRadius.circular(style.radius),
      showShadow: theme.policy.allowsShadow,
      child: Opacity(opacity: style.barOpacity.clamp(0.0, 1.0), child: row),
    );

    if (!style.showMask) {
      return material;
    }
    // 蒙层：官方语义是「叠在内容上方的一层纯色」，高度 = 栏高 + 额外 16vp。
    // 它在**栏体之外**向下再延伸一段，让栏与内容的交界不是硬边。
    final Color maskColor =
        style.maskColor ??
        (theme.isDark ? const Color(0x99000000) : const Color(0xCCF1F3F5));
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          bottom: -style.maskHeight,
          height: style.height + style.maskHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: maskColor,
                borderRadius: BorderRadius.circular(style.radius),
              ),
            ),
          ),
        ),
        material,
      ],
    );
  }

  Widget _item({
    required BuildContext context,
    required OhosThemeData theme,
    required OhosFloatingTabItem item,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final Color active = theme.highlightColor;
    final Color idle = theme.textSecondaryColor;
    // 墨屏上「选中 = 品牌色」会失效（`highlightColor` 与 `textPrimaryColor`
    // 都是纯黑），走 `selectionMark` 让策略决定怎么表达。
    final OhosSelectionMark mark = theme.policy.selectionMark;
    final bool inverse = selected && mark == OhosSelectionMark.inverse;
    final Color fg = !item.enabled
        ? theme.textTertiaryColor
        : selected
        ? (inverse ? theme.onHighlightColor : active)
        : idle;

    Widget icon = item.icon ?? const SizedBox.shrink();
    if (selected && item.activeIcon != null) {
      icon = item.activeIcon!;
    }
    final IconThemeData iconTheme = IconThemeData(
      color: fg,
      size: 24,
      opacity: item.enabled ? 1 : 0.4,
    );

    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconTheme.merge(data: iconTheme, child: icon),
        if (item.label != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            item.label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (theme.typography.labelSmall ?? const TextStyle(fontSize: 10))
                    .copyWith(
                      color: fg,
                      fontWeight: selected && mark == OhosSelectionMark.emphasis
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
          ),
        ],
      ],
    );

    if (item.badge != null) {
      content = Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          content,
          Positioned(
            right: -10,
            top: 0,
            child: _Badge(text: item.badge!, color: theme.dangerColor),
          ),
        ],
      );
    }

    Widget tapTarget = InkWell(
      onTap: item.enabled ? onTap : null,
      borderRadius: BorderRadius.circular(style.radius),
      child: Center(child: content),
    );

    if (inverse) {
      // 反白：实底 + 纸色文字，跨温度跨刷新都不漂。
      //
      // 形状必须跟着栏走。早先写死 12 的圆角、垂直方向不留白：56 高的方块
      // 塞进 28 半径的胶囊栏，四个角是直角，两端更是直接顶到栏的圆弧外面
      // —— 选中的那一块看起来溢出了栏体。改成四周各内缩 4vp、圆角取同曲率
      // （内缩后正好是半高圆），选中项就是栏里的一颗黑药丸。
      //
      // 关键是这层内缩**只能画在背景上**，不能靠 `Padding` 收窄内容区：
      // 内容区一收窄，`Icon(24) + 间距 2 + 单行标签` 在 `textScale ≳ 1.5` 时
      // 就撑破 48，而未选中项仍占满 56 —— 于是只有选中项溢出，偏偏大字号正是
      // 墨水屏阅读器的常用档。药丸退到 Stack 的背景层，内容继续用满高度。
      const double inset = 4;
      final Widget pill = Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.all(inset),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.highlightColor,
              borderRadius: BorderRadius.circular(
                (style.radius - inset).clamp(0.0, double.infinity),
              ),
            ),
          ),
        ),
      );
      return Stack(
        fit: StackFit.passthrough,
        children: <Widget>[pill, tapTarget],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: tapTarget,
    );
  }
}

/// 页签上的角标（14vp / 字号 9）。
///
/// 与 [OhosBadge] 是两份实现 —— 那个是 16vp 的圆、挂在图标的角上，这里要更小
/// 才能塞进栏内的一项。尺寸分开，**墨屏规则共用**（[ohosBadgeHalo] /
/// [ohosBadgeForeground]）：这一份压在**选中的页签**上，而墨屏里选中项本身
/// 就是反白实底，角标底色又同为 `dangerColor`，不描边就是一块同色的疙瘩；
/// 深色墨屏则反过来，底色与字都写死白时整颗消失。
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;

  /// 角标底色（`theme.dangerColor`）。
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ohosBadgeHalo(
      OhosTheme.of(context),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        constraints: const BoxConstraints(minWidth: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ohosBadgeForeground(color),
            fontSize: 9,
            height: 1.2,
          ),
        ),
      ),
      7,
    );
  }
}

/// 悬浮页签栏 + 内容的组合：栏叠在内容之上，且不占布局高度。
///
/// 官方要求 `barOverlap=true` —— 内容区一直延伸到栏底下，栏浮在上面。
/// 用 [Stack] 表达这件事比「给内容加底部 padding」更接近原意：加了 padding
/// 内容就**永远滚不到栏底下**，视觉上栏像是被切掉一块。
class OhosFloatingTabScaffold extends StatelessWidget {
  const OhosFloatingTabScaffold({
    super.key,
    required this.bar,
    required this.child,
    this.duration = OhosGeometry.durationShort,
  });

  /// 页签栏。
  final Widget bar;

  /// 内容区。
  final Widget child;

  /// 栏出现 / 消失的动效时长。
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        Positioned(left: 0, right: 0, bottom: 0, child: bar),
      ],
    );
  }
}
