import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// 环形弧段绘制的共用实现，供 `OhosGauge` 与 `OhosDataPanel` 使用。
///
/// 单独成文件的原因：两者画的是同一个东西（一段有厚度的圆弧），差别只在
/// 「哪几段、各占多少角度」，而角度语义（钟面 0 度、顺时针、只减法不回绕）
/// 与渐变方向都是**同一个坑**，各写一遍必然会漂。本文件不从
/// `harmony_ui.dart` 导出 —— 它是实现细节，不是公开 API。

/// 把「时钟 0 点为 0 度、顺时针为正」的角度换算成画布角度（弧度）。
///
/// 画布的角度以正 x 轴（3 点钟）为 0、顺时针为正，与钟面正好差 90°。官方
/// 两处角度（`Gauge.startAngle` / `endAngle`）都是钟面语义，所以每处都要过
/// 这一道换算，不能把文档里的 210/150 直接喂给 `drawArc`。
double ohosCanvasAngle(double degrees) => (degrees - 90) * math.pi / 180;

/// 从 [startAngle] 顺时针扫到 [endAngle] 的弧度。
///
/// 官方写明「从起始位置到终止位置的绘制只有顺时针方向」，所以 350° → 10° 是
/// **20°** 而不是 340°，直接求差会让大半圆弧反着画。
///
/// 两者相差 360° 的整数倍时按整圈处理：默认的 `0 → 360` 就是这种情况，照公式
/// 求余会得到 0，整环消失 —— 这是最容易漏的一处。
double ohosSweepRadians(double startAngle, double endAngle) {
  final double delta = (endAngle - startAngle) % 360;
  final double sweep = delta < 0 ? delta + 360 : delta;
  return (sweep == 0 ? 360 : sweep) * math.pi / 180;
}

/// 沿弧段方向铺色的 [Shader]。
///
/// 官方把 `LinearGradient` 画在**弧上**（从段首渐变到段尾），所以用
/// `SweepGradient` 而不是 `LinearGradient`：后者的方向是两点之间的一条直线，
/// 对一段 30° 的小弧还能蒙混过关，对整圈（起止点重合）直接退化成单色。
Shader ohosArcShader({
  required Rect rect,
  required double startRad,
  required double sweepRad,
  required List<Color> colors,
  List<double>? stops,
}) {
  return SweepGradient(
    startAngle: startRad,
    endAngle: startRad + sweepRad,
    colors: colors,
    stops: stops,
  ).createShader(rect);
}

/// 画一段有厚度的圆弧。
///
/// [radius] 是**中心线**半径（不是外沿）：`strokeWidth` 以它为中心对称展开，
/// 传入外沿半径会让整环按半个环厚向外溢出画布。
void ohosPaintArc(
  Canvas canvas, {
  required Rect rect,
  required double radius,
  required double thickness,
  required double startRad,
  required double sweepRad,
  required List<Color> colors,
  List<double>? stops,
}) {
  final Paint paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = thickness
    // 端头保持平齐：官方环的段与段之间是硬边，`round` 会让相邻段互相盖住
    // 对方 1/2 环厚，短段的实际长度肉眼可见地变长。
    ..strokeCap = StrokeCap.butt;
  if (colors.length == 1) {
    paint.color = colors.single;
  } else {
    paint.shader = ohosArcShader(
      rect: rect,
      startRad: startRad,
      sweepRad: sweepRad,
      colors: colors,
      stops: stops,
    );
  }
  canvas.drawArc(
    Rect.fromCircle(center: rect.center, radius: radius),
    startRad,
    sweepRad,
    false,
    paint,
  );
}

/// 把数值压成最短的可读形式：整数不带小数点，其余原样。
///
/// 量规图的最大最小值标签由组件自己生成（不是调用方给的字符串），所以
/// `0.0` / `0` 这类差别会直接显示在界面上 —— `0.0` 看起来像漏了格式化。
String ohosTrimNumber(double value) {
  if (!value.isFinite) {
    return '$value';
  }
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}