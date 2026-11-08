import 'package:flutter/foundation.dart';

/// 页签栏宽度的三档取值，对应官方 `HdsBarWidthRangeOptions`。
///
/// 三个字段分别对应三个断点区间，**但断点条件并不是简单的「宽度 <440 / 440–600 /
/// >600」** —— 官方原文（`hds-hdstabs.md` 的 `smallWidth` / `mediumWidth` /
/// `largeWidth` 三条说明）写的是：
///
/// - `smallWidth`：`HdsTabs` 宽度 **< 440vp**
/// - `mediumWidth`：宽度在 **440–600vp**，**或**宽度在 **600–840vp 之间且高宽比 < 0.8**
/// - `largeWidth`：宽度 **> 840vp**，**或**宽度在 **600–840vp 之间且高宽比 > 0.8**
///
/// 中间那档的条件里带了一个「高宽比 0.8」的旁支 —— 这是最容易被简化掉的一块：
/// 只按宽度分三档，在 600–840 的平板横竖屏之间就会选错档位。
@immutable
class OhosTabsBarWidthRange {
  const OhosTabsBarWidthRange({
    this.smallWidth,
    this.mediumWidth,
    this.largeWidth,
  });

  /// 宽度 < 440vp 时的页签栏宽度。为空则按 [OhosTabsWidthDefaults] 算。
  final double? smallWidth;

  /// 宽度在 440–600vp，或 600–840vp 且高宽比 < 0.8 时的宽度。
  final double? mediumWidth;

  /// 宽度 > 840vp，或 600–840vp 且高宽比 > 0.8 时的宽度。
  final double? largeWidth;

  @override
  bool operator ==(Object other) =>
      other is OhosTabsBarWidthRange &&
      other.smallWidth == smallWidth &&
      other.mediumWidth == mediumWidth &&
      other.largeWidth == largeWidth;

  @override
  int get hashCode => Object.hash(smallWidth, mediumWidth, largeWidth);
}

/// 页签栏宽度的**默认算法**（官方 `HdsBarWidthRangeOptions` 三条默认值说明）。
///
/// 规则按官方原文逐条拆开，**注意「≤3 个」与「≥4 个」是两条完全不同的路径**：
///
/// 1. 页签数 **≤ 3** 时：
///    - 总宽 < 600vp ⇒ `76 × n + 8`
///    - 总宽 ≥ 600vp ⇒ `80 × n + 8`（`mediumWidth` 与 `largeWidth` 两档默认值都是
///      `80 × n + 8`，`smallWidth` 那档写的是 `76 × n + 8`）
/// 2. 页签数 **≥ 4** 时：**上限 328vp**（不是在 `76n+8` 上夹，而是直接换规则）
/// 3. 迷你栏：最大宽度不超过 328vp（同一上限）
///
/// 第 3 条容易被读成「页签栏 328、迷你栏另算」—— 官方在三个字段的默认值说明里
/// 各写了一遍「迷你栏最大宽度不超过 328vp」，是同一个数。
class OhosTabsWidthDefaults {
  const OhosTabsWidthDefaults._();

  /// 小屏（<600vp）下每个页签的宽度。
  static const double compactItemWidth = 76;

  /// 大屏（≥600vp）下每个页签的宽度。
  static const double expandedItemWidth = 80;

  // 上面的 76 / 80 是**参考文档**的默认值（`hds-hdstabs.md` 的 `barWidth`
  // 说明）。设计规范配图用的是**另一套**：每页签 80 / 88，同一个 `n·w + 8` 的
  // 式子，2/3 个页签四张图逐个能对上（<600 档 168/248，≥600 档 184/272），
  // 与 76/80 恒定差 4vp/页签。两套值都在官方材料里，**不矛盾、也不等价**。
  //
  // 取 76/80：它是「编译产物的一手来源」（参考文档 + 组件默认行为）；设计稿
  // 那套留给调用方用 `OhosTabsBarWidthRange` 覆盖。改这里之前先想清楚要哪套 ——
  // 照配图改会把组件默认宽度整体放大约 5%。

  /// 页签栏两侧额外宽度。
  static const double extraWidth = 8;

  /// 页签栏 / 迷你栏的宽度上限。
  static const double maxBarWidth = 328;

  /// 断点：小屏与中屏的分界。
  static const double breakpointSmall = 440;

  /// 断点：中屏与大屏的分界。
  static const double breakpointMedium = 600;

  /// 断点：大屏上限。
  static const double breakpointLarge = 840;

  /// 600–840vp 区间内用高宽比决定中/大档的临界值。
  static const double aspectRatioThreshold = 0.8;

  /// 按页签数与容器宽度算出默认页签栏宽度。
  ///
  /// [tabCount] 页签个数；[containerWidth] 容器可用宽度；[containerHeight]
  /// 容器高度（只用于 600–840vp 区间的高宽比判定，可为 null —— 那时按宽度走）。
  ///
  /// **`tabCount <= 3` 与 `>= 4` 走两条不同路径**，不是「先算再夹」：
  /// 4 个页签按 `76×4+8 = 312` 还没到 328，但 5 个就是 388 —— 官方的规则是
  /// 超过 3 个**直接改用上限**，而不是继续按 `76n+8` 算再夹到 328。
  static double compute({
    required int tabCount,
    required double containerWidth,
    double? containerHeight,
  }) {
    if (tabCount <= 0) {
      return 0;
    }
    if (tabCount >= 4) {
      // ≥4 个：直接取上限。注意 4 个时 `76×4+8 = 312 < 328`，
      // 若按「算完再夹」会得到 312 而不是 328 —— 两条路径在这一档分出差异。
      return maxBarWidth;
    }
    final bool expanded = _isExpandedRange(
      containerWidth: containerWidth,
      containerHeight: containerHeight,
    );
    final double item = expanded ? expandedItemWidth : compactItemWidth;
    return item * tabCount + extraWidth;
  }

  /// 是否落在「大档」（用 80vp 宽度）。
  static bool _isExpandedRange({
    required double containerWidth,
    required double? containerHeight,
  }) {
    if (containerWidth >= breakpointLarge) {
      return true;
    }
    if (containerWidth < breakpointMedium) {
      return false;
    }
    // 600–840vp：由**高宽比**（height / width，不是 width / height）决定。
    //
    // 「高宽比」按中文词序读 = 高 ÷ 宽。官方的对应关系是
    // `largeWidth`：「600–840vp 之间且高宽比 **> 0.8**」⇒ 高宽比大 = 大档。
    // 于是 700×1000 的竖屏平板（1.43）落在 large、700×500 的宽扁屏（0.71）
    // 落在 medium —— 直觉上像是反的（竖屏反而用更宽的单页签），但官方原文
    // 就是这样写的，按原文来。
    //
    // 这里连着错过两次，方向相反的各一次：
    // ① 比值写成 width / height ⇒ 竖屏被判成横屏档；
    // ② 比值改对后返回值的两臂没跟着换 ⇒ 判档整体反了。
    // 两次都是同一条用例抓到的，所以这条断言必须留着。
    if (containerHeight == null) {
      return true;
    }
    return containerHeight / containerWidth > aspectRatioThreshold;
  }

  /// 选中哪一档，供测试与调试用。返回值与 [OhosTabsBarWidthRange] 的字段一一对应。
  static OhosTabsWidthTier tierOf({
    required double containerWidth,
    double? containerHeight,
  }) {
    if (containerWidth < breakpointSmall) {
      return OhosTabsWidthTier.small;
    }
    if (containerWidth < breakpointMedium) {
      return OhosTabsWidthTier.medium;
    }
    return _isExpandedRange(
          containerWidth: containerWidth,
          containerHeight: containerHeight,
        )
        ? OhosTabsWidthTier.large
        : OhosTabsWidthTier.medium;
  }
}

/// 页签栏宽度的三档。
enum OhosTabsWidthTier {
  /// 容器宽 < 440vp。
  small,

  /// 容器宽 440–600vp，或 600–840vp 且高宽比 < 0.8。
  medium,

  /// 容器宽 > 840vp，或 600–840vp 且高宽比 ≥ 0.8。
  large,
}
