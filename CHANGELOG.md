## 0.6.0 (unreleased)

Release date: TBD

- 新增：`OhosListGroup` + `OhosListGroupSliver` —— 补齐 ArkUI `ListItemGroup` 的分组能力：`style: none|card`、`header` / `footer`、`space`、`divider`，以及**吸顶组头**。**先拆清了 `sticky` 的归属**：它写在 `List` 的属性章节（`ts-container-list.md`），`StickyStyle` 枚举也在那一页 —— 这不是文档排版失误，是规格事实：一次管住列表内所有分组。Flutter 侧的「吸顶」是 sliver 行为（`PinnedHeaderSliver`），盒子形态根本无处可吸，所以拆成两个类，`sticky` **只出现在 `OhosListGroupSliver` 上** —— 盒子形态传了会得到一个「传了但没反应」的开关，那比不支持更坏。粒度上本库逐组声明、官方整表一次，逐组能表达的集合严格更大（每组可各选吸顶或不吸）
- 修复：吸顶组头**必须自带背板，而文档完全没提这件事**。`PinnedHeaderSliver` 只负责把子节点钉在视口顶端、不负责遮挡 —— 照文档做会得到一个浮起来却透明的组头，下面的行从它身上穿过去。真实规格在源码 `ListItemGroupPattern::ApplyHeaderFooterStyle`（`list_item_group_pattern.cpp:900`）：先 `UpdateBorderRadius(GetItemGroupDefaultBorderRadius())` 补分组圆角、再套 `UiMaterial::IMMERSIVE / THICK` 沉浸材质，本库对应 `OhosLightMaterial(level: OhosLightMaterialLevel.thick)`。这类「文档只讲交互、不讲视觉」的缺口，四层对照里只有第四层能补
- 文档：**卡片样式的三个数分处三个来源，复核方式因此不同**。`cardMargin = 12` 走资源表（`ohos_id_card_margin_start` / `_end`，经 `list_item_pattern.item_margin_left/right` 指向，`float.json` 两值都是 `12.0vp`）；`cardPadding = 4` **只在文档正文**（「卡片样式下…上下左右内边距 4vp」），资源表无对应令牌；`cardRadius = 24` 走 `list_item_pattern.item_border_radius` → `ohos_id_corner_radius_default_l`（`24.0vp`）。行级 CARD 的 **48 / 8** 同样只在正文（「高度 48vp、宽 100%、左右内边距 8vp」）—— 五个数里只有三个能跑 `fetch_sys_resources.sh` 复跑，另外两个只能对文档
- 新增：`OhosListGroupItemStyle`（行级 CARD）与 `OhosGroupDivider`。**`group.style` 与 `itemStyle` 是两个独立参数**，可自由组合 —— 官方示例 2 里 `CARD+CARD` / `CARD+NONE` / `NONE+CARD` 三种组合都出现过，合并成一个「外观档」会表达不了。**`space` 只作用于项与项之间**，不作用于组头与首行、末行与组尾（官方明文，也是最容易和「给每行加 padding」混淆的一条），用例把「组头→首行 8 / A→B 20 / 末行→组尾 8」三种距离分别钉住。**分组的 `divider` 默认 `null`（一条不画）**，与 `OhosList.divider: bool`（默认 true）**相反**；组接管分隔线后用 `OhosListDividerScope` 把行内 tile 自带那条压掉，避免双线
- 文档：**主动放弃吸底组尾（`Footer` / `BOTH`），标 `○` 而不是留一个不可靠的实现**。写过一版，用 `remainingPaintExtent` 推「视口末端距本 sliver 多远」，实测该值在 `SliverMainAxisGroup` 内部已被同组前面的子 sliver 扣掉、且滑出视口时被夹到 0 —— 「组尾原来在视口下方多少」这条关键信息恰好在需要它时丢失，吸底链会算成「原地不动」。换 `precedingScrollExtent` 与视口滚动量之差方向是对的，但同样拿不到视口自己的滚动量，仍是猜的。宁可留缺口 + 一条钉住缺口的用例（组尾应 `findsNothing` —— 它落在视口外根本没被构建，真吸底了就一定被构建），也不留一个「多数情况看着对、滚到某些位置就错位」的实现
- 文档：矩阵「列表」由 **4 行拆成 11 行**，统计重算为 **227 行 / 完整 145 / `◐` 7 / `○` 72 / `●` 2 / `—` 1**（`145+7+72+2+1 = 227` ✓，命令连跑两次一致）。新增的 6 行完整是「组头/组尾 builder」「`space`」「组内分割线」「组卡片」「项卡片」「吸顶组头」；另有 1 行 `○`（吸底组尾）、1 行 `—`（`childrenMainSize` 在 Flutter 无对应需求 —— ArkUI 的 `List` 需预声明子项尺寸才能精确跳转，`SliverList` 逐项测量）。复核脚本同时补上 `—` 分支，否则它会掉进 `else` 被算成「完整」。用例数 471 → **491**（`OhosListGroup` +13、`OhosListGroupSliver` +7）
- 新增：`OhosProgressIndicator` 补齐 `Eclipse` / `ScaleRing` / `Capsule` 三型（此前只有线性与环），`OhosLoadingIndicator`（LoadingProgress 的彗星拖尾动效）。**五种形态不是五种涂装，是三种度量** —— 线性/胶囊量**长度**、环/刻度环量**角度**、月相（Eclipse）量**面积**。把月相当扇形画（「从 -90° 扫 `value×360°`」）三档端点会全错：实测 `Path.contains` 采样 `0 → 0,0,0,0,0`、`0.5 → 1,1,0,0,0`（**整个左半圆**，不是零也不是一半）、`1 → 1,1,1,1,0`。源码 `PaintMoon` 是「左半圆 + 一条宽度随 `value` 变的椭圆弧」走非零环绕：`value ≤ 0.5` 时椭圆弧**逆时针**（与左半圆反向 ⇒ 相减出月牙）、`> 0.5` 时顺时针（同向 ⇒ 相加补右半圆）
- 修复：**刻度环的进度靠换色，不靠刻度变多** —— 源码先整圈用背景色画 120 个刻度，再用前景色覆盖前 `angle` 弧度那一段。照「沿长度填色」的直觉做会画出一条越来越长的弧，这是这批里最容易做反的一条，用例直接钉「刻度数恒为 120，只有颜色分段变化」
- 文档：**`ScaleRing` 的「默认宽高最小 77vp」不是随手取的数，是 `scaleCount` 上界的反解**。刻度数按键值范围 `[2, min(w,h)/scaleWidth/2/π]`：直径 72（半径 36）+ 120 刻度 + 宽 2 ⇒ 间距 1.88 < 2 ⇒ 退化；77（半径 38.5）⇒ 2.02 > 2 ⇒ 正好越过临界。用例把 36 / 38.5 两个半径的判定都钉住了。另两个陷阱：`DEFAULT_CAPSULE_BORDER_WIDTH = 0.0` 与 `progress_border_width = 1vp` **同名反值**（前者是绘制函数形参的兜底、后者才是进到组件里的主题令牌，照前者写会少一圈内描边）；`Path.getBounds()` **不能量填充面积**（它把弧的控制点也算进包围盒，于是 `eclipse(0)` 与 `eclipse(0.25)` 给出同一个矩形 —— 必须用 `Path.contains` 采样）
- 文档：矩阵统计口径重算为 **219 行 / 完整 139 / `◐` 7 / `○` 71 / `●` 2**（`139+7+71+2 = 219` ✓，命令连跑两次一致）。进度条与加载动效由 **6 行拆成 18 行**（+12），其中 4 行 `○` 全部转完整、另新增 12 行完整。用例数 444 → **471**（进度条 +21、加载动效 +6）
- 新增：`OhosDateCounter` + `OhosDate` —— 补齐 ArkUI `CounterType.INLINE_DATE`（日期型内联 Counter）。**刻意不用 `DateTime`**：官方的日期计数器不是时间点，是三个各自以不同方式回绕的数字 —— 年**夹取**在 `[1, 5000]`（到边界按钮就死）、月**回绕**但不进位到年（`12 + 1 = 1` 且年份不变）、日**回绕**按当月实际长度（`2024-02-29 + 1 = 02-01`，不是 3 月 1 日）。`DateTime` 会把 `2024-01-31 + 1 月` 悄悄进位成 `2024-03-02`，与组件行为完全不符。换月后日超长要**收敛到月末**（`updateDay()`：1 月 31 日切 2 月 → 2 月 29 日），这条单独抽成 `_clampedDay` 并有用例钉住。几何全部来自 `counter.ets` 的 `COUNTER_INLINE_*` 常量而非文档那句「32vp」概括：容器高 **32**、圆角 **8**（不是 `height/2`）、1vp 描边、日期组 **92**（年 38 + `/` 8 + 月 19 + `/` 8 + 日 19）、段输入高 **20**、箭头列 **32**。**两处有意偏离**：①每次都回调 `onChanged` —— 官方只在三个 `TextInput.onChange` 里调 `onDateChange`，按箭头改完数字**不通知应用**，那个组件实际上是只写的，照搬会让它无法被 Flutter 的 `setState` 驱动；②不做 1500ms 回退定时器 —— 官方给每段挂一个定时器让半截输入 1.5 秒后弹回，这里改成「失焦即弹回」，终态一样，但不会有 widget 被 dispose 后还活着的定时器
- 修复：`OhosDateCounter` 的箭头两半**不能按官方的 16+1+16 写**。官方 `COUNTER_INLINE_BUTTON_HEIGHT` 是 16，两个 16 加 1vp 分隔线是 33，比 32 的容器还高 —— 在 ArkUI 里成立是因为它的容器边框不占内容区，而 Flutter 走 `ohosBorderSide` 的 `strokeAlignInside`（描边画在盒内），内容区只有 30。第一版照抄常量，`flutter test` 里 12 条用例**全部**因 `RenderFlex overflowed by 2.0 pixels` 一起变红；改用 `Expanded` 平分后正常。这个偏差只在写测试时才暴露，`flutter analyze` 完全看不出来
- 修复：`OhosDateCounter` 点箭头会先**夺走焦点**再执行 —— `TextField.onTapOutside` 在 tap 落到箭头上时先把段失焦，于是「当前作用于哪一段」若读实时焦点，读到的永远是「无焦点」→ 回落到日，表现为「点了年份按上箭头，加的是日」。改为记住**最后聚焦的段**（`_lastField`）。ArkUI 没有这个竞态，它的箭头是键盘驱动的、焦点不会掉。这是第二个「官方行为照搬不过来」的地方，性质与上面第 ① 条相同：不是官方错了，是宿主平台的输入模型不同
- 新增：`OhosDateCounter` 的段内直接输入（满位提交、越界整段回退）、聚焦段底色反转（彩屏品牌蓝 + 白字、墨屏黑块 + 纸色字，**同一个分支**，因为墨屏的 `highlightColor` 本来就是纯黑 —— 这正是「策略该问怎么读得懂、不该问有没有某种能力」的一个正面例子：这里连 policy 都不用问）、`enabled: false` 时整体降到 40% 不透明且按钮失效。`upIcon` / `downIcon` 默认给 `Icons.keyboard_arrow_*`（`lib/` 不依赖任何图标包），示例页传官方 `OhosIcons.arrow_up` / `arrow_down`
- 文档：矩阵统计口径重算为 **193 行 / 完整 91 / `◐` 7 / `○` 93 / `●` 2**（`91+7+93+2 = 193` ✓，命令连跑两次一致）。数字加减由 **2 行拆成 9 行**：原「日期（DateStyle）」行由 `○` 转完整，另新增 7 行（5 行完整、2 行 `○`）。顺带改掉上一版把依据写成 `CounterType` 的表述 —— 那是类型枚举本身，真正的日期形态是 `CounterType.INLINE_DATE` + `DateStyleOptions`。用例数 315 → **335**（`OhosDate` +9、`OhosDateCounter` +11）
- 依赖：示例工程的图标包由 `ohos_icons` 迁移到 **`harmony_icons`**（`ohos_icons` 已改名，旧包在 pub.dev 标记 discontinued）。**类名不变，仍是 `OhosIcons`** —— 两包导出同一套 534 个 Symbol 常量，逐个比对只差两处笔误修正（`chevron_down_` → `chevron_down_L`、`chevron_up_` → `chevron_up_L`），本库用到的 `chevron_right` 不受影响。迁移是纯包名替换：`example/pubspec.yaml` 一行 + 8 个示例页的 import，零代码改动。`lib/` 本身不依赖任何图标包（图标一律由调用方从 `icon` 参数传入），所以这是**只影响 example 的改动**，库使用者无需做任何事
- 新增：`OhosPageIndicatorType.digit`（数字型导航点）+ `OhosSwiper(indicatorType:)` —— 补齐 ArkUI `DigitIndicator`。显示 `当前/总数` 且**从 1 起数**：`currentIndex` 是 0-based，直接拼进文案会显示成 `0/3`。字号 14fp / **w400**（`digitFont` 默认 `{size: 14, weight: Normal}`），当前页与总数**只差颜色**、不加粗不放大 —— 这与圆点「沿主轴变宽」是两种完全不同的强调方式。`count == 0` 时两侧都显示 0：`clamp` 前会算出 1，凭空冒出「第 1 页」比 `0/0` 更让人以为数据错了
- 新增：`OhosSwiper(showArrows:)` —— 补齐 `displayArrow` / `ArrowStyle`。默认 **`false`**，照官方默认值；底板 32、箭头取底板 3/4、底板色 10% 黑（`isSidebarMiddle: true` 那一档），上色走 `policy.tint` 而非直取彩屏色。**只有一页时不画** —— 官方写明「Swiper视窗内显示所有子节点时…左右翻页箭头均不显示」，即使显式打开了 `displayArrow`
- 修复：`OhosPageIndicator` 圆点尺寸对齐官方，**三处全偏**：未选中 8×8 → **6×6**（`itemWidth`/`itemHeight` 默认）、选中 8×16 → **12×6**（`ohos_id_swiper_indicator_selected_size`）、间距 6 → **8**（`space` 默认 / `ohos_id_swiper_indicator_point_padding`）。其中形状修正是重点：旧实现把选中点做成 8 宽 16 高（竖直胶囊），而官方是**沿主轴变宽、高度不变** —— 两个官方示例分别写 `itemWidth(8).selectedItemWidth(16).selectedItemHeight(8)` 与 `selectedItemWidth(15).selectedItemHeight(15)`，改变的都是宽度
- 修复：`OhosPageIndicator` 的点间距从每颗点自带 `margin` 改为 `Row.spacing`。`margin` 会被算进点自身的尺寸（6 的点量出来是 14），还会把点击/命中区一起撑大；而官方的 `space` 语义是**点与点之间**的距离，不是点的外扩。这个 bug 是新写的「未选中点 6×6」用例逼出来的 —— 断言 `getSize(dots.at(0)).width` 时拿到了 14
- 文档：**记录一处必须写清的数值冲突**。参考文档说 `DotIndicator` 的 `itemWidth` / `itemHeight` / `selectedItemWidth` / `selectedItemHeight` 默认值**都是 6**，而系统资源表有独立的 `ohos_id_swiper_indicator_selected_size = 12`（另有 `_size` = 6 对应未选中档），且官方所有示例的选中宽度都大于未选中宽度。本库取 12 —— **依令牌与渲染形状，不依那句散文**；文档里那四个 6 极可能是把第一行复制了四遍。这与 `search_height` / `search_text_field_padding_left` 不同：那两个是「令牌存在但零调用方」，这个是「文档值自相矛盾」，要按证据链而不是按字面选
- 文档：矩阵统计口径重算为 **186 行 / 完整 85 / `◐` 7 / `○` 92 / `●` 2**（`85+7+92+2 = 186` ✓，命令连跑两次一致）。导航点由 3 行拆成 8 行：「数字」「箭头」两行由 `○` 转完整，另新增 3 行记 `○`（超长显示 `maxDisplayCount`、蒙版 `mask`、任意位置 `left/top/right/bottom`）。用例数 306 → **315**（`OhosPageIndicator` +5、`OhosSwiper` +4）

- 新增：`OhosVisualPolicy.selectionMark` + `OhosSelectionMark { tint, inverse, emphasis }` —— 主题策略层新增一项能力：**「一组互斥项里当前是哪一项」该怎么让读者看出来**。与既有的 `litFill` 分工不同：那个管「点亮一个小图标」（开关、星标），答案必然是一抹颜色；这个管的场景里，颜色可能根本不可用。根因是墨屏 `OhosThemeData.ink()` 里 `highlightColor == textPrimaryColor == 纯黑`，所以「选中 = 换成品牌色」在灰阶屏上**等于什么都没做**。`tint` 是彩屏默认（换 `highlightColor`）、`inverse` 是墨屏（实底 `highlightColor` + `onHighlightColor` 反白）、`emphasis` 留给高对比主题（加粗 + 描边，不依赖色相）。**这是「可供性 vs 能力」那条设计的延续**：问题不是「有没有高亮色」，而是「这块屏怎么表达才读得懂」。首批只迁移了 `OhosToolbar`；`OhosNavigationBar` / `OhosTabBar` 有同样的取色方式但**尚未迁移** —— 它们另有胶囊底与下划线作第二条线索，不是当前最高优先级
- 行为变更（**破坏性**）：`OhosToolbarItem.selected: bool` → `state: OhosToolbarItemState`。旧字段把两件事压进一个布尔 ——「允不允许成为当前项」（官方逐项 `ItemState.ACTIVATE`）与「现在是不是当前项」（由 `activeIndex` 决定），于是可以写出「禁用 + 已选中」这种官方不存在、界面上是「一块蓝但点不动」的方块。新枚举 `{ enabled, disabled, activated }` 对应 `ItemState` 的 `ENABLE=1` / `DISABLE=2` / `ACTIVATE=3`，dartdoc 明确写「三值**不是**互斥开关，而是能不能点 / 允不允许激活两条维度」，避免调用方写出 `enabled && activated` 这种恒假判断。`OhosToolbarItem` 新增 `enabled` 派生 getter
- 新增：`OhosToolbar.activeIndex` / `moreLabel` / `moreIcon` / `onMorePressed`，并把官方几何全部对齐 —— 栏高 `DEFAULT_TOOLBAR_HEIGHT` **56**（**不含**分割线，整条 57）、图标 `IMAGE_SIZE` **24**、图标与文字间距 `padding_level1` **2**、标签 `ohos_id_text_size_caption1` = **10fp**/w500、圆角 `ohos_id_corner_radius_clicked` **8**、侧边距 `padding_level12` **24**。**标签是 10fp 不是 12fp**：放在 14/16 的字阶旁边显得过小，但这就是官方值，Material 的 caption 是 12，直接换过来会整条偏高。**激活态是双条件** —— `toolbar.ets` 的 `getIconColor()` 是 `activateIndex == index && state == ACTIVATE`，只给 `activeIndex` 指向一个 `ENABLE` 项**不点亮任何东西**（官方行为里最像 bug 的一处，已用用例钉住）。**收纳**：`TOOLBAR_MAX_LENGTH = 5` / `moreIndex = 4`，超过 5 项时前 4 留在线内、第 5 格变「更多」，默认走 `showOhosMenu<int>`，`value` 用**原始下标**（调用方拿到直接对自己 `items` 取值，不必再补 `_moreIndex`）。**侧边距条件是 `items.length < 5`，不是 `<=`** —— 正好 5 项时官方按 0 内边距均分铺满，而 6 项收纳后也是 5 格；写 `<=` 会让 5 项那档突然缩进 24，与收纳后的那档对不齐。**常态色从 `textSecondaryColor` 改回 `textPrimaryColor`**：旧实现让整条栏发灰，而工具栏是主导航不是辅助信息
- 文档：`OhosToolbar` 的「分组」不做 —— 官方 `ToolBar` 没有分组能力（`ToolBarOption` 只有 `button` / `text` / `icon`）。ROADMAP 当初写「`ItemState` + 分组」是照惯性想当然，属于**又一次「造一个官方不存在的入参」**（上一处是 `OhosSubheader` 的 `type`）。真正对应「非图标 + 文字」的 `ToolBarOption.button` 是自定义 slot，记为 `○`
- 新增：`OhosSubheader` 补齐 ArkUI `SubHeader`（子标题）的两种形态与全部尺寸 —— 高度三档 **56 / 56 / 72**、双行副标题（14fp / w400 / `titles_space` **2**）、单行副标题（14fp / w**500**）、左图标 **16** + 间距 **8**、左右边距 **16/16**、内容 padding **8**。旧实现只有一个 `padding: (16,16,16,8)`、**没有高度概念**，18fp 的实际行盒只有 ~42，比官方矮一截；也没有副标题、没有左图标。**没有照搬「`type: list|content` 入参」**：官方 `SubHeader` 根本没有 `type`，两形态是**参数组合的结果**（`subheader.ets:643` `leftArea()` 与 `:597` `getMinHeight()` 两条一致的优先级链）。造一个官方不存在的开关，等于让调用方声明渲染器兑现不了的形态 —— 改为**只读派生属性** `type`，由 `title` / `secondaryTitle` / `icon` 算出。**两处刻意保留的边界写进了文档与用例**：①`icon` 仅在存在 `secondaryTitle` 时出现（照 `leftArea()` 的判定顺序，`title` + `icon` 时图标不画）；②`leading` 顶掉全部文本但**不改变行高** —— `getMinHeight()` 读字段而非 builder，两个文本都在就仍是 72。另有一处容易写成一处的地方：副标题**权重随形态变**，双行 400（`_subtitle_font_weight`）、单行 500（`SecondTitleStyle` 里的 `FontWeight.Medium`）。组件从 `ohos_text.dart` 拆到独立文件 `ohos_subheader.dart`

- 新增：`OhosChip.selectedIcon` / `OhosChipItem.selectedIcon` —— 补齐 ArkUI `prefixSymbol` 的 `normal` / `activated` **双态图标**。`chip.ets:838` 的 `getPrefixSymbolModifier()` 是 `isChipActivated() ? prefixSymbol.activated : prefixSymbol.normal` —— 两态是**两个不同的图形**（描边→实心），不是同一图形换色；此前本库只有单图标 + 跟随选中态换色，等价于只做了 `activatedFillColor`。**有意偏离一处**：`chip.ets:1014` 的 `hasPrefix()` 写成 `isChipActivated() ? !!activated : !!normal`，只给 `normal` 时选中态连图标**和间距**一起消失。照搬会让既有用法（只传 `icon`）在被点中的一瞬间掉掉图标 —— 那不是双态而是缺陷。本库改为「选中态优先 `selectedIcon`，缺省回落 `icon`」，并补一条用例钉住「只传 `icon` 时选中不消失、间距仍 6」
- 新增：`OhosChipGroup.startSpace` / `endSpace` / `padding` —— 把 `chipGroupSpace` 的三段补全。`chipgroup.ets:46` 的默认值是 `{itemSpace: 8, startSpace: 16, endSpace: 16}`，而本库原来只有一个 `spacing`，只够表达**中间那一段**，首尾 16 全丢了 —— 于是首颗芯片紧贴容器边、滚动到起点时看起来像溢出容器。`chipGroupPadding` 同步补上（默认 `{top: 14, bottom: 14}`，整组高 = 36 + 28 = 64）；横向刻意不生效，它由 `startSpace` / `endSpace` 独占，两者同时生效会让首端变成 32
- 行为变更：`OhosChipGroup` 不传选中项时**默认选中第 0 颗** —— ArkUI 声明 `selectedIndexes: Array<number> = [0]`，且 `aboutToAppear` 在解析结果为空时再补一次 `[0]`（`chipgroup.ets:332` / `:356`），刚建好的组永远不是全空闲态；`multiple=true` 时同样如此（两种模式共享同一个数组）。这是**破坏性变更**：0.5.x 不传就一个都不选中。想保留旧表现请显式传 `selectedIndex: -1`（或 `selectedIndexes: const <int>{}`），已补用例钉住「旧表现仍可达」，否则升级路径是断的
- 新增：`OhosSearchBar.autoDisable` —— 补齐 `SearchButtonOptions.autoDisable`（API 18+）：无文本内容时搜索按钮**置灰且不可点击**。默认 **`false`**，照官方文档而不是照「更友好的直觉」—— 官方把选择权留给应用，不打开时空内容也能点，与 0.5.x 行为一致（也不补一条用例钉住这个默认值）。置灰取 `textTertiaryColor`：彩屏上是从品牌蓝降一档，墨屏上是 `#767676` 中灰，两者都落在「字还在、但点不动」的区间，没有引入新色值
- 修复：`OhosTabBar` 胶囊模式与 `OhosChipGroup` 的新组内边距**重复计算**。页签把 `OhosChipGroup` 套在固定 48 高的 `SizedBox` 里，chipGroupPadding 的 14+14 把 36 高的芯片压进 48 的栏里只剩 20 —— 芯片被裁掉一半，点击落在裁剪区外（表现为「点第二页签没反应」，`capsule tab bar switches pages` 用例当场变红）。页签是**条**不是「一坨独立芯片」，两端与内边距已由 TabBar 自己的 16 水平 padding 和 `height` 表达，现在显式传 `startSpace: 0 / endSpace: 0 / padding: EdgeInsets.zero`。**这是「同一个值别在两个组件里各管一遍」的第三次**（前两次：`OhosChip` / `OhosChipGroup` 的描边、尺寸）
- 修复：`OhosChipGroup` 非滚动模式在松高度约束下**纵向撑满整屏**。`_scrollableStrip` 里的 `Align(centerLeft)` 没有 `heightFactor`，于是取 `constraints.maxHeight` —— 一排芯片躺在页面里就变成占满 600 高的空白块，下面的内容全被顶走。加 `widthFactor: 1` / `heightFactor: 1` 让它只按子尺寸占位。这个缺陷一直存在，是新写的「整组高 64」用例逼出来的：断言 `group.height` 时拿到了 600
- 新增：`OhosChip.allowClose` / `onClose` / `suffixIcon`，`OhosChipItem` 同步支持 —— 补齐官方「可关闭芯片」形态。优先级按 ArkUI 的链落地：**给了 `suffixIcon` 就不画内置 ×**（对应 `suffixSymbol` > `suffixImageIcon` > `allowClose`），不是两个图标并排；后缀间距复用 `chip_normal_text_margin` / `chip_small_text_margin`（6 / 4），与左图标同一个 `metrics.iconGap`。`allowClose` 默认 **`false`**，这是**有意偏离**独立 `Chip` 的 `true`（`chip.ets:747` 的 `isClosable()` 是 `allowClose ?? true`）：本库一个 Chip 同时服务独立与 `ChipGroup` 两个场景，而 `chipgroup.ets:580` 传的正是 `chipItem.allowClose ?? false`；跟随 `true` 会让所有既有芯片在升级后凭空长出一个 ×，且 `onClose` 为 null 时那个 × 点了没反应 —— 与下方 `primaryLabel` 空药丸是同一类失败。关闭图标命中区就是图标本身（16），因为 `chip.ets` 的关闭按钮是 `padding(0)` + `stateEffect(false)`、没有可查的 hot_zone 令牌，不另拟数字
- 新增：`OhosSearchBar.searchButtonText` —— 补齐官方「右侧搜索按钮」形态。几何全部来自生效令牌：`search_button_space`(2) + `search_divider_side_space`(2) + 1px 分隔线 + `search_button_text_padding`(14) + 按钮高 `height - 2×search_button_space` = 36。顺序按源码直译：「清除 | 2 | 分隔线 | 2 | 按钮 | 2」——**清除按钮在分隔线左侧**，不是与按钮并排（`LayoutCancelButton` 的 `cancelX = buttonX - cancelW - 2*dividerSpace - dividerW`）。字号取 `search_font_size_API16` → `Body_M` = 14fp，不是文档兜底写的 16fp
- 文档：**发现第二处死令牌 `search_height` = 56**，并撤销据此写的「整栏 56」。上一版把 `sys.float.search_height` 当成「带搜索按钮时的整栏高」，阶段 D 里排了「补右侧按钮形态 —— 整栏高 56」。为落地去核实：13 份 `search/` 源文件里 `grep -rn search_height` **零命中**；`SearchTheme::height_` 只有一个赋值来源（`search_theme.h:65` 的 `search_default_height` = 40），`GetHeight()` 的 5 个调用点读的全是它；官方 30 个示例里配了 `.searchButton()` 的 3 处**全都写 `.height(40)`**。它与上一轮那个 `search_text_field_padding_left` 形状完全一致 —— 在 pattern 表里有值、能被 `GetAttr` 读出、也被编译进 `resources.index`，**唯独没有调用方**。本库栏高保持 40。这是 ROADMAP §七 第 10 条，也是第 8 条那条对策第一次在**动手写代码之前**生效
- 文档：矩阵统计口径重算为 **181 行 / 完整 83 / `◐` 7 / `○` 89 / `●` 2**（`83+7+89+2 = 181` ✓，命令连跑两次一致）。相对上一版（78/7/88/2 = 175）的变化：工具栏由 2 行拆成 8 行，其中 5 行转完整（几何、`ItemState` 三值、激活双条件、收纳 5 项、侧边距 `<5`）、2 行记 `○`（`button` slot、逐项长按）、1 行沿用原完整行。在此之前子标题六行已由 `○`/`◐` 转完整（73/8/92/2 → 78/7/88/2，行数不变）。**顺带修掉这条记录自身的算术错**：它曾写着「175 行 / 完整 78 / `◐` 7 / `○` 88 / `●` 2」却又括注「各类之和 174 == 行数 ✓」—— `78+7+88+2` 本来就是 175，那个 174 是更早一版改数字时漏改的残留。**统计口径的错最容易以「看起来自洽」的形式留下来**：行数与各类各自都像对的，只有相加才露馅。用例数 271 → 277 → 295 → **306**（子标题 +10、工具栏 +11、芯片/搜索框 +8）

- 新增：`OhosChipMetrics`（`lib/src/theme/ohos_chip_metrics.dart`）+ `OhosChipSize` 枚举，把芯片几何集中成一份官方数值：**36/28 高、18/14 圆角、16/12 文字 padding、6/4 图标间距、16/16 图标、14fp 字号**。这些数字来自 ArkUI 自己读的 `chip_*` `sys.float` 令牌真值（`tool/fetch_sys_resources.sh` 可复现）。抽出来是为了根除一个重复的根因：`OhosChip` 与 `OhosChipGroup` 是两份各写一遍的实现，**尺寸已经漂移** —— chip 靠 `padding: vertical 7` + 14fp×1.4 撑到 33.6（比官方矮 2.4，而且字阶一改高度就跟着漂），group 写死 32，两者互不相等。现在都由同一个类解析，`OhosChipGroupSize` 改为 `OhosChipSize` 的 `typedef`，`size` 参数名与取值保持不变（源码兼容）。顺带把选中态字重从 w600 改成官方的 `chip_activated_text_font_weight = 500`
- 修复：`OhosChip` / `OhosChipGroup` 尺寸对齐官方（本轮前五项全部偏小）：高度 32/24 → **36/28**、圆角 `height/2`(16/12) → 显式 **18/14**、字号 `labelSmall=12` → **14fp**、小号图标 14 → **16**、图标间距 4/2 → **6/4**。圆角改为显式值而非折半：两档当前恰好等于 `height/2`，但胶囊观感是**结果**不是来源，官方给的是 `chip_border_radius_*` 两个具体数
- 修复：`OhosSearchBar` 尺寸对齐官方：放大镜 18 → **16**、清除按钮命中区 32 → **40**（`search_close_icon_hot_zone_horizontal`，手指够得着的下限，32 在真机偏窄）、圆角由 `OhosGeometry.radiusCapsule`(999) 改为新增的 `OhosGeometry.radiusSearch`(20)。最后一项不是数值变化（999 一直被钳到 `height/2 = 20`），而是语义修正 —— 只要有人把高度调到 48，折半半径就变成 24、与官方 20 脱钩。空态占位同步 32 → 40，否则空↔有字切换时输入区会横向跳 24vp
- 文档：**纠正上一版自己写错的一条缺口 —— `OhosSearchBar` 的左内边距本来就是对的**。上一版从 `search_theme.h:71` 读到 `theme->leftPadding_ = pattern->GetAttr("search_text_field_padding_left", 0.0_vp)`，据此断定「官方输入区左 padding = 4，本库 12 多了 8」，写进了矩阵、ROADMAP 和阶段 D 任务。实际去查调用方：`GetLeftPadding()` 在整个 `search/` 目录**零调用方**，是旧框架 `frameworks/core/components/search` 的遗留字段。真正的水平几何在 `search_layout_algorithm.cpp` 的 `LayoutSearchIcon`(`:738`) / `LayoutTextField`(`:929`)，用的是 `search_icon_left_space`(12) + `search_icon_right_space`(8)。**教训：`GetAttr` 只证明「令牌被读进了字段」，不证明「字段被用了」** —— 判官方值必须再往下追一层调用方。这是 ROADMAP §七 第 8 条
- 文档：**矩阵统计命令本身有 bug，上一版的「完整 57」是扣出来的、不是数出来的**。`awk` 复核命令写的是 `if($0=="")print "完整"; else if(~/^○/)...`，而「完整」行的实现列里**有内容**（就一个类名），`$0==""` 永远不成立 → 62 行完整项落到四个分支之外、被静默丢弃（`awk` 不匹配时不报错、只是不输出）。真实值：**173 行 / 完整 62 / `◐` 9 / `○` 100 / `●` 2**，且各类之和 173 == 行数。现在 `else` 兜底指向「完整」，文件里写明了这个坑，并要求每次改完手工验一次「各类之和 == 合计」。`◐` 从 15 降到 9 是因为本轮修掉了搜索框 3 行 + 芯片 3 行的偏差
- 文档：`CONTROL-MATRIX.md` / `ROADMAP-0.6.md` / `doc/source/README.md` 三处同步：`search_text_field_padding_left` 标注为**死令牌**并附调用方查证结论；搜索框与芯片的偏差行从 `◐` 改为完整实现；阶段 D 第 4、10 项标注尺寸部分已完成、剩余工作只剩新形态（chip 的 `allowClose`、search 的右侧按钮）；用例数 268 → 271

- 文档：**令牌真实数值找到了，此前「拿不到」的结论是错的**。上一版明确写着「`Search` 这类系统组件的圆角/高度拿不到确切数值，`resources.index` 是 RestoolV2 二进制、本机解不出」，据此把这些行归到「只能以设计稿为准」。实际上 `resources.index` 只是 `global_system_resources` 仓库里 `systemres/main/resources/base/element/` 三份 JSON 的**编译产物**，直接读源文件即可：`pattern.json`（9701 行，组件主题模式）→ `float_sys.json`（1816 行，别名表）→ `float.json`（4112 行，真实值）。**这是「没找到就说没有」的第三次出现**（前两次：闭源 HDS 无文档、`EditableTitleBar` 无规格），已写进 ROADMAP §1.4(c)。新增 `tool/fetch_sys_resources.sh` 固化解析（含一个坑：pattern 层与 float_sys 层键同名，在 pattern 里反复回查会自引用成环，必须只跳一次）
- 文档：**`Search` 全部尺寸首次有了官方数值** —— 圆角 **20**、默认高 **40**、放大镜图标 **16**（左距 12、距文字 8）、清除按钮图标 16 且**命中区 40**、按钮文字 padding 14、按钮与分隔线间距各 2、默认无描边（`search_border_width` = 0）、聚焦光边 1。据此与 `OhosSearchBar` 逐项对账，查出三处偏差：放大镜 18（官方 16，大 2）、清除按钮命中区 32（官方 40，小 8）、圆角用 `radiusCapsule = 999`（被钳到 `height/2` 恰好也是 20，数值等价但**语义不同** —— 改高度半径会跟着变）。另两条当时写进文档的判断**后来被推翻**：`search_height` = 56 被当成「带搜索按钮时整栏高」（实际是死令牌，见上方条目）、`search_text_field_padding_left` = 4 被当成「官方左内边距」（同为死令牌，本库的 12 本就正确）。矩阵「搜索框」由 1 行拆成 7 行
- 文档：**`Chip` 尺寸此前一直是自拟值** —— 官方 `chip_normal_height` = **36**、`chip_small_height` = **28**、圆角 **18 / 14**、文字 padding 16 / 12、图标间距 6 / 4、字号 **14fp**（两档同值）、图标 16 / 16。本库现状是高度 32 / 24、圆角取 `height/2`（16 / 12）、字号用 `labelSmall = 12`、小号图标 14 —— **五项全部偏小**。顺带纠正一处自我矛盾：早前从 `chipgroup.ets` 读到 `enum ChipGroupHeight { NORMAL = 36, SMALL = 28 }` 曾误判为「芯片高度直接差异」、随后又自我否定说「只用于后缀渐变 Stack」，**两次判断都不对** —— 它和 `chip_normal_height` / `chip_small_height` 完全吻合，本来就是芯片高度。错在把它当孤证、又没去查令牌表。矩阵「操作块」由 4 行扩到 7 行
- 文档：`SubHeader` 的令牌数值经**两条独立链路互证** —— `float.json` 里 `subheader_single_title_height = 56vp`、`subheader_single_subtitle_height = 56vp`、`subheader_double_height = 72vp`、`subheader_title_font_size = 18fp`、`titles_space → padding_level1 = 2vp`、`left_icon_size = 16vp`、`content_margin → margin_left/_right = 16vp`、`content_padding → padding_level4 = 8vp`、`Subtitle_S = 14fp`，与 `subheader.ets` 的 `RESOURCE_CACHE_MAP` 逐个吻合。此前只有源码一条链路，现在两条互证，说明解析路径可靠
- 文档：`CONTROL-MATRIX.md` 统计口径修正为 **174** 行 / 完整 57 / `◐` 15 / `○` 100 / `●` 2（`●` 单列为「有意偏离官方」并注明理由 —— 目前两处都是墨水屏必需：`search` 补 1px 描边、`chip` 未选中态补描边）。清点命令重写：原来用 `grep -c '○'` 按**整行**匹配，一行里同时出现 `○` 与 `◐`（备注提到过）会被重复计入；改为 `-F'|'` 单取「本库实现」列再分类。**本轮这个数字又错了一次** —— 第一次用 `$4` 取列，实际状态列是 `$5`，把「依据」列当成了状态列。**（此处「完整 57 / `◐` 15 / 合计 174」也是错的，`awk` 兜底分支把 62 行完整项静默丢了；真实值见上方 0.6.0 最新条目。）**
- 文档：`CONTROL-MATRIX.md` 的「依据」列从三档增到四档，新增**令牌名**一档，并明确它比其余各档都硬 —— 它是构建 `resources.index` 的源文件本身，不是对它的描述

- 文档：**纠正一个比"读错"更严重的错误** —— 此前 `ROADMAP` / `CONTROL-MATRIX` / `doc/reference/README.md` 三处都写着「HDS 是闭源库，上游无文档」，据此把核心操作栏、即时操作归为「规格只能按设计稿截图猜」。实际上官网有 markdown 原文可直取：`doccenter-references/api/ui-design-<小写slug>.md`，8 份全部存在（`HdsActionBar` / `HdsSnackBar` / `HdsTabs` / `HdsNavigation` / `HdsListItem` / `HdsListItemCard` / `HdsColorPicker` / `hdsMaterial`）。只有 `EditableTitleBar` 确实没有（多个 slug 变体全 404，`HdsNavigation` 里也无对应章节）。区别在于前几次是读错了，这次是**没去找就说没有** —— 它让一整类组件自动降级为猜测，而且看起来像审慎判断。`tool/fetch_reference.sh` 增加第二条链路（`HDS_COMPONENTS`），参考文档从 43 份增至 **51 份**、示例从 362 增至 **369**（该步之后的差集补抓又增至 55 份 / 402 示例，见下方「用设计文档末尾的开发文档链接重新排查」条）
- 文档：核心操作栏按真实文档重写。实际签名是 `primaryButton?` / `primaryButtonBuilder?` + `primaryButtonBuilderWidth?` / **`startButtons?`** / **`endButtons?`** / `actionBarStyle?` / `isExpand?` / `blurStrategy?`。上一版规划的「侧边布局」是把设计规范里四个字直接当参数名 —— 真实轴是 `ActionBarStyle.isHorizontal`（默认 `true`，`false` 为竖直）。另修正两处事实：模糊**默认开**（`BlurStyle.COMPONENT_REGULAR`），不是「默认关」；主按钮图标是 `baseIcon` / `altIcon` 双图标靠 `isPrimaryIconChanged` 切，不是单图标换内置图。`ActionBarButton` 逐按钮可配 `width` / `backgroundColor` / `shadowStyle`（默认 `OUTER_DEFAULT_LG`）/ `iconSize` / `iconFillColor` / `enabled` / `hoverTips` / 无障碍三件套
- 文档：`HdsTabs` 文档推翻「底部页签已完整」的判断。除平铺/悬浮外还有：三档宽度（`HdsBarWidthRangeOptions`，`<440` / `440–600` / `>840`vp，且 600–840vp 按高宽比再分）、页签宽度算法（≤3 个 `76vp×n+8vp`、≥600vp 用 `80vp×n`、≥4 个上限 328vp）、渐变蒙层（浅 `#CCF1F3F5` / 深 `#99000000`）、**迷你栏**（折叠/展开、自定义内容、`HdsBarLayoutMode` 水平/垂直）、`applyMiniBarStyle` 等控制器方法
- 文档：`HdsSnackBar` 的右侧操作区是 **5 值**枚举（`TEXT_ONLY` / `CLOSE_BUTTON_ONLY` / `TEXT_WITH_ARROW` / `TEXT_WITH_CLOSE` / `HIGHLIGHT_TEXT_WITH_CLOSE`），现有只实现前两个；`duration` 默认 **5000ms** 且 **≤0 表示常驻**（本库默认 3s，语义近似但值不同）。`HdsColorPicker` 的收藏**上限 72 个**、`circleRadius` **小于 10 一律取 10**、`initialFavoriteColors` 只首帧生效 —— 而文档里**没有**「不透明度 / 屏幕取色 / 色值输入」，那三项只在设计规范出现，连系统组件都没做，矩阵里已分开标注
- 文档：`CONTROL-MATRIX.md` 补入 HDS 与反查文档后为 **160** 个数据行：完整 57 / 部分 8 / 缺失 95。「测试」列目前仅 `OhosActionBar` 一行填了用例名，其余 159 行为空 —— 按本文件自己的定义，空着不算覆盖，已在统计节写明这一点并附可复跑的清点命令，避免再出现两种混淆：一是「字段被实现过 = 覆盖了」，二是「手抄数字走样」。**本轮这个数字我错了两版**：第一版把统计表本身算进行数、还凭空写了一个矩阵里根本不存在的 `●` 符号；第二版清点命令用了写死的 `NR<180`，随后加行没同步改，数字当场漂掉 12 行。现在命令以 `## 统计` 为终点，加多少行都不会漂
- 文档：`custom-dialog-box` 文档补出弹出框**九项**缺漏，其中两条是硬缺口而非可选项 —— 官方对 `customStyle: false` 的默认容器**恒为 32vp 圆角**、宽度上限 **400vp**、高度上限 `0.9×(窗口高−安全区)`，而本库现在自己定圆角且不做任何夹取，长内容对话框会一路顶到屏幕边缘、看起来不像弹窗。其余：`gridCount` 栅格宽度、`isModal: false` 非模态（无遮罩、可点周围）、`maskColor`（默认 `0x33000000`）/ `maskRect`（区域外事件透传）、`showInSubWindow`（10+）、`enableHoverMode`（14+，折叠屏半折）、四段生命周期 `onWillAppear`→`onDidAppear`→`onWillDisappear`→`onDidDisappear`（19+）、`onWillDismiss` + `DismissDialogAction.reason`（12+，能区分点遮罩/侧滑/back/ESC）。窗口层级类（`levelMode`/`levelOrder`/`immersiveMode`）**明确不做** —— Flutter 侧没有对应物，强行模拟只会得到一套假的层级语义
- 文档：**用「设计文档末尾的开发文档链接」重新排查全部 42 个控件**，新增 `tool/trace_control_docs.sh`。上一轮找文档的方式是**猜 slug**，靠猜中/猜空来判定「有没有文档」——这是个方法论错误：猜空既可能是文档不存在，也可能只是名字没猜对，两者无法区分。正确链路是单向可追溯的：概览页 → 控件设计文档 → 该文档末尾「## 开发文档」小节里的链接 → 组件参考文档。跑完结果：41 个控件有链接且全部可达，1 个（色彩选择器）官方漏给链接但参考文档存在，**0 个控件真的没有文档**。脚本顺手暴露出一个必须先修的问题：官方链接形如 `...promptaction#showtoast`、`...navigation#toolbarconfiguration10`，直接把锚点拼进文件名会得到 200 一整个壳页面，必须 `refname="${refname%%#*}"` 剥掉
- 文档：靠差集比对补上 **4 份从未抓过的参考文档** —— `ohos-arkui-advanced-ChipGroup`（子页签）、`ts-methods-custom-dialog-box`（弹出框）、`ts-universal-attributes-sheet-transition`（半模态面板）、`arkts-apis-uicontext-promptaction`（即时反馈，Toast 挂在 `UIContext` 上、不是独立组件，这解释了为什么在开源仓库里搜不到）。参考文档 51 → **55 份**，示例 369 → **402**。其中 **31 个示例来自新增的 4 份**，说明分母里最缺的一块正是形态最多的两个组件。原抓取表用的是 `ohos-arkui-advanced-Chip`（单个 Chip）而不是 `ChipGroup`，等于子页签的官方文档从来没被抓过
- 文档：`bindSheet` 文档推翻「半模态面板已完整」的判断 —— 这是本轮**最没有依据**的一个 `●`。官方 `SheetType` 是 **5 值**：`BOTTOM` / `CENTER` / `POPUP` / `SIDE`(20+) / `CONTENT_COVER`(20+)，并且**按窗口宽度自动选型**（<600vp 默认底部、600–840 默认居中、≥840 默认跟手）。现有 `showOhosBottomSheet` 只做了底部一种；控制条还是**无条件**画的，而官方只在多挡位 `detents` 生效时才默认显示。另外缺多挡位（最多 3 挡，生效时 `height` 失效）、缺居中/跟手的最小 320vp 与最大窗口短边 90% 限制（且这两型下 `LARGE`/`MEDIUM` 无效、恒 560vp）、缺侧边型（高度恒全屏、宽度 md 断点 1/2 窗口、>md 恒 400vp）、缺全屏型（无圆角/边框/阴影/标题/关闭按钮/蒙层，仅侧滑关闭）。矩阵从 1 行 `●` 拆成 7 行（1 完整 6 缺失）
- 文档：子页签由 `●` 降为 `◐`。`ChipGroup` 文档给出三个此前没对过的默认值：`selectedIndexes` **默认 `[0]`**（不传也会选中第一个，且 `multiple=true` 时同样如此；`multiple=false` 时传多个只取第一个）、`chipGroupSpace` 默认 `{itemSpace:8, startSpace:16, endSpace:16}`（现有 `spacing` 只映射了中间的 8，首尾 16vp 没画）、`chipGroupPadding` 默认 `{top:14, bottom:14}`。还缺 `allowClose` 与后缀图标的关系：`suffixSymbol` / `suffixImageIcon` 任一存在时 `allowClose` **失效**，优先级 `suffixSymbol` > `suffixImageIcon` > `allowClose`
- 文档：**新增第四层对照基准 —— 组件实现源码**（`doc/source/` + `tool/fetch_source.sh`，29 份 `.ets` / 36,354 行）。前三层（设计规范 / 参考文档 / 文档示例）答得了「有哪些形态、默认值是什么」，答不了「具体画多大」：官方 `Chip` 文档把高度写成 `$r('sys.float.chip_normal_height')`，那是令牌**引用**不是数值，而令牌的真实值编在二进制 `resources.index`（RestoolV2，1.3MB）里、`strings` 只能读到名字。源码里不走 `$r(...)` 的部分则直接写着数值。抓取范围刻意只限 ArkTS 进阶组件：系统组件的 C++ 侧几何值几乎全走 `theme->GetAttr(...)`，同样退回令牌，实测 `search_layout_algorithm.cpp` 1060 行只有一条 `DEFAULT_DIVIDER_HEIGHT = 12.0_vp`
- 文档：源码层第一次核对就推翻了一条「已确认无文档」的结论 —— **`editabletitlebar.ets` 存在，958 行，规格完整**：栏高 56、标题 20vp、副标题 14vp、主标题最多占 65% / 副标题 35%、头像 64vp、编辑弹窗 216–256vp、Symbol 24vp。「`EditableTitleBar` 确实无文档」只在**参考文档**范围内成立（三个 slug 变体全 404 是真的），但**把「文档没有」当成「没有规格」是错的** —— 这与 §0.2「闭源 ⇒ 无文档」是同一个错误模式，只是这次跨了一层。矩阵该行已改为「源码有，文档无」
- 文档：`SubHeader`（子标题）按源码真实数值重核，由 3 行扩到 7 行。`subheader.ets` 是唯一带 `RESOURCE_CACHE_MAP` 的文件（28 条令牌→真实值），据此拿到此前拿不到的尺寸：**高度三档 56 / 56 / 72**、标题 18、副标题 14（权重 400）、`titles_space` 2、左图标 16、图标文字间距 8、左右边距 16/16、内容 padding 8。现有 `OhosSubheader`（`ohos_text.dart:118`）**没有高度概念**，只有一个 `padding: (16,16,16,8)`、行高全靠字阶撑，与官方 56/72 对不上；且没有副标题行、没有左图标
- 修复（工具）：`tool/fetch_source.sh` 不猜文件名。目录名与文件名不一致且方式不统一 —— `chip/source/chip.ets` 同名，但 `gridobjectsortcomponent/source/GridObjectSortComponent.ets` 是全驼峰，试「首字母大写」仍 404。改为用 API 列目录取真实 `.ets` 名。**这是「猜名字」这个错误的第三次出现**（前两次：猜 slug 判文档有无、`Chip` 误当 `ChipGroup`），已写进 ROADMAP 头部
- 文档：新增 `doc/ROADMAP-0.6.md` 第七节「方法教训」，把三轮补查归结成三条（只读设计规范会读错形态数 / 基于类比推断"闭源=无文档" / 矩阵写"无文档"会污染下游判断），并把落法写进 `sources.json` 的 `missing` 字段约定：只允许记录**试过的 slug 与返回码**，不允许写「该组件无文档」这种结论式表述，把三轮补查归结成三条（只读设计规范会读错形态数 / 基于类比推断"闭源=无文档" / 矩阵写"无文档"会污染下游判断），并把落法写进 `sources.json` 的 `missing` 字段约定：只允许记录**试过的 slug 与返回码**，不允许写「该组件无文档」这种结论式表述
- 修复：`OhosActionBar` 不传 `primaryLabel` 时渲染出一个**空白药丸** —— legacy 布局无条件画 `OhosButton(child: Text(primaryLabel ?? ''))`，于是官方「去掉主按钮」这一形态（`primaryButton` 本就是可选参数）实际不可达，调用方拿到的是一个看着像加载失败的空按钮，比不画更糟。现在无标签时整块不渲染；`primaryLoading: true` 仍保留按钮，因为转圈是「正在做某事」的唯一反馈，这时候抽掉会让人以为请求丢了。补 3 条用例（无标签不画 / 有标签照画 / loading 无标签仍画），已验证回退后第一条会红
- 文档：新增 `doc/CONTROL-MATRIX.md` —— 按**官方形态**而非「控件个数」统计的覆盖矩阵，每行带「依据 / 本库实现 / 测试」三列。0.5 声称「42 控件全覆盖」是按控件名统计，按形态统计实际有大量缺口（如进度条缺 `Eclipse`/`ScaleRing`/`Capsule`，分段按钮缺 tab 型与多选，列表缺 `ListItemGroup` 的 CARD 分组与吸顶）
- 文档：新增 `doc/reference/`（ArkUI 参考文档本地快照）与 `tool/fetch_reference.sh`。中文站参考页是 SPA，静态抓取只得到 404（页面里 `<link rel="alternate" type="text/markdown">` 指的地址同样 404），因此改抓 OpenHarmony 仓库原文 —— 内容与官网同源且自带完整 ArkTS 示例。文档本体不入库（上游内容、2.9MB、会漂移），用脚本可复现；`README.md` 与 `sources.json` 入库，负责记录两条链路与缺口
- 文档：新增 `doc/ROADMAP-0.6.md` 规划。其中纠正了上一轮基于设计规范得出的三处错误结论：滑块**没有**双值区间（`slideRange` 是「有效滑动区间」）、进度条是 **5 种**而非 3 种、列表分组样式是官方枚举 `NONE`/`CARD` 而非自拟视觉

## 0.5.0

Release date: 2026-11-01

- 修复：`OhosChipGroup` 未选中芯片没有描边 —— `_item` 自己搭 `AnimatedContainer`，`decoration` 里只有色和圆角，漏了 `OhosChip` 那套 `policy.line` 描边。彩屏上填充自己够得着（灰底压白页），但墨水屏的 `compBackgroundGrayColor` 就是纸色，芯片与页面同色又没有线，一排里只有选中那颗有形状、其余散成纯文字，读者分不出哪个能点。现在描边取色与 `OhosChip` 完全一致（选中品牌色 20%、未选中提示色 30%，经策略换成实色），彩屏上淡成发丝线不影响观感。根因是同一件事在两个组件里各写了一遍 —— 长期应让 `OhosChipGroup` 复用 `OhosChip`（两者的 padding 与圆角目前也不一致：chip 16/7、group 按高度取半径），本次只补齐缺失的那一处
- 修复：`OhosSearchBar` 内部 `TextField` 的边框状态槽位被宿主主题改写，胶囊里叠出第二道框。组件原来只写了 `border: InputBorder.none`，但 `InputDecoration.applyDefaults` 用的是 `enabledBorder ?? theme.enabledBorder` —— 装饰器自己的 `border` **不会**回填状态槽位，而 `_getBorder` 先按状态取槽位、取到了就压根不去读 `border`。宿主只要给 `inputDecorationTheme` 配过 `enabledBorder`（墨水屏上很常见：没有填充色可用，只能靠 1px 描边分层）就会中招。现在六个槽位逐个钉成 `none`，并显式 `filled: false`（同一处 `applyDefaults` 还会把宿主的 `filled: true` 带进来，在胶囊里多一块填充矩形）。外层胶囊已在 `foregroundDecoration` 里自己画 1px 边，内层永远不该再画
- 测试：新增 `test/downstream_issues_test.dart`（11 例），对应下游实测反馈的三个 issue。写法上刻意做成一件事：**断言落在「组件真的画出来了」而不是「组件里有了这个字段」** —— 字段存在却没被用上，正是这三个 bug 的形态。其中搜索框一例直接调用 `InputDecoration.applyDefaults(宿主主题)` 断言合并后的结果不再是 `OutlineInputBorder`，而不是只检查组件自己写的槽位是否为 `none`（后者在 bug 存在时也照样通过）。已验证：回退修复后这 6 例（ChipGroup 3 + SearchBar 3）全部变红
- 修复：深色档 `compBackgroundGray` 由 `#E5E5EA` 改为 `#202224`（本项随 `brightness` 语义拆分一并落地，此处记录以免遗漏）。原先那个值抄自官方 token 表，在 ArkUI 语境里成立（配的是深色**字** `#FFE5E5E5`），而本库把它当输入框 / chip 的**填充面**，上面画的是 `textPrimaryColor`（深色档 `0xE5FFFFFF` 半透明白），白字落在这块浅灰上实测 1.15:1 —— **token 抄对 ≠ 用对**。改后 6.59:1。配套加一条「深浅两档的同名**面**令牌不得近似同值」自查，只扫面令牌不扫彩色令牌（深色档的品牌色、交互色本来就该提亮，按「深色必须更暗」一刀切会把正确设计判成错误）
- 示例：`example` 的主题按钮改为「点按循环 浅色 → 深色 → 墨水屏，长按选全部五档（含深色墨水屏）」。此前直接用库里的 `OhosThemeToggleButton`，它的点按语义是「当前彩屏档位 ↔ 墨水屏」，深色只能进长按菜单 —— 结果是点一下就从浅色跳到黑底白字的电子纸，**深色那一档在画廊里根本走不到**。对一个专门用来看组件外观的应用来说，深色和墨水屏是并列的一等对照项，不该藏在长按里（`example/lib/theme_switch.dart`）
- 文档：README 头部截图区补上**深色档**五张对照（与墨水屏并列），并新增「深色（dark 主题）」小节 —— 深色只翻令牌明暗、表现规则仍是彩屏（有阴影/模糊/水波纹），与墨水屏正交；另收录一张**深色墨水屏**截图，把「两个维度同时成立」从说明变成可看的图
- 测试：`example/test/theme_switch_test.dart` 重写（7 例），钉住点按循环、深色档纸色真的换了、`toggle` 从墨屏回来落在深色、菜单能选到深色墨水屏、自定义主题下点按不是空操作。用例在 `runTest` 内部把默认平台临时换成 iOS —— Material 在 Android 平台用水波纹 `InkSparkle`，它首次绘制时加载 `shaders/ink_sparkle.frag`，本仓库的 `flutter_tester` 解析该 asset 会抛 `manifest could not be decoded`（既有环境问题，与主题无关，切墨水屏同样触发）；iOS 的 `InkRipple` 是纯 Dart 实现，不碰 shader

- **破坏性变更**：`OhosThemeData` 构造函数的 `monochrome` 参数（`bool`，默认 `false`）改为 `policy`（`OhosVisualPolicy`，默认 `ColorVisualPolicy()`）。这是本次唯一一处**编译期**不兼容 —— 直接写 `OhosThemeData(monochrome: true, ...)` 手搓主题的调用方会报「没有名为 monochrome 的命名参数」，改为 `policy: const InkVisualPolicy()` 即可（用工厂 `OhosThemeData.ink()` 的调用方不受影响）。改的理由：单色只是「这块屏怎么表现」的一个取值，用 bool 表达等于把 24 个组件的分支逻辑焊死在「彩色 / 单色」这一对上，再加高对比、深色墨水屏就要回头改组件
- 新增：视觉策略层 `OhosVisualPolicy` —— 把「这块屏上怎么表现才看得见」从色值里拆出来，两个实现 `ColorVisualPolicy`（彩屏：叠色 / 阴影 / 模糊 / 波纹）与 `InkVisualPolicy`（墨水屏：1px 实色线、无动效、灰阶量化）。接口是 `tint` / `line` / `quantize` / `outlineWidth` / `allowsShadow` / `allowsBlur` / `allowsRipple` / `scaleMotion`。**新增一类屏幕 = 新增一个子类 + 一份色值，组件层不动**
- 调整：`OhosThemeData.monochrome` 由字段改为 getter（`policy.isMonochrome`），读取侧全部兼容，但不能再被赋值；新增语义化 getter `usesOutlines` / `outlineWidth` / `outlineColor`，组件判断「要不要描边」改读这三个，不再摸 `monochrome`。`copyWith` 同时接受 `policy:` 与 `monochrome:`（后者内部换算成策略），旧调用点不用改
- 重构：24 个组件内部的 `theme.monochrome ? A : B` 分支全部消除，改为向策略提问。公开 API 与构造参数无变化。`tint()` 返回全透明表示「这层底托不住形体」，调用方据此改画线 —— 这一条约定替代了原来的往返判断；但「彩屏无、墨屏有」这类纯形状判断（如 plain 按钮禁用态的边框）仍显式写成 `theme.usesOutlines ? ... : ...`，不藏在 `tint` 的返回值里
- 新增：一键切换三件套 —— `OhosThemeController`（`ChangeNotifier`，`mode` / `toggle()` 记住上次彩屏档位）、`OhosThemeSwitcher`（包在 `MaterialApp` 外层，切换时原地重建以复用 Navigator State，不弹回首页）、`OhosThemeToggleButton`（默认点按翻转、长按弹三选一菜单）。配套 `OhosThemeMode` 枚举（`light` / `dark` / `ink`，带 `label` 与 `theme()`）
- 修复：`tint` 的透明阈值取 `<= 0.20` 而不是 `< 0.20` —— 20% 黑恰好落在 16 级灰阶第 3 级，与白底不可分，边界值必须一起改判
- 测试：新增 `test/theme_switch_test.dart`（15 例）把策略行为固化下来 —— `tint` 阈值、`line` 丢 alpha、`quantize` 不吸附灰阶格子、切换不丢页面栈、`toggle` 记住上次彩屏档位
- 新增：`OhosThemeData.id` —— 稳定的字符串标识（`'light'` / `'dark'` / `'ink'`），供应用侧做主题持久化。核心库仍不依赖任何存储插件，只给一个能存下来的 key；`copyWith` 会继承来源 id
- 新增：`OhosThemeData` / `OhosTypography` / `OhosVisualPolicy` 的 `==` 与 `hashCode`（按值比较）。此前 `OhosTheme.updateShouldNotify` 全靠引用比较，而 `light()` 每次调用都会新建 13 个 `TextStyle`，于是「字段完全相同的两份主题」被判成不同 —— 键盘弹出、旋转屏幕、宿主 `setState` 引起的任何重建都会让整棵 `OhosTheme.of(context)` 依赖树全量重建。实测 `OhosThemeData.light() == OhosThemeData.light()` 现在为 `true`
- 新增：`OhosThemeController.custom(OhosThemeData)` 与 `useTheme` / `setColorTheme` —— 自定义主题（品牌色、第四种屏幕）现在也能进切换流程，不再被枚举锁死。`toggle()` 记住的是**上一次的彩屏主题**而不只是档位，所以从自定义主题切到墨水屏再切回来，回到的仍是那份自定义主题
- 调整：`OhosThemeController.mode` 由 `OhosThemeMode` 改为 `OhosThemeMode?` —— 自定义主题没有档位。读它的地方需判空（或用 `isInk`）；`OhosThemeToggleButton` 内部已处理，无档位时按策略推导图标
- 调整：`OhosThemeSwitcher.materialThemeBuilder` 的入参由 `OhosThemeMode` 改为 `OhosThemeData`。自定义主题没有枚举可选，只能看主题本身
- 新增：`OhosThemeController.useMode(OhosThemeMode)` —— 选档位时自动分流「彩屏档位要记住 / 墨水屏不记住」，菜单类 UI 不必自己判断
- 新增：`OhosVisualPolicy.disabledFill(base)` —— 「被禁用的实心形状该填什么色」。此前 `OhosSlider` 直接引用了 `OhosColors.inkDisabled`，这是组件层最后一处硬编码的墨水屏令牌；现在组件只说「这是个禁用形状」，具体灰由策略决定
- 新增：`InkVisualPolicy.paper` —— 灰阶量化的合成底色，默认纯白。深色墨水屏传一块深色纸即可，不必另写策略子类（色值仍需另给一份）
- 修复：`OhosThemeToggleButton` 的图标原本对 `OhosThemeMode` 做穷举 `switch`，给枚举加第四档会让这个 widget 编译失败 —— 等于把「加主题」变成「改组件」。改为非穷举的兜底推导
- 测试：新增 `test/theme_extension_test.dart`（11 例）。核心用例在测试文件内**从零定义一个仓库里不存在的高对比主题**（自定义 `OhosVisualPolicy` + `copyWith` 出来的色值），驱动 `OhosButton` / `OhosCard` / `OhosSwitch` / `OhosSlider` / `OhosAppBar` 正常渲染并参与切换 —— 以此把「新增主题不需要改 widget」固化成回归约束，而不是口头承诺
- 新增：`OhosVisualPolicy.underlinesTextActions` —— `text` 按钮（无底色、无边框）在墨水屏上自带下划线。墨水屏的 `highlightColor` 与 `textPrimaryColor` 都是纯黑，一个纯黑的「了解更多」和一句纯黑的正文读者分不出哪个能点，下划线是这块屏上唯一剩下的可供性线索。判定交给策略而非 `usesOutlines`：描边宽度和文字可供性是两件事，高对比主题有 2px 描边也不该被顺带划线。禁用态不划线（否则读起来还能点）。配套测试 `test/text_button_affordance_test.dart`（9 例）
- 新增：`OhosVisualPolicy.litFill(base)` —— 「已激活 / 已选中」时点亮一个小图标取什么色，**保证比未激活态更醒目**。不能用 `quantize` 或 `line`：两者都走灰阶量化，高亮黄 `#F7CE00` 会变成 `#C3C3C3`（亮度 0.55），比未选中态的 `#767676`（0.18）还淡，状态语义直接反转。彩色的信息在灰阶屏上本就存不住，只能换成明暗对比：`InkVisualPolicy` 按纸面明暗取纯黑 / 纯白。用于 `OhosColorPicker` 的收藏星
- 修复：以墨水屏档位初始化控制器后，第一次 `toggle()` 回彩屏会丢掉 `fontFamily`，整个字阶掉回系统字体（example 默认停在 ink，点一下就能触发）；用 `dark` 初始化时档位也会被一起改写成 light。`_lastColorTheme` / `_lastColorMode` 原本用字段初始化器写死成浅色，现改为在构造函数里按 `initialMode` 播种。`OhosThemeController.custom()` 则把传入的主题本身播种为「普通」一侧
- 修复：`OhosCheckbox` 启用但未勾选时被铺了一层 15% 灰底 —— 把 `enabled || ink ? transparent : ...` 压成一次 `policy.tint(...)` 时丢了 `enabled` 这一维，而 `ColorVisualPolicy.tint` 在彩屏上恒返回带 alpha 的颜色。现恢复为「只有禁用态才铺灰底」
- 修复：`plain` 按钮禁用态底色基准从黑 `0x14000000` 变成 `cardColor`，而浅色档的 `cardColor` 就是白色 —— 白 8% 铺在白页面 / 白卡上等于没有，禁用与启用的区分度下降。基准色改回黑色
- 破坏性变更（源码兼容）：`OhosListTile.divider` 由 `bool`（默认 `true`）改为 `bool?`（默认 `null`）。
- 修复：墨水屏（`OhosThemeData.ink()`）下靠浅色填充表达状态的控件整块消失 —— 16 级灰阶里 20% 以内的黑落在第 0–3 级，禁用按钮的「20% 底 + 白字」等于什么都没有。禁用态改透明底 + 实色描边，并把同一类问题一起收掉：勾选框 / 单选框未选中描边、开关关闭态轨道与滑块、分段按钮轨道与选中段、进度条与滑动条未走轨道、纸片与状态按钮描边、输入框下划线，统一成「留白 + 1px 实线」，禁用降一档到 `#767676`
- 修复：`filled` 按钮 `loading` 时被当成禁用态（底色变浅、转圈却是写死的白色），真机上只剩一个空白药丸。现在 `loading` 只关掉点击，配色仍走主按钮
- 修复：墨水屏下默认白底的容器与页面同色、阴影也不存在，`OhosCard`（未显式传 `color`）、`OhosSearchBar` 胶囊与底部面板补 1px 黑描边
- 修复：`OhosCard` 在 `padding` 为零时，描边被自带底色的子节点（如 `OhosActionBar`）的抗锯齿边缘吃掉，圆角弧段消失、只剩直边 —— 描边改画在子节点之上并把子节点裁进圆角
- 修复：白底浮层只靠 `elevation` 分层 —— `showOhosSnackBar` 对浅底补 hairline（墨屏纯黑、彩屏主题分隔色），`OhosSelect` 的下拉面板与 `showOhosPicker` 面板补墨屏描边，`showOhosMenu` 的线在墨屏按 1px 算
- 修复：`OhosColorPicker` 的色块只有选中时才画框，未选中的白 / 浅色块压在白底上等于消失（墨水屏上 `multiInk` 压成灰阶后更明显）。未选中色块改按亮度补一圈描边（`computeLuminance() > 0.7`，墨屏纯黑、彩屏 26% 黑），深色块不描，选中仍是原来的粗框；选中态对勾也跟着亮度取色（深色白勾、浅色用前景色），白勾画在白块上等于没画；这条判定抽成 `ohosSwatchOutline` 供示例复用，示例的选中色预览块与调色板也补了白 / 浅灰两档
- 修复：墨水屏下滑动条的滑块是白圆 + 零阴影（`RoundSliderThumbShape` 只有 elevation 可调），贴在白页面上等于没有滑块。改为自绘的 `OhosSliderThumbShape`：白圆 + 完全落在圆内的 1 设备像素描边，彩屏仍走阴影；`enabled: false` 时滑块按 `enableAnimation` 收敛成灰色实心（白圆黑环在禁用时读起来仍然可拖），禁用轨道同时降一档到 `OhosColors.inkDisabled`；墨屏也不再画点按后的半透明灰块
- 修复：墨水屏下滑动条的气泡是两个叠在一起 —— `showValueBubble` 自绘的那个已补 1px 实线，Material 还会另画一个 value indicator（`divisions` + `label` 时默认 `onlyForDiscrete`），它白底、无描边，贴在白页面上整个消失。现在关掉原生 indicator，只留自绘气泡
- 修复：`OhosColorPicker` 光谱模式的指示器与手指**纵向反向** —— `Alignment.y` 的 `-1` 是上边，而 `value = 1`（最亮）也在上边，原来直接写 `value * 2 - 1` 把两者对调，往下拖指示器反而往上跑。改成 `1 - value * 2`，并把盒高从写死的 `96` 抽成 `_svHeight`、让 `_svAt` 收 `Size` 取坐标
- 调整：滑块条的拇指原本是「刚好占满轨道高度的一块白」，把 18vp 的轨道整段切断，浅色端看上去就是断裂成一块白色空白。改成**比轨道高的白圆**（24 vs 18）：圆心内缩半径、两端不会被裁成半圆，白圆外围一圈发丝线（墨屏纯黑、彩屏 25% 黑），浅色端也读得出来
- 修复：`OhosColorPicker` 在墨水屏下的显示 —— 光谱盒、色相/饱和/明度轨道各补一条发丝线（渐变两端接近白色，墨屏上直接化进白底），光谱指示器在白环外再套一圈深色发丝线（浅色区域靠它、深色区域靠白环），未选中的模式片从 6% 黑底改成「透明 + 1px 实线」，收藏星点亮色从品牌黄改成纯黑
- 修复：`OhosBadge` 的计数徽标在「高度有界、宽度无界」的父级里被拉成**竖胶囊** —— 标签容器用了 `Container(alignment:)`，它内部的 `Align` 在宽度无界时收缩、在有界高度上撑满，侧边菜单 48vp 的行因此把「8」画成 18×46 的黑条（`OhosBadge` 单独演示因为四周都是松约束所以看不出来）。改用 `Center(widthFactor: 1, heightFactor: 1)`，两个方向都只包住内容：一两位数字仍是 18vp 圆，多位数字横向长成胶囊
- 修复：`OhosList` 里每个行边界叠着两条分隔线 —— `OhosListTile` 自己画一条（`indent: 16`）、`OhosList` 又在行间插一条（`indent: 56`），左端不一致，看上去是「两条线错位叠加」；最后一个 tile 底下还多出一条压在卡片圆角里（n 行共 2n−1 条线）。现在线归列表所有：`OhosList` 通过 `OhosListDividerScope` 告诉每个 tile「在列表里 / 是不是最后一项」，tile 在列表内不再自己画，`OhosListTile.divider` 只在单独使用时生效
- **破坏性变更**：`OhosThemeMode` 由三档扩为四档，新增 `system`（`OhosThemeMode.values` 的首位）。遍历 `values` 建菜单的地方会自动多出一项；对枚举做穷举 `switch` 且未留兜底分支的调用方会编译失败（库内部已全部改为非穷举推导，加档不会再让 widget 挂掉）
- 新增：`OhosThemeController.resolveTheme({systemBrightness})` / `materialThemeOf({systemBrightness})` —— 按给定的系统亮度**现算**当前应生效的主题。两者都是纯函数（不写状态、不通知），因此可以安全地在 `build()` 里调用；系统亮度不进 controller 状态，而是像 `MediaQuery` 一样由 Widget 树提供。若在 `build` 期间把亮度喂回 controller 再 `notifyListeners()`，监听者会在当前构建过程中触发重建，直接抛 `setState() or markNeedsBuild() called during build`
- 新增：`OhosThemeSwitcher` 自动读取 `MediaQuery.platformBrightnessOf` 并传给 `resolveTheme`，`system` 档因此能响应系统浅/深色切换，用户改完系统设置界面立刻跟着翻
- 修复：`OhosThemeController.toggle()` 在 `system` 档下进入墨水屏时，把 `system` 原样存进了「上一次彩屏档位」，导致切回来永远停在「跟随系统」上，丢掉离开时那个具体明暗 —— 切换按钮实际上成了单向门。现在按离开那一刻解析出的亮度落成 `dark` / `light`
- **修复**：`OhosTypography.monochrome` 把字阶硬编码成纯黑，深色墨水屏下正文是「黑字压黑纸」，对比度约 1.1:1，整段消失（`AppBar` 标题、裸 `OhosText` 这些不自己 `copyWith` 颜色的地方全中招）。新增 `brightness` 参数，深色纸取纯白字阶 `textPrimaryMonochromeDark`；之所以要参数而不能让 `copyWith` 派生：字阶是 13 个 `TextStyle`，`copyWith` 做的是字段替换，不会有调用方去逐个改
- 新增：`OhosThemeData.ink(brightness: Brightness.dark)` —— 一行拿到完整的深色墨水屏（纸色 `#1A1A1A`、纯白字阶、禁用灰 `#4D4D4D`、多色系统反向）。此前做深色墨水屏要同时改对 6 个色值 + 13 个 `TextStyle` + 策略里的 `paper`，少改任何一处都是「某处黑字压黑纸」，而且窄到跑一遍看不出来
- 修复：`InkVisualPolicy.disabledFill` 硬编码 `#BFBFBF`，在深色纸上变成「禁用态比可用态更亮」，读者会去点它 —— 比「看不见」更糟的失败方式。改为按 `paper` 明暗分流（白纸 `#BFBFBF` / 深色纸 `#4D4D4D`）
- 修复：`OhosThemeController.custom()` 传入的主题**本身就是墨屏**时（如品牌定制的电子纸主题），它被播种成「普通」一侧，`toggle()` 切过去仍是墨屏，按钮看起来完全失灵。现在这种情况「普通」侧播种为内置浅色，与 `initialMode: OhosThemeMode.ink` 的处理保持一致
- 调整：`OhosThemeData.brightness` 文档重写，明确它**只描述令牌明暗** —— 不表示系统深色模式、不表示档位、不表示是否跟随系统。拆开之前 `ink()` 恒为 `Brightness.light`、`isDark` 恒假，「深色墨水屏」这个组合根本表达不出来
- 新增：`OhosVisualPolicy.allowsGlow` —— 「是否允许光这类纯装饰性的明度叠加」（点光源、按压缩放高光、沉浸光感边缘光晕）。与 `allowsShadow` 分开而不是合并，因为两者在这块屏上的**失败方式不同**：阴影不存在只是「少了点立体感」，而白色光晕叠在纯黑字上会直接糊掉正文，黑底场景下又完全看不见。灰阶屏上「光」这个隐喻本身不成立 —— 它没有背光可言。接入 `OhosPointLight` / `OhosPressShadow` / `OhosLightMaterial`，挡住的是装饰层，信息载体（底色、描边、图标）不受影响
- 新增：`OhosColors.inkBackgroundDark` / `inkTertiaryDark` / `inkInteractiveDark` / `inkDisabledDark` / `inkForegroundDark` / `multiInkDark` —— 深色纸那一侧的色值。这些不能靠白纸侧反相算出来：`#1A1A1A` 反相得到 `#E5E5E5`，那块面在环境光下比纸本身还刺眼
- 调整：`OhosVisualPolicy.allowsGlow` 在基类给默认 `true` 而非声明成抽象成员 —— 本库承诺「加一块屏 = 写一个子类」，外部已存在的自定义策略（高对比主题等）不该因为这里多一个能力声明就编译失败
- 测试：新增 `test/dark_ink_test.dart`（17 例）守「深色墨水屏真正可用」：`isDark` 与 `monochrome` 同时为真、正文/三级文字/字阶对比度达标、禁用灰比纸亮比正文暗、点亮态方向不反转、`multiInkDark` 下标语义不变、`copyWith` 也能拼、组件层能渲染。其中「字阶跟着翻」一例专门盯 `typography` 漏改导致的「黑字压黑纸」
- 测试：新增 `test/system_theme_test.dart`（17 例）守「跟随系统」：`resolveTheme` 是纯函数（反复解析不同亮度零通知）、非 `system` 档无视外部亮度、`materialThemeOf` 与 `resolveTheme` 亮度对齐、系统亮度变化后界面自动翻且不抛 build 期异常、切到墨屏后系统亮度变化不会推翻用户选择
- 测试：新增「组件层不判断具体主题类型」回归约束 —— 静态扫描 `lib/src/widgets/` 下所有源码（剥掉注释后再扫，否则文档里提到的 `OhosThemeData.monochrome` 会被误判），确保没有 `OhosThemeMode.` / `isMonochrome` / `.monochrome` 分支，只允许主题切换按钮自身例外。这条是「新增一种屏不改组件」从承诺变成可验证事实的关键
- 测试：`test/theme_extension_test.dart` 增补「自定义主题 × 墨水屏策略」6 例 —— 品牌色 + 灰阶表现规则同时成立、`custom()` 能识别自定义灰阶主题、`toggle` 来回不丢品牌色、老的自定义策略不覆写 `allowsGlow` 时行为不变
- 修复：`compBackgroundGrayDark` 由官方 token 表的 `#FFE5E5EA` 改为 `#202224`。那个值在 ArkUI 语境里成立（配的是深色**字** `#FFE5E5E5`），本库把它当输入框 / chip 的**填充面**，上面画的是 `textPrimaryColor`（深色档为 `0xE5FFFFFF` 半透明白），白字落在这块浅灰上实测对比度只有 1.23:1。**token 抄对 ≠ 用对**
- 文档：README 新增「应用案例」章节，收录第一个真实应用 **bige-editor**（代码阅读器 / 编辑器 + Git 客户端，鸿蒙 hap 与 Android apk 双形态）。含 logo、三张实机截图（仓库列表 / 变更与提交 / 同一份错误态在浅色·深色·墨水屏三档下的对照）与华为应用市场下载二维码。这一节同时是「普通深色不回归、墨水屏可用、深色墨屏不再是理论组合」三条验收标准的应用侧佐证
- 测试：新增 `test/dark_contrast_audit_test.dart`（9 例）用 WCAG 相对亮度公式对深色档做量化审计 —— 文字落页面底、功能色、输入类填充面、弹层、组件实际取色分组断言，半透明前景先 `Color.alphaBlend` 合成再算比值。`_luminance` 用 sRGB 直接加权而非 `computeLuminance()`（后者做线性化会算偏）
- 调整：分隔线两端不再贯穿 —— 左端对齐文字（有 `leading` 时让到图标之后，16 / 56vp）、右端统一留 16vp（`endIndent: 16`）；列表给非 `OhosListTile` 子节点补的线同样改成两端内缩
- 修复：`OhosGrid` 的栅格几何 —— ①末行不满时剩下的单元被拉伸铺满整行（12 列的网格里单个 `columnSpan: 3` 占满一整行，与上面满行行的单元边缘全都对不上），现在右侧保留空列，列宽统一为 `span·colWidth + (span−1)·gutter` 且与同行单元个数无关：每格左右各吃 `gutter/2` 内边距、外层 `padding` 让回半格，单元边缘仍精确落在页面边距上；②`maxWidth`（栅格最大使用宽度 2220vp）原来把两侧 margin 也算进上限，改为只限制单元区；③`runSpacing` 连末行也补一段，网格底部凭空多出一条行距；④`_emitRow` 的 `remaining` 参数声明了却没用上。配套 3 条用例（`test/ohos_ui_test.dart` 的 `OhosGrid` 组）
- 示例：布局与动效页在墨水屏下全部改走灰阶 —— 栅格 / 响应式 / 动效单元原来用「浅灰 `#F1F3F5` + 10% 品牌蓝」，压到 16 级灰阶上等于白色、整块看不见，现在保留同样的实心圆角块，只把颜色换成读得出来的灰阶（取值都是 17 的倍数，落在灰阶格子上、不出抖动噪点）；共享元素三张卡（蓝 / 绿 / 橙 + 白字）压成中灰后字读不出来，墨屏换深灰阶 + 保持白字，放大转场后的浮层底色改浅灰、去掉看不见的阴影；沉浸光感的粉紫蓝渐变压成一块实心深灰，THICK 退化成纯白后按库的约定自己补 1px 线，`+` 图标改读 `theme.highlightColor`
- 统一：描边宽度与「画在盒内」收口到新增的 `ohosStrokeWidth` / `ohosBorderSide` —— 宽度取整到整数设备像素（DPR 2/3 仍是 1vp，1.5 / 2.625 不再把一条线摊成两三行灰），并显式钉住 `strokeAlignInside`（画到盒外会被祖先 clip 吃掉半条，四条边就不同宽）。`OhosCard`、`OhosSearchBar`、弹窗、底部面板、菜单、下拉、浮条、侧栏、纸片、状态按钮、按钮、勾选框、开关、分段按钮、滑块气泡与弹层统一走这一个入口

## 0.4.0

Release date: 2026-10-30

- 修复：`OhosAlphabetIndexer` 点「当前高亮的字母」被静默忽略 —— `_selectAt` 里 `index != _current` 的短路把 `onSelected` 一起吞了；索引条不知道列表被 `jumpTo` 到了哪里，于是"点列表此刻所在的字母"变成静默无操作（`#` 在点过别的字母之前永远点不动）。修法是按手势来源分流：**tap 一律回调**，**drag 只在跨格时回调**（`onVerticalDragUpdate` 每帧都来，逐帧通知会把调用方的 `jumpTo` 打成连续滚动）
- 新增：拖动放大镜 —— `OhosMagnifier`（48vp 圆形泡泡，内容用 `text` 或 `child`；`monochrome` 下换纯黑描边并关掉入场动画）、`OhosMagnifierController`（`show` / `update` / `hide`，泡泡进根 `Overlay`，可画在宿主 `SizedBox` 之外，`IgnorePointer` 不抢手势；没有 `Overlay` 时 `show` 返回 `false`）、`OhosMagnifierPosition.resolve`（纯函数定位：泡泡落在手指的四个「角」上——纵向、横向各留 `gap`，默认偏内侧；该角放不下就翻到同角另一侧、再换到另一行；宽度上限为可用宽度一半，四个角都放不下才夹进安全区，此时 `side` 按夹紧后的最终矩形重算 —— 夹紧可能把泡泡挪到手指的另一侧，沿用首选角会让调用方把箭头/尾巴画反）
- 新增：`OhosAlphabetIndexer.showMagnifier`（默认 `true`，仅拖动时显示，点击不显示）与 `magnifierBuilder`（自定义泡泡内容）；泡泡字母与高亮同源（读内部生效值）。泡泡与手指留白按「指肚接触半径」取 32vp（16vp 实测仍被指肚压住一角），两个轴都留。需要祖先有 `Overlay`（`MaterialApp` / `WidgetsApp` 提供），没有时不显示
- 修复：索引条命中区从「只有字形」改为**整条**（`HitTestBehavior.opaque`）—— 22vp 的条只有中间约 12vp 可点，两侧留白与 `spaceBetween` 摊出来的字间空隙都会把事件漏给下层（`Stack` 叠放时会直接命中下面的列表行），`onVerticalDragUpdate` 也只在正好按到字形时才生效
- **破坏性变更**：删除 `OhosAlphabetIndexer.itemHeight`；槽位高度改由父级约束决定（`LayoutBuilder` 的 `constraints.maxHeight`，无界时退回 `size.height`），同一个 slot 同时供布局、字号与 `dy → 字母` 使用 —— 调用方不再需要按 `size` 手算第二套几何（原来默认 20 只在对齐时巧合成立，4 字母 160 高时点 A 会报 B）。迁移只需删掉这个实参：旧写法 `itemHeight: perLetter` + `size` 高 `perLetter × 字母数` 的结果不变
- 行为变化：字母改为**等高槽位**，首尾不再贴边、整体居中分布（与 ArkUI 索引条一致），命中格与视觉格完全重合
- 修复：父级高度小于 `size.height` 时索引条溢出（可拖分隔条的面板把 22 字母、`size` 高 420 的条压到 130 → `RenderFlex overflowed by 290 pixels`）；现在整条跟着缩、字号跟随，不再溢出
- 行为变化：索引条字号不再走 200ms 隐式动画，高度缩小立即生效（0.3.0 拖动分隔条时容器已缩到 260、字号还在 12 → 11 的路上，会抛 `RenderFlex overflowed` 并闪黄黑条纹）；高亮切换那 200ms 颜色过渡一并去掉
- 修复：索引条字母样式改为继承外层 `DefaultTextStyle`（`copyWith` 而非新建），外层没给家族时退到 `theme.typography.fontFamily` —— 真机落到系统字体看不出问题，但 `flutter_tester` 里 null 家族 = Ahem，整列都是实心方块。注意这只解决"家族有来源"：**golden 想出真字仍需测试侧 `FontLoader`** 把真实字体注册到同一家族名
- 新增：`OhosAlphabetIndexer.selectedIndex`（外部高亮，供"恢复上次位置 / 索引与列表互跳"这类**代码发起的定位**使用，不需要订阅滚动）—— 新值会写回内部状态，因此受控期间手指拖动依然即时高亮；越界在 debug 断言、release 夹到末格）
- 新增：`OhosAlphabetIndexer.onSelectEnd` —— 交互结束的一次性回调（tap up / drag end / drag cancel），带回最终字母。与 `onSelected` 分工：后者是过程（tap 落指一次、drag 每跨一格一次），前者是结果（恰好一次）。想"松手才定位"的调用方只订阅这个通道即可，不必再记 `onSelected` 的最后一次（原计划的 `jumpOnDragEnd` 开关不再需要）
- 新增：`OhosAppBar.statusBarBackgroundColor` —— `primary: true` 时把背景拆成「状态栏段 + 工具栏段」，状态栏那条可以单独着色（沉浸式页面常见的「状态栏 = 页面底色、工具栏 = 卡片色」），内边距仍由组件吸收、总高不变；与 `scrollEffect` / `lightMaterial` 叠加时该段保持纯色。名字刻意不叫 `statusBarColor`：那个是 `SystemUiOverlayStyle` 控制图标明暗的字段，容易混
- 新增：`OhosAppBar.heightOf(context, {height, bottom, primary})` —— 返回 `height + bottom + 状态栏内边距`，对标 `AppBar.preferredHeightFor`；`preferredSize` 拿不到 `BuildContext`，需要自己包一层顶栏时用它，不必手算
- 修复：`OhosScaffold` 的 body 子树仍会读到**已被认领**的 `MediaQuery.padding` —— `SafeArea` 只把**自己让过的那几条边**从子树里摘掉，`top: false` / `bottom: false` 的那一边原样留给后代，于是调用方在 body 里按最常见写法再包一层 `SafeArea`（或自己读 `padding` 做偏移）就叠出第二份：有 `appBar` 时凭空多一条状态栏高度的空白。现在四条边都已由「栏 / 页面容器 / 底部导航」认领完毕，统一从 body 子树摘干净，与 Flutter `Scaffold` 的 `body` 槽位口径一致；要在 body 里贴边绘制时改读 `View.of(context).padding`（`MediaQuery.viewPaddingOf` 会被同一处一起摘掉，不可靠）。示例：导航类新增「安全区：body 里再套 SafeArea 不叠第二份」对照页

## 0.3.0

Release date: 2026-10-22

- 修复：`OhosAppBar` 在沉浸式（edge-to-edge）下让系统状态栏压住标题与右侧动作 —— 新增 `primary`（默认 `true`）：为 `true` 时组件自行吸收 `MediaQuery.padding.top`，背景仍铺到屏幕最顶端、内容下移，与 Material `AppBar` 的 `SafeArea(bottom: false)` 行为一致；`primary: false` 留给「调用方已经自己让过」的场景，避免重复加内边距。`preferredSize` 仍为 `height` —— `Scaffold` 的 `appBarMaxHeight` 已经把状态栏高度算进去了，重复加会多出一条空白
- 调整：`OhosAppBar` 由 `Stack` 叠加层改为单行 `Row` 布局 —— leading / 标题 / actions 按行顺序排布，标题用 `Expanded` 居中于两者之间的剩余空间；标题不再压到右侧操作图标下面，过长时在自身空间内换行。状态栏内边距、沉浸光感 `lightMaterial`、`preferredSize` 与滚动动态模糊层（`scrollEffect`）均未改动
- 行为变化：标题居中基准从「整条栏的中轴」改为「leading 与 actions 之间的空间」，只有单侧有按钮时会比 0.1.1 的绝对居中略偏；需要绝对居中时调用方可在另一侧放等宽占位
- 测试：`test/ohos_ui_test.dart` 的 `OhosAppBar` 组补 3 条用例（leading/标题/actions 依次排布不重叠、只有 actions 时的居中基准、长标题被约束在剩余空间内不溢出）；测试宿主改用 `Align` + `SizedBox` 把栏宽固定为 360vp，避免路由紧约束让宽度断言失真
- 新增：`OhosAppBar` 补齐四个参数 —— `titleAlignment`（`center` 默认 / `start` 左对齐）、`titlePadding`（默认左右各 8vp，传 `EdgeInsets.zero` 可让标题位整块放 `OhosSearchBar`）、`leadingWidth`（左侧槽位定宽，leading 在槽内居中）、`bottom`（`PreferredSizeWidget`，高度并入 `preferredSize`，可直接挂 `OhosTabBar`）；另增 `systemOverlayStyle`，通过 `AnnotatedRegion<SystemUiOverlayStyle>` 下发状态栏图标明暗，组件不再猜
- 修复：`scrollEffect` 省略 `scrollController` 时退回 `PrimaryScrollController.maybeOf(context)`；既没显式传、祖先里也没有时在 debug 下 `assert` 报错，不再静默不生效
- 文档：`lightMaterial` 与 `actions` 补充约束说明 —— 前者是每帧全屏 `BackdropFilter`（墨水屏 / 低端机慎用），后者不裁剪、不滚动，标题会先被压到 0，动作过多仍会溢出
- 示例：导航类新增「对齐 / bottom / 标题位放控件」演示（左对齐标题 + `bottom` 挂 `OhosTabBar`，以及标题位换成 `OhosSearchBar`）
- 新增：墨水屏（e-ink）预设 `OhosThemeData.ink()` 与能力开关 `OhosThemeData.monochrome`（默认 `false`）；配套令牌 `OhosColors.inkForeground` / `inkBackground` / `inkInteractive` / `multiInk`。预设为纯黑 + 纯白、去掉中间调：分隔线纯黑 1px、水波纹 / 悬停 / 聚焦全透明、功能色压成黑，三级文字保留 `#767676`（它同时是 hint 色，给纯黑就分不出「未输入 / 已输入」）。`brightness` 仍为 `light`，组件判断一律读 `monochrome` 而不是 `isDark`，避免以后加第二套单色预设时无处挂
- 适配：`OhosLightMaterial`（含 `OhosAppBar.lightMaterial`、`showOhosBottomSheet`、底部页签光感）在 `monochrome` 下退化为纯色，不再做每帧全屏 `BackdropFilter`；`OhosAlertDialog` 与 `showOhosSnackBar` 在单色下补 1px 纯黑描边（浮条同时关掉 elevation，否则白底 + 阴影 = 无边界的白块）
- 修复：`OhosTextField` 的错误态底线改读 `theme.dangerColor`（原来硬编码 `OhosColors.danger`，是单色主题下唯一一处红色）
- 示例：展示类新增「墨主题」演示（纯看板：正文 / 提示色 / 按钮 / 开关 / 1px 分隔线 / 退化后的 `OhosLightMaterial`）
- 新增：`OhosTextField` 支持 `variant`（`underline` 默认 / `filled` 灰底圆角 / `capsule` 胶囊）与 `suffixIcon`、外部 `focusNode`。`filled` 在 `monochrome` 下自动退回「透明底 + 1px 线」——墨水屏上填充色等于背景色，靠底色分层会整个消失
- 新增：`OhosSearchBar` 支持外部 `focusNode`、`onClear`（清空后回调）、`onCancel` + `cancelText`（聚焦时出现「取消」，点击清空并失焦）。空态占位宽度从 12vp 改为 32vp，与清空键同宽，空↔有字切换时输入区不再横向跳 20vp
- 修复：`OhosButton` 的标签改为 `Flexible` + 默认单行省略 —— 420vp 抽屉里 3:2 双按钮、200vp 窄窗不再 `RenderFlex overflowed`（原来只能每个调用点自己包 `Flexible`）；`monochrome` 与 `NoSplash` 主题下不再闪水波纹
- 新增：`OhosAlertDialog.contentWidget`（`showOhosDialog` 同步支持）—— 表单类弹窗可以放 `OhosTextField` 等控件，不再只接受字符串 `content`
- 新增：`OhosListTile.density`（`regular` / `compact`，后者对应 Material 的 `ListTile(dense: true)`：标题 14 / 副标题 12、上下 8vp）；`padding` 改为可空，null 时按 density 取值
- 新增：`showOhosBottomSheet` 暴露 `level` 与 `lightMaterial`（`false` 或墨水屏主题下退化成纯色面板）；`showOhosSnackBar` 新增 `customMessenger`，可挂到指定层 `ScaffoldMessenger`（抽屉 / 弹层挂在根 Navigator 时的场景）
- 调整：`OhosDivider` 默认 `indent` 由 16 改为 **0**，与 Material `Divider` 一致 —— 直接替换不再改变既有版式；需要与列表文字对齐的场合（如 `OhosListTile`、分组列表）自己传 `indent`
- 适配：`OhosPopup` 与 `OhosSlider` 的数值气泡在 `monochrome` 下去掉 `Colors.black` 8% 阴影（白底上不可见），改 1px 纯黑描边
- 调整：`OhosAppBar` 自动插入的返回键改用 `Icons.arrow_back_rounded`（鸿蒙系统风格的粗箭头），不再是 iOS 式细 chevron；新增 `toolbarHeight` getter 作为 `height` 的别名，对齐 `AppBar.toolbarHeight` / `kToolbarHeight` 的命名，避免迁移时混用
- 文档：`OhosBlank` 澄清它是留白占位而不是空态组件
- 示例：输入类新增「填充 / 胶囊形态」与搜索框取消按钮演示；容器类新增「高密度列表」演示
- 修复：示例 gallery 在窄屏（360 / 320vp）下的「斑马线」（`RenderFlex overflowed`）——
  `DemoSection` 标题行改 `Expanded`、墨主题演示的按钮行改 `Wrap`、文件列表项与光感演示行改
  `Expanded` / `Flexible`；新增 `example/test/gallery_overflow_test.dart` 兜底（8 个页面 ×
  两种宽度逐屏下滑，收集溢出并报出出问题的 `Row` / `Column` 与源码行号）
- 修复：组件在窄屏下的溢出 —— `OhosActionBar` 次要操作改为横向滚动、主按钮固定贴右（原
  `Spacer` + 自然宽度在 320vp 直接溢出 58vp）；`OhosChipGroup` 非滚动模式改为按屏宽换行内
  横滚（无界宽度下仍保持自然宽度）；`OhosNavigationBar` 胶囊页签标签改 `Flexible` + 省略
  （`Flexible` 必须放在 `Padding` 外层，否则拿不到收缩约束）；`OhosAlphabetIndexer` 字号按
  可用高度自适应；`OhosDataPanel` 单元内容按比例缩放
- 修复：窄屏再叠加系统字体放大（Android 常见 1.15x、无障碍 1.3x）时的溢出 —— 示例 gallery
  的响应式说明行改 `Wrap`、光感演示标题改 `Flexible`；`OhosNavigationBar` 平铺栏标签限制
  最大放大 1.15x 并可被压缩（48vp 栏高下 1.3x 会纵向溢出 1vp）；`OhosAlphabetIndexer` 字号
  先按 `textScaler` 折算回设计字号再留 5% 余量（只按 vp 摊分，1.15x 下仍溢出 27vp）
- 测试：`example/test/gallery_overflow_test.dart` 扩展为 3 种宽度 × 3 种字号
  （1.0 / 1.15 / 1.3）× 8 个页面的矩阵扫描，共 72 条用例；宿主通过
  `MediaQuery.textScaler` 注入系统字号，逐屏下滑收集 `RenderFlex overflowed`
- 修复（评审 P1）：`OhosTextField.focusNode` 的生命周期错误 —— `_controller` / `_focusNode`
  原来都是 `late final`、只在 `initState` 创建，也没有 `didUpdateWidget`：父级把
  `focusNode` 换成别的节点后 `TextField` 仍用旧节点；「先传外部节点、后改成 `null`」再销毁
  组件时又按当前 `widget.focusNode == null` 判断所有权，把调用方的节点 dispose 掉
  （随后 `addListener` 抛 `A FocusNode was used after being disposed`）；反向切换
  （`null` → 外部节点）则泄漏内部节点。现在字段可变，各自记录 `_ownsFocusNode` /
  `_ownsController`，`didUpdateWidget` 同步节点、监听器与焦点态，只有自己创建的实例才 dispose。
  与 dartdoc 里「supplied node is never disposed by the widget」的承诺一致
- 修复（评审 P2）：`OhosSearchBar` 换 `focusNode` 后没有重算 `_focused` —— 旧节点聚焦时换成
  未聚焦的新节点，「取消」按钮会一直挂着；新节点本身已聚焦时反而要等下一次焦点变化才出现。
  另外 `controller` 也按所有权处理（`null` → 外部 → `null` 不再留下别人的实例）。
  「取消」由裸 `GestureDetector` 换成 `TextButton`：带 button 语义、可用键盘/回车激活、
  命中区 48×40vp，墨水屏下不闪水波纹
- 修复（评审 P2）：`OhosDataPanel` 不再把整个单元塞进 `FittedBox` —— 那会给标签传无界宽度，
  `maxLines: 1` + 省略号完全失效、整个单元被等比缩小（1.3x 系统字号被缩回 1x 以下，长标签
  还会连带把数值压小）。现在只对数值做 `Flexible` + `FittedBox`，标签留在有界宽度内省略
- 修复（评审 P2）：`OhosThemeData.ink()` 的字阶改为纯黑（新增 `OhosTypography.monochrome`）——
  原来直接复用 `OhosTypography.light`（主文字 `0xE6000000`，90% 黑），`OhosAppBar` 标题与
  未显式指定颜色的 `OhosText` 在 16 级灰上仍是中灰，与「纯黑 + 纯白、去掉中间调」冲突
- 修复（评审 P2）：`OhosAlertDialog.contentWidget` 补滚动保护（`Flexible` +
  `SingleChildScrollView`）—— 它是给表单/列表用的，320vp 窄屏 + 1.3x 字号下几个输入框就会
  超出弹窗高度并纵向溢出
- 新增（评审 P2）：`OhosNavigationBar.maxTextScaleFactor`（默认 `1.15`，传 `null` 关闭钳制）——
  平铺栏标签的无障碍上限不再写死且无法关闭；配合调大 `height` 可以让 1.3x 真正生效
- 文档（评审 P3）：`OhosChipGroup.scrollable` 说明写清「`false` 只是『放得下时不加滚动视图』，
  放不下仍会横滚且没有滑动提示，需要换行请自己用 `Wrap`」；`OhosThemeData.ink` 补充墨主题的
  适配范围（哪些组件会换画法、白底卡片 / 搜索框不会自动加描边）
- 测试：库测试 48 → 62 条，新增 focusNode / controller 的切换与所有权、`OhosSearchBar`
  换节点后的焦点态与「取消」按钮语义、`OhosDataPanel` 长标签 + 1.3x 字号、ink 字阶与
  渲染颜色、多字段表单弹窗的滚动兜底、`showOhosSnackBar(customMessenger)` 与
  `showOhosBottomSheet(lightMaterial: false)`；CI 增加 `working-directory: example` 的
  `flutter test`（示例溢出矩阵之前只在本地跑，CI 只做 analyze）

## 0.2.0 (unreleased)
- 对照华为「UI Design Kit 能力」文档补齐增强组件（全部见 `example` →「UI Design Kit」分类）：
  - 点光源：`OhosLightSource` / `OhosIlluminated`（none/border/content/borderContent/defaultFeatheringBorder 五种受光类型 + 强度调节）
  - 按压阴影：`OhosPressShadow`（BLEND_WHITE / BLEND_GRADIENT，指尖径向渐变）
  - 侧边栏：`OhosSideBar`（overlay 悬浮、遮罩、自动收起）+ `OhosSideMenu` / `OhosSideMenuItem` / `OhosSideMenuSubItem`（一二级菜单、红点/数字角标）
  - 横滑列表项：`OhosListItem` + `OhosSwipeAction`（左滑按钮、`fullDelete` 整划删除）
  - 常驻通知：`showOhosSnackBar(resident: true)`（duration -1 语义、关闭按钮、图标+标题+描述）
  - 子页签分割线：`OhosTabBar` 新增 `OhosTabBarDividerMode.visible/none/followScroll` 与 `OhosTabBarDividerOptions`
  - 颜色选择器：`OhosColorPicker` 重写为网格/光谱/滑块三模式 + 收藏（保留旧网格 API）
  - 动态模糊标题栏：`OhosAppBar` 新增 `scrollEffect`（commonBlur/transitionBlur/gradientBlur + BackdropFilter）
  - 可展开操作栏：`OhosActionBar(expandable: true)`（主按钮收起/展开次级宫格）
  - 分层图标与多窗入口：`OhosLayeredIcon` / `OhosMultiWindowEntry`
- 修复：`OhosListItem` 手势增量重复累加导致真实多点拖动时操作按钮无法展开、点击操作按钮失效；补多点步进与 fullDelete 单元测试
- 示例：新增「UI Design Kit」分类页与模拟器截图（`doc/screenshots/kit_*.png`），README 补充组件用法与截图

## 0.1.1 (unreleased)
- 问题修复（0.1.1）
  - 底部页签（平铺式）：选中项底部文字不再隐藏
  - 导航点/轮播：滑动过程中页面保持圆角（`OhosSwiper` 新增 `clipRadius`）
  - `OhosScaffold` 内包真实 `Scaffold`，`showOhosSnackBar` 可正常弹出
  - 空白 `OhosBlank`：有界空间内扩展、`ListView` 等无界上下文仅占 `minSize`，不再无限滚动
  - 标题栏：标题始终相对整条栏居中（`Stack` 布局，不受返回键/操作项影响）
  - 下拉按钮 `OhosSelect`：菜单锚定按钮下方弹出；按钮文本宽度上限 200vp 并省略
  - `showOhosMenu` 新增 `anchor`（`BuildContext`/`GlobalKey`），菜单相对触发控件弹出
  - 状态按钮示例补充行间距；分段按钮移除选中项外阴影（不再向相邻分段渗色）
  - 颜色选择器：容器过窄时自适应缩小色块，`Row`/`Expanded` 内不再溢出
  - 「一镜到底」示例改用 `Hero` 共享元素转场，卡片连续放大进入全屏页


- 包名由 `ohos_ui_kit` 更名为 `harmony_ui`，主库文件改为 `lib/harmony_ui.dart`，导入语句同步更新

- 对齐官方色彩 Token 表：新增 `comp_background_primary/gray`、`comp_emphasize_secondary/tertiary`（20%/10% 品牌高亮）、`interactive_hover/pressed/focus/select`、四级文字 `textFourth`，修正深色主文字透明度
- 沉浸光感：新增 `OhosLightMaterial`（背景模糊 + 光池 + 镜面/边缘高光 + 阴影 + 可选漫射 + 渐变模糊，ULTRA_THIN…ULTRA_THICK 五档），`OhosLightEffectTuning` / `OhosLightPalette` 调参；`OhosAppBar(lightMaterial:)`、`OhosNavigationBar(lightMaterial:)`、`OhosBottomSheet`（ULTRA_THICK）开箱即用
- 底部页签光感交互：悬浮式开启 `glow` 后光池跟随选中项，按压出现指尖光晕与彩色焦散
- 响应式布局：新增 `OhosResponsiveBuilder`、`OhosWindowSize`、`OhosGrid`/`OhosGridItem`，实现 600/840vp 断点与 4/8/12 列栅格（16/24/32vp 边距、8/12/16vp 槽宽）
- 子页签：`OhosTabBar` 支持 `OhosTabBarType.capsule`（品牌色填充 + 灰底未激活 + 8vp 间距）；新增 `OhosChipGroup`（单选/多选、普通/小尺寸）
- 底部页签：`OhosNavigationBar` 支持平铺式 48vp / 悬浮式 56vp，激活项 20% 品牌高亮胶囊、图标 24vp
- 转场动效：`OhosGeometry` 新增 `sharedElement` 曲线、`durationLong`、沉浸光感模糊强度映射
- 示例：新增「布局与动效」分类页（栅格/响应式断点/沉浸光感/一镜到底/曲线对比），导航页升级为双样式子页签与双样式底部页签，新增模拟器截图

## 0.1.0
