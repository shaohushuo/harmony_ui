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
4. 其余均为新增可选参数，向后兼容（`OhosListTile.padding` 改为可空，传值用法不变）。

## 验证

- `flutter analyze`（库 + example）零问题
- `flutter test` 48 条全通过，新增 25 条：
  - AppBar：行排布不重叠、单侧按钮的居中基准、长标题被约束、`titleAlignment.start`、
    `titlePadding: zero`、`leadingWidth` 槽内居中、`bottom` 并入 `preferredSize`、
    `systemOverlayStyle`、`PrimaryScrollController` 回退、`toolbarHeight`、返回键图标
  - 墨主题：ink 令牌（纯黑白 / 无中间调 / 功能色压黑）、`copyWith` 保留 `monochrome`、
    `OhosLightMaterial` 无 `BackdropFilter`（彩屏仍有）、输入框错误态取主题色、弹层 1px 黑边、
    底部面板退化
  - 组件：按钮窄容器不溢出 + 无水波纹、filled 在 ink 下转 1px 线、`suffixIcon` / `focusNode`、
    搜索框 `onClear` 与 32vp 占位、取消回调、`contentWidget` 优先、列表 density 字阶与行高、
    分隔线默认缩进
- 示例新增 4 处演示：AppBar「对齐 / bottom / 标题位放控件」、展示类「墨主题」、
  输入类「填充 / 胶囊形态」、容器类「高密度列表」

## 提交

```
6b06717 fix(appbar): 吸收状态栏内边距，避免沉浸式下标题/动作被系统栏压住
3c8dc24 refactor(appbar): 标题栏改为单行 Row 布局
bd482b4 test(appbar): 补行布局与居中基准用例
290f66a feat(appbar): 补齐标题对齐 / 内边距 / bottom / 状态栏样式
0ea6c87 feat(theme): 新增墨水屏预设 OhosThemeData.ink 与 monochrome 开关
e8f1103 feat: 按反馈补齐输入类与容器类组件的缺口
a605792 fix: 收敛反馈里剩下的分隔线 / 单色阴影 / 返回键三项
```

## 尚未处理（有意留下）

- `actions` 横向滚动 / "更多"菜单：见上表第三条理由
- `OhosBlank` 改名或新增 `OhosEmptyState`
- 暴露原始 `InputDecoration`
- AppBar 内部改用自绘（去掉 Material 依赖）
