import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// 开关的滑块与轨道样式，对应官方 `SwitchStyle`（Toggle 参考文档，API 12+）。
///
/// 四个字段与官方**一一对应**，默认值也取自同一张表：
///
/// | 字段 | 官方默认 | 出处 |
/// | --- | --- | --- |
/// | `pointRadius` | `高度/2 - 2*高度/20` → 30 高时 **12**、44 高时 **17.6** | 默认算法原文 |
/// | `unselectedColor` | `0x337F7F7F` | 文档「深色和浅色模式下均为」 |
/// | `pointColor` | `ohos_id_color_foreground_contrary` | 令牌 → 主题 `onHighlightColor` |
/// | `trackBorderRadius` | `高度/2` → 30 高时 **15** | 默认算法原文 |
///
/// 默认值刻意写成 `null` 而不是把「30 高的结果」硬编码进来：官方的默认算法
/// 是**跟着组件高度算的**，尺寸一变半径就得跟着变。钉死 12 / 15 的话，把
/// [OhosSwitch.size] 改成 60×40 滑块会缩在轨道中间一条，反而不像开关。
@immutable
class OhosSwitchStyle {
  const OhosSwitchStyle({
    this.pointRadius,
    this.unselectedColor,
    this.pointColor,
    this.trackBorderRadius,
  });

  /// 圆形滑块的半径（vp）。null 按官方默认算法：`h/2 - 2*h/20`。
  ///
  /// 官方对小于 0 的设定值「按默认算法设置」，这里同样处理 —— 负半径画不出
  /// 圆形，静默回落比抛异常温和，也与官方一致。
  final double? pointRadius;

  /// 关闭态轨道底色。官方默认 `0x337F7F7F`。
  ///
  /// **默认值故意留空**：本库关闭态的颜色来自主题（彩屏 `textTertiaryColor`
  /// 30%，描边主题则留白交给 `outlineWidth`）。直接把 `0x337F7F7F` 设成默认
  /// 会让墨水屏重新出现「一块 20% 的灰斑」—— 那正是策略层要拦的东西。要
  /// 严格对齐官方外观就显式传 `Color(0x337F7F7F)`。
  final Color? unselectedColor;

  /// 圆形滑块颜色。官方默认 `ohos_id_color_foreground_contrary`
  /// （开关打开时的反白色）→ 本库 [`OhosThemeData.onHighlightColor`]。
  final Color? pointColor;

  /// 轨道圆角（vp）。null 按官方默认算法 `h/2`。
  ///
  /// 官方对大于 `h/2` 的设定值夹到 `h/2`（胶囊上限），这里同样夹取。
  final double? trackBorderRadius;

  /// 按官方默认算法算出的滑块半径（`h/2 - 2*h/20`）。
  ///
  /// **公式逐字照抄官方文档**，不是「减去 4」这种等价化简：30 高时官方给 12、
  /// 旧实现 `h - 4` 的半径给 13；44 高时官方给 17.6、旧式给 20 —— 两档都不同，
  /// 30 高那 1vp 的差肉眼还看不出来，44 高那 2.4vp 就明显了。
  double resolvedPointRadius(double trackHeight) {
    final double r = pointRadius ?? (trackHeight / 2 - 2 * trackHeight / 20);
    // 官方「设定值小于 0 时按照默认算法设置」
    return r < 0 ? trackHeight / 2 - 2 * trackHeight / 20 : r;
  }

  /// 按官方默认算法算出的轨道圆角（`h/2`，且不超过 `h/2`）。
  double resolvedTrackRadius(double trackHeight) {
    final double r = trackBorderRadius ?? trackHeight / 2;
    if (r < 0) {
      return trackHeight / 2;
    }
    // 官方「设定值大于组件高度一半时按照组件高度一半设置」
    return r > trackHeight / 2 ? trackHeight / 2 : r;
  }

  OhosSwitchStyle copyWith({
    double? pointRadius,
    Color? unselectedColor,
    Color? pointColor,
    double? trackBorderRadius,
  }) {
    return OhosSwitchStyle(
      pointRadius: pointRadius ?? this.pointRadius,
      unselectedColor: unselectedColor ?? this.unselectedColor,
      pointColor: pointColor ?? this.pointColor,
      trackBorderRadius: trackBorderRadius ?? this.trackBorderRadius,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OhosSwitchStyle &&
      other.pointRadius == pointRadius &&
      other.unselectedColor == unselectedColor &&
      other.pointColor == pointColor &&
      other.trackBorderRadius == trackBorderRadius;

  @override
  int get hashCode => Object.hash(
    pointRadius,
    unselectedColor,
    pointColor,
    trackBorderRadius,
  );
}

/// A HarmonyOS switch, the counterpart of Flutter's [Switch] and
/// Cupertino's [CupertinoSwitch].
class OhosSwitch extends StatefulWidget {
  const OhosSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.size = const Size(50, 30),
    this.style = const OhosSwitchStyle(),
    this.pointColor,
  });

  /// Current value of the switch.
  final bool value;

  /// Called when the user toggles the value; null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Color of the track when active; defaults to the theme highlight color.
  final Color? activeColor;

  /// Color of the track when inactive.
  ///
  /// 与 [OhosSwitchStyle.unselectedColor] 是**同一条规格的两个入口**：[style]
  /// 里的那个对齐官方 `SwitchStyle.unselectedColor`，这个沿用本库 0.5 起的
  /// 参数名。两者都给时 [inactiveColor] 优先 —— 位置更具体。
  final Color? inactiveColor;

  /// Logical size of the whole switch.
  final Size size;

  /// 滑块与轨道样式（官方 `SwitchStyle`）。
  final OhosSwitchStyle style;

  /// 圆形滑块颜色（官方 `switchPointColor`，默认
  /// `ohos_id_color_foreground_contrary`）。
  ///
  /// 与 [OhosSwitchStyle.pointColor] 是同一条规格的两个入口，[pointColor]
  /// 优先（同 `inactiveColor` ←→ `unselectedColor` 的理由）。
  final Color? pointColor;

  @override
  State<OhosSwitch> createState() => _OhosSwitchState();
}

class _OhosSwitchState extends State<OhosSwitch> {
  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = widget.onChanged != null;
    final OhosVisualPolicy policy = theme.policy;
    final Color active = widget.activeColor ?? theme.highlightColor;
    // 30% 灰的轨道落在 16 级灰的第 2 级，关闭态等于只有一个白圆点悬在白页面
    // 上 —— 用描边的主题一律留白，轮廓交给 [outlineWidth] 那条实线。
    //
    // 取值优先级：`inactiveColor`（本位参数）→ `style.unselectedColor`（官方
    // 字段）→ 主题回落。前两者都是「调用方显式要求」，主题只是兜底。
    final Color inactive =
        widget.inactiveColor ??
        widget.style.unselectedColor ??
        (theme.usesOutlines
            ? Colors.transparent
            : theme.textTertiaryColor.withValues(alpha: 0.3));
    // 轨道 / 滑块共用的轮廓色：启用纯黑，禁用降一档到 #767676
    final Color lineColor = enabled
        ? theme.dividerColor
        : theme.textTertiaryColor;
    final double? outlineWidth = policy.outlineWidth;
    final double trackWidth = widget.size.width;
    final double trackHeight = widget.size.height;
    // 滑块半径与轨道圆角走官方的**算法**（见 OhosSwitchStyle），不是「高度减
    // 4」：官方 `pointRadius` 默认是 `h/2 - 2*h/20`，30 高时两式都得 13，但
    // 40 高时官方式给 16、减 4 式给 18 —— 差出来的 2vp 在真机上看得出来。
    // 半径夹进高度的一半：滑块不能比轨道还高。
    final double thumbRadius = math.min(
      widget.style.resolvedPointRadius(trackHeight),
      trackHeight / 2,
    );
    final double thumb = thumbRadius * 2;
    final double trackRadius = widget.style.resolvedTrackRadius(trackHeight);
    // 滑块颜色：官方 `switchPointColor` 默认 `ohos_id_color_foreground_contrary`
    // （反白色）。本位参数 → style.pointColor → 主题的反白色 → 纯白兜底。
    final Color point =
        widget.pointColor ??
        widget.style.pointColor ??
        theme.onHighlightColor;
    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
        child: AnimatedContainer(
          duration: OhosGeometry.durationShort,
          curve: OhosGeometry.spring,
          width: trackWidth,
          height: trackHeight,
          decoration: BoxDecoration(
            // 禁用 + 选中时轨道不再是实色，跟着描边一起降档
            color: widget.value
                ? (enabled ? active : policy.tint(active, 0.35))
                : inactive,
            borderRadius: BorderRadius.circular(trackRadius),
          ),
          // 边框走 `foregroundDecoration`：`BoxDecoration.border` 会占掉内边距，
          // 26vp 的滑块被压成 26×24 的椭圆（轨道高 30、padding 2、边框 1）。
          foregroundDecoration: outlineWidth == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(trackRadius),
                  border: Border.all(
                    color: lineColor,
                    width: ohosStrokeWidth(context, outlineWidth),
                  ),
                ),
          padding: EdgeInsets.all((trackHeight - thumb) / 2),
          child: AnimatedAlign(
            duration: OhosGeometry.durationShort,
            curve: OhosGeometry.spring,
            alignment: widget.value
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              width: thumb,
              height: thumb,
              decoration: BoxDecoration(
                color: point,
                shape: BoxShape.circle,
                // 白滑块贴在白页面上等于没有滑块，靠描边读出来
                border: outlineWidth == null
                    ? null
                    : Border.all(
                        color: lineColor,
                        width: ohosStrokeWidth(context, outlineWidth),
                      ),
                // 阴影在墨水屏上不存在，别占一层刷新
                boxShadow: policy.allowsShadow
                    ? const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
