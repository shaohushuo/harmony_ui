import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

/// 包住 `MaterialApp` 的那层 `OhosTheme` 跟随它重建，所以在任何页面点顶栏
/// 右上角的按钮，都能立刻看到同一组组件在三种主题下的样子。
///
/// 默认停在墨主题：这一轮改动（1px 描边、分割线、灰阶对比度）都是为它做的，
/// 打开演示程序即可对照，不用先点两下。
final ValueNotifier<GalleryTheme> galleryTheme =
    ValueNotifier<GalleryTheme>(GalleryTheme.ink);

/// 画廊里可选的主题档位。
enum GalleryTheme {
  light('浅色'),
  dark('深色'),
  ink('墨主题');

  const GalleryTheme(this.label);

  /// 菜单里显示的名字，也用来拼按钮的 tooltip。
  final String label;

  /// 这一档对应的组件主题。
  OhosThemeData get data => switch (this) {
    GalleryTheme.light => OhosThemeData.light(fontFamily: _fontFamily),
    GalleryTheme.dark => OhosThemeData.dark(fontFamily: _fontFamily),
    GalleryTheme.ink => OhosThemeData.ink(fontFamily: _fontFamily),
  };

  /// Material 侧的主题：只负责 `Scaffold` / 弹窗这类还没换成 Ohos 组件的
  /// 默认底色与文字色，组件本身一律走 [OhosThemeData]。
  ThemeData get materialTheme => ThemeData(
    brightness: this == GalleryTheme.dark
        ? Brightness.dark
        : Brightness.light,
    fontFamily: _fontFamily,
  );
}

const String _fontFamily = 'HarmonyOS Sans';

/// 顶栏右侧的主题切换按钮：点开是「浅色 / 深色 / 墨主题」三选一，当前档位打勾。
///
/// 宿主把它塞进任意 `OhosAppBar.actions` 即可，不用另接参数 —— 状态就在
/// [galleryTheme] 这一个 `ValueNotifier` 里。
class ThemeSwitchButton extends StatelessWidget {
  const ThemeSwitchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GalleryTheme>(
      valueListenable: galleryTheme,
      builder: (BuildContext context, GalleryTheme current, Widget? child) {
        // 菜单要贴在按钮上，所以 anchor 得是按钮自己的 context。
        return Builder(
          builder: (BuildContext anchorContext) => OhosIconButton(
            icon: Icon(_iconOf(current)),
            tooltip: '主题：${current.label}',
            onPressed: () => _pick(anchorContext, current),
          ),
        );
      },
    );
  }

  static IconData _iconOf(GalleryTheme theme) => switch (theme) {
    GalleryTheme.light => Icons.light_mode_outlined,
    GalleryTheme.dark => Icons.dark_mode_outlined,
    GalleryTheme.ink => Icons.contrast_rounded,
  };

  static Future<void> _pick(
    BuildContext anchorContext,
    GalleryTheme current,
  ) async {
    final GalleryTheme? picked = await showOhosMenu<GalleryTheme>(
      context: anchorContext,
      anchor: anchorContext,
      items: <OhosMenuItem<GalleryTheme>>[
        for (final GalleryTheme theme in GalleryTheme.values)
          OhosMenuItem<GalleryTheme>(
            label: theme.label,
            value: theme,
            icon: theme == current ? Icons.check_rounded : null,
          ),
      ],
    );
    if (picked != null) {
      galleryTheme.value = picked;
    }
  }
}
