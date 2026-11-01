import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_icon_button.dart';
import 'ohos_menu.dart';

/// 一键在「普通主题」与「墨水屏主题」之间切换的按钮。
///
/// 放进任意 `OhosAppBar.actions` 即可，不需要额外接线 —— 档位就在
/// [controller] 这一个对象里，切换后整棵树通过 [OhosThemeSwitcher] 重建。
///
/// 点按直接翻转（长按 / 右键则弹出三档菜单），因为这是最高频的动作；
/// 三档选择是次要路径，藏在菜单里。
///
/// ```dart
/// OhosAppBar(
///   title: const Text('示例'),
///   actions: <Widget>[OhosThemeToggleButton(controller: controller)],
/// );
/// ```
class OhosThemeToggleButton extends StatelessWidget {
  const OhosThemeToggleButton({
    super.key,
    required this.controller,
    this.showMenuOnLongPress = true,
    this.size = 48,
    this.iconSize = 24,
  });

  /// 要操作的档位持有者。
  final OhosThemeController controller;

  /// 长按弹出「浅色 / 深色 / 墨水屏」三选一菜单，默认开启。
  ///
  /// 关掉后长按无动作，点按仍是二态翻转。
  final bool showMenuOnLongPress;

  /// 触摸区域边长。
  final double size;

  /// 图标尺寸。
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final OhosThemeData theme = controller.themeData;
        // 菜单要贴在按钮上，所以 anchor 得是按钮自己的 context。
        return Builder(
          builder: (BuildContext anchorContext) => OhosIconButton(
            icon: Icon(_iconOf(controller.mode, theme)),
            tooltip: _tooltipOf(controller.mode, theme),
            size: size,
            iconSize: iconSize,
            onPressed: controller.toggle,
            onLongPress: showMenuOnLongPress
                ? () => _pick(anchorContext, controller.mode)
                : null,
          ),
        );
      },
    );
  }

  /// 图标由「档位 + 主题自身」共同决定，没有使用档位时退回按亮度推导。
  ///
  /// 刻意**不写**穷举 switch：那样给 `OhosThemeMode` 加第四档时，这个 widget
  /// 会编译失败，等于把「加主题」变成「改组件」。这里对未知档位一律走兜底
  /// 推导（有描边 → 对比度图标，否则按明暗），新档位最多是图标不够贴切，
  /// 不会中断构建。
  static IconData _iconOf(OhosThemeMode? mode, OhosThemeData theme) {
    if (mode == OhosThemeMode.light) {
      return Icons.light_mode_outlined;
    }
    if (mode == OhosThemeMode.dark) {
      return Icons.dark_mode_outlined;
    }
    if (mode == OhosThemeMode.ink) {
      return Icons.contrast_rounded;
    }
    if (theme.policy.isMonochrome || theme.usesOutlines) {
      return Icons.contrast_rounded;
    }
    return theme.brightness == Brightness.dark
        ? Icons.dark_mode_outlined
        : Icons.light_mode_outlined;
  }

  static String _tooltipOf(OhosThemeMode? mode, OhosThemeData theme) {
    final String name =
        mode?.label ??
        (theme.policy.isMonochrome
            ? '墨水屏'
            : theme.brightness == Brightness.dark
            ? '深色'
            : '浅色');
    return '主题：$name（点按切换墨水屏）';
  }

  Future<void> _pick(BuildContext anchorContext, OhosThemeMode? current) async {
    final OhosThemeMode? picked = await showOhosMenu<OhosThemeMode>(
      context: anchorContext,
      anchor: anchorContext,
      items: <OhosMenuItem<OhosThemeMode>>[
        for (final OhosThemeMode mode in OhosThemeMode.values)
          OhosMenuItem<OhosThemeMode>(
            label: mode.label,
            value: mode,
            icon: mode == current ? Icons.check_rounded : null,
          ),
      ],
    );
    if (picked != null) {
      // useMode 会自己分流「彩屏档位要记住 / 墨水屏不记住」。
      controller.useMode(picked);
    }
  }
}