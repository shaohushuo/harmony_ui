import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_button.dart';
import 'ohos_press_feedback.dart';

/// Option model of [showOhosPicker].
class OhosPickerItem<T> {
  const OhosPickerItem({
    required this.label,
    required this.value,
    this.subtitle,
  });

  /// Display label.
  final String label;

  /// Value returned when selected.
  final T value;

  /// Optional secondary line.
  final String? subtitle;
}

/// 选中项指示器的画法，对应官方 `PickerIndicatorType`。
enum OhosPickerIndicator {
  /// 给选中项铺一块圆角底（`PickerIndicatorType.BACKGROUND` = 0，**默认**）。
  background,

  /// 在选中项上下各画一条线（`PickerIndicatorType.DIVIDER` = 1）。
  divider,
}

/// 一列滚轮。
///
/// 官方 `UIPickerComponent` 的子组件本身就是选项（`Text` / `Image` / `Row`），
/// 多列靠横向并排多个容器实现 —— 所以「列」不是组件能力，而是布局结果。本库
/// 把这条结构显式化：[OhosPickerColumn] 一列一个实例，多列由调用方横向排列。
class OhosPickerColumn {
  const OhosPickerColumn({
    required this.labels,
    this.initialIndex = 0,
    this.loop,
    this.flex = 1,
  });

  /// 选项文本，顺序即滚轮顺序。
  final List<String> labels;

  /// 初始选中下标，越界时夹回 `[0, labels.length - 1]`。
  final int initialIndex;

  /// 是否循环，null 表示跟 [OhosWheelPicker.loop]。
  ///
  /// 官方 `canLoop` **默认 true**，但有一条硬条件：「如果子组件的个数小于8个，
  /// 无论 `isLoop` 设置为 true 还是 false，都不会循环滚动」。见
  /// [OhosWheelPicker.effectiveLoop]。
  final bool? loop;

  /// 横向伸缩比。多列宽度不等时（如「年/月/日」应是 2:1:1）用这个分配。
  final int flex;
}

/// 立体滚轮选择器（官方 `UIPickerComponent`）。
///
/// ## 官方几何（文档「说明」章节的明文数字）
///
/// - 选项行高**固定 40vp**，最多显示 **7** 个；
/// - 容器**建议高度 200vp**（= 5 × 40），大于等于它时可完整显示 7 项，小于
///   则从上下边缘向中间裁剪，选中项**始终垂直居中**；
/// - 所有文本默认 **20fp**，且子组件的 `height` 不生效（含 `Row` 内的子组件
///   可以生效，但 `Row` 整体仍固定 40）；
/// - 子组件对齐方式**固定居中**，`align` 属性不生效。
///
/// 7 × 40 = 280 > 200 —— 这看起来矛盾，但文档说的是「实际可视高度会小于
/// 40vp」：立体滚轮上非选中项按角度旋转，投影到 2D 后变薄。本库不模拟 3D
/// 旋转（Flutter 侧做透视要用 `Transform` 逐项矩阵，与滚动物理耦合，收益远
/// 小于复杂度），所以**按 5 行 200vp 落地**，把「最多 7 项」表达为
/// [OhosWheelPicker.visibleCount] 的可调参数。
///
/// ## 指示器
///
/// 默认 `{type: BACKGROUND, borderRadius: 12, backgroundColor:
/// 'sys.color.comp_background_tertiary'}`；`DIVIDER` 档的 `strokeWidth` 默认
/// **2.0px**、取值范围 `[0, 20]`（选中项高度的一半），越界回默认。
class OhosWheelPicker extends StatefulWidget {
  const OhosWheelPicker({
    super.key,
    required this.columns,
    this.initialIndexes,
    this.onChanged,
    this.onScrollStop,
    this.loop = true,
    this.height = 200,
    this.visibleCount = 5,
    this.indicator = OhosPickerIndicator.background,
    this.dividerColor,
    this.backgroundColor,
    this.enabled = true,
  });

  /// 各列数据。
  final List<OhosPickerColumn> columns;

  /// 各列初始下标；给了 [OhosPickerColumn.initialIndex] 时以列上的为准。
  final List<int>? initialIndexes;

  /// 任一行选中项变化时回调，参数是（列下标，行下标）。
  ///
  /// 对应官方 `onChange(selectedIndex)` —— 但它只有一列，所以只给一个下标；
  /// 多列时官方是「每列一个 `UIPickerComponent`，各自回调」，本库合成一个
  /// 回调，免去调用方自己按列拼装。
  final void Function(int column, int index)? onChanged;

  /// 滑动停止时回调（官方 `onScrollStop`）。
  ///
  /// 与 [onChanged] 的区别是**粒度**：滑动过程中每越过一项 `onChanged` 就
  /// 触发一次，`onScrollStop` 只在动画完全结束时触发一次。官方专门写了
  /// 「如果某次滑动动画还未结束时又触发了新的滑动动画，则不属于滑动停止」
  /// —— 所以这里必须等真实的滚动结束，不能用定时器近似。
  final void Function(int column, int index)? onScrollStop;

  /// 默认是否循环。见 [OhosPickerColumn.loop] 与 [effectiveLoop]。
  final bool loop;

  /// 总高度，默认官方建议的 200。
  final double height;

  /// 同时显示的项数，默认 5（200 / 40）。
  final int visibleCount;

  /// 指示器形态。
  final OhosPickerIndicator indicator;

  /// `DIVIDER` 档的线色。
  final Color? dividerColor;

  /// `BACKGROUND` 档的底色。
  final Color? backgroundColor;

  /// 为 false 时整条不可滚（仍可看清当前值）。
  final bool enabled;

  /// 行高，官方固定 40vp。
  static const double itemExtent = 40;

  /// 某一列实际是否循环。
  ///
  /// 官方硬条件：**少于 8 个子组件时不循环**，即使 `canLoop` 为 true。照抄
  /// 这条的理由不是「实现容易」：8 项以内一屏（5 项）就能看全大半，循环反而
  /// 让人分不清首尾 —— 官方把它做成无条件行为，本库也一样，不提供覆盖开关。
  bool loopOf(int column) {
    final OhosPickerColumn c = columns[column];
    return (c.loop ?? loop) && c.labels.length >= 8;
  }

  /// 某列的初始下标（已夹到合法范围）。
  int initialIndexOf(int column) {
    final OhosPickerColumn c = columns[column];
    final int requested =
        initialIndexes != null && column < initialIndexes!.length
        ? initialIndexes![column]
        : c.initialIndex;
    if (c.labels.isEmpty) {
      return 0;
    }
    return requested.clamp(0, c.labels.length - 1);
  }

  @override
  State<OhosWheelPicker> createState() => OhosWheelPickerState();
}

/// [OhosWheelPicker] 的状态，暴露当前下标。
class OhosWheelPickerState extends State<OhosWheelPicker> {
  late List<FixedExtentScrollController> _controllers;
  late List<int> _indexes;

  /// 当前各列下标。
  List<int> get indexes => List<int>.unmodifiable(_indexes);

  @override
  void initState() {
    super.initState();
    _rebuildControllers();
  }

  @override
  void didUpdateWidget(covariant OhosWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columns.length != widget.columns.length) {
      _disposeControllers();
      _rebuildControllers();
      return;
    }
    for (int i = 0; i < widget.columns.length; i++) {
      // 列内的选项变了就得重建：`FixedExtentScrollController` 的下标是绝对的，
      // 列表变短后停在越界位置会抛。只在长度变化时重建，普通 setState 重建
      // 控制器会把用户正在滚的位置弹回去。
      if (oldWidget.columns[i].labels.length !=
          widget.columns[i].labels.length) {
        _controllers[i].dispose();
        _controllers[i] = FixedExtentScrollController(
          initialItem: widget.initialIndexOf(i),
        );
        _indexes[i] = widget.initialIndexOf(i);
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _rebuildControllers() {
    _controllers = <FixedExtentScrollController>[
      for (int i = 0; i < widget.columns.length; i++)
        FixedExtentScrollController(initialItem: widget.initialIndexOf(i)),
    ];
    _indexes = <int>[
      for (int i = 0; i < widget.columns.length; i++) widget.initialIndexOf(i),
    ];
  }

  void _disposeControllers() {
    for (final FixedExtentScrollController c in _controllers) {
      c.dispose();
    }
  }

  /// 滚到指定项（带动画）。
  void animateTo(int column, int index) {
    if (column < 0 || column >= _controllers.length) {
      return;
    }
    final int max = widget.columns[column].labels.length - 1;
    _controllers[column].animateToItem(
      index.clamp(0, max < 0 ? 0 : max),
      duration: OhosGeometry.durationMedium,
      curve: OhosGeometry.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final double extent = OhosWheelPicker.itemExtent;
    // 视口高度取「显示项数 × 行高」，与容器高度取小 —— 容器矮于视口时
    // 官方是「从上下边缘向中间裁剪」，靠 `ClipRect` 实现，选中项仍居中。
    final double viewport = math.min(
      widget.height,
      extent * widget.visibleCount,
    );

    return SizedBox(
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // 指示器画在最底层：`DIVIDER` 档的两条线必须穿过所有列，而不是每列
          // 各画一份（那样列与列之间线会断开）。
          Positioned.fill(
            child: _Indicator(config: widget, theme: theme),
          ),
          ClipRect(
            child: SizedBox(
              height: viewport,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < widget.columns.length; i++)
                    Expanded(
                      flex: widget.columns[i].flex,
                      child: _buildColumn(context, theme, i, extent),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(
    BuildContext context,
    OhosThemeData theme,
    int column,
    double extent,
  ) {
    final OhosPickerColumn data = widget.columns[column];
    final bool loops = widget.loopOf(column);
    // 循环时把列表按 3 份复制，落点取中间那份，形成「首尾可接」的观感。
    // 官方 `canLoop` 是真正的无限循环；3 份在滚动到边界时会露头，但比一份
    // 完全不循环更接近，且不会把 `ListView` 变成无限滚动的虚拟列表（那会让
    // `onSelectedItemChanged` 的下标失去意义）。
    const int copies = 3;
    final List<String> labels = loops
        ? <String>[for (int k = 0; k < copies; k++) ...data.labels]
        : data.labels;
    final int base = loops ? data.labels.length : 0;

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification n) {
        if (n is ScrollEndNotification) {
          _report(column, _indexes[column], scrollStop: true);
        }
        return false;
      },
      child: ListWheelScrollView.useDelegate(
        controller: _controllers[column],
        itemExtent: extent,
        perspective: 0.003,
        diameterRatio: 1.6,
        squeeze: 1,
        overAndUnderCenterOpacity: 1,
        physics: widget.enabled
            ? const FixedExtentScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        onSelectedItemChanged: (int raw) {
          final int index = raw % base.clamp(1, 1 << 30);
          if (_indexes[column] != index) {
            _indexes[column] = index;
            _report(column, index, scrollStop: false);
          }
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: labels.length,
          builder: (BuildContext context, int raw) {
            final int index = labels.isEmpty
                ? 0
                : raw % (loops ? base : labels.length);
            return _WheelRow(
              label: labels[raw],
              // 选中项加重：官方没给字重差异（只说默认 20fp），但 3D 滚轮的
              // 选中项本来就被拉正、其余被压缩 —— 不模拟透视时字重是唯一
              // 的「当前项」线索。
              selected: loops
                  ? _indexes[column] == index
                  : _indexes[column] == raw,
              enabled: widget.enabled,
              theme: theme,
            );
          },
        ),
      ),
    );
  }

  void _report(int column, int index, {required bool scrollStop}) {
    if (scrollStop) {
      widget.onScrollStop?.call(column, index);
    } else {
      widget.onChanged?.call(column, index);
    }
  }
}

/// 滚轮里的一行：固定 40 高、居中、单行截断。
class _WheelRow extends StatelessWidget {
  const _WheelRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.theme,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          // 官方：所有文本默认 20fp。
          fontSize: 20,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          color: enabled
              ? (selected ? theme.textPrimaryColor : theme.textSecondaryColor)
              : theme.textTertiaryColor,
        ),
      ),
    );
  }
}

/// 选中项指示器。
class _Indicator extends StatelessWidget {
  const _Indicator({required this.config, required this.theme});

  final OhosWheelPicker config;
  final OhosThemeData theme;

  @override
  Widget build(BuildContext context) {
    // 指示器的高度恒等于一行（40），与视口无关：`DIVIDER` 档两条线的高度差
    // 就是选中项高度，`BACKGROUND` 档的底也是这一块。
    const double rowHeight = OhosWheelPicker.itemExtent;

    switch (config.indicator) {
      case OhosPickerIndicator.background:
        return Center(
          child: SizedBox(
            height: rowHeight,
            width: double.infinity,
            child: DecoratedBox(
              key: const ValueKey<String>('picker-indicator'),
              decoration: BoxDecoration(
                // 官方默认 `sys.color.comp_background_tertiary`；墨屏上该层
                // 灰会被策略判成透明，改画线（见 divider 分支的说明）。
                color: theme.usesOutlines
                    ? Colors.transparent
                    : (config.backgroundColor ??
                          theme.policy.tint(theme.textPrimaryColor, 0.05)),
                borderRadius: BorderRadius.circular(12),
                border: theme.usesOutlines
                    ? Border.all(
                        color: theme.dividerColor,
                        width: ohosStrokeWidth(context, 1),
                      )
                    : null,
              ),
            ),
          ),
        );
      case OhosPickerIndicator.divider:
        final Color line = config.dividerColor ?? theme.dividerColor;
        // 官方 `strokeWidth` 默认 2.0px、范围 [0, 20]（选中项高度的一半）。
        final double width = ohosStrokeWidth(context, 2);
        return Center(
          child: SizedBox(
            height: rowHeight,
            width: double.infinity,
            child: Column(
              children: <Widget>[
                Container(
                  height: width,
                  color: line,
                  key: const ValueKey<String>('picker-divider-top'),
                ),
                const Spacer(),
                Container(
                  height: width,
                  color: line,
                  key: const ValueKey<String>('picker-divider-bottom'),
                ),
              ],
            ),
          ),
        );
    }
  }
}

/// 时间选择器（时 / 分，可选秒），官方 `TimePicker` 的滚轮形态。
class OhosTimePicker extends StatelessWidget {
  const OhosTimePicker({
    super.key,
    required this.hour,
    required this.minute,
    this.second,
    this.onChanged,
    this.use24Hour = true,
    this.height = 200,
    this.loop = true,
    this.enabled = true,
  });

  /// 当前小时（0–23）。
  final int hour;

  /// 当前分钟（0–59）。
  final int minute;

  /// 当前秒（0–59）；null 表示不显示秒列。
  final int? second;

  /// 任一项变化时回调（时、分、秒）。
  final void Function(int hour, int minute, int second)? onChanged;

  /// 24 小时制。false 时时列取值 1–12，且**不画 AM/PM 列** —— 官方的
  /// `TimePicker` 有独立的 `amPm` 列，但 `useMilitaryTime` 只影响时列本身。
  /// 本库不做 AM/PM 列：它需要额外一个「上午/下午」状态，而调用方拿到
  /// 0–23 的 `hour` 后自己换算更直接。
  final bool use24Hour;

  /// 总高度。
  final double height;

  /// 是否循环。
  final bool loop;

  /// 是否可滚。
  final bool enabled;

  /// 时列的所有取值（含显示文本）。
  static List<String> hoursOf(bool use24Hour) => <String>[
    for (int i = use24Hour ? 0 : 1; i <= (use24Hour ? 23 : 12); i++)
      i.toString().padLeft(2, '0'),
  ];

  /// 分列的所有取值。
  static List<String> get minutes => <String>[
    for (int i = 0; i < 60; i++) i.toString().padLeft(2, '0'),
  ];

  /// 秒列的所有取值。
  static List<String> get seconds => minutes;

  /// 时列的下标（把 1–12 的显示值换算回 0 基下标）。
  int get hourIndex {
    final int base = use24Hour ? 0 : 1;
    return (hour - base).clamp(0, use24Hour ? 23 : 11);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> hourLabels = hoursOf(use24Hour);
    final List<String> minuteLabels = minutes;
    return OhosWheelPicker(
      height: height,
      loop: loop,
      enabled: enabled,
      columns: <OhosPickerColumn>[
        OhosPickerColumn(labels: hourLabels, initialIndex: hourIndex),
        OhosPickerColumn(
          labels: minuteLabels,
          initialIndex: minute.clamp(0, 59),
        ),
        if (second != null)
          OhosPickerColumn(labels: seconds, initialIndex: second!.clamp(0, 59)),
      ],
      onChanged: (int column, int index) {
        if (onChanged == null) {
          return;
        }
        final int base = use24Hour ? 0 : 1;
        final int h = column == 0 ? index + base : hour;
        final int m = column == 1 ? index : minute;
        final int s = column == 2 ? index : (second ?? 0);
        onChanged!(h, m, s);
      },
    );
  }
}

/// 日期选择器（年 / 月 / 日三列滚轮），官方 `DatePicker` 的滚轮形态。
///
/// **日期回绕照官方**：改月、改年时「日」收敛到当月实际最后一天，而不是进位
/// 到下一月 —— 与 `OhosDateCounter` 的 `_clampedDay` 是同一条规则。2 月 30 日
/// 在滚轮里必须直接变成 2 月 28/29 日，否则这三列会允许一个不存在的日期。
class OhosDatePicker extends StatefulWidget {
  const OhosDatePicker({
    super.key,
    required this.year,
    required this.month,
    required this.day,
    this.onChanged,
    this.minYear = 1900,
    this.maxYear = 2100,
    this.height = 200,
    this.loop = true,
    this.enabled = true,
  });

  /// 当前年。
  final int year;

  /// 当前月（1–12）。
  final int month;

  /// 当前日（1–31，越界时按当月实际长度收敛）。
  final int day;

  /// 日期变化回调。
  final void Function(int year, int month, int day)? onChanged;

  /// 年列下界。
  final int minYear;

  /// 年列上界。
  final int maxYear;

  /// 总高度。
  final double height;

  /// 是否循环。
  final bool loop;

  /// 是否可滚。
  final bool enabled;

  /// 某年某月的天数。
  static int daysInMonth(int year, int month) {
    // 与 `OhosDate` 同一套规则，不引 `DateTime` —— 见 ohos_date_counter.dart
    // 里「刻意不用 DateTime」那一段。
    const List<int> days = <int>[
      31,
      28,
      31,
      30,
      31,
      30,
      31,
      31,
      30,
      31,
      30,
      31,
    ];
    if (month == 2) {
      final bool leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
      return leap ? 29 : 28;
    }
    return days[(month - 1).clamp(0, 11)];
  }

  @override
  State<OhosDatePicker> createState() => _OhosDatePickerState();
}

class _OhosDatePickerState extends State<OhosDatePicker> {
  late int _year;
  late int _month;
  late int _day;

  @override
  void initState() {
    super.initState();
    _year = widget.year.clamp(widget.minYear, widget.maxYear);
    _month = widget.month.clamp(1, 12);
    _day = widget.day.clamp(1, OhosDatePicker.daysInMonth(_year, _month));
  }

  @override
  void didUpdateWidget(covariant OhosDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year ||
        oldWidget.month != widget.month ||
        oldWidget.day != widget.day) {
      _year = widget.year.clamp(widget.minYear, widget.maxYear);
      _month = widget.month.clamp(1, 12);
      _day = widget.day.clamp(1, OhosDatePicker.daysInMonth(_year, _month));
    }
  }

  /// 换年月时把日收敛到当月最后一天。
  void _setMonth(int year, int month) {
    final int days = OhosDatePicker.daysInMonth(year, month);
    final int nextDay = _day > days ? days : _day;
    final bool changed = nextDay != _day || year != _year || month != _month;
    setState(() {
      _year = year;
      _month = month;
      _day = nextDay;
    });
    if (changed) {
      widget.onChanged?.call(_year, _month, _day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> years = <String>[
      for (int y = widget.minYear; y <= widget.maxYear; y++) '$y',
    ];
    final List<String> months = <String>[
      for (int m = 1; m <= 12; m++) m.toString().padLeft(2, '0'),
    ];
    final int days = OhosDatePicker.daysInMonth(_year, _month);
    final List<String> daysList = <String>[
      for (int d = 1; d <= days; d++) d.toString().padLeft(2, '0'),
    ];

    return OhosWheelPicker(
      height: widget.height,
      loop: widget.loop,
      enabled: widget.enabled,
      // 2:1:1 —— 「2025 / 03 / 05」这类字样里年份最宽；官方多列示例也是
      // 按内容宽度分配，等比会让年份那列挤。
      columns: <OhosPickerColumn>[
        OhosPickerColumn(
          labels: years,
          initialIndex: _year - widget.minYear,
          flex: 2,
        ),
        OhosPickerColumn(labels: months, initialIndex: _month - 1),
        OhosPickerColumn(labels: daysList, initialIndex: _day - 1),
      ],
      onChanged: (int column, int index) {
        switch (column) {
          case 0:
            _setMonth(widget.minYear + index, _month);
          case 1:
            _setMonth(_year, index + 1);
          case 2:
            setState(() => _day = index + 1);
            widget.onChanged?.call(_year, _month, _day);
        }
      },
    );
  }
}

/// Shows a bottom-sheet picker (选择器 in the HarmonyOS guideline) and
/// resolves with the selected value.
///
/// ```dart
/// final String? city = await showOhosPicker<String>(
///   context: context,
///   title: '选择城市',
///   items: const [
///     OhosPickerItem(label: '北京', value: 'beijing'),
///     OhosPickerItem(label: '上海', value: 'shanghai'),
///   ],
///   initialValue: 'beijing',
/// );
/// ```
Future<T?> showOhosPicker<T>({
  required BuildContext context,
  required String title,
  required List<OhosPickerItem<T>> items,
  T? initialValue,
}) {
  final OhosThemeData sheetTheme = OhosTheme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: sheetTheme.popupColor,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      // 墨水屏：面板与页面同为纯白，顶上那条边只靠 scrim 撑不住 → 1px 实线
      side: sheetTheme.usesOutlines
          ? ohosBorderSide(context, sheetTheme.dividerColor)
          : BorderSide.none,
    ),
    builder: (BuildContext context) {
      final OhosThemeData theme = OhosTheme.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.typography.titleMedium?.copyWith(
                color: theme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final OhosPickerItem<T> item in items)
                    OhosPressFeedback(
                      onTap: () => Navigator.pop(context, item.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.label,
                                    style: theme.typography.bodyLarge?.copyWith(
                                      color: theme.textPrimaryColor,
                                    ),
                                  ),
                                  if (item.subtitle != null)
                                    Text(
                                      item.subtitle!,
                                      style: theme.typography.bodySmall
                                          ?.copyWith(
                                            color: theme.textSecondaryColor,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            if (item.value == initialValue)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: theme.highlightColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OhosButton(
                  onPressed: () => Navigator.pop(context),
                  style: OhosButtonStyle.text,
                  child: const Text('取消'),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
