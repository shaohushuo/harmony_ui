import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 分隔线的官方规格，来自参考文档 `ts-basic-components-divider.md` 的属性表。
class OhosDividerMetrics {
  const OhosDividerMetrics._();

  /// 厚度默认值：**1px（物理像素）**，不是 1vp。
  ///
  /// 文档原文「默认值：1px」，且注释里明确「如果设备硬件存在 1 像素取整后
  /// 分割线不显示问题，建议使用 2 像素」—— 说明这个单位就是设备像素。
  ///
  /// 老实现写 `thickness = 0.5`（vp）。在 3.5 密度屏上 0.5vp = 1.75px，比官方
  /// 粗；在 2 密度屏上 0.5vp = 1px 恰好对；在 1 密度屏上 0.5px 会被栅格化掉
  /// 一半 —— 同一个数值在三档密度上给出三种不同的线。按设备像素定义才与官方
  /// 一致。
  static const double thicknessPx = 1;

  /// 官方默认颜色 `#33182431`（20% 的深蓝黑）。
  ///
  /// 本库默认**不**用它，而是走 `theme.dividerColor`（10% 黑）：分隔线在这里
  /// 不是装饰而是结构层，深色主题与墨水屏都必须由 `OhosThemeData` 统一换值，
  /// 写死会让墨屏上留一条「半透明蓝」压在白底上（≤20% 黑落在第 0–3 级灰，
  /// 与白底不可分）。
  ///
  /// 需要严格对齐官方外观时显式传 `color: OhosDividerMetrics.color`。
  static const Color color = Color(0x33182431);
}

/// 分割线端点样式，对应官方 `LineCapStyle`（`divider` 的 `lineCap` 属性，
/// API 9+）。官方默认 [butt]。
enum OhosLineCap {
  /// 平切：端点在线段起止处截断，不延伸。对应 `LineCapStyle.Butt` /
  /// [StrokeCap.butt]。
  butt,

  /// 圆角：端点是半圆，向外延伸半个线宽。对应 `LineCapStyle.Round` /
  /// [StrokeCap.round]。
  round,

  /// 方切：端点是方形，向外延伸半个线宽。对应 `LineCapStyle.Square` /
  /// [StrokeCap.square]。
  square;

  /// 映射到 Flutter 绘制层的 [StrokeCap]。
  StrokeCap get strokeCap => switch (this) {
    OhosLineCap.butt => StrokeCap.butt,
    OhosLineCap.round => StrokeCap.round,
    OhosLineCap.square => StrokeCap.square,
  };
}

/// A hairline divider used to separate list items, the counterpart of
/// Flutter's [Divider].
///
/// [indent] defaults to 0, the same as Material's `Divider`, so a straight
/// replacement keeps the previous geometry. Insets that align the hairline with
/// list text are the caller's job — `OhosListTile` passes `indent: 16` (or 56
/// behind a leading icon) plus `endIndent: 16` itself, so the line stops before
/// both edges instead of running through them.
///
/// 与官方对齐的三处，另有竖线形态：
///
/// * 厚度按**设备像素**算（官方默认 1px），见 [OhosDividerMetrics.thicknessPx]；
/// * 支持竖线（官方 `vertical`，默认 `false`）；
/// * 支持端点样式 [lineCap]（官方 `lineCap`，默认平切）；
/// * [thickness] 可空 —— 不传就是官方的 1px，而不是某个 vp 字面量。
class OhosDivider extends StatelessWidget {
  const OhosDivider({
    super.key,
    this.thickness,
    this.color,
    this.indent = 0,
    this.endIndent = 0,
    this.height = 1,
    this.vertical = false,
    this.lineCap = OhosLineCap.butt,
  });

  /// 线宽（逻辑像素）。null 时按官方的 **1 个设备像素**（不是 1vp）。
  ///
  /// 传 ≤0 或非有限值会被夹回设备像素宽度 —— 官方「非法值：按默认值处理」。
  final double? thickness;

  /// Line color; defaults to the theme divider color.
  final Color? color;

  /// Leading padding before the line.
  ///
  /// 横线时是左侧缩进；竖线时是顶部缩进。
  final double indent;

  /// Trailing padding after the line.
  final double endIndent;

  /// 横线时占用总高度；竖线时占用总长度。
  final double height;

  /// 竖线形态（官方 `vertical`，默认 `false`）。
  ///
  /// 官方口径：「使用水平分割线时 strokeWidth 控制高度；使用垂直分割线时
  /// strokeWidth 控制宽度」。也就是说竖线不用单独给宽，[thickness] 就是它的
  /// 宽度；[height] 反过来成为它的长度。
  final bool vertical;

  /// 端点样式（官方 `lineCap`，默认 [OhosLineCap.butt]）。
  ///
  /// 默认平切时直接用 [ColoredBox] 画矩形，保证 1px 发丝线在各密度下精确；
  /// 圆角 / 方切需要端点延伸半个线宽，改用 [CustomPaint] 描线。
  final OhosLineCap lineCap;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 官方 1px → 1 个设备像素 → 逻辑宽度 1/dpr。不要写成 1vp：1vp 在 3.5 密度
    // 下是 3.5px，一条发丝线会变成一条粗边。
    final double px = 1 / (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1);
    final double raw = thickness ?? px;
    final double line = raw.isFinite && raw > 0 ? raw : px;
    final Color lineColor = color ?? theme.dividerColor;
    if (vertical) {
      return Padding(
        padding: EdgeInsets.only(top: indent, bottom: endIndent),
        child: SizedBox(
          width: line,
          height: height,
          child: lineCap == OhosLineCap.butt
              ? ColoredBox(color: lineColor)
              : CustomPaint(
                  painter: _OhosDividerPainter(
                    color: lineColor,
                    strokeWidth: line,
                    vertical: true,
                    cap: lineCap.strokeCap,
                  ),
                ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: SizedBox(
        height: height,
        child: Center(
          child: SizedBox(
            height: line,
            width: double.infinity,
            child: lineCap == OhosLineCap.butt
                ? ColoredBox(color: lineColor)
                : CustomPaint(
                    painter: _OhosDividerPainter(
                      color: lineColor,
                      strokeWidth: line,
                      vertical: false,
                      cap: lineCap.strokeCap,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 描线版分隔线：只有圆角 / 方切端点才需要，平切走 [ColoredBox]。
class _OhosDividerPainter extends CustomPainter {
  _OhosDividerPainter({
    required this.color,
    required this.strokeWidth,
    required this.vertical,
    required this.cap,
  });

  final Color color;
  final double strokeWidth;
  final bool vertical;
  final StrokeCap cap;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = cap
      ..style = PaintingStyle.stroke;
    if (vertical) {
      final double x = size.width / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    } else {
      final double y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_OhosDividerPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.vertical != vertical ||
      old.cap != cap;
}
