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
                // 顶部内边距分两种情况，横向（横屏刘海 / 挖孔）两种都得让：
                // * `primary: true`（默认）：栏自己吸收 `padding.top` 并铺出
                //   状态栏色带 —— 这一层必须 `top: false`，否则 SafeArea 会把
                //   `MediaQuery.padding.top` 摘成 0，色带退化成 0 高；
                // * `primary: false`：栏明确不吃顶部内边距（用于「不在屏幕顶部 /
                //   调用方自己让过」），页面级容器得替它让一次，不然内容顶到
                //   状态栏下面。
                if (appBar != null)
                  SafeArea(top: !appBar!.primary, bottom: false, child: appBar!),
                Expanded(
                  child: SafeArea(
                    // 有 AppBar 时状态栏那一段已经被它占掉，body 再让一次就是
                    // 双倍留白；没有 AppBar 时才由这里让。
                    top: appBar == null,
                    // 同理：底部导航自带 `SafeArea`，body 再让一次同样会多出
                    // 一条 padding.bottom 的缝（列表末项被整体顶起）。
                    bottom: bottomNavigationBar == null,
                    // 只让几何还不够：`SafeArea` 只把**自己让过的那几个边**从子树
                    // 的 `MediaQuery` 里摘掉，`top: false` / `bottom: false` 的那
                    // 一边仍原样留给后代。于是调用方在 body 里按最常见写法再包一层
                    // `SafeArea`（或自己读 `padding` 做偏移）就会叠出第二份 ——
                    // 有 AppBar 时凭空多一条状态栏高度的空白。
                    // 四个边到这里都已经由本页（栏 / 页面容器 / 底部导航）认领完毕，
                    // 统一摘干净，与 Flutter `Scaffold` 的 body 槽位一致（它也是
                    // `removeTopPadding: appBar != null` 那套）。
                    child: MediaQuery.removePadding(
                      context: context,
                      removeLeft: true,
                      removeTop: true,
                      removeRight: true,
                      removeBottom: true,
                      child: body ?? const SizedBox.shrink(),
                    ),
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
