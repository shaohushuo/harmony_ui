import 'package:flutter/widgets.dart';

/// 一套屏幕的「表现规则」，与「是什么颜色」分开。
///
/// 色板回答「这层该是什么颜色」，本类回答另一个问题：**在目标屏幕上，这层
/// 颜色要怎么写才看得见**。彩屏靠分层（半透明叠色、阴影、模糊、水波纹），
/// 16 级灰的墨水屏靠线（1px 实色描边）。
///
/// 组件因此不再写 `theme.monochrome ? A : B`，而是把意图交给策略：
///
/// - 想铺一层底色 → [tint]，返回透明就说明这块底托不住形体，改画线；
/// - 想画一条状态线 → [line]，墨水屏会忽略 alpha 用实色；
/// - 问「能不能投影 / 模糊 / 水波纹」→ [allowsShadow] 等。
///
/// 换屏 = 换一个实现。要支持新屏幕（高对比模式、深色墨水屏）时新增一个子类
/// 即可，组件层不动。
@immutable
abstract class OhosVisualPolicy {
  const OhosVisualPolicy();

  /// 是否面向灰阶屏。
  ///
  /// 只用于「整体压成黑白」这种与具体形状无关的判断（彩页预览）。组件的形状
  /// 分支请走 [tint] / [line]，别读这个字段，否则新屏幕又得回来改组件。
  bool get isMonochrome;

  /// 把「[base] 色按 [alpha] 铺一层」落到当前屏幕，用于**填充**。
  ///
  /// 返回 [Colors.transparent] 表示这层色在当前屏上托不住形体，调用方应改用
  /// [line] 画线分界。这条约定替代了原先每个 `ink ? Colors.transparent : ...`
  /// 分支，也替代了「12% 的浅底在灰阶屏上等于没有」那类注释。
  Color tint(Color base, double alpha);

  /// 状态线的颜色，用于**描边 / 分隔线**。
  ///
  /// [base] 与 [alpha] 描述彩屏上想要的观感（发丝细、半透明）；墨水屏忽略
  /// [alpha]、直接量化 [base] 的实色 —— 因为灰阶屏上的线必须是实色才读得出，
  /// 而「实色该有多深」已经由色板定好了（如墨水屏的 `textTertiaryColor`
  /// 就是 `#767676`），策略不需要再猜。
  Color line(Color base, double alpha);

  /// 把任意颜色压到当前屏幕能表达的档位上。
  ///
  /// 彩屏原样返回；墨水屏量化到 16 级灰，避免 `alpha: 0.12` 那种落在第 0～3
  /// 级、肉眼等于没有的色块。
  Color quantize(Color color);

  /// 状态线宽度。null 表示这套主题靠底色分层，不需要线（彩屏）。
  double? get outlineWidth;

  /// 是否允许投影。墨水屏上阴影不存在，留着只是多一层刷新。
  bool get allowsShadow;

  /// 是否允许 `BackdropFilter` 模糊。墨水屏上是每帧全屏合成，表现为拖尾。
  bool get allowsBlur;

  /// 是否允许水波纹。墨水屏每次点按会留一块半透明灰且刷新慢。
  bool get allowsRipple;

  /// 是否允许「光」这类纯装饰性的明度叠加 —— 点光源、按压缩放的高光、
  /// 沉浸光感的边缘光晕。
  ///
  /// 与 [allowsShadow] 分开，因为它们在这块屏上的失败方式不同：阴影不存在
  /// 只是「少了点立体感」，而白色的光晕叠在纯黑字上会**直接糊掉正文**，
  /// 黑底场景下又完全看不见。灰阶屏上「光」这个隐喻本身不成立 —— 它没有
  /// 背光可言，读者看到的只是一块不该出现的浅灰。
  ///
  /// 挡住的是 [OhosPointLight]、[OhosPressShadow]、[OhosLightMaterial] 的
  /// 装饰层；它们真正的信息载体（底色、描边、图标）不受影响。
  ///
  /// 默认 `true` 而不是声明成抽象成员：本库承诺「加一块屏 = 写一个子类」，
  /// 而外部已经存在的自定义策略（高对比主题等）不该因为这里多一个能力声明
  /// 就编译失败。需要关掉光效的屏自己覆写成 `false`。
  bool get allowsGlow => true;

  /// 过渡时长缩放。墨水屏没有中间帧，长动画只会让人白等一次全屏刷新。
  Duration scaleMotion(Duration base);

  /// 一个「被禁用 / 不可交互」的实心形状该填什么色。
  ///
  /// 这类填充不能用 [tint] 推导：灰阶屏上 20% 的底留不住形体，而禁用态恰恰
  /// **必须**看得出轮廓（否则读者会去点它）。彩屏可以用浅色叠底，灰阶屏只能
  /// 给一档实灰。默认取 [line] 的实色 —— 对彩屏即原样、对灰阶屏即该 base 的
  /// 灰，是两边都读得出的保守选择；需要更浅的灰请在自己的策略里覆写。
  ///
  /// 这里给的是「颜色该怎么落地」，而不是「这块屏能不能填灰」—— 后者是能力
  /// 声明，前者才是组件真正要问的问题。
  Color disabledFill(Color base) => line(base, 1);

  /// 「已激活 / 已选中」时，用这抹颜色点亮一个小图标该取什么色。
  ///
  /// 与 [quantize] / [line] 的关键区别：**它保证结果比未激活态更醒目**。
  /// 灰阶量化会让高亮黄 `#F7CE00` 变成 `#C3C3C3`（亮度 0.55），比未选中态的
  /// `#767676`（亮度 0.18）**更淡** —— 语义直接反转，读者以为没点亮。
  /// 彩色的信息在灰阶屏上本来就存不住，只能换成明度对比，不是换一种灰。
  ///
  /// 之所以不复用 [disabledFill]：那个的语义是「降一档让位于可用态」，方向
  /// 恰好相反；叫 `disabledFill` 的地方将来也会按各自的语义演化。
  ///
  /// 默认原样返回 —— 彩屏的这抹黄本身就是「点亮」。
  Color litFill(Color base) => base;

  /// 没有底色、没有边框的可点击文字，要不要自己划一条下划线。
  ///
  /// 问的是「这块屏上靠什么认出这是可点的字」，不是「这块屏有没有某种能力」。
  /// 彩屏的 `text` 按钮靠品牌蓝就够了；灰阶屏上品牌色被压成纯黑，与正文
  /// 同色 —— 一个纯黑的「了解更多」和一句纯黑的正文，读者分不出哪个能点。
  /// 这时下划线不是装饰，是**唯一**的可供性线索。
  ///
  /// 默认跟随 [isMonochrome]：彩屏不加，墨水屏加。高对比主题如果靠粗描边或
  /// 加粗就能区分，覆写成 `false` 即可 —— 这正是它不该写成
  /// `usesOutlines ? ...` 的原因：描边与否和文字可供性是两件事。
  bool get underlinesTextActions => isMonochrome;

  @override
  String toString() => '$runtimeType';
}

/// 彩屏：分层表达，保留阴影 / 模糊 / 水波纹。
class ColorVisualPolicy extends OhosVisualPolicy {
  const ColorVisualPolicy();

  @override
  bool get isMonochrome => false;

  @override
  Color tint(Color base, double alpha) => base.withValues(alpha: alpha);

  @override
  Color line(Color base, double alpha) => base.withValues(alpha: alpha);

  @override
  Color quantize(Color color) => color;

  @override
  double? get outlineWidth => null;

  @override
  bool get allowsShadow => true;

  @override
  bool get allowsBlur => true;

  @override
  bool get allowsRipple => true;

  @override
  bool get allowsGlow => true;

  @override
  Duration scaleMotion(Duration base) => base;

  @override
  bool operator ==(Object other) => other is ColorVisualPolicy;

  @override
  int get hashCode => (ColorVisualPolicy).hashCode;
}

/// 墨水屏（如华为 MatePad Paper / NoteAir）：纯黑纯白，只靠 1px 实线分界。
///
/// 依据是 16 级灰面板的分辨力 —— 低于约 20% 的黑落在第 0～3 级，与白底不可
/// 区分，所以：
///
/// - [tint] 低于 20% 直接返回透明，让调用方改画线。真机背景：NoteAir 变更抽屉
///   里禁用的「提交 (0)」按钮整块消失，就是 20% 浅底 + 白字造成的。
/// - [line] 丢掉 alpha 用实色，并把结果对齐到 16 级灰。
///
/// [paper] 是灰阶量化的合成底色。默认纯白；要做「深色墨水屏」时传一块深色
/// 纸，不必另写一个策略子类 —— 但色值本身仍需另给一份（`OhosThemeData`）。
class InkVisualPolicy extends OhosVisualPolicy {
  const InkVisualPolicy({this.paper = const Color(0xFFFFFFFF)});

  /// 量化时把颜色合成到这块底色上，再取灰。
  final Color paper;

  @override
  bool get isMonochrome => true;

  @override
  Color tint(Color base, double alpha) {
    // 真机结论：20% 及以下的浅底留不住形状（「提交 (0)」按钮在 NoteAir 上整块
    // 消失 —— 那是 20% 黑底 + 白字）。判成透明后，调用方会自动改画实线。
    if (alpha <= 0.20) {
      return const Color(0x00000000);
    }
    return quantize(base.withValues(alpha: alpha));
  }

  @override
  Color line(Color base, double alpha) => quantize(base);

  /// 合成到纯白纸上并灰度化。
  ///
  /// **不**把结果吸附到 `level * 17` 的格子上：色板里的灰（`#767676`、
  /// `#CCCCCC`）本身就是为这块屏挑的，硬吸附会白白挪动一档，让「已经调好的
  /// 观感」因为重构而变。量化在这里只负责一件事 —— 去掉半透明，因为灰阶屏
  /// 没有「叠一层」这回事。
  @override
  Color quantize(Color color) {
    if (color.a == 0) {
      return const Color(0x00000000);
    }
    // 先合成到纸面：叠加后的实色才是这块屏实际显示的东西。
    final Color solid = Color.alphaBlend(color, paper);
    // sRGB 直接加权而不是 `computeLuminance()`：后者做了线性化，会把 #CCCCCC
    // 算成 0.60 而不是 0.80，整体偏暗。
    final double value = solid.r * 0.299 + solid.g * 0.587 + solid.b * 0.114;
    final int gray = (value * 255).round().clamp(0, 255);
    return Color.fromARGB(255, gray, gray, gray);
  }

  @override
  double? get outlineWidth => 1;

  @override
  bool get allowsShadow => false;

  @override
  bool get allowsBlur => false;

  @override
  bool get allowsRipple => false;

  /// 灰阶屏没有「背光」这回事 —— 白色光晕叠上去只是一块不该出现的浅灰，
  /// 压在正文上会直接糊掉。点光源 / 按压高光 / 沉浸光感因此整层不画，
  /// 它们承载信息的底色与描边照旧。
  @override
  bool get allowsGlow => false;

  @override
  Duration scaleMotion(Duration base) => Duration.zero;

  /// 禁用态填一档「比纸面亮、比正文暗」的实灰。
  ///
  /// 不能是纯黑（禁用会比可用还显眼），也不能再靠 [tint] 叠 25% 的底 ——
  /// 那正是灰阶屏上消失的那一类。override 是为了把「哪一档灰」从组件里搬到
  /// 策略里：组件只说「这是个禁用形状」，不关心这块屏的灰有多深。
  ///
  /// **跟着 [paper] 走**：白纸上给 `#BFBFBF`，深色纸上必须给 `#4D4D4D`。
  /// 写死一个值的话，深色墨水屏上禁用态会比可用态更亮 —— 读者会去点它，
  /// 这是比「看不见」更糟的失败方式。这也是要按纸色分流、而不是让调用方
  /// 自己 `copyWith` 一个策略的原因。
  @override
  Color disabledFill(Color base) => quantize(
    paper.computeLuminance() > 0.5
        ? const Color(0xFFBFBFBF)
        : const Color(0xFF4D4D4D),
  );

  /// 灰阶屏上「点亮」= 与纸面反差最大那一档实色，而不是量化出来的灰。
  ///
  /// 量化走的是感知明度（黄 ≈ 0.76），落在中间调，作为「已选中」比未选中的
  /// #767676 还淡。灰阶屏没有色相可用，唯一的强度轴就是明暗，所以直接取
  /// 纸面的反面：白纸上给纯黑、深色纸上给纯白。
  ///
  /// 依据面板特性：16 级灰里第 15 与第 0 级的反差最稳，中间档反而容易因为
  /// 抖动/温度漂移糊成一片。
  @override
  Color litFill(Color base) =>
      paper.computeLuminance() > 0.5
      ? const Color(0xFF000000)
      : const Color(0xFFFFFFFF);

  /// 策略按值比较：[paper] 不同的两个墨水屏策略不是同一个东西。
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InkVisualPolicy && other.paper == paper);

  @override
  int get hashCode => Object.hash(InkVisualPolicy, paper);

  @override
  String toString() => 'InkVisualPolicy(paper: $paper)';
}