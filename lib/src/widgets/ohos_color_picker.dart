import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// Tab / mode of the [OhosColorPicker], mirroring `HdsColorPickerTabType`.
enum OhosColorPickerTab {
  /// 网格模式：preset color grid for quick selection.
  grid,

  /// 光谱模式：hue band + saturation/value spectrum for fine tuning.
  spectrum,

  /// 滑块模式：HSB sliders for precise adjustment.
  sliders,
}

/// A palette-style color picker (色彩选择器) built on the HarmonyOS
/// multi-color system, the Flutter counterpart of `HdsColorPicker`.
///
/// Supports the three official modes — grid (预设网格), spectrum (色相/饱和度
/// 光谱) and sliders (HSB 滑块) — plus a favorites (收藏) strip. The legacy
/// grid-only API (`colors` / `selectedColor` / `onChanged`) stays unchanged.
class OhosColorPicker extends StatefulWidget {
  const OhosColorPicker({
    super.key,
    required this.colors,
    required this.selectedColor,
    required this.onChanged,
    this.itemSize = 36,
    this.circleRadius = 12,
    this.tabs = const <OhosColorPickerTab>[OhosColorPickerTab.grid],
    this.activeTab = OhosColorPickerTab.grid,
    this.favoriteColors = const <Color>[],
    this.onFavoritesChanged,
  });

  /// Preset colors of the grid mode.
  final List<Color> colors;

  /// Currently selected color.
  final Color selectedColor;

  /// Called when the user picks a color.
  final ValueChanged<Color> onChanged;

  /// Diameter of each grid dot.
  final double itemSize;

  /// Corner radius of color preview chips (spectrum / favorites).
  final double circleRadius;

  /// Modes to expose; when more than one, a small tab strip is shown.
  final List<OhosColorPickerTab> tabs;

  /// Initially active mode.
  final OhosColorPickerTab activeTab;

  /// Initial favorite color list.
  final List<Color> favoriteColors;

  /// Called when the favorites list changes.
  final ValueChanged<List<Color>>? onFavoritesChanged;

  @override
  State<OhosColorPicker> createState() => _OhosColorPickerState();
}

class _OhosColorPickerState extends State<OhosColorPicker> {
  late OhosColorPickerTab _activeTab;
  late List<Color> _favorites;
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.activeTab;
    _favorites = List<Color>.of(widget.favoriteColors);
    _hsv = HSVColor.fromColor(widget.selectedColor);
  }

  @override
  void didUpdateWidget(covariant OhosColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColor != widget.selectedColor) {
      _hsv = HSVColor.fromColor(widget.selectedColor);
    }
  }

  void _select(Color color) {
    setState(() => _hsv = HSVColor.fromColor(color));
    widget.onChanged(color);
  }

  bool get _isFavorite =>
      _favorites.any((Color c) => c.toARGB32() == widget.selectedColor.toARGB32());

  void _toggleFavorite() {
    final int target = widget.selectedColor.toARGB32();
    if (_isFavorite) {
      _favorites.removeWhere((Color c) => c.toARGB32() == target);
    } else {
      _favorites = <Color>[..._favorites, widget.selectedColor];
    }
    setState(() {});
    widget.onFavoritesChanged?.call(List<Color>.of(_favorites));
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final List<OhosColorPickerTab> tabs = widget.tabs;
    final Color fg = _hsv.toColor();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_favorites.isNotEmpty) _favoritesRow(theme),
        if (_favorites.isNotEmpty) const SizedBox(height: 12),
        if (tabs.length > 1) ...<Widget>[
          _tabStrip(theme),
          const SizedBox(height: 10),
        ],
        _buildActive(theme),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '#${fg.toARGB32().toRadixString(16).padLeft(8, '0')}',
                style: theme.typography.labelSmall?.copyWith(
                  color: theme.textSecondaryColor,
                ),
              ),
            ),
            InkWell(
              onTap: _toggleFavorite,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  color: _isFavorite
                      ? const Color(0xFFF7CE00)
                      : theme.textTertiaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _favoritesRow(OhosThemeData theme) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final Color color in _favorites)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () => _select(color),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.toARGB32() ==
                              widget.selectedColor.toARGB32()
                          ? theme.textPrimaryColor
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: color.toARGB32() ==
                          widget.selectedColor.toARGB32()
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabStrip(OhosThemeData theme) {
    return Row(
      children: <Widget>[
        for (final OhosColorPickerTab tab in widget.tabs) ...<Widget>[
          _tabChip(tab, theme),
          const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _tabChip(OhosColorPickerTab tab, OhosThemeData theme) {
    final bool selected = tab == _activeTab;
    final String label = switch (tab) {
      OhosColorPickerTab.grid => '网格',
      OhosColorPickerTab.spectrum => '光谱',
      OhosColorPickerTab.sliders => '滑块',
    };
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? (theme.emphasizeSecondaryColor ??
                    theme.highlightColor.withValues(alpha: 0.12))
              : theme.textPrimaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.typography.labelSmall?.copyWith(
            color: selected ? theme.highlightColor : theme.textSecondaryColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildActive(OhosThemeData theme) {
    return switch (_activeTab) {
      OhosColorPickerTab.grid => _gridMode(theme),
      OhosColorPickerTab.spectrum => _spectrumMode(),
      OhosColorPickerTab.sliders => _slidersMode(),
    };
  }

  Widget _gridMode(OhosThemeData theme) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double size = _fitItemSize(constraints.maxWidth);
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            for (final Color color in widget.colors)
              InkWell(
                onTap: () => _select(color),
                customBorder: const CircleBorder(),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.toARGB32() ==
                              widget.selectedColor.toARGB32()
                          ? theme.textPrimaryColor
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: color.toARGB32() ==
                          widget.selectedColor.toARGB32()
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _spectrumMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _hueBar(),
        const SizedBox(height: 12),
        _svBox(),
      ],
    );
  }

  Widget _hueBar() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return _gradientBar(
          value: _hsv.hue / 360,
          colors: const <Color>[
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
          width: constraints.maxWidth,
          onChanged: (double t) {
            setState(() => _hsv = _hsv.withHue(t * 360));
            widget.onChanged(_hsv.toColor());
          },
        );
      },
    );
  }


  Widget _svBox() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Color base = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
        return GestureDetector(
          onTapDown: (TapDownDetails d) => _svAt(d.localPosition, constraints.maxWidth),
          onPanDown: (DragDownDetails d) => _svAt(d.localPosition, constraints.maxWidth),
          onPanUpdate: (DragUpdateDetails d) => _svAt(d.localPosition, constraints.maxWidth),
          child: SizedBox(
            height: 96,
            width: constraints.maxWidth,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: base),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: const <Color>[
                          Colors.white,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(
                      _hsv.saturation * 2 - 1,
                      _hsv.value * 2 - 1,
                    ),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(color: Colors.black26, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _svAt(Offset local, double width) {
    final double s = (local.dx / width).clamp(0.0, 1.0);
    final double v = (1 - local.dy / 96).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
    widget.onChanged(_hsv.toColor());
  }

  Widget _slidersMode() {
    return Column(
      children: <Widget>[
        _hsbSlider(
          label: '色相',
          value: _hsv.hue / 360,
          colors: const <Color>[
            Color(0xFFFF0000),
            Color(0xFFFFFF00),
            Color(0xFF00FF00),
            Color(0xFF00FFFF),
            Color(0xFF0000FF),
            Color(0xFFFF00FF),
            Color(0xFFFF0000),
          ],
          onChanged: (double t) {
            setState(() => _hsv = _hsv.withHue(t * 360));
            widget.onChanged(_hsv.toColor());
          },
        ),
        const SizedBox(height: 10),
        _hsbSlider(
          label: '饱和度',
          value: _hsv.saturation,
          colors: <Color>[
            HSVColor.fromAHSV(1, _hsv.hue, 0, 1).toColor(),
            HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
          ],
          onChanged: (double t) {
            setState(() => _hsv = _hsv.withSaturation(t));
            widget.onChanged(_hsv.toColor());
          },
        ),
        const SizedBox(height: 10),
        _hsbSlider(
          label: '明度',
          value: _hsv.value,
          colors: <Color>[
            HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 0).toColor(),
            HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor(),
          ],
          onChanged: (double t) {
            setState(() => _hsv = _hsv.withValue(t));
            widget.onChanged(_hsv.toColor());
          },
        ),
      ],
    );
  }

  Widget _hsbSlider({
    required String label,
    required double value,
    required List<Color> colors,
    required ValueChanged<double> onChanged,
  }) {
    final OhosThemeData theme = OhosTheme.of(context);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: theme.typography.labelSmall?.copyWith(
              color: theme.textSecondaryColor,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return _gradientBar(
                value: value,
                colors: colors,
                width: constraints.maxWidth,
                onChanged: onChanged,
              );
            },
          ),
        ),
      ],
    );
  }

  /// A tappable / draggable gradient bar with a white thumb, used by the hue
  /// band and the HSB sliders.
  Widget _gradientBar({
    required double value,
    required List<Color> colors,
    required double width,
    required ValueChanged<double> onChanged,
  }) {
    double getT(Offset local) => (local.dx / width).clamp(0.0, 1.0);
    return GestureDetector(
      onTapDown: (TapDownDetails d) => onChanged(getT(d.localPosition)),
      onPanDown: (DragDownDetails d) => onChanged(getT(d.localPosition)),
      onPanUpdate: (DragUpdateDetails d) => onChanged(getT(d.localPosition)),
      child: SizedBox(
        height: 18,
        width: width,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
              ),
              Align(
                alignment: Alignment(value.clamp(0.0, 1.0) * 2 - 1, 0),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.black26, width: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shrinks the grid dots when the container is too narrow, so the picker
  /// never overflows (e.g. inside a `Row`/`Expanded` on narrow screens).
  double _fitItemSize(double maxWidth) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return widget.itemSize;
    }
    const double spacing = 14;
    const int targetPerRow = 5;
    if (widget.colors.length <= targetPerRow) {
      return widget.itemSize;
    }
    final double idealPerRow = (maxWidth + spacing) / (widget.itemSize + spacing);
    if (idealPerRow >= targetPerRow) {
      return widget.itemSize;
    }
    final double fitted =
        (maxWidth - spacing * (targetPerRow - 1)) / targetPerRow;
    return fitted.clamp(18.0, widget.itemSize).toDouble();
  }
}
