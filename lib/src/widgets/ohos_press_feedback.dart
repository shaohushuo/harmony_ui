import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';

/// HarmonyOS 的按压反馈（按下变深一层），用来替代 Material 的水波纹。
///
/// **为什么必须换掉 `InkWell`**：Material 的 splash 是从触点扩散、随后淡出的
/// 一团圆形高光。它有三个 HarmonyOS 里不存在的特征：
///
/// 1. **有圆心和半径** —— 官方控件的按下态是「整块底板换一档色」
///    （`interactive_click`），形状与控件自身一致，不存在从一个点长出来的圆。
/// 2. **有扩散动画** —— 官方只做一次 90ms 的明度过渡，不表达「从哪里按下」。
/// 3. **会越过圆角** —— `InkWell` 的高光铺在 `Material` 上，圆角矩形上按下去
///    仍然能看到被裁掉一角的圆斑边缘。
///
/// 这三点加起来，一眼就能认出「这是 Material 的按钮」。所以本库所有可点区域都
/// 走这里：按下时在子节点之上铺一层 [pressedColor]（默认 `interactive_click`
/// 的 10% 黑），淡入 [OhosGeometry.durationPress]，松开淡出
/// [OhosGeometry.durationShort]，形状跟随 [borderRadius]。
///
/// 与 [OhosPressShadow] 的分工：那个是 HDS 的 `pressShadow` 视觉特效（白色混合
/// 或指尖径向渐变），属于可选的增强；这里是**基础交互反馈**，任何可点控件都该
/// 有这个，且不需要 `Material` 祖先。
///
/// ## 语义由这里统一接管
///
/// 本组件内部自带一层 `Semantics`（按钮角色 + 启用状态）。需要无障碍标签时
/// 传 [semanticLabel]，**不要**在外部再包一层 `Semantics(button: true)`：
/// 两层 button 语义不会合并，离屏时内层节点会退化为零宽，触发框架的
/// invisible-node 断言。需要合并外部零散语义时用 `MergeSemantics`。
class OhosPressFeedback extends StatefulWidget {
  const OhosPressFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressEnd,
    this.onLongPressCancel,
    this.onTapDown,
    this.semanticLabel,
    this.borderRadius,
    this.pressedColor,
    this.enabled = true,
    this.containedInkWell,
    this.clipBehavior = Clip.hardEdge,
  });

  /// 被包装的可点内容。
  final Widget child;

  /// 点击回调；null 表示不可交互（不注册手势，也不画按压态）。
  final VoidCallback? onTap;

  /// 长按回调。
  final VoidCallback? onLongPress;

  /// 长按结束（手指抬起）回调，参数是**本地坐标**。
  ///
  /// 注意框架在一次正常抬起时会先调 [onLongPressEnd] 再调 `onLongPressUp`，
  /// 本组件只注册前者，避免外部回调被调用两次。
  final ValueChanged<Offset>? onLongPressEnd;

  /// 长按被取消（手势输掉竞技场或收到 cancel 事件）回调。
  ///
  /// 取消时框架**不会**再调 [onLongPressEnd]，需要在这里做收尾
  /// （例如停止长按期间启动的定时器）。
  final VoidCallback? onLongPressCancel;

  /// 按下瞬间的回调，参数是**本地坐标**（供需要知道落点的调用方使用）。
  final ValueChanged<Offset>? onTapDown;

  /// 无障碍标签；由本组件统一出**唯一一层**按钮语义。
  ///
  /// 传入后不要再在外部包一层 `Semantics(button: true)`：两层 button 节点
  /// 不会自动合并，内层节点在离屏/被遮挡时会触发框架的
  /// 「Invisible SemanticsNodes should not be added to the tree」断言。
  /// 只要提供了标签，即使当前禁用（[onTap] 为 null），节点仍保持按钮角色，
  /// 只是 `enabled` 为 false —— 读屏会念出「按钮，已停用」。
  final String? semanticLabel;

  /// 内部 `Stack` 的裁剪方式。
  ///
  /// 默认 [Clip.hardEdge]。当 [child] 里有**故意画到自己盒子之外**的内容
  /// （例如底部页签的运营位：官方「运营资源可向上出血 4 vp」）时传
  /// [Clip.none]，否则那部分会被裁掉，看起来就是被削平了顶。
  ///
  /// 注意这**只影响本组件这一层**：外面若还有 `ClipRRect` / `ClipRect`
  /// （例如给栏体加圆角裁切的父级），照样会裁。
  final Clip clipBehavior;

  /// 按压层的圆角，默认直角。
  ///
  /// 传 `BorderRadius.circular(999)` 得到胶囊；圆形图标按钮传
  /// `BorderRadius.circular(size / 2)`。**这个圆角必须与控件的底板一致** ——
  /// 不一致时按下态会露出一个方角（`InkWell` 时代这个错误被 splash 的圆形
  /// 掩盖了，换成整块换色后就藏不住）。
  final BorderRadius? borderRadius;

  /// 按下态的颜色，默认取主题的 `interactivePressedColor`。
  final Color? pressedColor;

  /// false 时不响应手势、不画按压态。
  final bool enabled;

  /// 兼容参数：历史调用点从 `InkWell` 迁移过来时传 `true` 表示「这场按压反馈
  /// 应该被祖先的 `Material` 裁剪」。本组件自己裁剪，所以该参数不影响行为，
  /// 保留只为让迁移改动最小、且能在语义上留下痕迹。
  final bool? containedInkWell;

  /// 当前是否可交互。
  bool get isInteractive => enabled && onTap != null;

  @override
  State<OhosPressFeedback> createState() => _OhosPressFeedbackState();
}

class _OhosPressFeedbackState extends State<OhosPressFeedback>
    with SingleTickerProviderStateMixin {
  /// 0 = 松手，1 = 按住。
  ///
  /// 用 `AnimationController` 而不是 `AnimatedOpacity`：这里要的是一块**贴着
  /// 圆角走的色块**，不是矩形淡入。`AnimatedOpacity` 必须套 `ClipRRect` 才能
  /// 把矩形裁成圆角，而 `ClipRRect` 会在控件子树里凭空多一层裁剪节点，
  /// 让「壳在哪、裁剪在哪」变得难读（弹窗、芯片这些地方的结构断言都会撞上）。
  /// 自绘 RRect 既没有多余节点，也不需要 `saveLayer`。
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OhosGeometry.durationPress,
      reverseDuration: OhosGeometry.durationShort,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (!mounted) {
      return;
    }
    if (value) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 灰阶屏没有「叠一层」这回事：10% 的黑合成到纸上就是一档几乎看不见的灰，
    // 反而让整块区域在按下时轻微发脏。策略关掉水波纹时，按压反馈也一起不画。
    final Color pressed =
        widget.pressedColor ??
        theme.interactivePressedColor ??
        theme.policy.tint(theme.textPrimaryColor, 0.10);
    final Color overlay = theme.policy.allowsRipple
        ? theme.policy.tint(pressed, pressed.a)
        : Colors.transparent;
    final bool showOverlay = overlay.a > 0;

    // 语义只出这一层：有标签时即使禁用也保持按钮角色，外部不要再包 Semantics。
    final bool buttonRole =
        widget.isInteractive || widget.semanticLabel != null;
    return Semantics(
      button: buttonRole,
      enabled: widget.isInteractive,
      label: widget.semanticLabel,
      // GestureDetector 带了 excludeFromSemantics，它不会自己往语义树上挂
      // tap 动作 —— 不在这里补，读屏只会念「按钮」却点不动它。
      onTap: widget.isInteractive ? () => widget.onTap?.call() : null,
      child: GestureDetector(
        // 与 `InkWell` 一致：整块区域可点，而不只是子节点画到的地方。
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: widget.isInteractive
            ? (TapDownDetails d) {
                _setPressed(true);
                widget.onTapDown?.call(d.localPosition);
              }
            : null,
        onTapUp: widget.isInteractive
            ? (TapUpDetails _) => _setPressed(false)
            : null,
        onTapCancel: widget.isInteractive ? () => _setPressed(false) : null,
        onTap: widget.isInteractive ? widget.onTap : null,
        onLongPress: widget.isInteractive && widget.onLongPress != null
            ? () {
                widget.onLongPress!.call();
                // 长按触发后手指仍按着，抬起时不会再走 onTapUp —— 这里主动复位，
                // 否则按压态会一直留在屏幕上。
                _setPressed(false);
              }
            : null,
        onLongPressEnd: widget.isInteractive && widget.onLongPressEnd != null
            ? (LongPressEndDetails d) =>
                  widget.onLongPressEnd!.call(d.localPosition)
            : null,
        // 取消时框架不会再给 end 事件，单独回调收尾；与 end 互斥，不会重复。
        onLongPressCancel:
            widget.isInteractive && widget.onLongPressCancel != null
            ? () => widget.onLongPressCancel!.call()
            : null,
        child: Stack(
          fit: StackFit.passthrough,
          // 默认裁到自己的盒子：`Positioned.fill` 的按压色块本该只覆盖自身，
          // 不需要溢出。运营位（出血图标）这类**内容要画到框外**的场景显式
          // 传 `Clip.none`，否则外面那一圈越界绘制先被这里削掉。
          clipBehavior: widget.clipBehavior,
          children: <Widget>[
            widget.child,
            if (showOverlay)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) {
                      // 停稳后连画笔都不用挂：0 时不画，省掉一层 `CustomPaint`。
                      if (_controller.value == 0) {
                        return const SizedBox.expand();
                      }
                      return CustomPaint(
                        painter: _PressOverlayPainter(
                          progress: _controller.value,
                          color: overlay,
                          borderRadius:
                              widget.borderRadius ?? BorderRadius.zero,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 按 `progress` 淡入一块贴着圆角的实色 —— 这就是 HarmonyOS 的按下态。
class _PressOverlayPainter extends CustomPainter {
  const _PressOverlayPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
  });

  final double progress;
  final Color color;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0) {
      return;
    }
    final RRect rrect = borderRadius.toRRect(Offset.zero & size);
    final Paint paint = Paint()
      ..color = color.withValues(alpha: color.a * progress)
      ..isAntiAlias = true;
    canvas.drawRRect(rrect, paint);
  }

  // 每帧都按 progress 重画，所以相等性必须跟着 progress / 颜色 / 圆角走，
  // 否则主题切换（换 pressedColor）时这一层不会刷新。
  @override
  bool shouldRepaint(_PressOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius;
  }
}
