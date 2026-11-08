import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';

/// 复选框外形，对应官方 `CheckBoxShape`（API 11+）。
///
/// 官方默认值在 API 11 **由圆角方形改成了圆形** —— 文档原文「API version 11
/// 开始，Checkbox 默认样式由圆角方形变为圆形」，而且 `shape` 属性的默认值也
/// 明写 `CheckBoxShape.CIRCLE`。本库 0.5 的默认是圆角方形，这里按官方改过来。
enum OhosCheckboxShape {
  /// 圆形（官方默认）。
  circle,

  /// 圆角方形。
  roundedSquare,
}

/// 勾选图标的样式，对应官方 `MarkStyle`（checkbox `mark` 属性，API 10+）。
///
/// 三个字段与官方一一对应，默认值取自文档明写的对象：
///
/// ```text
/// { strokeColor: ohos_id_color_foreground_contrary,
///   strokeWidth: ohos_id_checkbox_stroke_width,   // 资源表 = 2vp
///   size: '20vp' }
/// ```
///
/// 与 [OhosCheckbox.size] 的关系：官方 `size` 是**勾本身**的边长，不是整个
/// 方框的边长。24 的框里画 20 的勾，四周各留 2vp。
@immutable
class OhosCheckboxMarkStyle {
  const OhosCheckboxMarkStyle({
    this.strokeColor,
    this.strokeWidth = 2,
    this.size = 20,
  });

  /// 勾的颜色。默认 `ohos_id_color_foreground_contrary` —— 选中底色上的
  /// 反白色，本库取 [OhosThemeData.onHighlightColor] 而不是写死白：
  /// 墨屏的 highlight 是纯黑，反白色仍是白；但深色主题的高亮可能是浅色，
  /// 写死白勾会消失在一块浅底上。
  final Color? strokeColor;

  /// 勾的线宽（vp）。资源表 `ohos_id_checkbox_stroke_width = 2vp`。
  final double strokeWidth;

  /// 勾的边长（vp）。官方默认 `20vp`。
  ///
  /// 夹到不超过方框边长：24 的框里传 40 会画出框外的勾，比缩回去更像坏掉。
  final double size;

  OhosCheckboxMarkStyle copyWith({
    Color? strokeColor,
    double? strokeWidth,
    double? size,
  }) {
    return OhosCheckboxMarkStyle(
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is OhosCheckboxMarkStyle &&
      other.strokeColor == strokeColor &&
      other.strokeWidth == strokeWidth &&
      other.size == size;

  @override
  int get hashCode => Object.hash(strokeColor, strokeWidth, size);
}

/// A HarmonyOS checkbox, the counterpart of Flutter's [Checkbox].
///
/// 默认外形在 0.6 改为**圆形**（对齐官方 `CheckBoxShape.CIRCLE` 默认值），
/// 需要老的圆角方形就传 `shape: OhosCheckboxShape.roundedSquare`。
class OhosCheckbox extends StatelessWidget {
  const OhosCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.unselectedColor,
    this.size = 24,
    this.shape = OhosCheckboxShape.circle,
    this.mark = const OhosCheckboxMarkStyle(),
  });

  /// Current value of the checkbox; true when checked.
  final bool value;

  /// Called when the user changes the state; null disables the checkbox.
  final ValueChanged<bool>? onChanged;

  /// Color of the checked frame and check mark.
  final Color? activeColor;

  /// 未选中时的边框颜色（官方 `unselectedColor`，默认
  /// `ohos_id_color_switch_outline_off`）。
  ///
  /// null 时走本库的主题口径（`textTertiaryColor` 的半透明线，经策略换成实色）。
  final Color? unselectedColor;

  /// Logical size of the checkbox.
  final double size;

  /// 外形（官方 `shape`）。
  final OhosCheckboxShape shape;

  /// 勾的样式（官方 `mark`）。
  final OhosCheckboxMarkStyle mark;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onChanged != null;
    final OhosVisualPolicy policy = theme.policy;
    final Color active = activeColor ?? theme.highlightColor;
    // 圆角方形的半径官方没有给 token。资源表里能查到的只有
    // `ohos_id_checkbox_focus_radius = 6vp`（焦点描边半径，不是形状圆角），
    // 对 24 的方框正好是 0.25 倍 —— 沿用 0.5 起的 0.26，差异在小数点后两位，
    // 换成 0.25 只是把「自拟值」凑成一个能查到出处的相邻数，不是新规格。
    final double radius = size * 0.26;
    // 勾边长夹进方框：官方 size 是勾自己的边长，比框大就画到框外去了。
    final double markSize = mark.size > size ? size : mark.size;
    return Semantics(
      checked: value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: OhosGeometry.durationShort,
          curve: OhosGeometry.spring,
          width: size,
          height: size,
          decoration: BoxDecoration(
            // 只有**禁用**态才铺那层 15% 灰底。启用但未选中必须留白：
            // `policy.tint` 在彩屏上恒返回带 alpha 的颜色（`ColorVisualPolicy`
            // 不判透明），少了 `enabled` 这一维，所有「启用未勾选」的复选框
            // 会在 light / dark 下多出一块浅灰，跟选中态的实心色抢对比度。
            // 墨水屏上这层灰本来就会被策略判成透明，交回描边。
            color: enabled && value
                ? active
                : (enabled
                      ? Colors.transparent
                      : policy.tint(theme.textTertiaryColor, 0.15)),
            shape: shape == OhosCheckboxShape.circle
                ? BoxShape.circle
                : BoxShape.rectangle,
            borderRadius: shape == OhosCheckboxShape.circle
                ? null
                : BorderRadius.circular(radius),
            border: Border.all(
              // 未选中的 50% 灰（≈#BBB）在 16 级灰上是第 3 级，几乎等于没有；
              // 策略一律换成实色，禁用时降一档以示区别。
              color: value && enabled
                  ? active
                  : (unselectedColor != null
                        ? policy.line(unselectedColor!, 1)
                        : policy.line(theme.textTertiaryColor, 0.5)),
              width: ohosStrokeWidth(context, 1.5),
            ),
          ),
          child: value
              ? Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: SizedBox(
                    width: markSize,
                    height: markSize,
                    child: CustomPaint(
                      painter: _CheckMarkPainter(
                        color: enabled
                            ? (mark.strokeColor ?? theme.onHighlightColor)
                            : theme.textTertiaryColor,
                        strokeWidth: mark.strokeWidth,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// 勾的形状。
///
/// **不用 `Icons.check_rounded`**：图标是固定线宽的字体字形，官方 `mark`
/// 的 `strokeWidth` 就没法生效 —— 而那个字段正是本项要补的东西。手画路径
/// 顺带把「勾的大小」与「线宽」两个自由度都拿回来了。
class _CheckMarkPainter extends CustomPainter {
  const _CheckMarkPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // 三个控制点按**相对比例**给，这样换成任何 markSize 都不需要改数字。
    // 比例取自勾的几何特征：起笔偏左、折点在左下、收笔在右上。
    final Path path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.52)
      ..lineTo(size.width * 0.40, size.height * 0.78)
      ..lineTo(size.width * 0.88, size.height * 0.24);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckMarkPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
