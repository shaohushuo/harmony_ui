import 'package:flutter/material.dart';

/// 半模态弹窗的形态 —— 对应官方 `SheetType`。
///
/// 五种形态**不是五种样式皮肤**，各有一套能力矩阵：哪些属性生效、能不能
/// 多挡位、关闭方式、圆角与蒙层。写成「都当底部弹窗、只换对齐」会在
/// `SIDE` / `CONTENT_COVER` 两型上整体跑偏。
enum OhosSheetType {
  /// 底部弹窗（官方 `BOTTOM = 0`）。本库最早只有这一型。
  bottom,

  /// 居中弹窗（官方 `CENTER = 1`）。
  center,

  /// 跟手弹窗（官方 `POPUP = 2`）。**面板不支持跟手滑动，下滑不关闭。**
  popup,

  /// 侧边弹窗（官方 `SIDE = 3`，20+）。**高度恒全屏、无挡位、无控制条。**
  side,

  /// 全屏弹窗（官方 `CONTENT_COVER = 4`，20+）。
  ///
  /// **无圆角 / 边框 / 阴影 / 标题栏 / 关闭按钮 / 蒙层**，宽高恒全屏，
  /// 仅侧滑关闭。这一型最容易做错：看起来像「一个没有装饰的底部弹窗」，
  /// 实际连蒙层都不该有。
  contentCover,
}

/// 高度挡位 —— 对应官方 `SheetSize`。
enum OhosSheetSize {
  /// 窗口高度的 60%（官方 `MEDIUM = 0`）。**CENTER / POPUP 下无效。**
  medium,

  /// 几乎为窗口高度（官方 `LARGE = 1`）。
  ///
  /// **不是「窗口高」** —— 官方公式是「屏幕/窗口高度 − 信号栏 − 8vp」，见
  /// [OhosSheetSpec.topGap]。**CENTER / POPUP 下无效。**
  large,

  /// 适应内容高度（官方 `FIT_CONTENT = 2`）。
  fitContent,
}

/// 一挡高度：枚举或具体数值（官方 `detents` 的元素允许两者混写）。
@immutable
class OhosSheetDetent {
  const OhosSheetDetent.size(OhosSheetSize this.size) : value = null;

  const OhosSheetDetent.value(double this.value) : size = null;

  /// 枚举挡位。
  final OhosSheetSize? size;

  /// 具体高度（vp）。
  final double? value;

  @override
  bool operator ==(Object other) =>
      other is OhosSheetDetent && other.size == size && other.value == value;

  @override
  int get hashCode => Object.hash(size, value);
}

/// 半模态的几何规格与解析规则 —— 对应官方 `SheetOptions` 里与布局相关的部分。
///
/// **本类里的数值分两类，读之前必须先看清是哪一类**：
///
/// - 标 **官方** 的来自参考文档原文或三张系统资源表（给出来源令牌名）；
/// - 标 **自拟** 的是文档与资源表都没有、按观感补的。
///
/// 混合最危险的地方在于：看起来都像「查过的数」，实际一半是转述、一半是
/// 编的。所以每个字段都单独注明，不整段标注。
abstract final class OhosSheetSpec {
  /// 圆角。**官方**：`radius` 默认值 **32vp**（参考文档 `SheetOptions.radius`）。
  ///
  /// 注意别错成 24 —— `float.json` 里的 `ohos_id_corner_radius_dialog = 24vp`
  /// 是**对话框**的圆角，与半模态不是同一个属性。两者的值是各自独立的，
  /// 拿错一个看起来完全合理（都是「圆角」、都在 20–30 区间）。
  static const double radius = 32;

  /// CENTER / POPUP 的最小高度。**官方**：320vp
  /// （资源表 `sheet_big_window_min_height = 320.0vp`，文档同时写了这条）。
  static const double minHeight = 320;

  /// CENTER / POPUP 的最大高度占「窗口短边」的比例。**官方**：90%
  /// （资源表 `sheet_height_percent_max = 0.9`）。
  static const double maxHeightRatio = 0.9;

  /// CENTER / POPUP 在 `MEDIUM` / `LARGE` 挡位下的**固定**高度。
  /// **官方**：560vp（文档原话「设置类型为 LARGE 和 MEDIUM 无效，显示默认高度 560vp」）。
  static const double centeredFixedHeight = 560;

  /// CENTER 的默认宽度。**官方**：480vp（资源表 `sheet_center_default_width = 480.0vp`）。
  static const double centerDefaultWidth = 480;

  /// SIDE 在「大于 md 断点」时的固定宽度。**官方**：400vp（文档原文）。
  static const double sideWideWidth = 400;

  /// 控制条高度。**官方**：16vp（资源表 `sheet_drag_bar_height = 16.0vp`）。
  static const double dragBarHeight = 16;

  /// 操作区（底部按钮行）高度。**官方**：56vp（资源表 `sheet_operation_height = 56.0vp`）。
  static const double operationHeight = 56;

  /// 面板顶边与**状态栏下缘**之间的留白。**官方**：8vp。
  ///
  /// 出处四处一致，**但资源表里没有对应令牌**：
  /// 1. `bindsheet` 正文「Large：屏幕/窗口高度 − 信号栏 − 8」；
  /// 2. 同文「Size-Regular 默认最大尺寸高度距离信号栏保持 8vp 间距」；
  /// 3. 同文横屏段「高度距离屏幕顶部 8vp 安全间距」；
  /// 4. 配图 `bindsheet_16`、`button_39`、`segmentbutton_10` 上标注的「8」。
  ///
  /// 唯一数值是 -8 的令牌 `sheet_title_area_margin = -8.0vp` **不是它** ——
  /// 那是标题区自身的负边距（把标题往控制条方向拉），同名不同义。所以这里
  /// 只能写成带出处的常量，`tool/token_lookup.py --value 8` 查不到。
  static const double topGap = 8;

  /// 挡位切换的速度阈值。**官方**：1000 px/s。
  ///
  /// 与距离阈值合用，但判据是**「速度优先」**：速度过阈值就直接按手速方向
  /// 切挡，**不看距离**；速度不够才退到距离判断。写成「两个条件都要满足」
  /// 会让快速轻扫失效。
  static const double detentVelocityThreshold = 1000;

  /// 挡位切换的距离阈值：当前位置与目标位置的 **1/2**。**官方**：50%。
  static const double detentDistanceRatio = 0.5;

  /// 挡位数上限。**官方**：最多 3 挡（文档原文「可能存在大于3个不同高度
  /// 的场景，不建议使用 detents」）。
  static const int maxDetents = 3;

  /// md 断点（SIDE 宽度取半的临界）。**官方**：600vp
  /// （「断点为 md 的场景，默认宽度为窗口的 1/2」）。
  static const double breakpointMedium = 600;

  /// lg 断点：宽度自适应形态的第三档起点。**官方**：840vp。
  static const double breakpointLarge = 840;

  /// 按窗口宽度给出默认形态 —— 官方 `preferType` 的响应式规则。
  ///
  /// 原文三条：
  /// 1. 宽度 < 600vp：底部、全屏。默认**底部**。
  /// 2. 600 ≤ 宽度 < 840：底部、居中、跟手、侧边、全屏。默认**居中**。
  /// 3. 宽度 ≥ 840：同上五种。默认**跟手**。
  ///
  /// **必须传容器约束宽度，不是 `MediaQuery` 的屏幕宽度** —— 分栏场景下
  /// 两者不等，读屏幕宽会把窄栏判成大屏、默认形态直接错一档。
  static OhosSheetType defaultTypeFor(double containerWidth) {
    if (containerWidth >= breakpointLarge) {
      return OhosSheetType.popup;
    }
    if (containerWidth >= breakpointMedium) {
      return OhosSheetType.center;
    }
    return OhosSheetType.bottom;
  }

  /// 该形态是否支持多挡位。
  ///
  /// **官方**：`SIDE` / `CONTENT_COVER` 都「无挡位能力，不支持 detents 与
  /// detentSelection」。`BOTTOM` 支持；`CENTER` / `POPUP` 的 `detents`
  /// 文档未明确禁止，但同一条也写了「MEDIUM / LARGE 在此两型下无效」，
  /// 所以这里只对这两型放开**数值挡位**，枚举挡位会被解析成固定 560。
  static bool supportsDetents(OhosSheetType type) =>
      type != OhosSheetType.side && type != OhosSheetType.contentCover;

  /// 该形态是否支持控制条（`dragBar`）。SIDE / CONTENT_COVER 都不支持。
  static bool supportsDragBar(OhosSheetType type) =>
      type != OhosSheetType.side && type != OhosSheetType.contentCover;

  /// 该形态是否画蒙层。**官方**：`CONTENT_COVER`「不支持蒙层效果」。
  static bool hasMask(OhosSheetType type) => type != OhosSheetType.contentCover;

  /// 该形态是否支持关闭按钮与标题。
  /// **官方**：`CONTENT_COVER` 两者都不支持。
  static bool hasTitleAndClose(OhosSheetType type) =>
      type != OhosSheetType.contentCover;

  /// 该形态的四角是否都圆。
  ///
  /// **官方**：「底部样式不显示半模态底部 2 个圆角，即使设置了也不生效」，
  /// 其余三型四角皆圆（`CONTENT_COVER` 例外 —— 它没有圆角）。
  static bool roundsAllCorners(OhosSheetType type) =>
      type != OhosSheetType.bottom && type != OhosSheetType.contentCover;

  /// 解析某一挡的**绝对值**（vp）；`fitContent` 返回 `null` 表示「随内容」。
  ///
  /// [viewportHeight] 是半模态所在窗口的高度（不是屏幕高）。
  /// [shortSide] 是窗口短边，用于 90% 上限 —— 横屏时它就是高度。
  /// [statusBarHeight] 是状态栏高度。**必须传**：`LARGE` 挡的官方公式里
  /// 「− 信号栏」就是减它，漏传会让面板盖住状态栏（默认 0 只是为了让
  /// 不关心状态栏的纯计算调用方仍能编译）。
  static double? resolveDetent({
    required OhosSheetDetent detent,
    required OhosSheetType type,
    required double viewportHeight,
    required double shortSide,
    double statusBarHeight = 0,
  }) {
    final double? raw = switch (detent.size) {
      OhosSheetSize.fitContent => null,
      // CENTER / POPUP 下 MEDIUM / LARGE 无效，恒 560vp（官方原话）。
      OhosSheetSize.medium || OhosSheetSize.large
          when type == OhosSheetType.center || type == OhosSheetType.popup =>
        centeredFixedHeight,
      OhosSheetSize.medium => viewportHeight * 0.6,
      OhosSheetSize.large => maxPanelHeight(
        type: type,
        viewportHeight: viewportHeight,
        statusBarHeight: statusBarHeight,
      ),
      null => detent.value,
    };
    if (raw == null) {
      return null;
    }
    return clampHeight(
      height: raw,
      type: type,
      viewportHeight: viewportHeight,
      shortSide: shortSide,
      statusBarHeight: statusBarHeight,
    );
  }

  /// 该形态的面板**最大高度**（vp）。
  ///
  /// 分水岭是「面板要不要给状态栏让位」：
  ///
  /// - `SIDE` / `CONTENT_COVER` 恒全屏，**不让**（侧边抽屉与全屏弹窗都顶到窗口顶）；
  /// - 其余三型都留出 `状态栏 + 8vp`。
  ///
  /// 写成「三型都减 8」会让全屏弹窗下面漏出 8vp 白边，写成「都不减」就是
  /// 本轮修掉的缺陷。
  static double maxPanelHeight({
    required OhosSheetType type,
    required double viewportHeight,
    double statusBarHeight = 0,
  }) {
    if (type == OhosSheetType.side || type == OhosSheetType.contentCover) {
      return viewportHeight;
    }
    final double reserved = statusBarHeight + topGap;
    // 窗口本身还没有「状态栏 + 8vp」高时不能倒挂成负数。
    return viewportHeight > reserved ? viewportHeight - reserved : 0.0;
  }

  /// CENTER / POPUP 的高度夹取：最小 320vp、最大窗口短边 90%。
  ///
  /// **官方两条原文合起来看**：①「最小高度 320vp，最大高度为窗口短边的 90%」
  /// ②「大于最大高度则显示最大高度，小于最小高度则显示最小高度」。
  ///
  /// 注意第 ② 条只对 CENTER / POPUP 成立 —— `BOTTOM` 的高度上限是「距状态栏
  /// 8vp」这类**位置约束**，不是 90% 短边，套过来会把底部弹窗压矮。
  ///
  /// 两条上限取**小**：短边 90% 与「窗口高 − 状态栏 − 8vp」都要满足。竖屏下
  /// 前者恒更小，横屏短屏时后者才会生效。
  static double clampHeight({
    required double height,
    required OhosSheetType type,
    required double viewportHeight,
    required double shortSide,
    double statusBarHeight = 0,
  }) {
    if (type == OhosSheetType.contentCover) {
      return viewportHeight;
    }
    if (type == OhosSheetType.side) {
      // SIDE 高度恒全屏。
      return viewportHeight;
    }
    final double ceiling = maxPanelHeight(
      type: type,
      viewportHeight: viewportHeight,
      statusBarHeight: statusBarHeight,
    );
    if (type == OhosSheetType.bottom) {
      // BOTTOM 不套 320 / 90%，只夹到「窗口高 − 状态栏 − 8vp」。
      return height.clamp(0.0, ceiling);
    }
    final double maxHeight = shortSide * maxHeightRatio < ceiling
        ? shortSide * maxHeightRatio
        : ceiling;
    // 窗口本身比 320 还矮时，上限会小于下限 —— 取上限，否则 clamp 抛断言。
    final double lower = minHeight > maxHeight ? maxHeight : minHeight;
    return height.clamp(lower, maxHeight);
  }

  /// 挡位切换的落点判定：速度优先，速度不够才看距离。
  ///
  /// 返回目标挡位下标。`current` 当前挡位、`delta` 位移（向上为负）、
  /// `velocity` 松手时的速度（向上为负，px/s）。
  ///
  /// **判据顺序不能反**：官方是「速度超过阈值 → 直接按手速方向切挡；
  /// 速度小于阈值 → 才引入 1/2 距离判断」。反过来写（先判距离）会让快速
  /// 轻扫（位移小、速度大）被判成「回到原挡」，而真实手感恰恰相反。
  static int resolveDetentIndex({
    required int current,
    required double delta,
    required double velocity,
    required List<double> heights,
  }) {
    if (heights.isEmpty) {
      return current;
    }
    final int dir = delta < 0 ? 1 : -1; // 向上滑动 → 更高挡（下标更大）
    final int target = (current + dir).clamp(0, heights.length - 1);
    if (dir == 0 || target == current) {
      return current;
    }
    if (velocity.abs() > detentVelocityThreshold) {
      // 速度方向可能与位移方向相反（甩动回弹），以速度为准。
      final int vDir = velocity < 0 ? 1 : -1;
      return (current + vDir).clamp(0, heights.length - 1);
    }
    final double distance = (heights[target] - heights[current]).abs();
    if (delta.abs() > distance * detentDistanceRatio) {
      return target;
    }
    return current;
  }
}
