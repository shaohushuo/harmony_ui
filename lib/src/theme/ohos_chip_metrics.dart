import 'package:flutter/foundation.dart';

/// Size classes of the ArkUI `Chip` component (`ChipSize`).
enum OhosChipSize {
  /// `ChipSize.NORMAL`.
  normal,

  /// `ChipSize.SMALL`.
  small,
}

/// Resolved geometry of a chip, in logical pixels.
///
/// These numbers are **not** self-authored: they are the terminal values of the
/// `sys.float` tokens that ArkUI's own `Chip` reads, resolved through
/// `pattern.json -> float_sys.json -> float.json` (see
/// `tool/fetch_sys_resources.sh` and `doc/source/README.md`).
///
/// | token                        | normal | small |
/// | ---------------------------- | ------ | ----- |
/// | `chip_normal_height`         | 36 vp  | 28 lpx |
/// | `chip_border_radius_*`       | 18 vp  | 14 vp |
/// | `chip_*_text_padding`        | 16     | 12    |
/// | `chip_*_text_margin`         | 6      | 4     |
/// | `chip_*_icon_size`           | 16     | 16    |
/// | `chip_*_font_size`           | 14 fp  | 14 fp |
///
/// Note the unit on the small height: it is `lpx`, not `vp`. The number is the
/// same but the semantic is a different unit, so don't write "28vp" anywhere.
///
/// Both [OhosChip] and [OhosChipGroup] read this class instead of each carrying
/// its own copy — they were two independent implementations once (the 0.5.0
/// stroke fix found that), which is exactly how they drifted apart in size.
@immutable
class OhosChipMetrics {
  const OhosChipMetrics({
    required this.height,
    required this.radius,
    required this.horizontalPadding,
    required this.iconGap,
    required this.iconSize,
    required this.fontSize,
  });

  /// Normal size: 36 vp tall, 18 vp corner radius.
  static const OhosChipMetrics normal = OhosChipMetrics(
    height: 36,
    radius: 18,
    horizontalPadding: 16,
    iconGap: 6,
    iconSize: 16,
    fontSize: 14,
  );

  /// Small size: 28 lpx tall (`lpx`, not `vp`), 14 vp corner radius.
  static const OhosChipMetrics small = OhosChipMetrics(
    height: 28,
    radius: 14,
    horizontalPadding: 12,
    iconGap: 4,
    iconSize: 16,
    fontSize: 14,
  );

  /// Capsule height.
  final double height;

  /// Corner radius — **not** `height / 2`, despite the capsule look. ArkUI
  /// ships explicit radii (18 / 14), so a chip stays visually a capsule only
  /// because 36/2 == 18 and 28/2 == 14 happen to agree.
  final double radius;

  /// Leading and trailing padding inside the capsule.
  final double horizontalPadding;

  /// Gap between the leading icon and the label (`chip_*_text_margin`).
  final double iconGap;

  /// Rendered size of the leading icon.
  final double iconSize;

  /// Label font size, in fp-equivalent logical pixels.
  final double fontSize;

  /// Resolves the metrics for [size].
  static OhosChipMetrics of(OhosChipSize size) =>
      size == OhosChipSize.small ? small : normal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OhosChipMetrics &&
          other.height == height &&
          other.radius == radius &&
          other.horizontalPadding == horizontalPadding &&
          other.iconGap == iconGap &&
          other.iconSize == iconSize &&
          other.fontSize == fontSize;

  @override
  int get hashCode => Object.hash(
    height,
    radius,
    horizontalPadding,
    iconGap,
    iconSize,
    fontSize,
  );
}
