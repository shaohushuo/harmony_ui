import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A numeric stepper with minus/plus buttons (数字加减 in the HarmonyOS
/// guideline).
///
/// 官方 `Counter` 给「加」和「减」**两个独立开关**（`enableInc` / `enableDec`），
/// 以及**两个独立回调**（`onInc` / `onDec`）。这不是冗余设计：库存为 0 时要
/// 禁「加」而留着「减」，限购上限到了要禁「加」而「减」照常 —— 一个整体的
/// `enabled` 表达不出这对组合。
///
/// ```dart
/// OhosCounter(
///   value: qty,
///   enableInc: qty < stock,
///   enableDec: qty > minQty,
///   onChanged: (int v) => setState(() => qty = v),
/// )
/// ```
class OhosCounter extends StatelessWidget {
  const OhosCounter({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    this.enabled = true,
    this.enableInc,
    this.enableDec,
    this.onInc,
    this.onDec,
    this.buttonSize = 32,
    this.textWidth = 44,
  });

  /// Current numeric value.
  final int value;

  /// Called with the new value after either button is pressed.
  ///
  /// 两个独立回调（[onInc] / [onDec]）都是「通知」性质，改值仍由调用方在
  /// [onChanged] 里做 —— 官方 `Counter` 的 `onInc` 也只是 `VoidCallback`，
  /// 值由调用方自增。本库保留 [onChanged] 作为主通道，是因为 Flutter 侧没有
  /// 双向绑定；只订单独回调的调用方可以在里面自己判方向。
  final ValueChanged<int> onChanged;

  /// Minimum allowed value.
  final int min;

  /// Maximum allowed value.
  final int max;

  /// Increment step.
  final int step;

  /// 总开关。false 时两个按钮都禁用，等价于 `enableInc: false` +
  /// `enableDec: false`。
  ///
  /// 保留它而不是删掉：老代码里只传 `enabled` 的用法继续有效，且
  /// `enabled: false` 比同时写两个 false 更直白。
  final bool enabled;

  /// 「加」按钮是否可用（官方 `enableInc`，默认 true）。
  ///
  /// null 时跟随 [enabled]。
  final bool? enableInc;

  /// 「减」按钮是否可用（官方 `enableDec`，默认 true）。null 时跟随 [enabled]。
  final bool? enableDec;

  /// 「加」被按下后触发（官方 `onInc`）。
  final VoidCallback? onInc;

  /// 「减」被按下后触发（官方 `onDec`）。
  final VoidCallback? onDec;

  /// Diameter of the round buttons.
  final double buttonSize;

  /// 数值文本的固定宽度。官方 `textWidth` 默认「自适应文本宽度」，
  /// 但加减按钮之间没有这个宽度就会在数字位数变化时左右跳动 —— 传 0
  /// 可退回自适应。
  final double textWidth;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color fg = theme.textPrimaryColor;
    final Color disabled = theme.textTertiaryColor.withValues(alpha: 0.3);
    // 两个方向分别看「开关」与「边界」：官方语义是纯开关，越界由调用方
    // 自己维护；本库留了 min/max 兜底，越界时按不可用画，免得点出一个
    // 超出范围的值。
    final bool canMinus = (enableDec ?? enabled) && value - step >= min;
    final bool canPlus = (enableInc ?? enabled) && value + step <= max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _CounterButton(
          size: buttonSize,
          color: canMinus ? fg : disabled,
          onTap: canMinus
              ? () {
                  onDec?.call();
                  onChanged(value - step);
                }
              : null,
          icon: Icons.remove_rounded,
          semanticLabel: '减少',
        ),
        SizedBox(
          width: textWidth,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.typography.titleMedium?.copyWith(color: fg),
          ),
        ),
        _CounterButton(
          size: buttonSize,
          color: canPlus ? fg : disabled,
          onTap: canPlus
              ? () {
                  onInc?.call();
                  onChanged(value + step);
                }
              : null,
          icon: Icons.add_rounded,
          semanticLabel: '增加',
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({
    required this.size,
    required this.color,
    required this.onTap,
    required this.icon,
    required this.semanticLabel,
  });

  final double size;
  final Color color;
  final VoidCallback? onTap;
  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Material(
      color: theme.textPrimaryColor.withValues(alpha: 0.06),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Semantics(
            button: true,
            label: semanticLabel,
            child: Icon(icon, size: size * 0.5, color: color),
          ),
        ),
      ),
    );
  }
}
