# 0.5.0 → 0.6.0 迁移指南

本版共 **12 处破坏性变更**，全部集中在「旧语义与官方文档对不上」的地方 —— 保留旧参数就无法补齐官方形态，所以选择在一个版本里集中破坏，而不是分散成几次各痛一次。

其中 7 处是主体实现轮次引入的（第 1–7 条），另外 5 处在收尾一轮按 `doc/AUDIT-0.6.md` 的 42 控件复核清单改实现（P0–P3 共 18 项）时补出（第 8–12 条）：**3 处编译期失败**（第 8 / 9 / 11 条）、**2 处静默的默认值变化**（第 10 / 12 条）。它们同样不可能在保留旧字段的前提下做到。

好消息先说：**所有顶层函数（`showOhosDialog` / `showOhosBottomSheet` / `showOhosPicker` / `showOhosMenu`）只新增了可选参数，没有删除任何一个**。如果你的代码大量用这些函数而不是直接构造组件，升级成本会小很多。

## 一览表

| # | 类型 | 变更 | 编译期失败 | 静默行为变化 |
| --- | --- | --- | --- | --- |
| 1 | `OhosActionBar` | 9 个参数移除，改成三段式 | ✅ | ✅ |
| 2 | `OhosDataPanel` | 语义调换，旧用法改名 `OhosStatGrid` | ✅ | — |
| 3 | `OhosToolbarItem` | `selected: bool` → `state: 枚举` | ✅ | ✅ |
| 4 | `OhosAlertDialog` | `borderRadius` 参数移除（28 → 固定 32） | ✅ | ✅ |
| 5 | `OhosSubheader` | `padding` 移除（报错）、`title` 改为可选（不报错） | ✅（仅 `padding`） | ✅ |
| 6 | `OhosProgressIndicatorVariant` | 枚举成员 `circular` → `ring` | ✅ | — |
| 7 | `OhosChipGroup` | 不传选中项时默认选中第 0 颗 | — | ✅ |
| 8 | `OhosTextClock` | `timeZone: String?` → `timeZoneOffset: double?` | ✅ | ✅ |
| 9 | `OhosRatingBar` | `value: int` → `double` | ✅ | — |
| 10 | `OhosCheckbox` / `OhosCheckboxGroup` | 默认形状改**圆形**、`round` 默认改 `true` | — | ✅ |
| 11 | `OhosImage` | `fit: BoxFit` → `OhosImageFit` | ✅ | ✅ |
| 12 | `OhosSelect` | 默认不再画「选中勾」 | — | ✅ |

> 第 7 条没有出现在上面的机械比对里 —— 它不是签名变化，是默认行为变化，只有读源码才能发现。也正因为不报错，它最容易在升级后「看起来正常但选中态错了」。

还有一处**看起来像破坏其实不是**：`OhosChipGroupSize` 曾是一个独立枚举，现在写成 `typedef OhosChipGroupSize = OhosChipSize`。成员名仍是 `normal` / `small`，所以 `OhosChipGroupSize.normal` 照旧编译通过 —— 已用真实工程验证。

---

## 1. `OhosActionBar` —— 9 个参数移除

官方 `HdsActionBar` 从来只有「起始组 + 主按钮 + 末尾组」这个形态，0.5.x 的「次要操作全放一侧」是当时没读文档的产物。

**旧写法**

```dart
OhosActionBar(
  primaryLabel: '确认支付',
  onPrimaryPressed: _pay,
  secondaryActions: <Widget>[
    IconButton(icon: Icon(Icons.schedule), onPressed: _later),
    IconButton(icon: Icon(Icons.mic), onPressed: _voice),
  ],
  primaryLoading: false,
  expandable: true,
  isExpanded: true,
  onIsExpandedChanged: (bool v) {},
  primaryIcon: Icons.check,
  primaryTooltip: '确认',
)
```

**新写法**

```dart
OhosActionBar(
  startButtons: <OhosActionBarButton>[
    OhosActionBarButton(
      icon: const Icon(Icons.schedule),
      tooltip: '稍后',
      onPressed: _later,
    ),
  ],
  endButtons: <OhosActionBarButton>[
    OhosActionBarButton(
      icon: const Icon(Icons.mic),
      tooltip: '语音',
      onPressed: _voice,
    ),
  ],
  primaryButton: OhosActionBarButton(
    icon: const Icon(Icons.check),
    tooltip: '确认',
    onPressed: _pay,
  ),
  isExpand: true,
  onIsExpandChanged: (bool v) {},
)
```

**参数对照**

| 0.5.0 | 0.6.0 |
| --- | --- |
| `secondaryActions` | `startButtons` + `endButtons` |
| `primaryLabel` / `primaryIcon` / `primaryTooltip` | `primaryButton: OhosActionBarButton(...)`（全部收进按钮对象） |
| `onPrimaryPressed` | `primaryButton.onPressed` |
| `expandable` | `isExpand`（**默认值反转**：旧 `expandable` 默认 `false` 但旧 `isExpanded` 默认 `true`；新 `isExpand` 默认 `false`，即默认不展开） |
| `isExpanded` | `isExpand` |
| `onIsExpandedChanged` | `onIsExpandChanged` |
| `primaryLoading` | 移除，**官方没有这个形态**。需要加载态用 `primaryButtonBuilder` + `primaryButtonBuilderWidth` 自己画（见下） |
| `padding` | 仍在，但几何改由 `style` 承担，见 `OhosActionBarStyle` |

**两个容易踩的点**

1. **`isExpand` 的默认值反了**。如果你的旧代码依赖「默认展开」，升级后要显式写 `isExpand: true`，否则视觉上按钮组是收起的。
2. **`startButtons` / `endButtons` 的元素类型是 `OhosActionBarButton`，不是 `Widget`**。旧的 `secondaryActions` 收的是任意 `Widget`，所以塞 `IconButton` 能过；新写法必须换成 `OhosActionBarButton`，否则编译报「element type can't be assigned to list type」。

顺带：主按钮要换图标时用 `OhosActionBarButton.altIcon` + `OhosActionBarStyle.isPrimaryIconChanged`（官方把这件事放在 style 上，因为它是整个栏的状态）。给了 `altIcon` 但没给 `isPrimaryIconChanged` 不会掉图标 —— 缺 `altIcon` 时会回落 `baseIcon`。

**`primaryLoading` 的替代**：官方 `HdsActionBar` 没有加载态，所以这个参数被移除了，而不是换成另一个名字。要保留加载圈的观感，用自定义主按钮：

```dart
OhosActionBar(
  primaryButtonBuilder: (BuildContext ctx) => _loading
      ? const Center(child: OhosLoadingIndicator(size: 24))
      : Icon(Icons.check),
  primaryButtonBuilderWidth: 56, // 必须给，否则 assert 失败
  ...
)
```

---

## 2. `OhosDataPanel` —— 名字还给官方，旧用途改名

这是最容易被忽略的一条：**同一个类名，语义完全换了**。

0.5.x 的 `OhosDataPanel` 是个 KPI 网格（标题 + 若干数值 + 列数）。官方文档里的 `DataPanel` 是**占比图**（环形或条形，表示数据的构成比例）。两者语义完全不同，占着同一个名字。

**旧代码（KPI 网格）**

```dart
OhosDataPanel(
  title: '今日数据',
  entries: <String, num>{'步数': 8000, '心率': 72},
  columns: 2,
  decimals: 0,
  prefix: '',
  suffix: '',
)
```

**迁移：把类名改成 `OhosStatGrid`，参数一个都不用动**

```dart
OhosStatGrid(
  title: '今日数据',
  entries: <String, num>{'步数': 8000, '心率': 72},
  columns: 2,
  decimals: 0,
  prefix: '',
  suffix: '',
)
```

`OhosStatGrid` 的签名与旧 `OhosDataPanel` **逐字相同**，视觉不变，是纯改名。

**新的 `OhosDataPanel`（官方占比图）**

```dart
OhosDataPanel(
  values: <double>[35, 25, 20, 20],
  max: 100,
  type: OhosDataPanelType.circle, // 或 .line
)
```

升级后旧代码不会「悄悄画错」—— 它会报 `The named parameter 'title' isn't defined` 和 `'values' is required`。这是好事：编译期就把你拦下了。

---

## 3. `OhosToolbarItem` —— `selected` 变成 `state`

旧字段把两件事压进一个布尔：**允不允许成为当前项**（官方 `ItemState.ACTIVATE`）与**现在是不是当前项**（由 `OhosToolbar.activeIndex` 决定）。于是可以写出「禁用 + 已选中」这种官方不存在、界面上是「一块蓝但点不动」的方块。

**旧写法**

```dart
OhosToolbarItem(
  icon: Icons.home,
  label: '首页',
  selected: true,
  onPressed: _go,
)
```

**新写法**

```dart
OhosToolbarItem(
  icon: Icons.home,
  label: '首页',
  state: OhosToolbarItemState.activated,
  onPressed: _go,
)
```

**迁移规则**

| 旧 | 新 | 说明 |
| --- | --- | --- |
| `selected: true` | `state: OhosToolbarItemState.activated` | 允许并应当成为激活项 |
| `selected: false` | `state: OhosToolbarItemState.enabled` | 正常可点 |
| 禁用项 | `state: OhosToolbarItemState.disabled` | 旧版没有办法表达 |

**注意**：`activated` 只表示「**允许**成为激活项」，真正高亮还要求 `OhosToolbar.activeIndex` 指向它。只把 `state` 设成 `activated` 而不设 `activeIndex`，这一项**不会**高亮 —— 这是官方行为，不是缺陷。三值不是互斥开关，而是「能不能点」与「允不允许激活」两条维度。

另外 `OhosToolbarItem` 不是 `Widget`，不能直接塞进 `Column`/`Row` —— 它是数据，要放进 `OhosToolbar(items: [...])`。

---

## 4. `OhosAlertDialog` —— `borderRadius` 不再是参数

**旧写法**

```dart
OhosAlertDialog(
  title: '删除文件',
  content: '删除后无法恢复',
  borderRadius: 20, // ← 报错：没有这个命名参数
)
```

**新写法：删掉这个实参即可**

```dart
OhosAlertDialog(title: '删除文件', content: '删除后无法恢复')
```

圆角现在恒为 `OhosDialogMetrics.borderRadius` = **32**（官方 `alert_container_max_width` 同一套令牌里的弹窗圆角）。

⚠️ **默认值从 28 变成 32**。这是静默视觉变化：删掉参数不会报错，但圆角会变大 4vp。在意的话需要调 `customStyle`：

- `customStyle: false`（默认）→ 圆角 32、不透明背板、padding 16、1px 描边
- `customStyle: true` → 圆角 0、背板透明、无内边距、无描边，**壳完全交给调用方**（想保留自定义圆角就走这条，自己在外面包 `ClipRRect`）

> 顺便说一个本版修掉的缺陷：`customStyle: false` 时弹窗曾经在窄屏上铺满整屏（`maxWidth = 400` 被当成了必然宽度）。现已改为「官方 400vp 上限」与「屏宽 − 16vp×2」取小。如果你之前为了绕开这个缺陷自己加了 `width:`，升级后可以去掉 —— 但注意 `width` 现在是**夹取**语义（超过 400 会被夹回 400），不是固定宽度。

---

## 5. `OhosSubheader` —— `padding` 移除、`title` 不再必填

**旧写法**

```dart
OhosSubheader(
  title: '系统设置',
  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), // ← 报错
  trailing: '更多',
  onTrailingTap: _more,
)
```

**新写法**

```dart
OhosSubheader(
  title: '系统设置',
  trailing: '更多',
  onTrailingTap: _more,
)
```

**为什么删掉 `padding`**：横向边距不是调用方能定的 —— 官方 `subheader.ets` 的 `getAreaPadding()` 按形态决定：副标题单行（或副标题 + 图标）时是 12，其余是 0。纵向是 `subheader_content_padding` = 8。让你设一个会被内部覆盖的值，比不给更好。

需要控制外边距用 `contentMargin`（外层），控制内边距用 `contentPadding`（内层）：

```dart
OhosSubheader(
  title: '系统设置',
  contentMargin: const EdgeInsets.symmetric(horizontal: 16),
  contentPadding: const EdgeInsets.symmetric(vertical: 8),
)
```

**第二个破坏点：`title` 从 `required` 变成了可选。**

这不会报编译错，但如果你原来只传 `title` 而现在误传成 `title: null`，会在运行时命中 `assert(title != null || secondaryTitle != null || leading != null)`。旧的 `padding` 默认值 `LTRB(16,16,16,8)` 也不存在了 —— 现在是 `contentMargin` 16 横 + `contentPadding` 8 纵，观感接近但不完全等价（旧的 16 纵包含了上下各 16，新的上下各 8）。

---

## 6. `OhosProgressIndicatorVariant` —— `circular` 改名 `ring`

**旧代码**

```dart
if (indicator.variant == OhosProgressIndicatorVariant.circular) { ... }
```

**新代码**

```dart
if (indicator.variant == OhosProgressIndicatorVariant.ring) { ... }
```

**注意区分两个东西**：

- ✅ **构造器 `.circular()` 保留**，`OhosProgressIndicator.circular(value: 0.5)` 照旧能用
- ❌ **枚举成员 `.circular` 没了**，改成 `.ring`

所以只改构造器调用的代码不受影响；读了 `variant` 字段做判断的代码会报 `There's no constant named 'circular'`。

本版枚举从 2 值扩到 5 值：`linear` / `ring` / `eclipse` / `scaleRing` / `capsule`，对应官方 `ProgressType` 的五个形态。**对 `variant` 做穷举 `switch` 且没有兜底分支的地方会编译失败** —— 这是预期的，新形态需要你决定怎么处理。

---

## 7. `OhosChipGroup` —— 默认选中第 0 颗（无编译错误）

这条最隐蔽：**不报错，但行为变了**。

ArkUI 的 `selectedIndexes: Array<number> = [0]`，且 `aboutToAppear` 在解析结果为空时再补一次 `[0]` —— 刚建好的组永远不是全空闲态。0.5.x 不传就一个都不选中。

**升级后如果你看到「第一颗莫名其妙被选中了」**，这不是缺陷，是官方行为。

想保留旧表现（全不选）：

```dart
OhosChipGroup(
  items: <OhosChipItem>[OhosChipItem(label: Text('选项一'))],
  selectedIndex: -1,               // 单选模式
  // 或多选模式：
  // selectedIndexes: const <int>{},
)
```

已补用例钉住「旧表现仍可达」，所以这条升级路径是通的。

> 顺带一个容易踩的签名细节：`OhosChipGroup.items` 收的是 `OhosChipItem`（不是 `Widget`），而 `OhosChipItem.label` 是 **`Widget`** 类型（不是 `String`）—— 写 `label: '选项一'` 会报类型错，要写 `label: Text('选项一')`。

---

## 8. `OhosTextClock` —— `timeZone` 换成 `timeZoneOffset`

**旧写法**

```dart
OhosTextClock(timeZone: 'Asia/Shanghai')
```

**新写法**

```dart
OhosTextClock(timeZoneOffset: -8)   // 东八区。注意是 -8，不是 +8
```

**为什么必须改**：旧参数**从来没生效过**。实现只有一行
`_now.toUtc().toLocal()` —— 一个恒等变换，传 `Asia/Shanghai` 与不传的渲染结果完全相同。它是个只在签名上存在的参数，保留它等于继续骗调用方。

符号方向是官方的：`timeZoneOffset` 取值 `[-14, 12]`，**负值表示东时区**
（`Date.getTimezoneOffset()` 那套）。东八区传 `-8`，写成 `+8` 会得到西八区。
`-5.75` 这类半小时档官方保留小数（共十个：`9.5 / 3.5 / -3.5 / -4.5 / -5.5 /
-5.75 / -6.5 / -9.5 / -10.5 / -12.75`），其余浮点值取整。

## 9. `OhosRatingBar` —— `value` 从 `int` 变 `double`

**旧写法**

```dart
OhosRatingBar(value: 3)
```

**新写法**

```dart
OhosRatingBar(value: 3)        // 仍编译通过：int 字面量可赋给 double
OhosRatingBar(value: 3.5)      // 官方 stepSize 默认 0.5，半星要 double 才表达得出
```

**注意**：如果 `value` 来自一个 `int` **变量**（不是字面量），会报
`argument_type_not_assignable`；`onChanged: (int v)` 也须改成 `(double v)`。
`int` 字面量能自动转换，所以示例里的 `value: 3` 不用动。

## 10. `OhosCheckbox` / `OhosCheckboxGroup` —— 默认形状改圆形

**无编译错误，只有观感变化**（这是本版第 2 处「静默」破坏）。

- `OhosCheckbox.shape` 默认从原先的**圆角方形**改成官方
  `CheckBoxShape.CIRCLE`（圆形）。要保留方形传 `shape: OhosCheckboxShape.roundedSquare`。
- `OhosCheckboxGroup.round` / `OhosCheckboxGroupHeader.round` 默认值 `false` → **`true`**，
  与 `OhosCheckbox` 同源 —— 否则同一个列表里会出现「圆形成员 + 方形组头」。
- 勾线从字体图标换成手画的 `CustomPaint`（字体字形的线宽是画死的，
  官方 `mark.strokeWidth` 落不了地）。如果你的代码里 `find.byType(Icon)`
  去找那个勾，会找不到。

## 11. `OhosImage` —— `fit` 类型换成 `OhosImageFit`

**旧写法**

```dart
OhosImage(image: ..., fit: BoxFit.cover)
```

**新写法**

```dart
OhosImage(image: ..., fit: OhosImageFit.cover)
```

**为什么不能继续收 `BoxFit`**：两组枚举同名不同义，且有档位在 `BoxFit` 里
根本不存在。`ImageFit` 有 8 个取值，`BoxFit` 有 7 个 —— 差值就在
`OhosImageFit.original`（原尺寸居中且**不裁**，`BoxFit` 没有这个组合）。
`none` 也各有细节差别。逐值硬映射看起来省事，实际会在边界上给出两种结果。

迁移只需把 `BoxFit.xxx` 换成对应的 `OhosImageFit.xxx`：
`cover` / `contain` / `fill` / `scaleDown` / `none` 五个同名，
`BoxFit.scaleDown` 之外没有别的需要换算；`fit` 默认仍是 `cover`（与官方一致）。

## 12. `OhosSelect` —— 默认不再画「选中勾」

**无编译错误，只有观感变化**（第 3 处「静默」破坏）。

`showDefaultSelectedIcon` 默认从 `true` 改成 **`false`** —— 官方口径是
「选中靠突出底色（20% 品牌色），不是靠勾」。老实现总是画勾，与这一条相反。
要保留旧观感传 `showDefaultSelectedIcon: true`。

---

## 不需要改的地方

确认过以下几处**没有破坏**，不用动：

| 项 | 为什么不是破坏 |
| --- | --- |
| `OhosChipGroupSize.normal` / `.small` | 改成 `typedef` 别名，成员名不变，已用真实工程编译验证 |
| `showOhosDialog` / `showOhosBottomSheet` / `showOhosPicker` / `showOhosMenu` | 只新增可选参数，无删除 |
| `OhosListTile.divider` | **本版根本没改**（`bool?` 是 0.5.0 之前就这样）。CHANGELOG 旧版把这条列为 0.6.0 破坏项，标注有误，已更正 |
| `OhosAlertDialog` 的其余 8 个新参数 | 全是可选的，不传就走默认 |
| `OhosChip` / `OhosChipItem` 的 `size` | 新增字段，有默认值 |
| `OhosVisualPolicy` 的自定义子类 | **没有新增抽象成员**（本版只加了带默认实现的 `selectionMark`），外部子类照旧编译 |

---

## 附：两处「不破坏 API、但观感会变」的修正

不是破坏性变更（签名没变、编译不报错），但**截图会不一样**，比对基线时别当成回归：

| 项 | 变化 | 想保留旧观感怎么办 |
| --- | --- | --- |
| `showOhosBottomSheet`（`type: bottom` / `detents: [`OhosSheetSize.large`]`） | 面板高度由「窗口高」变成「窗口高 − 状态栏 − 8vp」，顶边不再盖住状态栏 | 没有开关。这是官方公式（`bindsheet` 正文），旧行为是缺陷；确实需要满屏请用 `type: contentCover` |
| `showOhosMenu` 列表形态 | 条目左右内边距 12 → **16vp**（设计稿值），条目文案改为省略号截断 | 没有开关。宽 224vp 的菜单必须截断，此前是靠「刚好放得下」侥幸不溢出 |

---

## 一次性自查

升级后如果编译报错，按这个顺序过一遍：

```bash
# 1. 升级依赖
flutter pub upgrade harmony_ui

# 2. 抓编译错误（这里会一次性列出所有破坏点）
flutter analyze

# 3. 全文搜索几个最容易漏的关键词
grep -rn "secondaryActions\|primaryLabel\|primaryLoading" lib/
grep -rn "OhosProgressIndicatorVariant.circular" lib/
grep -rn "OhosDataPanel(" lib/       # 确认是不是 KPI 网格，是就换 OhosStatGrid
grep -rn "borderRadius:" lib/        # 看有没有传给 OhosAlertDialog
```

第 2 步能抓到的就不用搜。真正要手工确认的只有两件事：

1. **`OhosDataPanel` 的每一处调用** —— 它不报错（新签名也有 `title` 以外的必填），但你想要的可能是 `OhosStatGrid`
2. **`OhosChipGroup` 的选中态** —— 不传选中项的地方现在会默认选第一颗

---

## 附：本次核对的验证方式

上面的清单不是读签名猜的，是拿真实工程编译出来的：

1. 新建一个依赖本库的 Flutter 工程，把 0.5.0 的写法逐条写进去 → `flutter analyze` 报 **21 处错误**，覆盖第 1–6 条
2. 把同一段代码改成 0.6.0 写法 → `No issues found`
3. 第 7 条（`ChipGroup` 默认选中）签名单上看不出来，是读 `chipgroup.ets` 源码 + 对比 0.5/0.6 实现得出的
4. `OhosListTile.divider` 被 CHANGELOG 误列为破坏项，实际 `git diff main..HEAD -- lib/src/widgets/ohos_list_tile.dart` 为空 —— 本版没碰过这个文件