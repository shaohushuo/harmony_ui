import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 子标题的两种形态。
///
/// 官方 `SubHeader` **没有** `type` 入参 —— 形态完全由传了哪几个字段决定
/// （`subheader.ets:643` 的 `leftArea()` 与 `:597` 的 `getMinHeight()` 是两条
/// 一致的优先级链）。这里的枚举只是把那条链的**结果**命名出来，方便调用方
/// 判断自己处在哪种形态，而不是一个新的开关。
enum OhosSubheaderType {
  /// 列表型：一行文字，可带左图标。官方高度 56vp。
  list,

  /// 内容型：主标题 + 副标题两行。官方高度 72vp。
  content,
}

// ---- 官方令牌（`sys.float.*`，经 `subheader.ets` 的 RESOURCE_CACHE_MAP 与
// ---- `float_sys.json` / `float.json` 双路互证）----
//
// 别把这些数字当「本库自拟的排版」：它们是构建 `resources.index` 的源文件里
// 的原值，改一个就等于偏离官方。

/// 单标题 / 单副标题行高（两者**相等**，各 56）。
const double _singleHeightTitle = 56;
const double _singleHeightSubtitle = 56;

/// 主副标题双行行高。
const double _doubleHeight = 72;

/// 主标题字号（`subheader_title_font_size`）与字重（`_title_font_weight` = 700）。
const double _titleFontSize = 18;
const FontWeight _titleWeight = FontWeight.w700;

/// 副标题字号（`Subtitle_S` = 14）。双行时 400（`_subtitle_font_weight`），
/// 单独成行时 500 —— 后者是 `SecondTitleStyle` / `IconSecondaryTitleStyle` 里
/// 写死的 `FontWeight.Medium`，不是令牌，但同样出自源码。
const double _subtitleFontSize = 14;
const FontWeight _subtitleWeightDouble = FontWeight.w400;
const FontWeight _subtitleWeightSingle = FontWeight.w500;

/// 主副标题间距（`subheader_titles_space` = 2）。
const double _titlesSpace = 2;

/// 左图标边长（`subheader_left_icon_size` = 16）与图标后间距
/// （`subheader_left_icon_end_margin` = 8）。
const double _leftIconSize = 16;
const double _leftIconEndMargin = 8;

/// 左右外边距（`subheader_content_margin_start` / `_end` = 16 / 16）。
const double _contentMarginStart = 16;
const double _contentMarginEnd = 16;

/// 单副标题行的左右内边距（`subheader_single_subtitle_padding` = 12）。
///
/// 只有「副标题单独成行」那两种形态吃它（`getAreaPadding()` 的条件是
/// `icon && secondaryTitle` 或 `!primaryTitle && secondaryTitle`）。所以带图标
/// 的列表型子标题左侧实际是 16 + 12 = 28，比纯文本型（16）深一档 —— 这不是
/// 笔误，官方用它把副标题行对齐到列表项文字。
const double _subtitleOnlyPadding = 12;

/// 内容上下内边距（`subheader_content_padding` = 8）。
const double _contentPadding = 8;

/// 右侧文本的额外下内边距（`padding_level2` = 4）。
///
/// 与上面 [_contentPadding] 相加才是 8：`TextArrowStyle` 的 Row 自身
/// `padding top/bottom 4`，外面再套 `margin bottom 4`（`subheader.ets:888`
/// 与 `:949`）。两处都归右侧所有，这里合并成一个常量，避免有人只看到 4
/// 就去「修正」左右不对齐。
const double _trailingExtraBottom = 4;

/// A section subheader matching ArkUI's `SubHeader` (子标题) control.
///
/// Sits above a list or content block and names it. Two shapes, chosen by which
/// fields you pass — the same priority chain as `subheader.ets:643`
/// `leftArea()`:
///
/// | fields given                          | shape           | height |
/// | ------------------------------------- | --------------- | ------ |
/// | `title` + `secondaryTitle`            | two lines       | 72     |
/// | `secondaryTitle` + `icon`             | one line, icon  | 56     |
/// | `secondaryTitle` alone                | one line        | 56     |
/// | `title` alone                         | one line        | 56     |
///
/// **`icon` requires `secondaryTitle` to show up.** That is not an oversight in
/// this port: ArkUI resolves the leading slot as
/// `secondaryTitle && icon → IconSecondaryTitleStyle` before it ever looks at
/// `primaryTitle`, so `icon` + `title` renders the icon-less title. Pass both
/// texts *and* an icon and `title` is dropped entirely (the leading slot is
/// taken by the icon + `secondaryTitle`) — [type] reports [OhosSubheaderType.list]
/// in that case, matching the 56vp height ArkUI picks. If you want the icon next
/// to a two-line block, use [leading] instead.
///
/// Geometry is pinned, not derived from font metrics:
/// `subheader_single_title_height` / `_single_subtitle_height` = 56,
/// `subheader_double_height` = 72, title 18fp/700, subtitle 14fp (400 in the
/// two-line shape, 500 when it stands alone), `subheader_titles_space` = 2,
/// left icon 16 + 8 gap, margins 16/16, `subheader_content_padding` = 8.
///
/// ```dart
/// OhosSubheader(title: '最近使用', trailing: '查看全部')
/// OhosSubheader(title: '本周', secondaryTitle: '共 12 项')
/// OhosSubheader(secondaryTitle: '已完成', icon: Icon(Icons.check_rounded))
/// ```
class OhosSubheader extends StatelessWidget {
  const OhosSubheader({
    super.key,
    this.title,
    this.secondaryTitle,
    this.icon,
    this.leading,
    this.trailing,
    this.trailingIcon,
    this.showTrailingArrow = true,
    this.onTrailingTap,
    this.contentMargin,
    this.contentPadding,
    this.height,
  }) : assert(
         title != null || secondaryTitle != null || leading != null,
         'OhosSubheader needs a title, a secondaryTitle, or a leading widget',
       );

  /// Primary (upper) title, 18fp / w700 — ArkUI's `primaryTitle`.
  ///
  /// Ignored when [secondaryTitle] and [icon] are both given; see the class
  /// documentation.
  final String? title;

  /// Secondary (lower) title, 14fp — ArkUI's `secondaryTitle`.
  ///
  /// Alone it renders as the subheader's only line at weight 500; under
  /// [title] it becomes the second line at weight 400 with a 2vp gap.
  final String? secondaryTitle;

  /// Leading icon shown before [secondaryTitle].
  ///
  /// Rendered at 16×16 with an 8vp gap, per `subheader_left_icon_size` /
  /// `_left_icon_end_margin`. **Only takes effect together with
  /// [secondaryTitle]** — see the class documentation.
  final Widget? icon;

  /// Arbitrary leading widget, used instead of the icon + text slot.
  ///
  /// Escape hatch for the case ArkUI covers with `titleBuilder`: when it is
  /// given, [icon] / [title] / [secondaryTitle] are all ignored for painting.
  ///
  /// It does **not** change the row height: `subheader.ets` `getMinHeight()`
  /// reads the *fields*, not the builder, so `leading` + both texts still
  /// reserves 72vp. That looks surprising but is the documented behaviour, and
  /// it keeps a header from jumping when you swap a built-in title for a custom
  /// one. Pass [height] explicitly if you want a different row.
  final Widget? leading;

  /// Optional trailing text, e.g. "更多". Corresponds to ArkUI's
  /// `operationItem[0].value` under `operationType: TEXT_ARROW` / `BUTTON`.
  final String? trailing;

  /// Overrides the trailing chevron. Defaults to a 16vp chevron in
  /// [OhosThemeData.textSecondaryColor] when [showTrailingArrow] is true.
  final Widget? trailingIcon;

  /// Whether the trailing chevron is drawn — ArkUI's `TEXT_ARROW` (true) vs
  /// `BUTTON` (false).
  final bool showTrailingArrow;

  /// Called when the trailing text (chevron included) is tapped.
  final VoidCallback? onTrailingTap;

  /// Outer margin — ArkUI's `contentMargin`, default 16/16 horizontally and no
  /// vertical margin.
  ///
  /// The 8vp breathing room above and below is **inside** the fixed 56/72vp
  /// row (see [contentPadding]), not part of this margin: a section header needs
  /// a constant total height so lists don't jitter when a header swaps shapes.
  final EdgeInsetsGeometry? contentMargin;

  /// Inner padding — ArkUI's `contentPadding`, default 8vp top / bottom.
  ///
  /// Horizontal padding is not yours to set here: it is 12 when [secondaryTitle]
  /// stands alone (or sits next to [icon]) and 0 otherwise, which is what
  /// `subheader.ets` `getAreaPadding()` decides. Pass a full
  /// `EdgeInsets` only if you also mean to override that asymmetry.
  final EdgeInsetsGeometry? contentPadding;

  /// Overrides the resolved row height.
  ///
  /// Defaults to 72 for the two-line shape and 56 otherwise. The row is a
  /// **minimum**, so large text scales still grow it rather than clip.
  final double? height;

  /// Which shape this instance resolves to.
  ///
  /// Derived from the fields, not a switch you set — ArkUI has no `type`
  /// parameter, and inventing one here would let callers claim a shape the
  /// renderer cannot honour.
  OhosSubheaderType get type => _isDoubleLine
      ? OhosSubheaderType.content
      : OhosSubheaderType.list;

  /// Two-line shape: both texts present and no icon taking over the leading
  /// slot (`getMinHeight()` checks `secondaryTitle && icon` **before**
  /// `secondaryTitle && primaryTitle`).
  bool get _isDoubleLine =>
      secondaryTitle != null && title != null && icon == null;

  /// Whether the leading slot is dominated by `secondaryTitle` — the forms that
  /// get 12vp horizontal inset.
  ///
  /// `getAreaPadding()` asks `(secondaryTitle && icon) || (!primaryTitle &&
  /// secondaryTitle)`, which collapses to "has a secondaryTitle and is not the
  /// two-line shape".
  bool get _isSubtitleOnly => secondaryTitle != null && !_isDoubleLine;

  /// Horizontal inset inside [contentMargin] — 12 for the subtitle-only forms,
  /// 0 otherwise.
  double get _horizontalInset => _isSubtitleOnly ? _subtitleOnlyPadding : 0;

  /// Resolved row height before [height] is applied.
  ///
  /// The two 56s are separate tokens in ArkUI
  /// (`_single_title_height` / `_single_subtitle_height`) even though they hold
  /// the same number today. Keeping them apart is what lets this class report
  /// which shape it is in without a `type` switch; collapsing them into one
  /// constant would hide that the official spec can diverge them.
  double get _resolvedHeight {
    if (height != null) {
      return height!;
    }
    if (_isDoubleLine) {
      return _doubleHeight;
    }
    return secondaryTitle != null ? _singleHeightSubtitle : _singleHeightTitle;
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final EdgeInsets margin =
        (contentMargin ??
                const EdgeInsets.symmetric(horizontal: _contentMarginStart))
            .resolve(Directionality.of(context));
    final EdgeInsets padding =
        (contentPadding ??
                const EdgeInsets.symmetric(vertical: _contentPadding))
            .resolve(Directionality.of(context));

    final Widget content = Padding(
      // 纵向 8 是官方 `subheader_content_padding`：它和 56/72 的差额一起构成
      // 「上方留白多、下方贴着列表」的观感。横向的 12 只给副标题单行形态。
      padding: EdgeInsets.only(
        top: padding.top,
        bottom: padding.bottom,
        left: padding.left + _horizontalInset,
        right: padding.right + _horizontalInset,
      ),
      child: _buildLeading(theme),
    );

    return Padding(
      padding: margin,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _resolvedHeight),
        child: Row(
          // ArkUI 用 `Flex(alignItems: End)` + 左右各 8 的下边距，让内容贴着
          // 行底：上方多出来的高度就是与上一区块的间距。居中会把这个间距
          // 一分为二，看不出「这一段从哪开始」。
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: content),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: _contentMarginEnd),
              _buildTrailing(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeading(OhosThemeData theme) {
    if (leading != null) {
      return leading!;
    }
    if (_isDoubleLine) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (theme.typography.titleLarge ??
                        const TextStyle(fontSize: _titleFontSize))
                    .copyWith(
                      fontSize: _titleFontSize,
                      fontWeight: _titleWeight,
                      color: theme.textPrimaryColor,
                    ),
          ),
          // `subheader_titles_space` = 2：两行之间只给 2vp，因为 18/14 的字阶
          // 本身已经自带行距，再大就散成两块。
          const SizedBox(height: _titlesSpace),
          Text(
            secondaryTitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (theme.typography.bodySmall ??
                        const TextStyle(fontSize: _subtitleFontSize))
                    .copyWith(
                      fontSize: _subtitleFontSize,
                      fontWeight: _subtitleWeightDouble,
                      color: theme.textSecondaryColor,
                    ),
          ),
        ],
      );
    }

    final TextStyle titleStyle =
        (theme.typography.titleLarge ??
                const TextStyle(fontSize: _titleFontSize))
            .copyWith(
              fontSize: _titleFontSize,
              fontWeight: _titleWeight,
              color: theme.textPrimaryColor,
            );
    final TextStyle subtitleStyle =
        (theme.typography.bodySmall ??
                const TextStyle(fontSize: _subtitleFontSize))
            .copyWith(
              fontSize: _subtitleFontSize,
              fontWeight: _subtitleWeightSingle,
              color: theme.textSecondaryColor,
            );

    // 单行形态里 title 与 secondaryTitle 不会同时出现 —— 同时给了两个文本而
    // 没有图标是双行形态，走上面的分支；两者都给又有图标时 ArkUI 只画图标 +
    // secondaryTitle，title 被丢掉（见类文档）。
    final String? single = secondaryTitle ?? title;
    final TextStyle singleStyle = secondaryTitle != null
        ? subtitleStyle
        : titleStyle;

    final Widget text = Text(
      single!,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: singleStyle,
    );

    if (secondaryTitle == null || icon == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconTheme.merge(
          data: IconThemeData(
            size: _leftIconSize,
            color: theme.textSecondaryColor,
          ),
          child: icon!,
        ),
        // `subheader_left_icon_end_margin` = 8。
        const SizedBox(width: _leftIconEndMargin),
        Flexible(child: text),
      ],
    );
  }

  Widget _buildTrailing(OhosThemeData theme) {
    final Color color = onTrailingTap == null
        ? theme.textTertiaryColor
        : theme.highlightColor;
    return Padding(
      // 右侧总下边距也是 8：Row 本身 4 + 外面 4。两块都算在「右侧」头上。
      padding: EdgeInsets.only(top: _contentPadding, bottom: _trailingExtraBottom),
      child: InkWell(
        onTap: onTrailingTap,
        borderRadius: BorderRadius.circular(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              trailing!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (theme.typography.bodySmall ??
                          const TextStyle(fontSize: _subtitleFontSize))
                      .copyWith(
                        fontSize: _subtitleFontSize,
                        fontWeight: _subtitleWeightSingle,
                        color: color,
                      ),
            ),
            if (showTrailingArrow) ...<Widget>[
              const SizedBox(width: 2),
              IconTheme.merge(
                data: IconThemeData(size: 16, color: color),
                child:
                    trailingIcon ??
                    const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }
}