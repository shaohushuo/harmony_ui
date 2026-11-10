import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A 3x3 pattern lock input (图案锁 in the HarmonyOS guideline).
///
/// 官方几何（`PatternLock` 的默认值，见 `ts-basic-components-patternlock.md`）：
/// `sideLength` 288、`circleRadius` 6（上限 `sideLength/11`）、
/// `pathStrokeWidth` 12（上限 `sideLength/3`）、连线色 `#33182431`、
/// 圆点常态色 `#182431`、激活背景圆环半径约 `circleRadius × 11/6`
/// 且颜色同为 `#33182431`。
///
/// 三个几何量都按官方的**上限规则**夹取，而不是直接用：
/// 尺寸缩到 160 时 `circleRadius` 仍是 6 就会显得圆点胖得离谱，
/// 而 `pathStrokeWidth` 12 更是直接把九宫格糊成一片。
class OhosPatternLock extends StatefulWidget {
  const OhosPatternLock({
    super.key,
    required this.onCompleted,
    this.onError,
    this.errorPattern,
    this.size = 288,
    this.circleRadius = 6,
    this.pathStrokeWidth = 12,
    this.pathColor,
    this.circleColor,
    this.activeCircleColor,
  });

  /// Called with the pattern when the finger is lifted.
  ///
  /// 至少连到两个点才会触发：只落下一个点不构成图案，官方也不会把它当一次
  /// 输入（`setChallengeResult` 没有「一个点」这种结果）。
  final ValueChanged<List<int>> onCompleted;

  /// Called when the drawn pattern equals [errorPattern].
  final VoidCallback? onError;

  /// 视为「画错了」的图案序列；`null` 表示组件不自行判错。
  ///
  /// 判错这件事必须由调用方给答案——组件无从知道正确密码是什么。官方把这一步
  /// 拆成两条命令：`checkPattern` 由宿主管，`setChallengeResult(CORRECT |
  /// WRONG)` 由宿主回填。这里用「把错误图案交给组件」代替回填命令，是同一
  /// 语义的声明式写法：命中就整条路径换成 danger 色，直到下一次重新落笔。
  ///
  /// 给了 [errorPattern] 才会调用 [onError]；不给就只透传 [onCompleted]。
  final List<int>? errorPattern;

  /// 组件宽高（官方 `sideLength`，默认 **288vp**）。
  final double size;

  /// 圆点半径（官方 `circleRadius`，默认 **6vp**，上限 `size / 11`）。
  ///
  /// 官方的取值范围是 `(0, sideLength/11]`：「设置小于等于 0 的值时按默认值
  /// 处理；超过最大值时按最大值处理」。这条上限不是可选的美化项 ——
  /// 288/11 = 26.2 看着很宽，但组件缩到 160 时上限只有 14.5，再大就重叠。
  final double circleRadius;

  /// 连线宽度（官方 `pathStrokeWidth`，默认 **12vp**，上限 `size / 3`）。
  ///
  /// 12 在 288 的九宫格里是「粗线」的观感；缩到 160 时上限只剩 53 ——
  /// 真正常见的误用不是超上限，而是没跟着 `size` 一起缩：12 的线在 160 的
  /// 格里会盖住圆点，看起来像一根横杠。
  final double pathStrokeWidth;

  /// 连线颜色；`null` 取 `#33182431`（官方默认，深灰 20%）。
  final Color? pathColor;

  /// 圆点常态色；`null` 取 `#182431`（官方 `regularColor` 默认）。
  final Color? circleColor;

  /// 激活态背景圆环颜色；`null` 取 `#33182431`（官方 `activateCircleStyle`）。
  final Color? activeCircleColor;

  @override
  State<OhosPatternLock> createState() => _OhosPatternLockState();
}

class _OhosPatternLockState extends State<OhosPatternLock> {
  final List<int> _pattern = <int>[];
  Offset? _current;
  bool _error = false;

  /// 官方默认：`pathColor` / 激活圆环都是 `#33182431`（深灰 20%），
  /// 圆点常态是 `#182431`（深灰）。
  static const Color _defaultPathColor = Color(0x33182431);
  static const Color _defaultCircleColor = Color(0xFF182431);
  static const Color _defaultActiveCircleColor = Color(0x33182431);

  /// 官方区间夹取：`circleRadius ∈ (0, size/11]`、`pathStrokeWidth ∈ (0, size/3]`。
  double get _circleRadius {
    final double max = widget.size / 11;
    final double r = widget.circleRadius;
    if (r <= 0) {
      return math.min(6, max);
    }
    return math.min(r, max);
  }

  double get _strokeWidth {
    final double max = widget.size / 3;
    final double w = widget.pathStrokeWidth;
    if (w <= 0) {
      return math.min(12, max);
    }
    return math.min(w, max);
  }

  /// 激活圆环半径：官方「`circleRadius` 的约 1.833 倍（即 11/6）」。
  double get _ringRadius => _circleRadius * 11 / 6;

  /// 九宫格的格距。官方没有这一项，它由「圆点必须落在 288 方框内且四周留白
  /// 均匀」反推：3 个点 + 两侧各半个格距 = 4 等分，即 `size / 4`。
  /// 288 时格距 72、点位在 72/144/216，最外圈圆点到边缘 72 —— 与设计稿
  /// 里「九宫格居中、四周留白相等」一致。
  double get _step => widget.size / 4;

  static const List<Offset> _grid = <Offset>[
    Offset(1, 1),
    Offset(2, 1),
    Offset(3, 1),
    Offset(1, 2),
    Offset(2, 2),
    Offset(3, 2),
    Offset(1, 3),
    Offset(2, 3),
    Offset(3, 3),
  ];

  Offset _position(int index) {
    final Offset c = _grid[index];
    return Offset(c.dx * _step, c.dy * _step);
  }

  /// 命中半径**不是**格距的一大半。
  ///
  /// 早先是 `_step * 0.75`（288 的格子里是 54vp 半径）—— 相邻两点的命中区
  /// 大面积重叠，手指在两个点之间任意一处都算「碰到」，于是随手一划就把
  /// 整个九宫格串成一串。官方的语义是「手指经过圆点」，判据因此取圆点自身
  /// 的范围再加上一点点宽容度（半个圆点半径），而不是到下一个点的一半路。
  double get _hitRadius => _circleRadius * 1.5;

  int? _hit(Offset position) {
    // 取**最近**的候选，而不是「第一个落在范围里的」：后者的结果取决于
    // 遍历顺序，在两点之间取哪个是随机的。
    int? best;
    double bestDistance = double.infinity;
    for (int i = 0; i < _grid.length; i++) {
      if (_pattern.contains(i)) {
        continue;
      }
      final double d = (_position(i) - position).distance;
      if (d <= _hitRadius && d < bestDistance) {
        best = i;
        bestDistance = d;
      }
    }
    return best;
  }

  /// 手指当前位置在**九个圆点所占据的范围**内的投影。
  ///
  /// 这是「连线跑出 9 个点之外」的直接修复：早先把 `_current`（手指的本地
  /// 坐标）原样当线段终点，手指滑到控件边缘时线就一路画到边框外。
  ///
  /// 夹取范围是**最外圈圆点的外沿**（圆心 ± 圆点半径），不是整个控件。
  /// 这个区别很关键：默认 288 时九宫格的点位是 72 / 144 / 216，两侧各留
  /// 72 —— 如果按控件边缘（0..288）夹，等于没夹，线照样能跑到圆点外面
  /// 72vp 的地方去。按圆点外沿夹，线的最远端就是最外圈那个点的边缘，
  /// 视觉上永远「只在九个点之内」。
  Offset _clampToGrid(Offset position) {
    final double minX = _position(0).dx - _circleRadius;
    final double maxX = _position(2).dx + _circleRadius;
    final double minY = _position(0).dy - _circleRadius;
    final double maxY = _position(8).dy + _circleRadius;
    return Offset(position.dx.clamp(minX, maxX), position.dy.clamp(minY, maxY));
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _pattern.clear();
      _error = false;
      _current = _clampToGrid(d.localPosition);
      final int? hit = _hit(d.localPosition);
      if (hit != null) {
        _pattern.add(hit);
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _current = _clampToGrid(d.localPosition);
      final int? hit = _hit(d.localPosition);
      if (hit != null) {
        _pattern.add(hit);
      }
    });
  }

  void _onPanEnd(DragEndDetails d) {
    // 抬手后不再有「拖到一半」的线段：留着它会让静止的图案看起来还没画完。
    setState(() => _current = null);
    if (_pattern.length < 2) {
      // 一个点不算图案，一个都不算就更不算 —— 直接丢弃，连错误态都不进。
      if (_pattern.isNotEmpty) {
        setState(_pattern.clear);
      }
      return;
    }
    // 先判错再回调：调用方在 onError 里可能会重建本组件，顺序反了就会先收到
    // 一次 onCompleted 再看到红屏。
    final List<int>? expected = widget.errorPattern;
    if (expected != null && _isSamePattern(_pattern, expected)) {
      setState(() => _error = true);
      widget.onError?.call();
      return;
    }
    widget.onCompleted(List<int>.of(_pattern));
  }

  /// 逐位比较；长度不同直接判否（`listEquals` 也可，但这里只比 int 列表，
  /// 自己写省一次泛型装箱）。
  static bool _isSamePattern(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 错误态的整条路径换 danger 色（官方 `setChallengeResult(WRONG)` 的观感）。
    final Color path = _error
        ? theme.dangerColor
        : (widget.pathColor ?? _defaultPathColor);
    final Color circle = _error
        ? theme.dangerColor
        : (widget.circleColor ?? _defaultCircleColor);
    final Color ring = _error
        ? theme.dangerColor.withValues(alpha: 0.20)
        : (widget.activeCircleColor ?? _defaultActiveCircleColor);

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _PatternLockPainter(
          pattern: _pattern,
          current: _current,
          centers: <Offset>[for (int i = 0; i < 9; i++) _position(i)],
          circleRadius: _circleRadius,
          ringRadius: _ringRadius,
          strokeWidth: _strokeWidth,
          pathColor: path,
          circleColor: circle,
          ringColor: ring,
        ),
      ),
    );
  }
}

class _PatternLockPainter extends CustomPainter {
  const _PatternLockPainter({
    required this.pattern,
    required this.current,
    required this.centers,
    required this.circleRadius,
    required this.ringRadius,
    required this.strokeWidth,
    required this.pathColor,
    required this.circleColor,
    required this.ringColor,
  });

  final List<int> pattern;
  final Offset? current;
  final List<Offset> centers;
  final double circleRadius;
  final double ringRadius;
  final double strokeWidth;
  final Color pathColor;
  final Color circleColor;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // 1. 已经确定的段：点与点之间。
    for (int i = 0; i < pattern.length - 1; i++) {
      canvas.drawLine(centers[pattern[i]], centers[pattern[i + 1]], stroke);
    }

    // 2. 拖动中的那一段：从最后一个点连到手指（已在 `_clampToGrid` 里夹进
    //    九宫格）。这一段**不参与图案**，抬手就消失。
    if (pattern.isNotEmpty && current != null) {
      canvas.drawLine(centers[pattern.last], current!, stroke);
    }

    // 3. 圆点。顺序是「先画激活圆环、再画圆点」——官方 `enableForeground`
    //    默认 false，即背景圆环在圆点**下层**、不遮盖圆点。
    for (int i = 0; i < centers.length; i++) {
      final bool selected = pattern.contains(i);
      if (selected) {
        canvas.drawCircle(centers[i], ringRadius, Paint()..color = ringColor);
      }
      canvas.drawCircle(
        centers[i],
        circleRadius,
        Paint()
          ..color = selected
              ? circleColor
              : circleColor.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_PatternLockPainter oldDelegate) {
    // 几何字段（centers / 三个半径宽度）也要比：size 不变、仅改这些参数时
    // CustomPaint 不会因为尺寸变化而自动重绘，漏掉就会画旧几何。
    // List 用 listEquals 比内容 —— 引用比较在「同一个 list 被 mutate」
    // （pattern 的 add/clear）时永远判等，会漏刷新。
    return oldDelegate.current != current ||
        !listEquals(oldDelegate.pattern, pattern) ||
        !listEquals(oldDelegate.centers, centers) ||
        oldDelegate.circleRadius != circleRadius ||
        oldDelegate.ringRadius != ringRadius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.colorSignature != colorSignature;
  }

  /// 三种颜色（连线 / 圆点 / 圆环）的相等性签名。
  ///
  /// 不是「两个颜色」：painter 有 path / circle / ring 三个颜色字段，一起 hash。
  int get colorSignature => Object.hash(pathColor, circleColor, ringColor);
}
