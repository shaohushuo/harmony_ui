import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';
import 'ohos_app_bar.dart';

/// The page-level layout container of `ohos_ui`, the counterpart of Flutter's
/// [Scaffold].
///
/// Paints the theme background color and lays out an optional [appBar], the
/// [body], a [bottomNavigationBar] and a [floatingActionButton].
class OhosScaffold extends StatelessWidget {
  const OhosScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.drawer,
    this.endDrawer,
  });

  /// Optional top application bar.
  final OhosAppBar? appBar;

  /// The primary content of the page.
  final Widget? body;

  /// Optional bottom navigation bar.
  final Widget? bottomNavigationBar;

  /// Optional floating action button (usually an [OhosIconButton]).
  final Widget? floatingActionButton;

  /// Overrides the page background color.
  final Color? backgroundColor;

  /// Optional drawer shown from the leading edge.
  final Widget? drawer;

  /// Optional drawer shown from the trailing edge.
  final Widget? endDrawer;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color background = backgroundColor ?? theme.backgroundColor;
    // Built on a real [Scaffold] so `ScaffoldMessenger`-based overlays
    // (e.g. SnackBar shown through [showOhosSnackBar]) have a host to
    // present in, and drawers are wired up.
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Column(
              children: <Widget>[
                // `primary: true`（默认）的 AppBar 自己吸收状态栏内边距，所以
                // 不能包 `SafeArea`：SafeArea 会把 `MediaQuery.padding.top` 从
                // 子树里摘掉，栏里的 `topInset` 变成 0，`statusBarBackgroundColor`
                // 的色带随之退化成 0 高 —— README 推荐的
                // `OhosScaffold + OhosAppBar` 组合下该功能整个不可见。
                //
                // `primary: false` 的 AppBar 明确不吸收内边距（留给「不在屏幕
                // 顶部 / 调用方自己处理」的场景），页面级容器得替它让一次，
                // 否则内容直接顶到状态栏下面。
                if (appBar != null)
                  appBar!.primary
                      ? appBar!
                      : SafeArea(bottom: false, child: appBar!),
                Expanded(
                  child: SafeArea(
                    // 有 AppBar 时状态栏那一段已经被它占掉，body 再让一次就是
                    // 双倍留白；没有 AppBar 时才由这里让。
                    top: appBar == null,
                    // 同理：底部导航自带 `SafeArea`，body 再让一次同样会多出
                    // 一条 padding.bottom 的缝（列表末项被整体顶起）。
                    bottom: bottomNavigationBar == null,
                    child: body ?? const SizedBox.shrink(),
                  ),
                ),
                if (bottomNavigationBar != null)
                  SafeArea(top: false, child: bottomNavigationBar!),
              ],
            ),
          ),
          if (floatingActionButton != null)
            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: floatingActionButton,
                ),
              ),
            ),
        ],
      ),
      drawer: drawer,
      endDrawer: endDrawer,
    );
  }
}
