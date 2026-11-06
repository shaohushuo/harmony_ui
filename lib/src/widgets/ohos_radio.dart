import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// 单选框选中态的图形，对应官方 `RadioIndicatorType` 枚举。
///
/// 三个值不是「同一个图形的三种画法」，而是三份互斥的绘制内容 —— 官方的
/// `indicatorBuilder` 一旦给出就整块替换掉系统图形，`indicatorColor` 也随之
/// 失效（文档原文：「indicatorType设置为RadioIndicatorType.CUSTOM时，不支持
/// 修改内部颜色」）。所以这里不做「颜色 + 图形」的正交拆分。
enum OhosRadioIndicator {
  /// 勾（`RadioIndicatorType.TICK` = 0）。
  ///
  /// **这是 API version 12 起的默认值**。文档开头的说明原文：「API version 12
  /// 开始，Radio选中默认样式由 `RadioIndicatorType.DOT` 变为
  /// `RadioIndicatorType.TICK`」。沿用旧实现的圆点当默认值，会让所有按新文档
  /// 写代码的调用方看到另一套图形。
  tick,

  /// 圆点（`RadioIndicatorType.DOT` = 1）—— API 12 之前的默认值。
  dot,

  /// 自定义（`RadioIndicatorType.CUSTOM` = 2），内容由
  /// [OhosRadio.indicatorBuilder] 给出。
  ///
  /// 没给 builder 时回落到 [tick]，照文档「indicatorBuilder设置为undefined时，
  /// 按照 RadioIndicatorType.TICK 进行显示」。
  custom,
}

/// A HarmonyOS radio button, the counterpart of Flutter's [Radio].
///
/// ## 选中态是「实心底板 + 反差图形」，不是「空心环 + 实心圆点」
///
/// 官方的 `RadioStyle` 把选中态拆成两个独立属性：`checkedBackgroundColor`
/// （默认 `sys.color.ohos_id_color_text_primary_activated`，即品牌高亮色）是
/// **底板**色，`indicatorColor`（默认 `sys.color.ohos_id_color_foreground_contrary`，
/// 即反差色）是**内部图形**色。两个都有默认值，说明选中态必然同时存在这两层
/// —— 若选中态只是「空心环 + 品牌色圆点」，`checkedBackgroundColor` 就没有
/// 地方可画。
///
/// 本库旧实现正是「空心环 + 品牌色圆点」。本版改为实心底板，依据是上面这条
/// 结构：TICK 与 DOT 因此共用同一套底色逻辑、只换内部图形，这也解释了为什么
/// API 12 换默认图形时整体观感并没有变。
///
/// ## 几何
///
/// 容器 `radio_container_size` = 24vp、描边 `ohos_id_radio_border_width` =
/// 1vp、内部图形直径取 `ohos_id_radio_inner_size_ratio` = 0.5（12vp）。旧实现
/// 的 `size * 0.22` 内边距与 1.5vp 描边都是自拟值。
///
/// **命中区没有按官方加宽**：官方 `ohos_id_radio_hotzone_padding` = 14vp
/// （每边），实际可点范围 24 + 28 = 52。本库不加 —— 加宽要么改布局尺寸
/// （调用方按 24 排的间距会全部失效），要么用 `Stack` + 溢出绘制（父容器
/// `clipBehavior` 一设就被切掉）。这是已知边界，不是遗漏。
class OhosRadio extends StatelessWidget {
  const OhosRadio({
    super.key,
    required this.value,
    this.onChanged,
    this.indicator = OhosRadioIndicator.tick,
    this.indicatorBuilder,
    this.activeColor,
    this.checkedBackgroundColor,
    this.uncheckedBorderColor,
    this.indicatorColor,
    this.size = 24,
  });

  /// Current value of the radio; true when selected.
  final bool value;

  /// Called when the user selects it; null disables the radio.
  ///
  /// 只在**从未选中变为选中**时回调 `true`。点一个已经选中的单选框**不回调**
  /// —— 单选框没有「取消选中」这个交互：同组内互斥，点自己等于没有操作。
  /// 旧实现点了会给 `false`，调用方照做就会出现「一组里一个都没选」的状态。
  final ValueChanged<bool>? onChanged;

  /// 选中态图形，见 [OhosRadioIndicator]。
  final OhosRadioIndicator indicator;

  /// 自定义选中图形，仅 [indicator] 为 [OhosRadioIndicator.custom] 时使用。
  ///
  /// 内容与容器中心对齐（官方：「自定义组件与Radio组件为中心点对齐显示」）。
  /// 尺寸不做夹取 —— 星形图标、头像这类内容可能比容器大，硬夹会把它切掉，
  /// 交回调用方按 [size] 控制。
  final WidgetBuilder? indicatorBuilder;

  /// 选中底板色，等价于官方的 `checkedBackgroundColor`。
  ///
  /// 保留这个名字只为兼容旧用法；语义上它只影响**底板**，不影响内部图形。
  final Color? activeColor;

  /// 选中底板色（官方 `checkedBackgroundColor`）。优先于 [activeColor]。
  final Color? checkedBackgroundColor;

  /// 未选中时的描边色（官方 `uncheckedBorderColor`）。
  final Color? uncheckedBorderColor;

  /// 内部图形色（官方 `indicatorColor`）。
  ///
  /// [indicator] 为 [OhosRadioIndicator.custom] 时无效 —— 自定义内容自带配色。
  final Color? indicatorColor;

  /// Logical size of the radio.
  final double size;

  /// 内部图形占容器的比例（`ohos_id_radio_inner_size_ratio`）。
  static const double _innerRatio = 0.5;

  /// 实际生效的图形：`custom` 没有 builder 时回落 `tick`。
  OhosRadioIndicator get effectiveIndicator =>
      indicatorBuilder == null && indicator == OhosRadioIndicator.custom
      ? OhosRadioIndicator.tick
      : indicator;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onChanged != null;
    final Color plate =
        checkedBackgroundColor ?? activeColor ?? theme.highlightColor;

    return Semantics(
      checked: value,
      enabled: enabled,
      child: GestureDetector(
        // 选中态点自己不给回调：单选框没有「取消选中」这个动作，见 onChanged。
        onTap: enabled && !value ? () => onChanged!(true) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: OhosGeometry.durationShort,
          curve: OhosGeometry.spring,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // 未选中必须留白：底板色只在选中态出现，否则空心环里多一层浅色
            // 垫底，与「已选中」的实心圆挤在同一档灰阶上。
            color: value ? plate : Colors.transparent,
            border: Border.all(
              color: value
                  ? plate
                  : (uncheckedBorderColor ??
                        // 未选中的 50% 灰在 16 级灰上几乎不可见，墨屏改用实色
                        theme.policy.line(theme.textTertiaryColor, 0.5)),
              width: ohosStrokeWidth(context, 1),
            ),
          ),
          child: value
              ? Center(child: _indicatorContent(theme, plate))
              : null,
        ),
      ),
    );
  }

  /// 选中态内部那一层图形。
  Widget _indicatorContent(OhosThemeData theme, Color plate) {
    final double inner = size * _innerRatio;
    // 反差色而不是写死白色：`onHighlight` 就是「画在 highlight 上的颜色」，
    // 而底板可能被调用方改成任意色。给了 `indicatorColor` 就照用户的。
    final Color stroke = indicatorColor ?? theme.onHighlightColor;

    switch (effectiveIndicator) {
      case OhosRadioIndicator.tick:
        return Icon(Icons.check_rounded, size: inner, color: stroke);
      case OhosRadioIndicator.dot:
        return SizedBox.square(
          // 打 key 是为了让用例能区分「内部圆点」与 `AnimatedContainer` 自己
          // 生成的那层 `DecoratedBox` —— 两者类型相同，按类型查会拿到两个。
          key: const ValueKey<String>('radio-dot'),
          dimension: inner,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: stroke),
          ),
        );
      case OhosRadioIndicator.custom:
        return Builder(builder: indicatorBuilder!);
    }
  }
}