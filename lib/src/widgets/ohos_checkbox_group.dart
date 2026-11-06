import 'package:flutter/material.dart';

import '../theme/ohos_geometry.dart';
import '../theme/ohos_stroke.dart';
import '../theme/ohos_theme.dart';
import 'ohos_checkbox.dart';

/// 群组的选中状态，对应官方 `SelectStatus` 枚举。
enum OhosSelectStatus {
  /// 全部选中（`SelectStatus.All` = 0）。
  all,

  /// 部分选中（`SelectStatus.Part` = 1）—— 主勾选框画一横，不是勾。
  part,

  /// 全未选中（`SelectStatus.None` = 2）。
  none,
}

/// 由 [OhosSelectStatus] 与选中项集合推出来的现成值。
///
/// 这是本库对官方 `CheckboxGroupResult` 的对应物：官方回调给的是
/// `{ name: Array<string>, status: SelectStatus }`，也就是**选中项名单 + 三态**。
/// 只给三态不够（调用方还得知道是哪几项），只给名单也不够（全选与空集要靠
/// `length == total` 自己算，而 `total` 未必等于名单长度）。
@immutable
class OhosCheckboxGroupResult {
  const OhosCheckboxGroupResult({
    required this.names,
    required this.status,
    required this.total,
  });

  /// 群组内所有被选中的名称，按 [total] 中的顺序。
  final List<String> names;

  /// 三态。
  final OhosSelectStatus status;

  /// 群组总项数。
  ///
  /// 有它才能区分「全选」与「还没加载完」：`names.length == total` 才算 all，
  /// 只比 `names.length > 0` 是分不出 `Part` 和 `All` 的。
  final int total;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OhosCheckboxGroupResult &&
          other.status == status &&
          other.total == total &&
          _listEquals(other.names, names));

  @override
  int get hashCode => Object.hash(status, total, Object.hashAll(names));

  @override
  String toString() =>
      'OhosCheckboxGroupResult(${status.name}, $names / $total)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// 从「全集」与「选中集合」算出三态。
///
/// 边界两条：`allNames` 为空时视为 [OhosSelectStatus.none]（0 项全选没有意义，
/// 画成 all 会让一个空组显示成「已全选」）；选集为空时 none。
OhosSelectStatus ohosSelectStatusOf({
  required Iterable<String> allNames,
  required Set<String> selected,
}) {
  final int total = allNames.length;
  if (total == 0 || selected.isEmpty) {
    return OhosSelectStatus.none;
  }
  int hit = 0;
  for (final String name in allNames) {
    if (selected.contains(name)) {
      hit++;
    }
  }
  if (hit == 0) {
    return OhosSelectStatus.none;
  }
  return hit == total ? OhosSelectStatus.all : OhosSelectStatus.part;
}

/// 多选框群组（多选框群组 in the HarmonyOS guideline），ArkUI 的
/// `CheckboxGroup` 在 Flutter 侧的对应物。
///
/// 三个使用层级，从简到繁：
///
/// 1. **只画那个主勾选框** —— 给 [selectedCount] 与 [total]，自己处理点击。
/// 2. **用 [OhosCheckboxGroupScope] 管一整个受控群组** —— 见下。
/// 3. **不用本组件，自己算** —— 调 [ohosSelectStatusOf] 就够了。
///
/// ## 为什么不包住子控件
///
/// 官方的 `CheckboxGroup` **没有子组件**（文档「子组件：无」），它靠 `group`
/// 字符串与同名的 `Checkbox` 隐式配对。Flutter 侧没有这条约定，硬造一个
/// 「包住就自动分组」的容器会带来两个新问题：①子控件必须都是
/// `OhosCheckbox`，否则拿不到状态；②`ListView` 这类懒加载容器里未构建的子项
/// 不会被算进群组 —— 官方文档专门用示例 4 讲了这件事，说明它本身也是坑，
/// 不该再复制一层。
///
/// 所以这里**显式接管**：状态放在 [OhosCheckboxGroupScope] 里，群组头与每个
/// 成员都从同一个控制器读写。它是「受控」的，不存在「界面上的勾」与「应用
/// 记的勾」不一致。
///
/// ## 几何
///
/// 形状、选中色、未选中描边色与 [OhosCheckbox] 完全一致（`checkboxShape`
/// 的作用就是让群组与组内未单独设置的成员长得一样）。唯一差别是**部分选中
/// 画一横**（`Icons.remove_rounded`）而不是勾 —— 半选在视觉上必须与全选
/// 一眼可分，用「一个颜色浅一点的勾」是不够的。
class OhosCheckboxGroup extends StatelessWidget {
  const OhosCheckboxGroup({
    super.key,
    required this.selectedCount,
    required this.total,
    this.onChanged,
    this.activeColor,
    this.size = 24,
    this.round = false,
  }) : _status = null;

  /// 直接给三态，跳过由数量推算。
  ///
  /// 用于「只有状态、没有数量」的场景（例如外部系统直接推过来一个
  /// `SelectStatus.Part`）。两种构造方式的优先级是：给了三态就不再看数量。
  const OhosCheckboxGroup.status({
    super.key,
    required OhosSelectStatus status,
    this.onChanged,
    this.activeColor,
    this.size = 24,
    this.round = false,
  }) : _status = status,
       selectedCount = 0,
       total = 0;

  /// 当前选中项数量。
  final int selectedCount;

  /// 群组总项数。
  final int total;

  /// 点击回调，参数是**目标状态**：目前只会给 `true`（全选）或 `false`
  /// （全不选）。半选被点一下应当变成全选 —— 这是复选框的通行约定，也是官方
  /// `triggerChange` 的语义（「true 表示从部分选中或未选中变为全部选中」）。
  final ValueChanged<bool>? onChanged;

  /// 选中 / 半选的填充色。
  final Color? activeColor;

  /// 逻辑尺寸。
  final double size;

  /// 是否画成圆形（`CheckBoxShape.CIRCLE`）而不是圆角方形。
  ///
  /// 官方的默认值是 **CIRCLE**（`checkboxShape` 默认 `CheckBoxShape.CIRCLE`），
  /// 但本库的 [OhosCheckbox] 是圆角方形（对应 `ROUNDED_SQUARE`）。这里默认
  /// `false` 与自家成员保持一致 —— 一个圆角方形的列表里混一个圆形主勾选框
  /// 是最容易犯的错，因为官方文档的默认值恰好是另一档。
  final bool round;

  final OhosSelectStatus? _status;

  /// 由数量算三态；显式给了 `_status` 就用它。
  OhosSelectStatus get status =>
      _status ??
      ohosSelectStatusOf(
        allNames: List<String>.generate(total, (int i) => '$i'),
        selected: <String>{
          for (int i = 0; i < selectedCount.clamp(0, total); i++) '$i',
        },
      );

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = onChanged != null;
    final OhosVisualPolicy policy = theme.policy;
    final Color active = activeColor ?? theme.highlightColor;
    final OhosSelectStatus state = status;
    final bool partial = state == OhosSelectStatus.part;
    final bool checked = state == OhosSelectStatus.all || partial;
    final double radius = round ? size / 2 : size * 0.26;

    return Semantics(
      checked: state == OhosSelectStatus.all,
      // 半选必须单独报出来：读屏只说「未选中」会让全选按钮在部分选中时
      // 听起来像没点过。
      mixed: partial,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(state != OhosSelectStatus.all) : null,
        child: AnimatedContainer(
          duration: OhosGeometry.durationShort,
          curve: OhosGeometry.spring,
          width: size,
          height: size,
          decoration: BoxDecoration(
            // 与 OhosCheckbox 同一条规则：只有禁用态才铺那层 15% 灰底。
            color: enabled && checked
                ? active
                : (enabled
                      ? Colors.transparent
                      : policy.tint(theme.textTertiaryColor, 0.15)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: checked && enabled
                  ? active
                  : policy.line(theme.textTertiaryColor, 0.5),
              width: ohosStrokeWidth(context, 1.5),
            ),
          ),
          child: checked
              ? Icon(
                  // 半选是一横，不是勾。16 级灰上「浅一点的勾」与勾分不开。
                  partial ? Icons.remove_rounded : Icons.check_rounded,
                  size: size * 0.72,
                  color: enabled ? Colors.white : theme.textTertiaryColor,
                )
              : null,
        ),
      ),
    );
  }
}

/// 受控的多选框群组状态。
///
/// 用法：
///
/// ```dart
/// final OhosCheckboxGroupController controller = OhosCheckboxGroupController(
///   allNames: <String>['a', 'b', 'c'],
/// );
///
/// OhosCheckboxGroupScope(
///   controller: controller,
///   child: Column(
///     children: <Widget>[
///       OhosCheckboxGroupHeader(title: '全选'),
///       for (final String name in controller.allNames)
///         OhosCheckboxGroupTile(name: name, title: name),
///     ],
///   ),
/// )
/// ```
///
/// [allNames] 是**全集**，必须在构造时给出：三态里的「全选」是相对全集算的，
/// 只知道自己选了哪几项是分不出 `Part` 与 `All` 的（除非再传一个 total）。
class OhosCheckboxGroupController extends ChangeNotifier {
  OhosCheckboxGroupController({
    required List<String> allNames,
    Set<String>? selected,
  }) : _allNames = List<String>.unmodifiable(allNames),
       _selected = <String>{...?selected}.intersection(
         allNames.toSet(),
       );

  final List<String> _allNames;
  Set<String> _selected;

  /// 群组全集，顺序即回调里 `names` 的顺序。
  List<String> get allNames => _allNames;

  /// 当前选中集合的**只读视图**。
  ///
  /// 不返回可变集合：修改必须经过 [toggle] / [selectAll] / [clear]，否则
  /// 界面不会收到通知，勾选框与应用记录会静默分叉。
  Set<String> get selected => Set<String>.unmodifiable(_selected);

  /// 三态。
  OhosSelectStatus get status =>
      ohosSelectStatusOf(allNames: _allNames, selected: _selected);

  /// 群组结果（选中项名单 + 三态 + 总数）。
  OhosCheckboxGroupResult get result => OhosCheckboxGroupResult(
    names: <String>[
      for (final String name in _allNames)
        if (_selected.contains(name)) name,
    ],
    status: status,
    total: _allNames.length,
  );

  /// 全选。
  void selectAll() {
    if (_selected.length == _allNames.length) {
      return;
    }
    _selected = _allNames.toSet();
    notifyListeners();
  }

  /// 全不选。
  void clear() {
    if (_selected.isEmpty) {
      return;
    }
    _selected = <String>{};
    notifyListeners();
  }

  /// 全选与全不选之间切换。
  ///
  /// **半选时切到全选**，不是「先清空」—— 与 [OhosCheckboxGroup] 的点击语义
  /// 一致（官方 `triggerChange` 也是这么定义的）。
  void toggleAll() {
    if (status == OhosSelectStatus.all) {
      clear();
    } else {
      selectAll();
    }
  }

  /// 反转：选中的变未选、未选的变选中。
  ///
  /// 官方 `CheckboxGroup` 没有这个能力（它只有全选 / 全不选两档），这是补充。
  /// 不加进三态判断 —— 反选之后的三态还是那三个，不需要第四个状态。
  void invert() {
    _selected = <String>{
      for (final String name in _allNames)
        if (!_selected.contains(name)) name,
    };
    notifyListeners();
  }

  /// 切换单项。
  void toggle(String name) {
    if (!_allNames.contains(name)) {
      // 不在全集里的名字直接忽略：加进去会让「全选」永远算不出来
      // （选中数比总数还多）。
      return;
    }
    if (!_selected.remove(name)) {
      _selected.add(name);
    }
    notifyListeners();
  }

  /// 单项是否选中。
  bool isSelected(String name) => _selected.contains(name);

  /// 直接设置某一项。`true` 加入、`false` 移除，与当前值相同时不通知。
  void setSelected(String name, bool value) {
    if (!_allNames.contains(name)) {
      return;
    }
    final bool changed = value ? _selected.add(name) : _selected.remove(name);
    if (changed) {
      notifyListeners();
    }
  }
}

/// 把 [OhosCheckboxGroupController] 提供给子树。
class OhosCheckboxGroupScope extends InheritedNotifier<OhosCheckboxGroupController> {
  const OhosCheckboxGroupScope({
    super.key,
    required OhosCheckboxGroupController controller,
    required super.child,
  }) : super(notifier: controller);

  /// 取上层控制器；没有时返回 null。
  static OhosCheckboxGroupController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OhosCheckboxGroupScope>()
        ?.notifier;
  }

  /// 取上层控制器；没有时抛错。
  static OhosCheckboxGroupController of(BuildContext context) {
    final OhosCheckboxGroupController? controller = maybeOf(context);
    assert(
      controller != null,
      '找不到 OhosCheckboxGroupScope。OhosCheckboxGroupHeader / '
      'OhosCheckboxGroupTile 必须在 OhosCheckboxGroupScope 子树里使用',
    );
    return controller!;
  }
}

/// 群组头：主勾选框 + 标题。点击标题等同于点勾选框。
class OhosCheckboxGroupHeader extends StatelessWidget {
  const OhosCheckboxGroupHeader({
    super.key,
    required this.title,
    this.controller,
    this.enabled = true,
    this.activeColor,
    this.size = 24,
    this.round = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  /// 标题文本。
  final String title;

  /// 控制器；null 时从 [OhosCheckboxGroupScope] 取。
  final OhosCheckboxGroupController? controller;

  /// 为 false 时整行不可点。
  final bool enabled;

  /// 选中色。
  final Color? activeColor;

  /// 主勾选框尺寸。
  final double size;

  /// 主勾选框是否画成圆形（见 [OhosCheckboxGroup.round]）。
  final bool round;

  /// 内边距。官方示例里标题与勾选框同行、左对齐；16 是列表项的通行边距。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosCheckboxGroupController c =
        controller ?? OhosCheckboxGroupScope.of(context);
    return _GroupRow(
      onTap: enabled ? c.toggleAll : null,
      padding: padding,
      children: <Widget>[
        OhosCheckboxGroup(
          selectedCount: c.selected.length,
          total: c.allNames.length,
          size: size,
          round: round,
          activeColor: activeColor,
          onChanged: enabled ? (bool _) => c.toggleAll() : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.bodyMedium?.copyWith(
              color: enabled ? theme.textPrimaryColor : theme.textTertiaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// 群组里的一个成员：勾选框 + 标题。
class OhosCheckboxGroupTile extends StatelessWidget {
  const OhosCheckboxGroupTile({
    super.key,
    required this.name,
    required this.title,
    this.controller,
    this.enabled = true,
    this.activeColor,
    this.size = 24,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  /// 成员标识，对应官方 `Checkbox(name:)`。
  final String name;

  /// 显示文本。
  final String title;

  /// 控制器；null 时从 [OhosCheckboxGroupScope] 取。
  final OhosCheckboxGroupController? controller;

  /// 为 false 时整行不可点。
  final bool enabled;

  /// 选中色。
  final Color? activeColor;

  /// 勾选框尺寸。
  final double size;

  /// 内边距。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final OhosCheckboxGroupController c =
        controller ?? OhosCheckboxGroupScope.of(context);
    final bool checked = c.isSelected(name);
    return _GroupRow(
      onTap: enabled ? () => c.toggle(name) : null,
      padding: padding,
      children: <Widget>[
        OhosCheckbox(
          value: checked,
          size: size,
          activeColor: activeColor,
          onChanged: enabled ? (bool _) => c.toggle(name) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.bodyMedium?.copyWith(
              color: enabled ? theme.textPrimaryColor : theme.textTertiaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// 群组头与成员共用的整行点击区域。
///
/// 用 `GestureDetector` 自绘按压态而不是 `InkWell`：`InkWell` 要求祖先里有
/// `Material`，而这两个组件最常见的落点是 `Column` / `ListView` —— 一个裸
/// 的 `Column` 里放 `InkWell` 会在真机上直接抛 `No Material widget found`。
/// 本库其它列表项（如 `OhosListTile`）自带 `Material` 包裹，这里为了不给调用
/// 方加约束，走同一条自绘路线。
class _GroupRow extends StatefulWidget {
  const _GroupRow({
    required this.onTap,
    required this.padding,
    required this.children,
  });

  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final OhosThemeData theme = OhosTheme.of(context);
    final bool enabled = widget.onTap != null;
    final Color overlay = theme.policy.tint(theme.textPrimaryColor, 0.06);
    final bool showsOverlay =
        _pressed && enabled && overlay != Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: enabled ? (TapDownDetails _) => _setPressed(true) : null,
      onTapUp: enabled ? (TapUpDetails _) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      child: ColoredBox(
        // 只有按下去并且策略允许时才铺色。墨水屏上 `tint` 返回透明，那一档
        // 的反馈由勾选框自己的描边切换承担。
        color: showsOverlay ? overlay : Colors.transparent,
        child: Padding(
          padding: widget.padding,
          child: Row(children: widget.children),
        ),
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }
}