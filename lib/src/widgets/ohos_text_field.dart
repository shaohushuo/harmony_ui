import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_theme.dart';
import 'ohos_press_feedback.dart';
import 'ohos_selection_toolbar.dart';

/// Visual variant of [OhosTextField].
enum OhosTextFieldVariant {
  /// ArkUI default: transparent background with an accent underline.
  underline,

  /// Gray rounded block without a line, the common HarmonyOS form field.
  ///
  /// On an e-ink theme (`OhosThemeData.monochrome`) the fill would equal the
  /// page background, so the field falls back to a transparent background with
  /// a 1px border instead of a fill.
  filled,

  /// Fully rounded search-like field with a 1px outline.
  capsule,

  /// ArkUI `TextInputStyle.Inline` —— 内联输入风格（6.0.0 / API 9 起）。
  ///
  /// 用于「明显区分编辑态与非编辑态」的场景，例如文件列表里的重命名：非编辑
  /// 时它就是一行普通文本，点下去才变成输入框。**它不是「第五种配色」** ——
  /// 与上面三种是**另一个维度**：那三种管底板怎么画，这个管「输入框要不要看
  /// 起来像输入框」。官方枚举里 `Default` / `Inline` 也只互斥两档。
  ///
  /// 三处官方硬约束（照抄会错的地方）：
  /// * **只支持 `InputType.Normal`**（官方原文「内联输入风格只支持
  ///   `InputType.Normal` 类型」）。给了 `obscurePassword: true` 就回落成
  ///   [underline] —— 静默画出一个「内联的密码框」是官方没有的形态。
  ///   [multiline] 同理：内联是单行语义（整行重命名）。
  /// * **不支持 `showError`**（本库对应 [errorText]）：给了也不画，只留下边框
  ///   与计数器照常工作的部分 —— 官方是「不支持」，不是「画得不一样」。
  /// * **不支持拖入文本**，Flutter 侧靠 `TextField.onTapOutside` 之外没有
  ///   对应开关，记为边界写进 dartdoc。
  ///
  /// 几何全部取 `ohos_textfield_pattern` 的 `inline_*` 系列：圆角
  /// `inline_radius_size` = `corner_radius_level2` = **4**、底板
  /// `inline_bg_color` = `background_primary`、描边 `inline_border_color` =
  /// `comp_background_emphasize`、左内边距 `textfield_inline_padding_left` =
  /// **2**、右内边距 `textfield_inline_padding_right` = **12** ——
  /// **左右不对称是官方值，不是笔误**，左边贴紧前文、右边留出光标余量。
  inline,
}

/// 计数器的配置项，对应 ArkUI `InputCounterOptions`（API 11 起）。
///
/// 只有 [OhosTextField.showCounter] 为 `true` 时才生效，且**必须配
/// `maxLength`** —— 官方原话「文本框开启计数下标功能，需要配合 `maxLength`
/// 一起使用」，没有上限的计数器分母是 `Infinity`，没有意义。本库在
/// `maxLength == null` 时直接不画。
@immutable
class OhosInputCounterOptions {
  const OhosInputCounterOptions({
    this.thresholdPercentage,
    this.highlightBorder = true,
  });

  /// 超过「最大字符数 × 本百分比」时才显示计数器；`null` 表示**一有输入就显示**。
  ///
  /// 官方：有效区间 `[1, 100]`，小数向下取整；**超出区间时「不显示字符计数
  /// 器」**（不是夹到边界值）。这与「传 `undefined`」是两种截然不同的结果：
  /// 后者显示计数器但不按阈值过滤。`null` 对应 `undefined`。
  final int? thresholdPercentage;

  /// 溢出时是否把边框也变红；`false` 则只让计数文字变红（官方默认 `true`）。
  ///
  /// 注意官方的措辞是「**同时设置了** `InputCounterOptions` 且阈值在有效区间内」
  /// 才会变红 —— 也就是说只传 `showCounter(true)` 不传 options 时，溢出**不会
  /// 变红**，只有字数超了本身（由 `maxLength` 挡住）。本库照此实现。
  final bool highlightBorder;

  /// 溢出时是否该变红：见 [highlightBorder] 的说明。
  bool highlightsOnOverflow(int length, int maxLength) {
    if (!highlightBorder) {
      return false;
    }
    final int? t = thresholdPercentage;
    if (t == null) {
      return false;
    }
    if (t < 1 || t > 100) {
      return false;
    }
    return length > maxLength;
  }

  /// 计数文字是否该显示。
  bool isVisible(int length, int maxLength) {
    final int? t = thresholdPercentage;
    if (t == null) {
      return true;
    }
    if (t < 1 || t > 100) {
      return false;
    }
    return length > maxLength * t ~/ 100;
  }

  @override
  bool operator ==(Object other) {
    return other is OhosInputCounterOptions &&
        other.thresholdPercentage == thresholdPercentage &&
        other.highlightBorder == highlightBorder;
  }

  @override
  int get hashCode => Object.hash(thresholdPercentage, highlightBorder);
}

/// `ohos_textfield_pattern` 里与本组件相关、且被追到最终值的令牌。
///
/// **与 `OhosListItemCardMetrics` 相反，这一组几乎每个值都能沿
/// `$float:` 链走到具体的 vp/fp** —— 因为 `TextInput` 是开源组件，
/// `doc/reference/resources/pattern.json` 里的 `ohos_textfield_pattern`
/// 有 115 个属性、且都有对应资源。**「令牌有值」不等于「令牌生效」**，
/// 所以下面标了适用形态的那几条，来源是组件真正读它的那条路径
/// （`textfield_height` / `textfield_content_height` / `textfield_border_radius`
/// 都是容器与下划线形态在用），而不是「表里有就抄」。
class OhosTextFieldMetrics {
  const OhosTextFieldMetrics._();

  /// 容器高（`textfield_height` → `ohos_id_textfield_height` = 40）。
  ///
  /// 这个数不是「随便定的舒适高度」，而是**由内边距与内容高算出来的**：
  /// `paddingVertical`(8) + `contentHeight`(24) + `paddingVertical`(8) = 40。
  /// 三者任改其一都要重算 —— 早前 `contentPadding` 自拟成 14/14 时，实测
  /// 填充形态渲染成 52vp，与本常量对不上（见 `_boxedDecoration`）。
  static const double height = 40;

  /// 内容区高（`textfield_content_height` → `ohos_id_textfield_content_height`）。
  static const double contentHeight = 24;

  /// 密码形态高（`password_style_height` → `ohos_id_password_style_height`）。
  ///
  /// **48，比普通形态的 40 高 8** —— 官方给密码框单独留了更高的容器。这条
  /// 容易漏：它不在主几何里，只在 `password_style_height` 一个属性上。
  static const double passwordHeight = 48;

  /// 容器圆角（`textfield_border_radius` → `corner_radius_level10` = 20）。
  ///
  /// 这是**填充 / 胶囊形态**真正在用的那个圆角。证据在实现侧：
  /// `text_field_pattern.cpp` 清零用户未指定圆角时的分支是
  /// `auto radius = theme->GetBorderRadius();`，紧接着一行
  /// `auto ultimatelyRadius = IsUnderlineMode() ? ZERO_BORDER_RADIUS_PROPERTY
  /// : borderRadius;` —— 即「非下划线形态用 `textfield_border_radius`，
  /// 下划线形态**显式归零**」。
  static const double containerRadius = 20;

  /// 边框圆角（`border_radius_size` → `textfield_container_border_radius_size`
  /// → `corner_radius_level6` = 12）。
  ///
  /// **死令牌，不参与渲染。** `textfield_theme.h` 里确有
  /// `borderRadiusSize_` 成员与 `GetBorderRadiusSize()` 访问器（源码默认
  /// 20.0_vp，与 pattern.json 里追到的 12 不一致），但在
  /// `components_ng/pattern/text_field/` 整个目录里 grep
  /// `GetBorderRadiusSize` **零命中** —— 没有任何一处把它写进 renderContext。
  /// 保留常量只为记录这个结论：矩阵里不得为它开数据行，否则就是「表里有值
  /// 就当成规格」的老毛病。（早前把它写成「下划线错误态的细描边圆角」是错的，
  /// 已纠正。）
  static const double borderRadius = 12;

  /// 内联形态圆角（`inline_radius_size` → `corner_radius_level2` = 4）。
  ///
  /// 4 而不是 20 —— 内联形态是「一行文本」，大圆角会让它看起来像一个按钮。
  static const double inlineRadius = 4;

  /// 水平内边距（`textfield_padding_horizontal` →
  /// `textfield_container_padding_horizontal` → `padding_level8` = 16）。
  static const double paddingHorizontal = 16;

  /// 垂直内边距（`textfield_padding_vertical` → `padding_level4` = 8）。
  ///
  /// 与 `paddingHorizontal` 一起决定容器高：8 + `contentHeight`(24) + 8 = 40
  /// = [height]。
  static const double paddingVertical = 8;

  /// 下划线形态的垂直内边距（`textfield_underline_padding_vertical` →
  /// `padding_level6` = **12**）。
  ///
  /// 比填充形态的 8 大 —— 下划线形态没有底板，只能靠上下留白把文字托起来，
  /// 因此 12 + 24 + 12 = 48，比 40 高 8。
  static const double underlinePaddingVertical = 12;

  /// 内联形态左内边距（`textfield_inline_padding_left`）。**2，不对称。**
  static const double inlinePaddingLeft = 2;

  /// 内联形态右内边距（`textfield_inline_padding_right`）。**12，不对称。**
  static const double inlinePaddingRight = 12;

  /// 输入文字字号（`text_font_size` → `textfield_font_size` →
  /// `ohos_id_text_size_body1` = 16fp）。
  static const double fontSize = 16;

  /// 错误提示字号（`error_text_font_size` → `ohos_id_text_size_body3` = 12fp）。
  static const double errorFontSize = 12;

  /// 计数器字号（`count_text_font_size` → `ohos_id_text_size_caption1`
  /// = **10fp**）。
  ///
  /// 10 而不是 12 —— 与本库 `labelSmall`（12）差一档。在一堆 14/16 里显得
  /// 很小，但这就是官方值，直接换 12 会让计数器比错误提示还抢眼。
  static const double counterFontSize = 10;

  /// 尾部图标尺寸（`textfield_icon_size` → `ohos_id_textfield_icon_size` = 24）。
  ///
  /// 与官方 `passwordIcon` 的属性说明「该图标的固定尺寸为 24vp」一致 ——
  /// 两处独立来源给出同一个数，这条可信度高。
  static const double iconSize = 24;

  /// 尾部图标命中区（`textfield_icon_hot_zone_size` →
  /// `ohos_id_textfield_icon_hot_zone_size` = 40）。
  ///
  /// 图标 24 但命中区 40：直接拿 24 做点击区在真机偏窄。
  static const double iconHotZone = 40;

  /// 错误提示与输入框的间距（`textfield_error_spacing` → `padding_level4` = 8）。
  static const double errorSpacing = 8;

  /// 错误描边宽（`textfield_error_border_width` →
  /// `ohos_id_textfield_error_border_width` = 1）。
  static const double errorBorderWidth = 1;
}

/// A HarmonyOS text input, the counterpart of Flutter's [TextField].
///
/// Defaults to ArkUI's underline style and turns the accent line brand-colored
/// while focused; [variant] switches to the filled / capsule forms used by
/// HarmonyOS forms and search entries.
class OhosTextField extends StatefulWidget {
  const OhosTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.initialValue,
    this.maxLines = 1,
    this.variant = OhosTextFieldVariant.underline,
    this.style,
    this.selectionMenuItems = const <OhosSelectionMenuItem>[],
    this.contextMenuBuilder,
    this.obscurePassword = false,
    this.showPasswordIcon = true,
    this.onSecurityStateChange,
    this.passwordIconColor,
    this.maxLength,
    this.showCounter = false,
    this.counterOptions = const OhosInputCounterOptions(),
  });

  /// Controller for the text; if null an internal one is created from
  /// [initialValue].
  ///
  /// Swapping the controller later (including back to null) is supported: only
  /// an internal one is disposed by the widget.
  final TextEditingController? controller;

  /// External focus node, e.g. to focus the field from a button.
  ///
  /// When null the field owns one internally; a supplied node is never disposed
  /// by the widget. Swapping the node later is supported — the Field moves to
  /// the new node and only an internally created one is disposed.
  final FocusNode? focusNode;

  /// Hint shown when empty.
  final String? hintText;

  /// 输入框上方的静态标签（官方 `TextInput` 没有浮动标签这个形态）。
  ///
  /// **与 Flutter 的 `labelText` 同名但不同形态**：Material 的 label 会先坐在
  /// 输入框里当占位符，聚焦 / 有内容时缩小上浮成一枚小字压在边框上。HarmonyOS
  /// 的文本框没有这个动作 —— 标签是**框外上方那一行静态文字**（见设计规范
  /// 配图：`Phone number` / `Password` 各占一行，输入框是它们下面的独立底板），
  /// 它不参与命中区、不随聚焦变色、也不会把容器撑成两行。
  ///
  /// 因此这里**不再转给 `InputDecoration.labelText`**，而是在 [TextField] 之上
  /// 自己画一行标签。早先直接透传，得到的是 Material 的浮动标签：聚焦时文字
  /// 缩到 12fp 并往上跳，输入框高度会跟着从 40 涨到 56 —— 那是本库唯一一处
  /// 「一聚焦就换高度」的控件，也正是用户看到的「和规范不一样」。
  final String? labelText;

  /// Leading icon inside the field.
  final Widget? prefixIcon;

  /// Trailing icon inside the field (clear / visibility toggle etc.).
  final Widget? suffixIcon;

  /// Error message shown below the field in the danger color.
  final String? errorText;

  /// Hides the input (password etc.).
  final bool obscureText;

  /// When false the field is disabled.
  final bool enabled;

  /// Keyboard type of the input.
  final TextInputType? keyboardType;

  /// Action button of the input method.
  final TextInputAction? textInputAction;

  /// Called whenever the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the text.
  final ValueChanged<String>? onSubmitted;

  /// Initial value of the text.
  final String? initialValue;

  /// Maximum number of lines.
  final int maxLines;

  /// Visual variant: underline (default) / filled / capsule.
  final OhosTextFieldVariant variant;

  /// Overrides the input text style.
  final TextStyle? style;

  /// 扩展动作（翻译 / 分享 / 搜索 / 三方），显示在「更多」二级菜单里。
  ///
  /// 内置的剪切 / 复制 / 粘贴 / 全选四项由 [OhosSelectionToolbar] 固定补齐，
  /// 不需要写在这里 —— 这条分工对应设计规范的「前四项不进更多」。
  final List<OhosSelectionMenuItem> selectionMenuItems;

  /// 完全接管选择菜单的构建。给了它，[selectionMenuItems] 与内置四项都不再
  /// 生效，由调用方自己决定菜单长什么样、包含哪些动作。
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  /// 密码模式：内容遮蔽（对应 ArkUI `InputType.Password`）。
  ///
  /// 与原有的 `obscureText` 的区别在于**它同时打开了「末尾眼睛图标」这一整套
  /// 密码形态** —— 高度 48（[OhosTextFieldMetrics.passwordHeight]）、尾部图标
  /// 24、命中区 40，以及「点图标切换显隐」的交互。单纯的 `obscureText` 只是
  /// 遮蔽内容，不掺和这些。
  ///
  /// 两者同时为 `true` 时以本字段为准（它更完整），`obscureText` 视为同一件事。
  final bool obscurePassword;

  /// 密码模式时是否显示末尾的眼睛图标（官方 `showPasswordIcon`，默认 `true`）。
  ///
  /// 官方默认值按设备分档：「TV 设备为 false，其他设备为 true」。本库无设备
  /// 类型概念，取手机/平板的 `true`。关掉它仍保留遮蔽，只是不给用户切换显隐
  /// 的手段 —— 用于「显隐由页面上的其它开关统一控制」的场合。
  final bool showPasswordIcon;

  /// 密码显隐状态切换时回调（官方 `onSecurityStateChange`，API 12 起）。
  ///
  /// 官方特意写了为什么要这个回调：「由于输入框后端的状态和前端应用侧的状态
  /// 管理变量会不一致，可能导致末尾图标的状态异常。建议在
  /// `onSecurityStateChange` 上增加状态同步」。本库把显隐留在组件内部（[key
  /// 不受控]），但同样把它抛出来 —— 调用方想自己画一个独立的「显示密码」
  /// 按钮时必须知道当前状态，否则会出现「两个地方各显示一种状态」。
  ///
  /// 参数为**切换后**的显隐状态：`true` = 明文可见。
  final ValueChanged<bool>? onSecurityStateChange;

  /// 密码图标颜色；`null` 取 `textSecondaryColor`。
  final Color? passwordIconColor;

  /// 最大输入字数（官方 `maxLength`，默认 `Infinity`）。
  ///
  /// [showCounter] 依赖它：计数器显示的是「当前字数 / 最大字数」，没有上限
  /// 就没有分母。本字段为 `null` 时即使打了 [showCounter] 也不画计数器。
  final int? maxLength;

  /// 是否显示字数计数器（官方 `showCounter`，API 11 起，**默认不显示**）。
  ///
  /// 三处官方约束已照搬进实现：
  /// * 需要配合 [maxLength]；
  /// * 达到「最大值 × [OhosInputCounterOptions.thresholdPercentage]」才出现；
  /// * **内联模式与密码模式下不显示**（官方原文「内联模式、密码模式下字符
  ///   计数器不显示」）—— 这两处的计数器由组件直接跳过，不做「画出来但看不见」
  ///   的半成品。
  final bool showCounter;

  /// 计数器配置，见 [OhosInputCounterOptions]。
  final OhosInputCounterOptions counterOptions;

  /// 实际生效的遮蔽开关：两个入口合并成一个。
  bool get _obscured => obscurePassword || obscureText;

  /// 内联形态是否真的生效 —— 官方只支持 `InputType.Normal`（单行、不遮蔽）。
  bool get _inlineEffective =>
      variant == OhosTextFieldVariant.inline && !_obscured && maxLines == 1;

  @override
  State<OhosTextField> createState() => _OhosTextFieldState();
}

class _OhosTextFieldState extends State<OhosTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  /// 只有自己创建的实例才由本组件 dispose：外部传入的归调用方所有。
  /// 用独立的 owner 标记（而不是读 `widget.controller == null`）是必须的 ——
  /// 后者在 didUpdateWidget 里已经指向新 widget，判不出旧实例是谁创建的。
  bool _ownsController = false;
  bool _ownsFocusNode = false;
  bool _focused = false;

  /// 密码是否处于「明文可见」状态。
  ///
  /// 官方 `showPassword(visible)` 是受控属性，且文档点名了不受控的风险：
  /// 「输入框后端的状态和前端应用侧的状态管理变量会不一致，可能导致末尾图标
  /// 的状态异常」。本库取**组件内受控**（调用方每次点眼睛都要 setState 才能
  /// 维持状态太啰嗦），并用 [OhosTextField.onSecurityStateChange] 把真实状态
  /// 抛出去，让调用方按需同步。
  bool _passwordVisible = false;

  /// 当前字数，只用于计数器 —— 不跟 `_controller.text` 走，是因为外部
  /// controller 的内容可能在组件外被改（`controller.text = ...`）而不会经过
  /// [OhosTextField.onChanged]，那样计数会停在旧值。
  int _length = 0;

  @override
  void initState() {
    super.initState();
    _useController(widget.controller);
    _useFocusNode(widget.focusNode);
    _length = _controller.text.characters.length;
    _controller.addListener(_onTextChanged);
  }

  void _useController(TextEditingController? controller) {
    _controller =
        controller ?? TextEditingController(text: widget.initialValue ?? '');
    _ownsController = controller == null;
  }

  void _onTextChanged() {
    final int next = _controller.text.characters.length;
    if (next != _length) {
      setState(() => _length = next);
    }
  }

  void _useFocusNode(FocusNode? focusNode) {
    _focusNode = focusNode ?? FocusNode();
    _ownsFocusNode = focusNode == null;
    _focusNode.addListener(_onFocus);
    _focused = _focusNode.hasFocus;
  }

  void _releaseFocusNode() {
    _focusNode.removeListener(_onFocus);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  @override
  void didUpdateWidget(OhosTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 控制器 / 焦点节点可以中途换（含换成 null）：只处理自己那份，
    // 并同步监听器与焦点态，否则换了节点后「聚焦高亮 / 取消按钮」会停在旧状态。
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTextChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      _useController(widget.controller);
      _length = _controller.text.characters.length;
      _controller.addListener(_onTextChanged);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _releaseFocusNode();
      _useFocusNode(widget.focusNode);
    }
  }

  void _onFocus() {
    if (mounted && _focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _releaseFocusNode();
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    // 内联形态**不支持 showError**（官方原文），所以错误态在这里就被判成 false，
    // 不画红边也不算进 accent 的优先级链 —— 留下一个「红了但没提示文字」的框，
    // 比不红更让人困惑。
    final bool hasError =
        widget.errorText != null &&
        widget.errorText!.isNotEmpty &&
        !widget._inlineEffective;
    final Color highlight = theme.highlightColor;
    final Color accent = !widget.enabled
        ? theme.textTertiaryColor
        : hasError
        ? theme.dangerColor
        : _focused
        ? highlight
        : theme.textTertiaryColor;
    // 密码形态：眼睛图标替换 / 追加到尾部。
    final Widget? trailingIcon = _trailingIcon(theme);
    // 内联形态不成立时（密码 / 多行）回落成默认的下划线形态 —— 与
    // `variant` 的默认值一致，不是另造一个「半内联」。
    final OhosTextFieldVariant effective =
        widget.variant == OhosTextFieldVariant.inline &&
            !widget._inlineEffective
        ? OhosTextFieldVariant.underline
        : widget.variant;
    final InputDecoration decoration = switch (effective) {
      OhosTextFieldVariant.underline => InputDecoration(
        // `InputDecorator` 有一条无障碍兜底：内容高不足
        // `kMinInteractiveDimension`(48) 时会**强制撑到 48**（见
        // input_decorator.dart 的 `minContainerHeight`）。官方下划线形态是
        // 12 + 24 + 12 = 48，恰好相等所以看不出问题；一旦把内边距调回
        // 令牌值就会撞上这条兜底。`isDense: true` 时 `minContainerHeight`
        // 变 0，高度才由内容真正决定。
        isDense: true,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: trailingIcon ?? widget.suffixIcon,
        suffixIconConstraints: const BoxConstraints(),
        errorText: widget.errorText,
        enabled: widget.enabled,
        errorMaxLines: 2,
        hintStyle: TextStyle(color: theme.textTertiaryColor),
        labelStyle: TextStyle(
          color: hasError
              ? theme.dangerColor
              : _focused
              ? highlight
              : theme.textSecondaryColor,
        ),
        errorStyle: TextStyle(color: theme.dangerColor),
        prefixIconColor: accent,
        suffixIconColor: theme.textSecondaryColor,
        filled: false,
        // 下划线形态的垂直内边距走 `textfield_underline_padding_vertical`
        // → `padding_level6` = **12**；水平是 `textfield_underline_padding_
        // horizontal` → `padding_level0` = **0**。两者与填充形态的 8/16 不同
        // —— 下划线形态的留白是纯垂直的，靠线分层而不是靠方块。
        // 12 + 24 + 12 = 48，正好是矩阵里记的下划线形态 48vp 高。
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: OhosTextFieldMetrics.underlinePaddingVertical,
        ),
        // 50% / 20% 的下划线在 16 级灰上淡成一圈白边，输入框等于没有边界 ——
        // 策略换成实线，禁用降一档到提示色。
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: theme.usesOutlines
                ? theme.dividerColor
                : theme.textTertiaryColor.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: accent, width: 2),
        ),
        disabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: theme.policy.line(theme.textTertiaryColor, 0.2),
          ),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.dangerColor, width: 2),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: theme.dangerColor, width: 2),
        ),
      ),
      OhosTextFieldVariant.filled ||
      OhosTextFieldVariant.capsule ||
      OhosTextFieldVariant.inline => _boxedDecoration(
        theme: theme,
        hasError: hasError,
        accent: accent,
        // 墨屏上「填充色 = 背景色」，灰底方块的边界会整个消失 →
        // 改回透明底 + 实线，靠线而不是靠色分层。
        useFill:
            (effective == OhosTextFieldVariant.filled ||
                effective == OhosTextFieldVariant.inline) &&
            !theme.usesOutlines,
        radius: switch (effective) {
          // 胶囊形态：官方没有单独的胶囊令牌，胶囊 = 高度一半，这里仍然
          // 交给 `radiusCapsule`（999 会被 BorderRadius 夹到高的一半）。
          OhosTextFieldVariant.capsule => OhosGeometry.radiusCapsule,
          OhosTextFieldVariant.inline => OhosTextFieldMetrics.inlineRadius,
          // 填充形态：`textfield_border_radius` → 20。**不是** `radiusMedium`
          // (16) —— 原先取的是主题的中圆角，与官方令牌差 4vp。证据见
          // [OhosTextFieldMetrics.containerRadius] 的注释。
          _ => OhosTextFieldMetrics.containerRadius,
        },
        // 内联形态左右边距不对称（2 / 12）而上下为 0 —— 它就是「一行文字」，
        // 上下留白由它所在的行高提供，不是由输入框自己。
        padding: widget._inlineEffective
            ? const EdgeInsets.only(
                left: OhosTextFieldMetrics.inlinePaddingLeft,
                right: OhosTextFieldMetrics.inlinePaddingRight,
              )
            : null,
        // 内联形态的底板是页面底色 + 强调色描边，不是灰块。
        inline: widget._inlineEffective,
        suffix: trailingIcon ?? widget.suffixIcon,
      ),
    };
    final Widget field = TextField(
      controller: widget.controller ?? _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      // 密码模式下由 `_passwordVisible` 决定遮蔽：眼睛图标点一下就把内容
      // 摊开，这是「密码模式」相对单纯 `obscureText` 的全部意义。
      obscureText: widget._obscured && !_passwordVisible,
      // 官方 `maxLength` 的行为是**硬截断**（输入到上限就输不进去），
      // 与 Flutter 的 `maxLength` 一致 —— 但 Flutter 默认还会在右下角画
      // 一个计数器（`decoration.counterText`），那是 Material 的观感，
      // 本库的计数器自己画，所以这里固定传 `null`。
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      maxLines: widget._inlineEffective ? 1 : widget.maxLines,
      style:
          widget.style ??
          (theme.typography.bodyLarge?.copyWith(
            color: theme.textPrimaryColor,
            fontSize: OhosTextFieldMetrics.fontSize,
          )),
      decoration: decoration.copyWith(
        counterText: '',
        // 密码形态容器高 **48**（`password_style_height` →
        // `ohos_id_password_style_height`），比普通形态的 40 高 8。只在下
        // 划线以外的形态上补，因为下划线形态本来就是 48（12+24+12），
        // 再叠一层约束就等于没变、但会让「谁定的高度」变模糊。
        constraints:
            widget._obscured && effective != OhosTextFieldVariant.underline
            ? const BoxConstraints(
                minHeight: OhosTextFieldMetrics.passwordHeight,
              )
            : null,
      ),
      contextMenuBuilder:
          widget.contextMenuBuilder ??
          (BuildContext context, EditableTextState state) =>
              OhosSelectionToolbar.editable(
                context: context,
                editableTextState: state,
                items: widget.selectionMenuItems,
              ),
    );

    // 标签是**框外上方的一行静态文字**，不是 Material 的浮动 label。
    // 它不进 `InputDecoration`，所以既不会在聚焦时缩小上浮，也不会把 40 的
    // 容器撑成 56；间距取 `padding_level4` = 8（与 `textfield_error_spacing`
    // 同一个令牌，官方表单里「标签—控件」「控件—错误提示」都是这一档）。
    final Widget? label = widget.labelText == null || widget.labelText!.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.only(
              bottom: OhosTextFieldMetrics.errorSpacing,
            ),
            child: DefaultTextStyle.merge(
              style:
                  (theme.typography.bodyMedium ?? const TextStyle(fontSize: 15))
                      .copyWith(
                        color: hasError
                            ? theme.dangerColor
                            : theme.textSecondaryColor,
                      ),
              child: Text(
                widget.labelText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) label,
        field,
        if (_counterVisible) _buildCounter(theme),
      ],
    );
  }

  /// 计数器是否该出现。
  ///
  /// 四个前置条件缺一不可，其中第三个是官方明文：「内联模式、密码模式下字符
  /// 计数器不显示」。这条最容易漏 —— 单看 `showCounter` 的说明不会知道它跟
  /// 另外两个形态互斥。
  bool get _counterVisible {
    if (!widget.showCounter || widget.maxLength == null) {
      return false;
    }
    if (widget._inlineEffective || widget._obscured) {
      return false;
    }
    return widget.counterOptions.isVisible(_length, widget.maxLength!);
  }

  /// 字数计数器：`当前/上限`，右下角。
  ///
  /// 字号 **10fp**（`count_text_font_size` → `ohos_id_text_size_caption1`），
  /// 常规色 `count_text_color` = `font_tertiary`；溢出且
  /// `highlightBorder` 生效时两者都换 `warning`（`over_count_text_color` /
  /// `over_count_border_color` 都指向它，**不是** `alert` —— `alert` 是
  /// `over_text_color`，那是输入框里被截掉的文字用的）。
  Widget _buildCounter(OhosThemeData theme) {
    final int max = widget.maxLength!;
    final bool over = _length > max;
    final bool warn =
        over && widget.counterOptions.highlightsOnOverflow(_length, max);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Text(
          '$_length/$max',
          style: theme.typography.labelSmall?.copyWith(
            fontSize: OhosTextFieldMetrics.counterFontSize,
            color: warn ? theme.warningColor : theme.textTertiaryColor,
          ),
        ),
      ),
    );
  }

  /// 尾部图标：密码模式下是「眼睛」，否则交给调用方的 [suffixIcon]。
  ///
  /// 尺寸 24 / 命中区 40 都取令牌（`textfield_icon_size` /
  /// `textfield_icon_hot_zone_size`），与官方 `passwordIcon` 的「固定尺寸
  /// 24vp」相互印证。
  Widget? _trailingIcon(OhosThemeData theme) {
    if (!widget._obscured || !widget.showPasswordIcon) {
      return null;
    }
    final Color color =
        widget.passwordIconColor ??
        (widget.enabled ? theme.textSecondaryColor : theme.textTertiaryColor);
    return Semantics(
      button: true,
      label: _passwordVisible ? '隐藏密码' : '显示密码',
      child: OhosPressFeedback(
        onTap: widget.enabled ? _togglePassword : null,
        borderRadius: BorderRadius.circular(
          OhosTextFieldMetrics.iconHotZone / 2,
        ),
        child: SizedBox(
          width: OhosTextFieldMetrics.iconHotZone,
          height: OhosTextFieldMetrics.iconHotZone,
          child: Icon(
            _passwordVisible
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: OhosTextFieldMetrics.iconSize,
            color: color,
          ),
        ),
      ),
    );
  }

  void _togglePassword() {
    setState(() => _passwordVisible = !_passwordVisible);
    // 回调给的是**切换后**的状态，调用方直接同步即可，不需要自己再取反。
    widget.onSecurityStateChange?.call(_passwordVisible);
  }

  /// Filled / capsule variants: a boxed field whose border only shows while
  /// focused or in error, unless the fill is unavailable (e-ink) — then a
  /// hairline border carries the boundary instead.
  InputDecoration _boxedDecoration({
    required OhosThemeData theme,
    required bool hasError,
    required Color accent,
    required bool useFill,
    required double radius,
    EdgeInsets? padding,
    bool inline = false,
    Widget? suffix,
  }) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    // 墨水屏上 50% 的 hairline 会淡掉，填充框本来就退化成描边框（见上）
    final Color hairline = theme.policy.line(theme.textTertiaryColor, 0.5);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      // 同下划线分支：不吃 `kMinInteractiveDimension`(48) 的兜底，让
      // `contentPadding` + 内容高自己决定容器高，否则 8+24+8=40 会被撑到 48。
      isDense: true,
      hintText: widget.hintText,
      prefixIcon: widget.prefixIcon,
      // 内联形态没有浮起的 label 与错误提示的落位空间，label 会把它撑成两行，
      // 那就不是「一行文本」了。
      suffixIcon: suffix,
      // `InputDecoration` 默认 `suffixIconConstraints` 是 48×48 —— 那会把本库
      // 40 的密码命中区撑到 48、24 的图标在里面对不齐（实测 `getSize` 拿到
      // 48 才发现）。这里压到 0 让子节点自己定尺寸，再交给下面 wrap 的
      // 最小约束保底。
      suffixIconConstraints: const BoxConstraints(),
      errorText: inline ? null : widget.errorText,
      enabled: widget.enabled,
      errorMaxLines: 2,
      hintStyle: TextStyle(color: theme.textTertiaryColor),
      labelStyle: TextStyle(
        color: hasError
            ? theme.dangerColor
            : _focused
            ? theme.highlightColor
            : theme.textSecondaryColor,
      ),
      // 错误提示字号 12fp（`error_text_font_size` → `ohos_id_text_size_body3`）。
      errorStyle: TextStyle(
        color: theme.dangerColor,
        fontSize: OhosTextFieldMetrics.errorFontSize,
      ),
      prefixIconColor: accent,
      suffixIconColor: theme.textSecondaryColor,
      filled: useFill,
      fillColor: inline
          ? theme.backgroundColor
          : theme.compBackgroundGrayColor ??
                theme.backgroundSecondaryColor ??
                theme.cardColor,
      contentPadding:
          padding ??
          // 填充 / 胶囊形态：`textfield_padding_horizontal`(→ `padding_level8`
          // = 16) 与 `textfield_padding_vertical`(→ `padding_level4` = 8)。
          // 8 + 24 + 8 = 40 = `textfield_height`。早前这里自拟的是 14/14，
          // 实测渲染成 52vp、比官方高 12 —— 「令牌有值」却没接上来。
          const EdgeInsets.symmetric(
            horizontal: OhosTextFieldMetrics.paddingHorizontal,
            vertical: OhosTextFieldMetrics.paddingVertical,
          ),
      border: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide.none,
      ),
      // 内联形态的边界是「强调色细线」而不是「看不见的填充」——
      // 它要看起来像一个可以点进去的文本，而不是一块底板。
      enabledBorder: inline
          ? border(
              theme.usesOutlines ? theme.dividerColor : theme.textTertiaryColor,
              1,
            )
          : useFill
          ? border(Colors.transparent, 0)
          : border(hairline),
      focusedBorder: border(accent, inline ? 1 : 1.5),
      disabledBorder: useFill && !inline
          ? border(Colors.transparent, 0)
          : border(theme.policy.line(theme.textTertiaryColor, 0.2)),
      // 错误描边 **1vp**（`textfield_error_border_width` →
      // `ohos_id_textfield_error_border_width` = 1）。原先写 1.5 是为了「让错误
      // 比聚焦更醒目」，但官方靠的是**换色**（`error_text_border_color` =
      // `alert`）而不是加粗 —— 加粗会让错误态的框在视觉上跳动。
      errorBorder: border(
        theme.dangerColor,
        OhosTextFieldMetrics.errorBorderWidth,
      ),
      focusedErrorBorder: border(
        theme.dangerColor,
        OhosTextFieldMetrics.errorBorderWidth,
      ),
    );
  }
}
