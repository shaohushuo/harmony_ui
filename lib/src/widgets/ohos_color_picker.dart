import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';

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
  /// 光谱盒高度：手指坐标换算与指示器布局共用，避免两处各写一个 96。
  static const double _svHeight = 96;

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

  bool get _isFavorite => _favorites.any(
    (Color c) => c.toARGB32() == widget.selectedColor.toARGB32(),
  );

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
            OhosPressFeedback(
              onTap: _toggleFavorite,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 20,
                  // 收藏星是唯一的暖色装饰，灰阶屏上压成浅灰等于没点亮 ——
                  // 所以走「点亮」通道：`quantize(#F7CE00)` 约等于 #C3C3C3，
                  // 比未选中的 #767676 还淡，状态语义会反过来。`line()` 也不行，
                  // 它内部同样走量化。彩屏原样保留黄色，灰阶屏给与纸面反差
                  // 最大的实色。
                  color: _isFavorite
                      ? theme.policy.litFill(const Color(0xFFF7CE00))
                      : theme.textTertiaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 选中态对勾的颜色：跟着色块亮度走。
  ///
  /// 白勾画在白 / 浅色块上等于没画（墨屏压成灰阶后更明显），只有深色块才配白勾。
  /// 浅色块固定用纯黑，**不取 `theme.textPrimaryColor`** —— 深色主题里那个值
  /// 本身接近纯白，白勾会重新消失在浅色块上。
  Color _checkColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
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
                    border: color.toARGB32() == widget.selectedColor.toARGB32()
                        ? Border.all(color: theme.textPrimaryColor, width: 2)
                        : Border.fromBorderSide(
                            ohosSwatchOutline(context, theme, color),
                          ),
                  ),
                  child: color.toARGB32() == widget.selectedColor.toARGB32()
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: _checkColor(color),
                        )
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
    return OhosPressFeedback(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          // 未选中片的 6% 黑底在灰阶屏上等于没有，按「留白 + 实线」处理；
          // 选中那一档的 12% 黑只到第 2 级，比「留白加线」的未选中还弱，
          // 所以用描边主题时选中直接反相成实底。
          color: theme.usesOutlines
              ? (selected ? theme.dividerColor : Colors.transparent)
              : (selected
                    ? (theme.emphasizeSecondaryColor ??
                          theme.highlightColor.withValues(alpha: 0.12))
                    : theme.textPrimaryColor.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(12),
          border: theme.usesOutlines && !selected
              ? Border.fromBorderSide(
                  ohosBorderSide(
                    context,
                    theme.dividerColor,
                    width: theme.outlineWidth,
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: theme.typography.labelSmall?.copyWith(
            // 用描边的主题里选中是实底，文字跟着反相成背景色
            color: selected
                ? (theme.usesOutlines
                      ? theme.backgroundColor
                      : theme.highlightColor)
                : theme.textSecondaryColor,
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
              OhosPressFeedback(
                onTap: () => _select(color),
                borderRadius: BorderRadius.circular(size / 2),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: color.toARGB32() == widget.selectedColor.toARGB32()
                        ? Border.all(color: theme.textPrimaryColor, width: 3)
                        : Border.fromBorderSide(
                            ohosSwatchOutline(context, theme, color),
                          ),
                  ),
                  child: color.toARGB32() == widget.selectedColor.toARGB32()
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: _checkColor(color),
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
      children: <Widget>[_hueBar(), const SizedBox(height: 12), _svBox()],
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
    final OhosThemeData theme = OhosTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Color base = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
        final Size boxSize = Size(constraints.maxWidth, _svHeight);
        return GestureDetector(
          onTapDown: (TapDownDetails d) => _svAt(d.localPosition, boxSize),
          onPanDown: (DragDownDetails d) => _svAt(d.localPosition, boxSize),
          onPanUpdate: (DragUpdateDetails d) => _svAt(d.localPosition, boxSize),
          child: SizedBox(
            key: const Key('ohos-color-picker-sv-box'),
            height: _svHeight,
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
                        colors: const <Color>[Colors.white, Colors.transparent],
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
                  // 左上角是白色，白底卡片上无从分辨，补一条发丝线立住边界；
                  // 墨屏用纯黑，彩屏用 8% 黑。
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.fromBorderSide(
                        ohosBorderSide(
                          context,
                          theme.policy.line(
                            const Color(0xFF000000),
                            theme.usesOutlines ? 1 : 0.08,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _svIndicator(theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 光谱里的选中指示器。
  ///
  /// 纵坐标取反过一次：`Alignment.y = -1` 是**上边**，而 `value = 1`（最亮）
  /// 也在上边，直接用 `value * 2 - 1` 会让指示器跟手指反向跑。
  ///
  /// 白环外面再套一圈深色发丝线 —— 浅色区域靠它、深色区域靠白环，任何底色都
  /// 能看见（墨屏没有阴影可借用，纯黑发丝线就是唯一的分层手段）。
  Widget _svIndicator(OhosThemeData theme) {
    return Align(
      alignment: Alignment(_hsv.saturation * 2 - 1, 1 - _hsv.value * 2),
      child: Container(
        key: const Key('ohos-color-picker-sv-indicator'),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            ohosBorderSide(
              context,
              theme.policy.line(const Color(0xFF000000), 0.4),
            ),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    );
  }

  void _svAt(Offset local, Size size) {
    final double s = (local.dx / size.width).clamp(0.0, 1.0);
    // 纵向：上亮下暗，与指示器的 `1 - value * 2` 同一套坐标
    final double v = (1 - local.dy / size.height).clamp(0.0, 1.0);
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

  /// A tappable / draggable gradient bar with a round thumb, used by the hue
  /// band and the HSB sliders.
  ///
  /// 拇指是**比轨道高**的白圆（24 vs 18），不再是「刚好占满轨道高度的一块白」
  /// —— 后者会把轨道整段切断，看上去像浅色断裂成一块空白。拇指带一圈发丝线，
  /// 浅色端也能读出边界（墨屏纯黑、彩屏 25% 黑），彩屏另外保留一点投影，
  /// 墨屏不画（阴影在 16 级灰上只是一圈噪点）。
  Widget _gradientBar({
    required double value,
    required List<Color> colors,
    required double width,
    required ValueChanged<double> onChanged,
  }) {
    final OhosThemeData theme = OhosTheme.of(context);
    const double trackHeight = 18;
    const double thumbSize = 24;
    final double t = value.clamp(0.0, 1.0);
    // 拇指圆心留出半径，滑到两端时整圆仍落在轨道内，不会被父级裁掉半边
    final double centerX = thumbSize / 2 + t * (width - thumbSize);
    // 命中换算必须跟拇指行程用同一段区间：按整条宽度算的话，两端最大错位
    // 一个半径（指尖压在最左边，拇指却停在 12vp 处）。
    final double travel = (width - thumbSize).clamp(1.0, double.infinity);
    double getT(Offset local) =>
        ((local.dx - thumbSize / 2) / travel).clamp(0.0, 1.0);
    return GestureDetector(
      onTapDown: (TapDownDetails d) => onChanged(getT(d.localPosition)),
      onPanDown: (DragDownDetails d) => onChanged(getT(d.localPosition)),
      onPanUpdate: (DragUpdateDetails d) => onChanged(getT(d.localPosition)),
      child: SizedBox(
        height: thumbSize,
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              top: (thumbSize - trackHeight) / 2,
              height: trackHeight,
              child: DecoratedBox(
                key: const Key('ohos-color-picker-bar-track'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(trackHeight / 2),
                  gradient: LinearGradient(colors: colors),
                  // 渐变两端接近白色，没有这条线时轨道尽头就化进白底
                  border: Border.fromBorderSide(
                    ohosBorderSide(
                      context,
                      theme.policy.line(const Color(0xFF000000), 0.08),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: centerX - thumbSize / 2,
              top: 0,
              width: thumbSize,
              height: thumbSize,
              child: DecoratedBox(
                key: const Key('ohos-color-picker-bar-thumb'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    ohosBorderSide(
                      context,
                      theme.policy.line(const Color(0xFF000000), 0.25),
                    ),
                  ),
                  boxShadow: !theme.policy.allowsShadow
                      ? null
                      : const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ],
                ),
              ),
            ),
          ],
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
    final double idealPerRow =
        (maxWidth + spacing) / (widget.itemSize + spacing);
    if (idealPerRow >= targetPerRow) {
      return widget.itemSize;
    }
    final double fitted =
        (maxWidth - spacing * (targetPerRow - 1)) / targetPerRow;
    return fitted.clamp(18.0, widget.itemSize).toDouble();
  }
}
