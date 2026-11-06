import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_divider.dart';
import 'ohos_loading_indicator.dart';

/// A 区（列表左侧）元素的图形尺寸，对应 ArkUI 的 `IconSize`。
///
/// 值顺序与官方一致（`SMALL_ICON=1` / `SYSTEM_ICON=2`）。
enum OhosListItemCardIconSize {
  /// 小图标 16vp（穿戴设备 28vp）。官方 `IconSize.SMALL_ICON`。
  small,

  /// 系统图标 24vp（穿戴设备 32vp）。官方 `IconSize.SYSTEM_ICON`，默认值。
  system,
}

/// 列表卡片的整体几何。
///
/// **这一组里只有前两个来自官方文档，其余全是自拟值。** `HdsListItemCard`
/// 是闭源 HDS 组件，系统资源表（`pattern.json` / `float_sys.json` /
/// `float.json`）里没有 `hdslistitemcard` 相关的 pattern，参考文档也通篇
/// 没给任何布局默认值 —— 全页只有两处明写数字：`IconSize` 的 16 / 24，以及
/// 穿戴设备 `PrefixImage` 的 46×46。所以下面每个值都单独标了出处，
/// **不要把 `cardHeight` 之类当成「官方默认值」**：
///
/// | 常量 | 出处 |
/// | --- | --- |
/// | [iconSmall] / [iconSystem] | 官方 `IconSize` 枚举明文 |
/// | [cardHeight] / [cardRadius] / [cardMargin] | **文档未给**，自拟 |
/// | [blockGap] / [titleGap] / [suffixGap] | **文档未给**，自拟 |
class OhosListItemCardMetrics {
  const OhosListItemCardMetrics._();

  /// 小图标边长（官方 `IconSize.SMALL_ICON`）。
  static const double iconSmall = 16;

  /// 系统图标边长（官方 `IconSize.SYSTEM_ICON`）。
  static const double iconSystem = 24;

  /// 卡片默认高度。**文档未给。**
  ///
  /// 取 72 的依据是「官方示例里三层文本同时出现」这一最常见的重形态：
  /// 主标题 `bodyLarge`（16 × 1.5 = 24）+ 2 + 副标题 `bodySmall`
  /// （14 × 1.5 = 21）+ 2 + 描述 21 = **70**，72 刚好容下并留 2vp 呼吸。
  ///
  /// 这个数**不能凭感觉取小**：64 看起来「够两行」，三层一齐给出来时
  /// `Column` 会溢出 6vp（真机上是黄黑条纹，测试里是一条
  /// `RenderFlex overflowed`），而 `height` 是固定值不是 `minHeight`，
  /// 溢出不会被撑高。
  static const double cardHeight = 72;

  /// 卡片圆角。**文档未给。**
  ///
  /// 与 `OhosListGroupMetrics.cardRadius` 取同一个 24，这样「分组卡片」与
  /// 「列表卡片」并排时圆角一致，不会出现两种曲率。
  static const double cardRadius = 24;

  /// 卡片距屏幕左右边缘的边距（官方 `cardPrefixMargin` / `cardSuffixMargin`）。
  ///
  /// **文档只说明这两个属性存在，没给默认值。** 取 12，与分组卡片的
  /// `ohos_id_card_margin_start/end` 对齐。
  static const double cardMargin = 12;

  /// 卡片自身的水平内边距。**文档未给。** 取 16，与本库其余列表一致。
  static const double cardPadding = 16;

  /// A / B / C 三区之间的间距。**文档未给。**
  static const double blockGap = OhosGeometry.spaceSm;

  /// B 区标题与下一行之间的间距。**文档未给。**
  static const double titleGap = 2;

  /// C 区由多个元素组合时的间距。**文档未给。**
  static const double suffixGap = OhosGeometry.spaceXs;

  /// C 区允许占用的最大宽度。
  ///
  /// 防止一个长文本后缀把 B 区挤到只剩几个像素。**这是本库的防呆值**，
  /// 官方没有对应属性。
  static const double suffixMaxWidth = 160;
}

/// 列表卡片的 A 区（左侧）元素，对应 ArkUI 的 `PrefixItem` 一族。
///
/// ## 为什么没有一个类对应一个官方子类
///
/// 官方在这一层有**七个**具体子类：`PrefixImage` / `PrefixIcon` /
/// `PrefixBadge` / `PrefixSwitch` / `PrefixToggleButton` / `PrefixButton` /
/// `PrefixCustomBuilder`。逐个照搬会得到七个只装一个 Widget 的空壳类 ——
/// 它们是 ArkTS 类型系统的产物（一个 `prefixItem` 字段只能声明一个类型，
/// 差异必须靠子类表达），而 Flutter 的 `Widget` 本身就是那个共同的类型。
///
/// 所以本库收成一个 [child] 槽位 + 一个尺寸档 [size]。结构差异交给调用方：
/// `OhosBadge` / `OhosSwitch` / `OhosButton` 都已经是本库现成的组件，直接放进
/// [child] 即可。这不是省略能力，而是**不让类型层级去复用本来就是 Widget
/// 的东西**。
@immutable
class OhosListItemCardPrefix {
  const OhosListItemCardPrefix({
    required this.child,
    this.size = OhosListItemCardIconSize.system,
  });

  /// A 区内容。图标、图片、开关、徽标、按钮都可以直接放。
  final Widget child;

  /// 图标档位，见 [OhosListItemCardIconSize]。
  ///
  /// 只决定 A 区的**布局盒子**边长（16 或 24）；放进来的组件若自带尺寸
  /// （如 50×30 的开关），它会按自己的尺寸居中，不被这个盒子夹取。
  final OhosListItemCardIconSize size;

  /// 该档位的边长。
  double get extent => size == OhosListItemCardIconSize.small
      ? OhosListItemCardMetrics.iconSmall
      : OhosListItemCardMetrics.iconSystem;

  @override
  bool operator ==(Object other) {
    return other is OhosListItemCardPrefix &&
        other.child == child &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(child, size);
}

/// 列表卡片的 C 区（右侧）元素类型，对应 ArkUI 的 `SuffixItem` 一族。
///
/// ## 覆盖范围
///
/// 官方共 **17 个**具体子类（`SuffixItem` 基类与 3 个 `*Options` 类型
/// 不算形态）：`Text` / `Image` / `LoadingProgress` / `Radio` / `Checkbox` /
/// `Switch` / `Arrow` / `Badge` / `Button` / `Icon` / `SubIcon` / `Select` /
/// `ToggleButton` / `BadgeAndArrow` / `TextAndArrow` / `ArrowIconText` /
/// `CustomBuilder`。
///
/// > ROADMAP 早前写的「19 种」把 `SuffixIconOptions` /
/// > `SuffixArrowIconTextOptions` / `SuffixArrowIconOptions` 与基类也数了进去。
/// > 按 `^## Suffix` 逐条清点（21 条）扣掉基类 1 个与 3 个 Options，实际是
/// > 17 个形态 —— 与 `^## Prefix` 的 7 个形态同理，都是「把类型定义当成
/// > 形态」数出来的。
///
/// 本库落地其中 **9 个**有明确形态依据的：
/// [text] / [image] / [loading] / [radio] / [checkbox] / [switchButton] /
/// [arrow] / [select] / [badge]，外加 [custom] 兜住其余一切。
///
/// **未实现的是 7 个组合型与按钮型**：`Button`（自带背板的按钮）、`Icon` /
/// `SubIcon`（单/双 Symbol，与 [custom] 等价但需要 Symbol 字体）、
/// `ToggleButton`、`BadgeAndArrow`、`TextAndArrow`、`ArrowIconText`。
/// 后四个是「已有元素的两两组合」，逐一定义只会让枚举越拉越长，而调用方用
/// [custom] 拼一个 `Row` 反而更直接。这些在 `CONTROL-MATRIX.md` 里记为 `○`。
enum OhosListItemCardSuffixType {
  /// 文本（官方 `SuffixText`）。
  text,

  /// 图片（官方 `SuffixImage`）。
  image,

  /// 加载动效（官方 `SuffixLoadingProgress`）。
  loading,

  /// 单选框（官方 `SuffixRadio`）。
  radio,

  /// 勾选框（官方 `SuffixCheckbox`）。
  checkbox,

  /// 开关（官方 `SuffixSwitch`）。
  switchButton,

  /// 箭头（官方 `SuffixArrow`）。
  arrow,

  /// 下拉（官方 `SuffixSelect`）。
  select,

  /// 徽标（官方 `SuffixBadge`）。
  badge,

  /// 自定义内容（官方 `SuffixCustomBuilder`）。
  custom,
}

/// 列表卡片的 C 区（右侧）元素。
///
/// ## 为什么每个具名构造器都强制内容
///
/// 第一版只留了 `const OhosListItemCardSuffix.text(String text)` 这类
/// **位置参数可空**的构造器，然后 `switch` 里对 `image` / `radio` 等六种
/// 一律读 `builder` —— 结果是那六个枚举值**永远渲染成空白**：构造器没地方
/// 收内容，`builder` 恒为 null。那正是「传了但没反应」的开关，比不支持更坏。
///
/// 所以现在每种类型都要求它真正需要的那个内容（`required`），类型与内容
/// 一一对应，写不出「声明了 radio 却没给 radio」的组合。
@immutable
class OhosListItemCardSuffix {
  /// 文本后缀。
  const OhosListItemCardSuffix.text(String this.text, {this.enabled = true})
    : type = OhosListItemCardSuffixType.text,
      child = null,
      size = OhosListItemCardMetrics.iconSystem;

  /// 图片后缀。[child] 通常是一个已定尺寸的 `Image` 或 `Icon`。
  const OhosListItemCardSuffix.image(Widget this.child, {this.enabled = true})
    : type = OhosListItemCardSuffixType.image,
      text = null,
      size = OhosListItemCardMetrics.iconSystem;

  /// 加载动效后缀。内容由本库自绘，尺寸走 [size]。
  const OhosListItemCardSuffix.loading({
    this.enabled = true,
    this.size = OhosListItemCardMetrics.iconSystem,
  }) : type = OhosListItemCardSuffixType.loading,
       text = null,
       child = null;

  /// 单选框后缀。
  const OhosListItemCardSuffix.radio(Widget this.child, {this.enabled = true})
    : type = OhosListItemCardSuffixType.radio,
      text = null,
      size = OhosListItemCardMetrics.iconSystem;

  /// 勾选框后缀。
  const OhosListItemCardSuffix.checkbox(
    Widget this.child, {
    this.enabled = true,
  }) : type = OhosListItemCardSuffixType.checkbox,
       text = null,
       size = OhosListItemCardMetrics.iconSystem;

  /// 开关后缀。
  const OhosListItemCardSuffix.switchButton(
    Widget this.child, {
    this.enabled = true,
  }) : type = OhosListItemCardSuffixType.switchButton,
       text = null,
       size = OhosListItemCardMetrics.iconSystem;

  /// 箭头后缀（本库自绘 `Icon >`）。
  const OhosListItemCardSuffix.arrow({this.enabled = true, this.size = 20})
    : type = OhosListItemCardSuffixType.arrow,
      text = null,
      child = null;

  /// 下拉后缀。[text] 是当前选中的文案，箭头由本库绘制。
  const OhosListItemCardSuffix.select(String this.text, {this.enabled = true})
    : type = OhosListItemCardSuffixType.select,
      child = null,
      size = OhosListItemCardMetrics.iconSystem;

  /// 徽标后缀。
  const OhosListItemCardSuffix.badge(Widget this.child, {this.enabled = true})
    : type = OhosListItemCardSuffixType.badge,
      text = null,
      size = OhosListItemCardMetrics.iconSystem;

  /// 自定义后缀。
  const OhosListItemCardSuffix.custom(Widget this.child, {this.enabled = true})
    : type = OhosListItemCardSuffixType.custom,
      text = null,
      size = OhosListItemCardMetrics.iconSystem;

  /// 类型。
  final OhosListItemCardSuffixType type;

  /// 文本内容；仅 [OhosListItemCardSuffixType.text] / `select` 使用。
  final String? text;

  /// 子内容；图片 / 选择类 / 徽标 / 自定义使用。
  final Widget? child;

  /// 是否启用（官方 `enable`，默认 `true`）。
  ///
  /// 禁用时内容降到 `textTertiaryColor` —— 与卡片整体的 40% 不透明是两件事：
  /// 后者是「整行不可用」，这个是「只有 C 区这个控件不可用」。
  final bool enabled;

  /// 图形尺寸；仅 `loading` / `arrow` 使用，其余由 [child] 自带。
  final double size;

  @override
  bool operator ==(Object other) {
    return other is OhosListItemCardSuffix &&
        other.type == type &&
        other.text == text &&
        other.child == child &&
        other.enabled == enabled &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(type, text, child, enabled, size);
}

/// HDS `HdsListItemCard` 的 Flutter 实现：A-B-C 三区列表卡片。
///
/// ## 结构与官方的对应
///
/// 官方把列表项切成三段，每段有各自的类型体系：
///
/// | 区 | 官方 | 本库 |
/// | --- | --- | --- |
/// | A 区（左） | `PrefixItem` 一族（7 个具体子类） | [OhosListItemCardPrefix] |
/// | B 区（中） | `TextItemOptions`（三层文本 + Symbol） | [title] / [subtitle] / [description] |
/// | C 区（右） | `SuffixItem` 一族（17 个具体子类） | [OhosListItemCardSuffix] 9 种 + `custom` |
///
/// B 区官方给了 `primaryText` / `secondaryText` / `description` **三层并列**
/// 文本，每层还能带左右各两个 Symbol。本库落地三层文本 + 主标题左右各一个
/// 图标，**「副图标」（`*PrefixSubSymbol`）不做** —— 官方写明它「仅在左侧
/// 第一个 Symbol 图标存在时才显示」，是给两层图标叠放留的位置，在 16vp 的
/// 图标旁边再塞一个只会挤成一团。
///
/// 三层的字阶按官方语义分：主标题 `bodyLarge` + `textPrimaryColor`、
/// 副标题 `bodySmall` + `textSecondaryColor`、描述 `bodySmall` +
/// `textTertiaryColor`。**描述不是「副标题的第二行」** —— 官方三个字段并列，
/// 示意代码里三层同时出现，所以本库三层都能显示，不是二选一。
///
/// ## 三处与官方不同的地方
///
/// 1. **A / C 两区收成 Widget 槽位**，不复制官方的类型层级。理由见
///    [OhosListItemCardPrefix]。
/// 2. **`customBuilder` 的优先级照搬**：官方写明「`TextItemOptions` 中
///    `customBuilder` 优先级高于其它接口」，本库同样 —— 给了
///    [contentBuilder] 就整块替换 B 区，三层文本与图标一起让位。
/// 3. **几何值多为自拟**，见 [OhosListItemCardMetrics] 的逐条出处说明。
class OhosListItemCard extends StatelessWidget {
  const OhosListItemCard({
    super.key,
    this.prefix,
    this.title,
    this.subtitle,
    this.description,
    this.primaryPrefix,
    this.primarySuffix,
    this.contentBuilder,
    this.suffix,
    this.onTap,
    this.enabled = true,
    this.height = OhosListItemCardMetrics.cardHeight,
    this.width,
    this.backgroundColor,
    this.borderRadius = OhosListItemCardMetrics.cardRadius,
    this.prefixMargin = OhosListItemCardMetrics.cardMargin,
    this.suffixMargin = OhosListItemCardMetrics.cardMargin,
    this.semanticLabel,
  });

  /// A 区（左侧）元素。
  final OhosListItemCardPrefix? prefix;

  /// B 区主标题（官方 `primaryText`）。
  final String? title;

  /// B 区副标题（官方 `secondaryText`）。
  final String? subtitle;

  /// B 区描述（官方 `description`）。
  final String? description;

  /// 主标题左侧图标（官方 `primaryPrefixSymbol`）。
  final Widget? primaryPrefix;

  /// 主标题右侧图标（官方 `primarySuffixSymbol`）。
  final Widget? primarySuffix;

  /// 整块替换 B 区；给了它，三层文本与图标全部让位（官方 `customBuilder`）。
  final WidgetBuilder? contentBuilder;

  /// C 区（右侧）元素。
  final OhosListItemCardSuffix? suffix;

  /// 点击回调；`null` 时无点击反馈（与官方 `onClick` 缺省一致）。
  final VoidCallback? onTap;

  /// 是否启用（官方 `enable`，默认 `true`）。
  ///
  /// 禁用时整块降到 40% 不透明且不响应点击 —— 降不透明度而不是逐个换色，
  /// 是因为卡片底板、文字、A/C 区图形分属不同色相，逐个换色会得到一块
  /// 说不清「到底哪里变了」的区域。墨水屏上 `policy.quantize` 会把 40%
  /// 量化成实色灰，仍与纸面有区分。
  final bool enabled;

  /// 卡片高度（官方 `cardHeight`）。
  ///
  /// 默认 [OhosListItemCardMetrics.cardHeight]。注意它是 **`SizedBox` 固定
  /// 高度**，不是 `minHeight` —— 官方 `cardHeight` 也是固定值。内容超过时
  /// 会溢出而不是撑高，这与 `OhosListGroup` 的行卡片（`minHeight` 48）不同，
  /// 两者不要混用。
  final double height;

  /// 卡片宽度（官方 `cardWidth`）；`null` 表示撑满可用宽度。
  final double? width;

  /// 卡片底色（官方 `cardBackgroundColor`）；`null` 用 `theme.cardColor`。
  final Color? backgroundColor;

  /// 圆角（官方 `cardBorderRadius`）。
  final double borderRadius;

  /// 距屏幕左侧的边距（官方 `cardPrefixMargin`）。
  final double prefixMargin;

  /// 距屏幕右侧的边距（官方 `cardSuffixMargin`）。
  final double suffixMargin;

  /// 无障碍文本（官方 `accessibilityText`）。
  ///
  /// 不传时由 [title] / [subtitle] / [description] 自动拼接 —— 官方特意
  /// 强调「组件不包含文本属性时，屏幕朗读选中此组件时不播报」，而三区结构
  /// 很容易出现「只有一个图标」的行。
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosVisualPolicy policy = theme.policy;
    final bool tappable = enabled && onTap != null;

    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OhosListItemCardMetrics.cardPadding,
      ),
      child: Row(
        children: <Widget>[
          if (prefix != null) ...<Widget>[
            SizedBox(
              width: prefix!.extent,
              height: prefix!.extent,
              child: Center(
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: theme.textPrimaryColor,
                    size: prefix!.extent,
                  ),
                  child: prefix!.child,
                ),
              ),
            ),
            const SizedBox(width: OhosListItemCardMetrics.blockGap),
          ],
          Expanded(child: _buildMiddle(context, theme)),
          if (suffix != null) ...<Widget>[
            const SizedBox(width: OhosListItemCardMetrics.blockGap),
            _buildSuffix(context, theme),
          ],
        ],
      ),
    );

    final Widget surface = SizedBox(
      height: height,
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: tappable ? onTap : null,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: policy.allowsRipple
              ? theme.highlightColor.withValues(alpha: 0.08)
              : Colors.transparent,
          highlightColor: policy.allowsRipple
              ? theme.highlightColor.withValues(alpha: 0.06)
              : Colors.transparent,
          child: body,
        ),
      ),
    );

    // 卡片底板：彩屏用实色卡面；墨屏靠描边而不是靠浅色填充 —— 16 级灰里
    // 浅色底板与纸面（同样是白）分不开，一块看不见的底板比没有底板更糟。
    final Color surfaceColor = backgroundColor ?? theme.cardColor;
    final Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: theme.usesOutlines
            ? Border.fromBorderSide(ohosBorderSide(context, theme.dividerColor))
            : null,
      ),
      // 子节点裁进圆角：否则点击波纹与 A 区图标会溢出到圆角之外。
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: surface,
      ),
    );

    // `container: true` + `explicitChildNodes: false` 让它成为一个语义边界：
    // 三层 `Text` 各自产出的标签会被**丢弃**，只播报这一句拼好的。
    //
    // 不加 `container` 时实测得到的标签是四行 —— 拼好的那一句，后面又跟着
    // 「无线网络 / 已连接 / 信号强」三条子节点原文，读屏会把整行念两遍。
    // 这也是官方写明 `accessibilityText` 的用意：由组件决定播报什么。
    return Semantics(
      container: true,
      enabled: enabled,
      button: tappable,
      label: semanticLabel ?? _autoLabel,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: prefixMargin,
          end: suffixMargin,
        ),
        child: enabled
            ? card
            : Opacity(opacity: 0.4, child: IgnorePointer(child: card)),
      ),
    );
  }

  /// 三层文本拼成的一句无障碍标签。
  String? get _autoLabel {
    final List<String> parts = <String>[
      if (title != null) title!,
      if (subtitle != null) subtitle!,
      if (description != null) description!,
    ];
    return parts.isEmpty ? null : parts.join('，');
  }

  /// B 区：三层文本 + 主标题两侧图标，或整块自定义。
  Widget _buildMiddle(BuildContext context, OhosThemeData theme) {
    if (contentBuilder != null) {
      return contentBuilder!(context);
    }
    final TextStyle base =
        theme.typography.bodyLarge ?? const TextStyle(fontSize: 16);
    final TextStyle small =
        theme.typography.bodySmall ?? const TextStyle(fontSize: 14);
    final List<Widget> lines = <Widget>[];
    if (title != null) {
      lines.add(
        _textLine(
          title!,
          base.copyWith(color: theme.textPrimaryColor),
          primaryPrefix,
          primarySuffix,
        ),
      );
    }
    if (subtitle != null) {
      if (lines.isNotEmpty) {
        lines.add(const SizedBox(height: OhosListItemCardMetrics.titleGap));
      }
      lines.add(
        _textLine(
          subtitle!,
          small.copyWith(color: theme.textSecondaryColor),
          null,
          null,
        ),
      );
    }
    if (description != null) {
      if (lines.isNotEmpty) {
        lines.add(const SizedBox(height: OhosListItemCardMetrics.titleGap));
      }
      lines.add(
        _textLine(
          description!,
          small.copyWith(color: theme.textTertiaryColor),
          null,
          null,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: lines,
    );
  }

  /// 一行文本，可选左右各一个图标。
  ///
  /// 文本用 `Flexible` 包住：长标题应当省略，而不是把 C 区挤出卡片。官方没
  /// 明写省略行为，但「C 区是固定宽度图形」这个结构本身就假定了 B 区会被压窄。
  Widget _textLine(
    String text,
    TextStyle style,
    Widget? prefixIcon,
    Widget? suffixIcon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (prefixIcon != null) ...<Widget>[
          IconTheme.merge(
            data: IconThemeData(
              size: OhosListItemCardMetrics.iconSmall,
              color: style.color,
            ),
            child: prefixIcon,
          ),
          const SizedBox(width: OhosGeometry.spaceXxs),
        ],
        Flexible(
          child: Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (suffixIcon != null) ...<Widget>[
          const SizedBox(width: OhosGeometry.spaceXxs),
          IconTheme.merge(
            data: IconThemeData(
              size: OhosListItemCardMetrics.iconSmall,
              color: style.color,
            ),
            child: suffixIcon,
          ),
        ],
      ],
    );
  }

  /// C 区。
  ///
  /// 九种类型里 `text` / `select` / `arrow` / `loading` 由本库绘制（它们没有
  /// 可传入的「内容」——只有文案或什么都没有），其余五种把调用方给的组件
  /// 摆上去。`loading` 复用 [OhosLoadingIndicator]：官方这里就是
  /// `LoadingProgress`，自己再画一个转圈只会与库内其余加载态观感不一致。
  Widget _buildSuffix(BuildContext context, OhosThemeData theme) {
    final OhosListItemCardSuffix s = suffix!;
    final Color color = s.enabled
        ? theme.textSecondaryColor
        : theme.textTertiaryColor;
    final TextStyle textStyle =
        (theme.typography.bodySmall ?? const TextStyle(fontSize: 14)).copyWith(
          color: color,
        );
    final Widget child;
    switch (s.type) {
      case OhosListItemCardSuffixType.text:
        child = Text(
          s.text ?? '',
          style: textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case OhosListItemCardSuffixType.arrow:
        // 箭头用 Icon 而不是字符：笔画粗细跟主题走，墨水屏上也是实心路径，
        // 而不是一个依赖字体的字形。
        child = Icon(Icons.chevron_right, size: s.size, color: color);
      case OhosListItemCardSuffixType.select:
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                s.text ?? '',
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: OhosListItemCardMetrics.suffixGap),
            Icon(Icons.keyboard_arrow_down, size: 16, color: color),
          ],
        );
      case OhosListItemCardSuffixType.loading:
        child = OhosLoadingIndicator(size: s.size, color: color);
      case OhosListItemCardSuffixType.image:
      case OhosListItemCardSuffixType.radio:
      case OhosListItemCardSuffixType.checkbox:
      case OhosListItemCardSuffixType.switchButton:
      case OhosListItemCardSuffixType.badge:
      case OhosListItemCardSuffixType.custom:
        child = s.child ?? const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: OhosListItemCardMetrics.suffixMaxWidth,
      ),
      child: child,
    );
  }
}

/// 列表卡片的列表容器：把若干 [OhosListItemCard] 纵向排开并留出卡片间距。
///
/// 官方示例直接把这些卡片塞进 `List({ space: 5 })`，间距由列表负责。本库
/// 同样把「卡片之间留多少」交给这一层，而不是让每张卡自己带外边距 ——
/// 后者在插入 / 删除项时会留下多余的一条空缝。
class OhosListItemCardList extends StatelessWidget {
  const OhosListItemCardList({
    super.key,
    required this.children,
    this.space = OhosGeometry.spaceXs,
    this.divider = false,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.physics,
  });

  /// 卡片列表。
  final List<Widget> children;

  /// 卡片之间的间距，默认 8（官方示例用 `space: 5`，这里取 8 与库内节奏一致）。
  final double space;

  /// 是否在卡片之间画一条发丝线。
  ///
  /// 官方 `HdsListItemCard` 默认不带分隔线（卡片靠底板分层）；这个开关留给
  /// 「卡片底色与页面同色、只能靠线分层」的场合。
  final bool divider;

  /// 列表内边距。
  final EdgeInsetsGeometry padding;

  /// 是否按内容收缩高度（放进可滚动容器里时用 `false`）。
  final bool shrinkWrap;

  /// 滚动行为。
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        if (divider) {
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OhosListItemCardMetrics.cardMargin,
              ),
              child: OhosDivider(color: theme.dividerColor),
            ),
          );
        } else if (space > 0) {
          rows.add(SizedBox(height: space));
        }
      }
      rows.add(children[i]);
    }
    return ListView(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      children: rows,
    );
  }
}
