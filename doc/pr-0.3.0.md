# feat: 按 0.2.0 使用反馈补齐 AppBar / 墨主题 / 组件缺口

## 背景

来自一个全站 edge-to-edge 的 Flutter 应用（OpenHarmony API 26，平板 1600×2560）把
Material 控件逐个替换为 `Ohos*` 时整理的反馈：`feedback/HARMONY_UI_FEEDBACK.md`
（一～十一 + 附表）。这个 PR 覆盖其中可落地的条目，并按主题分成了 7 个提交。

## 变更概览

1. **OhosAppBar 能力补齐**：状态栏内边距、行布局（去掉固定 64vp）、标题对齐/内边距、
   `leadingWidth`、`bottom`、`systemOverlayStyle`、controller 回退与误配断言。
2. **墨水屏预设**：`OhosThemeData.ink()` + `monochrome` 能力开关 + 4 个 ink 令牌，
   并把「靠合成 / 靠底色分层」的组件在单色下换画法。
3. **输入类组件**：`OhosTextField.variant`（filled / capsule）、`suffixIcon`、`focusNode`；
   `OhosSearchBar` 的 `focusNode` / `onClear` / `onCancel` 与清空键定宽；
   `OhosButton` 标签 `Flexible` + 单色 / `NoSplash` 不吃水波纹。
4. **容器类组件**：`OhosAlertDialog.contentWidget`、`OhosListTile.density`、
   `showOhosBottomSheet(level, lightMaterial)`、`showOhosSnackBar(customMessenger)`、
   `OhosDivider` 默认缩进归 0。
5. **窄屏溢出（gallery 斑马线）**：示例页与 5 个组件在 360 / 320vp 下的
   `RenderFlex overflowed` 全部修掉，并新增示例工程的回归测试。
6. **窄屏 + 系统字体放大**：Android 常见 1.15x（Mate 60 Pro 出厂即 1.15）、无障碍
   1.3x 下再查一遍 —— `OhosNavigationBar` 平铺栏标签限制最大放大 1.15x 并可压缩
   （48vp 栏高、1.3x 时纵向溢出 1vp），`OhosAlphabetIndexer` 字号先按 `textScaler`
   折算回设计字号再留 5% 余量（只按 vp 摊分，1.15x 下仍溢出 27vp），示例页两处
   演示行相应改 `Wrap` / `Flexible`。
7. **评审第二轮（P1 / P2 全部修复）**：焦点节点生命周期、`OhosSearchBar` 的过期焦点态与
   「取消」按钮语义、`OhosDataPanel` 的静默缩放、墨水屏字阶、弹窗内容滚动、平铺栏字号钳制
   开关 —— 逐条应答见下文〈评审第二轮：逐条应答〉。

## 反馈条目对照

| 条目 | 状态 | 说明 |
|---|---|---|
| 一、状态栏内边距 | ✅ | `primary`（默认 true）自己吸收 `MediaQuery.padding.top`，背景仍铺到最顶端；`preferredSize` 保持 `height`（`Scaffold` 已加过一次） |
| 二、标题强制居中 + 左右 64 | ✅ | `titleAlignment`(center/start)、`titlePadding`（默认 8）、`leadingWidth`；固定 64vp 已移除 |
| 三、actions 溢出 | ◐ | 改行布局后标题先被压缩，不再与 actions 重叠、长标题在自身空间换行；未加横向滚动 / "更多"菜单（滚动式 actions 不符合鸿蒙习惯），文档已写明"动作过多仍会溢出" |
| 四、没有 bottom | ✅ | `bottom: PreferredSizeWidget?`，高度并入 `preferredSize`，可直接挂 `OhosTabBar` |
| 五、systemOverlayStyle | ✅ | `AnnotatedRegion<SystemUiOverlayStyle>` 下发，组件不再猜 |
| 六、scrollEffect 三件套误配 | ✅ | 省略 `scrollController` 时退回 `PrimaryScrollController.maybeOf`，两者都没有则 debug `assert`；另外核实：实现只读 `effect` 枚举、不读主题 `scrollEffectStyle`，所以"主题令牌默认 none 导致无效"这一现象不成立 |
| 七、lightMaterial 代价 | ✅ | dartdoc 标注为每帧全屏 `BackdropFilter`，墨水屏 / 低端机慎用 |
| 八.1 内部使用 Material | ❌ 保持 | 本库几乎所有组件都依赖 Material，只改 AppBar 无意义；纯自绘另开议题 |
| 八.2 iOS 风格返回图标 | ✅ | 默认改 `Icons.arrow_back_rounded`（鸿蒙粗箭头） |
| 八.3 缺 toolbarHeight 语义 | ✅ | 新增 `toolbarHeight` getter 作为 `height` 别名 |
| 九.9 清空键宽度跳 | ✅ | 空态占位 12 → 32vp，与清空键同宽 |
| 九.10 缺 focus / 取消语义 | ✅ | `focusNode`、`onClear`、`onCancel` + `cancelText`（聚焦出现「取消」，点击清空并失焦） |
| 九.11 四处缺口叠加 | ✅ | 自动内边距 + 对齐 + `bottom` + 标题位放控件（`titlePadding: zero` + `OhosSearchBar`） |
| 九.12 ListTile 无 density | ✅ | `OhosListTileDensity.regular / compact`（compact 等价 `ListTile(dense: true)`） |
| 九.13 填充式输入框缺失 | ✅ | `OhosTextFieldVariant.filled / capsule` |
| 十、墨水屏预设 | ✅ | `OhosThemeData.ink()`（纯黑白、无中间调、分隔线纯黑、水波纹全透明、功能色压黑、三级色留 #767676）+ `monochrome`；`OhosLightMaterial`（含 `lightMaterial` / bottom sheet / 页签光感）退化为纯色；`OhosAlertDialog`、`showOhosSnackBar`、`OhosPopup`、`OhosSlider` 补 1px 黑边；`OhosTextField` 硬编码 `danger` 改读主题 |
| 十一.1 SnackBar 指定 messenger | ✅ | `showOhosSnackBar(customMessenger:)` |
| 十一.2 Button 标签不收缩 | ✅ | 标签 `Flexible` + 默认单行省略（120vp 容器验证无 overflow） |
| 十一.3 Button 绕过 splashFactory | ✅ | `NoSplash` 与 `monochrome` 下 splash 透明 |
| 十一.4 AlertDialog 无描边 | ✅ | 单色下 1px 黑描边 |
| 附表：AlertDialog content 只收 String | ✅ | `contentWidget`（`showOhosDialog` 同步支持） |
| 附表：TextField 缺 suffixIcon/focusNode/风格 | ✅（除 `decoration`） | 同意不暴露原始 `InputDecoration`，避免绕过设计令牌 |
| 附表：Divider 默认 indent 16 | ✅ | 默认改 0（与 Material 一致）；`OhosListTile` 自己传 16 |
| 附表：Blank 名字像空态 | ◐ | dartdoc 澄清是留白占位；改名 / `OhosEmptyState` 属新 API，留待讨论 |
| 附表：bottomSheet 固定毛玻璃无开关 | ✅ | `level` + `lightMaterial`，单色主题自动退化 |

## ⚠️ 破坏性 / 行为变化（迁移方注意）

1. **`OhosDivider` 默认 `indent` 16 → 0**：直接替换 Material `Divider` 版式不再变化；
   需要与列表文字对齐时请显式传 `indent`（`OhosListTile` 已内置）。
2. **标题居中基准**：从"整条栏中轴"改为"leading 与 actions 之间的空间"。只有单侧有按钮时
   标题会比之前偏约 20vp；需要绝对居中时在另一侧放等宽占位。
3. **默认返回图标**：`arrow_back_ios_new_rounded` → `arrow_back_rounded`。
4. **`OhosAppBar.primary` 默认 `true`**：组件自己吸收 `MediaQuery.padding.top`。已经在外面
   包了 `SafeArea(top: true)` 的调用方会多出一次内边距，需要显式传 `primary: false`
   （`preferredSize` 没变，`Scaffold` 不会重复加）。
5. **`OhosNavigationBar` 平铺栏标签默认钳制在 1.15x**：默认栏高 48vp 装不下 1.3x 的标签
   行高（溢出 1vp）。这不是"抬高 `height` 就没了" —— 钳制是无条件的，需要跟随系统字号时
   传 `maxTextScaleFactor: null` 并同时调大 `height`（如 64）。
6. **`OhosChipGroup.scrollable: false` 不等于"不滚动"**：放不下时仍会横向滚动（原来直接
   `RenderFlex overflowed`），且没有滑动提示；需要换行请自己用 `Wrap` + `OhosChip` 组装。
7. **`OhosDataPanel` 的单元不再整体等比缩放**：标签在有界宽度内省略、只有数值在放不下时
   缩小。之前 320vp 窄卡里整格会被缩到 0.68x（1.3x 字号反而比 1x 还小），现在标签保持
   设计字号。
8. **`OhosThemeData.ink()` 的字阶是纯黑**（`OhosTypography.monochrome`），不再是 90% 黑；
   依赖 `typography.*.color` 的透明度做层次的自定义组件会看到颜色变深。
9. 其余均为新增可选参数，向后兼容（`OhosListTile.padding` 改为可空，传值用法不变；
   `OhosTextField` / `OhosSearchBar` 的 `controller` / `focusNode` 现在支持中途更换）。

## 评审第二轮：逐条应答

评审结论：「说明质量高、验证可复现，但有一个 P1 生命周期缺陷，外加多处『测试通过但掩盖了
行为退化』，建议修 P1/P2 后再合并」。结论接受 —— 6 项 P1/P2 全部按建议改掉；5 项 P3 里
2 项（CI、测试盲区）已修，3 项按你给的「文档路线」处理并写明理由。下面逐条对应你的编号。

### P1（必须修复）

**1. `OhosTextField.focusNode` 生命周期错误** — ✅ 已按建议重写

确认这是真缺陷，三个现象都能复现（换节点仍用旧节点 / 外部→`null` 再销毁误 dispose 外部节点 /
`null`→外部泄漏内部节点），根因就是 `late final` + 只在 `initState` 初始化 + 无
`didUpdateWidget`。

改法与你给的方向一致，但有一处必须在实现里额外注意：**所有权不能用 `widget.controller == null`
判断**，因为 `didUpdateWidget` 里 `widget` 已经指向新配置，判的是「新的有没有」，而不是
「旧的是谁创建的」。所以拆成实例字段 + owner 标记：

```dart
late TextEditingController _controller;   // 不再是 late final
late FocusNode _focusNode;
bool _ownsController = false;   // 只有自己 new 的才 dispose
bool _ownsFocusNode = false;

void _useFocusNode(FocusNode? node) {
  _focusNode = node ?? FocusNode();
  _ownsFocusNode = node == null;
  _focusNode.addListener(_onFocus);
  _focused = _focusNode.hasFocus;   // 顺带把焦点态同步到新节点
}

@override
void didUpdateWidget(OhosTextField oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.controller != oldWidget.controller) {
    if (_ownsController) _controller.dispose();
    _useController(widget.controller);
  }
  if (widget.focusNode != oldWidget.focusNode) {
    _releaseFocusNode();          // removeListener + 只在 _ownsFocusNode 时 dispose
    _useFocusNode(widget.focusNode);
  }
}
```

- `dispose()` 走同一套 `_releaseFocusNode` / `_ownsController`，不再看 `widget.*`。
- `controller` 按你的提示一并修：`null → external → null` 不再留旧实例，也不再 dispose 外部实例。
- dartdoc 里「a supplied node is never disposed by the widget」现在成立；同时把「支持中途更换」
  写进了 dartdoc。

验证（4 条新用例，都在 `test/ohos_ui_test.dart` 的 `OhosTextField` 组）：

- `换 focusNode 后立刻用新节点，旧的外部节点不被销毁` — A→B 后断言 `TextField.focusNode == B`，
  并对 A 调 `addListener`（被 dispose 会抛）。
- `外部节点换成 null 后再销毁组件，不 dispose 外部节点` — 就是你探针里那条
  `A FocusNode was used after being disposed`，现在不抛。
- `内部创建的节点在换成外部节点时被销毁（不泄漏）` — 先从 `TextField.focusNode` 取到内部节点，
  切成外部节点后断言该节点已 dispose。
- `换 controller 后组件用新实例，外部 controller 不被销毁`。

### P2（建议合并前修复）

**2. `OhosSearchBar` 更换 focusNode 后焦点状态过期** — ✅ 已修

- 换节点后立即 `_focused = _focusNode.hasFocus`（你的探针输出
  `cancel after swap to unfocused second: 1` 现在是 0；反向「新节点已聚焦」也不会再等下一次
  焦点变化）。`controller` 同样按所有权处理。
- 「取消」改成真正的按钮：`GestureDetector` → `TextButton`，带 button 语义、可聚焦、回车/空格
  可激活，`minimumSize: Size(48, 40)`。这里踩到一个坑值得记下：**`visualDensity` 不能压**，
  `VisualDensity.compact` 会再砍 8vp，48×40 直接变 40×32；所以用 `standard` +
  `tapTargetSize: shrinkWrap`（不额外加水波纹余量），墨水屏下 `overlayColor` 设透明。

验证：`换 focusNode 后「取消」按新节点的真实焦点显示`、`新节点带着焦点请求换进来时，「取消」自动出现`、
`「取消」是按钮：够大的命中区 + button 语义`（用 `matchesSemantics(isButton, hasTapAction,
hasFocusAction)` + 命中区 ≥48×40）。

**3. `OhosDataPanel` 用 FittedBox 静默缩小文字** — ✅ 已修，取「只缩放数值」方案

- 去掉整列外层 `FittedBox`，标签回到有界约束里 `maxLines: 1` + `ellipsis`（省略号重新生效），
  只有数值是 `Flexible` + `FittedBox(scaleDown)`。
- 复测 240vp（两列，`childAspectRatio: 1.6`，格宽 115、内容宽 87）：
  标签布局宽度 87vp（你原来测到 313.5vp 的无界宽度），高度 1.0x → 21vp、1.3x → 28vp
  （1.33 倍，确实跟随系统字号放大，而不是被整格缩回）。
- 遗留取舍（记录在案）：格高仍由 `GridView` 的 `childAspectRatio` 决定，所以 240vp 这种
  「两列太窄」的卡片里数值仍会缩（连 1.0x 都装不下：内容高 43.9vp，而标签 21 + 间距 6 +
  数值 31 就要 58vp）。彻底的解法是 `LayoutBuilder` 按当前字号算最小格高，但那会改动
  `OhosDataPanel` 的 `columns` / 间距契约，留作后续单独提。

验证：`长标签在 1.3x 字号下：标签仍被放大并省略，不是整格缩小` —— 同一 320vp 卡片分别在
1.0x / 1.3x 下取标签与数值的**渲染高度**，断言两者都 > 1.2 倍（整格缩小时这条必挂），并断言
标签宽度 ≤ 单元格宽（省略生效）。

**4. 墨水屏预设的排版文字不是纯黑** — ✅ 已修

- 新增 `OhosTypography.monochrome()`（`Color(0xFF000000)`），`OhosThemeData.ink()` 改用它。
- 没有在 ink 里逐个 `copyWith`：字阶是组件默认色的唯一来源，逐个改漏一处就又会退回
  `0xE6000000`；在字阶层面换颜色一次性覆盖 `OhosAppBar` 标题、未指定颜色的 `OhosText` 以及
  调用方自己 `Text(style: theme.typography.x)` 的写法。`light` / `dark` 字阶不变。

验证：`ink 字阶是纯黑…`（`bodyMedium` / `titleMedium` / `labelSmall` / `headlineMedium`
四个层级 + 彩屏仍是 `textPrimary`）；`ink 下没自己指定颜色的 AppBar 标题 / OhosText 渲染成纯黑`
—— 断言的是 `RichText` 里的**实际绘制色**，不是 `Text.style`。

**5. `contentWidget` 弹窗没有滚动保护** — ✅ 已修

- 内容槽改为 `Flexible` + `SingleChildScrollView`：标题与按钮不滚，内容超高时内部滚动。
- 没有额外加 `maxHeight`：内容多时让弹窗长到屏幕上限再内部滚动，比「弹窗只占半屏 + 里面小滚动
  区」更接近 ArkUI 表单弹窗的习惯；要限制可以在外部包 `ConstrainedBox`。

验证：`窄屏 + 大字号下，多字段表单的 contentWidget 改为滚动而不是溢出`（320×640、1.3x、
8 个 `OhosTextField` + 2 个动作，断言无异常、存在 `SingleChildScrollView`、弹窗高度 ≤ 640）。

**6. 平铺导航栏硬编码 1.15x 字号上限，且无法关闭** — ✅ 已修

- 新增 `OhosNavigationBar.maxTextScaleFactor`，默认 `1.15`（保持 48vp 栏高不溢出），传 `null`
  表示不钳制；此时配合 `height: 64` 可以真正拿到 1.3x。
- dartdoc 与迁移清单里原来「需要更大字号时自行抬高 height」的说法已改成「钳制是无条件的，
  要跟随系统字号请传 null 并同时抬高 height」——那句确实是错的，感谢指出。

验证：`平铺栏标签默认钳到 1.15x，maxTextScaleFactor: null 时跟随系统` —— 读 `RichText.textScaler`
的 `scale(10)`：默认 11.5，`null` + `height: 64` 时 13.0。

### P3（后续处理）

**7. `OhosChipGroup.scrollable` 语义被改变** — 📄 文档（保留横滚行为）

`false` 现在表示「放得下就不加滚动视图」，放不下时仍横滚 —— 因为不滚就是
`RenderFlex overflowed`（这正是 0.3.0 要修的问题）。已按你给的第一条路线更新 API 文档：
dartdoc 写清这层语义、说明窄屏上尾部 chip 需要横滑且**没有**滑动提示，并指明要换行请自己用
`Wrap` + `OhosChip` 组装；迁移清单同步加了一条。若你更希望 `false` 就换行，我倾向新增
`OhosChipGroup.layout`（`strip` / `wrap`）而不是改默认值 —— 单行横滑是官方「子页签」的版式，
改默认属于破坏性变化。

**8. 墨水屏适配不完整（`OhosCard` 白底无边、`OhosSearchBar` 白底胶囊）** — 📄 文档（明确支持范围）

采用你给的第二条路线：在 `OhosThemeData.ink()` 的 dartdoc 里列明**会换画法**的组件（light
material 退化纯色、`OhosAlertDialog` / `showOhosSnackBar` / `OhosPopup` / `OhosSlider` 1px 黑边、
filled 输入框转 1px 线、分隔线纯黑、阴影与水波纹关闭）与**不会**自动加描边的组件
（`cardColor` = 页面背景的那一类），并写明怎么自己补边界（`OhosCard.color`、外面包一层带边框
的父级；`OhosSearchBar` 目前没有颜色参数）。
没在本 PR 顺手加 1px 黑边的原因：会给所有既有卡片/胶囊版式每边各加 1vp，72 条矩阵基线也要
重跑，属于一次独立的「墨主题适配补全」。需要的话我可以单独提一个 PR（约 10 行 + 2 条用例）。

**9. 示例溢出测试未接入 CI** — ✅ 已修

`ci.yml` 增加 `Test (example)`：`working-directory: example` + `flutter test`。原来 example
只跑 format / analyze，这 72 条确实只在本地生效。

**10. 版本与迁移说明** — 📄 说明

- `pubspec.yaml` 的 `version` 没改（仍是 `0.2.0`，CHANGELOG 已是 `0.3.0 (unreleased)`）：
  发版节奏留给你，这个 PR 只占 unreleased 小节。
- 迁移清单补齐了你点的四项，并把「其余均为新增可选参数，向后兼容」这句过于绝对的表述拆开：
  `primary` 默认 `true`（已包 `SafeArea` 的调用方需传 `false`）、`OhosChipGroup` 非滚动模式仍
  横滚、`OhosDataPanel` 不再整体缩放、平铺栏默认钳制 1.15x。另外补了 ink 字阶变纯黑这一条。

**11. 测试盲区** — ✅ 已补 14 条

| 你点的盲区 | 新用例 |
|---|---|
| focusNode prop 切换 / 销毁 | 4 条（A→B、外部→`null`、`null`→外部、`controller` 同理） |
| SearchBar 焦点切换 | 2 条（两个方向）+ 1 条按钮语义/命中区 |
| tall contentWidget | 1 条（320×640 + 1.3x + 8 字段） |
| ink 渲染颜色 | 2 条（字阶静态断言 + `RichText` 实际绘制色） |
| DataPanel 长文本缩放 | 1 条（1.0x vs 1.3x 渲染高度） |
| `customMessenger` | 1 条（断言提示落在内层 `ScaffoldMessenger` 子树里） |
| `lightMaterial: false` | 1 条（彩屏上也不出 `BackdropFilter`） |

库测试 48 → 62 条；示例矩阵仍 72 条不变（本轮没有改动它的宿主逻辑）。

### 关于「做得好的地方」

谢谢确认 72 条矩阵确实扫到了页底（display 页 10,192vp / 覆盖 10,824vp）——
这正是我们敢在 P2-3 里改用「渲染高度比」而不是「有无 overflow」做断言的原因：
光看溢出是查不出静默缩放的。

## 验证

> 环境说明：你在 `ohos/oh-3.35.7-release`（Flutter 3.35.8）下复现了 P1～P2 的四个现象，我们按
> 你的探针描述逐条对齐了预期；本轮改动本身是在 Flutter **3.41.9** 上跑的 analyze / test
> （本机 fvm 的默认版本，`.fvmrc` 指向的 3.35.7 没装）。需要的话我可以切到
> `oh-3.35.7-release` 再跑一遍，把两边的结果都贴上来。

- `flutter analyze`（库 + example）零问题
- 库测试 `flutter test` 62 条全通过（第一轮 48 条 + 评审第二轮 14 条）：
  - AppBar：行排布不重叠、单侧按钮的居中基准、长标题被约束、`titleAlignment.start`、
    `titlePadding: zero`、`leadingWidth` 槽内居中、`bottom` 并入 `preferredSize`、
    `systemOverlayStyle`、`PrimaryScrollController` 回退、`toolbarHeight`、返回键图标
  - 墨主题：ink 令牌（纯黑白 / 无中间调 / 功能色压黑）、`copyWith` 保留 `monochrome`、
    `OhosLightMaterial` 无 `BackdropFilter`（彩屏仍有）、输入框错误态取主题色、弹层 1px 黑边、
    底部面板退化
  - 组件：按钮窄容器不溢出 + 无水波纹、filled 在 ink 下转 1px 线、`suffixIcon` / `focusNode`、
    搜索框 `onClear` 与 32vp 占位、取消回调、`contentWidget` 优先、列表 density 字阶与行高、
    分隔线默认缩进
  - 评审第二轮：`focusNode` 换节点后 `TextField` 用新节点、外部→`null` 后销毁不误 dispose
    调用方节点、`null`→外部时内部节点被销毁、`controller` 同理；SearchBar 换节点后「取消」
    按新焦点显示（两个方向）与按钮语义/命中区；DataPanel 长标签 + 1.3x 下标签与数值都真的
    被放大而不是缩小；ink 字阶纯黑 + AppBar 标题 / `OhosText` 实际渲染色；320vp × 1.3x 的
    8 字段弹窗改为滚动；`showOhosSnackBar(customMessenger)` 挂在内层 messenger 上、
    `showOhosBottomSheet(lightMaterial: false)` 在彩屏上也不铺光感
- 示例新增 4 处演示：AppBar「对齐 / bottom / 标题位放控件」、展示类「墨主题」、
  输入类「填充 / 胶囊形态」、容器类「高密度列表」
- CI：`Test (example)`（`working-directory: example` 的 `flutter test`）—— 溢出矩阵不再
  只在本地跑
- 示例工程新增 `example/test/gallery_overflow_test.dart`：8 个页面 × 3 种宽度
  （360 / 320 / 387vp）× 3 种字号（1.0 / 1.15 / 1.3）逐屏下滑，通过
  `MediaQuery.textScaler` 注入系统字号，捕获 `RenderFlex overflowed` 并报出出问题的
  `Row` / `Column` 与行号（72 条全通过）

## 提交

分支基于 `upstream/main` 的最新提交 `2df9d8b`（已把该提交的
`README.OpenHarmony.md` / `README.OpenHarmony_CN.md` / `CHANGELOG.OpenHarmony.md`
合入，无冲突）：

```
f7cc71d fix: 窄屏叠加系统大字号时的溢出
736b9b3 fix: 消除 gallery 与组件在窄屏下的「斑马线」
bb40502 docs: 补 0.3.0 PR 说明（反馈条目对照 / 破坏性变更 / 验证）
a605792 fix: 收敛反馈里剩下的分隔线 / 单色阴影 / 返回键三项
e8f1103 feat: 按反馈补齐输入类与容器类组件的缺口
0ea6c87 feat(theme): 新增墨水屏预设 OhosThemeData.ink 与 monochrome 开关
290f66a feat(appbar): 补齐标题对齐 / 内边距 / bottom / 状态栏样式
bd482b4 test(appbar): 补行布局与居中基准用例
3c8dc24 refactor(appbar): 标题栏改为单行 Row 布局
6b06717 fix(appbar): 吸收状态栏内边距，避免沉浸式下标题/动作被系统栏压住
```

评审第二轮的修复按你的分档再拆成三个提交追加在分支尾部（P1 生命周期 /
P2 五项 / 文档 + CI + 测试），提交哈希以 PR 页为准。

## 尚未处理（有意留下）

- `actions` 横向滚动 / "更多"菜单：见上表第三条理由
- `OhosBlank` 改名或新增 `OhosEmptyState`
- 暴露原始 `InputDecoration`
- AppBar 内部改用自绘（去掉 Material 依赖）
- 墨水屏下 `OhosCard` / `OhosSearchBar` 的白底无边（逐条应答 8）：本 PR 只写明支持范围与
  自助办法。自动补 1px 黑边会改变所有既有版式（卡片 / 胶囊每边各加 1vp），且要重跑 72 条
  基线，适合作为独立的「墨主题适配补全」提交
- `OhosChipGroup.scrollable: false` 的换行语义（逐条应答 7）：保持横滚，改成 `Wrap` 属于
  版式破坏性变化，且官方「子页签」规范里就是单行横滑；需要时新增 `layout` 参数而不是改默认
- `OhosDataPanel` 的格高自适应（逐条应答 3）：本轮只按建议把缩放范围收窄到数值。按当前字号
  算最小格高需要改 `columns` / 间距契约，另开 PR
- `OhosSearchBar` 还没有 `backgroundColor`：墨主题下想留边界只能靠父级描边，补一个可选颜色
  参数即可（未纳入本轮）
