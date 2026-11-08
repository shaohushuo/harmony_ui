# harmony_ui 0.6 规划

对照基准（**四层**，缺一不可）：

1. **设计规范** —— 官方「控件概览」<https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/general_overview-0000001929599380>，42 项逐个抓取 `doccenter-ux-design/<slug>.md` 正文。
2. **组件参考文档** —— 每页「开发文档」章节指向的 ArkUI 组件。分两条链路取：
   - 开源 ArkUI 组件：中文站参考页是 SPA、静态抓取只有 404，权威原文在 OpenHarmony 仓库 `raw.gitcode.com/openharmony/docs/raw/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/<组件名>.md`。
   - 闭源 HDS 组件：官网有 markdown 原文，路径 `developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-<小写slug>.md`。
3. **参考文档里的示例代码** —— 每个组件的 `### 示例N` 段落。**这是 0.5 完全漏掉的一层**：只读设计规范会知道「有哪些控件」，只有读参考文档与示例才知道「每个控件有几个形态、每个形态长什么样、默认值是多少」。
4. **具体数值**（文档层彻底给不了的东西）—— 有两个资料源，缺一不可：
   - **组件实现源码** `raw.gitcode.com/openharmony/arkui_ace_engine/raw/master/advanced_ui_component/<组件>/source/*.ets`：答**硬编码**的那部分（`DEFAULT_TITLE_BAR_HEIGHT = 56`、`MAX_MAIN_TITLE_PERCENT = 0.65`）。目录列表走 `api.gitcode.com/api/v5/repos/openharmony/arkui_ace_engine/contents/<路径>?ref=master` —— **列目录取真实文件名，不猜**。
   - **系统资源明文仓** `raw.gitcode.com/openharmony/global_system_resources` → `systemres/main/resources/base/element/float.json`（4324 行）+ `float_sys.json`（2032 行）：答**令牌**的那部分。文档写「默认值：`$r('sys.float.chip_normal_height')`」，`float_sys.json` 是别名表（`search_default_height → $float:ohos_id_search_default_height`），`float.json` 是真实值（`40.0vp`）。**这两份 JSON 就是 `resources.index` 的源文件**，不必去逆向 RestoolV2 二进制。

   > **2026-11 仓址迁移（原 gitee → GitCode）。** 三处地址全部改到 `raw.gitcode.com`，`arkui_ace_engine` 的仓库地址由用户指出后更正。两个必须记住的点：
   > ① `gitcode.com/<仓>/raw/...` 与 `/<仓>/-/raw/...` **只返回 HTML**，状态码还是 `200` —— 必须用 `raw.gitcode.com`；API 又必须用 `api.gitcode.com`，两者是不同 host。
   > ② 迁移的直接动因不是「地址变了」而是**旧地址的目录 API 已全线 403**（`Rate Limit Exceeded`）。旧的 raw 还能下（302 到 `raw.giteeusercontent`），但 `fetch_source.sh` 靠 `contents` API 列目录取真实文件名 —— 它一失效就只能退回去猜名字，那是最容易出错的环节。
   >
   > **这次迁移还牵出一个判据修正：源码不再必然答「硬编码」。** 上游连续两处把常量从字面值改成了令牌引用 —— `subheader.ets` 用 `lazyInit(() => getResourceValue('sys.float.subheader_right_*'))`，`chipgroup.ets` 干脆把 `enum ChipGroupHeight { NORMAL = 36, SMALL = 28 }` 整个删掉，改用 `chip.ets` 的 `ChipSize { NORMAL = "NORMAL", SMALL = "SMALL" }` + `$r('sys.float.chip_normal_height')`。源码现在只说令牌名，真值要回到 `float.json` / `float_sys.json` 查。本库第 4 层的原始表述「源码答硬编码、资源表答令牌」是按**来源**分的，实际应按**上游当时怎么写的**分：同一个字段两个来源都可能给，哪边给不出就换另一边。本轮已核对这两批令牌的真值（`subheader_right_arrow_height = 24vp`、`arrow_width = 12vp`、`icon_zone_size = 28vp`、`icon_size = 24vp`；`chip_normal_height = 36vp`、`chip_small_height = 28lpx`）**与原硬编码完全一致**，所以本库既有实现无需改动。

已抓取 **55 份**参考文档（43 份 ArkUI + 8 份 HDS 闭源 + 4 份反查项），合计 **402 个官方示例** —— 这是「我们照官方做了多少」的分母（`TextInput` 32、`Search` 30、`Image` 30、`Text` 29、`Tabs` 23、`Navigation` 18、`List` 17…）。

另抓取 **29 份组件实现源码**（36,354 行，`doc/reference/source/`，脚本 `tool/fetch_source.sh`）。

> **不要靠猜 slug 找文档。** 权威清单的唯一来源是 `tool/trace_control_docs.sh`：从概览页取 42 个控件链接 → 打开各自设计文档 → 取末尾「## 开发文档」里的链接 → 剥锚点后拼成参考文档地址。这条链路跑完的结果是 41 个控件有链接且全部可达、1 个（色彩选择器）官方漏给链接但文档存在、**0 个控件真的没有文档**。
>
> 上一版写的「51 份 / 369 示例」是差集比对之前的数。补进来的 4 份贡献了 31 个示例，其中 `ChipGroup`（子页签）此前**从未被抓过** —— 原抓取表用的是 `ohos-arkui-advanced-Chip`（单个 Chip），矩阵里「子页签 胶囊型」却一直标着 `●`。分母算小了，缺口就会被系统性低估。
>
> **抓源码这一层同样不要猜文件名。** 目录名与文件名不一致，且不一致的方式还不统一：`chip/source/chip.ets` 同名，但 `gridobjectsortcomponent/source/GridObjectSortComponent.ets` 是全驼峰 —— 试「首字母大写」也 404。正确做法是用 API 列目录取真实 `.ets` 名（`tool/fetch_source.sh` 已是这么写的）。**这是「猜名字」这个错误的第三次出现**（前两次：猜文档 slug 判有无、`Chip` 误当 `ChipGroup`）。
>
> **`search_theme.h` 也不在 `components_ng/pattern/search/` 下**（该目录只有 21 个文件，无 theme），实际在 `components/search/search_theme.h`。`components_ng` 那份是 404。这是同一个错误的第四次 —— 只是这次靠「先列目录」当场发现，没有写进文档。

---

## 〇、上一版规划的错误（已修正）

### 0.1 三处基于设计规范的误读

上一轮只读了设计规范、没读参考文档，以下三条判断是错的：

| 我曾写成 | 实际（参考文档原文） |
| --- | --- |
| 滑块缺「双值区间选择」 | **没有双值区间**。`slideRange` 是「设置**有效滑动区间**」（限制可达范围），不是 `RangeSlider`。官方 `Slider` 只有单值 + `stepSize` 步进 + `showSteps` 刻度显示 |
| 进度条只有 linear / capsule / eclipse | `ProgressType` 枚举是 **5 种**：`Linear` / `Ring` / `Eclipse` / `ScaleRing`（环形**带刻度**）/ `Capsule` |
| 列表分组间隔、圆角随意定 | `ListItemGroupStyle` 是枚举 **`NONE` / `CARD`** 两档，卡片样式是官方内置的，不是我自拟的视觉 |

### 0.2 一处更严重的错误：「HDS 闭源 = 没有文档」

上一版把 `HdsActionBar` / `HdsSnackBar` / `EditableTitleBar` 归为「闭源 HDS 组件，上游无文档」，据此宣布核心操作栏「规格只能以设计规范为准、以设计稿截图为准」，并在矩阵里把它们标成「无文档」。

**这是错的。** 官网的 `doccenter-references/api/ui-design-<slug>.md` 路径能直接取回 markdown 原文，8 份全部存在：`HdsActionBar` / `HdsSnackBar` / `HdsTabs` / `HdsNavigation` / `HdsListItem` / `HdsListItemCard` / `HdsColorPicker` / `hdsMaterial`。只有 `EditableTitleBar` 确实没有（多个 slug 变体全 404，`HdsNavigation` 里也没有对应章节）。

区别在于：前三条错误是**读错了**，这条是**没去找就说没有**。后者的危害更大 —— 它让一整类组件在规划里自动降级为猜测，而且看起来像经过了审慎判断（原文还专门写了「否则会假装自己查过了」这种话）。查不到可以写查不到，但必须是真的查过。

拿到文档后，核心操作栏与底部页签的规格全部推翻重写，见第一、二节。

---

## 一、核心操作栏：文档存在，规格比想象的具体得多

`HdsActionBar` 参考文档：<https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-hdsactionbar>（起始版本 6.0.0(20)，`@kit.UIDesignKit`）。上一版说它「无文档」是错的，现按原文核对。

真实构造签名：

```
HdsActionBar({
  primaryButton?: ActionBarButton,
  primaryButtonBuilder?: CustomBuilder,      // 优先级高于 primaryButton
  primaryButtonBuilderWidth?: LengthMetrics, // 用 builder 时必须同时给宽度
  startButtons?: Array<ActionBarButton>,     // 起始位置按钮组
  endButtons?: Array<ActionBarButton>,       // 末尾位置按钮组
  actionBarStyle?: ActionBarStyle,
  isExpand?: boolean,                        // 默认 false
  $isExpand?: Callback<boolean>,
  blurStrategy?: BlurStrategy,               // 默认 ADAPTIVE
})
```

**关键结构差异：`startButtons` 与 `endButtons` 是两端各一组，不是「次要操作列表 + 主按钮」的二元结构。** 上一版规划的「侧边布局」是把设计规范里的「侧边布局」四个字当成一个待加参数，实际官方表达这件事的轴是 `ActionBarStyle.isHorizontal`（默认 `true`；`false` 时竖直排列，此时 `startSpace` 指上边框、`endSpace` 指下边框）。

`ActionBarButton` 的属性（不是「改图标按钮大小」一个 bool，是每个按钮独立可配）：

| 属性 | 说明 |
| --- | --- |
| `width` | 圆形按钮宽度，支持 px/vp/fp/lpx，**不支持 percent** |
| `backgroundColor` | 圆形按钮背景色 |
| `shadowStyle` | 默认 **`ShadowStyle.OUTER_DEFAULT_LG`** |
| `enabled` | 默认 `true` |
| `baseIcon` | 初始图标；非主按钮时即该按钮图标 |
| `altIcon` | 主按钮切换后的图标；**非主按钮不生效** |
| `iconFillColor` / `iconSize` | 图标色 / 图标尺寸 |
| `baseIconSymbolGlyphModifier` / `altIconSymbolGlyphModifier` | 切换前后图标的 Modifier 样式 |
| `hoverTips` | 悬浮提示（桌面键鼠） |
| `buttonModifier` | Modifier |
| `accessibilityText` / `accessibilityDescription` / `accessibilityLevel` | 无障碍三件套，描述默认 `"单指双击即可执行"` |
| `id` | 供 `openPopup` 绑定 |

`ActionBarStyle` 的属性：

| 属性 | 默认值 / 说明 |
| --- | --- |
| `height` | 背板高度 |
| `backgroundBlurStyle` | **`BlurStyle.COMPONENT_REGULAR`（默认就开模糊）** |
| `backgroundColor` | 背板背景色 |
| `innerSpace` | 主按钮到起始按钮 / 到末尾按钮的距离 |
| `startSpace` / `endSpace` | 起始 / 末尾按钮到背板边框的距离 |
| `enabled` | 默认 `true`；`false` 时背板与**所有**按钮一并禁用 |
| `isHorizontal` | **默认 `true`**；`false` 为竖直排列 |
| `isPrimaryIconChanged` | 默认 `false`；`true` 时主按钮显示 `altIcon` |
| `margin` | 上下边距（**6.1.0(23) 起**） |

官方示例（唯一一个）演示的正是「主按钮图标随展开状态切换 + hoverTips 跟着换」：

```typescript
HdsActionBar({
  startButtons: [new ActionBarButton({ baseIcon: $r('sys.symbol.stopwatch_fill') })],
  endButtons: [new ActionBarButton({ baseIcon: $r('sys.symbol.mic_fill') })],
  primaryButton: new ActionBarButton({
    baseIcon: $r('sys.symbol.plus'),
    altIcon: $r('sys.symbol.play_fill'),
    onClick: () => {
      this.isExpand = !this.isExpand;
      this.isPrimaryIconChanged = !this.isPrimaryIconChanged;
      this.primaryHoverTips = this.isPrimaryIconChanged ? '暂停' : '开始';
    },
    hoverTips: this.primaryHoverTips
  }),
  actionBarStyle: new ActionBarStyle({ isPrimaryIconChanged: this.isPrimaryIconChanged }),
  isExpand: this.isExpand
})
```

对照现有 `OhosActionBar`（逐项读源码核对，非推测）：

| 官方能力 | `OhosActionBar` 现状 |
| --- | --- |
| 主按钮（`primaryButton`） | 有（legacy 文本药丸 / expandable 圆形按钮） |
| 自定义主按钮（`primaryButtonBuilder` + 宽度） | **无** |
| 两端按钮组 `startButtons` / `endButtons` | **无** —— 只有单一 `secondaryActions`，且全部落在主按钮左侧 |
| 每按钮 `width` / `backgroundColor` / `iconSize` / `iconFillColor` | **无**（尺寸写死 56，图标 26 写死） |
| 每按钮 `enabled` | **无** |
| 主按钮 `baseIcon` / `altIcon` 切换 | 部分（`primaryIcon` 单图标按 `isExpanded` 换内置图标，无法由调用方给两个图标） |
| `hoverTips`（桌面键鼠） | 部分（`Tooltip` 包裹，文案由 `primaryTooltip` 单字段给） |
| `isHorizontal` 竖直排列 | **无** |
| `innerSpace` / `startSpace` / `endSpace` / `height` / `margin` | **无**，padding 写死 `16,12,16,12` |
| 默认模糊材质 | **无默认**（`lightMaterial` 需显式开，默认关；官方是默认开） |
| `ActionBarStyle.enabled` 整体禁用 | **无** |
| 去掉主按钮 | **本轮已修**（见下） |

**本轮顺手修掉的一个真实缺陷**：`primaryLabel` 是 `String?`，但 legacy 布局无条件渲染 `OhosButton(child: Text(primaryLabel ?? ''))` —— 不传标签就得到一个**空药丸**，看着像加载失败。这既是官方「去掉主按钮」形态没实现，也是比"不画"更糟的失败方式。已改为 `if (primaryLabel != null || primaryLoading)`（loading 时保留，因为转圈本身是唯一反馈），并补 3 条用例；已验证回退后「不传标签」那条会红。

同类确认存在的问题（不是猜测，都读源码核过）：

- ~~`OhosToolbarItem` 只有 `selected`，**没有禁用态**~~ —— **已修**（见阶段 D-6，`selected` → `state`）。
- `OhosSegmentedButton` **没有 2–5 个的数量约束** —— 官方 `ItemRestriction` 明确限死 2–5 个。

**结论：核心操作栏要重做布局能力，规格有明确依据（就是上面那张表），不是"按截图猜"。** 需要注意 `OhosActionBar` 现有 API 与官方结构完全不同（单一 `secondaryActions` vs 两端 `startButtons`/`endButtons`），这会是 0.6 第二处破坏性变更 —— 见第六节待决事项。

### 同批新发现：底部页签远不止「平铺 / 悬浮」

`HdsTabs` 文档（1537 行）推翻矩阵里「底部页签 ● 完整」的判断：

- `barFloatingStyle`（6.1.0(23)+）内含 `barWidth`（**分档宽度**）、`barSideMargin` / `barBottomMargin`（默认随宽度 16/24/32vp 变化）、`gradientMask`（蒙层，浅色 `#CCF1F3F5` / 深色 `#99000000`，高度 = 页签栏高 + 16vp）、`lightColor`（光效）、`barOpacity`、`thermoCtrl`（温控）、`systemMaterialEffect`（材质）
- **迷你栏**（`HdsTabsMiniBar`，6.1.0(23)+）：可折叠 / 展开（`HdsBarStyle.COLLAPSE`/`EXPAND`）、自定义内容区、`barLayoutMode`（`HORIZONTAL`/`VERTICAL`，6.1.1(24)+），且与页签栏同时展开时按宽度走不同的居中规则
- 分档宽度是**三档** `smallWidth`（<440vp）/ `mediumWidth`（440–600vp，或 600–840vp 且高宽比 <0.8）/ `largeWidth`（>840vp，或 600–840vp 且高宽比 >0.8）；页签数 ≤3 时宽度 = `76vp×n+8vp`（≥600vp 时 `80vp×n+8vp`），≥4 时上限 328vp
- 控制器能力：`bindScroller(index, scroller, parentScroller?)` 把页签与内容区滚动联动；`applyMiniBarStyle` / `applyHideAnimation` / `applyShowAnimation`

现有 `OhosNavigationBar` 只有 `tile` / `float` 两型 + 光感，**没有迷你栏、没有分档宽度、没有蒙层、没有跟随手势折叠**。矩阵里那两行要降级。

### 其余 HDS 文档带来的修正

| 组件 | 上一版判断 | 文档实际 |
| --- | --- | --- |
| 即时操作 `HdsSnackBar` | 「无文档，布局细节按设计页」 | 有文档。`operationType` 是 **5 值**枚举：`TEXT_ONLY` / `CLOSE_BUTTON_ONLY` / `TEXT_WITH_ARROW` / `TEXT_WITH_CLOSE` / `HIGHLIGHT_TEXT_WITH_CLOSE`；`duration` 默认 **5000ms**、**≤0 表示常驻**；`isHeightAdaptive`（6.1.0+）默认 false；图标有 `SMALL`/`NORMAL` 两型；还有键盘起落避让高度 `keyboardUpAvoidHeight`/`keyboardDownAvoidHeight` |
| 色彩选择器 `HdsColorPicker` | 「无文档」 | 有文档（26.0.0+）。`tabs` 默认**三个全开** `[GRID, SPECTRUM, SLIDERS]`；`circleRadius` 默认 12vp、**小于 10 一律取 10**；收藏**上限 72 个**；`initialFavoriteColors` 是 `@Once`（只在首帧生效）。**注意：文档里没有「不透明度」「屏幕取色」「色值输入」三项** —— 矩阵里那三行依据是设计规范，与组件能力不是一回事，要分开记 |
| 列表项 `HdsListItem` / `HdsListItemCard` | 未考察 | `HdsListItem` 管横滑动效（`deleteTriggerType` / `fullDeleteOptions` / `onStateChange`），`HdsListItemCard` 管卡片内容（A 区 `prefixItem` / B 区 `textItem` / C 区 `suffixItem`）。**`suffixItem` 有 17 种预设**：文本 / 图片 / LoadingProgress / Radio / Checkbox / Switch / Arrow / Badge / Button / Icon / SubIcon / Select / ToggleButton / BadgeAndArrow / TextAndArrow / ArrowIconText / CustomBuilder；**`prefixItem` 有 7 种**（Image / Icon / Badge / Switch / ToggleButton / Button / CustomBuilder）。**这两个数照 `^## Suffix` / `^## Prefix` 逐条清点得出（21 / 10 条，扣掉基类与 `*Options` / `*Type` 类型定义），不是照章节标题数** —— 本行早前写的「19 种 / 8 种」正是把类型定义当成了形态。现有 `OhosListItem` 只有 `OhosSwipeAction` + `fullDelete`，`OhosListItemCard` 已补 |
| 标题栏 `HdsNavigation` | 只有 `Navigation` 的 Title | `titleMode` 是 **4 值**：`FREE`（滚动缩小）/ `FULL`（大标题，单标题 112vp、带副标题 138vp）/ `MINI`（56vp）/ `MODAL`（半模态，6.0.0+）；另有 `scrollEffectOpts`（`ScrollEffectType` 多档模糊 + `originalStyle`/`scrollEffectStyle` 两套样式线性过渡）、`systemMaterialEffect`、`bottomBuilder`、`subIcon`、`divider`（`OFF`/`ON`/`AUTO` 三态）。现有 `OhosAppBar` 有 `scrollEffect` 但**没有 FREE 模式的标题缩放**，也没有 MODAL 模式 |

同类（**唯一**确实无参考文档）：`EditableTitleBar`（标题栏可编辑形态）。

### 排查过程中又补上的 4 份文档（此前从未抓过）

用「概览页 42 个链接 → 各自设计文档末尾『## 开发文档』」跑出权威清单后，与仓库已有文档做**差集**，才暴露出下面 4 份。它们不在最早的抓取表里 —— 其中 `ChipGroup` 尤其要紧：原抓取表用的是 `ohos-arkui-advanced-Chip`（**单个 Chip**），等于**子页签的官方参考文档从来没被抓过**，而矩阵里「子页签 胶囊型」一直标着 `●`。

| 文档 | 组件 | 关键规格 |
| --- | --- | --- |
| `ohos-arkui-advanced-ChipGroup` | 子页签（胶囊） | `selectedIndexes` 默认 **`[0]`**（`multiple=true` 也默认选第 0 个；`multiple=false` 时传多个也只取第一个）；`chipGroupSpace` 默认 `{itemSpace:8, startSpace:16, endSpace:16}`；`chipGroupPadding` 默认 `{top:14, bottom:14}`；`allowClose` 默认 false，且 `suffixSymbol` / `suffixImageIcon` 任一存在时**失效**（优先级 `suffixSymbol` > `suffixImageIcon` > `allowClose`） |
| `ts-universal-attributes-sheet-transition` | 半模态面板 | `SheetType` 是 **5 值**（`BOTTOM`/`CENTER`/`POPUP`/`SIDE`/`CONTENT_COVER`），且**按窗口宽度自动选型**：<600vp 默认 `BOTTOM`、600–840 默认 `CENTER`、≥840 默认 `POPUP`。`preferType` 支持的取值也随宽度变（<600vp 只支持底部/全屏，够不到居中/跟手/侧边）；CENTER/POPUP 最小 320vp、最大窗口短边 90%，且 `LARGE`/`MEDIUM` 在这两型下无效（恒 560vp）；`detents` 最多 3 挡，生效时 `height` 失效、控制条自动出现 |
| `ts-methods-custom-dialog-box` | 弹出框（自绘内容） | 见阶段 D |
| `arkts-apis-uicontext-promptaction` | 即时反馈（Toast/弹窗入口） | Toast 挂在 `UIContext` 上，不是独立组件 —— 这解释了为什么在开源仓库里找不到「Toast 组件」 |

**半模态面板的 `●` 是这一轮改掉的最没有依据的一个。** 现有 `showOhosBottomSheet`（133 行）只做了 `BOTTOM` 一种形态，控制条还是**无条件**画的 —— 官方只在多挡位 `detents` 生效时才默认显示控制条。矩阵因此从「1 行 `●`」拆成「7 行，1 完整 6 缺失」。

### 1.4 第四层：实现源码里的真实数值

文档给的是**令牌名**，源码给的是**数值**。这一层是本轮新增的，收获分两类：

**(a) 拿到了一直拿不到的尺寸。** 以子标题 `SubHeader` 为例，源码里带一张 `RESOURCE_CACHE_MAP`，把令牌 → 真实值直接写出来（28 条）：

| 令牌 | 值 | 含义 |
| --- | --- | --- |
| `subheader_single_title_height` | **56** | 单标题行高 |
| `subheader_single_subtitle_height` | **56** | 单副标题行高 |
| `subheader_double_height` | **72** | 主副标题双行 |
| `subheader_title_font_size` | 18 | 标题字号 |
| `Subtitle_S` | 14 | 副标题字号（权重 400） |
| `subheader_titles_space` | 2 | 主副标题间距 |
| `subheader_left_icon_size` | 16 | 左图标 |
| `subheader_left_icon_end_margin` | 8 | 图标与文字间距 |
| `subheader_content_margin_start` / `_end` | 16 / 16 | 左右边距 |
| `subheader_content_padding` | 8 | 内容 padding |
| `padding_level1..8` | 2 / 4 / 6 / 8 / 12 / 16 | 通用间距阶梯 |

对完本库 `OhosSubheader`（当时在 `ohos_text.dart:118`）：**没有高度概念**，只有一个 `padding: (16,16,16,8)`，行高全靠字阶撑 —— 与官方 56 / 72 对不上；也没有副标题行、没有左图标。矩阵由 3 行扩到 8 行，当时仅 1 行 `◐`。**（本轮已全部补齐，见阶段 D 第 5 项；现为 6 行完整 + 1 行 `◐`。）**

**(b) 推翻一条「已确认无文档」的结论。** `editabletitlebar.ets` **存在，958 行**，规格完整：

```
DEFAULT_TITLE_BAR_HEIGHT = 56      TITLE 20vp   SUBTITLE 14vp
MAX_MAIN_TITLE_PERCENT   = 0.65    IMAGE_SIZE  64vp
MAX_SUB_TITLE_PERCENT    = 0.35    MAX_DIALOG  256vp / MIN_DIALOG 216vp
SYMBOL_SIZE = 24vp                 SYMBOL_TITLE_SIZE 64vp
```

也就是说，「`EditableTitleBar` 确实无文档」只在**参考文档**范围内成立 —— 三个 slug 变体全 404 是真的，`HdsNavigation` 里没有对应章节也是真的。但**把「文档没有」当成「没有规格」是错的**，这条和 §0.2 那个「闭源 ⇒ 无文档」是同一个错误模式，只是这次跨了一层（从文档层跨到源码层）。矩阵里那一行已改为「源码有，文档无」，并把 56 / 20 / 14 / 0.65 / 0.35 记进备注。

**(c) 令牌的真实数值：`float.json` 拿到了，`Search` 不再有缺口。**

上一版这段写的是「`Search` 这类系统组件的圆角/高度，本轮仍拿不到确切数值」，并判断只能去逆向 RestoolV2 二进制 —— **这个判断是错的，而且和 §0.2 是同一个错误模式：没找到就说没有。**

`resources.index` 确实是二进制的，但它不神秘：它是 `global_system_resources` 仓库里 `element/*.json` 的**编译产物**。直接读源文件即可，三个文件缺一不可：

```
systemres/main/resources/base/element/pattern.json    67 条   组件主题模式（ohos_search_pattern 等）
systemres/main/resources/base/element/float.json    1080 条  基础设计令牌（ohos_id_* / padding_levelN / 字阶）
systemres/main/resources/base/element/float_sys.json  507 条  组件级令牌（chip_* / search_* / subheader_*）
```

> 上一版这三行记的是**行数**（9701 / 4112 / 1816），2026-11 同步后变成 10208 / 4324 / 2032。改记条目数：行数随上游格式化漂移（缩进与空行改动就会让 `float_sys.json` 虚涨 12%），条目数才是有效基准。

**关于两张 float 表：键不重复，合起来才构成 `sys.float` 命名空间，不是「索引 + 内容」的关系。** 上一版我把 `float_sys` 一律当成别名表、`float` 一律当真实值，这个理解是错的 —— `chip_normal_height` 在 `float_sys.json` 里直接就是 `36.0vp`，压根不在 `float.json` 里；而 `subheader_single_title_height` 反过来只在 `float.json` 里。**解析器必须两张表都查**，不能规定哪张只能当跳板。

**解析要三步**：`search_theme.h` 里的键（如 `search_default_height`）先查 `ohos_search_pattern`，得到 `$float:search_default_height`；再查 `float_sys.json` 得到 `$float:ohos_id_search_default_height`；最后查 `float.json` 得到 `40.0vp`。只在 pattern 层做一次跳转，之后不要在 pattern 里回查（同名键会自引用成环）。

`Search` 的完整规格（`search_theme.h` 逐个 `GetAttr` 的键，全部走通）：

| 令牌 | 值 | 含义 |
| --- | --- | --- |
| `search_text_field_border_radius` | **20** | 圆角 |
| `search_default_height` | **40** | 默认高度 |
| `search_height` | **56 ——（死令牌）** 见下 | 「带搜索按钮时的整栏高」这个说法不成立 |
| `search_icon_size` / `search_icon_height` | **16 / 16** | 放大镜图标 |
| `search_icon_left_space` / `_right_space` | **12 / 8** | 图标左距 / 图标与文字间距 |
| `search_close_icon_size` | 16 | 清除按钮图标 |
| `search_close_icon_hot_zone_horizontal` | **40** | 清除按钮命中区（**比图标大得多**） |
| `search_text_field_padding_left` | 4 | **（死令牌）** 见下方纠正 |
| `search_text_field_right_padding_without_button` | 12 | 无按钮时右边距（源码兜底值也是 `12.0_vp`，两者一致） |
| `search_text_field_right_padding_with_button` | 0 | 有按钮时右边距 |
| `search_button_space` | 2 | 按钮与文字间距 |
| `search_divider_side_space` | 2 | 分隔线两侧留白 |
| `search_button_text_padding` | 14 | 搜索按钮文字 padding |
| `search_border_width` | **0** | 默认无描边 |
| `search_focus_padding` | 1 | 聚焦光边厚度 |
| `search_cancel_button_style` | 2 | 取消按钮样式档 |

> **纠正（第二次读源码时发现）：`search_text_field_padding_left = 4` 是死令牌，上一版据此判的「左内边距多 8」是错的。**
>
> 上一版只读了 `search_theme.h`，看到 `theme->leftPadding_ = pattern->GetAttr("search_text_field_padding_left", 0.0_vp)` 就认定它是输入区左内边距。再去查调用方：
> - `search_pattern.cpp`、`search_layout_algorithm.cpp`、`search_model_ng.cpp`、`search_text_field.cpp`、`search_pattern.h` / `search_layout_property.h` / `search_node.cpp` —— **`GetLeftPadding()` 零调用方**。整个 `search/` 目录只有 `search_theme.h` 自己定义并返回它。
> - 真正决定水平几何的是 `LayoutSearchIcon` / `LayoutTextField`（`search_layout_algorithm.cpp:738` / `:929`），用的全是 `search_icon_left_space`(12) 与 `search_icon_right_space`(8)：
>   ```
>   iconX  = padding.left + searchIconLeftSpace
>   fieldX = iconWidth + searchIconLeftSpace + searchIconRightSpace + padding.left
>   ```
>
> 顺带一提 `GetRightPaddingWithoutButton` / `WithButton` 是**有**调用方的（`:223` / `:227`），它们只在算 textField 可用宽度时用，也不是盒内 padding。`leftPadding_` 应是旧框架 `frameworks/core/components/search` 的遗留字段。
>
> **教训与 §七 那几条同类**：`GetAttr` 只能证明「令牌被读进了一个字段」，不能证明「那个字段被用了」。判「官方值是什么」必须再往下追一层调用方。

> **第二处死令牌：`search_height` = 56。** 上一版把它写成「带搜索按钮时的整栏高」，并据此在阶段 D-10 排了「补右侧搜索按钮形态 —— 整栏高 56」。这次为落地那一条去核实时发现：
>
> - `search_height` 在 **13 个 `search/` 源文件里一次都没出现**（`grep -rn search_height ok_*` 零命中）。
> - `SearchTheme::height_` 只有**一个**赋值来源：`search_theme.h:65` 的 `search_default_height`（= 40）。`GetHeight()` 的 5 个调用点（`:134` `:324` `:328` `:452` `:561`）读的全是它。
> - `search_height` 确实存在于 `ohos_search_pattern`，值是 `$float:ohos_id_search_height` → `56.0vp`。**它被定义、被编译进 `resources.index`，但没人读。**
> - 官方 30 个 `Search` 示例里，凡是配了 `.searchButton('SEARCH')` 的（示例 1、2、21 附近共 3 处）**全都写 `.height(40)`**，没有一处写 56。
>
> 所以「整栏 56」不成立。本库 `OhosSearchBar` 的高度保持 **40**，右侧搜索按钮形态按 40 落地。
>
> 两次死令牌（`search_text_field_padding_left`、`search_height`）的共同点值得记：它们都在 pattern 表里有值、都能被 `GetAttr` 读进字段，**唯一缺的是调用方**。第 8 条教训说「再追一层调用方」，这条是它的第一次复用 —— 而且是在动手写代码之前就拦住的，不是写完再回头改。

**与 `OhosSearchBar`（`lib/src/widgets/ohos_search_bar.dart`）逐项对账：**

| 项 | 官方 | 本库（本轮已对齐） | 结论 |
| --- | --- | --- | --- |
| 高度 | 40 | `height = 40` | ✓ |
| 圆角 | 20 | `OhosGeometry.radiusSearch = 20` | ✓ **本轮改**：原 `radiusCapsule = 999`，数值上被钳到 `height/2` 恰好也是 20，但语义不同 —— 高度改 48 就变 24。已改为显式 20 |
| 左侧留白 | `search_icon_left_space` = **12** | `EdgeInsets.only(left: 12)` | ✓ **上一版误判为 ✗**，见上方纠正 |
| 放大镜图标 | 16 | `size: 16` | ✓ **本轮改**：原 18 |
| 图标与文字间距 | 8 | `SizedBox(width: 8)` | ✓ |
| 清除按钮图标 | 16 | `size: 16` | ✓ |
| 清除按钮命中区 | **40** | `OhosIconButton(size: 40)` | ✓ **本轮改**：原 32，真机偏窄 |
| 默认描边 | 0 | `usesOutlines` 时补 1px | 有意偏离（墨水屏无填充色可用） |

**右侧搜索按钮形态（本轮已落地）。** 相关令牌全部走通，除 `search_height` 那条死令牌：

| 令牌 | 官方 | 本库 | 说明 |
| --- | --- | --- | --- |
| `search_button_space` → `padding_level1` | **2** | `SizedBox(width: 2)` ×2 + 右侧 padding 2 | 分隔线两侧各 2，按钮到右边界 2 |
| `search_divider_side_space` → `padding_level1` | **2** | 同上（与 `search_button_space` 同值，但语义不同） | `LayoutDivider` 用它算偏移 |
| `search_divider_width` | **1 px**（源码常量 `1.0_px`，非令牌） | `VerticalDivider(width: 1)` | 高度 `min(searchHeight, search_icon_height)` = 16 |
| `search_button_text_padding` → `padding_level7` | **14** | `EdgeInsets.symmetric(horizontal: 14)` | 仅左右，不含上下 |
| `search_font_size_API16` → `Body_M` | **14fp** | `TextStyle(fontSize: 14)` | 文档兜底写的 16fp 是 `SearchButtonOptions` 的默认值，不是 theme 实际取的 |
| 按钮高 | `height - 2×searchButtonSpace` = **36** | `fixedSize: Size.fromHeight(height - 4)` | 源码 `std::min(defaultButtonHeight, searchHeight_)` |
| `search_height` | 56 —— **死令牌** | 不采用，栏高仍 40 | 见上方纠正 |

按钮顺序是「清除 | 2 | 分隔线 | 2 | 按钮 | 2」——**清除按钮落在分隔线左侧**，不是与按钮并排，这是 `LayoutCancelButton` 里 `cancelX = buttonX - cancelW - 2*dividerSpace - dividerW` 的直译。

`chip` 同类令牌 —— **本轮已全部对齐**，数值集中到 `lib/src/theme/ohos_chip_metrics.dart`：

| 令牌 | 官方 | 本轮前 | 本轮后 |
| --- | --- | --- | --- |
| `chip_normal_height` / `chip_activated_normal_height` | **36vp** | 32 | ✓ 36 |
| `chip_small_height` / `chip_activated_small_height` | **28 lpx**（全表仅此两处用 `lpx`，不是 vp；默认配置下数值等同 vp，但不随字体缩放） | 24 | ✓ 28 |
| `chip_normal_radius` / `chip_border_radius_normal` | **18** | `_height/2 = 16` | ✓ 18（显式，不再折半） |
| `chip_small_radius` / `chip_border_radius_small` | **14** | `_height/2 = 12` | ✓ 14 |
| `chip_normal_text_padding` / `chip_small_text_padding` | **16 / 12** | 16 / 12 | ✓ 本来就对 |
| `chip_normal_text_margin` / `chip_small_text_margin` | 6 / 4 | 4 / 2 | ✓ 6 / 4 |
| `chip_normal_font_size` / `chip_small_font_size` | **14fp**（均指向 `ohos_id_text_size_button2`） | `labelSmall = 12` | ✓ 14 |
| `chip_border_width` | **0** | 未选中态画了描边 | 有意偏离（墨水屏需要） |
| `chip_normal_icon_size` / `chip_small_icon_size` | **16 / 16** | 16 / 14 | ✓ 16 / 16 |
| `chip_text_font_weight` / `chip_activated_text_font_weight` | 400 / **500** | 400 / 600 | ✓ 已改为 500 |

**为什么集中在 `OhosChipMetrics` 而不是各自改一行**：`OhosChip` 与 `OhosChipGroup` 是两份独立实现，0.5.0 修描边时就撞过一次。这次尺寸漂移是同一个根因的第二次发作 —— chip 靠 `padding: vertical 7` + 14fp×1.4 撑到 33.6（比官方矮 2.4，且字阶一改高度就漂），group 写死 32，两者还不相等。现在两边都读同一个类，`OhosChipGroupSize` 也改成了 `OhosChipSize` 的 `typedef`。

> 关于 `chipgroup.ets:63` 的 `enum ChipGroupHeight { NORMAL = 36, SMALL = 28 }`：早前先被误判为「芯片高度直接差异」、随后又自我否定（说它只用于后缀渐变 Stack）—— **两次都不对，但第二次更接近**。它确实只被 `:633` 的渐变遮罩 `.height()` 用到；芯片高度来自 `chip.ets` 的 `chipNode.normalHeight = $r('sys.float.chip_normal_height')`。两者都是 36/28 是**设计上的一致**，不是同一条来源。错在把孤证当结论、又没去查令牌表。

**关闭按钮与后缀图标（本轮已落地）。** `allowClose` 的默认值在两个组件里**不一样**，这是最容易被「合并成一份实现」抹掉的一条：

| 来源 | 默认值 | 位置 |
| --- | --- | --- |
| 独立 `Chip` | `true` —— `isClosable()` 是 `allowClose ?? true` | `chip.ets:747` |
| `ChipGroup` 内的项 | `false` —— 传的是 `chipItem.allowClose ?? false` | `chipgroup.ets:580` |

本库 `OhosChip` 与 `OhosChipItem` 都取 **false**（有意偏离独立 Chip 那一档）。理由是这个 Chip 同时服务两个场景：跟随 `true` 会让所有既有芯片在升级后凭空长出一个 ×，而 `onClose` 为 null 时那个 × 点了没反应 —— 比「不画」更糟的失败方式，和 §一 里 `primaryLabel` 空药丸是同一类。已写进两处 `dartdoc`。

优先级链（`suffixSymbol > suffixImageIcon > allowClose`）在 Flutter 侧落成 `suffixIcon > allowClose`：给了 `suffixIcon` 就不画内置 ×，而不是两个并排。间距复用 `chip_normal_text_margin`(=6) / `chip_small_text_margin`(=4)，与左图标同一个 `metrics.iconGap` —— `getLabelMargin()` 的 `end` 分支对 `hasSuffix()` 与 `isNeedShowCloseIconMargin()` 用的是同一个 `defaultLocalizedMargin.end`。

**有一处没有照搬**：`chip.ets` 的关闭按钮 `padding(0)` + `stateEffect(false)`，命中区就是图标本身（16×16），没有 `hot_zone` 令牌可查。所以本库不另拟一个更大的数字；需要大命中区时传 `suffixIcon` 自带一块按钮。

**前图标双态（本轮已落地）。** `ChipSymbolGlyphOptions` 是 `{normal?, activated?}` 两个 `SymbolGlyphModifier` —— **两态是两个图形，不是同一图形换色**：

```ts
// chip.ets:838
getPrefixSymbolModifier(): SymbolGlyphModifier | undefined {
  if (this.isChipActivated()) { return this.prefixSymbol?.activated; }
  return this.prefixSymbol?.normal;
}
```

本库新增 `OhosChip.selectedIcon` / `OhosChipItem.selectedIcon`。

**一处有意偏离**：同一文件的 `hasPrefix()`（`:1014`）写的是 `isChipActivated() ? !!activated : !!normal` —— 只给了 `normal` 时，选中态**连图标和间距一起消失**。在 ArkUI 里那是「调用方声明了双态但少给一半」的边界，照搬到 Flutter 侧就变成「只传 `icon` 的既有用法被点一下掉图标」，是缺陷而不是语义。本库改为「选中态优先 `selectedIcon`，缺省回落 `icon`」，并补用例钉住。

**子页签的三段间距与默认选中（本轮已落地）。** `chipgroup.ets:46` 起是 `chipGroupSpace: { itemSpace: 8, startSpace: 16, endSpace: 16 }`、`chipGroupPadding: { top: 14, bottom: 14 }`：

| 参数 | 官方默认 | 本库 | 落法 |
| --- | --- | --- | --- |
| `itemSpace` | 8 | `spacing` = 8 | Row 的 gap（本来就对） |
| `startSpace` | 16 | `startSpace` = 16 | `Padding(left:)` |
| `endSpace` | 16 | `endSpace` = 16 | `Padding(right:)` |
| `chipGroupPadding` | top/bottom 14 | `padding` = `EdgeInsets.symmetric(vertical: 14)` | 只取纵向；整组高 36 + 28 = 64 |
| `selectedIndexes` | `[0]`（`multiple` 时同样） | `selectedIndex` = 0 | 走 `_resolvedIndexes`，越界/负数按 `getSelectedIndexes()` 丢弃 |

> **横向 padding 刻意不生效。** 若 `padding` 的左右也一起用，首端会变成 `startSpace 16 + padding 16 = 32`：`chipgroup.ets:615` 的 Row 只给了 `left`/`right` 两个方向，上下另由 Stack 的 `chipGroupPadding` 负责，两者本来就是分开的两层。

> **`OhosTabBar` 的胶囊模式必须归零。** 页签是「条」不是「一坨独立芯片」，两端和内边距已由 TabBar 自己的 16 水平 padding + 固定 48 高表达。沿用组内边距会双重计算：水平 16+16=32、纵向 14+14 把 36 高的芯片压进 48 的栏里只剩 20 —— 芯片被裁掉一半，点击落在裁剪区外。落地时 `capsule tab bar switches pages` 用例当场变红，这是「同一个值别在两个组件里各管一遍」的**第三次**（前两次：描边、尺寸）。

> **顺带修掉一个一直存在的缺陷**：`_scrollableStrip` 的 `Align(centerLeft)` 没有 `heightFactor`，在松高度约束下取 `constraints.maxHeight` —— 一排芯片躺在页面里就撑成整屏 600 高的空白块。是新写的「整组高 64」用例把它逼出来的（断言 `group.height` 拿到 600）。

**`autoDisable`（本轮已落地）。** `SearchButtonOptions.autoDisable`（API 18+）：官方文档写「Search 无文本内容时按钮置灰且不可点击。**默认值：false**」。本库照文档取 `false`，不照「更友好的直觉」—— 官方把选择权留给应用，打开时空内容也能点，与 0.5.x 行为一致。置灰取 `textTertiaryColor`：彩屏上从品牌蓝降一档、墨屏上是 `#767676` 中灰，都落在「字还在、但点不动」的区间，没有引入新色值。

**`SubHeader` 交叉验证。** `float.json` 里 `subheader_single_title_height = 56vp`、`subheader_single_subtitle_height = 56vp`、`subheader_double_height = 72vp`、`subheader_title_font_size = 18fp`、`subheader_titles_space → padding_level1 = 2vp`、`subheader_left_icon_size = 16vp`、`subheader_content_margin_start/_end → margin_left/_right = 16vp`、`subheader_content_padding → padding_level4 = 8vp`、`Subtitle_S = 14fp` —— **与 `subheader.ets` 的 `RESOURCE_CACHE_MAP` 逐个吻合**。两条独立链路互证，说明这条解析路径可靠。

---

## 二、逐组件对照结果

图例：`●` 完整 / `◐` 部分形态 / `○` 缺失 / `—` 无需实现

### 导航类

| 控件 | 参考文档 | 官方形态 | 现状 | 缺口 |
| --- | --- | --- | --- | --- |
| 底部页签 | `HdsTabs` | 平铺 / 悬浮 / **迷你栏 / 分档宽度 / 蒙层** | 完整 | 迷你栏、三档宽度、`gradientMask`、控制器折叠动效（`applyMiniBarStyle` / `applyHideAnimation` / `applyShowAnimation`）与 `bindScroller` 滚动联动均已落地（`OhosFloatingTabBar` + `OhosMiniBar` + `OhosTabsController`）；`bindScroller` 的 `parentScroller` 只登记不参与计算（Flutter 无等价父子层级） |
| 子页签 | `Tabs` 的 `SubTabBarStyle` + **`ChipGroup`** | 文本 / 胶囊（含 `allowClose`、后缀图标、三段间距、默认选中） | 完整 | `chipGroupSpace` 三段（`spacing` 8 / `startSpace` 16 / `endSpace` 16）、`chipGroupPadding`（14/14，整组高 64）、`allowClose` + `suffixIcon` + `onClose`、`selectedIndexes` 默认 `[0]` 全部落地；`OhosTabBar` 胶囊模式显式归零组内边距（两端已由自己的 16 + 48 高表达）。见 §1.4(c) |
| 标题栏 | `HdsNavigation` | `FREE`（滚动缩小）/ `FULL`（112/138vp）/ `MINI`（56vp）/ **`MODAL`** | ◐ | 缺 FREE 的标题缩放与 MODAL 半模态；缺 `bottomBuilder` / `subIcon`；缺可编辑形态（`EditableTitleBar` **文档缺失但源码存在**，见 §1.4） |
| 导航点 | `Swiper` 的 `Indicator` | 圆点 / 数字 / 箭头 | 完整 | 超长显示、蒙版、任意定位仍缺，已单列 `○` |

> `Swiper` 参考文档给了 `DotIndicator` / `DigitIndicator` / `ArrowStyle` 三套 indicator 配置，现有只有圆点。

### 展示类

| 控件 | 参考文档 | 官方形态 | 现状 | 缺口 |
| --- | --- | --- | --- | --- |
| 文本 | `Text` | 单行 / 多行 / 跑马灯 | ◐ | 缺 `TextMarqueeOptions`（跑马灯），29 个示例只覆盖了 overflow |
| 分隔器 | `Divider` | 横 / 竖，`lineCap` | ● | — |
| 子标题 | `SubHeader` | **列表型 / 内容型** | ◐ | 形态、尺寸、字阶已齐（两种形态 + 高度三档 56/56/72 全部落地，含副标题、左图标、边距）。**仍缺的只有右侧操作区**：官方 `operationType` 四值中 `ICON_GROUP`（≤3 图标）、`LOADING` 未做，`select` 下拉未做 —— 已实现的只有 `TEXT_ARROW`/`BUTTON` 单条文本 |
| 进度条 | `Progress` + `LoadingProgress` | **Linear / Ring / Eclipse / ScaleRing / Capsule** | ◐ | 缺 `Eclipse`（月相）、`ScaleRing`（带刻度）、`Capsule`（头尾弧形）；全缺 `LoadingProgress` |
| 索引条 | `AlphabetIndexer` | 弹出 / 折叠 | ● | — |
| 滚动条 | `ScrollBar` | 有子节点 / 无子节点 / 嵌套 | ● | — |
| 新事件标记 | `Badge` | 数字 / 字符串 / 圆点 | ● | — |
| 即时反馈 | `PromptAction`（toast） | — | ● | — |
| 即时操作 | `HdsSnackBar` | **5 种右侧操作区** / 定时或常驻 | ◐ | 只有「文本按钮 / 关闭按钮」两态，缺 `TEXT_WITH_ARROW` / `TEXT_WITH_CLOSE` / `HIGHLIGHT_TEXT_WITH_CLOSE`；缺 `duration` 默认 5000ms 与 ≤0 常驻语义；缺 `isHeightAdaptive` 与键盘避让 |
| 气泡提示 | `bindPopup` | 气泡 / **CustomPopup** | ● | — |
| 数据可视化 | `DataPanel` + `Gauge` | **进度形 / 占比形 / 范围形 / 线形** | ○ | 见第三节 |
| 二维码 | `QRCode` | — | ● | — |
| 文本时钟 | `TextClock` | — | ● | — |
| 图片 | `Image` | — | ● | — |
| 空白 | `Blank` | — | ● | — |

### 操作类

| 控件 | 参考文档 | 官方形态 | 现状 | 缺口 |
| --- | --- | --- | --- | --- |
| 按钮 | `Button` | 胶囊 / 圆角 / 圆形 × 5 风格 × 3 尺寸 | ● | — |
| 下拉按钮 | `Select` | — | ● | — |
| 状态按钮 | `Toggle` | 开关 / **勾选** / **按钮** | ● | — |
| 操作块 | `Chip` | 基础 / **可关闭（allowClose）** / 尺寸 NORMAL·SMALL / **前图标双态** | 完整 | 尺寸与两种形态均已对齐：36/28 高、18/14 圆角、14fp、图标 16/16、间距 6/4（集中在 `OhosChipMetrics`）；`allowClose` + `onClose` + `suffixIcon`，优先级链 `suffixIcon > allowClose`；`selectedIcon` 双态（`prefixSymbol` 的 normal/activated），只给 `icon` 时选中态回落 —— 有意偏离 `hasPrefix()` 的「选中即消失」 |
| 工具栏 | `ToolBar` | 图标 + 文本 / `ItemState` 三值 / 激活 / 几何 / 收纳 | 完整 | 官方只有「图标 + 文本」一种形态，无分组能力；`selected` → `state` 为破坏性变更 |
| 核心操作栏 | `HdsActionBar` | 默认 / 去主按钮 / 竖直 / 自定义主按钮 / 逐按钮配置 | ◐ | 见第一节 |
| 菜单 | `Menu` | 列表 / **宫格** / 子菜单 | ● | — |
| 文本选择菜单 | `SelectionMenu` | 一级 / **更多二级** | ○ | 见第三节 |

### 输入类

| 控件 | 参考文档 | 官方形态 | 现状 | 缺口 |
| --- | --- | --- | --- | --- |
| 文本框 | `TextInput` | 默认 / **下划线** / **内联** / 密码 / 多行 | ◐ | 缺内联模式（`TextContentStyle`）；密码模式；字数计数器 `showCounter` |
| 搜索框 | `Search` | 取消按钮 / 清除按钮 / **右侧搜索按钮** | 完整 | 五个形态全部有：默认 / 清除 / 取消 / 右侧搜索按钮 / `autoDisable`。尺寸全部对齐：高度 40 ✓、圆角 20 ✓、放大镜 16 ✓、左距 12 ✓、文字间距 8 ✓、清除图标 16 ✓、命中区 40 ✓、按钮间距 2 ✓、分隔线两侧 2 ✓、按钮文字 padding 14 ✓、按钮高 36 ✓。`autoDisable`（18+）默认 `false` 照官方文档。见 §1.4(c) |
| 数字加减 | `advanced.Counter` + `Counter` | 数字 / **日期（`INLINE_DATE`）** / 列表型 / 紧凑型 / 数字内联型 | ◐ | **日期形态已完整**（`OhosDateCounter`，几何取自 `COUNTER_INLINE_*`，三种回绕各有实现与用例）。仍缺：`LIST` / `COMPACT` / `INLINE` 三种形态（现有 `OhosCounter` 是自拟的数字步进器，不属于这三者中任何一个）、长按连续加减 |
| 图案锁 | `PatternLock` | — | ● | — |

### 选择类

| 控件 | 参考文档 | 官方形态 | 现状 | 缺口 |
| --- | --- | --- | --- | --- |
| 勾选 | `Checkbox` + `CheckboxGroup` | 单个 / **全选组** | ◐ | 缺 `CheckboxGroup`（全选/半选/反选） |
| 开关 | `Toggle` | — | ● | — |
| 单选框 | `Radio` | 圆形 / **自定义 indicator** | ◐ | 缺 `RadioIndicatorType` |
| 评分条 | `Rating` | 整星 / 半星 / 自定义 | ● | — |
| 滑动条 | `Slider` | OutSet / InSet / **NONE（无滑块）** | ◐ | 缺 `NONE` 形态；缺 `showSteps` 刻度；缺 `prefix`/`suffix`；**无**双值（见第〇节） |
| 选择器 | `UIPickerComponent` + `CalendarPicker` | 滚轮 / 时间日期 / **月历** | ◐ | 缺滚轮（多维、循环、5/7 行）、缺时间日期、缺月历 |
| 色彩选择器 | `HdsColorPicker` + 设计规范 | 网格 / 光谱 / 滑块 + 收藏（≤72）+ 设计规范另列的不透明度 / 屏幕取色 / 色值输入 | ◐ | 前四类有；后三项仅设计规范有要求、`HdsColorPicker` 未提供，需自行设计 |
| 分段按钮 | `SegmentButton` | **tab / capsule × 单选 / 多选** | ◐ | 缺 `type: tab`、缺 `multiply` 多选；**官方限定 2–5 个按钮**，现在无限个 |

### 容器类

| 控件 | 参考文档 | 官方形态 | 现状 | 缺口 |
| --- | --- | --- | --- | --- |
| 列表 | `List` / `ListItem` / `ListItemGroup` / **`HdsListItemCard`** | 平铺 / 分组卡片（CARD）/ 吸顶（StickyStyle）/ **A-B-C 三区列表项** | ◐ | `OhosListGroup` + `OhosListGroupSliver` 已落地（组头/组尾、`space`、`divider`、组卡片、项卡片、**吸顶组头**），`OhosListItemCard` 已落地（A 区 **7 种**形态收成 Widget 槽位、C 区 **17 种**中落地 9 种 + `custom`、三层文本、9 个卡片属性）；仍缺**吸底组尾**（技术原因见阶段 D-2，已标 `○`）、`headerStyle`/`footerStyle` 的 `FLOATING`（26.0.0+）、`List.lanes` 多列、卡片副 Symbol（8 个字段）、`hoverBorderRadius` |
| 弹出框 | `advanced.Dialog` | Tips / Select / Confirm / Alert / **Loading** / **CustomContent** | ◐ | 缺 Loading 与 CustomContent 两个预设 |
| 半模态面板 | `bindSheet` | **5 种形态**：BOTTOM / CENTER / POPUP / SIDE(20+) / CONTENT_COVER(20+)，外加多挡位 `detents` | 完整 | 五型全部落地（`ohos_sheet_type.dart` 规格层 + `ohos_bottom_sheet.dart` 渲染层）、`detents`（枚举与数值挡位混写、首挡初始、生效时 `height` 失效）、响应式 `preferType`、CENTER/POPUP 高度夹取（320vp 下限 / 短边 90% 上限）、按形态给控制条与描边。圆角由 24 修正为官方 32vp |

---

## 三、两个必须单独说的

### 3.1 数据可视化：语义完全不符（最高优先）

`OhosDataPanel` 现在是「本日健康数据」那种 KPI 卡片网格，官方四类**一个都不对应**。

参考文档给出的精确规格（`DataPanel`）：

- `values: number[]` —— **最多 9 段**，超过取前 9，小于 0 置 0
- `max` —— **>0 时为最大值；≤0 时等于数组各项之和、按比例显示**。默认 100
- `type` —— `Line`(0) / `Circle`(4)，**不支持动态修改**
- `strokeWidth` —— 默认 **24vp**，环类型专用；大于半径时自动改为半径的 12%
- `trackBackgroundColor` —— 默认 **`#08182431`**（ARGB，前两位是透明度）
- `valueColors` —— 纯色或 `LinearGradient`；**默认 9 段渐变，色值在文档里逐个写明**（`#F7CE00→#F99B11`、`#F76223→#F2400A`、`#F772AC→#E65392`、`#A575EB→#A12DF7`、`#7B79F7→#4B48F7`、`#4B8AF3→#007DFF`、`#73C1E6→#4FB4E3`、`#A5D61D→#69D14F`、`#A2A2B0→#8E8E93`）
- `trackShadow` —— 继承 `MultiShadowOptions`，`colors` 缺省等于 `valueColors`；>9 段截断、<9 段只画设定个数
- `closeEffect` —— 关掉旋转进场动效与投影

（`Gauge`）：

- `startAngle` 默认 **0**、`endAngle` 默认 **360**，0 点为 0 度、顺时针为正
- `strokeWidth` 默认 **4**
- `colors` —— 单色 / `LinearGradient` / `Array<[color, weight]>` 分段；**最多 9 段**；非法色值回退 `0xFFE84026`；比重为 0 则该段不显示；**全部为 0 则整环不显示**
- `indicator` —— 传 null 不显示指针
- `description` —— 自定义说明内容；**不设则看是否设了 min/max：设了就显示最大最小值，没设就不显示**

`DataPanel` 的 4 个示例分别演示：环形与线形、渐变与投影、关闭动效与投影、自定义内容区。

因此规划：新增 `OhosGauge`；`OhosDataPanel` 按上述语义**重写**；旧 KPI 卡片能力迁到 `OhosStatGrid`（并给迁移表）。

### 3.2 文本选择菜单：唯一完全缺失

`SelectionMenu` 参考文档给了 `SelectionMenuOptions` / `EditorMenuOptions` / `ExpandedMenuOptions` 三层结构，设计规范给了固定的动作顺序：剪切 → 复制 → 粘贴 → 全选 → 翻译 → 分享 → 搜索 → 其他；**前四项不进「更多」，三方扩展全部进「更多」**。

现状：`lib/` 全库无 `selectable` / `selectionControls` / `contextMenuBuilder` / `TextSelection` 任何引用，`OhosTextField` 填的是 Material 默认菜单。

---

## 四、实施顺序

### 阶段 0：先补「对照矩阵」作为回归基线

在 `doc/` 下建一张机器可校验的对照表（组件 → 参考文档 → 官方形态 → 本库实现 → 测试名），让「42 控件全覆盖」这句话以后能被脚本验证，而不是靠人记。这一步先做，后面每补一个形态就勾掉一行。

### 阶段 A：数据可视化（最大、最独立、语义错了必须先改）

1. `ohos_gauge.dart` —— 按 `Gauge` 参考文档：角度语义、分段色（≤9）、比重为 0 不显示、`indicator` 可关、`description` 按 min/max 有无决定。先做它，环形弧段绘制可被 `DataPanel` 复用。
2. `ohos_data_panel.dart` —— 按 `DataPanel` 参考文档：`Line`/`Circle`、`values`≤9、`max` 两段语义、`strokeWidth` 默认 24、`trackBackgroundColor` 默认 `#08182431`、9 段官方默认渐变、`trackShadow`、`closeEffect`。
3. `ohos_stat_grid.dart` —— 承接旧 KPI 卡片，保留原视觉。
4. 示例：展示类改成四类并排（进度 / 占比 / 范围 / 线形），按参考文档的 4 个示例各做一个对照。

### 阶段 B：文本选择菜单

1. `OhosSelectionMenuAction` + `OhosSelectionToolbar`（走 `OhosLightMaterial`）。
2. `OhosTextField` / `OhosSearchBar` 接 `contextMenuBuilder`。
3. 内置四项固定顺序 + 「更多」二级菜单（复用 `showOhosMenu`）。
4. 墨水屏退化：无模糊、1px 实线、无进场动效。

### 阶段 C：选择类补齐（按改动面从小到大）

1. `OhosSegmentedButton` —— 加 `type`（`tab`/`capsule`）、`multiply`（多选，tab 型强制单选）、**断言 2–5 个按钮**。**已完成**。**断言而不是截断**：第一版在 `build` 里 `segments.take(5)`，6 项静默丢第 6 项 —— 调用方看到第 6 项凭空消失而没有任何提示，比当场报错更坏；官方在类型层面（`ItemRestriction` 5 元组）就传不进第 6 项。`build` 里的 `SizedBox.shrink()` 只兜 release（release 不执行 assert）。**tab 与 capsule 是结构性差异**：官方 `multiply` 写在 `if (this.type === 'capsule')` 分支内，tab 型传了也白传；tab 型 `buttons` 的类型上没有图标字段 ⇒ 静默忽略 `icon`；tab 选中是**白背板**（`cardColor`）不是品牌色。**多选圆角只有首末段外侧**（`calculateBorderRadius()` 里 `isSingleSelect = type=='tab' || !multiply`），中间段 `setLeft/RightCorners(0)`，底板内边距多选归 0（单选 2）。几何全部取自 `segmentbutton.ets` 常量：`MIN_ITEM_COUNT=2` / `MAX_ITEM_COUNT=5` / 高 28 / 文字内边距 8×4（图标+文本 6）/ `Row({space:1})` / `Column({space:2})` / 图标 24 / 14fp / 未选 w400 选 w500 / 边框宽 0。三处有意偏离写进 dartdoc：①选中态逐段淡入而非浮层滑动；②tab 型忽略 `icon`；③`height` 默认 null（旧版写死 40 是自拟值）。**新增 13 条用例。此项已完成**
2. `OhosSlider` —— 加 `SliderStyle.NONE`（无滑块）、`showSteps` 刻度、`prefix`/`suffix`。**不做双值**。**已完成**。数值全在系统资源表：`slider_outset_track_thickness=4` / `slider_inset_track_thickness=20` / `slider_none_track_thickness=4` / `slider_outset_block_size→ohos_id_outset_block_size=16` / `slider_inset_block_size=12` / 命中区 `40/32/40` / 圆角 `2/10`（都正好是轨道粗细的一半）。**`stepSize` 是直径不是半径**：默认 4vp、范围 `[0, trackThickness)`（0 不显示、负数取默认、超轨道粗细回夹）；Material 的 `RoundSliderTickMarkShape` 半径取 `trackHeight/4`，口径差一个 2 倍 ⇒ 自写 `_OhosTickMarkShape` 直接画。`showSteps` **必须同时有 `divisions`**（没有步长不知道该在哪画点），但吸附步长**始终由 `divisions` 决定** —— 这条写进了注释，免得下一个人把它俩绑死。`prefix`/`suffix` 包在固定高 = 命中区的 `SizedBox` + `Center` 里，防大字号把整条顶高；`none` 形态外层补 `ConstrainedBox(minHeight: 40)`，否则父容器按 0 高测量连轨道都画不出来。**新增 8 条用例。此项已完成**
3. `OhosCheckboxGroup` —— 全选 / 半选 / 反选。**已完成**，落在新文件 `ohos_checkbox_group.dart`（约 530 行）。**不包子控件**：官方文档明写「子组件：无」，靠 `group` 字符串隐式配对；硬造「包住就自动分组」会带来两个新问题 —— 子控件类型受限、`ListView` 懒加载项漏算（官方示例 4 专门讲了这个坑，说明它本身是坑，不该再复制一层）。改为**显式受控**：`OhosCheckboxGroupController`（`selectAll` / `clear` / `toggleAll` / `invert` / `toggle` / `setSelected`）+ `OhosCheckboxGroupScope`（`InheritedNotifier`），群组头与成员从同一个控制器读写，不存在「界面上的勾」与「应用记的勾」不一致。三态 `OhosSelectStatus { all, part, none }` 对应官方 `SelectStatus.All=0/Part=1/None=2`；**半选画一横不是勾**（16 级灰上「颜色浅一点的勾」与勾分不开），`Semantics(mixed: true)` 单独报，读屏不会把部分选中说成「未选中」。`OhosCheckboxGroupResult` 比官方 `CheckboxGroupResult` 多一个 `total`：没有它分不出 `Part` 与 `All`。`toggleAll` **半选时切到全选**（不是先清空），与官方 `triggerChange` 同向。`invert` 反选是补充能力（官方只有全选/全不选两档）。**新增 24 条用例。此项已完成**
4. `OhosRadio` —— `RadioIndicatorType` 自定义指示器。**已完成，并且发现一处必须先修的规格漂移**：文档开头明写「**API version 12 开始，Radio 选中默认样式由 `RadioIndicatorType.DOT` 变为 `RadioIndicatorType.TICK`**」—— 旧实现画的正是圆点，即 API 12 之前的默认值。新增 `OhosRadioIndicator { tick, dot, custom }`，默认 `tick`。**更重要的是选中态结构**：`RadioStyle` 同时给了 `checkedBackgroundColor`（底板，默认 `ohos_id_color_text_primary_activated`）与 `indicatorColor`（内部图形，默认 `ohos_id_color_foreground_contrary`）两个默认值 —— 若选中态只是「空心环 + 品牌色圆点」，前者无处可画 ⇒ 改为**实心底板 + 反差图形**（旧实现两者都不是）。`custom` 没给 builder 时**回落 TICK**（官方「indicatorBuilder设置为undefined时，按照RadioIndicatorType.TICK进行显示」），否则会画出一个「已选中但空无一物」的实底圆。**点已选中项不回调**：单选框没有「取消选中」这个交互，旧实现给 `false` 会让一组里一个都不选。几何改按令牌：容器 `radio_container_size` **24**、描边 `ohos_id_radio_border_width` **1**（旧 1.5 是自拟）、内部图形 `ohos_id_radio_inner_size_ratio` **0.5**（旧 `size*0.22` 内边距是自拟）。**命中区未按官方加宽**（`hotzone_padding` 14 ⇒ 52）：加宽要么改布局尺寸让调用方按 24 排的间距失效，要么靠 `Stack` 溢出绘制被父级 clip 切掉 —— 已知边界，写进 dartdoc。**新增 11 条用例。此项已完成**
5. `OhosPicker` —— 滚轮（多维、循环、5/7 行）+ 时间日期 + 月历视图。**滚轮 / 时间 / 日期已完成，月历视图未做**（单列于下方）。落在 `ohos_picker.dart`，新增 `OhosWheelPicker` + `OhosPickerColumn` + `OhosPickerIndicator` + `OhosTimePicker` + `OhosDatePicker`。几何全取文档「说明」章节明文：行高**固定 40vp**、最多 **7** 项、建议高 **200vp**、文本 **20fp**、子组件对齐固定居中（`align` 不生效）。**「7 项 vs 200」不矛盾**：文档说「实际可视高度会小于 40vp」（非选中项按角度旋转、投影变薄），7 × 40 = 280 能落进 200；本库不模拟 3D 透视（要逐项矩阵且与滚动物理耦合），**按 5 行落地**、「最多 7 项」改为可调 `visibleCount` —— 唯一一处有意偏离，写进 dartdoc。**少于 8 项无条件不循环**：官方「如果子组件的个数小于8个，无论isLoop设置为true还是false，都不会循环滚动」，这是硬条件、不提供覆盖开关，`loopOf()` 直接实现。**多列是布局结果不是组件能力**（官方子组件本身就是选项，多列靠横向并排多个容器）⇒ 显式化为「一列一个 `OhosPickerColumn`」，`flex` 分配宽度（年月日 2:1:1）。指示器默认 `BACKGROUND`（圆角 12）、`DIVIDER` 档线宽 2.0px；墨屏上 5% 灰会被策略判透明 ⇒ 改画 1px 线。`onChanged`（逐项）与 `onScrollStop`（动画完全结束才一次）分开 —— 官方专门写了「如果某次滑动动画还未结束时又触发了新的滑动动画，则不属于滑动停止」，所以不能用定时器近似。**时间**：24 制 0–23 / 12 制 **1–12**（含 0 会让 12 小时制出现「00 点」），`second != null` 才有第三列；**不做 AM/PM 列**（需要额外的上下午状态，调用方拿 0–23 自己换算更直接）。**日期**：改年/月时「日」**收敛到当月末而非进位** —— 3 月 31 日改 2 月得 28/29 日（照搬 `DateTime` 会得到 3 月 3 日），与 `OhosDateCounter` 是同一条规则。**新增 23 条用例。滚轮 / 时间 / 日期三项已完成；月历视图（`CalendarPicker`）仍为 `○`**

### 阶段 D：展示与容器补齐

1. `OhosProgressIndicator` —— 补 `Eclipse` / `ScaleRing` / `Capsule`；新增 `OhosLoadingIndicator`。
2. `OhosListGroup` —— `style: none|card`、`header` / `footer`、吸顶组头（对标 `StickyStyle`）。**此项已完成（吸底未做，理由见下）**，落在新文件 `ohos_list_group.dart`（约 400 行）。**先拆清了 `sticky` 的归属**：它写在 `List` 的属性章节（`ts-container-list.md`）、`StickyStyle` 枚举也在那一页 —— 这不是文档排版失误而是规格事实，一次管住列表内所有分组。Flutter 侧的「吸顶」是 sliver 行为（`PinnedHeaderSliver`），盒子形态根本无处可吸，所以拆成 `OhosListGroup`（盒子）与 `OhosListGroupSliver`（sliver）两个类，`sticky` **只出现在后者** —— 盒子形态传了会得到一个「传了但没反应」的开关，那比不支持更坏。粒度上本库逐组声明、官方整表一次，逐组能表达的集合严格更大。**吸顶组头必须自带背板，而文档完全没提**：`PinnedHeaderSliver` 只负责钉住不负责遮挡，照文档做会得到一个浮起来却透明的组头、下面的行从它身上穿过去；真实规格在源码 `ListItemGroupPattern::ApplyHeaderFooterStyle`（`list_item_group_pattern.cpp:900`）—— 先 `UpdateBorderRadius(GetItemGroupDefaultBorderRadius())` 补分组圆角、再套 `UiMaterial::IMMERSIVE / THICK` 沉浸材质，本库对应 `OhosLightMaterial(level: thick)`。**卡片样式的三个数分处三个来源**，复核方式因此不同：`cardMargin = 12` 走资源表（`ohos_id_card_margin_start/_end`，经 `list_item_pattern.item_margin_left/right` 指向，`float.json` 两值都是 `12.0vp`）；`cardPadding = 4` **只在文档正文**（「卡片样式下…上下左右内边距 4vp」），资源表无令牌；`cardRadius = 24` 走 `list_item_pattern.item_border_radius → ohos_id_corner_radius_default_l`（`24.0vp`）。行级 CARD 的 **48 / 8** 同样只在正文（「高度 48vp、宽 100%、左右内边距 8vp」）—— 五个数里只有三个能跑 `fetch_sys_resources.sh` 复跑。**`group.style` 与 `itemStyle` 是两个独立参数**（官方示例 2 里 `CARD+CARD` / `CARD+NONE` / `NONE+CARD` 三种组合都出现过），不合并成一个「外观档」。**`space` 只作用于项与项之间**、不作用于组头与首行、末行与组尾 —— 这是最容易和「给每行加 padding」混淆的一条，用例把「组头→首行 8 / A→B 20 / 末行→组尾 8」三种距离分别钉住。**分组的 `divider` 默认 `null`（一条不画）**，与 `OhosList.divider: bool`（默认 true）相反；组接管分隔线后用 `OhosListDividerScope` 把行内 tile 自带那条压掉，避免双线。**吸底（`Footer` / `BOTH`）主动放弃并标 `○`**：实现了但不可靠 —— `SliverMainAxisGroup` 内部拿不到可靠的视口末端距离，`remainingPaintExtent` 已被同组前面的子 sliver 扣掉、且滑出视口时被夹到 0，「组尾原来在视口下方多少」这条关键信息恰好在需要它时丢失；换 `precedingScrollExtent` 与视口滚动量之差方向对了，但分组内部同样拿不到视口自己的滚动量，仍是猜的。宁可留缺口 + 一条钉住缺口的用例（组尾应 `findsNothing` —— 它落在视口外根本没被构建，真吸底了就一定被构建），也不留一个「多数情况看着对、滚到某些位置就错位」的实现。**新增 20 条用例。此项已完成（吸底除外）**
3. `OhosListItemCard` —— 承接 `HdsListItemCard` 的 A/B/C 三区结构。**此项已完成**，落在新文件 `ohos_list_item_card.dart`（约 740 行）+ `OhosListItemCardList` 容器。**先纠正了计划里的两个错数**：原文写「不做全 19 种 suffix」「A 区 8 种」，实际按 `^## Suffix` 清点得 21 条、扣掉基类与 3 个 `*Options` 是 **17 种**；`^## Prefix` 得 10 条、扣掉基类与 `PrefixIconOptions` / `PrefixIconType` 是 **7 种**。两处错法相同 —— **把 `*Options` 类型定义也当成了形态**，与仓库里「按目录名推文件名」是同一族错误。落地其中 **9 个**有明确形态依据的 suffix（文本 / 图片 / LoadingProgress / Radio / Checkbox / Switch / Arrow / Select / Badge）+ `custom` 兜住其余 7 个组合型 / 需 Symbol 字体的。
   **A / C 两区不照搬 7 + 17 个类**：ArkTS 是单字段单类型才需要那么多子类，Flutter 的 `Widget` 本身就是共同类型，照搬只会得到一堆只装一个 Widget 的空壳。收成 `OhosListItemCardPrefix(child, size)` + `OhosListItemCardSuffix` 具名构造器 —— **每个构造器强制收自己需要的内容**（`required` 位置参数），写不出「声明了 radio 却没给 radio」的组合。这条来自一次自捕获：首版六个枚举值只读 `builder`、而具名构造器从未赋值它，结果是**永远渲染空白**的开关，比不支持更坏。
   **几何几乎全是自拟，这是本项最需要说清的一点**：HDS 是闭源组件，`pattern.json` / `float_sys.json` / `float.json` 三张资源表搜 `list_item_card` / `listitem` / `hds` **全部零命中**，1944 行参考文档只给了两处数字（`IconSize` 的 **16 / 24**，与穿戴设备 `PrefixImage` 固定 46×46）。所以 `OhosListItemCardMetrics` 里除这两个之外**每条都标注「文档未给，自拟」**，不能让后人误以为是官方默认值。**`cardHeight` 从 64 改成 72 是被测试逼出来的**：`bodyLarge` 16×1.5 = 24、`bodySmall` 14×1.5 = 21，三层 + 两个 2vp 间距 = **70**，64 只够两行、`Column` 溢出 6vp。算错的原因是把字号当成了行高 —— 「照抄常量前先算」的第二次翻车。
   **三层文本是并列不是二选一**（官方 `primaryText` / `secondaryText` / `description` 三个独立字段，示意代码三层同时出现），字阶按语义分 `bodyLarge` / `bodySmall` / `bodySmall`。`contentBuilder` 优先级照搬官方原话「`customBuilder` 优先级高于其它接口」：给了就整块替换 B 区。**无障碍标签订住了一处实测坑**：`Semantics(label:)` 默认不是语义边界，实测节点标签是「拼好的一句 + 三层原文各一行」，读屏会把整行念两遍；加 `container: true` + `excludeSemantics: true` 才收成一个边界。**不做**：副 Symbol（8 个字段，官方写明「仅在左侧第一个 Symbol 存在时才显示」，16vp 图标旁再叠一个必然挤成一团）、`hoverBorderRadius`（Flutter 没有「hover 时单独换圆角」的机制）。**新增 33 条用例。此项已完成**
4. `OhosChip` —— ~~先对齐尺寸再补形态~~ **尺寸与两种新形态均已完成**。尺寸五项全修（36/28 高、18/14 圆角改为显式值、14fp、图标 16/16、间距 6/4），选中字重 w600 → 官方 500，数值抽到 `theme/ohos_chip_metrics.dart` 由 `OhosChip` / `OhosChipGroup` 共用（后者原本写死 32/24），`OhosChipGroupSize` 改为 `OhosChipSize` 的 `typedef`。**形态一**：`allowClose` + `onClose`、`suffixIcon`，按 ArkUI 的优先级链实现「给了后缀图标就不画内置 ×」；`allowClose` 默认取 `false`（有意偏离独立 Chip 的 `true`，理由见 §1.4）。**形态二（本轮）**：`selectedIcon`，即 `prefixSymbol` 的 `normal` / `activated` 双态 —— `chip.ets:838` 是 `isChipActivated() ? activated : normal`，两态是**两个图形**而非一个图形换色。有意偏离 `hasPrefix()`（`:1014`）的「只给 normal 则选中态连图标带间距一起消失」：照搬等于既有用法被点一下掉图标，改为回落。`OhosChipItem` 同步两项。**此项已完成**
5. `OhosSubheader` —— ~~补 `type: list|content`~~ **六项全部完成，此项已完成**。**没有照搬「`type` 入参」**：官方 `SubHeader` 根本没有 `type`，`list`/`content` 是**参数组合的结果**（`subheader.ets:643` 的 `leftArea()` 与 `:597` 的 `getMinHeight()` 是两条一致的优先级链）。造一个官方不存在的开关，等于让调用方声明渲染器兑现不了的形态 —— 改为只读派生属性 `type`，由 `title` / `secondaryTitle` / `icon` 三个字段算出。落地内容：高度三档 **56 / 56 / 72**（`ConstrainedBox(minHeight:)`，松约束下不会被大字号压扁，也不会像旧实现那样靠 18fp 字阶撑出 ~42）；副标题双行（14fp / **400** / `titles_space` 2）与单行（14fp / **500**，官方权重随形态变，`subheader.ets:711` vs `:735`）两种字重；左图标 **16** + 间距 **8**；左右边距 **16/16** + 内容 padding **8**，副标题单行形态额外 +12（`subheader_single_subtitle_padding`，使左侧成 28 —— 这不是笔误，官方用它对齐列表项文字）。**保留的两处有意偏离/边界**：①`icon` 只在有 `secondaryTitle` 时出现（照 `leftArea()` 的判定顺序，不是 bug，文档里写清）；②`leading` 顶掉全部文本但**不改变行高** —— `getMinHeight()` 读字段而非 builder，两个文本都在就仍是 72，这点已在用例里钉住。组件从 `ohos_text.dart` 拆到独立文件 `ohos_subheader.dart`（原实现只有一个 `padding`，扩到 300 行会把纯文本文件撑坏）。新增 10 条用例。
6. `OhosToolbar` —— ~~`ItemState`（启用/禁用/激活）+ 分组~~ **此项已完成（「分组」不做，理由见下）**。**`selected` → `state` 是破坏性变更**：旧字段把两件事压进一个布尔 ——「允不允许成为当前项」（官方逐项 `ItemState.ACTIVATE`）与「现在是不是当前项」（`activeIndex` 决定），于是可以写出「禁用 + 已选中」这种官方不存在、界面上一块蓝却点不动的方块。改为 `OhosToolbarItemState { enabled, disabled, activated }`，dartdoc 明确写「三值不是互斥开关，而是能不能点 / 允不允许激活两条维度」，避免调用方写出 `enabled && activated` 这种恒假判断。**激活态是双条件**：`toolbar.ets` 的 `getIconColor()` 是 `activateIndex == index && state == ACTIVATE`，只给 `activeIndex` 指向一个 `ENABLE` 项不点亮任何东西 —— 这是官方行为里最像 bug 的一处，用例显式钉住。**几何全部按官方常量**：栏高 `DEFAULT_TOOLBAR_HEIGHT` = **56**（**不含**分割线，所以整条 57）、图标 `IMAGE_SIZE` **24**、图标与文字间距 `padding_level1` **2**、标签 `ohos_id_text_size_caption1` = **10fp**/w500（不是 Material caption 的 12fp，在一堆 14/16 里显得很小，但这就是官方值）、圆角 `ohos_id_corner_radius_clicked` **8**、侧边距 `padding_level12` **24**。**侧边距的条件是 `items.length < 5`，不是 `<=`**：正好 5 项时官方已经按 0 内边距均分铺满，而 6 项收纳后也是 5 格 —— 写 `<=` 会让 5 项那档突然缩进 24，与收纳后的 5 格对不齐。**收纳**：`TOOLBAR_MAX_LENGTH = 5` / `moreIndex = 4`，超过 5 项时前 4 留在线内、第 5 格变「更多」，点击默认走 `showOhosMenu<int>`，`value` 用**原始下标**（调用方拿到直接对自己 `items` 取值，不必再补 `_moreIndex`）。**常态色改回 `textPrimaryColor`**：旧实现用 `textSecondary` 让整条栏发灰，而工具栏是主导航不是辅助信息。**「分组」不做**：官方 `ToolBar` 没有分组能力（`ToolBarOption` 只有 `button` / `text` / `icon`），ROADMAP 当初写「+ 分组」是照 Hammerspoon 式工具栏想当然 —— 又是「造一个官方不存在的入参」，与子标题那处同型。**跨组件修复**：新增策略能力 `OhosVisualPolicy.selectionMark` + `OhosSelectionMark { tint, inverse, emphasis }`，`InkVisualPolicy` 覆写为 `inverse`（实底 `highlightColor` + `onHighlightColor` 反白）。根因是墨屏 `highlightColor == textPrimaryColor == 纯黑`，「选中 = 换品牌色」在灰阶屏上等于什么都没做；工具栏只有图标 + 文字两条信息，没有胶囊底也没有下划线可借，颜色一失效就彻底分不出当前项。`OhosNavigationBar` / `OhosTabBar` 有同样取色方式但**尚未迁移** —— 它们另有胶囊底与下划线作第二条线索，不是当前最高优先级。新增 11 条用例。
7. `OhosPageIndicator` —— ~~补数字型与箭头型~~ **此项已完成**。**数字型**：`OhosPageIndicatorType.digit`，显示 `当前/总数` 且**从 1 起数**（`currentIndex` 是 0-based，直接拼会显示 `0/3`）；字号 14fp / **w400**（`digitFont` 默认 `{size: 14, weight: Normal}`），当前页与总数**只差颜色**、不加粗也不放大 —— 这与圆点「沿主轴变宽」是两种完全不同的强调方式，最容易照圆点的思路给数字加粗。`count == 0` 时两侧都显示 0（`clamp` 前会算出 1，凭空冒出第 1 页比 `0/0` 更糟）。**箭头型**：`OhosSwiper.showArrows`，默认 **`false`**（照 `displayArrow` 的默认值）；底板 32、箭头取底板 3/4、底板色 10% 黑（`isSidebarMiddle: true` 那一档），走 `policy.tint` 上色；**只有一页时不画** —— 官方写明「Swiper视窗内显示所有子节点时…左右翻页箭头均不显示」，即使显式打开了 `displayArrow`。**顺带修掉圆点自身三处偏差**：未选中 6×6（旧 8×8）、选中 **12×6**（旧 8×16）、间距 **8**（旧 6）。其中「选中是变宽不是变大」是官方形状 —— 两个官方示例分别写 `itemWidth(8).selectedItemWidth(16).selectedItemHeight(8)` 与 `selectedItemWidth(15).selectedItemHeight(15)`，**改变的是宽度**。**一处必须在文档里写清的数值冲突**：参考文档说 `itemWidth` / `itemHeight` / `selectedItemWidth` / `selectedItemHeight` 默认值**都是 6**，而资源表有独立的 `ohos_id_swiper_indicator_selected_size = 12`、且官方所有示例的选中宽度都大于未选中。本库取 12 —— 依令牌与渲染形状，不依那句散文；文档那四个 6 极可能是把第一行复制了四遍。**顺带把间距从 margin 改成 `Row.spacing`**：margin 会被算进点自身尺寸（6 的点量出 14），也会把命中区一起撑大，而官方的 `space` 是点与点之间的距离。新增 9 条用例。
8. `OhosCounter` —— 日期形态（`DateStyle`）。**此项已完成**，落在新文件 `ohos_date_counter.dart`，与原有 `OhosCounter`（数字步进器）并存。**刻意不用 `DateTime`**：官方的日期计数器不是时间点，是三个各自以不同方式回绕的数字 —— 年**夹取** `[1, 5000]`（到边界按钮即失效）、月**回绕**但不进位到年（`12 + 1 = 1`，年份不动）、日**回绕**按当月实际长度（`2024-02-29 + 1 = 02-01`）。`DateTime` 会把 `2024-01-31 + 1 月` 进位成 `2024-03-02`，与组件行为完全不符 —— 所以新增 `OhosDate` 值对象（`addYears` / `addMonths` / `addDays` 三个方法各自实现一种回绕，另 `_clampedDay` 实现 `updateDay()` 的「换月后日收敛到月末」）。**几何全部取 `counter.ets` 的 `COUNTER_INLINE_*` 常量**，而不是文档那句「32vp」概括：容器高 **32**、圆角 **8**（显式值，不是 `height/2`）、1vp 描边、日期组 **92**（年 38 + `/` 8 + 月 19 + `/` 8 + 日 19）、段输入高 **20**、箭头列 **32**、箭头图标 **12**。**两处有意偏离官方**：①每次变更都回调 `onChanged` —— 官方的 `onDateChange` 只在三个 `TextInput.onChange` 里被调用，按箭头改完数字**不通知应用**（组件实际上是只写的），照搬会让它无法被 Flutter 的 `setState` 驱动；②不做官方的 1500ms 回退定时器，改成「失焦即弹回」，终态一样但没有 dispose 后仍在跑的定时器。**两处平台差异导致照抄不成**：①箭头两半不能按 16+1+16 写 —— 官方之和是 33、比 32 的盒还高，在 ArkUI 成立是因为容器边框不占内容区，而 Flutter 走 `strokeAlignInside` 后内容区只有 30，第一版照抄让 12 条用例**全部**因 `RenderFlex overflowed by 2.0 pixels` 变红，改用 `Expanded` 平分；②点箭头会先让 `TextField` 失焦（`onTapOutside`），若「当前作用段」读实时焦点就永远回落到日，改为记住最后聚焦的段。段内直接输入（满位提交、越界整段回退）、聚焦段底色反转（彩屏品牌蓝 + 白字 / 墨屏黑块 + 纸色字，同一个分支、无需 policy 判断）、长按连续加减记为 `○`。**新增 `OhosDate` 9 条 + `OhosDateCounter` 11 条用例。**
9. `OhosTextField` —— 内联模式、密码模式、`showCounter`。**此项已完成**，落在 `ohos_text_field.dart`（约 800 行），新增第四枚举值 `OhosTextFieldVariant.inline` + `OhosInputCounterOptions` + `OhosTextFieldMetrics`。
   **内联形态有三条官方硬约束，任何一条不满足都回落成下划线形态**（不是画一个「半内联」）：只支持 `InputType.Normal`（单行不遮蔽）、不支持 `showError`、内联 / 密码模式下计数器不显示。官方原文写在 `TextInput.style`（「内联输入风格只支持 InputType.Normal 类型」）与 `showCounter`（「内联模式、密码模式下字符计数器不显示」）两处 —— **后者最容易漏**，单看 `showCounter` 的说明不会知道它跟另外两个形态互斥。落地方式是用派生 getter `_inlineEffective` 一次算清，`switch (effective)` 统一消费，避免「这一处判了那一处忘了判」。
   **密码模式不是「`obscureText` 换个名字」**：它带一整套形态 —— 末尾 **24vp** 眼睛图标（`textfield_icon_size`，与 `passwordIcon` 属性说明「固定尺寸为 24vp」相互印证）、**40vp** 命中区（`textfield_icon_hot_zone_size`）、容器高 **48**（`password_style_height`）。眼睛的显隐状态取**组件内受控**（`_passwordVisible`）并用 `onSecurityStateChange` 把真实状态抛出去 —— 官方 `showPassword(visible)` 是受控属性且文档点名了不受控的风险（前后端状态不一致会导致图标异常），但每次点眼睛都要求调用方 setState 太啰嗦。`obscurePassword` 与原有的 `obscureText` 是**同一形态的两个入口**，用 `_obscured` 收口。
   **计数器有四个前置条件**：`showCounter` + `maxLength != null` + 非内联非密码 + 过阈值。`thresholdPercentage` 的有效区间是 `[1,100]`，**超出区间时不显示计数器**（不是夹到边界）——「显示但不过滤」的那种语义对应的是 `undefined`。字号 **10fp**（`count_text_font_size` → `ohos_id_text_size_caption1`），比本库 `labelSmall`(12) 还小一档，这是官方值。颜色令牌三个不同：`count_text_color` = `font_tertiary`（正常）、`over_count_text_color` / `over_count_border_color` = `warning`（溢出）、`over_text_color` = `alert`（被截掉的输入文字）。
   **这一项真正的难点不是写形态，而是「令牌有值 ≠ 令牌生效」—— 本轮在这里栽了两次，都是实测才发现。**
   ① **填充形态实测渲染 52vp，官方 40**。`contentPadding` 是早前自拟的 `14/14`，而 `textfield_padding_horizontal`(→`padding_level8`=16) 与 `textfield_padding_vertical`(→`padding_level4`=8) 从来没接上：8 + 24 + 8 = 40 才对。改回令牌后仍是 48，挖出第二层原因 —— `InputDecorator` 在 `isDense == false` 时把容器高**夹到 `kMinInteractiveDimension`(48) 以上**（`input_decorator.dart` 的 `minContainerHeight`），这是无障碍最小触摸目标兜底，会把 40 的规格无条件覆盖。必须显式开 `isDense: true` 才能拿到 40。**这两层任何一层没查出来，都会得出「官方 40 做不到」的错误结论。**
   ② **两个圆角令牌，哪个是容器圆角不能靠名字猜**。`textfield_border_radius`(→`corner_radius_level10`=20) 与 `border_radius_size`(→`corner_radius_level6`=12) 都在 `ohos_textfield_pattern` 里，先前按名字猜成「12 是容器、20 是别的」。实测两个都对不上 —— 代码实际用的是主题的 `radiusMedium` = **16**。去读源码才定论：`text_field_pattern.cpp` 里 `auto radius = theme->GetBorderRadius();` 后面紧跟 `IsUnderlineMode() ? ZERO_BORDER_RADIUS_PROPERTY : borderRadius` —— 非下划线形态用 `textfield_border_radius`，下划线形态**显式归零**；而 `GetBorderRadiusSize()` 在整个 `text_field/` 目录 **grep 零命中**（`textfield_theme.h` 里有成员、有访问器，就是没人调）。这与搜索框的 `search_text_field_padding_left` 是同一类病：**表里有、没人读**。`borderRadius` 常量因此保留但标「死令牌、不参与渲染」，矩阵不给它开数据行。
   ③ **密码形态的 48 不随底板变化**。`password_style_height` 是独立容器高，只在「内边距恰好算成 48」的下划线形态上碰巧成立；填充底板上按内边距算是 40，必须单独加最小高度约束。
   ④ **`InputDecoration.suffixIconConstraints` 默认 48×48**，会把本库 40 的密码命中区撑到 48、24 的图标在里面对不齐（实测 `getSize(icon)` 拿到 48 才发现）。需显式传 `const BoxConstraints()`。
   **有一处明写「未接」而不假装实现**：`textfield_error_spacing`(8) 决定错误提示与输入框的间距，但 Flutter 侧这个间距是 `InputDecorator.subtextGap`，M3 写死 4、无 decoration 级入口；要对齐只能自己画错误提示，会连带失去 `_hasError` 的自动推导 —— 收益不足以抵风险，常量留在 `errorSpacing` 备后续。
   **新增 31 条用例**（密码 6 + 内联 6 + 计数器 12 + 几何 7）。其中最后 7 条**全部量真实渲染尺寸**（`tester.getSize` / `decoration.isDense` / `errorBorder.width`），而不是像原来那条「几何令牌逐条可查」只断言常量字面值 —— 后者在 52vp 偏差存在时**依然全绿**，正是「常量写对了 ≠ 常量被用上了」。**此项已完成**
10. `OhosSearchBar` —— ~~按官方数值收口~~ **尺寸与五个形态均已完成**。尺寸：放大镜 18 → **16**、清除命中区 32 → **40**、圆角从 `radiusCapsule=999` 改成显式 **20**（`OhosGeometry.radiusSearch`）。**没有再改的一条**：左内边距保持 12 —— 上一版计划写的「12 → 4」基于死令牌（`search_text_field_padding_left` 零调用方），12 才是官方 `search_icon_left_space` 的值。**形态四**：新增 `searchButtonText`，按 `search_button_space`(2) + `search_divider_side_space`(2) + 1px 分隔线 + `search_button_text_padding`(14) + 按钮高 36 落地。**形态五（本轮）**：`autoDisable`（`SearchButtonOptions`，API 18+），无文本时按钮置灰且不可点；默认 **`false`** 照官方文档，置灰取 `textTertiaryColor`。**没有照搬的 56**：`search_height` = 56 同样零调用方，官方带 `searchButton` 的示例全写 `.height(40)`，故栏高保持 40（见 §1.4(c) 第二段纠正）。**此项已完成**
11. `OhosAlertDialog` —— 按 `CustomDialogControllerOptions` 补缺。**此项已完成**，文件 `ohos_alert_dialog.dart` 从 198 行扩到约 500 行，新增 `OhosDialogMetrics` / `OhosDismissReason` / `OhosDismissDialogAction` / `OhosDialogLifecycle` 四个类型与八项参数。
    **尺寸是「上限」不是「固定值」，这是本项最容易被抄错的一点。**`maxWidth = 400`、`maxHeight = 0.9×(窗口高−安全区)` 都是 `ConstrainedBox` 的上限，内容短了弹窗自己收缩。高度乘的是「窗口高 − 安全区」而不是窗口高 —— PC/2in1 上要避让屏幕边缘与窗口标题栏，直接用窗口高会让底边被裁掉。高度**不给 `minHeight`**，让内容决定多高，超了由内层 `Flexible` + 滚动消化。
    **`width` 的语义是夹取，`gridCount` 的语义是回落 —— 两种不同处置，不能互换。**`width: 800` 官方「设置后不超过默认最大宽度 400vp」⇒ `clamp(0, 400)` 夹回 400；而 `gridCount: 999` 官方「异常值按默认值处理，最大栅格数为系统最大栅格数」⇒ 返回 `null` 走默认宽度路径。**夹取会让 `gridCount: 999` 悄悄变成「占满整屏」，那不是调用方要的** —— 一个想占满但写错数字的调用方，得到一个恰好像占满的弹窗，比明确回落更坏。
    **`customStyle` 是两档语义，不是加个开关。**`false`（默认）→ 圆角 32（比本库 `radiusLarge`(24) 还大一档，弹窗是官方少见的「圆角比卡片更大」的容器）、不透明背板、`padding` 16、1px 描边；`true` → 圆角 0、背板 `Transparent`、无内边距、无描边，**壳完全交给调用方**。文档原计划写的是二选一（要么对齐 32，要么声明本库只走 `customStyle: true`），落地时发现两者并不冲突：默认档对齐官方 32，可选档才是「壳交出去」。
    **`isModal: false` 在两种入口下语义不同，因此写成两档而不是假装全支持。**直接构造 `OhosAlertDialog` 时是真的非模态：不画遮罩、不拦截下层手势；而经 `showOhosDialog` 弹出时路由上的 `ModalBarrier` 一定存在，这个参数只能表达「不画那层 20% 黑」——下层依旧点不到。写清差异比让调用方以为「非模态了」要好。
    **遮罩默认色与 Material 差一倍多。**`0x33000000` = 20% 黑，Material 的 `barrierColor` 是 `Colors.black54`（54%）。官方的遮罩更淡，靠弹窗自身底板与投影分层，而不是把背景压黑 —— 照抄 Material 的 54% 会让整屏发灰、失去层级。`maskColor` 可覆盖；`maskRect` 默认全窗口，**「区域外事件透传」没做**（Flutter 侧需要自定义 hit-test 区域，官方那个默认值也等价于全屏，先记 `○`）。
    **生命周期四段**（`onWillAppear`→`onDidAppear`→`onWillDisappear`→`onDidDisappear`）按 `OhosDialogLifecycle` 一次传入。`onDidAppear` 用 postFrame 近似，并判 `mounted && !_disappearing` —— 官方写明「动效被打断则不触发 `onDidAppear`」，这个判断在嵌入式构造下没有真动效可被打断，只是让它与路由级行为一致。销毁时补发退出回调，避免调用方漏收。
    **`onWillDismiss` 的官方语义与 Flutter 相反，这是本项最容易写出「看着能用、其实相反」的地方。**注册后**不调 `dismiss()` 就不关**；不是「返回 false 才拦」。为此 `showOhosDialog` 在给了 `onWillDismiss` 时**把路由的 `barrierDismissible` 强制设成 false** —— 否则路由先 pop、回调跑不跑都来不及看。`OhosDismissReason` 只落 `pressBack` / `touchOutside` / `closeButton` 三值（照官方值序；`slideDown` / `slide` 属半模态，不是弹窗能产生的事件）。
    **两个 bug 是被用例抓出来的，静态分析全绿时都看不出来。**① `Center(child: Stack(...))` 里 `Positioned.fill` 的遮罩**不会铺满全屏**：`Center` 给子节点松约束，`Stack` 收缩到弹窗大小，实测遮罩只有 **179×124**，点弹窗外面根本命中不到 —— 必须外套 `SizedBox.expand`。② `tester.getSize(find.byType(OhosAlertDialog))` 量到的是铺满全屏的 `Center` 根节点，**永远等于窗口宽**，「宽度 ≤ 400」的断言恒真是假绿 —— 改为量那层 `ClipRRect` 弹窗壳。另外 `setSurfaceSize` 不改 `MediaQuery`，栅格用例算出 179 而非 180（断点判成 medium / 8 列），要同时设 `tester.view.physicalSize`。
    **主动不做**：`showInSubWindow` / `levelMode` / `levelOrder` / `immersiveMode`（属于 ArkUI 窗口层级体系，Flutter 侧没有对应物，强行模拟只会得到一套假的层级语义）。**新增 15 条用例 + 3 段 example 演示，矩阵弹出框 7 行由 `○` 转完整。**

### 阶段 E：核心操作栏 + 底部页签（都是 HDS 组件，按文档重做）

核心操作栏（`HdsActionBar`）—— **此项已完成**（七项全落，两处 `○` 已明写理由）。落在 `ohos_action_bar.dart`，从 196 行重写到约 700 行，新增 `OhosActionBarButton` / `OhosActionBarStyle` / `OhosActionBarMetrics` / `OhosBlurStrategy` 四个类型。
**几何全部是自拟，这是本项最需要说清的一点。** `HdsActionBar` 属 HDS 闭源套件：`pattern.json` / `float_sys.json` / `float.json` 三张系统资源表搜 `actionbar` / `action_bar` **全部零命中**（连 `hds` 前缀都一个不存在），293 行参考文档**只列属性、一条默认值数值都没给**，设计规范（`component_actionbar`）只有定性描述「悬浮在页面下方」「组件背板默认带有模糊材质和投影」。所以 `OhosActionBarMetrics` 里每个数（按钮 56 / 次按钮 40 / 图标 24 / 栏高 72 / 圆角 24 / 间距 8 / 边距 16）都标了「自拟」，**不能当成官方默认值转述** —— 这与 `OhosListGroup`（12 / 4 / 24 大多能指到令牌）是相反情形，与 `OhosListItemCard` 相同。
**1. 结构改造**：`startButtons` / `endButtons` 两端取代单一 `secondaryActions`，是**破坏性变更**。官方从来只有「起始组 + 主按钮 + 末尾组」这个形态，0.5.x 的「全部放一侧」是当时没读文档的产物。布局用三段 `Expanded`（左右各一段 + 中间主按钮）而不是 `Spacer` —— 两侧按钮数量不等时（左 1 右 3）`Spacer` 会把主按钮推偏，居中失效。
**2. `ActionBarButton` 等价类**：官方 17 个属性里落 12 个（width / backgroundColor / iconSize / iconFillColor / icon / altIcon / enabled / onPressed / tooltip / accessibilityLabel）。**不收 `buttonModifier` / `baseIconSymbolGlyphModifier`（Modifier 体系无 Flutter 对应）、`id`（为 `openPopup` 服务，Flutter 没有）、`accessibilityDescription` / `accessibilityLevel`（无对应机制）**。**`shadowStyle` 主动不做**：`ShadowStyle` 枚举只给「大阴影」这种定性描述，`OUTER_DEFAULT_LG = 3` 只是枚举序号，`shadow.h` 里也无数值表 —— 与 `textfield_error_spacing` 同类：**有名字、无值**。自拟一组阴影数字不难，但那是编造官方规格。
**3. 双图标切换**：`OhosActionBarStyle.isPrimaryIconChanged` 照官方放在 style 而非按钮上（它是整个操作栏的状态，展开/收起常与图标切换同步）。**缺 `altIcon` 时回落 `baseIcon`** —— 与 `OhosChip.selectedIcon` 同一条规则：「切一下就掉图标」不是双态而是缺陷。
**4. 自定义主按钮**：`primaryButtonBuilder` 优先级高于 `primaryButton`（官方原话）。官方「设置 `primaryButtonBuilder` 时必须同时设置 `primaryButtonBuilderWidth`」是硬约束 —— 自定义 builder 没有内在宽度，缺了它无法排版，所以缺宽度直接 `assert` 失败而不是静默取默认。
**5. 竖直排列与五个间距**：`height` / `innerSpace` / `startSpace` / `endSpace` / `margin` 全部落地。**`startSpace` / `endSpace` 在竖直排列下映射到上下边框而不是左右** —— 官方在参数说明里逐字写了「水平排列时为左边框，竖直排列时为上边框」，按名字固定成 left/right 是个很容易犯、且视觉上不易察觉的错，已用用例钉住。另修掉一个自造 bug：竖直排列时若沿用固定的 72 栏高，3 行按钮 + 间距需要 152，`RenderFlex overflowed by 80 pixels` —— 改成分支处理，竖直只给 `minHeight`。
**6. 默认开模糊**：`blurStyle` 默认 `OhosLightMaterialLevel.regular`（对应 `COMPONENT_REGULAR` = `BlurStyle` 枚举值 10「组件普通材质模糊」，见 `ts-universal-attributes-background.md`）。**默认真开是有依据的**：设计规范把这件事写成默认属性而非可选装饰。墨屏由 `policy.allowsBlur` 判掉、改画实色 + 1vp 描边（`BackdropFilter` 在墨水屏真机退化为「拖尾」或「留灰块且慢」）；`blurStrategy: disabled` 走同一条退化路径，但原因不同 —— 一个是硬件画不出来，一个是调用方显式关掉。`OhosBlurStrategy.adaptive` 与 `enabled` 处理成一致，并在 dartdoc 里**写清「Flutter 读不到系统性能档位」**而不是假装做了自适应（官方 `ADAPTIVE` 依赖厂商配置的精美/轻柔/流畅三档）。
**7. 整体禁用**：`style.enabled` 是**总开关**，不是背板自己的开关 —— 官方原文「`enabled=false` 则背板不启用并且所有按钮都不启用；`enabled=true` 时每个按钮可以单独设置」。实现上与逐按钮 `enabled` 做 `&&`，并用 0.4 不透明度表达「还在、但不能操作」（官方只要求失效，没要求变透明；但背板与按钮同时失效后留一块无反馈的图形更糟）。
**一处因祸得福的发现**：改完跑 `example` 的溢出矩阵，`container` 页整片变红，报「Vertical viewport was given unbounded height」。根因不在操作栏 —— 是上一版往 `container_page` 加的 `OhosListItemCardList`（内部是 `ListView`）被放进了 `DemoScaffold` 的纵向 `ListView`，两个纵向视口嵌套；`shrinkWrap` 参数本来就有，example 里没传。**上一版改完 example 没跑溢出矩阵**，这个错误漏了整整一轮。**新增 13 条用例，example 的 85 条溢出用例全过。**

底部页签（`HdsTabs`）：

> **实施前先纠正一个归属错误，它改变了 1–4 项的落点。** 第 1、2、3、4 项全部挂在 `barFloatingStyle` 之下 —— 也就是说它们描述的**不是**现有的平铺 `OhosTabBar`，而是一个本库此前完全没有的形态：**悬浮页签栏**。证据链：
>
> - `HdsBarWidthRangeOptions`（三档宽度）在全文只被两处引用：`HdsTabsFloatingStyle.barWidth` 与 `HdsTabsMiniBar.miniBarWidth`。平铺栏的 `barWidth` 是 `barWidth(value: Length)`，**单个 `Length`**，与三档无关；
> - `gradientMask` 同样只在 `HdsTabsFloatingStyle` 里出现，而且文档在「页签栏悬浮样式」一节明确写明「若在 `barFloatingStyle` 中设置 `miniBar`，则可实现迷你栏」；
> - 悬浮样式有三个前置条件（`barOverlap=true`、`vertical=false`、`barPosition=BarPosition.End`），平铺栏一条都不满足。
>
> 所以这五项应作为**一个新组件** `OhosFloatingTabBar` 一起落地，而不是往 `OhosTabBar` 上加参数。这正是「按属性名找宿主、不按类名找」的反例教训 —— 上一版就是因为「都是 tabs 家族的」把它们都算在了已有组件头上。
>
> 另：HDS 闭源套件在三张资源表里搜 `hds` / `minibar` / `mini_bar` **零命中**，`floating` 虽有 18 条但全是 `ohos_id_shadow_floating_sm_*` 这类通用阴影、与页签栏无关（与 `HdsActionBar` 完全同型）。所以悬浮栏与迷你栏的几何（圆角、内边距、折叠态宽度）**全部自拟并逐条标注**；能指到令牌的只有 ArkUI 通用 tabs 家族那批（`ohos_id_tab_padding` 16vp、`ohos_id_tab_gradient_width` 24vp、`ohos_id_tab_default_height` 56vp、`ohos_id_bottomtab_height` 48vp），它们属于平铺栏，用来给 `OhosTabBar` 对账，不能拿来当悬浮栏的值。

1. 三档宽度 `smallWidth` / `mediumWidth` / `largeWidth`，及「≤3 个 `76vp×n+8vp`（≥600vp 用 `80vp×n`）/ ≥4 个上限 328vp」的默认算法。**已完成**：`lib/src/widgets/ohos_tabs_width.dart` 的 `OhosTabsBarWidthRange` / `OhosTabsWidthDefaults` / `OhosTabsWidthTier`（6 条纯函数用例），并已接进 `OhosFloatingTabBar`（3 条布局用例）。**三档的断点条件比原计划复杂**：`mediumWidth` = 宽度 440–600vp，**或** 600–840vp 且高宽比 < 0.8；`largeWidth` 对称。三处曾写错、都已用用例钉住 ——
   - 「≥4 个」是**直接换规则取 328**，不是算完再夹：4 个页签 `76×4+8 = 312` 还没到上限，写成 clamp 会差 16vp；
   - 「高宽比」按中文词序读 = **高 ÷ 宽**。第一版写成 宽÷高，第二版比值改对了但返回值两臂没跟着换，方向各错一次，都是同一条断言抓到的；
   - 328 是**绝对上限不是必然值**：容器 340 宽时「16 + 328 + 16 = 360」溢出 20vp，必须再夹一次可用宽度。
2. `gradientMask` 蒙层（浅色 `#CCF1F3F5` / 深色 `#99000000`，高度 = 栏高 + 16vp）。**已完成**：`OhosFloatingTabBarStyle.showMask` / `maskColor` / `maskHeight`，2 条用例。**这两个值与高度都是对的，上一版曾把它们「更正」成另一组，那次更正是错的 —— 两个 API 被混成了一个。** `HdsTabsBackgroundStyle`（`maskColor` / `maskHeight`）只是一个**共用类型**，被两处引用，各自默认值不同：

   | API | 挂在哪 | 起始版本 | 浅色 | 深色 | 高度 |
   |---|---|---|---|---|---|
   | `gradientMask` | `barFloatingStyle` 内（悬浮样式） | 6.1.0(23) | `#CCF1F3F5` | `#99000000` | 页签栏默认高度 + **16vp** |
   | `barBackgroundStyle` | TabBar 本身（渐变模糊） | 6.0.0(20) | `#CCFFFFFF` | `#CC000000` | TabBar 高度 + **32vp** |

   两者的**语义也不同**：`barBackgroundStyle` 是「模糊样式为渐变模糊」，依赖「页签栏位于容器底部 + `barOverlap=true` + 去掉默认模糊值」；`gradientMask` 是**悬浮样式下**叠在内容上方的一层纯色蒙层。**上一轮把两者当同一个，等于用一个 API 的默认值覆盖了另一个 API 的默认值**，还附带把「16vp」改成「32vp」—— 这条留在这里当反例：**同名类型被多处引用时，默认值必须按「引用它的属性」读，不能按类型读。**
3. 迷你栏 `HdsTabsMiniBar`：折叠 / 展开、自定义内容区、`barLayoutMode` 水平 / 垂直。**已完成**，落在新文件 `ohos_mini_bar.dart`（`OhosMiniBar` / `OhosMiniBarStyle` / `OhosMiniBarScaffold` / `OhosBarStyle` / `OhosBarLayoutMode` / `OhosMiniBarAlign`），17 条用例。三个容易写错的点：

   > **① 官方在 440vp 处换了居中口径**，两条原文只差几个字、结论相反：
   > 「宽度小于 440vp … → 页签栏和迷你栏将**整体**底部居中显示」
   > 「宽度在 440vp-600vp 之间 … → **展开的**页签栏或迷你栏将底部居中显示」
   > 差别是**折叠者跟着走还是贴边**。抽成纯函数 `OhosMiniBar.alignFor` 单独守，塞进布局里就只能靠量像素反推。
   >
   > **② 「居中」是相对容器，不是相对兄弟节点。** 最初用 `Row + Spacer`，折叠者占掉了流式布局的一段，展开者中心被推偏 28vp（520 宽、折叠 56 + 展开 200）。改用 `Stack` + `Align` 让两者在同一坐标系各自定位。
   >
   > **③ 两个栏宽度各自独立算，合计可能超容器。** 320vp 屏上「迷你栏 200 + 间距 8 + 页签栏 220 = 428」，`Row` 不折行、静态分析不报错 —— example 溢出矩阵报 `RenderFlex overflowed by 68 pixels` 才暴露。两侧套 `Flexible` 兜住。
   >
   > 另：`miniBarStyle` 的初始化规则要两条原文合起来读 —— ①「首次创建默认折叠」②「仅 <600vp 生效设置，>600vp 则为展开」。即 **>600vp 时调用方传什么都不作数**，写成 `requested ?? (width > 600 ? expand : collapse)` 会让显式 `collapse` 在大屏生效，与官方相反。折叠态宽度 56 是**自拟**（官方只给展开态 `miniBarWidth`）。
4. 控制器 `applyMiniBarStyle` / `applyHideAnimation` / `applyShowAnimation`。**已完成**：`OhosTabsController`（`ohos_mini_bar.dart`），5 条用例。两个判据：
   > **① 折叠 / 展开与滚动联动是两套机制，别合并成一个状态机。** 前者是一次**离散跳变**（动效只是附庸），后者是**连续位置**（绑的是内容区滚动体，与折叠状态无关）。
   > **② 状态没变就不通知。** 否则每次滚动回调都写一遍同样的值，整棵子树跟着重建，而肉眼什么都没发生。
   > 官方两个 `applyXxx` 收 `mode`（`SCROLL_ANIMATION` / `CLICK_ANIMATION`）却没说它影响别的什么，本库记进 `lastAnimationMode` 当线索。另外 `applyTabBarStyle` 是**本库补的**（官方 `applyMiniBarStyle` 只管迷你栏，页签栏的折叠由用户点它触发），命名与官方对齐但别误当成官方 API。
5. `bindScroller(index, scroller, parentScroller?)` —— 页签与内容区滚动联动。**已完成**：4 条用例。两个要点：
   > **① 只挂只读监听，绝不 `hold()` 或改写 position。** 曾经的写法是 `scroller.position.hold()`，那会让内容区滚动卡住不动 —— 单看 API 签名完全看不出来，只能真滚一次。
   > **② `parentScroller` 只登记、不参与计算。** Flutter 的 `ScrollPosition` 相互独立、没有等价的父子层级；留字段是为了让调用方能照官方签名写，而不是悄悄吞掉一个官方参数。
   > 重复绑同一索引会先解绑旧的那个 —— 否则旧控制器上留着监听、且再没人能解掉。
6. 动效时长走 `policy.scaleMotion` 而非写死。**已完成**：墨水屏返回 `Duration.zero`、栏直接定格；灰阶屏的宽度过渡会拖出一条中间灰带，真机上像「栏没画完」。

子页签（`ChipGroup`）—— 与底部页签同批做，因为它也是 HDS 侧的 tab 家族：

7. `chipGroupSpace` 拆成三段（`itemSpace` 8 / `startSpace` 16 / `endSpace` 16），现有单一 `spacing` 只够表达中间那一段。**已完成**：新增 `startSpace` / `endSpace`，`spacing` 继续对应 `itemSpace`。
8. `chipGroupPadding`（默认 14/14），影响整组高度。**已完成**：新增 `padding`，只取纵向（横向由 `startSpace` / `endSpace` 独占，两者同时生效会让首端变 32），整组高 36 + 28 = 64。
9. `selectedIndexes` 默认 `[0]` —— 包括 `multiple=true` 时。这是**行为变更**，不传就一个都不选中的现状要改。**已完成**：`selectedIndex` 默认 `0`（`multiple` 时走 `_resolvedIndexes`，null → `{0}`），越界/负数按 `getSelectedIndexes()` 的过滤丢弃；传 `-1` 或空集可退回旧表现。
10. `allowClose` + 后缀图标优先级链（`suffixSymbol` > `suffixImageIcon` > `allowClose`，前者存在时后者失效）。**已完成**（与阶段 D-4 同批落地）：`OhosChipItem.allowClose` / `onClose` / `suffixIcon`。

### 阶段 F：半模态面板（5 种形态）—— **已完成**

`bindSheet` 是这一轮唯一「原本标 `●`、实际只做了 1/5」的组件。已全部落地：`ohos_sheet_type.dart`（纯规格层，15 条用例）+ `ohos_bottom_sheet.dart`（渲染层，7 条形态用例）。

**核心判据：5 种形态不是 5 种皮肤，是 5 套能力矩阵。** 上一版只有 BOTTOM，且把「画什么」写死在渲染里（顶部一条描边、无条件画控制条、标题栏必出、圆角固定 `BorderRadius.vertical(top:)`）。只换对齐方式会在这四处同时出错：

| 形态 | 圆角 | 蒙层 | 标题/关闭 | 控制条 | 挡位 | 宽高 |
| --- | --- | --- | --- | --- | --- | --- |
| BOTTOM | 仅上面两角 | 有 | 有 | 有 | 有 | 内容高 |
| CENTER | 四角 | 有 | 有 | 有 | 有 | 480 宽 / 夹取高 |
| POPUP | 四角 | 有 | 有 | 有 | 有 | 同上 |
| SIDE | 四角 | 有 | 有 | **无** | **无** | 固定宽 / 全屏高 |
| CONTENT_COVER | **无** | **无** | **无** | **无** | **无** | 全屏 |

1. 形态枚举与 `type` 参数（`OhosSheetType` 五型全落，含 API 20+ 的 `SIDE` / `CONTENT_COVER`）。**已完成**。
2. 宽度响应式默认值（`OhosSheetSpec.defaultTypeFor`）。**已完成**，5 条边界用例（360/599/600/839/840）。
   > **判据分两处，各自正确、别互相套**：`showOhosBottomSheet` 在建**新路由**时读 `MediaQuery`（调用点拿不到面板自己的约束）；`LayoutBuilder` 场景（如迷你栏）必须用**约束宽度**，分栏时两者不等。
3. `detents` 与控制条。**已完成**：`OhosSheetDetent`（枚举挡位与数值挡位混写）、首挡为初始高度、**生效时 `height` 直接失效**（实测：`height: 200` + 首挡 300 → 得到 300）。
   > **挡位切换是「速度优先」**：速度过 1000px/s 直接按手速方向切挡、**不看距离**；速度不够才退到「位移 > 当前与目标距离的 1/2」。写成「两个条件都要满足」会让快速轻扫（位移小、速度大）被判成回原挡，而真实手感恰恰相反。
4. CENTER / POPUP 高度夹取。**已完成**：最小 320vp、最大窗口短边 90%、`LARGE`/`MEDIUM` 在这两型下**无效**（恒 560vp）。
   > 规格本身有一处冲突：「恒 560vp」与「最大短边 90%」在短边 < 622 时打架。本库选择**照常夹取** —— 让 560 溢出窗口是更糟的结果，且官方夹取条款原文是「大于最大高度则显示最大高度」。已写成显式用例（短边 400 → 360）。
5. 墨水屏描边按形态给边。**已完成**：`CONTENT_COVER` 无蒙层无圆角，`CENTER`/`POPUP`/`SIDE` 四边实线，`BOTTOM` 只顶上一条。
6. 修一处真实偏差：圆角原实现 **24vp**，官方 `SheetOptions.radius` 默认 **32vp**。
   > 24 是 `float.json` 里 `ohos_id_corner_radius_dialog`（**对话框**圆角）的值。同一个「圆角」概念、数值都在 20–30 区间，拿错一个看起来完全合理 —— 与 `gradientMask` / `barBackgroundStyle` 是同一类错误。
7. 修一处漏实现：`LARGE` 挡 / `BOTTOM` 的显式高度**没给状态栏让位**。**已完成**（配图核查轮）：官方公式是「屏幕/窗口高度 − 信号栏 − **8vp**」（`bindsheet` 正文三处 + `bindsheet_16`/`button_39`/`segmentbutton_10` 三张图），旧实现直接顶到窗口顶。
   > `OhosSheetSpec.topGap = 8` + `maxPanelHeight()`；`SIDE`/`CONTENT_COVER` 恒全屏**不减** 8vp（减了会漏白边）。**状态栏高必须取 `View.of(context).padding.top`** —— 调用点常在 `OhosScaffold` 的 `SafeArea` 内，`MediaQuery.paddingOf` 在那里恒为 0，用它等于白改。CENTER/POPUP 有两条上限（短边 90% 与「窗口高 − 状态栏 − 8」），取小。

### 阶段 G：收口

1. README 覆盖表改成「官方形态清单」逐项勾选。**已完成**：6 大类全覆盖，每行按 `✓` / `◐` / `○` / `—` 标形态，并指向 `doc/CONTROL-MATRIX.md`。
   > 同时补了 `tool/check_readme_matrix.py` —— **两份文件是同一事实的两个副本**，矩阵改了 README 没跟上时**不会让任何测试变红**，只能靠脚本兜。脚本用显式 `MAP` 声明 README 行名到矩阵控件名的映射，**不靠子串猜**：「文本」子串会命中「文本框」，把两个不相干的控件混成一个（初版就这么错过）。
   > 脚本已做变异验证：故意给标题栏多打一个 `✓` 会报 `❌ 打了 3 个 ✓，但矩阵里只有 2 个`。
2. 全量截图重拍（浅色 / 深色 / 墨水屏 / 深色墨水屏四档）。**已完成**：`tool/capture_theme.sh <light|ink>` 一轮采到底（8 分类 × 5 屏 = 40 张），共 80 张。
   > **这条目本身暴露了一个真正的缺陷**：重拍时发现墨水屏图里仍有彩色，一度判断为「主题没切」。实际主题切对了（脚本里 `switch_theme()` 会先用平均饱和度探针确认），彩色来自**示例自绘的占位内容** —— 沉浸光感的渐变壁纸、轮播的四色页、动效曲线的填充条、点光源的深底、按压阴影的灰块。这些既不是组件令牌也不是状态表达，`policy` 管不到，**库层测试全绿也拦不住**。
   > 已补 `example/test/ink_no_color_test.dart`（8 页 × 扫全树 `DecoratedBox`）：墨屏下除显式申报的 [InkColorData] 之外，任何非灰实色与渐变都失败。判据迭代过两版 —— 先按「单块面积占比」放行小色块，**变异验证时它放过了真实缺陷**（曲线条是四条 `358×10`，每块只占 1% 屏，叠起来却是一整片彩带）；最终改成「默认必须灰，颜色即数据要显式申报」，并对三处真实缺陷逐一做过变异验证（撤销修复 → 三条测试分别变红）。
   > 构建链另有一坑已记录：`hvigor` 的 `ohpm install` / `SignHap` 都要删除产物，撞上工具的批量删除保护后**报错信息完全指向别处**（`ohpm install failed` / `Error Code: 00308018 Unknown Error`）。绕法是构建时去掉注入的 `NODE_OPTIONS`。
   >
   > **收口补充（归档阶段）**：按 README 的 45 个手选文件名逐张核对时，发现脚本采不到全部内容，补做了三件事：
   > ① **脚本本身有两处缺陷**。`switch_theme` 的词表不匹配 —— 调用方传 `ink`（与 `mode`、目录名、README 一致），主题探针只输出 `gray` / `light` / `dark`，两者永远 `!=`，脚本因此永远判「切不过去」并把主题转走；修法是加 `[ "$want" = "ink" ] && target=gray` 映射，失败时改为直接退出，**不再产出错标主题的图**。顺带纠正一个认知：主题按钮是 **3 态循环**（light → dark → gray → light）而非 4 态，「深色墨水屏」只能在长按菜单里选 —— 脚本的循环在结构上就拍不到它。
   > ② **按分类定屏数**。导航类与 `UI Design Kit` 的区块数超过 5，原先 `kit_09` / `kit_10` 都拍成了同一个常驻通知；改成这两个分类各采 11 屏，并支持 `./tool/capture_theme.sh <light|ink> 导航类` 只补采指定分类。
   > ③ **交互态只能现场操作**：弹层 / 放大镜 / 菜单 / 转场脚本采不到。`uinput -M` 的「按下 / 移动 / 抬起」三步可**分离执行**，能在按住状态截到索引条放大镜与自定义泡泡；`uitest uiInput drag` 则用「后台起拖 + 定时截图」卡拖拽中间帧（色带放大镜、共享元素转场）。
   >
   > **这一轮又抓到一个真缺陷，而且是「同一个坑的第二次发作」**：墨屏弹窗的标题与正文在真机上各带**两条黄线**（截图实测 5340 个 `#FDFE53` 级黄像素）。根因是弹窗挂在 Navigator 的 Overlay 上、**没有 `Material` 祖先**，文字退到 `DefaultTextStyle.fallback`（`#FFFF00` + `double` 下划线，专门用来标记「这段文字没有任何样式来源」）。`ohos_popup.dart` 的注释里早就记过同一个坑，但当时只修了 Toast 一条路径，**没有回头查「还有谁挂在 Overlay 上」**。顺着这条线索又发现 `OhosButton` 的 `decorationColor: underline ? foreground : null` —— `DefaultTextStyle.merge` 只覆盖非 null 字段，`null` 是「不表态」而非「清空」，祖先的颜色因此漏了下来。两处都已修，并把原来用 `isNot(红色)` 写的弱断言改成强断言 `Colors.transparent`（`null` 也能通过前一种断言），做过变异验证。
   > **方法教训**：这三个缺陷（示例彩色、弹窗黄线、按钮 decoration）有一个共同点 —— **静态分析全绿、单元测试不报错、只在特定主题或特定祖先链的真机上显形**。「补全截图」这个动作不只是产出文档素材，它是唯一能把这类缺陷逼出来的检查手段。
3. `example` 溢出矩阵扩到新组件。**已完成**，且发现了原矩阵的**真实盲区**：它只扫**页面本身**，而弹层（半模态 / 菜单 / 弹出框 / 选择器 / Toast）是在**新路由**里建的 —— 页面上那个触发按钮扫一万遍也不会让面板布局跑一次。新增 `example/test/overlay_overflow_test.dart`：10 种弹层 × 3 尺寸 × 3 字号 = **90 条**（半模态 5 形态 + detents + 对话框 + 菜单 + Toast + SnackBar）。
   > 写这组用例时踩了一坑并已记录：`showOhosToast` 的自动关闭定时器没推完，测试以 **「Pending timers」** 失败 —— 那个报错里没有 `overflowed` 字样，看起来像布局问题、实际只是收尾没做。修法是收尾 `pump(4s)` 走完定时器。
4. 版本 0.6.0，`CHANGELOG.md` + `CHANGELOG.OpenHarmony.md` 双份。**已完成**：`pubspec.yaml` 0.5.0 → 0.6.0，两份 CHANGELOG 按各自既有格式（前者平铺条目、后者 `Features`/`Bugfix`/`Breaking changes`/`Optimization` 分节）写入同一批事实。

---

## 五、贯穿全部阶段的约束

1. **组件层不判断具体主题类型** —— `lib/src/widgets/` 不得出现 `OhosThemeMode.` / `isMonochrome` / `.monochrome`，新组件同样受这条静态扫描约束。
2. **新增值对象必须实现 `==` / `hashCode`** —— `OhosGauge` 的色段、`OhosSelectionMenuAction` 都属此类，否则 `OhosTheme.updateShouldNotify` 静默失效。
3. **多色 ≠ 灰阶可读** —— 9 段渐变 `quantize` 后全部变同一档灰。数据可视化在墨水屏上必须改「段间留白 + 1px 实线」，这也是不能直接复用 Material 多色实现的原因。
4. **`test/theme_extension_test.dart` 必须继续通过** —— 它是「加主题不改组件」的唯一可验证形式。
5. **每个形态都要有能变红的测试** —— 断言落在「真的画出来了」，不是「字段存在」。例如 `ScaleRing` 要断言刻度线数量，不是断言 `type == scaleRing`。
6. **示例代码要能对着官方示例逐条数** —— 参考文档每个组件有 3–32 个示例，收口时统计「官方 N 个示例，本库示例覆盖 M 个」，M<N 的要说明理由。

---

## 六、需要先决定的四件事

1. **屏幕取色**：纯 Flutter 读不到系统级像素。建议 (a) 只从当前 Flutter 页面截图取色 + 文档注明差异，而不是走平台通道。补充依据：`HdsColorPicker` 文档**没有**这个能力，它只有 `GRID`/`SPECTRUM`/`SLIDERS` 三个 tab，屏幕取色只出现在设计规范里 —— 连系统组件都没做。
2. **`OhosDataPanel` 破坏性重写**：旧构造语义（KPI 卡片网格）与官方（占比/环形数据图）完全不符，无法兼容。可给旧构造挂 `@Deprecated` 保留一个大版本，但类名与官方语义不符会再多挂一个版本。
3. **`OhosActionBar` 破坏性重写**：这是新发现的第二处编译期破坏。官方是 `startButtons` / `endButtons` 两端数组，现有是单一 `secondaryActions` 且全部落在主按钮左侧 —— 语义不同，无法在保留旧参数的前提下加出来。选项：(a) 0.6 直接改（在一次破坏里把 DataPanel 和 ActionBar 都换掉）；(b) 新增 `OhosActionBar.v2` 类过渡一个版本。倾向 (a)：两个破坏集中在同一个版本，比分散在两个版本各痛一次好。
4. **`OhosPicker` 范围**：滚轮 + 时间日期 + 月历，月历工作量约等于前两项之和。是否本轮只做前两项，月历推 0.7？

---

## 七、本轮工作留下的方法教训

三轮「补查文档」各暴露了一类问题，值得写进流程而不是只写进这份规划：

1. **只读设计规范会读错形态数**（滑块双值、进度条 3 种、分组样式自拟）—— 设计规范说「有什么、怎么用」，不说「枚举有几个值、默认值是多少」。
2. **改抓 OpenHarmony 仓库解决了开源组件，但把「HDS 闭源」误当成「HDS 无文档」** —— 这是一个**基于类比的推断**（不在开源仓库 ⇒ 没有文档），而它恰好是错的。教训是：找不到文档要写「我试过哪些路径，都失败」，而不是写「不存在」。本轮实际试过的 404 路径记在 `doc/reference/README.md`。
3. **矩阵里写「无文档」会污染下游判断** —— 一旦标成「无文档」，规格就自动降级为「按截图猜」，规划里随之出现「侧边布局」这种把设计规范四个字直接当参数名的假需求。文档一到手，真实轴是 `isHorizontal`，与「侧边」不是一回事。
4. **第四轮的根因是「猜 slug」这个动作本身** —— 前三轮的教训都指向「去补查文档」，但补查的方式仍是猜名字：猜中就算有、猜空就算没有。而猜空有两种可能（真无文档 / 名字没猜对），这个动作**无法区分它们**，所以它给出的「没有」在结构上就不可信。改成从官方链接反查（`tool/trace_control_docs.sh`）之后，同一次排查立刻多出 4 份文档，其中 1 份是子页签的主文档。**结论：不要用「搜索是否命中」来证明「不存在」，要用「权威索引里是否列出」来证明。** 更隐蔽的一层是抓取表本身也会漏 —— `Chip` 与 `ChipGroup` 是两个组件，表里只写了一行，看起来「子页签已覆盖」，实际主文档从未入库。差集（官方清单 − 已有快照）应当作为固定动作，而不是靠人眼比对。
5. **「文档里没有」≠「没有规格」** —— 源码层第一次核对就推翻了一条：`EditableTitleBar` 在参考文档里确实查不到（三个 slug 变体全 404，`HdsNavigation` 也无对应章节），但 `editabletitlebar.ets` 一直存在且规格完整（56 / 20vp / 14vp / 0.65 / 0.35）。这与第 2 条是同一个错误模式的第二次发作 —— **都是在某一层找不到，就断言在那个层所指的整个对象上不存在**。对策是把「哪一层缺」和「缺什么」分开记：`confirmedAbsent` 必须写明限定范围（这里是「参考文档」而非「规格」），否则下游会照旧降级为猜测。
6. **进入第四层（源码）之后，「猜名字」的错误仍在重复** —— `gridobjectsortcomponent` 的文件名是 `GridObjectSortComponent.ets`，试「首字母大写」也 404（它是全驼峰）。同一个动作在三轮里被纠正两次、第三次又犯。**根因不是不细心，而是「从一个已知名推出另一个名」这个动作本身就不该存在** —— 只要有目录/索引可列，就应该列，而不是推。第四轮（找 `search_theme.h`）又出现了同型的一次：guessed 路径 `components_ng/pattern/search/search_theme.h` 是 404，真实位置在 `components/search/search_theme.h`。唯一值得写下来的是这次**靠「先列目录」当场发现**，没有把「search 没有 theme 文件」写进文档。
7. **「二进制所以解不出」是第 2、5 条的第三次发作** —— 上一版明确写下「`resources.index` 是 RestoolV2 二进制、本机解不出，不打算逆向（版本一升就失效）」，并据此把 `Search` 等组件的尺寸标为不可得。这段话读起来像审慎判断，实质是**在错误的位置停止了搜索**：`resources.index` 不是需要逆向的私有格式，它是 `global_system_resources` 仓库中 `element/*.json` 的编译产物，源文件就在公网。真正的分界线不是「能不能解二进制」，而是「有没有先去确认这个二进制是不是别人生成过的产物」。
   - 同一模式的三次发作可以并成一句话：**「我在 X 处找不到」不等于「它不存在」，因为 X 可能根本不是它该在的地方。** 第 2 条 X = 开源仓库，第 5 条 X = 参考文档，本条 X = 二进制文件。每次都能给出看起来很专业的理由（不在开源仓库、没有对应章节、是私有格式），而每次正确的动作都是同一个：**换一层找，而不是宣布没有。**
   - 附带一个纯技术的坑，值得记：资源解析是**三层**（`pattern.json` → `float_sys.json` → `float.json`），而 pattern 层与 float_sys 层的键**同名**（都叫 `search_default_height`）。在 pattern 里递归回查会自引用成环，输出一长串 `-> $float:x -> $float:x`。第一版解析器就是这么错的。**看到别名链指向自己，先怀疑查错了层，别怀疑数据。**
8. **第四层的第二次：`GetAttr` 只证明「读进了字段」，不证明「字段被用了」** —— 上一版从 `search_theme.h:71` 读到 `theme->leftPadding_ = pattern->GetAttr("search_text_field_padding_left", 0.0_vp)`，就断定「官方输入区左 padding = 4，本库 12 多了 8」，并据此写进了矩阵、ROADMAP 和阶段 D 任务。第二次读源码时去查调用方：`GetLeftPadding()` 在**整个 `search/` 目录零调用方**（`search_pattern.cpp`、`search_layout_algorithm.cpp`、`search_model_ng.cpp`、`search_text_field.cpp`、`search_pattern.h`、`search_layout_property.h`、`search_node.cpp` 逐个 grep 过），是旧框架 `frameworks/core/components/search` 的遗留字段。真正的水平几何在 `LayoutSearchIcon` / `LayoutTextField`（`search_layout_algorithm.cpp:738` / `:929`），用的是 `search_icon_left_space`(12) + `search_icon_right_space`(8) —— 本库的 12 本来就是对的。
   - 与第 7 条是同一个方向上的递进：第 7 条错在「没换层」，本条错在「换了层但**只看了半层**」—— 从令牌表跳到了头文件，就以为到了终点。**令牌被读进字段 ≠ 字段被用；判「官方值是多少」必须再往下追一层调用方。**
   - 附带发现：`GetRightPaddingWithoutButton` / `WithButton` 是**有**调用方的（`:223` / `:227`），但它们只参与「算 textField 可用宽度」，也不是盒内 padding。所以不能靠「有没有调用方」一刀切，得看**用在哪一环**。

9. **统计命令本身也要验证，不能只看某一类像不像** —— 矩阵末尾那条 `awk` 复核命令写的是
   `if($0=="")print "完整"; else if(~/^○/)... else if(~/^◐/)... else if(~/^●/)...`。
   「完整」行的实现列里**有内容**（就一个类名，如 `` `OhosButton` ``），`$0==""` 永远不成立，
   于是 62 行完整项全部落到四个分支之外、被 `awk` 静默丢弃。当时看到的「57 / 15 / 100 / 2 合计 174」
   里，57 是从 174 减去另外三类**扣出来的**，不是数出来的 —— 真实值 62，`◐` 也不是 15 而是 9。
   `awk` 对未匹配的输入不报错，只是不输出，这比报错危险得多。
   **对策：`else` 兜底必须指向一个明确的类别，并且每次都要校验「各类之和 == 行数」**（`62+9+100+2 = 173` ✓）。
   这条命令现已改成兜底 `print "完整"`，并在文件里写明了这个坑。

10. **同一条教训在同一个文件里又犯了一次：复核命令自己多跳了 2 行** —— 修好 `else` 兜底后，命令前面还留着
   `sed -n '3,$p'`，那是更早版本为了跳过表头写的。可表头两行**已经被 `!/^\| 控件 /` 与 `!/^\| --- /` 滤掉了**，
   这一步等于把矩阵前 2 行数据一起丢掉。
   危险之处在于它**看起来完全正常**：合计 175、`○` 92、`●` 2、`◐` 8、完整 73 各自都像个正常数字，
   只有相加才发现 92+2+8+73 = 175 —— 咦这次是对的，因为我是先发现「和 != 行数」再回头找原因的。
   上一版没有相加那一步，于是「各类和 173 / 合计 174 / 差值 1」被当成了「有一行状态写成了 `—`」，
   真实原因是**管道丢掉两行、同时又有一行状态异常**，两个错误互相掩盖。
   **对策：复核命令也纳入「验和」流程；改矩阵行数时先跑一遍命令看和是否等于 `grep -c .`，差值非 0 就直接停下来查管道。**

11. **「同一个值在两个组件里各管一遍」是本仓库反复发作的根因，这次是第三次** ——
   前两次是 `OhosChip` / `OhosChipGroup` 的描边与尺寸；这次给 `OhosChipGroup` 补 `chipGroupPadding`(14/14) 之后，
   `OhosTabBar` 的胶囊模式把它套在固定 48 高的 `SizedBox` 里，芯片被压到 20 高、点击落在裁剪区外 ——
   `capsule tab bar switches pages` 用例当场变红。**这个失败不是新写的代码错了，而是旧代码一直在重复计算**，
   只是以前两边都缺这个值、错得一致，所以看不出来。
     - 落法：跨组件复用的常量一律放 `theme/`（如 `OhosChipMetrics`）；**「谁负责这段几何」要能一句话说清**，
       说不清就是两边都在管。页签场景下答案很明确：页签是「条」，两端与内边距归 TabBar，芯片组只负责中间那颗的距离。
     - 另一个同源的缺陷是一起被用例逼出来的：`_scrollableStrip` 的 `Align(centerLeft)` 缺 `heightFactor`，
       在松高度约束下取 `maxHeight`，一排芯片在页面里撑成整屏 600 高的空白块。**旧代码里的缺陷，只有新用例才逼得出来** ——
       这也是为什么「补形态」必须配「补断言」，只改实现的话，这类问题会一直静默存在。

可执行的落法：
- `doc/reference/sources.json` 里的字段只允许记录**逐个试过的 slug 与其返回码**，不允许写「该组件无文档」这种结论式表述；确实缺的分两类记（`noDevDocLink` = 官方漏给链接但文档存在 / `confirmedAbsent` = 多个变体全 404），且 `confirmedAbsent` 必须限定层级（「参考文档缺失」不等于「无规格」）。
- 每次调整抓取表后，跑 `tool/trace_control_docs.sh` 取权威清单，与 `doc/reference/api/*.md` 做差集；差集非空就是漏抓。
- 抓源码用 `tool/fetch_source.sh`，它靠列举目录取真实文件名，不接受「按目录名推文件名」。
- 抓数值用 `tool/fetch_sys_resources.sh`，它从 `pattern.json` → `float_sys.json` → `float.json` 解析别名链。**任何写进文档的尺寸都必须能在这个脚本里复现**，否则就是自拟值。
- **判「某个令牌是否生效」时必须 grep 调用方**，不能只 grep `GetAttr`。命中 `GetXxx()` 定义不算证据，要看有没有人调用它、以及调用点落在布局/绘制的哪一环。
- 矩阵里不给「无依据的 `●`」，也不给「无依据的数字」。这一轮清掉的两个 `●`（半模态、子页签）都不是实现退步，而是**从来没对过**：一个只做了 5 种形态里的 1 种，一个连主文档都没抓过却标着完整。新增的反向约束：**写进「依据」列的数值全部要能追到令牌名或源码常量**，本库自己的取值（如 chip 高 32）不能出现在「依据」列。
- 矩阵统计每次改完必须跑文件末尾的复核命令，并**手工验一次「各类之和 == 合计」**。数字对不上时先怀疑命令，别急着信输出。

10. **死令牌不是孤例：`search_height` 是同一次排查里的第二个。** 上一版把 `sys.float.search_height` = 56 写成「带搜索按钮时的整栏高」，并据此在阶段 D 排了任务。为落地那条去核实时发现：13 个 `search/` 源文件里 `grep -rn search_height` **零命中**；`SearchTheme::height_` 只有一个赋值来源（`search_default_height` = 40），`GetHeight()` 的 5 个调用点读的都是它；官方 30 个示例里配了 `.searchButton()` 的 3 处**全都写 `.height(40)`**。
    - 关键在于**它被定义、被编译进 `resources.index`、也能被 `GetAttr` 读出 56** —— 一切看起来都像「生效」，只有调用方那一层是空的。这与第 8 条是同一个形状，区别是这次**在动手写代码之前**就拦住了，而不是写完再回头改。
    - 所以第 8 条那句「判官方值必须再追一层调用方」不是一次性的补丁，而是每次读令牌都要走的固定步骤。**pattern 表里有值 ≠ 实现里在用**；「这个令牌叫什么」和「这个令牌有没有人读」是两个独立问题，后者只能靠 grep 回答。
    - 附带一个好用的交叉验证：**看官方示例里怎么写死尺寸**。示例是给人抄的，作者会把生效值直接写出来；如果示例里的 `.height()` 与某个令牌对不上，多半是令牌没被用，而不是示例写错了。