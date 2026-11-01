import 'package:flutter/material.dart';

export 'ohos_theme_data.dart';
export 'ohos_visual_policy.dart';

import 'ohos_theme_data.dart';
import 'ohos_visual_policy.dart';

/// Inherited widget that provides an [OhosThemeData] to the subtree, the
/// `ohos_ui` counterpart of Flutter's [Theme].
class OhosTheme extends InheritedWidget {
  const OhosTheme({super.key, required this.data, required super.child});

  /// Design tokens for the subtree.
  final OhosThemeData data;

  /// Returns the [OhosThemeData] from the closest enclosing [OhosTheme], or a
  /// light fallback theme when none exists.
  static OhosThemeData of(BuildContext context) {
    final OhosTheme? theme = context
        .dependOnInheritedWidgetOfExactType<OhosTheme>();
    return theme?.data ?? OhosThemeData.light();
  }

  /// Returns the [OhosThemeData] from the closest enclosing [OhosTheme] in an
  /// ancestor, without creating a dependency.
  static OhosThemeData? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<OhosTheme>()?.data;
  }

  @override
  bool updateShouldNotify(OhosTheme oldWidget) => data != oldWidget.data;
}

/// 应用的皮肤档位：普通（浅色 / 深色）与墨水屏。
///
/// 只有三档，是因为墨水屏不是「深色」的一个变体 —— 它是浅色（黑字白纸）
/// 换了一套表现规则（[OhosVisualPolicy]）。把两者当同一根轴上的取值会让
/// 「深色墨水屏」这类未来需求无处安放。
///
/// ```dart
/// // 1. 建一个控制器（`main()` 里建，或挂在状态管理里）
/// final OhosThemeController theme = OhosThemeController();
///
/// // 2. 包住 MaterialApp
/// OhosThemeSwitcher(
///   controller: theme,
///   builder: (context, material) => MaterialApp(theme: material, home: ...),
/// );
///
/// // 3. 顶栏放一个按钮，点一下就在普通 / 水墨之间翻转
/// OhosAppBar(actions: <Widget>[OhosThemeToggleButton(controller: theme)]);
/// ```
enum OhosThemeMode {
  /// Colored light theme.
  light('浅色'),

  /// Colored dark theme.
  dark('深色'),

  /// E-ink: pure black on pure white, 1px outlines instead of layered surfaces.
  ink('墨水屏');

  const OhosThemeMode(this.label);

  /// Human-readable name, e.g. for a menu entry or a tooltip.
  final String label;

  /// 这一档是不是灰阶屏。给「整体压成黑白」的少数场景用（如彩页预览）。
  bool get isMonochrome => this == OhosThemeMode.ink;

  /// 构造这一档对应的主题数据。
  OhosThemeData theme({String? fontFamily}) => switch (this) {
    OhosThemeMode.light => OhosThemeData.light(fontFamily: fontFamily),
    OhosThemeMode.dark => OhosThemeData.dark(fontFamily: fontFamily),
    OhosThemeMode.ink => OhosThemeData.ink(fontFamily: fontFamily),
  };
}

/// 主题档位的持有者：改一次 [mode]，整棵子树跟着重建。
///
/// 放在 `MaterialApp` **上面**（见 [OhosThemeSwitcher]），这样 push 出去的页面
/// 也能拿到新主题 —— 挂在 `home:` 里的 `OhosTheme` 传不到 Navigator 的兄弟
/// 节点，页面会静默退回默认浅色。
///
/// ```dart
/// final OhosThemeController controller = OhosThemeController();
///
/// OhosThemeSwitcher(
///   controller: controller,
///   builder: (BuildContext context, ThemeData material) => MaterialApp(
///     theme: material,
///     home: const HomePage(),
///   ),
/// );
///
/// // 任何位置，包括任意页面：
/// controller.toggle();
/// ```
///
/// 继承 [ChangeNotifier] 而不是自己造一套通知，是为了能直接喂给
/// `AnimatedBuilder` / `ListenableBuilder`。切换时还会额外通知一次
/// [materialThemeOf]，让依附 Material 的组件（`Scaffold` 底色、还没换成
/// Ohos 组件的弹窗）一起翻。
class OhosThemeController extends ChangeNotifier {
  /// 用内置档位初始化。
  ///
  /// 只有内置三档够用时用这个；要自定义主题（品牌色、第四种屏幕）请用
  /// [OhosThemeController.custom]，那里直接持有 [OhosThemeData]。
  OhosThemeController({
    OhosThemeMode initialMode = OhosThemeMode.light,
    this.fontFamily,
  }) : _theme = initialMode.theme(fontFamily: fontFamily),
       _mode = initialMode;

  /// 用任意主题数据初始化 —— 自定义主题、以及将来新增的主题预设都走这里。
  ///
  /// [theme] 可以是 `OhosThemeData.light().copyWith(...)`，也可以是完全手写的
  /// 一份。切换按钮在 [mode] 为 null 时只显示当前主题，不提供三选一菜单。
  OhosThemeController.custom(OhosThemeData theme, {this.fontFamily})
    : _theme = theme,
      _mode = null;

  /// 当前档位。用 [OhosThemeController.custom] 构造时为 null。
  OhosThemeMode? _mode;

  /// 当前主题数据。任何来源（内置档位或自定义）都在这里收敛。
  OhosThemeData _theme;

  /// 上一次停留在哪个彩屏**主题**，供 [toggle] 从墨水屏切回来时用。
  ///
  /// 存的是 [OhosThemeData] 而不是档位：从自定义主题切到墨水屏再切回来，
  /// 应该回到那份自定义主题，而不是掉回某个内置预设。
  OhosThemeData _lastColorTheme = OhosThemeData.light();

  /// 与 [_lastColorTheme] 配套的档位。自定义主题没有档位，所以是 nullable。
  OhosThemeMode? _lastColorMode = OhosThemeMode.light;

  /// 字体族，透传给 [OhosTypography]。
  final String? fontFamily;

  /// 当前档位。自定义主题为 null —— 调用方 switch 它之前先判空。
  OhosThemeMode? get mode => _mode;

  /// 当前主题数据。
  OhosThemeData get themeData => _theme;

  /// 当前档位对应的 Material 主题。
  ///
  /// 只交给 `MaterialApp.theme`，负责 `Scaffold` / 弹窗这类还没换成 Ohos
  /// 组件的默认底色与文字色；组件本身一律走 [themeData]。
  ThemeData get materialTheme => ThemeData(
    brightness: _theme.brightness,
    fontFamily: fontFamily,
  );

  /// 切到指定档位。与当前相同时不通知。
  set mode(OhosThemeMode value) {
    useTheme(value.theme(fontFamily: fontFamily), mode: value);
  }

  /// 切到任意主题数据。这是唯一的真正入口，其余方法都收敛到这里。
  ///
  /// 用值比较判断是否真有变化：[OhosThemeData] 重载了 `==`，所以传一份
  /// 「字段完全相同」的新实例不会触发重建。
  void useTheme(OhosThemeData theme, {OhosThemeMode? mode}) {
    if (_theme == theme) {
      _mode = mode;
      return;
    }
    _theme = theme;
    _mode = mode;
    notifyListeners();
  }

  /// 设置具体的主题数据，并让 [toggle] 记住它作为「普通」那一侧。
  ///
  /// 这是给「我的普通主题是品牌色」这类场景用的：设完之后 [toggle] 会在
  /// 这份自定义主题与墨水屏之间来回，而不是在两个内置预设之间来回。
  void setColorTheme(OhosThemeData theme, {OhosThemeMode? mode}) {
    _lastColorTheme = theme;
    _lastColorMode = mode;
    useTheme(theme, mode: mode);
  }

  /// 在「普通」与「墨水屏」之间一键来回。
  ///
  /// 「普通」指上一次用过的彩屏主题：[light] → [ink] 之后回来仍是那份浅色，
  /// 深色或自定义品牌主题同理，不会把用户拽回某个内置预设。
  void toggle() {
    if (_theme.policy.isMonochrome) {
      useTheme(_lastColorTheme, mode: _lastColorMode);
    } else {
      _lastColorTheme = _theme;
      _lastColorMode = _mode;
      useTheme(
        OhosThemeData.ink(fontFamily: fontFamily),
        mode: OhosThemeMode.ink,
      );
    }
  }

  /// 切换到指定的彩屏档位（浅色 / 深色），同时记住它。
  void setColorMode(OhosThemeMode value) {
    assert(
      !value.isMonochrome,
      'setColorMode 只接受彩屏档位；切墨水屏请用 mode = ... 或 toggle()',
    );
    setColorTheme(value.theme(fontFamily: fontFamily), mode: value);
  }

  /// 切到某个内置档位，自动判断它该记住还是不记住。
  ///
  /// 彩屏档位会写进 [toggle] 的「普通」那一侧，墨水屏不会 —— 这样从深色切到
  /// 墨水屏再切回来仍然是深色。菜单类 UI 直接用这个，不必自己分流。
  void useMode(OhosThemeMode value) {
    if (value.isMonochrome) {
      useTheme(value.theme(fontFamily: fontFamily), mode: value);
    } else {
      setColorMode(value);
    }
  }

  /// 当前是否为墨水屏档位。
  ///
  /// 读的是主题本身的表现规则，不是枚举 —— 自定义的灰阶主题同样为 true。
  bool get isInk => _theme.policy.isMonochrome;
}

/// 把 [OhosThemeController] 接到界面上的唯一入口：包在 `MaterialApp` 外面，
/// 主题数据与 Material 主题一起跟随档位重建。
///
/// 这样调用方不用同时写 `OhosTheme` + `Theme` + 两次 `ValueListenableBuilder`，
/// 也不会漏掉「`OhosTheme` 必须在 `MaterialApp` 之上」这个容易踩的坑。
class OhosThemeSwitcher extends StatelessWidget {
  const OhosThemeSwitcher({
    super.key,
    required this.controller,
    required this.builder,
    this.materialThemeBuilder,
  });

  /// 档位持有者，通常由 `main()` 创建后一直传下来。
  final OhosThemeController controller;

  /// 拿到当前主题后构建子树，一般是 `MaterialApp`。
  ///
  /// 第一个参数是 `OhosTheme` 提供的 [OhosThemeData]（可直接读
  /// `OhosTheme.of(context)`），第二个是配套的 Material 主题，交给
  /// `MaterialApp.theme`。
  final Widget Function(BuildContext context, ThemeData materialTheme) builder;

  /// 覆写 Material 主题。
  ///
  /// 参数是当前主题数据（不再是档位枚举），因此自定义主题也能拿到正确的
  /// 亮度与色值；返回 `null` 表示用默认推导。
  final ThemeData Function(OhosThemeData theme)? materialThemeBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final OhosThemeData theme = controller.themeData;
        return OhosTheme(
          data: theme,
          child: Builder(
            builder: (BuildContext context) => builder(
              context,
              materialThemeBuilder?.call(theme) ?? controller.materialTheme,
            ),
          ),
        );
      },
    );
  }
}