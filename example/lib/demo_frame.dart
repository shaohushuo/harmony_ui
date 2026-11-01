import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

/// 示例容器外框 / 分隔线的颜色。
///
/// 彩屏沿用画廊一直用的「10% 黑」细线；墨水屏上这条浅线会被压成两三档灰、
/// 直接化进背景 —— 真机上表现为「示例缺了左上右的边框」，所以墨主题换成
/// 分割色（纯黑），与组件内部的描边口径一致。
Color demoFrameColor(OhosThemeData theme) => theme.monochrome
    ? theme.dividerColor
    : theme.textTertiaryColor.withValues(alpha: 0.4);

/// 与 [demoFrameColor] 配套的 1px 描边：线宽取整到整数设备像素，画在盒内。
Border demoFrameBorder(BuildContext context, OhosThemeData theme) =>
    Border.all(color: demoFrameColor(theme), width: ohosStrokeWidth(context));
