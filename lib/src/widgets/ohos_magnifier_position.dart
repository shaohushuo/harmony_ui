import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which **corner** of the anchor a magnifier bubble occupies.
///
/// The bubble is never centred on the finger (it would cover both the finger
/// and the content right under it): it sits above-left / above-right of the
/// touch point, with [OhosMagnifierPosition.resolve]'s `gap` cleared on both
/// axes. When that corner has no room on screen, the resolver flips to the
/// opposite corner on the same row, then to the row below.
enum OhosMagnifierSide {
  /// 左上/右上中离屏幕内侧更近的那个角；放不下时自动换角、换行。
  auto,

  /// Above and to the left of the anchor.
  aboveLeft,

  /// Above and to the right of the anchor.
  aboveRight,

  /// Below and to the left of the anchor (fallback when the top is covered,
  /// e.g. by an app bar).
  belowLeft,

  /// Below and to the right of the anchor.
  belowRight,
}

/// Result of [OhosMagnifierPosition.resolve].
@immutable
class OhosMagnifierPlacement {
  const OhosMagnifierPlacement({
    required this.offset,
    required this.size,
    required this.side,
  });

  /// Top-left corner of the bubble, in global coordinates.
  final Offset offset;

  /// Size actually used: the requested size clamped to what fits on screen.
  final Size size;

  /// Corner that was finally used; never [OhosMagnifierSide.auto].
  final OhosMagnifierSide side;

  @override
  bool operator ==(Object other) =>
      other is OhosMagnifierPlacement &&
      other.offset == offset &&
      other.size == size &&
      other.side == side;

  @override
  int get hashCode => Object.hash(offset, size, side);

  @override
  String toString() => 'OhosMagnifierPlacement($offset, $size, $side)';
}

/// Pure geometry for a magnifier bubble: no render objects involved, so every
/// edge case (top / bottom / left / right / narrow screens) is unit testable.
@immutable
class OhosMagnifierPosition {
  const OhosMagnifierPosition._();

  /// Places a [bubble]-sized bubble in the given [side] corner of [anchor],
  /// falling back to the other corners when that one does not fit.
  ///
  /// 【为什么是「左上/右上」而不是「上方」】泡泡正对手指会同时盖住指肚和
  /// 手指下方那几格字母，所以它在两个轴上都留 [gap]：横向上落在手指左边或
  /// 右边 `gap` 处，纵向上让底边距手指 `gap`，即手指的左上角或右上角。
  ///
  /// 尝试顺序：
  ///
  /// 1. [side] 指定的角（[OhosMagnifierSide.auto] 取靠屏幕内侧的那个角）；
  /// 2. 同一行的另一个角（贴左/右边缘时）；
  /// 3. 另一行的两个角（顶部被顶栏占了时）。
  ///
  /// 四个角都放不下（窄屏 + 大字号）才退回第 1 个候选并夹进安全区。
  /// 宽度上限为可用宽度的一半，避免泡泡把整条索引条盖住。
  static OhosMagnifierPlacement resolve({
    required Offset anchor,
    required Size bubble,
    required EdgeInsets safe,
    required Size screen,
    OhosMagnifierSide side = OhosMagnifierSide.auto,
    double gap = 12,
  }) {
    final double usableWidth = math.max(0, screen.width - safe.horizontal);
    final double usableHeight = math.max(0, screen.height - safe.vertical);
    final Size size = Size(
      math.min(bubble.width, usableWidth * 0.5),
      math.min(bubble.height, usableHeight),
    );

    // 先定「首选行」与「首选列」：auto 时上面优先、内侧优先。
    final bool preferLeft = switch (side) {
      OhosMagnifierSide.aboveLeft || OhosMagnifierSide.belowLeft => true,
      OhosMagnifierSide.aboveRight || OhosMagnifierSide.belowRight => false,
      OhosMagnifierSide.auto => anchor.dx > screen.width / 2,
    };
    final bool? forcedAbove = switch (side) {
      OhosMagnifierSide.aboveLeft || OhosMagnifierSide.aboveRight => true,
      OhosMagnifierSide.belowLeft || OhosMagnifierSide.belowRight => false,
      OhosMagnifierSide.auto => null,
    };
    final List<bool> rows = <bool>[
      forcedAbove ?? true,
      !(forcedAbove ?? true),
    ];
    final List<bool> columns = <bool>[preferLeft, !preferLeft];

    for (final bool above in rows) {
      for (final bool left in columns) {
        final Offset candidate = _corner(anchor, size, gap, above, left);
        if (_fits(candidate, size, safe, screen)) {
          return OhosMagnifierPlacement(
            offset: candidate,
            size: size,
            side: _sideOf(above, left),
          );
        }
      }
    }

    // 四个角都放不下：用首选角，硬夹进安全区。
    final Offset fallback = _corner(
      anchor,
      size,
      gap,
      rows.first,
      columns.first,
    );
    final double maxLeft = screen.width - safe.right - size.width;
    final double maxTop = screen.height - safe.bottom - size.height;
    return OhosMagnifierPlacement(
      offset: Offset(
        math.min(math.max(fallback.dx, safe.left), math.max(safe.left, maxLeft)),
        math.min(math.max(fallback.dy, safe.top), math.max(safe.top, maxTop)),
      ),
      size: size,
      side: _sideOf(rows.first, columns.first),
    );
  }

  static Offset _corner(
    Offset anchor,
    Size size,
    double gap,
    bool above,
    bool left,
  ) {
    final double dy = above ? anchor.dy - gap - size.height : anchor.dy + gap;
    final double dx = left ? anchor.dx - gap - size.width : anchor.dx + gap;
    return Offset(dx, dy);
  }

  static bool _fits(Offset offset, Size size, EdgeInsets safe, Size screen) {
    return offset.dx >= safe.left &&
        offset.dy >= safe.top &&
        offset.dx + size.width <= screen.width - safe.right &&
        offset.dy + size.height <= screen.height - safe.bottom;
  }

  static OhosMagnifierSide _sideOf(bool above, bool left) {
    if (above) {
      return left ? OhosMagnifierSide.aboveLeft : OhosMagnifierSide.aboveRight;
    }
    return left ? OhosMagnifierSide.belowLeft : OhosMagnifierSide.belowRight;
  }
}
