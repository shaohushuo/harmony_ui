import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

/// 画廊的皮肤档位，由 `OhosThemeController` 持有。
///
/// 包住 `MaterialApp` 的那层 `OhosTheme` 跟随它重建，所以在任何页面点顶栏
/// 右上角的按钮，都能立刻看到同一组组件在三种主题下的样子。
///
/// 默认停在墨主题：这一轮改动（1px 描边、分割线、灰阶对比度）都是为它做的，
/// 打开演示程序即可对照，不用先点两下。
final OhosThemeController galleryTheme = OhosThemeController(
  initialMode: OhosThemeMode.ink,
  fontFamily: galleryFontFamily,
);

/// 全画廊统一的字体族。鸿蒙设备自带，其他平台由 Flutter 回退到系统字体。
const String galleryFontFamily = 'HarmonyOS Sans';

/// 顶栏右侧的主题切换按钮。
///
/// 点按在「当前彩屏档位 ↔ 墨水屏」之间一键来回；长按弹出三档菜单。档位存在
/// [galleryTheme] 里，宿主把它塞进任意 `OhosAppBar.actions` 即可。
class ThemeSwitchButton extends StatelessWidget {
  const ThemeSwitchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OhosThemeToggleButton(controller: galleryTheme);
  }
}