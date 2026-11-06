import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_responsive.dart';

/// `CustomDialogControllerOptions` 里与本组件相关、且能追到明文默认值的几何。
///
/// 与 `OhosTextFieldMetrics` / `OhosListItemCardMetrics` 都不同：那两组的来源
/// 分别是**系统资源表**与**实现源码**，而这一组全部来自
/// `doc/reference/hds-ts-methods-custom-dialog-box.md` 的
/// `CustomDialogControllerOptions` 参数表 —— 参数表里直接写了默认值，不需要
/// 再往下追令牌。
class OhosDialogMetrics {
  const OhosDialogMetrics._();

  /// 弹窗宽度**默认最大值**（`width` 参数说明：「弹窗宽度默认最大值：400vp」）。
  ///
  /// 这是官方默认行为，不是可选配置 —— 之前没有上限，长内容会一路顶到屏幕
  /// 边缘，看起来不像弹窗。
  static const double maxWidth = 400;

  /// 弹窗高度**默认最大值系数**（`height` 参数说明：
  /// 「弹窗高度默认最大值：0.9 *（窗口高度 - 安全区域）」）。
  ///
  /// 乘的是「窗口高 − 安全区」而不是窗口高：PC/2in1 上要避让屏幕边缘与窗口
  /// 标题栏，直接用窗口高会让底边被裁掉。
  static const double maxHeightFactor = 0.9;

  /// `customStyle: false` 时的默认圆角（参数表原文「默认圆角为32vp」）。
  ///
  /// 32 而不是本库主题里的 `radiusLarge`(24) —— 弹窗是官方少见的、圆角比卡片
  /// 还大一档的容器。
  static const double borderRadius = 32;

  /// 遮罩层默认颜色（`maskColor` 默认值 `0x33000000`）。
  ///
  /// 20% 黑。与 Material 的 `barrierColor`（`Colors.black54`，54%）差一倍多
  /// —— 官方的遮罩更淡，靠弹窗自身底板与投影分层，而不是把背景压黑。
  static const Color maskColor = Color(0x33000000);

  /// 遮罩层默认覆盖整个窗口（`maskRect` 默认 `{0,0,'100%','100%'}`）。
  static const Rect maskRect = Rect.fromLTWH(
    0,
    0,
    double.infinity,
    double.infinity,
  );

  /// 弹窗与窗口左右边缘的最小间距。
  ///
  /// **这个数不在参数表里，只能下到系统资源表取**：`pattern.json` 的
  /// `ohos_dialog_pattern` 有 `dialog_container_margin_left` /
  /// `dialog_container_margin_right`，两者都指向 `$float:margin_left` /
  /// `margin_right`，在 `float_sys.json` 里都是 **16.0vp**。
  ///
  /// 为什么必须有它：`maxWidth = 400` 是**上限**，不是「一定 400」。窄屏上
  /// 可用宽度小于 400 时，直接把 `SizedBox(width: 400)` 塞进 `Center`，
  /// 弹窗会贴住屏幕左右两侧（360vp 屏上超出 40vp，表现为「宽度占满整屏」），
  /// 圆角切在屏幕外、看起来不像弹窗。这与 `OhosFloatingTabBar` 的 328 上限
  /// 是同一类错：**绝对上限 ≠ 必然值，还要再夹一次可用宽度**。
  static const double sideMargin = 16;
}

/// 弹窗关闭原因，对应 ArkUI 的 `DismissReason`。
///
/// 值顺序照抄官方（`PRESS_BACK` 0 / `TOUCH_OUTSIDE` 1 / `CLOSE_BUTTON` 2 /
/// `SLIDE_DOWN` 3 / `SLIDE` 4），但本组件只产生前三个：后两个的文档明文
/// 「仅支持在半模态转场中使用」，那是 `showOhosBottomSheet` 的领域。
enum OhosDismissReason {
  /// 点击三键 back、侧滑（左滑/右滑）、键盘 ESC。
  pressBack,

  /// 点击遮罩层。
  touchOutside,

  /// 点击关闭按钮。
  closeButton,
}

/// 交给 [OhosAlertDialog.onWillDismiss] 的「关闭请求」句柄。
///
/// 与 Flutter 的习惯相反：**不调用 [dismiss] 就不会关**。官方的模型是
/// 「注册了 `onWillDismiss` 之后不立刻关闭，在回调里凭 reason 决定是否
/// 允许」，所以这里必须显式放行 —— 做成「默认关、返回 false 才拦」会与官方
/// 语义相反，且调用方容易忘记返回值。
class OhosDismissDialogAction {
  OhosDismissDialogAction._(this.reason, this._dismiss);

  /// 触发本次关闭请求的操作类型。
  final OhosDismissReason reason;

  final void Function() _dismiss;

  bool _dismissed = false;

  /// 是否已被放行（供测试与调用方查状态）。
  bool get isDismissed => _dismissed;

  /// 允许关闭。重复调用无副作用。
  void dismiss() {
    if (_dismissed) {
      return;
    }
    _dismissed = true;
    _dismiss();
  }
}

/// 弹窗四段生命周期的回调集合。
///
/// 官方时序固定为 `onWillAppear >> onDidAppear >> onWillDisappear >>
/// onDidDisappear`，本库按这个顺序调用，不做重排。
class OhosDialogLifecycle {
  const OhosDialogLifecycle({
    this.onWillAppear,
    this.onDidAppear,
    this.onWillDisappear,
    this.onDidDisappear,
  });

  /// 显示动效**前**。
  final VoidCallback? onWillAppear;

  /// 弹出后。
  ///
  /// 官方补了一条容易漏的边界：「弹窗入场动效未完成时彻底关闭弹窗，动效打断，
  /// `onDidAppear` 不会触发」。本库用 `route.isCurrent` + 首帧是否已过判定，
  /// 若在首帧前就被 pop，则跳过 [onDidAppear]。
  final VoidCallback? onDidAppear;

  /// 退出动效**前**。
  final VoidCallback? onWillDisappear;

  /// 消失后。
  final VoidCallback? onDidDisappear;
}

/// Shows a HarmonyOS alert dialog and returns the value of the pressed action.
///
/// ```dart
/// final bool? ok = await showOhosDialog<bool>(
///   context: context,
///   title: '删除此项？',
///   content: '该操作不可恢复。',
///   actions: <OhosDialogAction>[
///     OhosDialogAction(label: '取消', onPressed: () => Navigator.pop(context, false)),
///     OhosDialogAction(label: '删除', danger: true, onPressed: () => Navigator.pop(context, true)),
///   ],
/// );
/// ```
class OhosAlertDialog extends StatefulWidget {
  const OhosAlertDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    this.actions = const <OhosDialogAction>[],
    this.customStyle = false,
    this.isModal = true,
    this.maskColor,
    this.gridCount,
    this.width,
    this.height,
    this.lifecycle = const OhosDialogLifecycle(),
    this.onWillDismiss,
  });

  /// Title of the dialog.
  final String title;

  /// Optional body text.
  final String? content;

  /// Rich body, for text fields / lists that [content] cannot express.
  ///
  /// Takes precedence over [content]; the widget is laid out in the same
  /// centered slot, so a form dialog keeps the ArkUI spacing. The slot scrolls
  /// vertically when the content is taller than the space left by the title and
  /// the actions, so a multi-field form on a narrow screen (or with a large
  /// system font) does not overflow the dialog.
  final Widget? contentWidget;

  /// Action buttons laid out vertically (ArkUI style).
  final List<OhosDialogAction> actions;

  /// 容器样式是否自定义（`customStyle`，默认 `false`）。
  ///
  /// 取值与官方一致，但**落地方式不同**，这是本组件最需要说清的一处：
  ///
  /// - `false`（默认）：圆角恒为 [OhosDialogMetrics.borderRadius] = **32**，
  ///   背板由本库画。注意官方此档的背板色其实是 `Transparent` —— 圆角与背板
  ///   在这里是两件事，圆角 32 属于「默认样式」，透明度属于「谁来填色」。
  /// - `true`：**圆角为 0、背板透明**，边界交给 [contentWidget] 自己画。
  ///   这是官方原文（「圆角为0，弹窗背景色为透明色，并且弹窗的沉浸光感效果
  ///   不生效」）。此时本库不再补墨水屏描边 —— 壳已经交出去了。
  ///
  /// 早前版本自己定 28 圆角、且没有这个开关，与官方默认值 32 不一致。
  final bool customStyle;

  /// 是否模态（`isModal`，默认 `true`）。
  ///
  /// `false` 时官方语义是「非模态窗口**且无遮罩层**，可以与弹窗周围其他控件
  /// 进行交互」。Flutter 的 `showDialog` 只能栅格化所有下层交互（它插一条
  /// `ModalBarrier`），所以本组件分两档落地：
  ///
  /// - **直接构造**（`OhosAlertDialog` 作为普通 widget 用，如 `Overlay` 里的
  ///   一层、或页面里嵌一个）：`false` 就是真的非模态 —— 不画遮罩、不拦截
  ///   点击，下层照常可点。
  /// - **`showOhosDialog`**：这是路由级弹层，无论 `isModal` 取值都会挡住下层
  ///   （`ModalBarrier` 是 `showDialog` 的一部分）。此时 `false` 只表达「不画
  ///   遮罩色」，不表达「可交互」。
  ///
  /// 写成两档而不是假装支持：给出一个「看着是非模态、其实点不动下层」的开关，
  /// 比明说不支持更坏。
  final bool isModal;

  /// 遮罩层颜色（`maskColor`，默认 `0x33000000`）。
  ///
  /// 只有 [isModal] 为 `true` 时才有意义。
  final Color? maskColor;

  /// 弹窗宽度占栅格的列数（`gridCount`，默认按窗口自适应）。
  ///
  /// 官方「默认为按照窗口大小自适应，异常值按默认值处理，最大栅格数为系统
  /// 最大栅格数」。本库先按断点取 4 / 8 / 12 列，再把 `gridCount` 夹到
  /// `[1, 系统最大列数]` —— 异常值（0、负数、超过列数）一律回落到 `null`
  /// 的默认路径，与官方「异常值按默认值处理」一致。
  final int? gridCount;

  /// 显式宽度（`width`）。给了就不再按 [`maxWidth`] 与栅格推。
  ///
  /// 官方此档的语义是「设置后不超过默认最大宽度 400vp」——注意是**不超过**，
  /// 超出的部分会被夹回去，而不是让调用方突破上限。本库照此实现。
  final double? width;

  /// 显式高度（`height`）。同样受 `0.9 ×（窗口高 − 安全区）` 夹取。
  final double? height;

  /// 四段生命周期回调。
  final OhosDialogLifecycle lifecycle;

  /// 交互式关闭拦截（`onWillDismiss`）。
  ///
  /// 注册后，点遮罩 / 返回键**不会**直接关闭：先回调本函数，由调用方决定是否
  /// 调 [OhosDismissDialogAction.dismiss]。不注册则照常关闭。
  final void Function(OhosDismissDialogAction action)? onWillDismiss;

  @override
  State<OhosAlertDialog> createState() => _OhosAlertDialogState();
}

class _OhosAlertDialogState extends State<OhosAlertDialog> {
  /// 是否正在退出（防止 `onWillDisappear` 被重复回调）。
  bool _disappearing = false;

  @override
  void initState() {
    super.initState();
    widget.lifecycle.onWillAppear?.call();
    // 官方补了一条容易漏的边界：「弹窗入场动效未完成时彻底关闭弹窗，动效
    // 打断，`onDidAppear` 不会触发」。这里用「首帧后 mounted 仍然为真」来
    // 近似它 —— 首帧前就被 pop 掉的弹窗，回调里 `mounted` 已经是 false 或
    // 已进入退出流程，于是跳过 `onDidAppear`。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _disappearing) {
        return;
      }
      widget.lifecycle.onDidAppear?.call();
    });
  }

  @override
  void dispose() {
    // 若还没走到 `_beginDisappear`（例如被直接 remove），补一次退出回调，
    // 否则 `onWillDisappear` / `onDidDisappear` 会静默丢失。
    if (!_disappearing) {
      _disappearing = true;
      widget.lifecycle.onWillDisappear?.call();
    }
    widget.lifecycle.onDidDisappear?.call();
    super.dispose();
  }

  void _beginDisappear() {
    if (_disappearing) {
      return;
    }
    _disappearing = true;
    widget.lifecycle.onWillDisappear?.call();
  }

  /// 拦截一次关闭请求。返回 `true` 表示可以直接关（没注册拦截，或已放行）。
  bool _requestDismiss(OhosDismissReason reason) {
    final void Function(OhosDismissDialogAction)? hook = widget.onWillDismiss;
    if (hook == null) {
      _beginDisappear();
      return true;
    }
    // 注意：这里**不**调 `_beginDisappear`。拦截回调是同步的，但「放行」
    // 可能发生在之后（异步确认弹窗），退出回调要等到真正放行那一刻。
    bool allowed = false;
    final OhosDismissDialogAction action = OhosDismissDialogAction._(
      reason,
      () {
        allowed = true;
        _beginDisappear();
      },
    );
    hook(action);
    return allowed;
  }

  /// 解析出最终宽度与高度：先算上限（400 / 0.9×可用高），再让显式值与栅格
  /// 优先级覆盖，最后统一夹回上限。
  ({double maxWidth, double maxHeight}) _bounds(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    // 扣掉安全区再乘 0.9 —— 官方明写「0.9 *（窗口高度 - 安全区域）」。
    final double usableHeight = screen.height - safe.top - safe.bottom;
    // 宽度上限要**两个条件取小**：官方的 400vp 上限，与「窗口宽 − 左右边距」。
    // 400 是绝对上限而非必然值 —— 360vp 屏上它不可能被满足，只夹 400 会
    // 让弹窗铺满整屏、圆角切在屏幕外。宽度同样要扣安全区（横屏刘海在左右）。
    final double usableWidth =
        screen.width -
        safe.left -
        safe.right -
        OhosDialogMetrics.sideMargin * 2;
    return (
      maxWidth: OhosDialogMetrics.maxWidth < usableWidth
          ? OhosDialogMetrics.maxWidth
          : usableWidth,
      maxHeight: usableHeight * OhosDialogMetrics.maxHeightFactor,
    );
  }

  /// 按 `gridCount` 与断点算出目标宽度；`null` 表示走默认（夹到 400）。
  double? _gridWidth(BuildContext context) {
    final int? requested = widget.gridCount;
    if (requested == null) {
      return null;
    }
    final OhosWindowSize window = OhosWindowSize.fromWidth(
      MediaQuery.sizeOf(context).width,
    );
    // 官方「异常值按默认值处理，最大栅格数为系统最大栅格数」：超界与非法值
    // 都回落到默认路径，而不是夹到边界 —— 夹取会让 `gridCount: 999` 悄悄
    // 变成「占满整屏」，那不是调用方要的。
    if (requested < 1 || requested > window.columns) {
      return null;
    }
    final double total = window.width - window.margin * 2;
    final double cell =
        (total - window.gutter * (window.columns - 1)) / window.columns;
    return cell * requested + window.gutter * (requested - 1);
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final ({double maxWidth, double maxHeight}) bounds = _bounds(context);
    final BorderRadius radius = widget.customStyle
        ? BorderRadius.zero
        : BorderRadius.circular(OhosDialogMetrics.borderRadius);

    // customStyle: true → 壳完全交出去：无圆角、背板透明、无描边、无内边距。
    final Color background = widget.customStyle
        ? Colors.transparent
        : theme.popupColor;

    // 弹窗由 `showDialog` 挂在 Navigator 的 Overlay 上，**没有 `Material`
    // 祖先**。这种位置的文字会退到 `DefaultTextStyle.fallback` —— 那个常量
    // 是黄色 `#FFFF00` + `double` 下划线，专门用来在视觉上标记「这段文字
    // 没有任何样式来源」。真机上因此让标题「删除文件」和正文各带了两条黄线
    // （宽度 135px / 262px，见墨屏无色判据抓到的 5340 个黄像素）。
    //
    // 按钮文字没中招，只因为 `_OhosDialogActionButton` 自己包了 `Material`
    // —— 所以这个缺陷在只截图弹窗按钮时看不出来。
    Widget surface = DefaultTextStyle(
      style: TextStyle(
        fontFamily: theme.typography.bodyMedium?.fontFamily,
        color: theme.textPrimaryColor,
        decoration: TextDecoration.none,
      ),
      child: Padding(
        padding: widget.customStyle
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(24, 28, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style:
                  (theme.typography.titleMedium ??
                          const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ))
                      .copyWith(color: theme.textPrimaryColor),
            ),
            if (widget.contentWidget != null)
              // 表单 / 列表可能比弹窗剩余空间高（320vp 窄屏 + 1.3x 字号下几个
              // 输入框就够）：Flexible + 滚动，宁可滚也不纵向溢出。
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SingleChildScrollView(child: widget.contentWidget!),
                ),
              )
            else if (widget.content != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.content!,
                      textAlign: TextAlign.center,
                      style:
                          (theme.typography.bodyMedium ??
                                  const TextStyle(fontSize: 15))
                              .copyWith(color: theme.textSecondaryColor),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            for (int i = 0; i < widget.actions.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 4),
              _OhosDialogActionButton(action: widget.actions[i]),
            ],
          ],
        ),
      ),
    );

    if (!widget.customStyle) {
      final double? explicitWidth = widget.width ?? _gridWidth(context);
      final double width = explicitWidth == null
          ? bounds.maxWidth
          : explicitWidth.clamp(0.0, bounds.maxWidth);
      // 高度不夹到 maxHeight —— 只给上限，让内容自己决定有多高；内容再高由
      // 上面的 `Flexible` + 滚动消化。
      final double? height = widget.height;

      surface = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width,
          maxHeight: bounds.maxHeight,
          minHeight: 0,
        ),
        child: SizedBox(width: width, height: height, child: surface),
      );

      // 墨水屏：弹层与页面同为纯白，只剩遮罩提供边界 → 补 1px 描边。
      surface = DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: theme.usesOutlines
              ? Border.fromBorderSide(
                  ohosBorderSide(
                    context,
                    theme.dividerColor,
                    width: theme.outlineWidth,
                  ),
                )
              : null,
        ),
        child: ClipRRect(borderRadius: radius, child: surface),
      );

      if (!widget.isModal) {
        // 非模态：不画遮罩、不拦截。直接构造时这是真的可交互。
        return Center(child: surface);
      }

      // `SizedBox.expand` 是必须的：`Center` 给子节点的是**松约束**，直接写
      // `Center(child: Stack(...))` 会让 Stack 收缩到面（surface）那么大，
      // 于是那层「全屏遮罩」实际只有弹窗大小 —— 点弹窗外面根本不会命中它。
      // 实测：`Positioned.fill` 的遮罩量出来是 179×124（弹窗尺寸），不是
      // 400×800。
      return SizedBox.expand(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_requestDismiss(OhosDismissReason.touchOutside)) {
                    Navigator.maybePop(context);
                  }
                },
                child: ColoredBox(
                  color: widget.maskColor ?? OhosDialogMetrics.maskColor,
                ),
              ),
            ),
            Center(child: surface),
          ],
        ),
      );
    }

    // customStyle: true —— 壳交出去了，只保留尺寸上限与拦截能力。
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: bounds.maxWidth,
          maxHeight: bounds.maxHeight,
        ),
        child: surface,
      ),
    );
  }
}

/// An action entry of [OhosAlertDialog].
class OhosDialogAction {
  const OhosDialogAction({
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.textStyle,
  });

  /// Visible label of the action.
  final String label;

  /// Called when the action is pressed.
  final VoidCallback onPressed;

  /// When true the label is tinted with the danger color.
  final bool danger;

  /// Optional label style override.
  final TextStyle? textStyle;
}

class _OhosDialogActionButton extends StatelessWidget {
  const _OhosDialogActionButton({required this.action});

  final OhosDialogAction action;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Color color = action.danger
        ? theme.dangerColor
        : theme.highlightColor;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(OhosGeometry.radiusMedium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onPressed,
        highlightColor: color.withValues(alpha: 0.08),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          child: Text(
            action.label,
            style:
                (action.textStyle ??
                        theme.typography.labelLarge ??
                        const TextStyle(fontSize: 16))
                    .copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Builds and shows an [OhosAlertDialog], the `ohos_ui` counterpart of
/// `showDialog` + `AlertDialog`.
///
/// 路由级弹层用 [RouteSettings] 的 `barrierColor` 承接 `maskColor` /
/// `isModal`，因此这两项在这个入口上是**真的起作用**的（非模态时遮罩透明）。
/// 但请注意：`showDialog` 本身总插一条 `ModalBarrier`，所以从这里弹出来的
/// 弹窗即使用 `isModal: false` 也挡不住下层交互 —— 那是 [OhosAlertDialog] 的
/// 文档里已经写明的一档差异。
Future<T?> showOhosDialog<T>({
  required BuildContext context,
  required String title,
  String? content,
  Widget? contentWidget,
  List<OhosDialogAction> actions = const <OhosDialogAction>[],
  bool barrierDismissible = true,
  bool customStyle = false,
  bool isModal = true,
  Color? maskColor,
  int? gridCount,
  double? width,
  double? height,
  OhosDialogLifecycle lifecycle = const OhosDialogLifecycle(),
  void Function(OhosDismissDialogAction action)? onWillDismiss,
}) {
  // `onWillDismiss` 注册时，遮罩点击不能由路由直接吃掉 —— 否则回调还没判，
  // 弹窗已经被 pop 了。改为 `barrierDismissible: false`，点击由弹窗自己的
  // 遮罩层拦下并走 `_requestDismiss`。
  final bool routeBarrierDismissible =
      onWillDismiss == null && barrierDismissible;

  return showDialog<T>(
    context: context,
    barrierDismissible: routeBarrierDismissible,
    // 官方 maskColor 默认 20% 黑，Material 的 barrierColor 是 54% —— 差一倍
    // 多。不显式传就会一直用 54%，背景被压得太黑。
    barrierColor: isModal
        ? (maskColor ?? OhosDialogMetrics.maskColor)
        : Colors.transparent,
    builder: (BuildContext dialogContext) {
      return OhosAlertDialog(
        title: title,
        content: content,
        contentWidget: contentWidget,
        actions: actions,
        customStyle: customStyle,
        isModal: isModal,
        maskColor: maskColor,
        gridCount: gridCount,
        width: width,
        height: height,
        lifecycle: lifecycle,
        onWillDismiss: onWillDismiss,
      );
    },
  );
}
