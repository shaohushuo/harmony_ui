import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ohos_theme.dart';
import 'ohos_icon_button.dart';
import 'ohos_light_material.dart';

/// 标题栏动态模糊 style, mirroring `ScrollEffectType`.
enum OhosAppBarScrollEffectType {
  /// No scroll-dependent effect.
  none,

  /// 通用模糊 (COMMON_BLUR): a uniform blur backplate and a hairline fade in
  /// as content scrolls under the bar.
  commonBlur,

  /// 过渡模糊 (TRANSITION_BLUR): the bar's background / content linearly
  /// transitions from `originalStyle` to `scrollEffectStyle`.
  transitionBlur,

  /// 渐变模糊 (GRADIENT_BLUR): blur strength ramps and the backplate fades in
  /// with a soft gradient edge.
  gradientBlur,
}

/// Scroll range (vp) over which the dynamic blur reaches full strength, plus
/// the scrolled style, mirroring `scrollEffectOpts` +
/// `originalStyle/scrollEffectStyle`.
class OhosAppBarScrollEffectOptions {
  const OhosAppBarScrollEffectOptions({
    this.effect = OhosAppBarScrollEffectType.none,
    this.blurEffectiveStartOffset = 0,
    this.blurEffectiveEndOffset = 20,
    this.blurSigma = 10,
  });

  /// Dynamic blur style.
  final OhosAppBarScrollEffectType effect;

  /// Scroll offset at which the effect starts.
  final double blurEffectiveStartOffset;

  /// Scroll offset at which the effect reaches full strength.
  final double blurEffectiveEndOffset;

  /// Maximum blur sigma.
  final double blurSigma;
}

/// How [OhosAppBar.title] sits between the leading and trailing slots.
enum OhosAppBarTitleAlignment {
  /// Centered on the bar's own axis, whatever the two side slots hold
  /// (default).
  ///
  /// This is what "centered title" means in Material (`AppBar.centerTitle`),
  /// Compose (`CenterAlignedTopAppBar`) and UIKit: a bar with a back button and
  /// three trailing icons still puts the title in the middle of the bar, not in
  /// the middle of the space left over — those differ by
  /// `(leading − actions) / 2`, i.e. 38vp for a 48vp back button plus three
  /// 40vp actions on a 360vp bar.
  ///
  /// The title keeps the full space between the two slots, and its centered
  /// position is clamped so it never runs under a slot: when the bar is too
  /// crowded for a real centered title, it slides towards the roomier side and
  /// ellipsizes instead of collapsing. A 360vp bar with two 48vp leading
  /// buttons and four 48vp actions still leaves the title 60vp; reserving
  /// `max(leading, actions)` symmetrically would leave it 0.
  ///
  /// A title that fills the remaining space by itself (a `TextField`, a
  /// `SizedBox.expand`) has no slack to slide in, so its position is the same
  /// as [start] — there is nothing to center.
  center,

  /// Centered in the space left *between* leading and actions.
  ///
  /// The title keeps the same width as [center], but the centering axis is the
  /// leftover space, so the two sides do not have to balance: a back button
  /// alone pushes the title 26vp right of the bar axis, three trailing icons
  /// push it 38vp left. Kept for apps that want the pre-0.7 look; prefer
  /// [center] unless the title has to hug the leading slot.
  centerBetweenSlots,

  /// Aligned to the leading slot's inner edge, the usual HarmonyOS list /
  /// detail page look.
  ///
  /// Direction aware: flush left in a [TextDirection.ltr] subtree, flush right
  /// in a [TextDirection.rtl] one, where the leading slot itself sits on the
  /// right.
  start,
}

/// The top application bar of `ohos_ui`, the counterpart of Flutter's
/// [AppBar].
///
/// Lays the bar out as a single row: a back button when [leading] is provided
/// or [automaticallyImplyLeading] is true and a route can pop, then [title] in
/// the remaining space, then [actions] on the trailing edge. Where the title
/// sits inside that space is up to [titleAlignment].
///
/// Leading / trailing are resolved against the ambient [Directionality]: in an
/// RTL subtree the back button moves to the right edge, the actions to the
/// left, and [OhosAppBarTitleAlignment.start] flushes against whichever side
/// the leading slot took.
class OhosAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OhosAppBar({
    super.key,
    this.title,
    this.titleAlignment = OhosAppBarTitleAlignment.center,
    this.titlePadding = const EdgeInsets.symmetric(horizontal: 8),
    this.leading,
    this.leadingWidth,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.elevation = 0,
    this.height = 56,
    this.primary = true,
    this.lightMaterial = false,
    this.lightLevel = OhosLightMaterialLevel.ultraThin,
    this.bottom,
    this.systemOverlayStyle,
    this.scrollEffect,
    this.scrollController,
    this.scrolledBackgroundColor,
    this.statusBarBackgroundColor,
  });

  /// The main title widget, typically a [Text].
  ///
  /// The bar installs a `DefaultTextStyle` with `maxLines: 1` and
  /// [TextOverflow.ellipsis], so a plain [Text] never wraps into a second line
  /// that the bar height would clip. A [Text] that sets its own `maxLines` /
  /// `overflow` keeps them — pass those to opt into a wrapping title.
  final Widget? title;

  /// How [title] is placed between the leading and trailing slots.
  ///
  /// Defaults to [OhosAppBarTitleAlignment.center], i.e. centered on the bar's
  /// own axis. Existing 0.6.x code that wants the old
  /// "centered in the leftover space" look should pass
  /// [OhosAppBarTitleAlignment.centerBetweenSlots].
  final OhosAppBarTitleAlignment titleAlignment;

  /// Padding around [title], inside the space it is given.
  ///
  /// The bar no longer reserves a fixed 64vp on each side, so a narrow
  /// container can keep its title readable by passing a smaller value; pass
  /// [EdgeInsets.zero] when the title is a full-bleed widget such as a search
  /// field.
  final EdgeInsetsGeometry titlePadding;

  /// Leading widget of the bar (back button etc.).
  final Widget? leading;

  /// Fixed width of the leading slot; the widget is centered inside it.
  ///
  /// Useful for aligning the title with the content below when the leading
  /// slot is wider than an icon button. Null keeps the natural width.
  final double? leadingWidth;

  /// Actions displayed at the trailing edge.
  ///
  /// The bar lays them out at their natural width and lets [title] shrink
  /// first, so a crowded bar degrades to a shorter title rather than an
  /// overlap. The actions themselves are not clipped or scrollable: once they
  /// alone exceed the bar width the row overflows, so keep it to a handful of
  /// icons or fold the rest into a "more" menu.
  final List<Widget>? actions;

  /// When true and [leading] is null, a back button is inserted when the
  /// enclosing route can actually pop.
  final bool automaticallyImplyLeading;

  /// Overrides the bar background color.
  final Color? backgroundColor;

  /// Background of the status bar band — the `MediaQuery.padding.top` strip
  /// that [primary] reserves above the toolbar.
  ///
  /// Null (the default) keeps the 0.3.0 look: one surface, so the band and the
  /// toolbar share [backgroundColor]. Setting a color splits the background
  /// into two bands, which is what an immersive page usually wants (status bar
  /// = page background, toolbar = card color). The inset is still absorbed by
  /// the bar, so [preferredSize] and the layout stay the same.
  ///
  /// Unrelated to [SystemUiOverlayStyle.statusBarColor] (that one only picks
  /// light/dark icons) — hence the longer name.
  ///
  /// When [scrollEffect] or [lightMaterial] is set, the band keeps its own
  /// solid color and does not take part in the scroll-driven recoloring.
  final Color? statusBarBackgroundColor;

  /// Shadow elevation; HarmonyOS bars are usually flat so the default is 0.
  final double elevation;

  /// Logical height of the bar.
  final double height;

  /// Alias of [height] using Material's `AppBar.toolbarHeight` /
  /// `kToolbarHeight` wording, so migrations do not mix the two up.
  double get toolbarHeight => height;

  /// Whether this bar is the topmost one on screen and should therefore keep
  /// the system status bar clear.
  ///
  /// When true (the default) the bar absorbs `MediaQuery.padding.top` into its
  /// own height, the same way Material's `AppBar` does with
  /// `SafeArea(bottom: false)`: the background still paints edge-to-edge, but
  /// the title / leading / actions are pushed below the clock and signal icons.
  ///
  /// This matters on OpenHarmony, where immersive (edge-to-edge) layouts are
  /// the norm: a bar that ignores the inset draws the title *under* the status
  /// bar, and the actions end up hidden behind the system icons — silently,
  /// with no overflow error.
  ///
  /// Note that [preferredSize] stays `height + bottom.preferredSize.height` and
  /// leaves the inset out: `Scaffold` already reserves
  /// `preferredSize.height + MediaQuery.padding.top` for its `appBar` slot (see
  /// `Scaffold.appBarMaxHeight`), so adding the inset here would leave an empty
  /// strip. Use [heightOf] when the total height is needed outside `Scaffold`.
  ///
  /// Set false when the bar is **not** at the top of the screen (for example
  /// inside a nested panel that already sits below the status bar) or when the
  /// caller has wrapped it in a `SafeArea` itself, otherwise the inset is
  /// applied twice.
  final bool primary;

  /// Whether the bar uses the immersive light material
  /// (ULTRA_THIN + top gradient fade) instead of an opaque background.
  ///
  /// Cost warning: this is a full-bar `BackdropFilter`, i.e. a blur composite
  /// every frame. On e-ink panels (e.g. Huawei MatePad Paper) it smears, and on
  /// low-end SoCs it drops frames — do not enable it by default for an app that
  /// has to run there.
  final bool lightMaterial;

  /// Immersive-light level when [lightMaterial] is true.
  final OhosLightMaterialLevel lightLevel;

  /// An optional widget below the toolbar, typically a [OhosTabBar].
  ///
  /// Its `preferredSize.height` is added to [preferredSize], the same way
  /// Material's `AppBar.bottom` works.
  final PreferredSizeWidget? bottom;

  /// Icon brightness of the system status bar while this bar is on top.
  ///
  /// The component does not guess it, because a bar can sit on a gradient or an
  /// image where automatic contrast fails. Null leaves the system default.
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// Optional scroll-driven dynamic blur (动态模糊) configuration.
  final OhosAppBarScrollEffectOptions? scrollEffect;

  /// Listens to the content scroll extent for [scrollEffect].
  ///
  /// When null the bar falls back to `PrimaryScrollController.maybeOf(context)`,
  /// so a page whose body owns the primary controller needs no wiring.
  final ScrollController? scrollController;

  /// Background color once the scroll effect is fully active
  /// (`scrollEffectStyle.backgroundStyle.backgroundColor`).
  final Color? scrolledBackgroundColor;

  @override
  Size get preferredSize =>
      Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  /// Total height the bar occupies at the top of a page:
  /// `height + bottom.preferredSize.height + (primary ? inset : 0)`.
  ///
  /// [preferredSize] cannot fold in the inset (it has no `BuildContext`), so a
  /// caller that reserves the space itself — wrapping the bar in its own widget
  /// to paint a separate status bar band, for example — needs this instead of
  /// hand-rolling the sum.
  static double heightOf(
    BuildContext context, {
    double height = 56,
    PreferredSizeWidget? bottom,
    bool primary = true,
  }) {
    final double inset = primary
        ? MediaQuery.maybePaddingOf(context)?.top ?? 0.0
        : 0.0;
    return height + (bottom?.preferredSize.height ?? 0) + inset;
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    final bool canPop = route?.canPop ?? false;
    Widget? leadingWidget = leading;
    if (leadingWidget == null && automaticallyImplyLeading && canPop) {
      leadingWidget = OhosIconButton(
        // 鸿蒙系统导航用带一点粗度的左箭头；iOS 那种细 chevron
        // (`arrow_back_ios_new_rounded`) 在鸿蒙观感上偏轻。
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.maybePop(context),
      );
    }
    final Color baseColor = lightMaterial
        ? Colors.transparent
        : backgroundColor ?? theme.backgroundColor;
    // 状态栏内边距：只把**内容**往下压，背景色仍铺到屏幕最顶端（沉浸式）。
    // `maybePaddingOf` 而不是 `paddingOf`：脱离 MediaQuery 使用时不至于抛异常。
    final double topInset = primary
        ? MediaQuery.maybePaddingOf(context)?.top ?? 0.0
        : 0.0;
    // leading / actions 归哪一边由书写方向决定；没有 `Directionality` 时按 LTR。
    final bool ltr = (Directionality.maybeOf(context) ?? TextDirection.ltr) ==
        TextDirection.ltr;
    // 两种居中都用居中的文本对齐；只有 `start` 是贴边对齐。
    final bool centered = titleAlignment != OhosAppBarTitleAlignment.start;
    final Widget titleSlot = DefaultTextStyle.merge(
      style: theme.typography.titleMedium ?? const TextStyle(fontSize: 17),
      textAlign: centered ? TextAlign.center : TextAlign.start,
      // 单行 + 省略：中轴居中只有「位置」没有「宽度」可让，标题放大了字号
      // 又长一点就会折成两行，多出来的行被 56vp 的栏高直接裁掉（不报溢出）。
      // 调用方自己写了 `maxLines` / `overflow` 的话以它为准。
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: Padding(
        padding: titlePadding,
        child: title ?? const SizedBox.shrink(),
      ),
    );
    final Widget? leadingSlot = leadingWidget == null
        ? null
        : leadingWidth == null
        ? Padding(
            // 外侧留 4vp：LTR 在左、RTL 在右。
            padding: ltr
                ? const EdgeInsets.only(left: 4)
                : const EdgeInsets.only(right: 4),
            child: leadingWidget,
          )
        : SizedBox(
            width: leadingWidth,
            child: Align(alignment: Alignment.center, child: leadingWidget),
          );
    final List<Widget>? actionWidgets = actions == null || actions!.isEmpty
        ? null
        : actions;
    final Widget? actionsSlot = actionWidgets == null
        ? null
        : Padding(
            padding: ltr
                ? const EdgeInsets.only(right: 4)
                : const EdgeInsets.only(left: 4),
            // 组内那 4vp 垫在「靠标题」的一侧：`Row` 的首个子节点在 RTL 下
            // 落在最右边，所以两种书写方向要换一下塞的位置。
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ltr
                  ? <Widget>[
                      for (final Widget action in actionWidgets) action,
                      const SizedBox(width: 4),
                    ]
                  : <Widget>[
                      const SizedBox(width: 4),
                      for (final Widget action in actionWidgets) action,
                    ],
            ),
          );
    final Widget toolbar = SizedBox(
      height: height,
      // `CustomMultiChildLayout` 而不是 Row：只有它能在一趟布局里先量出两侧
      // 槽位的实际宽度，再把标题按「整栏中轴」（`center`）或「剩余空间中轴」
      // （`centerBetweenSlots`）摆好。Row 拿不到对侧宽度，也就没法在偏一边
      // 的栏里把位置夹回两侧之间。
      child: CustomMultiChildLayout(
        delegate: _AppBarLayout(alignment: titleAlignment, ltr: ltr),
        children: <Widget>[
          if (leadingSlot != null)
            LayoutId(id: _AppBarSlot.leading, child: leadingSlot),
          LayoutId(id: _AppBarSlot.title, child: titleSlot),
          if (actionsSlot != null)
            LayoutId(id: _AppBarSlot.actions, child: actionsSlot),
        ],
      ),
    );
    final PreferredSizeWidget? bottomWidget = bottom;
    final Widget content = bottomWidget == null
        ? toolbar
        : Column(
            mainAxisSize: MainAxisSize.min,
            // 必须 stretch：默认的 `center` 给 bottom 的是**松**宽度约束
            // （minWidth 0）。`OhosTabBar` 的 Stack 里全是 `Positioned.fill`，
            // 松约束下会取 `constraints.smallest` → 宽度塌成 0，几个页签
            // 的标题挤在正中叠成一坨（高度还对，所以不报错）。
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[toolbar, bottomWidget],
          );
    final Color? bandColor = statusBarBackgroundColor;
    final Widget surface = Material(
      color: baseColor,
      elevation: elevation,
      // 状态栏那条单独着色时，内边距由外层那一段吸收，这里不再加。
      child: bandColor == null
          ? Padding(
              padding: EdgeInsets.only(top: topInset),
              child: content,
            )
          : content,
    );
    Widget result = lightMaterial
        ? OhosLightMaterial(
            level: lightLevel,
            gradientFade: OhosLightFade.top,
            gradientExtent: 24,
            child: surface,
          )
        : surface;
    final OhosAppBarScrollEffectOptions? effect = scrollEffect;
    // 忘了传 controller 是最常见的误配：滚动效果会静默失效。先退到页面的
    // `PrimaryScrollController`，两者都没有时在 debug 下直接断言报出来。
    final ScrollController? scroller =
        scrollController ?? PrimaryScrollController.maybeOf(context);
    final bool wantsEffect =
        effect != null && effect.effect != OhosAppBarScrollEffectType.none;
    assert(
      !wantsEffect || scroller != null,
      'OhosAppBar.scrollEffect 需要一个 ScrollController：既没有显式传 '
      'scrollController，祖先里也没有 PrimaryScrollController。',
    );
    if (wantsEffect && scroller != null) {
      result = _ScrollEffectBar(
        effect: effect,
        controller: scroller,
        baseColor: baseColor,
        scrolledColor: scrolledBackgroundColor,
        child: result,
      );
    }
    if (bandColor != null) {
      // 状态栏段放在最外层：不参与 scrollEffect 的颜色过渡，也不会被
      // lightMaterial 的顶部渐隐压住。总高仍是 inset + height + bottom。
      result = Column(
        mainAxisSize: MainAxisSize.min,
        // `center`（默认值）给子节点的是**松**宽度约束，没有 child 的
        // `ColoredBox` 会缩成 `constraints.smallest`（宽 0）→ 色带整条不可见。
        // 撑满才能铺到屏幕左右两端。
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: topInset,
            child: ColoredBox(color: bandColor),
          ),
          // `Column` 给非 flex 子节点的是**无界**高度约束，栏体内部件原本靠
          // 外层给的高度只能用 `constraints.maxHeight`（`OhosLightMaterial`
          // 就是 `isFinite ? maxHeight : 0`，无界时整层光感直接缩成 0）。
          // 这里按 `preferredSize` 把它还回去，控件内部看到的还是确定高度。
          SizedBox(height: preferredSize.height, child: result),
        ],
      );
    }
    final SystemUiOverlayStyle? overlay = systemOverlayStyle;
    if (overlay != null) {
      // 注解要**包住整条栏**（含状态栏那一段）：系统取状态栏图标明暗时是在
      // 屏幕顶端中点采样 `AnnotatedRegion`，色带若画在注解外面，那里采不到
      // 样式，等同于没传 `systemOverlayStyle`。
      result = AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlay,
        child: result,
      );
    }
    return result;
  }
}

/// Slots of the bar's single row.
enum _AppBarSlot { leading, title, actions }

/// Lays the bar out in one pass: the side slots are measured first, then the
/// title is given the width that is actually free (`barWidth − leading −
/// actions`) and positioned according to [OhosAppBarTitleAlignment].
///
/// All three alignments hand the title the same width; they only differ in
/// where it starts:
///
/// * [OhosAppBarTitleAlignment.start] — flush against the leading slot (left in
///   LTR, right in RTL — that is the side the leading slot took);
/// * [OhosAppBarTitleAlignment.centerBetweenSlots] — centered in the leftover
///   space;
/// * [OhosAppBarTitleAlignment.center] — centered on the bar axis, clamped into
///   `[leading, barWidth − actions − titleWidth]` so it never runs under a
///   slot. The clamp is what keeps a crowded bar readable instead of shrinking
///   the title to nothing. Direction independent: the bar axis is the same
///   rectangle in both writing directions.
class _AppBarLayout extends MultiChildLayoutDelegate {
  _AppBarLayout({required this.alignment, required this.ltr});

  final OhosAppBarTitleAlignment alignment;

  /// Whether the leading slot sits on the left edge and the actions on the
  /// right (`Directionality.ltr`).
  final bool ltr;

  @override
  void performLayout(Size size) {
    // 两侧槽位按「主轴无界」量：与原 Row 对非弹性子节点的约束一致，调用方
    // 塞进一个超宽 leading 时行为不变（照旧溢出，而不是被压窄后换行）。
    const BoxConstraints loose = BoxConstraints();
    double leadingWidth = 0;
    double actionsWidth = 0;
    if (hasChild(_AppBarSlot.leading)) {
      final Size slot = layoutChild(
        _AppBarSlot.leading,
        loose.copyWith(maxHeight: size.height),
      );
      leadingWidth = slot.width;
      positionChild(
        _AppBarSlot.leading,
        Offset(
          ltr ? 0 : size.width - slot.width,
          (size.height - slot.height) / 2,
        ),
      );
    }
    if (hasChild(_AppBarSlot.actions)) {
      final Size slot = layoutChild(
        _AppBarSlot.actions,
        loose.copyWith(maxHeight: size.height),
      );
      actionsWidth = slot.width;
      positionChild(
        _AppBarSlot.actions,
        Offset(
          ltr ? size.width - slot.width : 0,
          (size.height - slot.height) / 2,
        ),
      );
    }
    // 两侧加起来已经吃掉整栏时，标题必被挤成 0 宽、动作按钮还会画到栏外
    // （`Material` 默认不裁，肉眼看到的是按钮压在返回键上）。这种布局没有
    // 任何「正确的摆法」，debug 下直接报出来，而不是静默画歪。
    assert(
      leadingWidth + actionsWidth <= size.width,
      'OhosAppBar 的两侧槽位宽 ${leadingWidth + actionsWidth}vp 超过了栏宽 '
      '${size.width}vp：标题会被压成 0 宽，动作按钮会画到栏外盖住 leading。'
      '请减少 actions，或折叠进「更多」菜单。',
    );
    // 标题的「自由区间」（两侧槽位之间那段）。宽度与方向无关，**端点**与方向
    // 有关：RTL 下 leading 在右、actions 在左，左边那一刀切的是 actions。
    final double freeStart = ltr ? leadingWidth : actionsWidth;
    final double freeEnd = ltr
        ? size.width - actionsWidth
        : size.width - leadingWidth;
    // 两种居中给标题的**宽度**完全一样：两侧槽位之间的剩余空间。差别只在
    // 「居中轴」是哪一条 —— 严格对称预留（`栏宽 − 2×max(两侧)`）会让标题位在
    // 偏一边的栏里塌成 0（360vp 栏 + 2 个 leading + 4 个 actions 就是负值），
    // Material 的 `NavigationToolbar` 也是给剩余空间再把位置夹进两侧之间，
    // 所以这里采用同一套算术。
    final double maxTitleWidth = math.max(0, freeEnd - freeStart);
    final Size titleSize = layoutChild(
      _AppBarSlot.title,
      loose.copyWith(maxWidth: maxTitleWidth, maxHeight: size.height),
    );
    // 标题没占满时，居中位置可以在 [leading 内沿, 另一侧内沿 − 标题宽]
    // 之间自由滑动；标题本来就填满了剩余空间时这个区间退化成一个点，
    // 于是自然贴住较窄的那一侧 —— 永不重叠，也永不塌成 0。
    final double slack = math.max(0, maxTitleWidth - titleSize.width);
    final double titleX = switch (alignment) {
      // 贴 leading 的内沿：LTR 从自由区间左端起算，RTL 从右端往左让出标题宽。
      OhosAppBarTitleAlignment.start => ltr ? freeStart : freeStart + slack,
      OhosAppBarTitleAlignment.centerBetweenSlots => freeStart + slack / 2,
      OhosAppBarTitleAlignment.center => ((size.width - titleSize.width) / 2)
          .clamp(freeStart, freeStart + slack)
          .toDouble(),
    };
    positionChild(
      _AppBarSlot.title,
      Offset(titleX, (size.height - titleSize.height) / 2),
    );
  }

  @override
  bool shouldRelayout(_AppBarLayout oldDelegate) =>
      oldDelegate.alignment != alignment || oldDelegate.ltr != ltr;
}

/// Applies the scroll-driven dynamic blur (动态模糊) to an [OhosAppBar].
class _ScrollEffectBar extends StatelessWidget {
  const _ScrollEffectBar({
    required this.effect,
    required this.controller,
    required this.baseColor,
    required this.scrolledColor,
    required this.child,
  });

  final OhosAppBarScrollEffectOptions effect;
  final ScrollController controller;
  final Color baseColor;
  final Color? scrolledColor;
  final Widget child;

  double get _progress {
    final double offset = controller.hasClients ? controller.offset : 0;
    final double span =
        (effect.blurEffectiveEndOffset - effect.blurEffectiveStartOffset).clamp(
          0.1,
          1e9,
        );
    return ((offset - effect.blurEffectiveStartOffset) / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _progress;
        if (t <= 0) {
          return child!;
        }
        switch (effect.effect) {
          case OhosAppBarScrollEffectType.none:
            return child!;
          case OhosAppBarScrollEffectType.transitionBlur:
            final OhosThemeData theme = OhosTheme.of(context);
            final Color target = scrolledColor ?? Colors.white;
            final Color color = Color.lerp(baseColor, target, t)!;
            return Material(
              color: color,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: child!),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: t,
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: theme.dividerColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          case OhosAppBarScrollEffectType.commonBlur:
          case OhosAppBarScrollEffectType.gradientBlur:
            final double eased =
                effect.effect == OhosAppBarScrollEffectType.gradientBlur
                ? Curves.easeOut.transform(t)
                : t;
            final double sigma = effect.blurSigma * eased;
            // 尺寸**由 `child!` 决定**，模糊层与色罩用 `Positioned.fill` 贴上去。
            //
            // 早先写的是 `Stack(fit: StackFit.expand)`。它在**高度无界**的父约束
            // 下会把 `BoxConstraints.biggest`（此时 h = Infinity）原样传给
            // `BackdropFilter`，于是直接抛
            // 「BoxConstraints forces an infinite height」。
            //
            // 触发条件不罕见：标题栏被放进可滚动容器（`ListView` / `Column` 里的
            // 弹性区）就会出现 —— 而 `OhosAppBar` 正是被设计成能塞进任意父容器的
            // 一个普通 widget。示例页「kit 页」在 320vp × 1.3 字号下就是这条路径，
            // 一旦某个示例变高、把这块滚进视口，整页红屏。
            //
            // `Positioned.fill` 的子节点拿到的是 Stack 尺寸的**紧约束**，而 Stack
            // 尺寸只由非定位子节点（这里的 `child!`）决定，所以无界高度天然被
            // `child` 的高度兜住。
            return ClipRect(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  child!,
                  // Frosted tint over the blurred backdrop.
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white.withValues(
                        alpha: 0.20 + 0.30 * eased,
                      ),
                    ),
                  ),
                ],
              ),
            );
        }
      },
      child: child,
    );
  }
}
