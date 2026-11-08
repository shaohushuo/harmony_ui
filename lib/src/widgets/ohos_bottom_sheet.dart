import 'package:flutter/material.dart';

import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_button.dart';
import 'ohos_divider.dart';
import 'ohos_light_material.dart';
import 'ohos_sheet_type.dart';

/// Shows a HarmonyOS half-sheet panel (半模态面板 in the guideline).
///
/// 官方 `bindSheet` 有 **5 种形态**（`SheetType`）。本库按形态分别渲染，
/// 不是「同一块面板换对齐方式」—— 形态决定的不只是位置，还有：
///
/// | 形态 | 圆角 | 蒙层 | 标题/关闭 | 控制条 | 挡位 | 宽高 |
/// | --- | --- | --- | --- | --- | --- | --- |
/// | BOTTOM | 仅上面两角 | 有 | 有 | 有 | 有 | 内容高 |
/// | CENTER | 四角 | 有 | 有 | 有 | 有 | 默认 480 宽 / 夹取高 |
/// | POPUP | 四角 | 有 | 有 | 有 | 有 | 同上 |
/// | SIDE | 四角 | 有 | 有 | **无** | **无** | 固定宽 / 全屏高 |
/// | CONTENT_COVER | **无** | **无** | **无** | **无** | **无** | 全屏 |
///
/// ```dart
/// await showOhosBottomSheet(
///   context: context,
///   title: '分享',
///   content: SizedBox(height: 200, child: ...),
/// );
///
/// // 居中形态，宽度走响应式默认：
/// await showOhosBottomSheet(
///   context: context,
///   title: '选择',
///   content: ...,
///   type: OhosSheetType.center,
/// );
/// ```
Future<void> showOhosBottomSheet({
  required BuildContext context,
  required String title,
  required Widget content,
  String? dismissLabel,
  bool showCloseButton = true,
  OhosLightMaterialLevel level = OhosLightMaterialLevel.ultraThick,
  bool lightMaterial = true,
  OhosSheetType? type,
  double? height,
  double? width,
  List<OhosSheetDetent>? detents,
  int initialDetent = 0,
}) {
  // 没传形态就按窗口宽度取默认（官方 `preferType` 的三档规则）。
  // 这里读 `MediaQuery` 是因为 `showModalBottomSheet` 在**新路由**里建面板，
  // 调用点拿不到面板自己的约束 —— 与组件内部 `LayoutBuilder` 的判据不同，
  // 那处必须用约束宽度。两者各自正确，别互相套用。
  final double windowWidth = MediaQuery.sizeOf(context).width;
  final OhosSheetType resolved = type ?? OhosSheetSpec.defaultTypeFor(windowWidth);

  final double windowHeight = MediaQuery.sizeOf(context).height;
  final double shortSide = windowWidth < windowHeight ? windowWidth : windowHeight;

  switch (resolved) {
    case OhosSheetType.bottom:
    case OhosSheetType.center:
    case OhosSheetType.popup:
      return _showPanel(
        context: context,
        type: resolved,
        title: title,
        content: content,
        dismissLabel: dismissLabel,
        showCloseButton: showCloseButton,
        level: level,
        lightMaterial: lightMaterial,
        windowWidth: windowWidth,
        windowHeight: windowHeight,
        shortSide: shortSide,
        requestedHeight: height,
        requestedWidth: width,
        detents: detents,
        initialDetent: initialDetent,
      );
    case OhosSheetType.side:
      return _showSide(
        context: context,
        type: resolved,
        title: title,
        content: content,
        dismissLabel: dismissLabel,
        showCloseButton: showCloseButton,
        level: level,
        lightMaterial: lightMaterial,
        windowWidth: windowWidth,
        windowHeight: windowHeight,
      );
    case OhosSheetType.contentCover:
      return _showContentCover(
        context: context,
        content: content,
        level: level,
        lightMaterial: lightMaterial,
      );
  }
}

/// BOTTOM / CENTER / POPUP 三者共用一版面板：差别只在圆角、宽度与高度。
Future<void> _showPanel({
  required BuildContext context,
  required OhosSheetType type,
  required String title,
  required Widget content,
  required String? dismissLabel,
  required bool showCloseButton,
  required OhosLightMaterialLevel level,
  required bool lightMaterial,
  required double windowWidth,
  required double windowHeight,
  required double shortSide,
  required double? requestedHeight,
  required double? requestedWidth,
  required List<OhosSheetDetent>? detents,
  required int initialDetent,
}) {
  final BorderRadius shape = _shapeFor(type);
  return showModalBottomSheet<void>(
    context: context,
    // CENTER / POPUP 是「悬浮在中间」，不能贴底；用 `isScrollControlled`
    // + 外部 `Align` 表达位置，而不是靠 bottom sheet 默认的贴底行为。
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // CENTER / POPUP 需要蒙层；BOTTOM 也要。`showModalBottomSheet` 默认带
    // 蒙层，这里只在真不需要时关掉（CONTENT_COVER 那个分支单独处理）。
    barrierColor: Colors.black54,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    builder: (BuildContext context) {
      final OhosThemeData theme = OhosTheme.of(context);
      final Widget panel = _panelBody(
        context: context,
        theme: theme,
        title: title,
        content: content,
        dismissLabel: dismissLabel,
        showCloseButton: showCloseButton,
        type: type,
      );

      // 三型的共同点：宽度与高度都不一样，所以外面套一层定位。
      final double panelWidth = requestedWidth ??
          (type == OhosSheetType.center || type == OhosSheetType.popup
              ? OhosSheetSpec.centerDefaultWidth
              : windowWidth);

      // 高度：detents 生效时 `height` 失效（官方原文），取首挡。
      final double? resolvedHeight = _resolvePanelHeight(
        type: type,
        detents: detents,
        requestedHeight: requestedHeight,
        viewportHeight: windowHeight,
        shortSide: shortSide,
        initialDetent: initialDetent,
      );

      final Widget shell = _shell(
        context: context,
        theme: theme,
        level: level,
        lightMaterial: lightMaterial,
        shape: shape,
        child: panel,
      );

      final Widget sized = SizedBox(
        width: panelWidth > windowWidth ? windowWidth : panelWidth,
        height: resolvedHeight,
        child: shell,
      );

      if (type == OhosSheetType.bottom) {
        // BOTTOM 贴底、宽度占满。
        return Align(
          alignment: Alignment.bottomCenter,
          child: sized,
        );
      }
      // CENTER / POPUP 居中悬浮。
      return Center(child: sized);
    },
  );
}

/// SIDE：右侧抽屉，高度恒全屏、固定宽度、无控制条与挡位。
Future<void> _showSide({
  required BuildContext context,
  required OhosSheetType type,
  required String title,
  required Widget content,
  required String? dismissLabel,
  required bool showCloseButton,
  required OhosLightMaterialLevel level,
  required bool lightMaterial,
  required double windowWidth,
  required double windowHeight,
}) {
  // 官方宽度规格：md 断点（600vp）为窗口 1/2，大于 md 恒 400vp。
  final double panelWidth = windowWidth <= OhosSheetSpec.breakpointMedium
      ? windowWidth / 2
      : OhosSheetSpec.sideWideWidth;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (BuildContext context, _, __) {
      final OhosThemeData theme = OhosTheme.of(context);
      final Widget panel = _panelBody(
        context: context,
        theme: theme,
        title: title,
        content: content,
        dismissLabel: dismissLabel,
        showCloseButton: showCloseButton,
        type: type,
      );
      return Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: panelWidth,
          height: windowHeight,
          child: _shell(
            context: context,
            theme: theme,
            level: level,
            lightMaterial: lightMaterial,
            shape: _shapeFor(type),
            child: panel,
            sideEdge: true,
          ),
        ),
      );
    },
    transitionBuilder: (BuildContext context, Animation<double> a, _, Widget child) {
      // 官方：侧边「从右向左进入，原地向右退出」，不支持自定义转场。
      final Animation<Offset> slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: child);
    },
  );
}

/// CONTENT_COVER：全屏、无圆角/边框/阴影/标题/关闭按钮/**蒙层**，仅侧滑关闭。
Future<void> _showContentCover({
  required BuildContext context,
  required Widget content,
  required OhosLightMaterialLevel level,
  required bool lightMaterial,
}) {
  return showGeneralDialog<void>(
    context: context,
    // **无蒙层**是官方的硬规格（「不支持蒙层效果」），不是省略。
    // Flutter 的 `barrierColor` 给 `Colors.transparent` 仍然会拦截点击，
    // 所以这里用 `showGeneralDialog` 并显式给透明 + 允许侧滑关闭。
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (BuildContext context, _, __) {
      final OhosThemeData theme = OhosTheme.of(context);
      return SizedBox.expand(
        child: Material(
          color: theme.cardColor,
          child: SafeArea(child: content),
        ),
      );
    },
    transitionBuilder: (BuildContext context, Animation<double> a, _, Widget child) {
      final Animation<Offset> slide = Tween<Offset>(
        begin: const Offset(0, 0.02),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: FadeTransition(opacity: a, child: child));
    },
  );
}

/// 面板本体（标题栏 + 内容 + 操作区）。标题与关闭按钮按形态开关。
Widget _panelBody({
  required BuildContext context,
  required OhosThemeData theme,
  required String title,
  required Widget content,
  required String? dismissLabel,
  required bool showCloseButton,
  required OhosSheetType type,
}) {
  final bool withChrome = OhosSheetSpec.hasTitleAndClose(type);
  return SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 控制条只在支持挡位的形态下画 —— SIDE / CONTENT_COVER 官方明确
          // 「不支持控制条」，画上去就是凭空多一个手柄。
          if (OhosSheetSpec.supportsDragBar(type) && withChrome)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.textTertiaryColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          if (withChrome)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: theme.typography.titleMedium?.copyWith(
                      color: theme.textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (showCloseButton)
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ),
              ],
            ),
          if (withChrome) const SizedBox(height: 12),
          Flexible(child: SingleChildScrollView(child: content)),
          if (dismissLabel != null) ...<Widget>[
            const SizedBox(height: 8),
            const OhosDivider(indent: 0, endIndent: 0),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: OhosButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(dismissLabel),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// 面板外壳：毛玻璃 / 纯色 + 按形态给描边。
Widget _shell({
  required BuildContext context,
  required OhosThemeData theme,
  required OhosLightMaterialLevel level,
  required bool lightMaterial,
  required BorderRadius shape,
  required Widget child,
  bool sideEdge = false,
}) {
  if (!lightMaterial || !theme.policy.allowsBlur) {
    // 关掉毛玻璃，或这套主题不做整层模糊：退化成纯色面板。
    //
    // 墨屏上面板与页面同为纯白，边会整个消失 —— 必须按形态描边：
    // BOTTOM 只要顶上一条；CENTER / POPUP / SIDE 要四边，否则悬浮面板
    // 在白底上没有轮廓。原实现写死了 `BorderRadius.vertical(top:)`，
    // 那是只有底部形态时才成立。
    return Material(
      color: theme.cardColor,
      clipBehavior: Clip.antiAlias,
      shape: theme.usesOutlines
          ? RoundedRectangleBorder(
              borderRadius: shape,
              side: ohosBorderSide(
                context,
                theme.dividerColor,
                width: theme.outlineWidth,
              ),
            )
          : null,
      borderRadius: theme.usesOutlines ? null : shape,
      child: child,
    );
  }
  return OhosLightMaterial(
    level: level,
    borderRadius: shape,
    child: child,
  );
}

/// 按形态给圆角。
///
/// **官方**：BOTTOM 只显示上面两角（「即使设置了底部 2 个圆角也不生效」）；
/// CONTENT_COVER 完全没有圆角；其余三型四角皆圆。默认半径 32vp。
BorderRadius _shapeFor(OhosSheetType type) {
  final Radius r = const Radius.circular(OhosSheetSpec.radius);
  if (type == OhosSheetType.contentCover) {
    return BorderRadius.zero;
  }
  if (type == OhosSheetType.bottom) {
    return BorderRadius.vertical(top: r);
  }
  return BorderRadius.all(r);
}

/// 高度解析：detents 生效时 `height` 失效（官方原文），取首挡。
double? _resolvePanelHeight({
  required OhosSheetType type,
  required List<OhosSheetDetent>? detents,
  required double? requestedHeight,
  required double viewportHeight,
  required double shortSide,
  required int initialDetent,
}) {
  final List<OhosSheetDetent>? list = detents;
  if (list != null && list.isNotEmpty && OhosSheetSpec.supportsDetents(type)) {
    final int index = initialDetent.clamp(0, list.length - 1);
    final double? resolved = OhosSheetSpec.resolveDetent(
      detent: list[index],
      type: type,
      viewportHeight: viewportHeight,
      shortSide: shortSide,
    );
    if (resolved != null) {
      return resolved;
    }
    // fitContent：交给内容自己撑。
    return null;
  }
  if (requestedHeight != null) {
    return OhosSheetSpec.clampHeight(
      height: requestedHeight,
      type: type,
      viewportHeight: viewportHeight,
      shortSide: shortSide,
    );
  }
  // 未指定高度：CENTER / POPUP 给官方默认 560（同样受夹取约束）。
  if (type == OhosSheetType.center || type == OhosSheetType.popup) {
    return OhosSheetSpec.clampHeight(
      height: OhosSheetSpec.centeredFixedHeight,
      type: type,
      viewportHeight: viewportHeight,
      shortSide: shortSide,
    );
  }
  return null;
}
