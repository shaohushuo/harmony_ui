import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

/// 画廊的皮肤档位，由 `OhosThemeController` 持有。
///
/// 包住 `MaterialApp` 的那层 `OhosTheme` 跟随它重建，所以在任何页面点顶栏
/// 右上角的按钮，都能立刻看到同一组组件在三种主题下的样子。
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