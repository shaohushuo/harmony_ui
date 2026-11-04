import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_light_material.dart';

/// 背板模糊的生效策略，对应官方 `BlurStrategy`
/// （定义在 `hds-hdsnavigation.md`，`HdsNavigation` / `HdsActionBar` 共用）。
enum OhosBlurStrategy {
  /// 使能模糊（官方 `ENABLE = 0`）。
  enabled,

  /// 不使能模糊（官方 `DISABLE = 1`）。
  disabled,

  /// 由系统策略决定（官方 `ADAPTIVE = 2`，`isExpand` / `blurStrategy` 的默认值）。
  ///
  /// 官方对 `ADAPTIVE` 的解释是「共设置三档系统策略：精美、轻柔、流畅，只有
  /// 精美档位配置能够生效模糊效果。系统策略由设备厂商根据设备性能配置，未配置
  /// 时默认执行精美策略」。Flutter 侧读不到那个硬件档位，所以本库把 `adaptive`
  /// 与 `enabled` 处理成一致，**并把「读不到」这件事写在这里**而不是假装做了
  /// 自适应 —— 一个静默等同的枚举值，好过一个返回 `true` 的 `isBlurAllowed()`。
  adaptive,
}

/// 单个圆形操作按钮，对应 HDS 的 `ActionBarButton`。
///
/// 官方 `ActionBarButton` 有 **17 个**属性，本类只落其中能用 Widget 表达的
/// 12 个（见下方「不做」）。收成一个不可变值对象而不是 `Widget`：
/// 操作栏要按「两端分组 + 主按钮」重新排布，按钮必须能被读出内容
/// （图标、尺寸、是否禁用），`Widget` 做不到。
@immutable
class OhosActionBarButton {
  const OhosActionBarButton({
    required this.icon,
    this.altIcon,
    this.onPressed,
    this.enabled = true,
    this.width,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
    this.tooltip,
    this.accessibilityLabel,
  });

  /// 图标（官方 `baseIcon`）。主按钮收起态也用它。
  final Widget icon;

  /// 主按钮切换后的图标（官方 `altIcon`）。
  ///
  /// 官方明写「如果是非主按钮，`altIcon` 不生效」—— 这里不做声明式丢弃，
  /// 非主按钮的位置上它本来就不会被读（只有 `isPrimaryIconChanged` 那条路读它）。
  final Widget? altIcon;

  /// 点击事件。
  final VoidCallback? onPressed;

  /// 是否启用（官方 `enabled`，默认 `true`）。
  ///
  /// 与 [onPressed] 是**两条独立线索**：`enabled: false` 是「看起来就点不动」，
  /// `onPressed == null` 是「没接事件」。两者都表现为不可点，但前者还要降色，
  /// 不能合并成一个 `onPressed == null` 判断。
  final bool enabled;

  /// 按钮宽度（官方 `width`）。为空时用 [OhosActionBarMetrics.buttonSize]。
  ///
  /// 官方只说「支持 px/vp/fp/lpx，不支持 percent」，没给默认值 —— HDS 是闭源
  /// 套件，`pattern.json` / `float_sys.json` / `float.json` 三张资源表搜
  /// `actionbar` **全部零命中**，所以这个数是自拟的（见 [OhosActionBarMetrics]）。
  final double? width;

  /// 按钮背景色（官方 `backgroundColor`）。为空时主按钮取品牌色、其余取背板色。
  final Color? backgroundColor;

  /// 图标颜色（官方 `iconFillColor`）。
  final Color? iconColor;

  /// 图标尺寸（官方 `iconSize`）。
  final double? iconSize;

  /// 悬浮提示（官方 `hoverTips`）。
  final String? tooltip;

  /// 无障碍文本（官方 `accessibilityText`）。默认 `""`。
  final String? accessibilityLabel;
}

/// 操作栏的样式，对应 HDS 的 `ActionBarStyle`。
///
/// 官方 `ActionBarStyle` 是 `@ObservedV2` 可变对象（`@Trace` 逐字段），本库统一
/// 用不可变值对象 + `copyWith` 表达，实现 `==` / `hashCode` —— 缺了它
/// `updateShouldNotify` 会静默失效。
@immutable
class OhosActionBarStyle {
  const OhosActionBarStyle({
    this.height,
    this.blurStyle = OhosLightMaterialLevel.regular,
    this.backgroundColor,
    this.innerSpace,
    this.startSpace,
    this.endSpace,
    this.enabled = true,
    this.isHorizontal = true,
    this.isPrimaryIconChanged = false,
    this.margin,
  });

  /// 背板高度（官方 `height`）。
  final double? height;

  /// 背板模糊效果（官方 `backgroundBlurStyle`，默认 `COMPONENT_REGULAR`）。
  ///
  /// `COMPONENT_REGULAR` 是 `BlurStyle` 枚举里的「组件普通材质模糊」
  /// （`ts-universal-attributes-background.md` 的枚举值 10），对应本库
  /// [OhosLightMaterialLevel.regular]。**默认真开**，因为设计规范把这件事
  /// 写成默认属性：「组件背板默认带有模糊材质和投影，能够提高该组件的悬浮感
  /// 和可识别性」。墨屏由 `policy.allowsBlur` 判掉，改画 1vp 实线。
  final OhosLightMaterialLevel blurStyle;

  /// 背板颜色（官方 `backgroundColor`）。
  final Color? backgroundColor;

  /// 主按钮与两端按钮组的距离（官方 `innerSpace`）。
  final double? innerSpace;

  /// 起始按钮到背板边框的距离（官方 `startSpace`）。
  final double? startSpace;

  /// 终止按钮到背板边框的距离（官方 `endSpace`）。
  final double? endSpace;

  /// 整体是否启用（官方 `enabled`，默认 `true`）。
  ///
  /// 官方说明写得很清楚：「如果 `enabled=false` 表示不启用，则背板不启用并且
  /// 所有按钮都不启用；如果 `enabled=true`，则每个按钮可以单独设置是否启用」。
  /// 所以它是**总开关**，不是「背板自己的开关」。
  final bool enabled;

  /// 水平排列还是竖直排列（官方 `isHorizontal`，默认 `true`）。
  ///
  /// 官方在 `startSpace` / `endSpace` 的说明里专门括号了「水平排列时为左边框，
  /// 竖直排列时为上边框」，所以这两个参数在两个方向上都是「到背板边框」的距离，
  /// 只是边不同 —— 实现里按方向取 `EdgeInsets` 的对应边即可。
  final bool isHorizontal;

  /// 是否切换主按钮图标（官方 `isPrimaryIconChanged`，默认 `false`）。
  ///
  /// `true` → 主按钮画 `altIcon`；`false` → 画 `baseIcon`。官方把它放在
  /// `ActionBarStyle` 里而不是按钮上，因为它是**整个操作栏的状态**（展开/收起
  /// 往往与图标切换同步）。本库照官方放这里。
  final bool isPrimaryIconChanged;

  /// 上下边距（官方 `margin`，**起始版本 6.1.0(23)**）。
  final double? margin;

  OhosActionBarStyle copyWith({
    double? height,
    OhosLightMaterialLevel? blurStyle,
    Color? backgroundColor,
    double? innerSpace,
    double? startSpace,
    double? endSpace,
    bool? enabled,
    bool? isHorizontal,
    bool? isPrimaryIconChanged,
    double? margin,
  }) {
    return OhosActionBarStyle(
      height: height ?? this.height,
      blurStyle: blurStyle ?? this.blurStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      innerSpace: innerSpace ?? this.innerSpace,
      startSpace: startSpace ?? this.startSpace,
      endSpace: endSpace ?? this.endSpace,
      enabled: enabled ?? this.enabled,
      isHorizontal: isHorizontal ?? this.isHorizontal,
      isPrimaryIconChanged: isPrimaryIconChanged ?? this.isPrimaryIconChanged,
      margin: margin ?? this.margin,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OhosActionBarStyle &&
        other.height == height &&
        other.blurStyle == blurStyle &&
        other.backgroundColor == backgroundColor &&
        other.innerSpace == innerSpace &&
        other.startSpace == startSpace &&
        other.endSpace == endSpace &&
        other.enabled == enabled &&
        other.isHorizontal == isHorizontal &&
        other.isPrimaryIconChanged == isPrimaryIconChanged &&
        other.margin == margin;
  }

  @override
  int get hashCode => Object.hash(
    height,
    blurStyle,
    backgroundColor,
    innerSpace,
    startSpace,
    endSpace,
    enabled,
    isHorizontal,
    isPrimaryIconChanged,
    margin,
  );
}

/// 操作栏的几何常量。
///
/// **全部为自拟值，这是本组件最需要说清的一点。** `HdsActionBar` 属于 HDS
/// 闭源套件：`pattern.json` / `float_sys.json` / `float.json` 三张系统资源表
/// 搜 `actionbar` / `action_bar` **全部零命中**（连 `hds` 前缀都一个没有），
/// 293 行参考文档只列属性、**一条默认值数值都没给**，设计规范
/// （`component_actionbar`）只有定性描述「悬浮于页面底部」「默认带有模糊材质
/// 和投影」。所以这里每个数都是按视觉规则推的，不能当成官方默认值转述。
class OhosActionBarMetrics {
  const OhosActionBarMetrics._();

  /// 圆形按钮直径。
  ///
  /// 自拟。三个约束交叉出来的：① 设计规范把操作栏描述为「悬浮」元素，圆形
  /// 按钮要能单手拇指按到，40 偏小、64 偏大；② 图标按 24 画（与工具栏、列表
  /// 项的 `IMAGE_SIZE` 一致），24/56 = 0.43，视觉上图标占比与官方截图相符；
  /// ③ 本库墨屏要求描边为整数像素，56 的圆周长足够让 1vp 描边不糊。
  static const double buttonSize = 56;

  /// 非主按钮直径（比主按钮小一档，形成主次）。
  static const double secondaryButtonSize = 40;

  /// 图标尺寸。
  static const double iconSize = 24;

  /// 背板高度。
  static const double height = 72;

  /// 主按钮与按钮组的间距（`innerSpace`）。
  static const double innerSpace = 8;

  /// 按钮组到背板边框的间距（`startSpace` / `endSpace`）。
  static const double edgeSpace = 16;

  /// 背板圆角。
  static const double radius = 24;

  /// 展开/收起动效时长。
  static const Duration animationDuration = OhosGeometry.durationMedium;
}

/// 操作栏（核心操作栏 in the HarmonyOS guideline），HDS `HdsActionBar` 的
/// Flutter 对应物。
///
/// 结构照官方拆成三块：**起始按钮组** + **主按钮** + **末尾按钮组**，外面一层
/// 带模糊材质的背板。主按钮可展开/收起两侧按钮组，也可换成自定义 builder。
///
/// 与 0.5.x 的旧实现相比，`secondaryActions` 这个单一列表被 `startButtons` /
/// `endButtons` 两端取代 —— 官方从来只有两端布局，没有「全部放一侧」这个形态，
/// 旧字段是当时没读文档的产物。
class OhosActionBar extends StatefulWidget {
  const OhosActionBar({
    super.key,
    this.primaryButton,
    this.primaryButtonBuilder,
    this.primaryButtonBuilderWidth,
    this.startButtons = const <OhosActionBarButton>[],
    this.endButtons = const <OhosActionBarButton>[],
    this.style = const OhosActionBarStyle(),
    this.isExpand = false,
    this.onIsExpandChanged,
    this.blurStrategy = OhosBlurStrategy.adaptive,
    this.padding,
  });

  /// 主按钮（官方 `primaryButton`）。
  final OhosActionBarButton? primaryButton;

  /// 自定义主按钮（官方 `primaryButtonBuilder`）。
  ///
  /// 官方明写：「`primaryButtonBuilder` 优先级高于 `primaryButton`」，并且
  /// 「设置 `primaryButtonBuilder` 时必须同时设置 `primaryButtonBuilderWidth`」。
  /// 后一条是硬约束 —— 自定义 builder 没有内在宽度，缺了它操作栏无法排版。
  /// 所以这里用 `assert` 把「给了 builder 却没给宽度」挡在构造期。
  final WidgetBuilder? primaryButtonBuilder;

  /// 自定义主按钮的宽度。
  final double? primaryButtonBuilderWidth;

  /// 起始位置按钮组。
  final List<OhosActionBarButton> startButtons;

  /// 末尾位置按钮组。
  final List<OhosActionBarButton> endButtons;

  /// 样式。
  final OhosActionBarStyle style;

  /// 展开还是收起（官方 `isExpand`，默认 `false`）。
  ///
  /// **默认收起**是官方值。0.5.x 的 `expandable` 形态默认展开，与此相反 ——
  /// 迁移时要显式传 `isExpand: true`。
  final bool isExpand;

  /// 展开状态回调（官方 `$isExpand`）。
  final ValueChanged<bool>? onIsExpandChanged;

  /// 模糊生效策略（官方 `blurStrategy`，默认 `ADAPTIVE`）。
  final OhosBlurStrategy blurStrategy;

  /// 背板外层的额外内边距。官方没有对应参数（间距全部由 [style] 表达），
  /// 保留它是为了与 0.5.x 的 `padding` 调用点兼容。
  final EdgeInsetsGeometry? padding;

  @override
  State<OhosActionBar> createState() => _OhosActionBarState();
}

class _OhosActionBarState extends State<OhosActionBar> {
  @override
  void initState() {
    super.initState();
    // 官方「设置 primaryButtonBuilder 时必须同时设置 primaryButtonBuilderWidth」。
    // 放在这里而不是 `assert` 里，是因为 assert 只在 debug 生效，而一个缺宽度的
    // 自定义主按钮在 release 下会撑出一块尺寸未知的区域 —— 那是看得见的布局错误，
    // 不是「开发期提醒」能覆盖的。
    assert(
      widget.primaryButtonBuilder == null ||
          widget.primaryButtonBuilderWidth != null,
      'primaryButtonBuilder 必须同时给 primaryButtonBuilderWidth —— 自定义主按钮'
      '没有内在宽度，缺了它操作栏无法排版（官方同款约束）。',
    );
  }

  bool get _enabled => widget.style.enabled;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosActionBarStyle style = widget.style;

    final Widget content = style.isHorizontal
        ? _horizontal(theme)
        : _vertical(theme);

    final Widget backplate = _backplate(theme, content);

    final double? margin = style.margin;
    final Widget padded = Padding(
      padding:
          widget.padding ??
          EdgeInsets.symmetric(vertical: margin ?? 0),
      child: backplate,
    );

    return Opacity(
      // 整体禁用：官方只要求「背板不启用 + 所有按钮都不启用」，没说变透明。
      // 但背板与按钮同时失效后，界面上剩下的只是一块没有反馈的图形 —— 用
      // 0.4 的透明表示「它还在，但现在不能操作」，比留一块看似可用的背板好。
      opacity: _enabled ? 1 : 0.4,
      child: padded,
    );
  }

  /// 背板：默认模糊材质 + 投影；墨屏退化为实色 + 1vp 描边。
  Widget _backplate(OhosThemeData theme, Widget child) {
    final OhosActionBarStyle style = widget.style;
    final BorderRadius radius = BorderRadius.circular(OhosActionBarMetrics.radius);
    final double barHeight = style.height ?? OhosActionBarMetrics.height;

    // 高度只在**水平排列**时是固定值（`ActionBarStyle.height` 的语义是
    // 「背板高度」，横向栏才有这个形态）。竖直排列下按钮数是变量，强行钉 72
    // 会让 `Column` 直接溢出 —— 实测 3 行按钮 + 间距需要 152，被 72 夹住后
    // `RenderFlex overflowed by 80 pixels`。改成只给最小高度。
    final Widget sized = style.isHorizontal
        ? SizedBox(height: barHeight, child: child)
        : ConstrainedBox(
            constraints: BoxConstraints(minHeight: barHeight),
            child: child,
          );

    // `GaussianBlur`/`BackdropFilter` 在墨水屏上真机退化为「拖尾」或「留灰块
    // 且慢」，`policy.allowsBlur` 为 false 时改画实色 + 1vp 实线 —— 这不是
    // 「降级装饰」，是墨屏上唯一能表达「这是一层独立的悬浮背板」的手段。
    if (!theme.policy.allowsBlur ||
        widget.blurStrategy == OhosBlurStrategy.disabled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: style.backgroundColor ?? theme.popupColor,
          borderRadius: radius,
          border: Border.all(
            color: theme.policy.line(theme.dividerColor, 1),
            width: ohosStrokeWidth(context, theme.outlineWidth),
          ),
        ),
        child: sized,
      );
    }

    return OhosLightMaterial(
      level: style.blurStyle,
      borderRadius: radius,
      // 官方「背板默认带有模糊材质和投影」—— 投影只有彩屏能画，
      // 墨屏的 `allowsShadow` 是 false，交给策略判而不是自己判主题。
      showShadow: theme.policy.allowsShadow,
      child: sized,
    );
  }

  Widget _horizontal(OhosThemeData theme) {
    final OhosActionBarStyle style = widget.style;
    final double inner = style.innerSpace ?? OhosActionBarMetrics.innerSpace;
    final double start = style.startSpace ?? OhosActionBarMetrics.edgeSpace;
    final double end = style.endSpace ?? OhosActionBarMetrics.edgeSpace;

    final Widget? primary = _primary(theme);

    final Widget startGroup = _group(theme, widget.startButtons);
    final Widget endGroup = _group(theme, widget.endButtons);

    // 三段式：左右各一段 `Expanded` 装按钮组、中间主按钮。
    // 不用 `Spacer` —— 两侧按钮数量不等时（左 1 右 3）`Spacer` 会把主按钮
    // 推偏，居中失效；`Expanded` 各占一半，主按钮才真的在几何中心。
    return Padding(
      padding: EdgeInsets.only(left: start, right: end),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: startGroup),
          ),
          if (primary != null) ...<Widget>[
            SizedBox(width: inner),
            primary,
            SizedBox(width: inner),
          ],
          // 收起态时末尾按钮组让位。用 `SizedBox.shrink()` 而不是
          // `Visibility(maintainSize: true)` —— 后者保留占位，主按钮右侧会
          // 凭空多出一段空白，看起来像没对齐。
          Expanded(
            child: AnimatedSize(
              duration: OhosActionBarMetrics.animationDuration,
              curve: OhosGeometry.spring,
              alignment: Alignment.centerLeft,
              child: widget.isExpand
                  ? Align(alignment: Alignment.centerRight, child: endGroup)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vertical(OhosThemeData theme) {
    final OhosActionBarStyle style = widget.style;
    final double inner = style.innerSpace ?? OhosActionBarMetrics.innerSpace;
    final double start = style.startSpace ?? OhosActionBarMetrics.edgeSpace;
    final double end = style.endSpace ?? OhosActionBarMetrics.edgeSpace;

    final Widget? primary = _primary(theme);

    // 竖直排列时 `startSpace` / `endSpace` 落到**上下**边框（官方在参数说明
    // 里明文写了这条），所以这里把它们映射到 `top` / `bottom`。
    return Padding(
      padding: EdgeInsets.only(top: start, bottom: end),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _group(theme, widget.startButtons, vertical: true),
          if (primary != null) ...<Widget>[
            SizedBox(height: inner),
            primary,
            SizedBox(height: inner),
          ],
          if (widget.isExpand) _group(theme, widget.endButtons, vertical: true),
        ],
      ),
    );
  }

  /// 按钮组。空组返回 `SizedBox.shrink()` 而不是抛错 —— 官方允许 0 或多(个)
  /// 非主按钮，一侧为空是正常形态（示例 1 就只有 1 个 start + 1 个 end）。
  Widget _group(
    OhosThemeData theme,
    List<OhosActionBarButton> buttons, {
    bool vertical = false,
  }) {
    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }
    final double gap = widget.style.innerSpace ?? OhosActionBarMetrics.innerSpace;
    final List<Widget> children = <Widget>[
      for (final OhosActionBarButton button in buttons)
        _SecondaryButton(
          button: button,
          enabled: _enabled && button.enabled,
          theme: theme,
        ),
    ];
    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: gap,
      children: children,
    );
  }

  Widget? _primary(OhosThemeData theme) {
    final WidgetBuilder? builder = widget.primaryButtonBuilder;
    if (builder != null) {
      final double width =
          widget.primaryButtonBuilderWidth ?? OhosActionBarMetrics.buttonSize;
      // 自定义主按钮：官方把壳完全交给调用方，本库不套圆底、不加图标色。
      return SizedBox(width: width, height: OhosActionBarMetrics.buttonSize, child: builder(context));
    }

    final OhosActionBarButton? button = widget.primaryButton;
    if (button == null) {
      return null;
    }
    // 主按钮图标按官方 `isPrimaryIconChanged` 选：`true` 用 `altIcon`，
    // 否则用 `baseIcon`。缺 `altIcon` 时回落 —— 与 `OhosChip.selectedIcon`
    // 同一条规则，避免「切换一下就掉图标」。
    final Widget icon =
        (widget.style.isPrimaryIconChanged && button.altIcon != null)
        ? button.altIcon!
        : button.icon;

    return _PrimaryButton(
      button: button,
      icon: icon,
      enabled: _enabled && button.enabled,
      theme: theme,
    );
  }
}

/// 非主按钮（次要操作）。
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.button,
    required this.enabled,
    required this.theme,
  });

  final OhosActionBarButton button;
  final bool enabled;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    final double size =
        button.width ?? OhosActionBarMetrics.secondaryButtonSize;

    return _CircleButton(
      size: size,
      enabled: enabled,
      // 次要按钮用背板色系：它不是视觉焦点，与主按钮同色会让「哪个是主要操作」
      // 重新变成谜。官方把 `backgroundColor` 留给调用方，默认值没写。
      background: button.backgroundColor ?? theme.policy.tint(theme.cardColor, 1),
      foreground: button.iconColor ?? theme.textPrimaryColor,
      iconSize: button.iconSize ?? OhosActionBarMetrics.iconSize,
      icon: button.icon,
      onPressed: enabled ? button.onPressed : null,
      tooltip: button.tooltip,
      accessibilityLabel: button.accessibilityLabel,
    );
  }
}

/// 主按钮。
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.button,
    required this.icon,
    required this.enabled,
    required this.theme,
  });

  final OhosActionBarButton button;
  final Widget icon;
  final bool enabled;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    final double size = button.width ?? OhosActionBarMetrics.buttonSize;

    return _CircleButton(
      size: size,
      enabled: enabled,
      background: button.backgroundColor ?? theme.highlightColor,
      foreground: button.iconColor ?? theme.onHighlightColor,
      iconSize: button.iconSize ?? OhosActionBarMetrics.iconSize,
      icon: icon,
      onPressed: enabled ? button.onPressed : null,
      tooltip: button.tooltip,
      accessibilityLabel: button.accessibilityLabel,
    );
  }
}

/// 圆底按钮的共同壳。
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.size,
    required this.enabled,
    required this.background,
    required this.foreground,
    required this.iconSize,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.accessibilityLabel,
  });

  final double size;
  final bool enabled;
  final Color background;
  final Color foreground;
  final double iconSize;
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? accessibilityLabel;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);

    final Widget core = SizedBox(
      width: size,
      height: size,
      child: IconTheme.merge(
        data: IconThemeData(color: foreground, size: iconSize),
        child: Center(child: icon),
      ),
    );

    final Widget material = Material(
      color: enabled ? background : theme.policy.disabledFill(background),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        // 墨屏的水波纹真机上会「留灰块且慢」，`policy.allowsRipple` 是唯一
        // 该问的地方 —— 不要在组件里判 `theme.mono`。
        canRequestFocus: enabled,
        child: core,
      ),
    );

    Widget result = material;

    if (accessibilityLabel != null) {
      result = Semantics(
        label: accessibilityLabel,
        button: true,
        enabled: enabled,
        container: true,
        excludeSemantics: true,
        child: result,
      );
    }

    if (tooltip != null) {
      result = Tooltip(message: tooltip!, child: result);
    }

    return result;
  }
}