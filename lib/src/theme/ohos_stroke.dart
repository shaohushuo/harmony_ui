import 'package:flutter/widgets.dart';

import 'ohos_theme_data.dart';

/// 描边宽度，取整到整数个设备像素。
///
/// 1vp 在非整数 DPR（1.5 / 2.625 …）上会被栅格化成两三行灰度，墨水屏上这条线
/// 看着发虚、像「一边实一边灰」。取整到整数设备像素后线是实的；DPR 2 / 3 上算
/// 出来仍是 1.0vp，视觉不变。
///
/// 它管不到的是「盒边界落在半像素」：那由父布局给的位置决定，组件层无从对齐。
double ohosStrokeWidth(BuildContext context, [double logical = 1]) {
  // `maybe*` 而不是 `devicePixelRatioOf`：组件在极端场景里可能脱离 `MediaQuery`
  // 构建（自定义宿主、纯 render 树里做快照），断言崩溃比退回 1.0 更糟。
  final double? ratio = MediaQuery.maybeDevicePixelRatioOf(context);
  if (ratio == null || ratio <= 0) {
    return logical;
  }
  final double dpr = ratio;
  final double px = (logical * dpr).roundToDouble();
  return (px < 1 ? 1.0 : px) / dpr;
}

/// 统一的描边：宽度取整到设备像素，并显式声明画在盒内。
///
/// [BorderSide.strokeAlign] 的默认值本来就是 `strokeAlignInside`，这里写出来是为
/// 了钉住语义 —— 描边一旦画到盒外，会被祖先的 clip 吃掉半条，四条边就不再同宽。
BorderSide ohosBorderSide(
  BuildContext context,
  Color color, {
  double width = 1,
}) {
  return BorderSide(
    color: color,
    width: ohosStrokeWidth(context, width),
    strokeAlign: BorderSide.strokeAlignInside,
  );
}

/// 浅色色块（白 / 浅灰）压在白底上等于消失：给它一条发丝线，深色返回
/// [BorderSide.none]。
///
/// 判断走亮度而不是「是不是白色」—— 墨水屏上 `multiInk` 把颜色压成灰阶后，浅黄
/// 浅蓝也会化进背景。墨屏用纯黑（10% 黑的分隔色在 16 级灰上等于没有），彩屏用
/// 26% 黑（与渐变条拇指的描边同一档）。
BorderSide ohosSwatchOutline(
  BuildContext context,
  OhosThemeData theme,
  Color color, {
  double maxLuminance = 0.7,
}) {
  if (color.computeLuminance() <= maxLuminance) {
    return BorderSide.none;
  }
  return BorderSide(
    color: theme.usesOutlines
        ? theme.dividerColor
        : const Color(0x42000000),
    width: ohosStrokeWidth(context, theme.outlineWidth),
  );
}
