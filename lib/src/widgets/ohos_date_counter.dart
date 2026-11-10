import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';

/// A calendar date, mirroring ArkUI's `DateData` (`advanced.Counter`).
///
/// Deliberately **not** a `DateTime`: the official date counter is not a point in
/// time, it is three independent numbers that wrap in three different ways —
/// the year clamps to `[1, 5000]`, the month wraps around 12 **without**
/// carrying into the year, and the day wraps around the current month's length.
/// `DateTime` would silently carry `2024-01-31 + 1 month` to `2024-03-02`,
/// which is not what the component does.
@immutable
class OhosDate {
  const OhosDate({required this.year, required this.month, required this.day});

  /// Drops the time part of [value].
  OhosDate.fromDateTime(DateTime value)
    : year = value.year,
      month = value.month,
      day = value.day;

  final int year;
  final int month;
  final int day;

  /// `COUNTER_MIN_YEAR` / `COUNTER_MAX_YEAR` in `counter.ets`.
  static const int minYear = 1;
  static const int maxYear = 5000;

  static const int minMonth = 1;
  static const int maxMonth = 12;
  static const int minDay = 1;

  /// Gregorian leap rule, as written in `getDayNumber()`:
  /// `(year % 4 == 0 && year % 100 != 0) || year % 400 == 0`.
  bool get isLeapYear => (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  /// Days in [month] of [year]; 29 in a leap February.
  int get daysInMonth {
    switch (month) {
      case 2:
        return isLeapYear ? 29 : 28;
      case 4:
      case 6:
      case 9:
      case 11:
        return 30;
      case 1:
      case 3:
      case 5:
      case 7:
      case 8:
      case 10:
      case 12:
        return 31;
      default:
        // `getDayNumber()` falls through to `SMALL_MONTH_DAYS` for a month that
        // is not in the table. Only reachable if someone constructs an
        // out-of-range OhosDate by hand.
        return 30;
    }
  }

  /// Year is **clamped**, not wrapped — the buttons go dead at 1 and 5000.
  OhosDate addYears(int delta) => _clampedDay(
    OhosDate(
      year: (year + delta).clamp(minYear, maxYear),
      month: month,
      day: day,
    ),
  );

  /// Month **wraps** and never carries into the year.
  ///
  /// `counter.ets` does `month += step % 12; if (month > 12) month -= 12;` — the
  /// year is untouched. Real modulo is used here so a step larger than a year
  /// still lands somewhere sensible instead of crawling. Dart's `%` on ints is
  /// always non-negative for a positive divisor, so no sign fix-up is needed.
  OhosDate addMonths(int delta) => _clampedDay(
    OhosDate(year: year, month: (month - 1 + delta) % 12 + 1, day: day),
  );

  /// Day **wraps** around the current month's length — `2024-02-29 + 1 day` is
  /// `2024-02-01`, not March.
  OhosDate addDays(int delta) {
    final int days = daysInMonth;
    return OhosDate(
      year: year,
      month: month,
      day: (day - 1 + delta) % days + 1,
    );
  }

  OhosDate copyWith({int? year, int? month, int? day}) => _clampedDay(
    OhosDate(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
    ),
  );

  /// Pulls [day] back to the last day of the month if the month got shorter.
  ///
  /// This is `updateDay()` in `counter.ets`, called after every month / year
  /// change: going from 2024-01-31 to February must land on the 29th, not on an
  /// invalid "February 31st".
  OhosDate _clampedDay(OhosDate date) {
    final int year = date.year.clamp(minYear, maxYear);
    final int month = date.month.clamp(minMonth, maxMonth);
    final OhosDate probe = OhosDate(year: year, month: month, day: 1);
    final int day = date.day.clamp(minDay, probe.daysInMonth);
    return OhosDate(year: year, month: month, day: day);
  }

  DateTime toDateTime() => DateTime(year, month, day);

  /// `YYYY-MM-DD`, the same shape as `DateData.toString()`.
  @override
  String toString() {
    final String m = month < 10 ? '0$month' : '$month';
    final String d = day < 10 ? '0$day' : '$day';
    return '$year-$m-$d';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OhosDate &&
          other.year == year &&
          other.month == month &&
          other.day == day);

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Which of the three numbers the stepper buttons act on.
///
/// ArkUI decides this by which `TextInput` currently holds focus (`FocusText` in
/// `counter.ets`), falling back to the day when nothing is focused. Here the
/// same rule is used: [OhosDateCounter] reads the focused segment, and treats
/// "nothing focused" as [day].
enum OhosDateCounterField { year, month, day }

/// A date stepper: `YYYY / MM / DD` with an up/down pair (`CounterType.INLINE_DATE`
/// in the HarmonyOS guideline).
///
/// Geometry is taken from `counter.ets` rather than from the reference doc —
/// the doc only says the container is "32vp", the rest is in the source:
///
/// - container **32** high, radius **8** (`COUNTER_INLINE_RADIUS`), 1vp border
///   (`COUNTER_BORDER_WIDTH` → `sys.float.border_width` = 1vp);
/// - date group **92** wide (year 38 + `/` 8 + month 19 + `/` 8 + day 19) with
///   **12** on both sides (`COUNTER_INLINE_DATE_TEXT_MARGIN`);
/// - each segment input is **20** high; the `/` separators are **8** wide;
/// - the button column is **32** wide and 32 tall, split into two **32×16**
///   halves separated by a 1vp rule, and a 1vp rule separates it from the text.
///
/// Two deviations from the official component, both documented in
/// `CHANGELOG.md`:
///
/// 1. **Every change calls [onChanged]**, including button presses. ArkUI only
///    invokes `onDateChange` from the three `TextInput.onChange` handlers, so a
///    button press updates the number on screen and never tells the app — the
///    component is effectively write-only. Copying that would make this widget
///    impossible to drive from a Flutter `setState`.
/// 2. **No 1500 ms revert timer.** Official starts a timer per segment so a
///    half-typed year snaps back after 1.5 s. Here an incomplete value simply
///    stays until the field loses focus, then snaps back — same end state, no
///    pending timers to leak when the widget is disposed mid-edit.
class OhosDateCounter extends StatefulWidget {
  const OhosDateCounter({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.enabled = true,
    this.upIcon = Icons.keyboard_arrow_up_rounded,
    this.downIcon = Icons.keyboard_arrow_down_rounded,
  });

  /// The date currently shown.
  final OhosDate value;

  /// Called with the new date on every change.
  final ValueChanged<OhosDate> onChanged;

  /// How far one press moves. Clamped to `>= 1` like `CommonOptions.step`.
  ///
  /// The year moves by this many years; month and day **wrap** by it, so a step
  /// of 1 on the 31st of January gives the 1st of February.
  final int step;

  /// When false both buttons are inert and the segments do not accept input.
  final bool enabled;

  /// Glyph of the increase button.
  ///
  /// Defaults to a rounded chevron because `lib/` deliberately does not depend
  /// on an icon package. The official glyph is `ohos_ic_public_arrow_up` at
  /// 24×12; pass it from `harmony_icons` for exact parity.
  final IconData upIcon;

  /// Glyph of the decrease button, see [upIcon].
  final IconData downIcon;

  // ---- Geometry, straight from `counter.ets`. ----

  static const double _containerHeight = 32; // COUNTER_INLINE_CONTAINER_HEIGHT
  static const double _containerRadius = 8; // COUNTER_INLINE_RADIUS
  static const double _dateGroupWidth = 92; // 38 + 8 + 19 + 8 + 19
  static const double _dateGroupMargin = 12; // COUNTER_INLINE_DATE_TEXT_MARGIN
  static const double _segmentHeight = 20;
  static const double _yearWidth = 38;

  // Month and day are both 19 wide; the reference shows them as equal.
  static const double _smallSegmentWidth = 19;
  static const double _separatorWidth = 8;
  static const double _buttonColumnWidth = 32; // COUNTER_INLINE_BUTTON_WIDTH
  // COUNTER_INLINE_BUTTON_HEIGHT is 16 in `counter.ets`, and two of those plus
  // a 1vp rule is 33 — one more than the 32vp container. That works in ArkUI
  // because its border sits outside the content box; here the halves come from
  // `Expanded` instead (see `_arrow`).
  static const double _iconSize = 12; // COUNTER_INLINE_BUTTON_ICON_HEIGHT
  static const double _disabledOpacity = 0.4; // COUNTER_BUTTON_DISABLE_OPACITY
  static const double _fontSize = 16; // ohos_id_text_size_body1

  @override
  State<OhosDateCounter> createState() => _OhosDateCounterState();
}

class _OhosDateCounterState extends State<OhosDateCounter> {
  late final TextEditingController _year;
  late final TextEditingController _month;
  late final TextEditingController _day;
  late final FocusNode _yearFocus;
  late final FocusNode _monthFocus;
  late final FocusNode _dayFocus;

  /// The segment the user last put the caret in.
  ///
  /// Needed because tapping an arrow blurs the field first (`onTapOutside`), so
  /// by the time the arrow's `onTap` runs **no** segment has focus — reading
  /// focus alone would silently fall back to the day and the year/month arrows
  /// would move the wrong number. ArkUI has no such race: its arrows are driven
  /// by the keyboard, which keeps focus.
  OhosDateCounterField _lastField = OhosDateCounterField.day;

  @override
  void initState() {
    super.initState();
    _year = TextEditingController(text: _padYear(widget.value.year));
    _month = TextEditingController(text: _pad2(widget.value.month));
    _day = TextEditingController(text: _pad2(widget.value.day));
    _yearFocus = FocusNode()..addListener(() => _onFocusChanged(_yearFocus));
    _monthFocus = FocusNode()..addListener(() => _onFocusChanged(_monthFocus));
    _dayFocus = FocusNode()..addListener(() => _onFocusChanged(_dayFocus));
  }

  @override
  void didUpdateWidget(covariant OhosDateCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync when the value really changed. Reassigning unconditionally
    // would wipe a half-typed segment every time the parent rebuilds for an
    // unrelated reason.
    if (oldWidget.value != widget.value) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _year.dispose();
    _month.dispose();
    _day.dispose();
    _yearFocus.dispose();
    _monthFocus.dispose();
    _dayFocus.dispose();
    super.dispose();
  }

  void _onFocusChanged(FocusNode node) {
    if (node.hasFocus) {
      // Remember which generated field the caret is in — survives the blur that
      // precedes an arrow tap. See [_lastField].
      if (identical(node, _yearFocus)) {
        _lastField = OhosDateCounterField.year;
      } else if (identical(node, _monthFocus)) {
        _lastField = OhosDateCounterField.month;
      } else {
        _lastField = OhosDateCounterField.day;
      }
    } else {
      // Snap an incomplete segment back when it loses focus. Done here rather
      // than on every keystroke so typing "2" then "0" is not interrupted.
      if (identical(node, _yearFocus)) {
        _year.text = _padYear(widget.value.year);
      } else if (identical(node, _monthFocus)) {
        _month.text = _pad2(widget.value.month);
      } else {
        _day.text = _pad2(widget.value.day);
      }
    }
    // The focused block's fill is state, so a plain rebuild is enough.
    if (mounted) setState(() {});
  }

  static String _pad2(int v) => v.toString().padLeft(2, '0');

  static String _padYear(int v) => v.toString().padLeft(4, '0');

  void _syncControllers() {
    _year.text = _padYear(widget.value.year);
    _month.text = _pad2(widget.value.month);
    _day.text = _pad2(widget.value.day);
  }

  /// The segment the buttons act on.
  ///
  /// Uses the last focused segment ([_lastField]) rather than live focus,
  /// because an arrow tap blurs the field before the tap lands. ArkUI falls
  /// back to the day when nothing is focused (`focusDayWithAdd` /
  /// `focusDayWitdhSub`); [_lastField] starts as [OhosDateCounterField.day] so
  /// a never-touched counter behaves the same.
  OhosDateCounterField get _target => _lastField;

  int get _step => widget.step < 1 ? 1 : widget.step;

  bool get _canIncrease =>
      widget.enabled &&
      !(_target == OhosDateCounterField.year &&
          widget.value.year >= OhosDate.maxYear);

  bool get _canDecrease =>
      widget.enabled &&
      !(_target == OhosDateCounterField.year &&
          widget.value.year <= OhosDate.minYear);

  void _emit(OhosDate next) {
    if (next == widget.value) return;
    // Repaint the segments before the parent rebuilds so the user never sees a
    // frame of stale text; `didUpdateWidget` will do it again, harmlessly.
    _year.text = _padYear(next.year);
    _month.text = _pad2(next.month);
    _day.text = _pad2(next.day);
    widget.onChanged(next);
  }

  void _stepBy(int direction) {
    final int delta = direction * _step;
    final OhosDate current = widget.value;
    switch (_target) {
      case OhosDateCounterField.year:
        _emit(current.addYears(delta));
      case OhosDateCounterField.month:
        _emit(current.addMonths(delta));
      case OhosDateCounterField.day:
        _emit(current.addDays(delta));
    }
  }

  /// Year commits only at 4 digits, matching `value.length === 4`.
  void _onYearInput(String raw) {
    if (raw.length != 4) return;
    final int? year = int.tryParse(raw);
    if (year == null || year < OhosDate.minYear || year > OhosDate.maxYear) {
      _year.text = _padYear(widget.value.year);
      return;
    }
    _emit(widget.value.copyWith(year: year));
  }

  void _onMonthInput(String raw) {
    if (raw.length != 2) return;
    final int? month = int.tryParse(raw);
    if (month == null ||
        month < OhosDate.minMonth ||
        month > OhosDate.maxMonth) {
      _month.text = _pad2(widget.value.month);
      return;
    }
    _emit(widget.value.copyWith(month: month));
  }

  void _onDayInput(String raw) {
    if (raw.length != 2) return;
    final int? day = int.tryParse(raw);
    if (day == null ||
        day < OhosDate.minDay ||
        day > widget.value.daysInMonth) {
      _day.text = _pad2(widget.value.day);
      return;
    }
    _emit(widget.value.copyWith(day: day));
  }

  /// An incomplete or invalid segment snaps back when it loses focus — see
  /// [_onFocusChanged]. That is where the official 1500 ms timer lands here.

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color line = theme.outlineColor;
    final double stroke = ohosStrokeWidth(context, 1);

    final BorderSide side = BorderSide(color: line, width: stroke);
    final TextStyle style = TextStyle(
      fontSize: OhosDateCounter._fontSize,
      fontWeight: FontWeight.w500, // official: FontWeight.Medium
      color: theme.textPrimaryColor,
      height: 1,
    );

    return Opacity(
      opacity: widget.enabled ? 1 : OhosDateCounter._disabledOpacity,
      child: Container(
        height: OhosDateCounter._containerHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(OhosDateCounter._containerRadius),
          border: Border.fromBorderSide(side),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OhosDateCounter._dateGroupMargin,
              ),
              child: SizedBox(
                width: OhosDateCounter._dateGroupWidth,
                child: Row(
                  children: <Widget>[
                    _segment(
                      theme: theme,
                      controller: _year,
                      focus: _yearFocus,
                      width: OhosDateCounter._yearWidth,
                      maxLength: 4,
                      hint: 'YYYY',
                      style: style,
                      onChanged: _onYearInput,
                    ),
                    _divider(theme, style),
                    _segment(
                      theme: theme,
                      controller: _month,
                      focus: _monthFocus,
                      width: OhosDateCounter._smallSegmentWidth,
                      maxLength: 2,
                      hint: 'MM',
                      style: style,
                      onChanged: _onMonthInput,
                    ),
                    _divider(theme, style),
                    _segment(
                      theme: theme,
                      controller: _day,
                      focus: _dayFocus,
                      width: OhosDateCounter._smallSegmentWidth,
                      maxLength: 2,
                      hint: 'DD',
                      style: style,
                      onChanged: _onDayInput,
                    ),
                  ],
                ),
              ),
            ),
            // 1vp rule between the text group and the arrows.
            Container(
              width: stroke,
              height: OhosDateCounter._containerHeight,
              color: line,
            ),
            SizedBox(
              width: OhosDateCounter._buttonColumnWidth,
              height: OhosDateCounter._containerHeight,
              child: Column(
                children: <Widget>[
                  // `Expanded` rather than the official 32×16 halves: the 1vp
                  // border is drawn *inside* the 32vp box (see `ohosBorderSide`
                  // — `strokeAlignInside`), so the content area is 30vp, not 32.
                  // Hard-coding 16+1+16 would overflow by 2vp. ArkUI's
                  // container border does not shrink its children, which is why
                  // `counter.ets` can write 16 and get away with it.
                  Expanded(
                    child: _arrow(
                      theme: theme,
                      icon: widget.upIcon,
                      line: line,
                      stroke: stroke,
                      enabled: _canIncrease,
                      onTap: () => _stepBy(1),
                      border: Border(
                        bottom: BorderSide(color: line, width: stroke),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _arrow(
                      theme: theme,
                      icon: widget.downIcon,
                      line: line,
                      stroke: stroke,
                      enabled: _canDecrease,
                      onTap: () => _stepBy(-1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(OhosThemeData theme, TextStyle style) {
    return SizedBox(
      width: OhosDateCounter._separatorWidth,
      child: Text(
        '/',
        textAlign: TextAlign.center,
        style: style.copyWith(color: theme.textPrimaryColor),
      ),
    );
  }

  Widget _segment({
    required OhosThemeData theme,
    required TextEditingController controller,
    required FocusNode focus,
    required double width,
    required int maxLength,
    required String hint,
    required TextStyle style,
    required ValueChanged<String> onChanged,
  }) {
    // The focused segment is filled with the highlight color and its text turns
    // to `onHighlightColor` — that is the official `hasFocusText*` treatment
    // (`BUTTON_BORDER_FOCUSED_COLOR` background, `Color.White` text). It needs
    // no policy branch: on a colour screen it is brand blue on white, on an
    // e-ink screen `highlightColor` is pure black so it becomes a black block
    // with paper-white text, which is exactly the "inverse" mark that screen
    // needs.
    final bool focused = focus.hasFocus;
    final Color fg = focused ? theme.onHighlightColor : theme.textPrimaryColor;

    return Container(
      width: width,
      height: OhosDateCounter._segmentHeight,
      color: focused ? theme.highlightColor : null,
      child: TextField(
        controller: controller,
        focusNode: focus,
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        style: style.copyWith(color: fg),
        cursorColor: fg,
        cursorHeight: OhosDateCounter._fontSize,
        // Lock the line box to the font size: 16fp with the default 1.4 line
        // height would overflow the 20vp segment.
        strutStyle: const StrutStyle(
          fontSize: OhosDateCounter._fontSize,
          height: 1,
          forceStrutHeight: true,
        ),
        decoration: InputDecoration(
          isDense: true,
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: style.copyWith(color: theme.textTertiaryColor),
          contentPadding: EdgeInsets.zero,
          counterText: '',
        ),
        onChanged: onChanged,
        onTapOutside: (_) => focus.unfocus(),
        onEditingComplete: focus.unfocus,
      ),
    );
  }

  /// One half of the arrow column.
  ///
  /// Height comes from the parent [Expanded], not from a constant: the official
  /// 32×16 halves assume a container border that does not eat into the content
  /// box, while Flutter's inside-stroke border does (32 − 2 = 30).
  Widget _arrow({
    required OhosThemeData theme,
    required IconData icon,
    required Color line,
    required double stroke,
    required bool enabled,
    required VoidCallback onTap,
    Border? border,
  }) {
    return Container(
      width: OhosDateCounter._buttonColumnWidth,
      decoration: BoxDecoration(border: border),
      child: OhosPressFeedback(
        onTap: enabled ? onTap : null,
        child: Center(
          child: Icon(
            icon,
            size: OhosDateCounter._iconSize,
            color: enabled
                ? theme.textPrimaryColor
                : theme.textPrimaryColor.withValues(
                    alpha: OhosDateCounter._disabledOpacity,
                  ),
          ),
        ),
      ),
    );
  }
}
