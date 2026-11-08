## 0.6.1

Release date: 2026-11-08

> 0.6.0 之后的**墨水屏 / 深色主题整改轮**，来自社区 8 个 PR（AtomGit !13–!20，关联 Issue #7–#11）。共同根因是「反白前景写死成白色 / 官方深色」，而深色墨水屏的 `highlightColor` 本身就是纸白、白纸墨屏的又是纯黑 —— 于是白底白字、黑底黑字，整块内容消失。本版把判据统一为**合成后的实际底色对比度**，反白色一律取 `theme.onHighlightColor`，不再按「是不是墨屏」分支。用例 750 → **776**；8 个 PR 依次合并零冲突，合并态 `flutter analyze` 干净、全量 776 条通过。
>
> **兼容性**：没有破坏性变更。`OhosVisualPolicy` 新增的 `statusMotion` 是**带默认实现的普通方法**（默认转发 `scaleMotion`），外部自定义策略子类无需改动 —— 延续 0.6.0「策略层不新增抽象成员」的承诺。
>
> **行为变更（需留意）**：墨水屏下不确定态进度游标与加载彗星从「停在静态中位」改为**照常按 2000ms 周期运动**。静止的游标与「进度卡死」在 16 级灰阶上完全同形，没有别的线索能表达「还在动」。代价是持续的局部逐帧刷新：更慢的电子墨水屏可能有残影，自定义策略把 `statusMotion` 覆写成 `Duration.zero` 即可退回静态符号（此时建议用文字或状态图标承载「在加载」）。

- 新增：`OhosVisualPolicy.statusMotion(Duration)` —— 与 `scaleMotion` 的分界不是「动画长短」，而是**归零之后还剩什么信息**：装饰性过渡归零只是少一段动画，进度游标归零则丢掉「还在加载」这件事。`InkVisualPolicy` 只放行这一类；`_IndeterminateCycle._sync`、`OhosLoadingIndicator._syncAnimation` 与它的渲染分支改走该入口（!15）
- 新增：`ohosContrastRatio` / `ohosOnFillReadable` / `ohosReadableContrast`（`lib/src/theme/ohos_contrast.dart`）—— 半透明底先 `Color.alphaBlend` 合成到实际背景再算亮度：`computeLuminance()` 不看 alpha，不合成会把 15% 黑算成纯黑，进而误判成「白字压白底」（!13 / !14 / !17 共用同一份工具）
- 修复：`OhosProgressIndicator.capsule` 墨屏文字压在纯黑填充上只剩 1.3:1 —— 改**叠两层字**：轨道层保留官方 `capsuleTextColor`，填充层取 `onHighlightColor`，用与填充同源的 `ClipPath`（`ohosCapsuleProgressPath`，圆头不是直边）裁开，文字跨在 52% 边界上时两半都完整；第二层 `ExcludeSemantics` 防读屏双读，`fill <= 0` 不叠层。阈值取 2 而非 WCAG 3，因为官方彩屏蓝底本身只有 2.8:1（!14，Issue #8）
- 修复：`OhosAlphabetIndexer` 墨屏选中字母黑底黑字糊成一块 —— 实底分支改取 `onHighlightColor`；选中底改成 `SizedBox(dot, dot)` 的**等径正圆**，`dot = min(slot, 条宽)`，宽窄字母的圆不再一大一小。半透明底一律用品牌色，避免深色档「选中/未选中」只剩一圈淡 tint（!13，Issue #7）
- 修复：`OhosChip` 墨屏选中变成「透明底 + 反白字」—— 选中态改走 `policy.selectionMark` 的 `inverse` 约定（实底 + `onHighlightColor` 文字），与 tabs / toolbar 一致；底色最终透明时字色退回正文色。彩屏仍是原来的浅底 + 品牌色（!17，Issue #11）
- 修复：`OhosBadge` 白纸墨屏里与黑色图标连成一片、深色墨屏白底白字 —— 墨屏给本体裹一圈 1vp 纸色描边（`outlineWidth`），数字色按底色亮度取黑白；`OhosFloatingTabBar` 的页签角标复用同一组 `ohosBadgeHalo` / `ohosBadgeForeground`。顺带把墨屏选中药丸从写死 12 圆角、顶到栏外的方块改成**背景层**内缩 4vp 的胶囊，内容区仍占满 56vp，`textScale 1.5` 时不再溢出（!16，Issue #10）
- 修复：`OhosButton` 的 `filled` 变体与 loading 转圈在深色墨屏下写死 `Colors.white` / `Colors.white70` —— 改取 `theme.onHighlightColor`（转圈带 0.7 alpha），浅色/深色彩屏外观不变（!19）
- 修复：`OhosNavigationBar` 悬浮分支构造 `OhosLightMaterial` 时漏传 `borderRadius`，内部模糊背板 / 漫射层 / 边缘高光全按直角算，只靠外层 clip 硬裁；顶部亮线原先写死 `(12, 1) → (width − 12, 1)`，现在按圆角半径内缩、渐变按实际线段取，胶囊两端不再被硬切。库里其余 6 处 `OhosLightMaterial` 调用本来就传了半径（!18）
- 示例：底部页签演示底板补 `clipBehavior: Clip.antiAlias`（平铺栏本身是方角，官方口径贴窗口底边不带圆角）；工具栏演示卡片换 `_FlushTopCard` —— 上直角、下圆角，彩屏与两种墨屏轮廓统一，说明文字补内边距免得首字被圆角切掉（!18 / !20）
- 测试：8 个 PR 共新增 26 条用例，覆盖两层字色与裁切边界、语义去重、半透明填充不误判反白、三档主题角标字色、`textScale 1.5` 不溢出、材质圆角传递、深色墨屏 filled 字色等；两条「墨屏不许有帧动画」的旧断言随 !15 一并转为「墨屏也要走」
- 遗留（本版未动）：`ohos_checkbox_group.dart:233` 的对勾仍写死 `Colors.white`，若选中底同样取 `highlightColor`，深色墨屏会遇到同款白底白勾 —— 建议单开 issue 跟进

## 0.6.0

Release date: 2026-11-04

> 本版把官方「控件概览」42 控件按**形态**逐项做完并重新对账：矩阵从本轮起点的 **227 行** 扩到 **284 行 / 完整 223**，口径变严（多个控件从 1–2 行拆成 5–23 行）。用例 491 → **745**，`example` 用例 **85 → 183 条**（其中溢出矩阵 72 → 170：新增弹层维度 90 条 = 10 种弹层 × 3 尺寸 × 3 字号）。
>
> **7 + 5 = 12 处破坏性变更**，逐条迁移写法见 [`doc/MIGRATION-0.6.md`](doc/MIGRATION-0.6.md)：`OhosActionBar`（9 个参数移除）、`OhosDataPanel`（语义调换，旧用法改名 `OhosStatGrid`）、`OhosToolbarItem.selected` → `state` 枚举、`OhosAlertDialog.borderRadius` 移除（默认 28 → 32）、`OhosSubheader.padding` 移除、`OhosProgressIndicatorVariant.circular` → `ring`、`OhosChipGroup` 默认选中第 0 颗；以及审计轮新增的 `OhosTextClock.timeZone` → `timeZoneOffset`、`OhosRatingBar.value` `int` → `double`、`OhosCheckbox` 默认圆形、`OhosImage.fit` `BoxFit` → `OhosImageFit`、`OhosSelect` 默认不画勾（其中 3 处编译期失败、2 处静默）。共同理由是「旧语义与官方文档对不上，无法在保留旧参数的前提下补齐」。
>
> 好消息：**所有顶层函数（`showOhosDialog` / `showOhosBottomSheet` / `showOhosPicker` / `showOhosMenu`）只新增可选参数、没有删除**；`OhosVisualPolicy` 没有新增抽象成员，外部自定义子类不受影响。
>
> 收尾一轮按 [`doc/AUDIT-0.6.md`](doc/AUDIT-0.6.md) 的 42 控件复核清单**实际改实现**，P0–P3 共 18 项全部落地，用例 **651 → 745**，矩阵 **256 → 284 行**。详见文末「按审计清单对齐（P0–P3）」一节——那里记的是**改动做了什么**与**四条实施中才暴露的事实**（紧约束下「最大宽度」在 Flutter 布局模型里不成立、`SwitchStyle.pointRadius` 是算法不是常数、组件层禁用 `policy.isMonochrome`；以及 P3 轮补充的「链式 `replaceAll` 做模板格式化是错的」「`SliverGrid.childAspectRatio` 会钉死行高」）。

- 新增：`OhosSheetType` / `OhosSheetSize` / `OhosSheetDetent` / `OhosSheetSpec`（`ohos_sheet_type.dart`）—— 对应官方 `bindSheet` 的 `SheetType`（5 值）、`SheetSize`、`detents` 与 `preferType`。**「5 种形态」不是 5 种皮肤，是 5 套能力矩阵**：形状决定的不只是位置，还有圆角（BOTTOM 只圆上面两角、CONTENT_COVER 完全不圆）、蒙层（CONTENT_COVER「不支持蒙层效果」）、标题与关闭按钮（CONTENT_COVER 都没有）、控制条与挡位（SIDE / CONTENT_COVER 都无）、宽高（SIDE 高度恒全屏、CONTENT_COVER 恒全屏）。只换对齐方式会在这五处同时出错
- 新增：`showOhosBottomSheet` 五形态全落 —— 上一版只有 BOTTOM 一种、且把「画什么」写死在渲染里（顶部一条描边、无条件画控制条、标题栏必出、圆角固定 `BorderRadius.vertical(top:)`）。现按 `type` 分别渲染，`SIDE` 用 `showGeneralDialog` + `SlideTransition` 从右滑入（官方「从右向左进入，原地向右退出，不支持自定义转场」），`CONTENT_COVER` 用 `barrierColor: Colors.transparent` 实现「无蒙层」
- 修复：**半模态圆角由 24vp 改为官方 32vp**。24 是 `float.json` 里 `ohos_id_corner_radius_dialog`（**对话框**圆角）的值 —— 同一个「圆角」概念、数值都在 20–30 区间，拿错一个看起来完全合理。这与 `gradientMask` / `barBackgroundStyle` 是同一类错误：**按属性读默认值，不能按名字猜**
- 新增：`detents` 多挡位（枚举挡位与数值挡位混写，最多 3 挡，首挡为初始高度，**生效时 `height` 直接失效**——实测 `height: 200` + 首挡 300 得到 300）。**挡位切换是「速度优先」**：速度过 1000px/s 直接按手速方向切挡、**不看距离**；速度不够才退到「位移 > 当前与目标距离的 1/2」。写成「两个条件都要满足」会让快速轻扫（位移小、速度大）被判成回原挡，而真实手感恰恰相反
- 新增：CENTER / POPUP 的高度夹取 —— 最小 320vp、最大窗口短边 90%、`LARGE`/`MEDIUM` 在这两型下**无效**（恒 560vp）。规格内部有一处冲突：「恒 560vp」与「最大短边 90%」在短边 < 622 时打架，本库选择**照常夹取**（让 560 溢出窗口更糟，且官方夹取条款原文是「大于最大高度则显示最大高度」），已写成显式用例
- 文档：矩阵「半模态面板」6 行 `○` 转完整，统计重算为 **256 行 / 完整 204 / `◐` 4 / `○` 44 / `●` 2 / `—` 2**（`204+4+44+2+2 = 256` ✓，命令连跑两次一致）。用例数 617 → **649**
- 新增：`OhosMiniBar` / `OhosMiniBarStyle` / `OhosMiniBarScaffold` / `OhosBarStyle` / `OhosBarLayoutMode` / `OhosMiniBarAlign`（`ohos_mini_bar.dart`）—— 对应官方 `HdsTabs` 的 `barFloatingStyle.miniBar`。**迷你栏与页签栏是两个独立的栏**（官方单列 `HdsTabsMiniBar`，有自己的宽度分档 `miniBarWidth`、自己的折叠状态 `HdsBarStyle`、自己的动效回调），所以落成独立组件而不是页签栏的一个参数
- 新增：`OhosTabsController` + `OhosAnimationMode` —— 对应官方 `HdsTabsController` 的折叠动效三方法与 `HdsAnimationMode`（`SCROLL_ANIMATION` / `CLICK_ANIMATION`）。**「折叠 / 展开」与「滚动联动」是两套机制，别合并成一个状态机**：前者是一次离散跳变（动效只是附庸），后者是连续位置（绑的是内容区滚动体，与折叠状态无关）
- 新增：`applyMiniBarStyle` / `applyTabBarStyle` / `applyHideAnimation` / `applyShowAnimation` —— 状态没变时**不通知**，否则每次滚动回调都写一遍同样的值，整棵子树跟着重建而肉眼什么都没发生。官方两个 `applyXxx` 收 `mode` 却没说它影响别的什么，本库记进 `lastAnimationMode` 当线索。`applyTabBarStyle` 是**本库补的**（官方 `applyMiniBarStyle` 只管迷你栏，页签栏的折叠由用户点它触发）
- 新增：`bindScroller` / `unbindScroller` —— **只挂只读监听，绝不 `hold()` 或改写 position**。曾经的写法是 `scroller.position.hold()`，那会让内容区滚动卡住不动，单看 API 签名完全看不出来，只能真滚一次（已写成用例）。`parentScroller` 只登记不参与计算 —— Flutter 的 `ScrollPosition` 相互独立、没有等价父子层级，留字段是为了让调用方能照官方签名写，而不是悄悄吞掉一个官方参数。重复绑同一索引会先解绑旧的，否则旧控制器上留着监听、再没人能解掉
- 新增：`OhosMiniBar` / `OhosMiniBarScaffold` 接受 `controller` —— 给了就跟着它走（含折叠动效）；不给则用 `barStyle` / `miniStyle` / `tabStyle` 把状态钉死。两个入口都留是因为**测试与静态展示**不该先 pump 到动画结束 —— 那样测的就不是布局而是动画
- 新增：`OhosMiniBar.motionDuration` 的过渡时长走 `policy.scaleMotion` 而非写死。墨水屏返回 `Duration.zero`、栏直接定格；灰阶屏上的宽度过渡会拖出一条中间灰带，真机上像「栏没画完」
- 文档：矩阵「底部页签」再补两行（控制器折叠动效、滚动联动），统计重算为 **256 行 / 完整 198 / `◐` 4 / `○` 50 / `●` 2 / `—` 2**（`198+4+50+2+2 = 256` ✓，命令连跑两次一致），该控件状态由 `◐` 转**完整**。用例数 617 → **627**
- 新增：`OhosMiniBar.alignFor` —— **官方在 440vp 处换了居中口径**，两条原文只差几个字、结论相反：「宽度小于 440vp … → 页签栏和迷你栏将**整体**底部居中显示」「宽度在 440vp-600vp 之间 … → **展开的**页签栏或迷你栏将底部居中显示」。差别是**折叠者跟着走还是贴边**。抽成纯函数单独守（4 条），塞进布局就只能靠量像素反推
- 修复：**「居中」是相对容器，不是相对兄弟节点**。起初用 `Row + Spacer`，折叠者占掉流式布局的一段，展开者中心被推偏 28vp（520 宽、折叠 56 + 展开 200 时）。改用 `Stack` + `Align` 让两者在同一坐标系各自定位
- 修复：**两个栏的宽度各自独立算出，合计可能超容器**。320vp 屏上「迷你栏 200 + 间距 8 + 页签栏 220 = 428」溢出 68vp —— `Row` 不折行、静态分析毫无提示，是 example 溢出矩阵报 `RenderFlex overflowed by 68 pixels` 才暴露。两侧套 `Flexible` 兜住，并补一条回归用例
- 新增：`OhosMiniBar.initialStyle` —— 官方两条原文合起来才完整：①「首次创建迷你栏时，默认是折叠样式」②「`miniBarStyle` 仅 HdsTabs 宽度小于 600vp 生效设置 … 如果宽度大于 600vp 则为展开样式」。**>600vp 时调用方传什么都不作数**，写成 `requested ?? (width > 600 ? expand : collapse)` 会让显式 `collapse` 在大屏生效，与官方相反
- 文档：迷你栏**折叠态宽度 56 是自拟** —— 官方只给了展开态分档宽度（`miniBarWidth`），折叠态全文未给。取 56 与栏高一致，配 `radius = 高度/2` 正好是正圆。`minibar` / `mini_bar` / `hds` 在三张资源表**零命中**（`floating` 的 18 条全是 `ohos_id_shadow_floating_sm_*` 通用阴影，与页签栏无关）
- 文档：矩阵「底部页签」迷你栏两行 `○` 转完整，并把「居中规则」单独拆成一行（+1），统计重算为 **254 行 / 完整 196 / `◐` 4 / `○` 50 / `●` 2 / `—` 2**（`196+4+50+2+2 = 254` ✓，命令连跑两次一致）。用例数 599 → **617**
- 修复：`doc/CONTROL-MATRIX.md` 第 369 行有一处**历史拼接残留**（「按属性读默认值」那句之后接进了操作栏的账目文字，句子被截断），已切除。这类残留是多次追加式编辑留下的，读起来像「一句话没说完」
- 新增：`OhosFloatingTabBar` / `OhosFloatingTabItem` / `OhosFloatingTabBarStyle` / `OhosFloatingTabScaffold` —— 对应官方 `HdsTabs` 的 `barFloatingStyle`。**这不是 `OhosTabBar` 的一个变体，是另一个形态**：官方把「三档宽度」`HdsBarWidthRangeOptions`、蒙层 `gradientMask`、迷你栏 `miniBar` 全部挂在 `barFloatingStyle` 之下，而它有三个平铺栏一条都不满足的前置条件（`barOverlap=true` 栏叠在内容上、`vertical=false`、`barPosition=End`）。所以落成独立组件
- 文档：**上一版把这批参数排给 `OhosTabBar` 是归属错误**，依据是「只被谁引用」—— `HdsBarWidthRangeOptions` 全文只出现在 `HdsTabsFloatingStyle.barWidth` 与 `HdsTabsMiniBar.miniBarWidth` 两处，平铺栏的 `barWidth` 是单个 `Length`，与三档无关。当时的推理是「都是 tabs 家族的，所以算在已有组件头上」：**按类名归类，而不是按属性找宿主**
- 新增：`OhosTabsWidthDefaults` / `OhosTabsBarWidthRange` / `OhosTabsWidthTier`（`ohos_tabs_width.dart`，纯函数）—— 三档宽度的默认算法。两条易错规则：① **≥4 个页签直接取上限 328，不是「算完再夹」** —— 4 个按 `76×4+8 = 312` 还没到上限，写成 `clamp` 会差 16vp；② **「高宽比」= 高 ÷ 宽**（按中文词序读），600–840vp 区间由它决定中/大档，写成宽÷高会把竖屏平板判成横屏档
- 修复：**328 是绝对上限不是必然值**。容器 340 宽时「16 + 328 + 16 = 360」直接溢出 20vp，官方原文是「最大宽度不超过 328」，所以必须再夹一次可用宽度。`RenderFlex` 不报错，只是把栏挤出屏幕
- 新增：`OhosFloatingTabBarStyle` 的 `barSideMargin` 按宽度三档（**官方值**：<600vp 取 16、600–840vp 取 24、>840vp 取 32）。字段默认 `null` 表示「自动分档」，**不写成 `= 16`** —— 那样就和「调用方显式要 16」无法区分，用 `sideMargin == 16` 反推「他有没有改过」是个会在下一块屏上出错的写法
- 修复：悬浮栏**必须居中，不是靠左**。官方在「迷你栏和页签栏处于左右布局场景时」反复写「整体底部居中显示」；用 `Padding(left/right)` 定位会变成左对齐，栏一窄就贴在左边，肉眼像是漏了一半。边距约束的是栏与容器边界的**最小间隙**，不是定位锚点
- 文档：**纠正上一版的一处「更正」** —— `gradientMask` 的默认值（浅色 `#CCF1F3F5` / 深色 `#99000000`，高度 = 栏高 + **16vp**）**本来就是对的**。上一版把它改成 `#CCFFFFFF` / `#CC000000` / +32vp，那是另一个 API `barBackgroundStyle` 的值。两者共用 `HdsTabsBackgroundStyle` 类型，但**默认值要按「引用它的属性」读，不能按类型读** —— 把一处默认值套到另一处，看起来像「查过文档」，实际抹掉了一个真实存在的项
- 新增：`OhosFloatingTabBar` 栏高默认 **56vp**（`barHeight` 在悬浮样式下的官方默认值；平铺是 48vp，两者差 8vp、肉眼不明显，已用用例守住）
- 新增：`OhosFloatingTabBar` 墨屏退化 —— `allowsBlur` 为 false 时不建 `BackdropFilter`（真机表现为拖尾或留灰块且慢），改画实色底 + 1px 描边（走 `ohosStrokeWidth` / `policy.line`）；选中态走 `policy.selectionMark`，`inverse` 档用实底 + 纸色文字，因为灰阶屏上 `highlightColor` 与 `textPrimaryColor` 都是纯黑
- 文档：**悬浮栏的几何大多是自拟**。`hds` / `floating` 在 `pattern.json` / `float_sys.json` / `float.json` 三张系统资源表里**零命中**（与 `HdsActionBar` 完全同型）；能指到令牌的只有 ArkUI 通用 tabs 家族那批（`ohos_id_tab_padding` 16vp、`ohos_id_tab_gradient_width` 24vp、`ohos_id_tab_default_height` 56vp、`ohos_id_bottomtab_height` 48vp），它们属于**平铺栏**，用来给 `OhosTabBar` 对账，不能拿来当悬浮栏的值
- 文档：矩阵「底部页签」由 **4 行改写成 6 行**（+2），当时统计为 253 行 / 完整 193 / `◐` 4 / `○` 52 / `●` 2 / `—` 2（已被迷你栏那次更新到 254）。用例数 580 → **599**（宽度算法 6 条 + 悬浮栏 13 条）
- 文档：**源码快照更新后，`chipgroup.ets` 的 `enum ChipGroupHeight { NORMAL = 36, SMALL = 28 }` 已不存在** —— 上游把尺寸并进 `chip.ets` 的 `ChipSize { NORMAL = "NORMAL", SMALL = "SMALL" }`（字符串成员），高度改由 `$r('sys.float.chip_normal_height')` / `chip_small_height` 令牌给出。这是与 `subheader.ets` 同类的**判据退化**：源码从「写字面值」变成「只写令牌名」，源码层对 chip 高度不再答得出数值。核对令牌真值 `36vp` / `28lpx` 与原硬编码**一致**，故 `OhosChip` / `OhosChipGroup` 实现无需改动
- 文档：`doc/reference/source/README.md` 与 `doc/ROADMAP-0.6.md` 里的 `.ets` **行号引用全部移除**，改为「搜键名」。这批快照随上游漂移且不入库，行号是最脆弱的定位方式 —— 本轮三个行号（`chipgroup.ets` 46 / 63、`chip.ets` 371）在同步后同时失效。三张资源表的行数（9701 / 4112 / 1816）同样过期，改记**条目数** 67 / 1080 / 507
- 行为变更（**破坏性**）：`OhosActionBar` 结构改造 —— `startButtons` / `endButtons` 两端按钮组取代单一 `secondaryActions`，`primaryLabel` / `onPrimaryPressed` / `primaryLoading` / `expandable` / `isExpanded` / `onIsExpandedChanged` / `primaryIcon` / `primaryTooltip` 全部移除。官方 `HdsActionBar` 从来只有「起始组 + 主按钮 + 末尾组」这个形态，0.5.x 的「全部放一侧」是当时没读文档的产物。布局用三段 `Expanded`（左右各一段 + 中间主按钮）而不是 `Spacer` —— 两侧按钮数量不等时（左 1 右 3）`Spacer` 会把主按钮推偏，居中失效。`isExpand` **默认 `false`**（官方值），与旧 `expandable` 默认展开相反
- 行为变更（**破坏性**）：`OhosDataPanel` 把名字还给官方，旧的 KPI 卡片网格改名 `OhosStatGrid`（`ohos_stat_grid.dart`，签名与旧 `OhosDataPanel` **逐字相同**，视觉不变）。这是一次「名字对、语义不符」的纠正：0.5.x 的 `OhosDataPanel` 是「标题 + 若干数值 + 列数」的统计卡片，而官方 `DataPanel` 是**占比图**（环形 / 条形，表示数据构成比例）—— 两者语义完全不同却占着同一个名字。新的 `OhosDataPanel` 按官方落 `values` / `max` / `type`（`OhosDataPanelType.circle` / `.line`）/ `strokeWidth` / `trackShadow` / `closeEffect`。升级时旧代码会报 `'title' isn't defined` 与 `'values' is required`，**编译期就能拦下**，不会悄悄画错
- 新增：`OhosActionBarButton`（官方 `ActionBarButton` 17 个属性里落 12 个）与 `OhosActionBarStyle`（官方 `ActionBarStyle` 10 个字段全落），`OhosActionBarMetrics` 几何常量表，`OhosBlurStrategy` 枚举。样式是值对象、实现 `==` / `hashCode` —— 缺了它 `updateShouldNotify` 静默失效
- 文档：**`OhosActionBarMetrics` 里每个数都是自拟，这是本项最需要说清的一点**。`HdsActionBar` 属 HDS 闭源套件：`pattern.json` / `float_sys.json` / `float.json` 三张系统资源表搜 `actionbar` / `action_bar` **全部零命中**（连 `hds` 前缀都一个不存在），293 行参考文档**只列属性、一条默认值数值都没给**，设计规范（`component_actionbar`）只有定性描述「悬浮在页面下方」「组件背板默认带有模糊材质和投影」。所以按钮 56 / 次按钮 40 / 图标 24 / 栏高 72 / 圆角 24 / 间距 8 / 边距 16 全部标了「自拟」。**这与 `OhosListGroup`（12 / 4 / 24 大多能指到令牌）是相反情形**，与 `OhosListItemCard` 相同
- 新增：主按钮双图标 `baseIcon` / `altIcon` + `OhosActionBarStyle.isPrimaryIconChanged`。官方把它放在 style 而非按钮上（它是整个操作栏的状态，展开/收起常与图标切换同步）。**缺 `altIcon` 时回落 `baseIcon`** —— 与 `OhosChip.selectedIcon` 同一条规则：「切一下就掉图标」不是双态而是缺陷
- 新增：自定义主按钮 `primaryButtonBuilder` + `primaryButtonBuilderWidth`，优先级高于 `primaryButton`（官方原话）。官方「设置 `primaryButtonBuilder` 时必须同时设置 `primaryButtonBuilderWidth`」是硬约束 —— 自定义 builder 没有内在宽度，缺了它无法排版，所以缺宽度直接 `assert` 失败而不是静默取默认
- 新增：`ActionBarStyle` 五个间距参数 `height` / `innerSpace` / `startSpace` / `endSpace` / `margin`（此前 padding 写死）。**`startSpace` / `endSpace` 在竖直排列下映射到上下边框而不是左右** —— 官方在参数说明里逐字写了「水平排列时为左边框，竖直排列时为上边框」。按名字固定成 left/right 是个很容易犯、视觉上又不易察觉的错，已用用例钉住
- 修复：`OhosActionBar` 竖直排列时 `RenderFlex overflowed by 80 pixels`。背板高度原先无条件钉死 72，而竖直排列下 3 行按钮 + 间距需要 152。改成分支处理：水平排列固定高（`ActionBarStyle.height` 的语义是「背板高度」，横向栏才有这个形态），竖直排列只给 `minHeight`。**这是又一个只有真 `pumpWidget` 才能发现的布局错误**，`flutter analyze` 全绿
- 新增：`OhosActionBar` 默认开模糊材质 —— `blurStyle` 默认 `OhosLightMaterialLevel.regular`（对应 `COMPONENT_REGULAR` = `BlurStyle` 枚举值 10「组件普通材质模糊」，见 `ts-universal-attributes-background.md`）。**默认真开是有依据的**：设计规范把这件事写成默认属性而非可选装饰。墨屏由 `policy.allowsBlur` 判掉、改画实色 + 1vp 描边（`BackdropFilter` 在墨水屏真机退化为「拖尾」或「留灰块且慢」）；`blurStrategy: disabled` 走同一条退化路径，但原因不同 —— 一个是硬件画不出来，一个是调用方显式关掉
- 文档：`OhosBlurStrategy.adaptive` 与 `enabled` 处理成一致，并在 dartdoc 里**写清「Flutter 读不到系统性能档位」**而不是假装做了自适应。官方 `ADAPTIVE` 的解释是「三档系统策略：精美、轻柔、流畅，只有精美档位能生效模糊，由设备厂商配置」—— 一个静默等同的枚举值，好过一个返回 `true` 的 `isBlurAllowed()`
- 新增：`OhosActionBarStyle.enabled` 整体禁用 —— 它是**总开关**，不是背板自己的开关（官方原文「`enabled=false` 则背板不启用并且所有按钮都不启用；`enabled=true` 时每个按钮可以单独设置」）。实现上与逐按钮 `enabled` 做 `&&`，并用 0.4 不透明度表达「还在、但不能操作」
- 文档：**逐按钮阴影 `shadowStyle` 主动不做**。官方默认 `OUTER_DEFAULT_LG`，但 `ShadowStyle` 枚举只给「大阴影」这种定性描述，`OUTER_DEFAULT_LG = 3` 只是枚举序号，`shadow.h` 里也无数值表 —— 与 `textfield_error_spacing` 同类：**有名字、无值**。自拟一组阴影数字不难，但那是编造官方规格。矩阵记 `○`
- 修复：`example` 的 `container_page` 报了整片「Vertical viewport was given unbounded height」。根因不是当轮改的组件 —— 是上一版加进去的 `OhosListItemCardList`（内部是 `ListView`）被放进了 `DemoScaffold` 的纵向 `ListView`，两个纵向视口嵌套；`shrinkWrap` 参数本来就有、默认 `false`，example 里没传。**上一版改完 example 没跑溢出矩阵，这个错误漏了整整一轮** —— 与「`flutter analyze` 看不见布局问题」是同一条教训的第三次出现
- 文档：矩阵「核心操作栏」由 **13 行改写成 16 行**（+3），统计重算为 **251 行 / 完整 189 / `◐` 4 / `○` 54 / `●` 2 / `—` 2**（`189+4+54+2+2 = 251` ✓，命令连跑三次一致）。用例数 570 → **580**（`OhosActionBar` 由 3 条扩到 13 条，净增 10）。`example` 溢出矩阵 **85 条全过**
- 新增：`OhosAlertDialog` 补全 `CustomDialogControllerOptions` 的九项规格，新增 `OhosDialogMetrics` / `OhosDismissReason` / `OhosDismissDialogAction` / `OhosDialogLifecycle` 四个类型与八项参数（`customStyle` / `isModal` / `maskColor` / `gridCount` / `width` / `height` / `lifecycle` / `onWillDismiss`），组件从 `StatelessWidget` 改为 `StatefulWidget`。**尺寸是「上限」不是「固定值」**：`maxWidth = 400`、`maxHeight = 0.9×(窗口高−安全区)` 都是 `ConstrainedBox` 的上限，内容短了弹窗自己收缩，高度**不给 `minHeight`**（超了由内层 `Flexible` + 滚动消化）。乘的是「窗口高 − 安全区」而不是窗口高 —— PC/2in1 上要避让屏幕边缘与窗口标题栏，直接用窗口高会让底边被裁掉
- 行为变更（**破坏性**）：`OhosAlertDialog.borderRadius` 参数移除，圆角改由 `OhosDialogMetrics.borderRadius` 恒定 **32**（旧参数默认 28）。移除的理由与 `customStyle` 的分档一致：非自定义壳时圆角是官方规格、不该由调用方逐处覆写；要自定义就走 `customStyle: true` 把整个壳交出去。**注意这是静默视觉变化** —— 删掉那个实参不会报错，但圆角会大 4vp
- 文档：**`width` 的语义是夹取，`gridCount` 的语义是回落 —— 两种不同处置，不能互换**。`width: 800` 官方「设置后不超过默认最大宽度 400vp」⇒ `clamp(0, 400)` 夹回 400；而 `gridCount: 999` 官方「异常值按默认值处理，最大栅格数为系统最大栅格数」⇒ 返回 `null` 走默认宽度路径。**夹取会让 `gridCount: 999` 悄悄变成「占满整屏」** —— 一个写错数字的调用方得到一个恰好像占满的弹窗，比明确回落更坏
- 新增：`OhosAlertDialog.customStyle` 两档语义（不是加个开关）。`false`（默认）→ 圆角 **32**（比本库 `radiusLarge`(24) 还大一档，弹窗是官方少见的「圆角比卡片更大」的容器）、不透明背板、`padding` 16、1px 描边；`true` → 圆角 **0**、背板 `Transparent`、无内边距、无描边，**壳完全交给调用方**。ROADMAP 原计划写的是二选一（要么对齐 32、要么声明本库只走 `customStyle: true`），落地时发现两者不冲突：默认档对齐官方 32，可选档才是「壳交出去」
- 新增：`OhosAlertDialog.isModal` / `maskColor`。遮罩默认 `0x33000000` = **20% 黑**，而 Material 的 `barrierColor` 是 `Colors.black54`（54%）—— **差一倍多**。官方的遮罩更淡，靠弹窗自身底板与投影分层，而不是把背景压黑；照抄 Material 的 54% 会让整屏发灰、失去层级。`isModal: false` 在**两种入口下语义不同**，因此写成两档而不假装全支持：直接构造时是真的非模态（不画遮罩、不拦截下层手势），经 `showOhosDialog` 弹出时路由上的 `ModalBarrier` 一定存在，这个参数只能表达「不画那层 20% 黑」—— 下层依旧点不到
- 新增：`OhosAlertDialog.lifecycle` 四段（`onWillAppear` → `onDidAppear` → `onWillDisappear` → `onDidDisappear`）。`onDidAppear` 用 postFrame 近似并判 `mounted && !_disappearing` —— 官方写明「动效被打断则不触发 `onDidAppear`」，这个判断在嵌入式构造下没有真动效可被打断，只是让它与路由级行为一致。销毁时补发退出回调，避免调用方漏收
- 新增：`OhosAlertDialog.onWillDismiss` + `OhosDismissReason { pressBack, touchOutside, closeButton }`。**官方语义与 Flutter 相反**：注册后**不调 `dismiss()` 就不关**，不是「返回 false 才拦」。为此 `showOhosDialog` 在给了 `onWillDismiss` 时**把路由的 `barrierDismissible` 强制设成 false** —— 否则路由先 pop、回调跑不跑都来不及看。`OhosDismissDialogAction` 用 `_dismissed` 标志位保证重复调用幂等。reason 只落三值（照官方值序），`slideDown` / `slide` 属半模态、不是弹窗能产生的事件
- 修复：**`Center(child: Stack(...))` 里 `Positioned.fill` 的遮罩不会铺满全屏**。`Center` 给子节点的是**松约束**，`Stack` 会收缩到弹窗大小 —— 实测那层「全屏遮罩」只有 **179×124**（弹窗尺寸），点弹窗外面根本命中不到，于是「点遮罩应该关」完全失效。必须外套 `SizedBox.expand`。这个 bug 在 2019 条静态分析全绿时看不出来，只有交互用例跑起来才暴露
- 修复：`tester.getSize(find.byType(OhosAlertDialog))` 量到的是**铺满全屏的 `Center` 根节点**，永远等于窗口宽 —— 拿它断言「宽度 ≤ 400」恒真是**假绿**。改用 `dialogSurface()` 量那层 `ClipRRect` 弹窗壳。另：`setSurfaceSize` **不改 `MediaQuery`**，栅格用例算出 179 而非 180（断点判成 medium / 8 列），要同时设 `tester.view.physicalSize` + `devicePixelRatio`
- 文档：**`maskRect` 的「区域外事件透传」没做**，记 `○`。Flutter 侧需要自定义 hit-test 区域，而官方那个默认值（`{0,0,'100%','100%'}`）本身也等价于全屏 —— 不支持的部分不影响任何默认行为。**主动不做**：`showInSubWindow` / `levelMode` / `levelOrder` / `immersiveMode`（属于 ArkUI 窗口层级体系，Flutter 侧没有对应物，强行模拟只会得到一套假的层级语义）
- 文档：矩阵「弹出框」7 行由 `○` 转完整，统计重算为 **248 行 / 完整 175 / `◐` 7 / `○` 62 / `●` 2 / `—` 2**（`175+7+62+2+2 = 248` ✓，命令连跑三次一致）。用例数 555 → **570**（`OhosAlertDialog` +15），example 新增 3 段演示（栅格列数 + 拦截关闭 / 壳交出去 / 非模态）
- 新增：`OhosTextFieldVariant.inline`（内联形态）、密码模式（`obscurePassword` 一组六个字段）、字数计数器（`showCounter` + `OhosInputCounterOptions`），并抽出 `OhosTextFieldMetrics`。**内联有三条官方硬约束，任何一条不满足都回落成下划线形态**（不画「半内联」）：只支持 `InputType.Normal`（单行不遮蔽）、不支持 `showError`、**内联/密码模式下计数器不显示**。最后一条最容易漏 —— 它写在 `showCounter` 的说明里，单看那个接口不会知道跟另外两个形态互斥。落地用派生 getter `_inlineEffective` 一次算清、`switch (effective)` 统一消费，避免「这处判了那处忘判」
- 新增：密码形态不是一个 `obscureText` 开关，是一整套视觉 —— 末尾 **24vp** 眼睛图标（`textfield_icon_size`，与 `passwordIcon` 属性说明「固定尺寸为 24vp」两处独立印证）、**40vp** 命中区（`textfield_icon_hot_zone_size`）、容器高 **48**（`password_style_height`）。显隐状态取**组件内受控**并用 `onSecurityStateChange` 把真实状态抛出：官方 `showPassword(visible)` 是受控属性且文档点名了不受控的风险（前后端状态不一致会导致图标异常），但每次点眼睛都要求调用方 setState 太啰嗦。`obscurePassword` 与原有 `obscureText` 是同一形态的两个入口，用 `_obscured` 收口
- 新增：计数器四个前置条件缺一不可 —— `showCounter` + `maxLength != null` + 非内联非密码 + 过阈值。`thresholdPercentage` 有效区间 `[1,100]`，**超出区间时不显示计数器**（不是夹到边界）；「显示但不过滤」对应的是 `undefined`。字号 **10fp**（`count_text_font_size` → `ohos_id_text_size_caption1`），比本库 `labelSmall`(12) 还小一档，但这就是官方值。三个颜色令牌别混：`count_text_color`=`font_tertiary`（正常）、`over_count_text_color` / `over_count_border_color`=`warning`（溢出）、`over_text_color`=`alert`（被截掉的输入文字）
- 修复：**填充形态实测渲染 52vp，官方 40 —— 两层原因叠在一起，任何一层没查出来都会误判成「官方 40 做不到」**。第一层：`contentPadding` 是早前自拟的 `14/14`，而 `textfield_padding_horizontal`(→`padding_level8`=16) / `textfield_padding_vertical`(→`padding_level4`=8) 从没接上，8+24+8=40 才对。第二层：改回令牌后仍是 48 —— `InputDecorator` 在 `isDense == false` 时把容器高**夹到 `kMinInteractiveDimension`(48) 以上**（`input_decorator.dart` 的 `minContainerHeight`），这是无障碍最小触摸目标兜底，会把 40 的规格无条件覆盖。必须显式开 `isDense: true` 才拿得到 40。同时补上下划线形态的真实值：`textfield_underline_padding_vertical`(→`padding_level6`=12) × 2 + 24 = **48**
- 修复：**容器圆角从主题 `radiusMedium`(16) 改成令牌 `textfield_border_radius` = 20**。两个圆角令牌 `textfield_border_radius`(20) 与 `border_radius_size`(12) 都在 `ohos_textfield_pattern` 里，先前按名字猜成「12 是容器」，实测**两个都对不上**（代码用的是 16）。去读源码才定论：`text_field_pattern.cpp` 里 `auto radius = theme->GetBorderRadius();` 后紧跟 `IsUnderlineMode() ? ZERO_BORDER_RADIUS_PROPERTY : borderRadius` —— 非下划线用 `textfield_border_radius`、下划线**显式归零**；而 `GetBorderRadiusSize()` 在整个 `text_field/` 目录 **grep 零命中**（`textfield_theme.h` 里有成员、有访问器，就是没人调）。常量保留但标「死令牌、不参与渲染」，矩阵**不给它开数据行** —— 与搜索框的 `search_text_field_padding_left` 是同一类病
- 修复：**密码形态的 48 不随底板变化**。`password_style_height` 是独立容器高，只在「内边距恰好算成 48」的下划线形态上碰巧成立；填充底板上按内边距算是 40，必须单独加最小高度约束。另修正错误描边从 1.5 改成 **1vp**（`textfield_error_border_width`）—— 官方靠**换色**（`error_text_border_color`=`alert`）而不是加粗表示错误，1.5 会让错误框比聚焦框粗、视觉上跳动；错误提示字号接上 **12fp**（`error_text_font_size`）
- 修复：`InputDecoration.suffixIconConstraints` 默认 **48×48**，会把本库 40 的密码命中区撑到 48、24 的图标在里面对不齐（实测 `getSize(icon)` 拿到 48 才发现）。需显式传 `const BoxConstraints()`。**同一类坑第二次**：上一次是 `OhosListItemCard` 的语义标签被自动补全的祖先文本污染，都属「框架默认值悄悄接管了本库已经定好的几何/语义」
- 文档：**`textfield_error_spacing`(8) 明写「未接」而不假装实现**。它决定错误提示与输入框的间距，但 Flutter 侧这个间距是 `InputDecorator.subtextGap`，M3 写死 4、无 decoration 级入口；要对齐只能自己画错误提示，会连带失去 `_hasError` 的自动推导 —— 收益不足以抵风险，常量留在 `errorSpacing` 备后续
- 修复：**`OhosTextField` 新增的 7 条几何用例全部量真实渲染尺寸**（`tester.getSize` / `decoration.isDense` / `errorBorder.width`），而不是像原来那条「几何令牌逐条可查」只断言常量字面值。后者在 52vp 偏差存在时**依然全绿** —— 这是「常量写对了 ≠ 常量被用上了」的直接证据，也是本轮把 D-3 的教训（`suffixGap` 声明了零调用方）在 D-4 又踩一遍的地方
- 文档：矩阵「输入类」再拆 —— 文本框由 **7 行拆成 14 行**（+7），统计重算为 **248 行 / 完整 168 / `◐` 7 / `○` 69 / `●` 2 / `—` 2**（`168+7+69+2+2 = 248` ✓，命令连跑三次一致）。用例数 524 → **555**（`OhosTextField` +31：密码 6 + 内联 6 + 计数器 12 + 几何 7）
- 新增：`OhosListItemCard` + `OhosListItemCardList` —— 承接 HDS `HdsListItemCard` 的 **A-B-C 三区**列表卡片：A 区图形、B 区三层文本、C 区后缀。**先纠正了 ROADMAP 里的两个错数**：原文写「19 种 suffix / 8 种 prefix」，按 `^## Suffix` 清点得 21 条、扣掉基类与 3 个 `*Options` 是 **17 种**；`^## Prefix` 得 10 条、扣掉基类与 `PrefixIconOptions` / `PrefixIconType` 是 **7 种**。两处错法相同 —— **把 `*Options` / `*Type` 这类类型定义也当成了形态**，与仓库里「按目录名推文件名」是同一族错误。清点必须逐条读定义句（「定义 Xxx 类，A 区…元素」），不能只数章节标题
- 新增：`OhosListItemCardSuffix` 的 **9 种具名构造器** —— `text` / `image` / `loading` / `radio` / `checkbox` / `switchButton` / `arrow` / `select` / `badge`，另加 `custom` 兜住其余 7 个组合型与需 Symbol 字体的。**每个构造器强制收自己需要的内容**（`required` 位置参数），写不出「声明了 radio 却没给 radio」的组合。这条来自一次自捕获：首版六个枚举值只读 `builder`、而具名构造器从未给它赋值，结果是**永远渲染空白**的开关 —— 传了但没反应，比不支持更坏
- 文档：**A 区 7 种 / C 区 17 种没有逐一照搬成 7 + 17 个类**。ArkTS 是单字段单类型才需要那么多子类，Flutter 的 `Widget` 本身就是共同类型，照搬只会得到一堆只装一个 Widget 的空壳。收成 `OhosListItemCardPrefix(child, size)`（两档尺寸对应官方 `IconSize.SMALL_ICON` 16 / `SYSTEM_ICON` 24）+ `Suffix` 具名构造器
- 文档：**`OhosListItemCardMetrics` 里几乎每个值都是自拟，这是本项最需要说清的一点**。HDS 是闭源组件：`pattern.json` / `float_sys.json` / `float.json` 三张资源表搜 `list_item_card` / `listitem` / `hds` **全部零命中**，1944 行参考文档只给了两处数字（`IconSize` 的 16 / 24，与穿戴设备 `PrefixImage` 固定 46×46，属 wearable 适配不在本库范围）。这与 `OhosListGroup`（12 / 4 / 24 大多能指到令牌）是**相反的情形** —— 所以每条常量都单独标注了出处，不能让后人误以为是官方默认值
- 修复：`OhosListItemCard` 的 `cardHeight` 从 64 改成 **72** —— 被测试逼出来的。`bodyLarge` 16×1.5 = 24、`bodySmall` 14×1.5 = 21，三层 + 两个 2vp 间距 = **70**，64 只够两行，`Column` 溢出 6vp。算错的原因是把**字号当成了行高**，这是「照抄常量前先算」的第二次翻车（上一次是 `OhosDateCounter` 的 16+1+16 > 32）。已加一条用例钉住「三层同时出现不溢出」
- 修复：`OhosListItemCard` 的无障碍标签会**念两遍**。`Semantics(label:)` 默认不是语义边界，实测节点标签是「拼好的一句 + 三层原文各一行」（`无线网络，已连接，信号强\n无线网络\n已连接\n信号强`）。加 `container: true` + `excludeSemantics: true` 才收成一个边界。官方 `accessibilityOptions` 的 `isGroup` 做的就是这件事，文档只说「组合聚焦播报」、没说「不加就会重复」—— 又一处「文档沉默」
- 新增：`OhosListItemCard` 的三层文本按官方**并列**而非二选一（`primaryText` / `secondaryText` / `description` 是三个独立字段，示意代码三层同时出现），字阶按语义分 `bodyLarge` / `bodySmall` / `bodySmall`；`contentBuilder` 优先级照搬官方原话「`customBuilder` 优先级高于其它接口」，给了就整块替换 B 区、三层文本与主标题图标一起让位。**不做**副 Symbol（8 个字段，官方写明「仅在左侧第一个 Symbol 存在时才显示」，16vp 图标旁再叠一个必然挤成一团）、`hoverBorderRadius`（Flutter 没有「hover 时单独换圆角」的机制）
- 文档：矩阵「列表」再拆 —— 原「A 区前缀（8 种）」「C 区后缀（19 种）」两行展开成 **16 行**，统计重算为 **241 行 / 完整 158 / `◐` 7 / `○` 72 / `●` 2 / `—` 2**（`158+7+72+2+2 = 241` ✓，命令连跑三次一致）。用例数 491 → **524**（`OhosListItemCard` +29、`OhosListItemCardList` +4）
- 新增：`OhosListGroup` + `OhosListGroupSliver` —— 补齐 ArkUI `ListItemGroup` 的分组能力：`style: none|card`、`header` / `footer`、`space`、`divider`，以及**吸顶组头**。**先拆清了 `sticky` 的归属**：它写在 `List` 的属性章节（`ts-container-list.md`），`StickyStyle` 枚举也在那一页 —— 这不是文档排版失误，是规格事实：一次管住列表内所有分组。Flutter 侧的「吸顶」是 sliver 行为（`PinnedHeaderSliver`），盒子形态根本无处可吸，所以拆成两个类，`sticky` **只出现在 `OhosListGroupSliver` 上** —— 盒子形态传了会得到一个「传了但没反应」的开关，那比不支持更坏。粒度上本库逐组声明、官方整表一次，逐组能表达的集合严格更大（每组可各选吸顶或不吸）
- 修复：吸顶组头**必须自带背板，而文档完全没提这件事**。`PinnedHeaderSliver` 只负责把子节点钉在视口顶端、不负责遮挡 —— 照文档做会得到一个浮起来却透明的组头，下面的行从它身上穿过去。真实规格在源码 `ListItemGroupPattern::ApplyHeaderFooterStyle`（`list_item_group_pattern.cpp:900`）：先 `UpdateBorderRadius(GetItemGroupDefaultBorderRadius())` 补分组圆角、再套 `UiMaterial::IMMERSIVE / THICK` 沉浸材质，本库对应 `OhosLightMaterial(level: OhosLightMaterialLevel.thick)`。这类「文档只讲交互、不讲视觉」的缺口，四层对照里只有第四层能补
- 文档：**卡片样式的三个数分处三个来源，复核方式因此不同**。`cardMargin = 12` 走资源表（`ohos_id_card_margin_start` / `_end`，经 `list_item_pattern.item_margin_left/right` 指向，`float.json` 两值都是 `12.0vp`）；`cardPadding = 4` **只在文档正文**（「卡片样式下…上下左右内边距 4vp」），资源表无对应令牌；`cardRadius = 24` 走 `list_item_pattern.item_border_radius` → `ohos_id_corner_radius_default_l`（`24.0vp`）。行级 CARD 的 **48 / 8** 同样只在正文（「高度 48vp、宽 100%、左右内边距 8vp」）—— 五个数里只有三个能跑 `fetch_sys_resources.sh` 复跑，另外两个只能对文档
- 新增：`OhosListGroupItemStyle`（行级 CARD）与 `OhosGroupDivider`。**`group.style` 与 `itemStyle` 是两个独立参数**，可自由组合 —— 官方示例 2 里 `CARD+CARD` / `CARD+NONE` / `NONE+CARD` 三种组合都出现过，合并成一个「外观档」会表达不了。**`space` 只作用于项与项之间**，不作用于组头与首行、末行与组尾（官方明文，也是最容易和「给每行加 padding」混淆的一条），用例把「组头→首行 8 / A→B 20 / 末行→组尾 8」三种距离分别钉住。**分组的 `divider` 默认 `null`（一条不画）**，与 `OhosList.divider: bool`（默认 true）**相反**；组接管分隔线后用 `OhosListDividerScope` 把行内 tile 自带那条压掉，避免双线
- 文档：**主动放弃吸底组尾（`Footer` / `BOTH`），标 `○` 而不是留一个不可靠的实现**。写过一版，用 `remainingPaintExtent` 推「视口末端距本 sliver 多远」，实测该值在 `SliverMainAxisGroup` 内部已被同组前面的子 sliver 扣掉、且滑出视口时被夹到 0 —— 「组尾原来在视口下方多少」这条关键信息恰好在需要它时丢失，吸底链会算成「原地不动」。换 `precedingScrollExtent` 与视口滚动量之差方向是对的，但同样拿不到视口自己的滚动量，仍是猜的。宁可留缺口 + 一条钉住缺口的用例（组尾应 `findsNothing` —— 它落在视口外根本没被构建，真吸底了就一定被构建），也不留一个「多数情况看着对、滚到某些位置就错位」的实现
- 文档：矩阵「列表」由 **4 行拆成 11 行**，统计重算为 **227 行 / 完整 145 / `◐` 7 / `○` 72 / `●` 2 / `—` 1**（`145+7+72+2+1 = 227` ✓，命令连跑两次一致）。新增的 6 行完整是「组头/组尾 builder」「`space`」「组内分割线」「组卡片」「项卡片」「吸顶组头」；另有 1 行 `○`（吸底组尾）、1 行 `—`（`childrenMainSize` 在 Flutter 无对应需求 —— ArkUI 的 `List` 需预声明子项尺寸才能精确跳转，`SliverList` 逐项测量）。复核脚本同时补上 `—` 分支，否则它会掉进 `else` 被算成「完整」。用例数 471 → **491**（`OhosListGroup` +13、`OhosListGroupSliver` +7）
- 行为变更（**破坏性**）：`OhosProgressIndicatorVariant` 的 `circular` 成员改名 `ring`，枚举从 2 值（`circular` / `linear`）扩到 5 值（`linear` / `ring` / `eclipse` / `scaleRing` / `capsule`）。改名是因为官方 `ProgressType` 里这一型叫 `Ring`，而 `circular` 与 `eclipse`（月相）都是「圆形」，按旧名字读会以为 `eclipse` 是它的子类。**构造器 `OhosProgressIndicator.circular()` 保留不动** —— 只改枚举成员，所以只用构造器的代码不受影响；读 `variant` 做判断的代码会报 `There's no constant named 'circular'`。对 `variant` 做穷举 `switch` 且无兜底分支的地方也会编译失败（新三型需要你决定怎么处理）
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

- 行为变更（**破坏性**）：`OhosSubheader.padding` 移除，`title` 从 `required` 改为可选。`padding` 删掉是因为它本不该由调用方定 —— 横向边距由官方 `getAreaPadding()` 按形态决定（副标题单行或副标题 + 图标时 12，其余 0），纵向是 `subheader_content_padding` = 8；给一个会被内部覆盖的值比不给更坏。需要控制边距请用 `contentMargin`（外层，默认横向 16）/ `contentPadding`（内层，默认纵向 8）。`title` 变可选是为了让「只有副标题」「只有 leading」两种官方形态可达，三者全空时由 `assert` 拦下。**旧的 `padding: (16,16,16,8)` 与新的 `contentMargin` 16 横 + `contentPadding` 8 纵观感接近但不完全等价**（旧的上方共 16、新的上下各 8）

- 新增：`OhosChip.selectedIcon` / `OhosChipItem.selectedIcon` —— 补齐 ArkUI `prefixSymbol` 的 `normal` / `activated` **双态图标**。`chip.ets:838` 的 `getPrefixSymbolModifier()` 是 `isChipActivated() ? prefixSymbol.activated : prefixSymbol.normal` —— 两态是**两个不同的图形**（描边→实心），不是同一图形换色；此前本库只有单图标 + 跟随选中态换色，等价于只做了 `activatedFillColor`。**有意偏离一处**：`chip.ets:1014` 的 `hasPrefix()` 写成 `isChipActivated() ? !!activated : !!normal`，只给 `normal` 时选中态连图标**和间距**一起消失。照搬会让既有用法（只传 `icon`）在被点中的一瞬间掉掉图标 —— 那不是双态而是缺陷。本库改为「选中态优先 `selectedIcon`，缺省回落 `icon`」，并补一条用例钉住「只传 `icon` 时选中不消失、间距仍 6」
- 新增：`OhosChipGroup.startSpace` / `endSpace` / `padding` —— 把 `chipGroupSpace` 的三段补全。`chipgroup.ets:46` 的默认值是 `{itemSpace: 8, startSpace: 16, endSpace: 16}`，而本库原来只有一个 `spacing`，只够表达**中间那一段**，首尾 16 全丢了 —— 于是首颗芯片紧贴容器边、滚动到起点时看起来像溢出容器。`chipGroupPadding` 同步补上（默认 `{top: 14, bottom: 14}`，整组高 = 36 + 28 = 64）；横向刻意不生效，它由 `startSpace` / `endSpace` 独占，两者同时生效会让首端变成 32
- 行为变更（**破坏性**）：`OhosChipGroup` 不传选中项时**默认选中第 0 颗** —— ArkUI 声明 `selectedIndexes: Array<number> = [0]`，且 `aboutToAppear` 在解析结果为空时再补一次 `[0]`（`chipgroup.ets:332` / `:356`），刚建好的组永远不是全空闲态；`multiple=true` 时同样如此（两种模式共享同一个数组）。这是**破坏性变更**：0.5.x 不传就一个都不选中。想保留旧表现请显式传 `selectedIndex: -1`（或 `selectedIndexes: const <int>{}`），已补用例钉住「旧表现仍可达」，否则升级路径是断的
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
- 文档：`CONTROL-MATRIX.md` / `ROADMAP-0.6.md` / `doc/reference/source/README.md` 三处同步：`search_text_field_padding_left` 标注为**死令牌**并附调用方查证结论；搜索框与芯片的偏差行从 `◐` 改为完整实现；阶段 D 第 4、10 项标注尺寸部分已完成、剩余工作只剩新形态（chip 的 `allowClose`、search 的右侧按钮）；用例数 268 → 271

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
- 文档：**新增第四层对照基准 —— 组件实现源码**（`doc/reference/source/` + `tool/fetch_source.sh`，29 份 `.ets` / 36,354 行）。前三层（设计规范 / 参考文档 / 文档示例）答得了「有哪些形态、默认值是什么」，答不了「具体画多大」：官方 `Chip` 文档把高度写成 `$r('sys.float.chip_normal_height')`，那是令牌**引用**不是数值，而令牌的真实值编在二进制 `resources.index`（RestoolV2，1.3MB）里、`strings` 只能读到名字。源码里不走 `$r(...)` 的部分则直接写着数值。抓取范围刻意只限 ArkTS 进阶组件：系统组件的 C++ 侧几何值几乎全走 `theme->GetAttr(...)`，同样退回令牌，实测 `search_layout_algorithm.cpp` 1060 行只有一条 `DEFAULT_DIVIDER_HEIGHT = 12.0_vp`
- 文档：源码层第一次核对就推翻了一条「已确认无文档」的结论 —— **`editabletitlebar.ets` 存在，958 行，规格完整**：栏高 56、标题 20vp、副标题 14vp、主标题最多占 65% / 副标题 35%、头像 64vp、编辑弹窗 216–256vp、Symbol 24vp。「`EditableTitleBar` 确实无文档」只在**参考文档**范围内成立（三个 slug 变体全 404 是真的），但**把「文档没有」当成「没有规格」是错的** —— 这与 §0.2「闭源 ⇒ 无文档」是同一个错误模式，只是这次跨了一层。矩阵该行已改为「源码有，文档无」
- 文档：`SubHeader`（子标题）按源码真实数值重核，由 3 行扩到 7 行。`subheader.ets` 是唯一带 `RESOURCE_CACHE_MAP` 的文件（28 条令牌→真实值），据此拿到此前拿不到的尺寸：**高度三档 56 / 56 / 72**、标题 18、副标题 14（权重 400）、`titles_space` 2、左图标 16、图标文字间距 8、左右边距 16/16、内容 padding 8。现有 `OhosSubheader`（`ohos_text.dart:118`）**没有高度概念**，只有一个 `padding: (16,16,16,8)`、行高全靠字阶撑，与官方 56/72 对不上；且没有副标题行、没有左图标
- 修复（工具）：`tool/fetch_source.sh` 不猜文件名。目录名与文件名不一致且方式不统一 —— `chip/source/chip.ets` 同名，但 `gridobjectsortcomponent/source/GridObjectSortComponent.ets` 是全驼峰，试「首字母大写」仍 404。改为用 API 列目录取真实 `.ets` 名。**这是「猜名字」这个错误的第三次出现**（前两次：猜 slug 判文档有无、`Chip` 误当 `ChipGroup`），已写进 ROADMAP 头部
- 文档：新增 `doc/ROADMAP-0.6.md` 第七节「方法教训」，把三轮补查归结成三条（只读设计规范会读错形态数 / 基于类比推断"闭源=无文档" / 矩阵写"无文档"会污染下游判断），并把落法写进 `sources.json` 的 `missing` 字段约定：只允许记录**试过的 slug 与返回码**，不允许写「该组件无文档」这种结论式表述，把三轮补查归结成三条（只读设计规范会读错形态数 / 基于类比推断"闭源=无文档" / 矩阵写"无文档"会污染下游判断），并把落法写进 `sources.json` 的 `missing` 字段约定：只允许记录**试过的 slug 与返回码**，不允许写「该组件无文档」这种结论式表述
- 修复：`OhosActionBar` 不传 `primaryLabel` 时渲染出一个**空白药丸** —— legacy 布局无条件画 `OhosButton(child: Text(primaryLabel ?? ''))`，于是官方「去掉主按钮」这一形态（`primaryButton` 本就是可选参数）实际不可达，调用方拿到的是一个看着像加载失败的空按钮，比不画更糟。现在无标签时整块不渲染；`primaryLoading: true` 仍保留按钮，因为转圈是「正在做某事」的唯一反馈，这时候抽掉会让人以为请求丢了。补 3 条用例（无标签不画 / 有标签照画 / loading 无标签仍画），已验证回退后第一条会红
- 文档：新增 `doc/CONTROL-MATRIX.md` —— 按**官方形态**而非「控件个数」统计的覆盖矩阵，每行带「依据 / 本库实现 / 测试」三列。0.5 声称「42 控件全覆盖」是按控件名统计，按形态统计实际有大量缺口（如进度条缺 `Eclipse`/`ScaleRing`/`Capsule`，分段按钮缺 tab 型与多选，列表缺 `ListItemGroup` 的 CARD 分组与吸顶）
- 文档：新增 `doc/reference/api/`（ArkUI 参考文档本地快照）与 `tool/fetch_reference.sh`。中文站参考页是 SPA，静态抓取只得到 404（页面里 `<link rel="alternate" type="text/markdown">` 指的地址同样 404），因此改抓 OpenHarmony 仓库原文 —— 内容与官网同源且自带完整 ArkTS 示例。文档本体不入库（上游内容、2.9MB、会漂移），用脚本可复现；`README.md` 与 `sources.json` 入库，负责记录两条链路与缺口
- 文档：新增 `doc/ROADMAP-0.6.md` 规划。其中纠正了上一轮基于设计规范得出的三处错误结论：滑块**没有**双值区间（`slideRange` 是「有效滑动区间」）、进度条是 **5 种**而非 3 种、列表分组样式是官方枚举 `NONE`/`CARD` 而非自拟视觉
- 新增：`example/test/ink_no_color_test.dart` —— **墨水屏下「不应出现彩色」的回归测试**（8 个示例页 × 全树扫 `DecoratedBox`）。这条测试补的是一个此前无人守的洞：README 的墨水屏图集靠真机截图，而截图的失败方式是**看起来像主题没切**。实际主题切对了（`switch_theme()` 会用平均饱和度探针确认），彩色来自**示例自绘的占位内容** —— 沉浸光感的渐变壁纸、轮播的四色页、动效曲线的填充条、点光源的深底、按压阴影的灰块。这些既不是组件令牌也不是状态表达，`policy` 管不到，所以**库层测试全绿也拦不住**
- 新增：`example/lib/ink_color_data.dart` 的 `InkColorData` —— 给「**颜色本身就是数据**」的子树做显式申报（取色带、取色泡泡里的色点）。判据因此是「默认必须灰，数据要显式申报」，而不是给颜色猜一个宽容度
- 文档：**判据迭代过两版，第一版被变异验证否掉了**。初版按「单块面积占比」放行小色块（理由：12 格色板每块只占 0.34% 屏），但曲线条是四条 `358×10`、每块只占 1% 屏，叠起来却是一整片彩带 —— **撤销修复后测试依然全绿**。逐块面积是**渲染后**的属性，而缺陷出在**源码**里；判据必须落在能改的地方。改用祖先链标记后，三处真实缺陷逐一做过变异验证（撤销 → 三条测试分别变红，报出 `rgb(10,89,247)` 与坐标）
- 修复：示例「布局与动效」页的动效曲线填充条写死 `0xFF0A59F7`，墨屏上是一条彩色带。原注释写着「55% 品牌蓝压到灰阶上是中灰，留着反而与彩屏对照最直观」—— 那句话对 16 级灰的**真机**成立，对**截图**不成立：截图里就是蓝的，放进墨水屏图集等于自证主题没生效。改走 `theme.policy.quantize(...)`
- 修复：示例「导航类」页的轮播占位页写死四色（蓝/绿/黄/粉），墨屏下一页里出现四条彩色带。改走 `policy.quantize` 的同时**把字色判断从「查写死的表」改成「算量化结果的亮度」** —— 「黄色配黑字」这条规则量化后不再成立，量化到哪一档灰由纸面决定
- 修复：示例「UI Design Kit」页的点光源深底 `0xFF101418` 与按压阴影示范块 `0xFF8A8A8E` 未跟主题退化，墨屏下带蓝相。两者都是**示例自绘的演示面**（点光源需要暗底才看得见白点），不是品牌色也不是数据，改走 `policy.quantize`
- 文档：**构建链有一个会指向错误位置的环境坑**。`hvigor` 的 `ohpm install` 与 `SignHap` 都要删除中间产物，撞上执行环境的批量删除保护后，报错分别写成 `ohpm install failed`（附「检查网络/仓库地址」）与 `Error Code: 00308018 Unknown Error` —— **两处都完全指不到真正的失败原因**，读起来像依赖问题或签名配置问题，而实际是 `safe-delete: count == threshold`。构建时去掉注入的 `NODE_OPTIONS` 即可通过；此坑此前也被误判过两次（一度以为是 `ohpm` 仓库配置、一度以为是证书不可猜）
- 文档：全量截图重拍完成（`tool/capture_theme.sh light` / `ink`，8 分类 × 5 屏 = 40 张/套，共 80 张）。重拍前先修完上面三处示例彩色，避免「采完再发现」的返工
- 修复：**`OhosAlertDialog` 的标题与正文在真机上带两条黄线**。弹窗由 `showDialog` 挂在 Navigator 的 Overlay 上，**没有 `Material` 祖先**，文字因此退到 `DefaultTextStyle.fallback` —— 那个常量是 `#FFFF00` + `TextDecorationStyle.double`，专门用来在视觉上标记「这段文字没有任何样式来源」。实测墨屏截图有 5340 个 `#FDFE53` 级黄像素（标题宽 135px、正文宽 262px 各一条）。修法是在弹窗内部补一层 `DefaultTextStyle`（给中性值 `TextDecoration.none` + `textPrimaryColor`），而不是逐处给 `Text` 传 `style`。**按钮文字当时是正常的**，因为 `_OhosDialogActionButton` 自己包了 `Material` —— 只截按钮会漏判，用例对标题与正文分别断言
- 修复：`OhosButton` 的 `TextButton` 变体 `decorationColor: underline ? foreground : null`，非下划线分支给 `null` 等于**把祖先的 `decorationColor` 放行下来**。`DefaultTextStyle.merge` 只覆盖非 null 字段，`null` 不是「清空」而是「不表态」。真机（墨屏容器页弹窗）表现为标题下方一条黄线，flutter_test 的默认 `DefaultTextStyle` 恰好带 `decorationColor = #FFFF00`（测试框架给「不该有下划线却有了」留的警报色），而 M3 真机该字段是正文色，所以**只有墨屏 + 特定祖先链才显形**。改为两个分支都给值（`Colors.transparent`）
- 文档：**这两条是同一个坑的两次发作**，且都属于「静态分析看不见、单元测试不报错、只在特定祖先链的真机上显形」。原有的 `test/text_button_affordance_test.dart` 用 `isNot(const Color(0xFFFF0000))` 断言，`null` 也能通过 —— 已改成强断言 `Colors.transparent`，并做变异验证（撤销修复后变红）。`ohos_popup.dart` 的注释里早就记过同一个坑（Toast 走 `inherit: false` 绕开），但当时只修了那一条路径，**没有回头查「还有谁挂在 Overlay 上」**
- 文档：排查过全部 Overlay / 独立路由入口，其余不受影响：`showMenu`（`ohos_menu.dart`）与 `showModalBottomSheet`（`ohos_bottom_sheet.dart` / `ohos_picker.dart`）内部都自带 `Material` 祖先；`OhosToast` / `OhosPopup` 早已显式给中性值；`OhosMagnifier` 则用 `inherit: false` 断链。**只有 `showDialog` 这一条路会中招**
- 文档：`tool/capture_theme.sh` 修了两处**导致重采失败**的缺陷。① `switch_theme` 的词表不匹配：调用方传 `ink`（与 `mode`、目录名、README 一致），探针只输出 `gray` / `light` / `dark`，两者永远 `!=`，脚本因此永远判「切不过去」并把主题转走（转一圈后停在第 4 态）——加 `[ "$want" = "ink" ] && target=gray` 映射；失败时改为**直接退出**，不再产出错标主题的图。② 增加分类过滤与按分类定屏数：`./tool/capture_theme.sh <light|ink> 导航类`，导航类与 `UI Design Kit` 各采 11 屏（其余 5 屏）—— 这两个页面区块数超过 5，原先 `kit_09` / `kit_10` 都拍成了同一个常驻通知
- 文档：**主题按钮是 3 态循环**（light → dark → gray → light），不是 4 态；「深色墨水屏」只能在长按菜单里选。这条是脚本连采失败后手动点 5 次实测出来的，此前按「四态」写的循环次数永远差一
- 文档：截图归档按 README 的 45 个手选文件名逐一核对，**按帧号推测映射会错位**（`capsule` 拍的是 ChipGroup、`bottom` 拍的是下划线子页签），须逐帧裁上部拼图核对后才敢改名。交互态（弹层 / 放大镜 / 菜单 / 转场）无法由脚本采到，改用 `hdc uitest` 现场操作：`uinput -M` 的「按下 / 移动 / 抬起」可分离，能在**按住状态**截到放大镜与索引条泡泡；`uitest uiInput drag` 则用「后台起拖 + 定时截图」卡住拖拽中间帧（色带放大镜、共享元素转场都靠这个）

## 按审计清单对齐（P0–P3）

> 依据 `doc/AUDIT-0.6.md`（42 控件逐条对照设计规范 / 参考文档 / 资源表 / 源码）。
> 每项都做了**变异验证**：把改动还原成老实现后对应断言必须变红。

### P0 功能缺失

- 修复：`OhosRatingBar` 的 `value` 由 `int` 改为 **`double`** —— 官方 `stepSize` 默认 **0.5**，`int` 根本表达不出半星。新增 `stepSize` / `indicator` / `activeIcon` / `inactiveIcon` / `starSize`，并把 `OhosRatingMetrics`（`starCount 5` / `starSize 28` / `indicatorStarSize 12`，均出自 `float.json` 的 `ohos_id_rating_*`）单独成表。半星用 `ClipRect + Align(widthFactor: fill)` 裁切**已选中图形**而不是 `ClipPath` —— 换图标不用改代码。点击落点决定分值（`ceil(fraction / step)`）。同时删掉自加的「再点一次清零」语义，官方没有这一条
- 修复：`OhosCounter` 的 `enabled` 拆成 **`enableInc` / `enableDec` 两个独立开关**（null 时跟随 `enabled`）+ 独立的 `onInc` / `onDec`。「库存为 0 时只能减不能加」这类场景原先无法表达
- 修复：`OhosScrollbar` 条宽 8 → **4**、`minThumbLength 48`、`timeToFade 2s`、距边 4（`padding` 而非 `crossAxisMargin`，后者会把轨道撑宽）。**官方要求的 32vp 热区做不到**：`RawScrollbar` 把 `_kMinInteractiveSize = 48.0` 写死，命中带恒为拇指中心 ± 24，条宽 4 + 距边 4 实际只有 30vp；也没有 `onThumbPress` 一类回调，「激活加粗到 8vp」无法实现。这两处以 `OhosScrollbarMetrics.touchWidth` / `activeWidthUnsupported` 常量留痕，不假装对齐
- 修复：`OhosBadge` 补 `OhosBadgePosition` 3 档（`rightTop` / `right` / `left`）、`OhosBadgeMetrics`（`size 16` / `fontSize 10` / `dotSize 6` / `maxCount 99`）、字符串形态 `value`（空串退化为圆点）。`numerical_badge_padding = 6` 按**总额**而非每侧取，才能保住一位数徽标仍是 16vp 的圆。`badgeSize < fontSize` 时按 `fontSize` 生效（官方口径）
- 修复：`OhosAlphabetIndexer` 补 4 个颜色属性 + `OhosIndexerAlign` 4 档 + `itemSize` + 弹窗气泡。**默认色最终取主题来源而不是官方固定值**（`0x99182431` / `0xFF007DFF`）：写死会绕开 `policy.quantize`，墨水屏上无法退化成灰阶，且 `ink_no_color_test` 必红。要严格对齐官方外观可显式传 `OhosIndexerMetrics.textColor` / `.selectedColor`

### P1 数值不符

- 修复：`OhosToast` 最大宽 320 → **400**（并按「屏宽 − 两侧 16」夹取）、圆角 18、距底 80、位置默认 `bottom`。**padding 取 16/8 而不是审计写的 10vp** —— 10 出自设计规范的**智能穿戴**段落，手机侧真值是资源表 `toast_padding_horizontal_api_twelve = 16vp` / `toast_padding_vertical_api_twelve = 8vp`
- 修复（**形态级**）：`OhosPopup` 从「无箭头浮层」重写为**指向型气泡** —— 圆角 20、箭头 16×8、`targetSpace 8`、最大宽 400（并夹屏宽）、`OhosPopupPlacement.bottom` / `.top` 两档、放不下自动翻边。`_OhosPopupLayout` 是 `SingleChildLayoutDelegate`，居中 + 夹边 + 翻边；箭头 x 与 `getPositionForChild` 用**同一条公式**（注释标明「改一处必须改另一处」）
- 修复：`OhosMenu` 补 **224vp 固定宽**（手机），电脑 224 可配、下限 64。圆角 16 → **20**（`menu_default_radius_token` / `ohos_id_corner_radius_menu`）
- 修复：`OhosButton` / `OhosSegmentedButton` 补 **448vp 最大宽度**。⚠ **它是上限，不是必然值**：`SizedBox(width: 700)` 给的是紧约束，`ConstrainedBox.maxWidth` 与 `Align(widthFactor:)` 都会被 `constraints.constrain()` 夹回 700 —— 实测两种写法渲染都是 700。**没有任何 Widget 能在紧约束下变窄**，所以断言改用松约束父级（`Align`）。这条一度把「实现没修好」和「测试写错了」混在一起，改了三轮才分开
- 修复：`OhosDivider` 厚度从固定 `0.5vp` 改为 **`1px` 物理像素**（`1 / devicePixelRatio`）—— `0.5vp` 在三档密度下给出三种不同粗细的线，而官方规格是「1px」，物理像素与逻辑像素不是一回事。另补 `vertical`（官方默认 `false`）与 `#33182431` 默认色

### P2 可配置性

- 新增：`OhosSwitchStyle{pointRadius, unselectedColor, pointColor, trackBorderRadius}` + `OhosSwitch.pointColor`（官方 `switchPointColor`）。**`pointRadius` 的默认值跟着高度算**（官方 `h/2 - 2*h/20`：30 高 → 12、44 高 → 17.6），老实现是「高度减 4」，两种口径在 30 高差 1vp、44 高差 2.4vp。`trackBorderRadius` 超 `h/2` 夹到 `h/2`（官方原话）。官方明写 `switchStyle` **仅当 `type` 为 `Switch` 生效**，所以 `OhosToggleButton` 不加 —— 审计把两者合成一项是对官方语义的宽松读法
- 新增：`OhosCheckboxShape{circle, roundedSquare}`（**默认改成官方 `CheckBoxShape.CIRCLE`**，0.5 默认是圆角方形）+ `OhosCheckboxMarkStyle{strokeColor, strokeWidth: 2, size: 20}` + `unselectedColor`。勾从 `Icons.check_rounded` 换成手画 `CustomPaint`：字体图标的线宽是字形画死的，官方 `mark.strokeWidth` 落不了地。`OhosCheckboxGroup` / `OhosCheckboxGroupHeader` 的 `round` 默认同步改为 `true`，否则同一列表里会出现「圆形成员 + 方形组头」
- 新增：`OhosSelect` 的 `selectedOptionBgColor` / `selectedOptionFontColor` / `optionBgColor` / `optionFontColor` / `showDefaultSelectedIcon` / `OhosSelectMenuAlign`（3 档）/ `OhosSelectArrowPosition`（2 档）/ `optionWidth` / `optionHeight` / `showDivider` / `dividerColor`，并补 `OhosSelectMetrics`（`space 8` / `popupRadius 16` / `popupMinWidth 136` / `optionMinHeight 48`，均出自资源表）。**`showDefaultSelectedIcon` 默认改为 `false`** —— 官方口径是「选中靠突出底色，不是靠勾」，老实现总是画勾，与这一条相反。`center` / `end` 两种对齐是**近似**：`showMenu` 定位先于布局，拿不到菜单实际宽度
- 新增：`OhosChip` 的 `suffixSelectedIcon`（后缀双态）、`backgroundColor` / `activatedBackgroundColor` / `labelColor` / `activatedLabelColor` / `labelFontSize` / `labelFontFamily`，以及**字重双态 400 / 500**（`chip_text_font_weight` / `chip_activated_text_font_weight`）。**文字色与图标色拆成两条**：官方 `LabelOptions.fontColor` 默认 `ohos_id_color_text_primary`，而 `prefixIcon.fillColor` 默认 `chip_usually_icon_color`（≈ secondary），老实现绑在同一个 `fg` 上，文字常态偏淡一档
- 修复：`OhosToast` / `OhosAlphabetIndexer` 里读 `policy.isMonochrome` 的两处回归 —— 组件层按主题档位分支是被 `system_theme_test` 明令禁止的（加一块屏就得回来改 52 个文件）。改成问策略「这个颜色能否在你那块屏上原样表达」：`policy.quantize(c) == c`（彩屏原样返回、灰阶必然不等）。`tint` 不能用于这种探测，它的阈值是 ≤20%，而 toast 遮罩是 90%，两边都返回非透明

### P3 结构缺口

- 新增（**形态级**）：`OhosList.scrollable` —— 上一版 `OhosList` 只有 4 个参数（`children`/`header`/`headerPadding`/`divider`）、是一个**不滚动的卡片容器**，而官方 `List` 是滚动容器、53 个属性。补上 `CustomScrollView` 形态：固定高度、`OhosListLanes`（`OhosFixedLanes` 列数 / `OhosLanesByWidth` 最小列宽 + `gutter`）、`OhosListDivider` 对象形态（`strokeWidth`/`color`/`startMargin`/`endMargin`）、`sticky` 广播到每个分组、`onReachStart`/`onReachEnd`/`onScrollIndex`。**静态形态原样保留** —— 直接改成滚动容器会让所有既有布局凭空多出一个视口高度
- 新增：`OhosImage` 的 `OhosImageFit`（8 档官方 `ImageFit` 语义）、`errorPlaceholder`（官方 `ImageAlt` 22+ 的第二张图）、`onError`（`OhosImageError`）、`onComplete`（`OhosImageLoadInfo` **9 字段**，`loadingStatus` 0 与 1 各回调一次）、`placeholder` 与图片**共用同一个 `fit`**（官方「占位图支持使用 objectFit 设置填充效果，与图片的填充效果一致」）。**`ImageFit` 不能拿 `BoxFit` 顶替**：新增 `original` 档（原尺寸且不裁）在 `BoxFit` 里没有对应值
- 新增：`OhosTextClockController`（`start()` / `stop()`，官方默认 `started = true`）、`timeZoneOffset`（**官方符号：东八区传 -8**，范围 `[-14, 12]`，十个半小时档不取整）、`onDateChange`（Unix **秒**）、`OhosClockHourFormat`（官方 `dateTimeOptions` 两个取值）、官方 `format` 全部十个字母，以及「组件不可见时停走」（`TickerMode`）。**旧参数 `String? timeZone` 是空操作**（实现只做 `toUtc().toLocal()` 恒等变换，传 `America/New_York` 与不传结果完全相同），已替换
- 文档：`OhosActionBar` 的 `margin`（官方 6.1.0(23)）**已经在本版里**，语义与官方「上下边距」一致 —— 审计 §5 那一条是过期待办
- 文档：`CONTROL-MATRIX.md` 按 P3 的实现回填 —— **文本时钟 1 行拆成 10 行、图片 1 行拆成 13 行、列表 17 行加到 23 行**，统计重算为 **283 行 / 完整 222 / `◐` 4 / `○` 52 / `●` 2 / `—` 3**（`222+4+52+2+3 = 283` ✓，命令连跑两次一致）。两处旧写法是「一个控件一行、官方形态列写 `—`」，读不出任何可核对的信息 —— 矩阵要么逐形态登记，要么等于没登记

### 实施中才暴露的四件事

1. **紧约束下的「最大宽度」不存在**（见 `OhosButton` 那条）—— 比修复本身更值得记住的一条。
2. **`SwitchStyle.pointRadius` 的默认值是算法不是常数**，且 30 高给 **12**（我自己一度算成 13）。老实现 `h - 4` 在 30 高给**半径 13 / 直径 26**，与官方的**半径 12 / 直径 24** 只差 1vp，肉眼几乎看不出 —— 测试必须挑 44 高才把两条公式分开。
3. **官方文档本身有口径差**：审计写的 Toast「10vp」出自智能穿戴段落。遇到两处不一致时先问「哪个是编译产物的一手来源」，别按文档等级排优先级。
4. **链式 `replaceAll` 做模板格式化是错的**：`yyyy年M月d日 EEEE` 会把 `EEEE → Sat` 里的 `a`、`S` 再吃一遍，实测吐出 `2026年11月7日 51下午t`；`aa hh:mm:ss` 被拆成「下午下午」。模板串必须**一次扫描、逐字符吐结果**。附带两条环境事实：`SliverGrid` 的 `childAspectRatio` 会把行高钉死（360 屏两列时每格 44.8 高、tile 要 53 → 溢出矩阵报 `overflowed by 13 pixels`，改用 `SliverCrossAxisGroup`）；`Localizations.localeOf` 在 `flutter_test` 里恒给 `en_US`（`locale: Locale('zh')` 也会被回落到英文）

## 配图数值核查后修正的三处

> 背景：84 条手机形态配图数值逐条对过「配图 / 正文 / 令牌 / 实现」四层（明细见
> [`doc/AUDIT-IMAGE-SPECS.md`](doc/AUDIT-IMAGE-SPECS.md)）。45 条是「令牌表根本没这一项」——
> 这类写带出处的常量是对的，不用改。真正要动代码的三条如下。

- 修复：**半模态 `LARGE` 挡 / `BOTTOM` 显式高度没有给状态栏让位**。官方公式是
  「屏幕/窗口高度 − 信号栏 − 8vp」（`bindsheet` 正文三处 + `bindsheet_16`/`button_39`/
  `segmentbutton_10` 三张图），旧实现 `OhosSheetSize.large => viewportHeight` 直接顶到窗口顶，
  面板把状态栏盖在下面。新增 `OhosSheetSpec.topGap`（8vp，令牌表无此项）与
  `maxPanelHeight(...)`（`SIDE`/`CONTENT_COVER` 恒全屏**不减**，其余三型减「状态栏 + 8」），
  `LARGE`、`BOTTOM` 的显式高度、`CENTER`/`POPUP` 的 90% 上限统一走它（两条上限取小）。
  **状态栏高度必须用 `View.of(context).padding.top`**：调用点常在 `OhosScaffold` 的 `SafeArea` 内，
  `MediaQuery.paddingOf` 在那里恒为 0，用它等于白改（这条是修的时候才发现的）
- 修复：**菜单内容左右内边距实际是 12vp，不是设计稿的 16vp**。此前没声明、吃的是框架
  `PopupMenuItem` 默认值（实测 12，与直觉里的 16 差 4）。新增 `OhosMenuMetrics.contentPaddingHorizontal = 16`
  显式钉住。改完立刻暴露第二个问题：长文案 `RenderFlex overflowed by 4.3 pixels`
  （可用宽 224 − 32 = 192，文案要 196.3）—— 固定 224vp 宽的菜单本来就必须截断，
  条目文案改为 `Expanded` + `maxLines: 1` + 省略号。这两件事是同一个原因的两面：
  **靠框架默认值兜着的规格，一旦写实就会露馅**
- 文档：悬浮页签栏的 `76/80` 与设计稿的 `80/88` 是**两套都在官方材料里**的值（每页签恒差 4vp，
  四张图能被 80/88 精确复现）。组件默认仍取参考文档的 76/80（编译产物的一手来源），
  但把这层关系写进了 `ohos_tabs_width.dart` 的注释 —— 否则下一个人照配图改会把默认宽度整体放大约 5%
- 文档：矩阵补回一行「半模态高度挡位 LARGE / MEDIUM」—— 这是**缺行**，不是实现问题：
  8vp 公式此前只活在代码注释里，矩阵没有对应行，于是漏实现也没人发现。统计重算为
  **284 行 / 完整 223 / `◐` 4 / `○` 52 / `●` 2 / `—` 3**（`223+4+52+2+3 = 284` ✓，命令连跑两次一致）
- 修复：`README.md` 顶部引用的矩阵数字停在 **256 行 / 完整 204**（P3 回填时只改了矩阵、没改 README）。
  `tool/check_readme_matrix.py` 当场报红，已改成 284 / 223 —— 这个脚本存在的理由正是「两份文件是
  同一事实的两个副本，矩阵改了 README 没跟上不会让任何测试变红」
- 明确不做两条（理由写进 `doc/AUDIT-IMAGE-SPECS.md`，不是「待办」）：列表行高五档是**内容自然高的五种结果**
  而非五个可选高度，加 `height` preset 会与「按内容撑」的官方语义相反；超长文本 16vp 渐隐依附
  **滚动文本**才成立，本库没有滚动文本组件
- 用例：739 → **745**（半模态 5 条 + 菜单 1 条）；`example` 183 条不变

### 这一轮踩到的两件事

1. **断言里引用被改的常量，等于没断言**。P1 第一版写成
   `expect(resolveDetent(...), 800 - OhosSheetSpec.topGap)`，把 `topGap` 改成 `0` 做变异验证，
   用例**全绿** —— 断言跟着常量一起变了。改成字面值并与 `expect(topGap, 8)` 拆开后，
   同一次变异 5 条全红。凡是 `expect(f(x), g(CONST))` 且 `g` 里含 `CONST`，都要先问
   「把 `CONST` 改坏，这条会红吗」。
2. **「值相同」不等于「同一个令牌」在实现侧也成立**。`divider_padding_horizontal = 16vp`
   数值与设计稿的菜单内边距一样，但语义是分割线的内边距；用它当出处，会让实现看起来
   「有令牌支撑」，实际 16 从来没在菜单里生效过（真正生效的是框架的 12）。

## 上游资料知识库（`doc/reference/`）

> 这一节不涉及 API，只改「规格从哪来、怎么刷新」。但它是上面 P0–P3 全部结论的基础 ——
> 每一条数值都要能指回一个上游文件。

- 重构：四层上游资料合并到 `doc/reference/` 的四个子目录 —— `design/`（42 份设计规范 + 608 张配图）、
  `api/`（56 份开发参考文档）、`source/`（29 份 `.ets`）、`resources/`（3 份令牌表）。
  原先是 `doc/reference/` + `doc/source/` + `.tmp/ux/` 三处，**配图放在 `.tmp/` 里**
  —— 这个名字本身就在说「可删」，而它实际是 180MB、要十几分钟重抓、且是「配图是唯一写数值处」这条结论的唯一依据。
- 新增：`tool/upstream.sh` 作为唯一入口（`all` / `api` / `source` / `resources` / `ux` / `index` /
  `manifest` / `verify` / `status`）。此前五个 `fetch_*` 脚本各自为政，没有任何东西记录
  「上次什么时候抓的、抓全了没有」—— 少一份文档和根本没抓过，在 `ls` 里长得一样。
- 新增：`doc/reference/manifest.json`（入库）记录每层的路径、上游地址、条数、字节数、最新文件时间；
  `upstream.sh verify` 重算后比对，不一致非零退出。**只比数量与字节数，不比 mtime**
  （本地 checkout 会改 mtime；字节数变了才是上游真的动过）。
- 新增：用户级 skill `upstream-sync`（`~/.workbuddy/skills/`），把「先判快照新不新 → 只刷新变化的那层 →
  重跑派生索引」固化成流程；详细规则仍以仓库内 `doc/reference/README.md` 为准，避免两处各说一套。
- 文档：三份 README 收敛为一份总说明（`doc/reference/README.md`），讲清四层各回答什么问题、四条抓取链路、
  已知缺口、配图再处理流程；`doc/reference/source/README.md` 保留（源码层与令牌层的判据细节只在那里）。
- 修复：顺手纠正三处**过期数字**，都是「写死之后上游变了自己不知道」——
  开发文档 `55 → 56` 份（漏数一份）、官方示例 `402 → 442`（前两次都是手抄漏项，这次是上游真的新增）、
  `UX-SPEC-FROM-IMAGES.md` 的「非候选 548 / 大尺寸无标注色 213」`→ 495 / 194`（标注判据从 `b>190`
  改成色相窗口后候选从 60 涨到 113，文档却还写着旧值）。后一处已改成**从 `ux-images.scan.json` 现算**。
- 文档：`doc/source/` 目录删除，全仓 50 个文件里的路径引用机械改写（含 `lib/` 中 4 处「规格出处」注释），
  改完 grep 旧路径残留为 0。

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
