import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A numeric stepper with minus/plus buttons (数字加减 in the HarmonyOS
/// guideline).
class OhosCounter extends StatelessWidget {
  const OhosCounter({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    this.enabled = true,
    this.buttonSize = 32,
  });

  /// Current numeric value.
  final int value;

  /// Called with the new value.
  final ValueChanged<int> onChanged;

  /// Minimum allowed value.
  final int min;

  /// Maximum allowed value.
  final int max;

  /// Increment step.
  final int step;

  /// When false the counter is disabled.
  final bool enabled;

  /// Diameter of the round buttons.
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color fg = theme.textPrimaryColor;
    final Color disabled = theme.textTertiaryColor.withValues(alpha: 0.3);
    final bool canMinus = enabled && value - step >= min;
    final bool canPlus = enabled && value + step <= max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _CounterButton(
          size: buttonSize,
          color: canMinus ? fg : disabled,
          onTap: canMinus ? () => onChanged(value - step) : null,
          icon: Icons.remove_rounded,
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.typography.titleMedium?.copyWith(color: fg),
          ),
        ),
        _CounterButton(
          size: buttonSize,
          color: canPlus ? fg : disabled,
          onTap: canPlus ? () => onChanged(value + step) : null,
          icon: Icons.add_rounded,
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
  });

  final double size;
  final Color color;
  final VoidCallback? onTap;
  final IconData icon;

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
          child: Icon(icon, size: size * 0.5, color: color),
        ),
      ),
    );
  }
}
