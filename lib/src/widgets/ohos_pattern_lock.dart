import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// A 3x3 pattern lock input (图案锁 in the HarmonyOS guideline).
///
/// Resolves with the pattern as a list of node indices (0-8) when the finger
/// is lifted; pass [onError] for wrong-pattern feedback.
class OhosPatternLock extends StatefulWidget {
  const OhosPatternLock({
    super.key,
    required this.onCompleted,
    this.onError,
    this.size = 280,
    this.cellSize = 56,
    this.cellColor,
    this.activeColor,
    this.errorColor,
  });

  /// Called with the pattern when the finger is lifted.
  final ValueChanged<List<int>> onCompleted;

  /// Called when the drawn pattern equals [errorPattern]; use this to show
  /// red error feedback on a failed retry.
  final VoidCallback? onError;

  /// Side length of the whole view.
  final double size;

  /// Diameter of each node dot.
  final double cellSize;

  /// Node color; defaults to the theme secondary text.
  final Color? cellColor;

  /// Active stroke color; defaults to the theme highlight color.
  final Color? activeColor;

  /// Error stroke color.
  final Color? errorColor;

  @override
  State<OhosPatternLock> createState() => _OhosPatternLockState();
}

class _OhosPatternLockState extends State<OhosPatternLock> {
  final List<int> _pattern = <int>[];
  Offset? _current;
  bool _error = false;

  static const List<Offset> _centers = <Offset>[
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

  double get _step => widget.size / 4;

  Offset _position(int index) {
    final Offset c = _centers[index];
    return Offset(c.dx * _step, c.dy * _step);
  }

  int? _hit(Offset position) {
    for (int i = 0; i < _centers.length; i++) {
      if ((_position(i) - position).distance <= _step * 0.75 &&
          !_pattern.contains(i)) {
        return i;
      }
    }
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _pattern.clear();
      _current = d.localPosition;
      _error = false;
      final int? hit = _hit(d.localPosition);
      if (hit != null) _pattern.add(hit);
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _current = d.localPosition;
      final int? hit = _hit(d.localPosition);
      if (hit != null) _pattern.add(hit);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_pattern.length < 2) return;
    _error = _pattern.length < 2;
    widget.onCompleted(List<int>.of(_pattern));
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color active = _error
        ? (widget.errorColor ?? theme.dangerColor)
        : (widget.activeColor ?? theme.highlightColor);
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
          cellSize: widget.cellSize,
          activeColor: active,
          idleColor: widget.cellColor ?? theme.textSecondaryColor,
        ),
      ),
    );
  }
}

class _PatternLockPainter extends CustomPainter {
  _PatternLockPainter({
    required this.pattern,
    required this.current,
    required this.centers,
    required this.cellSize,
    required this.activeColor,
    required this.idleColor,
  });

  final List<int> pattern;
  final Offset? current;
  final List<Offset> centers;
  final double cellSize;
  final Color activeColor;
  final Color idleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < pattern.length - 1; i++) {
      canvas.drawLine(centers[pattern[i]], centers[pattern[i + 1]], stroke);
    }
    if (pattern.isNotEmpty && current != null) {
      canvas.drawLine(centers[pattern.last], current!, stroke);
    }
    for (int i = 0; i < centers.length; i++) {
      final bool active = pattern.contains(i);
      canvas.drawCircle(
        centers[i],
        cellSize / 2,
        Paint()
          ..color = active ? activeColor : idleColor.withValues(alpha: 0.6),
      );
      if (active) {
        canvas.drawCircle(
          centers[i],
          cellSize / 6,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PatternLockPainter oldDelegate) =>
      oldDelegate.pattern != pattern ||
      oldDelegate.current != current ||
      oldDelegate.activeColor != activeColor;
}
