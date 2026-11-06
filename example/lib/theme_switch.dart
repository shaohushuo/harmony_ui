import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

/// 画廊的皮肤档位，由 `OhosThemeController` 持有。
///
/// 包住 `MaterialApp` 的那层 `OhosTheme` 跟随它重建，所以在任何页面点顶栏
/// 右上角的按钮，都能立刻看到同一组组件在各类主题下的样子。
///
/// 默认停在彩屏：这是组件的常态外观，也是 README 主截图的取景档位。墨屏是
/// 「同一套组件换一块屏」的对照，**用右上角按钮一键切过去**看，不该让人一
/// 进来就先点一下才见到正常样子。
final OhosThemeController galleryTheme = OhosThemeController(
  initialMode: OhosThemeMode.light,
  fontFamily: galleryFontFamily,
);

/// 全画廊统一的字体族。鸿蒙设备自带，其他平台由 Flutter 回退到系统字体。
const String galleryFontFamily = 'HarmonyOS Sans';

/// 切到**深色墨水屏**（黑底白字的电子纸），用于演示「令牌明暗」与「表现规则」
/// 两维正交。
///
/// 它不进 [OhosThemeMode] 枚举：深色墨水屏不是「用户会主动选的第 5 档」，而是
/// 墨水屏这一档的另一种色值。走 `custom()` 让画廊能切过去看，同时保留
/// [galleryTheme] 原来的彩屏/墨屏来回能力。
///
/// 从深色墨屏 toggle 出来会落到 [OhosThemeData.light]（`custom()` 在传入主题
/// 本身是墨屏时把「普通」侧播种成内置浅色）—— 这是刻意的：切换按钮的职责是
/// 「在彩屏与墨屏之间翻转」，不该因为当前这份墨屏恰好是深色纸就停在原地。
void showDarkInk() {
  galleryTheme.setColorTheme(
    OhosThemeData.ink(
      fontFamily: galleryFontFamily,
      brightness: Brightness.dark,
    ),
    mode: OhosThemeMode.ink,
  );
}

/// 顶栏右侧的主题切换按钮。
///
/// 比库里那个 [OhosThemeToggleButton] 多一层「彩屏内部也要能切明暗」：
///
/// - **点按**按 浅色 → 深色 → 墨水屏 → 浅色 循环
/// - **长按**弹菜单，列出全部档位（含深色墨水屏）并给当前档打勾
///
/// 为什么不直接用 [OhosThemeToggleButton]：它的点按语义是「在彩屏与墨水屏之间
/// 翻转」，深色只能进长按菜单里翻。对一个用来**看组件长什么样**的画廊来说，
/// 深色是和墨水屏同等重要的一等对照项（README 里两套截图并列），把它藏在长按
/// 里等于默认它不存在 —— 实测点一下就从浅色跳到墨屏，深色那一档根本走不到。
///
/// 打开菜单用非穷举推导拿当前项，理由与库内一致：给 `OhosThemeMode` 加档位时
/// 这个文件不该跟着编译失败。
class ThemeSwitchButton extends StatefulWidget {
  const ThemeSwitchButton({super.key});

  @override
  State<ThemeSwitchButton> createState() => _ThemeSwitchButtonState();
}

class _ThemeSwitchButtonState extends State<ThemeSwitchButton> {
  /// 点按循环的档位顺序。
  ///
  /// 深色排在墨水屏**前面**：它保留全部颜色，只是明暗翻转，离浅色更近；
  /// 墨水屏换的是整块屏的表现规则，排在最后当「另一类东西」。
  static const List<OhosThemeMode> _cycle = <OhosThemeMode>[
    OhosThemeMode.light,
    OhosThemeMode.dark,
    OhosThemeMode.ink,
  ];

  /// 菜单项。深色墨水屏不进枚举，所以在菜单里单列一条伪档位。
  static const String _darkInkLabel = '深色墨水屏';

  void _cycleNext() {
    final OhosThemeMode? current = galleryTheme.mode;
    // 自定义主题（例如当前正停在深色墨水屏）没有档位：回浅色，与
    // `OhosThemeController.toggle()` 对自定义主题的处理一致 —— 按钮的职责是
    // 往前走一步，不是停在一块屏上。
    if (current == null) {
      galleryTheme.useMode(OhosThemeMode.light);
      return;
    }
    final int index = _cycle.indexOf(current);
    galleryTheme.useMode(_cycle[(index + 1) % _cycle.length]);
  }

  Future<void> _openMenu() async {
    // 菜单要贴在按钮上，anchor 得是按钮自己的 context。
    final BuildContext anchorContext = context;
    final OhosThemeMode? current = galleryTheme.mode;

    final String? picked = await showOhosMenu<String>(
      context: anchorContext,
      anchor: anchorContext,
      items: <OhosMenuItem<String>>[
        for (final OhosThemeMode mode in OhosThemeMode.values)
          OhosMenuItem<String>(
            label: mode.label,
            value: mode.name,
            icon: mode == current ? Icons.check_rounded : null,
          ),
        // 深色墨水屏单列一条：它不在枚举里，但画廊要能一键看到。
        OhosMenuItem<String>(
          label: _darkInkLabel,
          value: 'ink_dark',
          icon: current == null && galleryTheme.themeData.isDark
              ? Icons.check_rounded
              : null,
        ),
      ],
    );

    if (picked == null) {
      return;
    }
    if (picked == 'ink_dark') {
      showDarkInk();
      return;
    }
    // 非穷举推导：枚举将来加档位时这里最多是「不认识」，不该编译失败。
    for (final OhosThemeMode mode in OhosThemeMode.values) {
      if (mode.name == picked) {
        // useMode 会自己分流「彩屏档位要记住 / 墨水屏不记住」。
        galleryTheme.useMode(mode);
        return;
      }
    }
  }

  /// 图标按档位给；没有档位（自定义主题）时按主题自身推导。
  ///
  /// 深色墨屏与浅色墨屏要区分：只按 `isMonochrome` 判会都画成同一个对比度
  /// 图标，切到深色纸时按钮看起来没反应。
  IconData _iconOf() {
    final OhosThemeMode? mode = galleryTheme.mode;
    if (mode == OhosThemeMode.light) {
      return Icons.light_mode_outlined;
    }
    if (mode == OhosThemeMode.dark) {
      return Icons.dark_mode_outlined;
    }
    if (mode == OhosThemeMode.system) {
      return Icons.brightness_auto_outlined;
    }
    if (mode == OhosThemeMode.ink) {
      return galleryTheme.themeData.isDark
          ? Icons.nightlight_round
          : Icons.contrast_rounded;
    }
    // 自定义主题：墨屏画对比度、彩屏按亮度。
    final OhosThemeData theme = galleryTheme.themeData;
    if (theme.policy.isMonochrome) {
      return theme.isDark ? Icons.nightlight_round : Icons.contrast_rounded;
    }
    return theme.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined;
  }

  String _tooltipOf() {
    final String name =
        galleryTheme.mode?.label ??
        (galleryTheme.themeData.isDark ? '深色墨水屏' : '自定义主题');
    return '主题：$name（点按循环，长按选档）';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: galleryTheme,
      builder: (BuildContext context, Widget? child) => OhosIconButton(
        icon: Icon(_iconOf()),
        tooltip: _tooltipOf(),
        onPressed: _cycleNext,
        onLongPress: _openMenu,
      ),
    );
  }
}
