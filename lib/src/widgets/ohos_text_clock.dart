import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 文本时钟的控制器，对应 ArkUI 的 `TextClockController`。
///
/// 官方原话：「一个 TextClock 组件仅支持绑定一个控制器」。所以这里不做
/// 「一个控制器驱动多个时钟」的广播 —— 那样两个时钟会有各自的启动状态，
/// 而官方 `TextClockConfiguration.started` 是**每组件一份**。
/// 要同步两个时钟就让调用方各建一个，官方示例 3 正是这么写的。
class OhosTextClockController extends ChangeNotifier {
  bool _started = true;

  /// 时钟是否在走。官方 `TextClockConfiguration.started`，默认 `true`。
  bool get started => _started;

  /// 启动文本时钟（官方 `start()`）。
  ///
  /// 未绑定组件时调用是安全的空操作 —— 官方说「使用前需先将控制器绑定到
  /// 组件」，但一个还没 mount 的控制器在 Flutter 里太常见（在 `initState`
  /// 就 `start()`），抛错只会逼调用方到处判 `mounted`。
  void start() {
    if (_started) {
      return;
    }
    _started = true;
    notifyListeners();
  }

  /// 停止文本时钟（官方 `stop()`）。
  ///
  /// **停的是「刷新」，不是「显示」**：官方只说停止时钟，没说要清空文本，
  /// 示例里停下后按钮图标照旧显示当前时间。所以这里冻结在最后一帧的值，
  /// 不清成空串、也不退回默认格式。
  void stop() {
    if (!_started) {
      return;
    }
    _started = false;
    notifyListeners();
  }
}

/// `DateTimeOptions` 里唯一被官方支持的 `hour` 取值。
///
/// 官方 `dateTimeOptions`：「只支持设置 hour 参数」，两个取值分别表示
/// 显示 / 不显示前导零。
enum OhosClockHourFormat {
  /// 不显示前导零（官方 `{hour: "numeric"}`）。
  numeric,

  /// 显示前导零（官方 `{hour: "2-digit"}`）。
  twoDigit,
}

/// 时间变化回调收到的参数。
///
/// 官方 `onDateChange(event: (value: number) => void)`，参数是
/// **Unix 时间戳（秒）**。本库保留整数秒这层粒度而不是给 `DateTime` ——
/// 调用方拿到的就是官方那个数，要 `DateTime` 自己 `fromMillisecondsSinceEpoch
/// (value * 1000)`，两边不必猜对方用的是哪个单位。
@immutable
class OhosTextClockTick {
  const OhosTextClockTick({required this.value, required this.dateTime});

  /// Unix 时间戳，单位**秒**（官方 `value`）。
  final int value;

  /// 同一时刻的 [DateTime]，省得调用方每次再算一遍。
  final DateTime dateTime;

  @override
  bool operator ==(Object other) =>
      other is OhosTextClockTick &&
      other.value == value &&
      other.dateTime == dateTime;

  @override
  int get hashCode => Object.hash(value, dateTime);
}

/// A live text clock matching the "文本时钟" control in the HarmonyOS
/// design guideline, the counterpart of ArkUI's `TextClock`.
///
/// 官方口径里有三条与「每秒刷新的文本」直觉相反，都落在这里：
///
/// 1. **`timeZoneOffset` 的符号是反的**：负数表示东时区，东八区传 **-8**
///    （`new Date().getTimezoneOffset()` 那套符号）。写成 `+8` 会得到西八区。
/// 2. **组件不可见时时间停止变动**。官方按 `onVisibleAreaChange` 的可见阈值
///    `ratios > 0` 判可见。Flutter 侧用 [TickerMode] 做同一件事 —— 它正是
///    「这棵子树现在该不该动」的官方通道，`AnimatedBuilder` 也走它。
///    自己计时器的话，一屏放十个时钟会有十个每秒都跑的 `Timer`。
/// 3. **格式字母区分大小写**：`H` 是 24 小时制、`h` 是 12 小时制，`M` 是月、
///    `m` 是分。`replaceAll('M')` 先于 `replaceAll('m')` 不会互相误伤（大小写
///    不同），但 `E`（星期）与 `S`（毫秒）需要单独处理。
class OhosTextClock extends StatefulWidget {
  const OhosTextClock({
    super.key,
    this.format,
    this.timeZoneOffset,
    this.controller,
    this.textStyle,
    this.textAlign,
    this.onDateChange,
    this.hourFormat,
    this.clockSource,
    this.locale,
  });

  /// 显示格式（官方 `format`）。
  ///
  /// 支持 `y/M/d/E/H/h/m/s/S/a` 十个字母与空格、`年月日`、`/`、`-`、`.` 等
  /// 分隔符。为空串或 `null` 时按官方默认：24 小时制 `HH:mm:ss`。
  ///
  /// 官方对无效字母的规定是「该字母会被忽略」，不是抛错；全是无效字母时
  /// 「显示格式跟随系统语言和系统小时制」—— Flutter 侧没有系统小时制可读，
  /// 一律按 24 小时制（`MediaQuery.alwaysUse24HourFormat` 描述的是**界面**
  /// 是否 24 小时，不是时钟格式），并把这件事写在这里而不是假装读到了。
  final String? format;

  /// 时区偏移量，单位**小时**（官方 `timeZoneOffset`）。
  ///
  /// 取值范围 `[-14, 12]`，**负值表示东时区**（东八区 = `-8`）。范围内的
  /// 浮点值会取整，但 `9.5 / 3.5 / -3.5 / -4.5 / -5.5 / -5.75 / -6.5 /
  /// -9.5 / -10.5 / -12.75` 这十个保持原样不取整（官方明文，印度 +5:30
  /// 就在里面）。越界或为 `null` 时用系统当前时区。
  ///
  /// 0.6 之前这里是 `String? timeZone`（IANA 名），但**它什么都没做** ——
  /// 实现只是 `toUtc().toLocal()`，一个恒等变换，传 `America/New_York` 与
  /// 不传结果完全相同。改成官方这个数字参数，语义与实现终于对得上。
  final double? timeZoneOffset;

  /// 启动 / 停止控制（官方 `controller`）。
  final OhosTextClockController? controller;

  /// 时钟文字样式；默认为主题 `titleMedium` + 主文字色 + 等宽数字。
  final TextStyle? textStyle;

  /// Text alignment.
  final TextAlign? textAlign;

  /// 时间变化回调（官方 `onDateChange`），回调间隔 1 秒。
  ///
  /// 官方「组件不可见时不回调」—— 这里同样受 [TickerMode] 约束：不可见时
  /// 计时器根本不建，自然不回调。
  final ValueChanged<OhosTextClockTick>? onDateChange;

  /// 小时是否显示前导零（官方 `dateTimeOptions`）。
  ///
  /// 官方默认：**24 小时制显示前导零、12 小时制不显示**。所以 `null` 时按
  /// 「格式里用的是 `H` 还是 `h`」自动决定，而不是钉成一个固定姿势。
  final OhosClockHourFormat? hourFormat;

  /// 时间源，仅供测试注入（`@visibleForTesting`）。
  ///
  /// **为什么需要它**：官方「组件不可见时时间停止变动」这条规格，用真实系统
  /// 时钟断不出来 —— `flutter_test` 的 `pump(Duration(...))` 会推进 `Timer`，
  /// 但**不会推进 `DateTime.now()`**，wall clock 不动。于是「有没有在走」
  /// 在真实时钟下观测不到，用例只能是恒真的。换成可控时间源才真验得了：
  /// 推进假时钟 → 秒数变了 → 进 `TickerMode(false)` → 再推进 → 秒数必须没变。
  @visibleForTesting
  final DateTime Function()? clockSource;

  /// 决定星期名用哪套语言（官方按系统语言输出）。
  ///
  /// **不能只读 `Localizations.localeOf`** —— 实测的坑：`MaterialApp(locale:
  /// Locale('zh'))` 在 `flutter_test` 下解析出来仍是 `en_US`，因为默认的
  /// `GlobalMaterialLocalizations.delegate` 只带 `en` 一套支持列表，中文会被
  /// 「最近的可用语言」规则回落到英文。所以这里给一个显式入口：传了就按它，
  /// 没传才读 `Localizations`（再没有则按中文，本库的主要用户群）。
  final Locale? locale;

  @override
  State<OhosTextClock> createState() => _OhosTextClockState();
}

class _OhosTextClockState extends State<OhosTextClock> {
  Timer? _ticker;
  late OhosTextClockTick _tick;

  @override
  void initState() {
    super.initState();
    _tick = _readClock();
    widget.controller?.addListener(_onControllerChanged);
    // 第一次 tick 也要通知 —— 官方 `onDateChange` 是「时间变化时回调」，
    // 不是「初始化时回调」；但调用方通常用它来同步一份外部状态，首帧不报
    // 会让那份状态永远差一秒。放在 `didChangeDependencies` 之后的微任务里，
    // 避免在 `initState` 里 `setState` 外部 widget。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onDateChange?.call(_tick);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(OhosTextClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
    // 时间源、时区都换了就必须重读 —— 否则 `_advance` 的「秒数没变就跳过」
    // 会把新的时区当成同一秒而静默不生效。踩过：把 `timeZoneOffset` 从 -8
    // 改成 +5，界面还是 `10:00`，因为 UTC 秒数一模一样、差异只在偏移上。
    if (oldWidget.timeZoneOffset != widget.timeZoneOffset ||
        oldWidget.clockSource != widget.clockSource) {
      _tick = _readClock();
    }
    _syncTicker();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    // 启动时立刻对齐一次：停了两分钟再点开始，不该先显示两分钟前的值
    // 再等下一秒才跳。
    if (widget.controller?.started ?? true) {
      _advance();
    }
    _syncTicker();
  }

  /// 计时器只在「该走」的时候存在：控制器说 stop、或本轮帧不可见（[TickerMode]
  /// 为 false）都直接不建。这与官方「组件不可见时时间变动停止」是同一条规则。
  void _syncTicker() {
    // 这里只能用旧 API，是**双 SDK** 逼出来的，不是懒得改：
    // Flutter 3.47 把 `TickerMode.of` 与 `getNotifier` 都弃用了，替代品
    // `valuesOf(context).enabled` 要求 3.36+；而本库还要能构建 HarmonyOS 分支
    // （`oh-3.35.7-release`），那里**没有** `valuesOf`（已核对该版本的
    // `ticker_provider.dart`，只有 `of` 与 `getNotifier`）。换成新 API 会让
    // ohos 构建直接编译失败，两害相权取「保留旧 API + 忽略提示」。
    // 等最低支持版本抬到 3.36 之后，这里改成 `valuesOf(context).enabled` 即可。
    // ignore: deprecated_member_use
    final bool visible = TickerMode.of(context);
    final bool started = widget.controller?.started ?? true;
    final bool shouldRun = visible && started;

    if (shouldRun && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _advance());
    } else if (!shouldRun && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _advance() {
    final OhosTextClockTick next = _readClock();
    // 秒数没变就不通知：`Timer.periodic` 会漂移，偶尔两次回调落在同一秒，
    // 那时重建一次子树只是白花一帧。
    if (next.value == _tick.value) {
      return;
    }
    setState(() => _tick = next);
    widget.onDateChange?.call(next);
  }

  /// 官方 `timeZoneOffset` 收的是「本地时间差」而非「UTC 偏移」：
  /// 东八区传 `-8`（`Date.getTimezoneOffset()` 那套符号），所以
  /// **本地 = UTC − offset**。写成 `UTC + offset` 会得到西八区 —— 实测
  /// `utc=15:22` 时后者给 `07:22`（正是 UTC-8），前者给 `23:22`。
  OhosTextClockTick _readClock() {
    final DateTime utc = (widget.clockSource ?? DateTime.now)().toUtc();
    final double? requested = widget.timeZoneOffset;
    if (requested == null || requested < -14 || requested > 12) {
      final DateTime local = utc.toLocal();
      return OhosTextClockTick(
        value: local.millisecondsSinceEpoch ~/ 1000,
        dateTime: local,
      );
    }
    // 官方「范围内的浮点值会取整」，但十个半小时档保持原样。乘 60 转分钟是
    // 因为 `Duration` 收不到小数小时；`-5.75` 落成 +345 分钟正好是 -5:45。
    final DateTime shifted = utc.add(
      Duration(
        minutes: -(_wholeHoursOrOfficialHalfHour(requested) * 60).round(),
      ),
    );
    return OhosTextClockTick(
      value: shifted.millisecondsSinceEpoch ~/ 1000,
      dateTime: shifted,
    );
  }

  /// 官方「范围内的浮点值会取整，但下列十个保持原样」。
  static double _wholeHoursOrOfficialHalfHour(double raw) {
    const List<double> keepFraction = <double>[
      9.5, 3.5, -3.5, -4.5, -5.5, -5.75, -6.5, -9.5, -10.5, -12.75, //
    ];
    for (final double v in keepFraction) {
      if (v == raw) {
        return raw;
      }
    }
    return raw.floorToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final String pattern = _resolvePattern(widget.format);
    final DateTime shown = _tick.dateTime;

    return Text(
      _format(
        shown,
        pattern,
        widget.locale ?? Localizations.maybeLocaleOf(context),
      ),
      textAlign: widget.textAlign,
      style:
          widget.textStyle ??
          theme.typography.titleMedium?.copyWith(
            color: theme.textPrimaryColor,
            // 官方 `fontFeature` 的典型用法就是「等宽时钟数字」；每秒跳动时
            // 非等宽数字会让整段文本左右抖 1–2px。
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
    );
  }

  /// 官方「若 format 为空字符串或者 undefined，则使用默认值」。
  /// 非空时原样交给 [_format]（无效字母在那里逐个忽略）。
  static String _resolvePattern(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'HH:mm:ss';
    }
    return raw;
  }

  /// 把格式串渲染成时间文本。
  ///
  /// **必须是「一次扫描、逐字符吐结果」，不能在原串上反复 `replaceAll`。**
  /// 踩过的坑：链式替换会让**已经吐出来的结果**再次被后面的模式命中 ——
  /// `yyyy年M月d日 EEEE` 里的 `EEEE` 先被换成 `Sat`，随后单字母 `a` 把
  /// `Sat` 里的 `a` 换成了「下午」，单字母 `S` 又把 `Sat` 的 `S` 换成了
  /// 毫秒，最终吐出 `51下午t`。`aa hh:mm:ss` 同理被拆成「下午下午」。
  /// 官方那套格式串的语义就是「同名连续字母 = 一个字段」，扫描时先吃同名字母
  /// 的整段、再查表，才与官方同构。
  String _format(DateTime t, String pattern, Locale? locale) {
    final bool isZh = (locale?.languageCode ?? 'zh') == 'zh';
    // 官方「当设置小时制式为 H 时，该参数不生效」—— 是否 12 小时制由**格式串
    // 里的字母**决定（`h` 是 12 小时制、`H` 是 24 小时制）。两者同时出现时
    // 偏向 `h`：那说明调用方确实要 12 小时制，`H` 只是笔误。
    final bool twelveHour = pattern.contains('h') && !pattern.contains('H');
    // 官方默认：**24 小时制补前导零、12 小时制不补**。所以 `null` 时跟着
    // `twelveHour` 走，而不是钉成一个固定姿势。
    final bool padHour = switch (widget.hourFormat) {
      OhosClockHourFormat.twoDigit => true,
      OhosClockHourFormat.numeric => false,
      null => !twelveHour,
    };
    final String ms = t.millisecond.toString().padLeft(3, '0');

    String two(int v) => v.toString().padLeft(2, '0');

    final StringBuffer out = StringBuffer();
    int i = 0;
    while (i < pattern.length) {
      final String ch = pattern[i];
      if (!_formatLetters.contains(ch)) {
        out.write(ch);
        i += 1;
        continue;
      }
      // 吃完同名字母的整段。`yyyy` 是四位、`yy` 是两位、`y` 官方未定义
      // （按「无效字母被忽略」处理成两位）。
      int run = 1;
      while (i + run < pattern.length && pattern[i + run] == ch) {
        run += 1;
      }
      out.write(
        _field(
          ch,
          run,
          t,
          isZh: isZh,
          padHour: padHour,
          twelveHour: twelveHour,
          ms: ms,
          two: two,
        ),
      );
      i += run;
    }
    return out.toString();
  }

  /// 官方 `format` 认的十个字母。其余字母按「无效字母会被忽略」当字面量
  /// 处理？不 —— 官方说的是**忽略**，所以它们既不输出也不报错。这里用
  /// 「字母表之外当分隔符原样保留」的宽松读法：`yyyy年` 的「年」是汉字
  /// 分隔符，必须保留；而纯 ASCII 字母除这十个以外本库原样吐出，理由是
  /// 「忽略」与「原样」在常见格式串里没有区别，原样至少不会把用户的
  /// 文字吃掉。
  static const String _formatLetters = 'yMdEhHmsSa';

  String _field(
    String letter,
    int run,
    DateTime t, {
    required bool isZh,
    required bool padHour,
    required bool twelveHour,
    required String ms,
    required String Function(int) two,
  }) {
    switch (letter) {
      case 'y':
        // `yyyy` 完整年份、`yy` 后两位；单个 `y` 官方没定义，按两位处理。
        return run >= 4
            ? t.year.toString().padLeft(4, '0')
            : (t.year % 100).toString().padLeft(2, '0');
      case 'M':
        return run >= 2 ? two(t.month) : t.month.toString();
      case 'd':
        return run >= 2 ? two(t.day) : t.day.toString();
      case 'E':
        // 官方：`EEEE` 完整星期（星期六）、`E`/`EE`/`EEE` 简写（周六）。
        return _weekdayName(t.weekday, long: run >= 4, zh: isZh);
      case 'H':
        // 官方的 `hour` 是**一个**选项，不分大小写地管「小时是否补零」；
        // 12/24 制由 `h` / `H` 决定，补不补零由 `dateTimeOptions` 决定。
        // 所以这里必须同样读 `padHour` —— 只写死 `two()` 会让 `HH` 在
        // `numeric` 下照样补零（踩过：`HH:mm` + numeric 仍是 `01:05`）。
        return _hour(t.hour, pad: padHour);
      case 'h':
        return _hour12(t.hour, padHour);
      case 'm':
        return two(t.minute);
      case 's':
        return two(t.second);
      case 'S':
        // 官方：「format 中 S 个数 < 3，全部按厘秒处理；>= 3 全部按毫秒」。
        return run >= 3 ? ms : ms.substring(0, 2);
      case 'a':
        // 官方「当设置小时制式为 H 时，该参数不生效」—— 不生效即不输出。
        return twelveHour ? (t.hour < 12 ? '上午' : '下午') : '';
      default:
        return '';
    }
  }

  static String _hour(int hour24, {required bool pad}) {
    return pad ? hour24.toString().padLeft(2, '0') : hour24.toString();
  }

  static String _hour12(int hour24, bool pad) {
    final int h = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return pad ? h.toString().padLeft(2, '0') : h.toString();
  }

  /// 星期的本地化名称。
  ///
  /// 官方按**系统语言**输出（中文系统给「星期六」）。Flutter 侧要拿完整
  /// 本地化得走 `MaterialLocalizations`，但本库的时钟不带 `MaterialApp` 也
  /// 能用（示例里就挂在纯 `OhosTheme` 下面），所以按 `Locale.languageCode`
  /// 分中英两套 —— **只覆盖中文与英文，其余语言回落到英文缩写**。这条口径差
  /// 记在这里，不假装做了全语言本地化。
  static String _weekdayName(
    int weekday, {
    required bool long,
    bool zh = true,
  }) {
    // 官方示例表：`EEEE` → 「星期六」，`E`/`EE`/`EEE` → 「周六」。两套都要，
    // 中文确实有「周六」这个短形态（官方自己写在示例表里）。
    const List<String> zhLong = <String>[
      '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日', //
    ];
    const List<String> zhShort = <String>[
      '周一', '周二', '周三', '周四', '周五', '周六', '周日', //
    ];
    const List<String> enLong = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const List<String> enShort = <String>[
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
    ];
    final int i = weekday - 1;
    if (zh) {
      return long ? zhLong[i] : zhShort[i];
    }
    return long ? enLong[i] : enShort[i];
  }
}
