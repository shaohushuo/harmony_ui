import 'package:flutter/material.dart';

export 'ohos_theme_data.dart';
export 'ohos_visual_policy.dart';

import 'ohos_theme_data.dart';

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

/// 应用的皮肤档位。
///
/// 四档看着像一根轴，其实是**两个正交维度**各自取了一个内置值：
///
/// | 档位 | 颜色外观 | 表现规则 |
/// | --- | --- | --- |
/// | [system] | 跟随系统亮度 | 彩屏 |
/// | [light] | 浅色 | 彩屏 |
/// | [dark] | 深色 | 彩屏 |
/// | [ink] | 浅色（黑字白纸） | 墨水屏 |
///
/// 前三个是「颜色外观」这一维的取值（[system] 表示交给系统决定），[ink] 则
/// 顺带把「表现规则」这一维也钉成了墨水屏 —— 它是给「只想一键切到电子纸」
/// 这个高频场景准备的便利档，**不是**墨水屏的唯一表达方式。
///
/// 要表达 [ink] 覆盖不到的合法组合（深色墨水屏、彩色墨水屏、高对比模式），
/// 用 [OhosThemeData.copyWith] 直接给一份主题数据 + 一个策略，走
/// [OhosThemeController.custom]，不需要往本枚举里加值。这也是为什么新增一块
/// 屏不该改组件：枚举只列常见的几档，真正的表达能力在 [OhosThemeData]。
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
  /// 跟随系统的浅色 / 深色设置。
  ///
  /// 只影响**颜色外观**，不影响显示策略：墨水屏设备上跟随系统仍是彩屏策略，
  /// 要电子纸表现请显式选 [ink] 或用自定义主题。
  system('跟随系统'),

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
  ///
  /// [system] 为 false —— 系统亮度是颜色外观维度的事，与是不是灰阶屏无关。
  bool get isMonochrome => this == OhosThemeMode.ink;

  /// 这一档需要向系统查询当前亮度。
  bool get followsSystem => this == OhosThemeMode.system;

  /// 构造这一档对应的主题数据。
  ///
  /// [system] 需要知道系统当前是浅色还是深色，由调用方通过
  /// [systemBrightness] 传入；不传则按浅色处理（首帧 SystemBrightness
  /// 还没拿到的场景，先给一个安全默认值，拿到后会自动重建）。
  OhosThemeData theme({String? fontFamily, Brightness? systemBrightness}) =>
      switch (this) {
        OhosThemeMode.system =>
          (systemBrightness ?? Brightness.light) == Brightness.dark
              ? OhosThemeData.dark(fontFamily: fontFamily)
              : OhosThemeData.light(fontFamily: fontFamily),
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
    Brightness systemBrightness = Brightness.light,
  }) : _theme = initialMode.theme(
         fontFamily: fontFamily,
         systemBrightness: systemBrightness,
       ),
       _mode = initialMode,
       // 「普通」那一侧必须随构造一起播种：
       // 若初值写死成 `OhosThemeData.light()`，用 `initialMode: ink`（example
       // 的默认档位）构造出来的控制器，点一次 toggle 就回落到一个 fontFamily
       // 为 null 的浅色主题 —— 整个字阶掉回系统字体。用 `dark` 初始化时更糟：
       // 档位也会被一起改写成 light。
       _lastColorTheme = initialMode.isMonochrome
           ? OhosThemeData.light(fontFamily: fontFamily)
           : initialMode.theme(
               fontFamily: fontFamily,
               systemBrightness: systemBrightness,
             ),
       // 墨水屏切回来时回的「彩屏主题」不应该继承 [system]：那是「跟随系统」
       // 这个选择本身，不是一个具体主题。回到上一次明确的浅色 / 深色。
       _lastColorMode = initialMode.isMonochrome
           ? OhosThemeMode.light
           : (initialMode == OhosThemeMode.system
                 ? (systemBrightness == Brightness.dark
                       ? OhosThemeMode.dark
                       : OhosThemeMode.light)
                 : initialMode);

  /// 用任意主题数据初始化 —— 自定义主题、以及将来新增的主题预设都走这里。
  ///
  /// [theme] 可以是 `OhosThemeData.light().copyWith(...)`，也可以是完全手写的
  /// 一份。切换按钮在 [mode] 为 null 时只显示当前主题，不提供三选一菜单。
  ///
  /// 如果 [theme] **本身就是墨屏**（如品牌定制的电子纸主题），「普通」那一侧
  /// 会播种成内置浅色 —— 否则 [toggle] 会拿这份墨屏主题去当「彩屏」侧，切
  /// 过去仍然是墨屏，按钮看起来完全失灵。这与
  /// `OhosThemeController(initialMode: OhosThemeMode.ink)` 的处理保持一致。
  OhosThemeController.custom(OhosThemeData theme, {this.fontFamily})
    : _theme = theme,
      _mode = null,
      // 自定义主题本身就是「普通」那一侧：先进入墨水屏再切回来，回到的应该
      // 是这份主题，而不是内置浅色。但若这份主题自己就是墨屏，它不能兼任
      // 「普通」侧 —— 见上面文档。
      _lastColorTheme = theme.policy.isMonochrome
          ? OhosThemeData.light(fontFamily: fontFamily)
          : theme,
      _lastColorMode = null;

  /// 当前档位。用 [OhosThemeController.custom] 构造时为 null。
  OhosThemeMode? _mode;

  /// 当前主题数据。任何来源（内置档位或自定义）都在这里收敛。
  OhosThemeData _theme;

  /// 上一次停留在哪个彩屏**主题**，供 [toggle] 从墨水屏切回来时用。
  ///
  /// 存的是 [OhosThemeData] 而不是档位：从自定义主题切到墨水屏再切回来，
  /// 应该回到那份自定义主题，而不是掉回某个内置预设。
  ///
  /// 由构造函数播种，不用字段初始化器 —— 初始化器拿不到 [fontFamily]，
  /// 会造出一份丢掉字体族的主题。
  OhosThemeData _lastColorTheme;

  /// 与 [_lastColorTheme] 配套的档位。自定义主题没有档位，所以是 nullable。
  OhosThemeMode? _lastColorMode;

  /// 字体族，透传给 [OhosTypography]。
  final String? fontFamily;

  /// 系统当前的浅色 / 深色设置，只在 [OhosThemeMode.system] 档下参与解析。
  /// 当前档位。自定义主题为 null —— 调用方 switch 它之前先判空。
  OhosThemeMode? get mode => _mode;

  /// 当前主题数据。
  ///
  /// 注意：选了 [OhosThemeMode.system] 时，这里返回的是**构造/切换那一刻**的
  /// 解析结果。系统亮度后来变了、而调用方又需要最新结果时用 [resolveTheme]。
  /// [OhosThemeSwitcher] 会自己做这件事，直接用它就不必关心这个区别。
  OhosThemeData get themeData => _theme;

  /// 按给定的系统亮度解析出**当前应当生效**的主题。
  ///
  /// 纯函数，不写状态、不通知 —— 这是它能被 [OhosThemeSwitcher] 在 `build`
  /// 里安全调用的原因。在 `build` 期间 `notifyListeners()` 会触发
  /// `setState() called during build`，所以系统亮度**不进 controller 的状态**，
  /// 而是像 MediaQuery 一样由 Widget 树提供、每次 build 现算。
  ///
  /// 为什么不让 controller 自己订阅亮度：那需要在某处监听
  /// `platformBrightnessOf` 再把值推回来，等于用一个状态去镜像另一个状态，
  /// 两边一旦不同步就是「切了系统深色但界面没动」这类难查的 bug。让亮度像
  /// 其他继承数据一样从 context 流下来，只有一条通路。
  ///
  /// [systemBrightness] 只在 [OhosThemeMode.system] 档下起作用；其余档位
  /// 返回 [themeData] 本身（值相等，不会引起多余重建）。
  OhosThemeData resolveTheme({Brightness? systemBrightness}) {
    if (_mode != OhosThemeMode.system || systemBrightness == null) {
      return _theme;
    }
    return OhosThemeMode.system.theme(
      fontFamily: fontFamily,
      systemBrightness: systemBrightness,
    );
  }

  /// 当前档位对应的 Material 主题。
  ///
  /// 只交给 `MaterialApp.theme`，负责 `Scaffold` / 弹窗这类还没换成 Ohos
  /// 组件的默认底色与文字色；组件本身一律走 [themeData]。
  ///
  /// 与 [resolveTheme] 一样是「现算」的：需要系统亮度时用 [materialThemeOf]，
  /// 否则「跟随系统」档下这边会停在上次解析的亮度，跟 Ohos 那一侧对不上。
  ThemeData get materialTheme => materialThemeOf();

  /// 按给定亮度算一份 Material 主题，语义与 [resolveTheme] 对齐。
  ThemeData materialThemeOf({Brightness? systemBrightness}) => ThemeData(
    brightness: resolveTheme(systemBrightness: systemBrightness).brightness,
    fontFamily: fontFamily,
  );

  /// 切到指定档位。与当前相同时不通知。
  ///
  /// [systemBrightness] 只在 [OhosThemeMode.system] 档下起作用。这个 setter
  /// 读不到 Widget 树，所以拿不到真实系统亮度 —— 传浅色，随后
  /// [OhosThemeSwitcher] 会用 [resolveTheme] 立刻纠正成正确的那个，用户看不到
  /// 中间帧。自己管理 `OhosTheme` 而不走 Switcher 时，请用
  /// `useTheme(controller.resolveTheme(systemBrightness: ...))` 显式给值。
  set mode(OhosThemeMode value) {
    useTheme(
      value.theme(
        fontFamily: fontFamily,
        systemBrightness: Brightness.light,
      ),
      mode: value,
    );
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
      // 回到「普通」那一侧。有档位就按档位**重新解析**，而不是回放当时存下的
      // 那份 OhosThemeData —— 停在墨水屏期间系统可能已经切过深色，回放会让
      // 用户回到一个已经过时的亮度。自定义主题没有档位，只能回放那份数据。
      //
      // 回 [system] 时这里能给到的亮度是浅色（读不到 context），但紧接着
      // Switcher 会用 resolveTheme 换成系统真实亮度，最终结果正确。
      final OhosThemeMode? back = _lastColorMode;
      useTheme(
        back == null ? _lastColorTheme : back.theme(fontFamily: fontFamily),
        mode: back,
      );
    } else {
      _lastColorTheme = resolveTheme();
      // [system] 不是「一个主题」，而是「跟随」这个选择本身，所以不能原样
      // 存进 [_lastColorMode] —— 存进去之后 toggle 回来就落在 system 档上，
      // 永远停在那里，而用户其实是在某个**具体明暗**下离开的。
      //
      // 这里读 [_lastColorTheme] 的亮度把 system 落成具体档位：那份数据就是
      // 进墨水屏那一刻实际显示的东西，也正是用户期望回来时看到的。
      _lastColorMode = _mode == OhosThemeMode.system
          ? (_lastColorTheme.isDark
                ? OhosThemeMode.dark
                : OhosThemeMode.light)
          : _mode;
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
    setColorTheme(
      value.theme(fontFamily: fontFamily),
      mode: value,
    );
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
///
/// **它还是 [OhosThemeMode.system] 档的亮度来源。** 系统亮度只能在 Widget 树里
/// 读到（`MediaQuery.platformBrightnessOf` 会订阅变化），所以由这里在每次
/// build 时喂给控制器；控制器只在真的换了主题时才通知，不会因为每次
/// `MediaQuery` 变化就重建整棵树。
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
        // 「跟随系统」档要在这里现算系统亮度。**不能**把它喂回 controller 再
        // 靠 notifyListeners 通知 —— 那会在 build 期间触发重建，直接抛
        // `setState() or markNeedsBuild() called during build`。
        //
        // resolveTheme 是纯函数：只读 controller 的档位、加上刚读到的亮度。
        // MediaQuery.platformBrightnessOf 会订阅变化，所以系统切深色时这个
        // builder 会重建，拿到新亮度，主题跟着翻 —— 一条通路，没有第二份状态。
        //
        // 放在 ListenableBuilder 内部而不是外面：外面那层读不到最新的 controller
        // 状态，切档后 title 会慢一帧。
        final OhosThemeData theme = controller.resolveTheme(
          systemBrightness: MediaQuery.platformBrightnessOf(context),
        );
        return OhosTheme(
          data: theme,
          child: Builder(
            builder: (BuildContext context) => builder(
              context,
              materialThemeBuilder?.call(theme) ??
                  ThemeData(
                    brightness: theme.brightness,
                    fontFamily: controller.fontFamily,
                  ),
            ),
          ),
        );
      },
    );
  }
}