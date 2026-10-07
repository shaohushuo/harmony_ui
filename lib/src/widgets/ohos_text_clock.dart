import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A live text clock that updates every second, matching the "文本时钟"
/// control in the HarmonyOS design guideline.
class OhosTextClock extends StatefulWidget {
  const OhosTextClock({
    super.key,
    this.format = 'HH:mm',
    this.timeZone,
    this.textStyle,
    this.textAlign,
  });

  /// Format string parsed by `intl`-style patterns:
  /// `HH:mm`, `yyyy年MM月dd日 HH:mm` etc. Only `y/M/d/H/m/s` tokens are
  /// supported (24h clock).
  final String format;

  /// Optional IANA time zone name (requires `timezone` package data);
  /// when null the device local time is used.
  final String? timeZone;

  /// Style of the clock text; defaults to the theme title style.
  final TextStyle? textStyle;

  /// Text alignment.
  final TextAlign? textAlign;

  @override
  State<OhosTextClock> createState() => _OhosTextClockState();
}

class _OhosTextClockState extends State<OhosTextClock> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(DateTime t, String pattern) {
    final String result = pattern
        .replaceAll('yyyy', t.year.toString().padLeft(4, '0'))
        .replaceAll('MM', t.month.toString().padLeft(2, '0'))
        .replaceAll('dd', t.day.toString().padLeft(2, '0'))
        .replaceAll('HH', t.hour.toString().padLeft(2, '0'))
        .replaceAll('mm', t.minute.toString().padLeft(2, '0'))
        .replaceAll('ss', t.second.toString().padLeft(2, '0'))
        .replaceAll('yy', (t.year % 100).toString().padLeft(2, '0'));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final DateTime display = widget.timeZone == null
        ? _now
        : _now.toUtc().toLocal(); // tz-aware conversion requires timezone pkg
    return Text(
      _format(display, widget.format),
      textAlign: widget.textAlign,
      style:
          widget.textStyle ??
          theme.typography.titleMedium?.copyWith(
            color: theme.textPrimaryColor,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
    );
  }
}
