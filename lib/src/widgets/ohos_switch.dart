import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

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
  });

  /// Current value of the switch.
  final bool value;

  /// Called when the user toggles the value; null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// Color of the track when active; defaults to the theme highlight color.
  final Color? activeColor;

  /// Color of the track when inactive.
  final Color? inactiveColor;

  /// Logical size of the whole switch.
  final Size size;

  @override
  State<OhosSwitch> createState() => _OhosSwitchState();
}

class _OhosSwitchState extends State<OhosSwitch> {
  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = widget.onChanged != null;
    final Color active = widget.activeColor ?? theme.highlightColor;
    final Color inactive =
        widget.inactiveColor ?? theme.textTertiaryColor.withValues(alpha: 0.3);
    final double trackWidth = widget.size.width;
    final double trackHeight = widget.size.height;
    final double thumb = trackHeight - 4;
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
            color: widget.value ? active : inactive,
            borderRadius: BorderRadius.circular(trackHeight / 2),
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
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
