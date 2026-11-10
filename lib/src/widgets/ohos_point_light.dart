import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ohos_theme.dart';

/// 组件自身是否发光（官方的 `hdsEffect.PointLightSourceType`）。
///
/// 与「受光」是两个独立开关，官方文档把它们拆得很清楚：
/// 「如果需要发光,配置 sourceType 属性;如果需要被照亮,配置 illuminatedType
/// 属性」。一个组件可以只发光、只受光、两者都做，或者都不做。
enum OhosPointLightSourceType {
  /// 不发光。仍然是**光源**（会照亮别的组件），只是自己那块底板不亮。
  none,

  /// 自身发亮（加一圈 bloom）。
  bright,
}

/// 受光类型（官方的 `hdsEffect.PointLightIlluminatedType`）。
///
/// 这五项决定「受光面画什么」，**不**决定「哪儿亮」—— 后者由光源的实际
/// 相对位置算出来（见 [OhosIlluminated]）。
enum OhosPointLightIlluminatedType {
  /// 不受光。
  none,

  /// 只有朝向光源的那条边亮。
  border,

  /// 只有面上的光池，边缘不亮。
  content,

  /// 边亮 + 面亮。
  borderContent,

  /// 更宽、更柔的羽化描边（官方 `DEFAULT_FEATHERING_BORDER`）。
  defaultFeatheringBorder,
}

/// 光源参数，对应官方 `pointLight({ options: { color, intensity, height } })`。
///
/// 三个默认值都来自官方示例里的写法
/// （`options: { color: Color.White, intensity: 10, height: 150 }`）。
class OhosPointLightOptions {
  const OhosPointLightOptions({
    this.color = Colors.white,
    this.intensity = 10,
    this.height = 150,
  });

  /// 光的颜色。
  final Color color;

  /// 光的强度。官方示例用 **10** 作基准值；`0` 等于不发光。
  ///
  /// 官方 Java/Python 侧的取值范围是 0–1（那是 `LightSource.intensity`），
  /// 而 ArkTS 的 `pointLight(options)` 示例写的是 10 —— 两套 API 的量纲不同。
  /// 这里跟 ArkTS 的 10，因为它是 `hdsEffect` 这一侧的参数。
  final double intensity;

  /// 光源离受光面的高度。
  ///
  /// 「光源越高，光照范围越广」（官方原文：The higher the light source, the
  /// broader the light distribution）。高度越大，光池越大越淡。
  final double height;

  @override
  bool operator ==(Object other) =>
      other is OhosPointLightOptions &&
      other.color == color &&
      other.intensity == intensity &&
      other.height == height;

  @override
  int get hashCode => Object.hash(color, intensity, height);
}

/// 光源注册表：同一 [OhosPointLightScope] 内的光源与受光面共享一份。
///
/// 这是官方语义在 Flutter 里的落点。ArkUI 的 `visualEffect(pointLight(...))`
/// 是引擎级的：引擎知道所有组件的位置，所以**不需要**调用方告诉它「光从哪个
/// 方向来」。Flutter 没有这种全局效果通道，只能自己搭一条：
///
/// - [OhosLightSource] 把自己登记进来（带一个 `RenderBox` 引用）；
/// - [OhosIlluminated] 在绘制时按需换算成自己的本地坐标。
///
/// 位置在**绘制时**才求值，而不是在 build 时：build 阶段 sibling 的布局还没
/// 完成，那时拿到的尺寸是上一帧的。
class _LightRegistry extends ChangeNotifier {
  final Set<_OhosLightSourceState> _sources = <_OhosLightSourceState>{};
  bool _notifyQueued = false;

  /// 是否已经 `dispose()`。
  ///
  /// 必须自己记：`ChangeNotifier` 的 `debugAssertNotDisposed` 只在 debug 下
  /// 抛断言，release 下 `notifyListeners` 会静默跑在已释放的对象上。而这里的
  /// 通知是**延时**的（下一帧回调），「排队时还活着、执行时已经销毁」是常态
  /// —— 每次页面跳转、每个 `OhosPointLightScope` 被移除都会走到。
  bool _disposed = false;

  Iterable<_OhosLightSourceState> get sources => _sources;

  void register(_OhosLightSourceState source) {
    _sources.add(source);
    _queueNotify();
  }

  void unregister(_OhosLightSourceState source) {
    if (_sources.remove(source)) {
      _queueNotify();
    }
  }

  /// 布局可能变了，通知受光面重画。
  ///
  /// 必须延到帧末：注册发生在 `didChangeDependencies`（也就是 build 期间），
  /// 当场 `notifyListeners()` 会让 `InheritedNotifier` 在 build 过程中触发
  /// 重建，直接报 "setState() or markNeedsBuild() called during build"。
  void _queueNotify() {
    if (_notifyQueued || _disposed) {
      return;
    }
    _notifyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyQueued = false;
      // 排队到执行之间可能已经 dispose 了。
      if (_disposed) {
        return;
      }
      notifyListeners();
    });
  }

  /// 光源的布局可能变了（比如父容器尺寸变化），需要重算位置。
  void positionChanged() => _queueNotify();

  @override
  void dispose() {
    _disposed = true;
    _sources.clear();
    super.dispose();
  }
}

/// 点光源的作用域：把发光源与受光面放进同一个坐标系。
///
/// 官方示例里，光源是容器中间那个 Button，受光的是它周围的 15 个圆 —— 它们
/// 是**兄弟节点**，引擎靠布局算相对位置。这里同理：放进同一个
/// [OhosPointLightScope] 里，[OhosIlluminated] 会自动找到最近的光源。
///
/// 一个 scope 内最多 12 个光源生效（官方约束：单个组件最多同时受 12 个光源
/// 照亮），超出的按注册顺序截断。
class OhosPointLightScope extends StatefulWidget {
  const OhosPointLightScope({super.key, required this.child});

  final Widget child;

  @override
  State<OhosPointLightScope> createState() => _OhosPointLightScopeState();
}

/// 当前节点的注册表；没有 scope 时返回 null。
_LightRegistry? _registryOf(BuildContext context) {
  return context
      .dependOnInheritedWidgetOfExactType<_PointLightScopeMarker>()
      ?.registry;
}

/// 单个受光面最多同时受几个光源照亮（官方约束：12）。
///
/// 放在这里而不是 [OhosPointLightScope] 的静态成员上：那个类公开了
/// `maybeRegistryOf`，其返回类型是私有的，再挂常量只会把问题变复杂。
const int ohosPointLightMaxSources = 12;

class _OhosPointLightScopeState extends State<OhosPointLightScope> {
  final _LightRegistry _registry = _LightRegistry();

  @override
  void dispose() {
    _registry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PointLightScopeMarker(registry: _registry, child: widget.child);
  }
}

class _PointLightScopeMarker extends InheritedNotifier<_LightRegistry> {
  const _PointLightScopeMarker({
    required _LightRegistry registry,
    required super.child,
  }) : super(notifier: registry);

  _LightRegistry get registry => notifier!;
}

/// 一个发光源（官方 `sourceType` 的那一半）。
///
/// 只负责「自己发光」和「登记自己的位置」，不负责画别人身上的光 —— 那是
/// [OhosIlluminated] 的事。这两件事在官方是同一个 `pointLight()` 调用，但
/// 在 Flutter 里必须分开：一个 widget 没法画到兄弟 widget 身上。
///
/// ```dart
/// OhosPointLightScope(
///   child: Stack(children: <Widget>[
///     OhosLightSource(child: myButton),          // 按下时亮
///     OhosIlluminated(illuminatedType: ..., child: myCard),
///   ]),
/// )
/// ```
class OhosLightSource extends StatefulWidget {
  const OhosLightSource({
    super.key,
    required this.child,
    this.sourceType = OhosPointLightSourceType.bright,
    this.options = const OhosPointLightOptions(),
  });

  /// 光源自己的外观。发光是叠加在它**之上**的一层 bloom，不改变它原本的
  /// 底色与描边 —— 官方的 `bloom` 同样是叠加发光度，不是替换颜色。
  final Widget child;

  /// 自身是否发亮。
  final OhosPointLightSourceType sourceType;

  /// 照亮别人时用的参数。
  final OhosPointLightOptions options;

  @override
  State<OhosLightSource> createState() => _OhosLightSourceState();
}

class _OhosLightSourceState extends State<OhosLightSource> {
  final GlobalKey _anchor = GlobalKey();

  _LightRegistry? _registry;

  /// 上一次登记时的全局矩形。
  ///
  /// 用它来抑制「位置没变也通知」：`didChangeDependencies` 在父容器重建、
  /// 主题变化时都会跑，无条件通知会让注册表每帧都排一次「下一帧再通知」，
  /// `pumpAndSettle` 于是永远等不到静止（表现为超时），真机上则是一直多画
  /// 一层 —— 而画面其实没有任何变化。
  Rect? _lastRect;

  /// 光源在**全局坐标**里的矩形；布局未完成时返回 null。
  ///
  /// 用全局坐标做中转，是因为受光面与光源只共享「屏幕」这个坐标系 —— 它们
  /// 中间可能隔着若干层 `Padding` / `Stack` / `Column`，逐层反推变换很容易
  /// 漏一层。
  Rect? get globalRect {
    final RenderObject? object = _anchor.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      return null;
    }
    return object.localToGlobal(Offset.zero) & object.size;
  }

  /// 位置若与上次不同，通知受光面重算。
  void _syncPosition() {
    final Rect? rect = globalRect;
    if (rect == _lastRect) {
      return;
    }
    _lastRect = rect;
    _registry?.positionChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final _LightRegistry? next = _registryOf(context);
    if (next != _registry) {
      _registry?.unregister(this);
      _registry = next;
      _registry?.register(this);
      _lastRect = null;
    }
    // 布局在这一轮才刚跑，`globalRect` 可能还是旧值（或 null）——
    // 延到帧末再比，避免拿到半成品位置。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncPosition();
      }
    });
  }

  @override
  void dispose() {
    _registry?.unregister(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final Widget body = KeyedSubtree(key: _anchor, child: widget.child);

    final bool glowing =
        widget.sourceType == OhosPointLightSourceType.bright &&
        widget.options.intensity > 0;
    // 灰阶屏上没有「光」这个隐喻：白晕叠上去只是一块浅灰，压在纯黑底上
    // 反而像「蒙了一层雾」。策略不允许就只留 child 本身。
    if (!glowing || !theme.policy.allowsGlow) {
      return body;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        body,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _LightSourcePainter(
                color: widget.options.color,
                intensity: widget.options.intensity,
                height: widget.options.height,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 光源自身的 bloom。
///
/// 官方没有给「发光源长什么样」的具体数值，只给了两个可调项：`intensity`
/// 与 `height`。所以这里不做拟真光照，只保证两件事：
///
/// 1. **强度单调** —— `intensity` 越大，光晕越亮越大；
/// 2. **高度单调** —— `height` 越高，光晕越散（同一份能量铺到更大面积上）。
///
/// 这两条是唯一的可验证语义，也是判断「效果调对没有」的唯一依据。
class _LightSourcePainter extends CustomPainter {
  const _LightSourcePainter({
    required this.color,
    required this.intensity,
    required this.height,
  });

  final Color color;
  final double intensity;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final Offset center = size.center(Offset.zero);
    final Rect bounds = Offset.zero & size;

    // 归一化强度：官方示例的 10 当作「标准亮度」，20 大约亮一倍。
    final double strength = (intensity / 10).clamp(0.0, 3.0);
    // 高度归一化：150 是官方示例值，当作「标准扩散」。
    final double spread = (height / 150).clamp(0.2, 4.0);
    // 峰値透明度不会超过 1，但会随强度增长；上限 0.9 是为了留住 child 的
    // 轮廓 —— 全白会把它糊成一个圆。
    final double peak = (0.32 * strength).clamp(0.0, 0.9).toDouble();

    // 画布比 child 大一圈：bloom 必须能溢出到自身边界之外，否则看起来只是
    // 「组件变亮了」而不是「它在发光」。这里让渐变半径覆盖整个 size，并在
    // size 之外由父级裁掉（`Stack` 默认 clipBehavior 是 hardEdge）。
    final double radius = size.shortestSide / 2;

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: peak),
            color.withValues(alpha: peak * 0.45),
            color.withValues(alpha: 0),
          ],
          // 越高的光源，能量铺得越开：把中段往后推。
          stops: <double>[0, 0.35 + 0.25 * (1 - 1 / spread), 1],
        ).createShader(bounds),
    );

    // 核心高光：一小块近乎不透明的亮斑。没有它，bloom 在深色底上只是一团
    // 灰雾，读不出「光源」这个身份。
    final Rect coreRect = Rect.fromCircle(
      center: center,
      radius: radius * 0.55,
    );
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: (peak * 1.6).clamp(0.0, 1.0)),
            color.withValues(alpha: 0),
          ],
        ).createShader(coreRect),
    );
  }

  @override
  bool shouldRepaint(_LightSourcePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.intensity != intensity ||
        oldDelegate.height != height;
  }
}

/// 一个受光面（官方 `illuminatedType` 的那一半）。
///
/// ## 为什么不再有 `lightAlignment`
///
/// 早先这个组件要求调用方传 `lightAlignment`（「光从哪个方向来」），再据此
/// 在**固定的一侧**画光池与月牙。那是凭空猜的方向：只要光源一挪，画出来的
/// 光就与真实位置无关了。官方没有这个参数 —— 光源就在容器里，位置是**已知
/// 量**，不需要谁去描述它。
///
/// 现在位置从 [OhosPointLightScope] 里注册的光源算出来：每个受光面在绘制时
/// 取光源的全局矩形，换算成自己的本地坐标，再按「离光源多远、面向哪边」
/// 决定亮度和分布。光源挪了，光就跟着挪。
///
/// ## 单个受光面最多 12 个光源
///
/// 官方约束「单个组件最多同时受 12 个光源照亮」。超出部分按注册顺序截断 ——
/// 静默丢弃不好，但这里没有比「不画」更合理的降级：叠加 13 个光晕的效果与
/// 12 个无法区分，而拒绝渲染整个组件更糟。
class OhosIlluminated extends StatefulWidget {
  const OhosIlluminated({
    super.key,
    required this.child,
    this.illuminatedType = OhosPointLightIlluminatedType.borderContent,
    this.borderRadius = BorderRadius.zero,
    this.clipContent = true,
  });

  /// 受光面的内容。
  final Widget child;

  /// 受光形态。
  final OhosPointLightIlluminatedType illuminatedType;

  /// 受光面的圆角。光会被裁在这个形状里。
  final BorderRadius borderRadius;

  /// 是否用 [borderRadius] 裁剪 [child]。
  ///
  /// 与光照无关 —— 光**始终**画在形状内。保留这个开关是因为有些内容（阴影、
  /// 焦点环）本来就该溢出边界。
  final bool clipContent;

  @override
  State<OhosIlluminated> createState() => _OhosIlluminatedState();
}

class _OhosIlluminatedState extends State<OhosIlluminated> {
  final GlobalKey _anchor = GlobalKey();

  /// 把注册表里的光源换算成本地坐标。
  ///
  /// 在 `paint` 里调用（那时全局布局一定完成了）。返回的是**惰性**求值结果，
  /// 不是缓存 —— 缓存会让「容器尺寸变化」这种没有 rebuild 的情形停留在旧
  /// 位置上。
  List<_ResolvedLight> _resolve(Size size) {
    final _LightRegistry? registry = _registry;
    if (registry == null) {
      return const <_ResolvedLight>[];
    }
    final RenderObject? object = _anchor.currentContext?.findRenderObject();
    if (object is! RenderBox || !object.hasSize) {
      return const <_ResolvedLight>[];
    }
    final Offset origin = object.localToGlobal(Offset.zero);

    final List<_ResolvedLight> lights = <_ResolvedLight>[];
    for (final _OhosLightSourceState source in registry.sources) {
      if (lights.length >= ohosPointLightMaxSources) {
        break;
      }
      final Rect? rect = source.globalRect;
      if (rect == null) {
        continue;
      }
      // 光源以自身中心为发射点。用中心而不是左上角：官方示例里光源是一个
      // 圆形按钮，光的中心就是它的圆心。
      lights.add(
        _ResolvedLight(
          center: rect.center - origin,
          options: source.widget.options,
        ),
      );
    }
    // 只做记录，不影响绘制。
    lastResolvedLightCenters = <Offset>[
      for (final _ResolvedLight l in lights) l.center,
    ];
    return lights;
  }

  _LightRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry = _registryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = widget.clipContent
        ? ClipRRect(borderRadius: widget.borderRadius, child: widget.child)
        : widget.child;

    if (widget.illuminatedType == OhosPointLightIlluminatedType.none) {
      return content;
    }

    final OhosThemeData theme = OhosTheme.of(context);
    // 与 OhosLightSource 同一条判据：灰阶屏上「光」不成立。
    if (!theme.policy.allowsGlow) {
      return content;
    }
    // 没有 scope 就没法知道光在哪。这是用法错误，但**不 assert**：
    //
    // 一个「少了个祖先」的错误，代价应该是「少一层光」，不是「整块页面红屏」
    // —— 受光面本身是有用的内容容器，不该被光照配置连坐。撰写期用
    // `debugPrint` 留一条线索，release 下静默降级。
    if (_registry == null) {
      assert(() {
        debugPrint(
          'OhosIlluminated 不在 OhosPointLightScope 内：受光面的亮度取决于光源的'
          '实际位置，而位置只能在同一作用域内解析。当前降级为「只渲染内容、'
          '不画光」。',
        );
        return true;
      }());
      return content;
    }

    return KeyedSubtree(
      key: _anchor,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _IlluminationPainter(
                  type: widget.illuminatedType,
                  borderRadius: widget.borderRadius,
                  resolve: _resolve,
                  repaint: _registry!,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一个光源换算到受光面本地坐标后的形态。
class _ResolvedLight {
  const _ResolvedLight({required this.center, required this.options});

  /// 光源中心在受光面**本地坐标**里的位置（可能落在受光面边界之外）。
  final Offset center;

  final OhosPointLightOptions options;
}

/// 上一次受光面解析出的光源位置（本地坐标），供测试断言。
///
/// 为什么要开这个口子：这套实现唯一的验收点是「光跟着光源走」，而它的判据
/// 只存在于绘制那一刻。试过两条更"干净"的路，都不通：
///
/// - 读 `Paint.shader` 反推渐变中心 —— `Gradient.createShader()` 返回的是
///   `dart:ui` 的内部 `Gradient`，与 `painting.RadialGradient` 同名但不同
///   类型，取不到 `center`；
/// - 截图比像素 —— `RenderRepaintBoundary.toImage()` 要求 `!debugNeedsPaint`，
///   而 `CustomPainter` 的图层在测试环境的下一帧才落盘，`runAsync` 里先撞上
///   这条断言。
///
/// 所以留一个只读的记录点。它是**观察**而不是开关：不改变任何绘制行为，
/// release 下也不参与逻辑（写入本身是一次 list copy，可以忽略）。
@visibleForTesting
List<Offset> lastResolvedLightCenters = const <Offset>[];

/// 清空 [lastResolvedLightCenters]，用例间互不影响。
@visibleForTesting
void resetResolvedLightCenters() {
  lastResolvedLightCenters = const <Offset>[];
}

class _IlluminationPainter extends CustomPainter {
  _IlluminationPainter({
    required this.type,
    required this.borderRadius,
    required this.resolve,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final OhosPointLightIlluminatedType type;

  final BorderRadius borderRadius;

  /// 每次绘制时重新求值的光源列表。
  final List<_ResolvedLight> Function(Size size) resolve;

  bool get _hasContent =>
      type == OhosPointLightIlluminatedType.content ||
      type == OhosPointLightIlluminatedType.borderContent;

  bool get _hasBorder =>
      type == OhosPointLightIlluminatedType.border ||
      type == OhosPointLightIlluminatedType.borderContent ||
      type == OhosPointLightIlluminatedType.defaultFeatheringBorder;

  /// 描边宽度（vp）。
  ///
  /// 官方**没有**给这一项数值，只说 `DEFAULT_FEATHERING_BORDER` 是「羽化」的
  /// 那一档。所以这两个数是从观感倒推的常量，不是令牌：常规描边 4、羽化 14。
  /// 羽化档必须明显更宽，否则它和 `border` 就只剩渐变曲线的差别，四种形态
  /// 看起来只有三种。
  static const double _borderWidth = 4;
  static const double _featheredBorderWidth = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final List<_ResolvedLight> lights = resolve(size);
    if (lights.isEmpty) {
      return;
    }

    final Rect bounds = Offset.zero & size;
    final RRect shape = borderRadius.toRRect(bounds);
    // 半径换算：`RadialGradient.radius` 是相对 rect **较短边的一半**的比例，
    // 而这里想表达的是「vp 值」，所以除一下。
    final double unit = size.shortestSide / 2;

    // 多个光源时逐个叠加。用 `BlendMode.plus`：光本来就是加色的，两块光斑
    // 重叠处应该更亮，而不是「后画的盖掉先画的」。
    canvas.saveLayer(bounds, Paint());

    for (final _ResolvedLight light in lights) {
      final OhosPointLightOptions options = light.options;
      final double strength = (options.intensity / 10).clamp(0.0, 3.0);
      if (strength <= 0) {
        continue;
      }
      final double height = options.height.clamp(1.0, 4000.0);
      final Offset lightPos = light.center;

      // 光源到受光面中心的距离，用来做「越近越亮」的衰减。
      // 平方反比会让远处的光掉得太快（一屏之内基本全黑），官方也没有说明
      // 用哪条衰减曲线，所以取一条线性 + 高度归一化的式子：高度越大，同一
      // 距离下的衰减越慢（这正是「光源越高，光照范围越广」）。
      final double distance = (lightPos - bounds.center).distance;
      final double falloff = height / (height + distance);

      if (_hasContent) {
        _paintContent(
          canvas: canvas,
          bounds: bounds,
          shape: shape,
          unit: unit,
          lightPos: lightPos,
          color: options.color,
          strength: strength * falloff,
          height: height,
        );
      }
      if (_hasBorder) {
        _paintBorder(
          canvas: canvas,
          bounds: bounds,
          shape: shape,
          unit: unit,
          lightPos: lightPos,
          color: options.color,
          strength: strength * falloff,
          height: height,
        );
      }
    }

    canvas.restore();
  }

  /// 面上的光池。
  ///
  /// 用**以光源为原点的径向渐变**直接填满形状：离光源近的地方亮、远的暗，
  /// 不需要额外判断「受光面在光源的哪一侧」。这是「位置驱动」与「方向参数
  /// 驱动」的分水岭 —— 前者光源一挪就跟着变，后者永远固定在一侧。
  void _paintContent({
    required Canvas canvas,
    required Rect bounds,
    required RRect shape,
    required double unit,
    required Offset lightPos,
    required Color color,
    required double strength,
    required double height,
  }) {
    // 峰值透明度：官方没有给出可换算的数值，取一条单调曲线并留出上限，
    // 保证 `intensity` 从 0 调到 30 时是「渐亮」而不是「一下子全白」。
    final double peak = (0.30 * strength).clamp(0.0, 0.75).toDouble();
    if (peak <= 0) {
      return;
    }
    // 光池半径随高度增长：150 的高度在 60vp 的圆上大约铺满整个面。
    final double poolRadius = unit * (0.6 + height / 300);
    final Rect shaderRect = bounds;

    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawRRect(
      shape,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: _alignmentOf(lightPos, shaderRect),
          radius: (poolRadius / unit).clamp(0.05, 8.0),
          colors: <Color>[
            color.withValues(alpha: peak),
            color.withValues(alpha: peak * 0.55),
            color.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(shaderRect),
    );
    canvas.restore();
  }

  /// 边缘受光。
  ///
  /// 同样用「以光源为原点的径向渐变」当描边画笔：靠近光源的那段边落在渐变
  /// 内圈（亮），背对的那段落在外圈（暗）。这一条就同时表达了「哪条边亮」
  /// 和「亮多少」，不需要逐边算 `dot(normal, lightDir)`。
  void _paintBorder({
    required Canvas canvas,
    required Rect bounds,
    required RRect shape,
    required double unit,
    required Offset lightPos,
    required Color color,
    required double strength,
    required double height,
  }) {
    final bool feathered =
        type == OhosPointLightIlluminatedType.defaultFeatheringBorder;
    final double width = feathered ? _featheredBorderWidth : _borderWidth;
    final double peak = (0.55 * strength).clamp(0.0, 0.95).toDouble();
    if (peak <= 0) {
      return;
    }
    final double glowRadius = unit * (0.8 + height / 260);

    canvas.drawRRect(
      shape.deflate(width / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          center: _alignmentOf(lightPos, bounds),
          radius: (glowRadius / unit).clamp(0.05, 8.0),
          colors: <Color>[
            color.withValues(alpha: peak),
            // 羽化档把中段抬高，让光往背光侧多渗一段；常规档掉得快，
            // 形成「只有一条边亮」的对比。
            color.withValues(alpha: feathered ? peak * 0.55 : peak * 0.16),
            color.withValues(alpha: 0),
          ],
          stops: <double>[0, feathered ? 0.7 : 0.4, 1],
        ).createShader(bounds),
    );
  }

  /// 全局本地坐标 → `Alignment`（-1..1，相对 rect 中心）。
  static Alignment _alignmentOf(Offset position, Rect rect) {
    final double halfWidth = rect.width / 2;
    final double halfHeight = rect.height / 2;
    if (halfWidth <= 0 || halfHeight <= 0) {
      return Alignment.center;
    }
    return Alignment(
      ((position.dx - rect.center.dx) / halfWidth).clamp(-2.0, 2.0),
      ((position.dy - rect.center.dy) / halfHeight).clamp(-2.0, 2.0),
    );
  }

  @override
  bool shouldRepaint(_IlluminationPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.resolve != resolve;
  }
}

/// 供示例/测试使用的公开换算：光源与受光面中心连线在受光面**本地坐标**里
/// 的方向。
///
/// 暴露它是因为「光是不是真的跟着光源走」是这套实现唯一的验收点，而这个
/// 验收需要能在不读私有 painter 的情况下做断言。
Alignment ohosPointLightDirection({
  required Offset lightCenter,
  required Rect surface,
}) {
  final Offset delta = lightCenter - surface.center;
  final double distance = delta.distance;
  if (distance == 0) {
    return Alignment.center;
  }
  return Alignment(
    (delta.dx / math.max(surface.width / 2, 1e-6)).clamp(-1.0, 1.0),
    (delta.dy / math.max(surface.height / 2, 1e-6)).clamp(-1.0, 1.0),
  );
}
