import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 反白前景压在底色上，至少要这么多对比度才用它。
///
/// 2.5 是「看得清」的下限：彩屏实底品牌蓝 + 白字约 6.1:1、墨屏纸底黑字约
/// 21:1；而 10% 品牌色 tint 底上的白字只有约 **1.2:1** —— 那一档必须退到品牌
/// 色字。取 2.5 而不是 WCAG 的 3：官方彩屏蓝底白字本身就站在 2.8 附近，抬到
/// 3 会把官方的观感一起改掉。
const double ohosReadableContrast = 2.5;

/// WCAG 对比度：`(L1 + .05) / (L2 + .05)`，L 为相对亮度。
double ohosContrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [onFill] 压在 [fill] 上读不读得清。
///
/// [fill] 允许半透明：先合成到 [backdrop] 再算。`computeLuminance()` 只看
/// RGB、不看 alpha，不合成的话判的是「这块色如果实心」的亮度 —— 半透明黑会
/// 被当成纯黑，而屏幕上画出来几乎是一张白纸。
///
/// 判据是**实际渲染出的底色**，不是「底是不是透明」这种分支特征：同一份规则
/// 才能同时兜住「10% tint 底配白字」和「调用方传实心底却退回品牌色字」两种反
/// 向失效。
bool ohosOnFillReadable(
  Color onFill,
  Color fill, {
  required Color backdrop,
  double minContrast = ohosReadableContrast,
}) {
  final Color composed = Color.alphaBlend(fill, backdrop);
  return ohosContrastRatio(onFill, composed) >= minContrast;
}
