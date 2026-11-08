# CHANGELOG

## Unreleased

> 对应 `pubspec.yaml` 0.6.0 → **0.6.1**（2026-11-08）：墨水屏 / 深色主题整改轮，AtomGit !13–!20。无破坏性变更；`OhosVisualPolicy.statusMotion` 是带默认实现的普通方法，自定义策略子类不受影响。用例 750 → 776。

### Features

- `OhosVisualPolicy.statusMotion(Duration)`：把「承载状态的动效」（进度游标、加载指示）从 `scaleMotion` 里拆出来。分界不是动画长短，而是**归零之后还剩什么信息** —— 装饰性过渡归零只是少一段动画，游标归零则与「进度卡死」同形。默认转发 `scaleMotion`，彩屏与既有自定义策略行为不变；`InkVisualPolicy` 覆写成原样返回，只放行这一类。代价是墨水屏上持续的局部逐帧刷新，更慢的屏可能有残影，自定义策略覆写成 `Duration.zero` 即可退回静态符号（!15）
- `lib/src/theme/ohos_contrast.dart`：`ohosContrastRatio` / `ohosOnFillReadable` / `ohosReadableContrast`。半透明底先 `Color.alphaBlend` 合成到实际背景再算 WCAG 对比度 —— `computeLuminance()` 不看 alpha，不合成会把 15% 黑算成纯黑（!13 / !14 / !17 共用）

### Bugfix（墨屏 / 深色主题对比度整改）

- 修复「反白前景写死白色 / 官方深色」这一类复发：深色墨屏的 `highlightColor` 就是纸白、白纸墨屏的是纯黑，白底白字 / 黑底黑字会让整块内容消失。统一改成按**合成后的实际底色**判对比度，反白色一律取 `theme.onHighlightColor`（!13 / !14 / !17 / !19，Issue #7 / #8 / #11）
- 修复 `OhosProgressIndicator.capsule` 墨屏 1.3:1 的数字整段消失：叠两层字（轨道官方色 + 填充反白色），用与填充同源的 `ClipPath` 裁开，跨边界的两半字形都完整；第二层排除语义、`fill <= 0` 不叠层（!14）
- 修复 `OhosAlphabetIndexer` 墨屏选中字母黑底黑字：实底改配 `onHighlightColor`，选中底改为等径正圆（`dot = min(slot, 条宽)`）（!13）
- 修复 `OhosChip` 墨屏选中「透明底 + 反白字」：改走 `selectionMark.inverse` 实底反白；底色透明时字色退回正文色。彩屏仍是浅底 + 品牌色（!17）
- 修复 `OhosBadge` / 页签角标白纸墨屏与黑色图标连成一片、深色墨屏白底白字：墨屏加 1vp 纸色描边，数字色按底色亮度取黑白，两处实现共用 `ohosBadgeHalo` / `ohosBadgeForeground`；墨屏选中药丸退到背景层内缩 4vp，内容区仍占满 56vp，`textScale 1.5` 不再溢出（!16，Issue #10）
- 修复 `OhosButton` 的 `filled` 字色与 loading 转圈写死白：改取 `theme.onHighlightColor`（转圈 0.7 alpha），彩屏外观不变（!19）
- 修复 `OhosNavigationBar` 悬浮分支漏传 `borderRadius`：材质内部各层按直角算、只靠外层 clip 硬裁；顶部亮线改为按圆角内缩、渐变按实际线段取（!18）
- 示例：底部页签演示底板补 `clipBehavior: Clip.antiAlias`；工具栏演示卡片换成上直角 / 下圆角，四种主题轮廓一致（!18 / !20）
- 遗留：`ohos_checkbox_group.dart:233` 的对勾仍写死 `Colors.white`，深色墨屏有同款风险，建议单开 issue

### Bugfix

- 破坏性变更（源码兼容）：`OhosListTile.divider` 由 `bool`（默认 `true`）改为 `bool?`（默认 `null`）。`null` 表示跟随所在的 `OhosList` —— 列表接管分隔线，行边界恰好一条、末行不画；显式传 `true` / `false` 的行为与以前一致（原来 `false` 会被列表的 scope 静默忽略）。改类型是为了修掉「列表内每行各画一条、行边界变成双线」，同时保留逐行关掉分隔线的能力
- 修复墨水屏（`OhosThemeData.ink()`）下「靠浅色填充表达状态」的控件整块消失：16 级灰阶里 20% 以内的黑落在第 0–3 级，禁用按钮的 20% 底 + 白字因此变成一片空白。现在禁用态改为透明底 + 实色描边，并波及同一类问题：勾选框 / 单选框未选中描边、开关关闭态轨道与滑块、分段按钮轨道与选中段、进度条与滑动条未走轨道、纸片与状态按钮的描边、输入框下划线 —— 一律从 15%~50% 半透明改成「留白 + 1px 实线」，禁用降一档到 `#767676`
- 修复 `filled` 按钮在 `loading` 时被当成禁用态：底色退成浅色而转圈颜色写死 `Colors.white70`，真机上只剩一个空白药丸。现在 `loading` 只关掉点击，配色仍走主按钮（实底 + 白转圈），禁用与加载两个状态在视觉上分开
- 修复墨水屏下「默认白底」的容器与页面糊成一片：`OhosCard`（未显式传 `color` 时）、`OhosSearchBar` 胶囊、底部面板补 1px 黑描边；`OhosCard` 在墨水屏下也不再画看不见的阴影
- 修复 `OhosCard` 的描边在 `padding: EdgeInsets.zero` 时被内容吃掉：子节点自带整块底色（`OhosActionBar` 最典型）时，它的抗锯齿边缘会把相邻 1px 边洗掉 —— 直边尚存、圆角弧段整段消失，看起来像「矩形框和圆角框重叠」。描边改画在子节点之上（`foregroundDecoration`），并把子节点裁进圆角
- 修复白底浮层仍要靠阴影分层的问题：`showOhosSnackBar` 对浅底一律补一条 hairline（墨屏纯黑、彩屏用主题分隔色），不再只依赖 `elevation`；`OhosSelect` 的下拉面板与 `showOhosPicker` 的面板补墨屏描边（前者原来根本没有 `side`），`showOhosMenu` 的 0.5px 线在墨屏上按 1px 算，`OhosSideBar` 的 overlay 面板同样补线
- 修复 `OhosColorPicker` 的色块只在选中时才有框：未选中的白 / 浅色块压在白底上等于消失（墨屏上 `multiInk` 压成灰阶后更明显，浅黄、浅蓝也会化进背景）。改为按亮度判断（`computeLuminance() > 0.7`）给未选中的浅色块补一圈描边 —— 墨屏纯黑、彩屏 26% 黑，深色块不描；选中仍是原来的粗框。选中态的对勾同样按亮度取色（深色白勾、浅色用前景色），否则白勾画在白块上等于没画。这条判定抽成 `ohosSwatchOutline`（`lib/src/theme/ohos_stroke.dart`），示例里"选中的颜色"预览块直接复用，调色板同时补了白 / 浅灰两档，方便在真机上对照
- 修复滑动条的滑块在墨水屏上等于没有：它是白圆 + 零阴影，而 `RoundSliderThumbShape` 只有 `elevation` 可调、没有描边能力。新增自绘的 `OhosSliderThumbShape`（白圆 + 完全落在圆内的 1 设备像素描边，彩屏仍靠阴影）；`enabled: false` 时滑块按 `enableAnimation` 收敛成灰色实心 —— 白圆黑环在禁用态读起来仍然「可拖」，实心灰更直观；禁用轨道同时降一档到 `OhosColors.inkDisabled`。墨屏点按后的半透明灰块也不再画
- 修复滑动条的气泡在墨水屏上是两个叠在一起：`showValueBubble` 自绘的那个已补 1px 实线，Material 还会另画一个 value indicator（有 `divisions` + `label` 时默认 `onlyForDiscrete`），它白底、无描边，贴在白页面上整个消失。现在关掉原生 indicator，只留自绘气泡（松手即收起）
- 统一描边入口：新增 `ohosStrokeWidth` / `ohosBorderSide`，宽度取整到整数设备像素（DPR 2 / 3 仍算 1vp，1.5 / 2.625 这类非整数 DPR 上不再把一条线摊成两三行灰），并显式钉住 `strokeAlignInside` —— 描边画到盒外会被祖先 clip 吃掉半条，四条边就不再同宽。`OhosCard`、`OhosSearchBar`、弹窗、底部面板、菜单、下拉、浮条、侧栏、纸片、状态按钮、按钮、勾选框、开关、分段按钮、滑块气泡与弹层统一走这一个入口
- 示例：展示类墨主题章节补齐禁用 / 加载按钮、勾选与单选、开关关闭态、分段按钮、进度条、纸片、角标、滑动条与输入框，可直接在真机上对照
- 示例：`OhosTheme` 从 `home:` 内层移到 `MaterialApp` 外层 —— push 出去的页面是 Navigator 的兄弟节点，原来拿不到主题、会静默退回默认浅色（整体验证墨主题时容易误判为「ink 没生效」）
- 修复 `OhosColorPicker` 光谱模式的两个问题，并把墨屏下的一整套观感收口：

  - **指示器与手指纵向反向**：`Alignment.y` 的 `-1` 是上边，而 `value = 1`（最亮）也在上边，原来的 `Alignment(sat*2-1, value*2-1)` 把两者对调了 —— 往顶部点（变亮）指示器反而沉到底部。改成 `1 - value*2`；顺带把盒高从两处各写一个 `96` 收成 `_svHeight`，`_svAt` 改为接收 `Size`，坐标换算不再依赖魔数。
  - **滑块轨道被拇指切断**：拇指原先是 18×18 的白块、与轨道等高，滑到渐变浅色端时白块 + 25% 黑细边几乎看不见，读起来就是「浅色轨道断裂成一块白色空白」。改成比轨道高的白圆（24 vs 18）：圆心内缩一个半径，滑到两端也不会被父级裁掉半边；白圆外围一圈发丝线（墨屏纯黑、彩屏 25% 黑），彩屏保留投影、墨屏不画。
  - **墨主题协调**：光谱盒与三条轨道各补一条发丝线（墨屏纯黑、彩屏 8% 黑）—— 渐变两端接近白色，不补线时在灰阶上直接化进白底；光谱指示器在白环外套一圈深色发丝线（浅色区域靠它、深色区域靠白环）；未选中的模式片从「6% 黑底」改成「透明 + 1px 实线」，收藏星点亮色从品牌黄 `#F7CE00` 改成纯黑。
  - 配套 `test/ohos_ui_test.dart` 新增 `OhosColorPicker` 组 2 条：点光谱盒上沿后指示器必须跑到上半部且取到的色值 > 0.9（反向时会失败）、滑块拇指是圆且高于轨道。示例 `UI Design Kit` 的取色器三个模式已在 NoteAir 上逐项对照。
- 修复 `OhosBadge` 计数徽标被父级行高拉成「竖胶囊」：标签容器写的是 `Container(alignment: Alignment.center, ...)`，展开后是一个 `Align` —— 在「宽度无界、高度有界」的约束下（Row 的非弹性子节点正是这种情况）它只在高度方向撑满，宽度依旧跟着内容收缩。侧边菜单 48vp 的行里，`badgeCount: 8` 因此被画成 18×46 的黑色竖条，而 `OhosBadge` 自己的演示页面四周都是松约束、两个方向都收缩，所以一直没暴露。改用 `Center(widthFactor: 1, heightFactor: 1)`，让标签在宽高两个方向都只包住内容：一两位数字是 18vp 的圆（半径 9），多位数字横向长成胶囊。配套 `test/ohos_ui_test.dart` 新增 `OhosBadge` 组 3 条用例（48vp 行里高度锁在 18 且宽 ≥ 高、多位数横向长于高度、点是 8×8 / 无 count 无 child 时收成零）
- 修复 `OhosList` 里每个行边界叠着两条分隔线：`OhosListTile` 默认自己画一条（`divider: true`、`indent: 16`），`OhosList` 又在行与行之间插一条（`indent: 56`），两条左端不一致，看上去就是「两条线错位叠加」；顺带最后一个 tile 底下还有一条压在卡片圆角里 —— n 行共画出 2n−1 条线。现在分隔线归列表所有：`OhosList` 通过新增的 `OhosListDividerScope` 告诉每个 tile「你在列表里 / 你是不是最后一项」，tile 在列表内不再自己画（`OhosListTile.divider` 只在单独使用时生效），列表对非 `OhosListTile` 的子节点仍按原样补线。配套 `test/ohos_ui_test.dart` 新增 `OhosList` 组 4 条用例：3 行只出 2 条线、`indent` 跟着 `leading` 走（56 / 16）且左端与标题文字重合、`divider: false` 整列不画、非 tile 子节点由列表补线
- 调整分隔线两端不再贯穿（作者意图：两端收进卡片更好看）：左端对齐文字 —— 无 `leading` 为 16vp、有 `leading` 让到图标之后 56vp；右端统一留 16vp（`endIndent: 16`）。列表给非 `OhosListTile` 子节点补的线同步改成两端内缩，`OhosDivider` 的文档也一并更正
- 修复 `OhosGrid` 的栅格几何（四处一起收）：

  1. **末行不满时单元被拉伸**：原来每格是 `Expanded(flex: span)` 加固定宽 gutter spacer，末行剩下的空间全摊给已有单元 —— 12 列里单个 `columnSpan: 3` 的单元会占满一整行，与上方满行行的列边缘对不齐。现在右侧保留空列（补一个 `Expanded(flex: remaining)` 占位），并把 gutter 劈成两半放进每格的左右内边距，外层 `padding` 让回半格：槽位宽 = `(内容宽 + gutter)·span / 列数`，减掉两半正好是官方的 `span·colWidth + (span−1)·gutter`，**与同行单元个数无关**，行与行之间边缘严丝合缝，首格仍贴页面边距。
  2. **`maxWidth` 语义**：2220vp 的「栅格最大使用宽度」原来连两侧 margin 一起算在上限里（可见内容区实际是 2220 − 2×margin），现在只限制单元区，边距在外（见上方 padding 让半格的处理）。
  3. **末行多一条行距**：`runSpacing` 原来连最后一行也补一段 `Padding(bottom:)`，网格底部凭空多出一条空行距，拼接下一块内容时对不齐；改为只加在行与行之间。
  4. **`_emitRow` 的无用参数**：`remaining` 声明了却没用上，其语义（本行还剩几列）现在真正用在了空列占位上。

  配套 `test/ohos_ui_test.dart` 新增 `OhosGrid` 组 3 条用例：末行单元宽度与满行一致且左边缘对齐、行距只出现在行与行之间（网格总高 96 而非 112）、`maxWidth` 限制的是单元区（宽屏下跨满 12 列正好等于 `maxWidth`）
- 示例：布局与动效页在墨水屏下全部改走灰阶，保留彩色屏的填充形式、只换颜色（真机 NoteAir 上已逐项对照）：

  - 栅格 / 响应式 / 动效单元：原来用「浅灰 `#F1F3F5` 底 + 10% 品牌蓝」，压到 16 级灰阶上全落成白色、单元整块看不见。改成 `#DDDDDD` / `#BBBBBB`（栅格两级）与 `#CCCCCC` / `#BBBBBB` / `#AAAAAA`（响应式三级，底板 `#EEEEEE`），取值都是 17 的倍数、正好落在灰阶格子上，不出抖动噪点；文字色改读主题字阶（墨屏纯黑）。
  - 共享元素三张卡：蓝 / 绿 / 橙压成中灰后配白字读不出来（绿、橙两张几乎糊在一起）。墨屏换深灰阶 `#111111` / `#333333` / `#555555`，白字对比度仍在 7:1 以上；放大转场后的浮层底色由「35% 黑」改成浅灰 `#DDDDDD`，并去掉白底上本来就不存在的阴影。
  - 沉浸光感：粉紫蓝渐变压成一块没有意义的灰带，墨屏直接给一档实心深灰 `#333333` 当背景，THIN 退化成纯白后仍然立得住；THICK 退化成纯白后与页面同色，按库的约定（边界交给调用方）自己补 1px 线；`+` 图标改读 `theme.highlightColor`（原来硬编码品牌蓝）。
  - 动效曲线：跑道底由 `#F1F3F5` 换成 `#EEEEEE`，圆点改读 `theme.highlightColor`；进度条仍是 55% 品牌蓝 —— 压到灰阶上是中灰，与彩屏版本对照最直观。

### Bugfix（`DefaultTextStyle` 继承链）

- 修复 `OhosAlertDialog` 的标题与正文在真机（墨屏）上各带**两条黄线**。弹窗由 `showDialog` 挂在 Navigator 的 Overlay 上，**没有 `Material` 祖先**，那两段 `Text` 因此退到 `DefaultTextStyle.fallback` —— 这个常量是 `#FFFF00` + `TextDecorationStyle.double`，专门用来在视觉上标记「这段文字没有任何样式来源」。实测截图有 **5340 个 `#FDFE53` 级黄像素**（标题宽 135px、正文宽 262px 各一条）。修法是在弹窗内部补一层 `DefaultTextStyle`（`TextDecoration.none` + `textPrimaryColor`），一次覆盖标题、正文与任意 `contentWidget`；不是逐处给 `Text` 传 `style`。**按钮文字当时是正常的**（`_OhosDialogActionButton` 自己包了 `Material`），所以只截按钮或只测按钮会完全漏掉这个缺陷
- 修复 `OhosButton` 的 `TextButton` 变体：`decorationColor: underline ? foreground : null`。非下划线分支给 `null` 等于**把祖先的 `decorationColor` 放行下来** —— `DefaultTextStyle.merge` 只覆盖非 null 字段，`null` 不是「清空」而是「不表态」。这条在真机上表现为墨屏弹窗标题下方一条黄线；`flutter_test` 的默认 `DefaultTextStyle` 恰好带 `decorationColor = #FFFF00`（测试框架给「不该有下划线却有了」留的警报色），而 Material 3 真机该字段是正文色，所以**只在墨屏 + 特定祖先链上显形**。改为两个分支都给值（`Colors.transparent`）
- 修复对应的弱断言：`test/text_button_affordance_test.dart` 原来用 `isNot(const Color(0xFFFF0000))`，`null` 也能通过。改成强断言 `Colors.transparent` 并做变异验证（撤销修复 → 变红）
- 排查范围：`showMenu`（内部自带 `Material`）、`showModalBottomSheet`（`ohos_bottom_sheet.dart` / `ohos_picker.dart` 各自有 `Material`）、`OhosToast` / `OhosPopup`（早已显式给中性值）、`OhosMagnifier`（`inherit: false` 断链）均不受影响。**只有 `showDialog` 这一条路会中招** —— `ohos_popup.dart` 的注释里其实早就记过同一个坑，但当时只修了 Toast 那一条路径，没有回头查「还有谁挂在 Overlay 上」

### Tooling

- `tool/capture_theme.sh`：修 `switch_theme` 的词表不匹配 —— 调用方传 `ink`（与 `mode`、目录名、README 一致），主题探针只输出 `gray` / `light` / `dark`，两者永远 `!=`，脚本因此永远判「切不过去」并把主题转走。失败时改为直接退出，不再产出错标主题的截图
- `tool/capture_theme.sh`：支持按分类过滤与按分类定屏数 —— `./tool/capture_theme.sh <light|ink> 导航类`；导航类与 `UI Design Kit` 各采 11 屏（其余 5 屏），因为这两个页面区块数超过 5，原先 `kit_09` / `kit_10` 会拍成同一张
- 文档：**主题按钮是 3 态循环**（light → dark → gray → light），不是 4 态；「深色墨水屏」只能在长按菜单里选，脚本的循环拍不到，必须现场操作
- 文档：交互态截图（弹层 / 放大镜 / 菜单 / 转场）的采法 —— `uinput -M` 的「按下 / 移动 / 抬起」三步可分离执行，能在**按住状态**截到放大镜与索引条泡泡；`uitest uiInput drag` 则用「后台起拖 + 定时截图」卡拖拽中间帧（色带放大镜、共享元素转场靠这个）

### Optimization

- 示例工程与文档的图标包依赖由 `ohos_icons` 迁移到 **`harmony_icons`**。`ohos_icons` 已改名为 `harmony_icons`，旧包在 pub.dev 上标记为 discontinued（`"isDiscontinued": true`），不会再有更新；`harmony_icons` 0.1.0 于 2026-10-13 发布。**类名不变，仍是 `OhosIcons`** —— 两包导出的是同一套 534 个 Symbol 常量，逐个比对只差两处笔误修正（`chevron_down_` → `chevron_down_L`、`chevron_up_` → `chevron_up_L`，旧名末尾多一个下划线），本库用到的 `chevron_right` 不受影响。因此迁移是纯包名替换：`example/pubspec.yaml` 一行 + 8 个示例页的 import 一行，零代码改动。下方 v0.1.0 的条目仍写 `ohos_icons`，那是当时的真实依赖，不改写历史

## v0.6.0

Release date: 2026-11-04

### Features

- 半模态面板 `bindSheet` 的 **5 种 `SheetType` 全部落地**（`OhosSheetType` / `OhosSheetSize` / `OhosSheetDetent` / `OhosSheetSpec`）。这不是「同一块面板换对齐方式」，而是 **5 套能力矩阵**：BOTTOM 只圆上面两角；CONTENT_COVER 无圆角、**无蒙层**、无标题栏与关闭按钮；SIDE 高度恒全屏且无控制条与挡位；CENTER / POPUP 下 `SheetSize.MEDIUM` 与 `LARGE` **无效**（恒 560vp）
- 半模态多挡位 `detents`：枚举挡位与数值挡位可混写、最多 3 挡、首挡为初始高度、**生效时 `height` 直接失效**。挡位切换按官方判据实现 —— **速度优先**（>1000px/s 直接按手速方向切挡，不看距离），速度不够才退回到「位移 > 当前与目标距离的 1/2」
- 半模态宽度响应式默认形态（`preferType`）：<600vp BOTTOM、600–840vp CENTER、≥840vp POPUP
- 悬浮页签栏 `OhosFloatingTabBar` / `OhosFloatingTabItem` / `OhosFloatingTabBarStyle` / `OhosFloatingTabScaffold`，以及三档宽度算法 `OhosTabsWidthDefaults`。**这是另一个形态而非 `OhosTabBar` 的变体** —— 官方把三档宽度、蒙层、迷你栏全部挂在 `barFloatingStyle` 下，它有三个平铺栏不满足的前置条件（栏叠在内容之上、非纵向、位于底部）
- 迷你栏 `OhosMiniBar` / `OhosMiniBarStyle` / `OhosMiniBarScaffold` 与 `OhosTabsController` / `OhosAnimationMode`。**迷你栏与页签栏是两个独立的栏**（官方单列 `HdsTabsMiniBar`，有自己的宽度分档、折叠状态与动效回调）。控制器含折叠动效三方法（`applyMiniBarStyle` / `applyHideAnimation` / `applyShowAnimation`）与滚动联动（`bindScroller` / `unbindScroller`）
- 核心操作栏 `OhosActionBar` 按官方结构重写：`startButtons` / `endButtons` 两端按钮组 + 主按钮，落 `OhosActionBarButton`（官方 17 属性取 12）与 `OhosActionBarStyle`（官方 10 字段全落）
- 数据面板 `OhosDataPanel` 按官方语义重写（占比图 / 环形 / 线形），并新增量规图 `OhosGauge`
- 列表卡片 `OhosListItemCard` / `OhosListItemCardList`（A-B-C 三区、三层文本、17 种后缀）与列表分组 `OhosListGroup` / `OhosListGroupSliver`（卡片样式、组头组尾、吸顶组头）

### Bugfix

- 半模态圆角由 **24vp 修正为官方 32vp**。24 是 `float.json` 里 `ohos_id_corner_radius_dialog`（**对话框**圆角）的值 —— 同一个「圆角」概念、数值都在 20–30 区间，拿错一个看起来完全合理
- 半模态墨水屏描边按形态给边：原实现写死 `BorderRadius.vertical(top:)`（只有底部形态成立），现 BOTTOM 只描顶上一条、CENTER / POPUP / SIDE 描四边、CONTENT_COVER 无圆角
- 悬浮页签栏 **328vp 是绝对上限不是必然值**：容器 340vp 宽时「16 + 328 + 16 = 360」直接溢出 20vp，必须再夹一次可用宽度。`RenderFlex` 不会报错，只是把栏挤出屏幕
- 悬浮页签栏**必须居中**：用 `Padding(left/right)` 定位会变成左对齐，栏一窄就贴左，肉眼像漏了一半。边距约束的是最小间隙，不是定位锚点
- 迷你栏**「居中」是相对容器**：用 `Row + Spacer` 时折叠者占掉流式布局空间，展开者中心偏移 28vp（520vp 宽、折叠 56 + 展开 200 时）。改用 `Stack` + `Align`
- 迷你栏两个栏宽度各自独立算出、**合计可能超容器**：320vp 屏上「200 + 8 + 220 = 428」溢出 68vp，`Row` 不折行且静态分析不报错，是 `example` 溢出矩阵报 `RenderFlex overflowed by 68 pixels` 才暴露
- `OhosTabsController.bindScroller` **只挂只读监听、绝不 `hold()` 或改写 position** —— 曾写成 `scroller.position.hold()`，会让内容区滚动卡住不动，单看 API 签名完全看不出来
- 示例「布局与动效」页的动效曲线填充条写死品牌蓝 `#0A59F7`，墨水屏下是一条彩色带。原注释写着「55% 品牌蓝压到灰阶上是中灰，留着反而与彩屏对照最直观」—— 那句话对 16 级灰的**真机**成立，对**截图**不成立。改走 `theme.policy.quantize(...)`
- 示例「导航类」页的轮播占位页写死四色（蓝/绿/黄/粉），墨水屏下一页里出现四条彩色带。改走 `policy.quantize`，同时**把字色判断从「查写死的表」改成「算量化结果的亮度」** —— 「黄色配黑字」这条规则量化后不再成立
- 示例「UI Design Kit」页的点光源深底 `#101418` 与按压阴影示范块 `#8A8A8E` 未跟主题退化，墨水屏下带蓝相。两者都是**示例自绘的演示面**（点光源需要暗底才看得见白点），不是品牌色也不是数据，改走 `policy.quantize`

### Breaking changes

- `OhosActionBar` 结构改造：`startButtons` / `endButtons` 取代单一 `secondaryActions`；`primaryLabel` / `onPrimaryPressed` / `primaryLoading` / `expandable` / `isExpanded` / `onIsExpandedChanged` / `primaryIcon` / `primaryTooltip` 全部移除。官方 `HdsActionBar` 从来只有「起始组 + 主按钮 + 末尾组」这个形态
- `OhosDataPanel` 重写：旧构造语义（KPI 卡片网格）与官方（占比/环形数据图）完全不符，无法兼容
- `OhosListTile.divider` 由 `bool`（默认 `true`）改为 `bool?`（默认 `null`）。`null` 表示跟随所在的 `OhosList` —— 列表接管分隔线，行边界恰好一条、末行不画

### Optimization

- 文档重新对账：`doc/CONTROL-MATRIX.md` 从 227 行扩到 **256 行 / 完整 204**（口径变严：多个控件从 1–2 行拆成 5–17 行）
- README 的控件覆盖表从「只写类名」改为「官方形态逐项勾选」，并新增 `tool/check_readme_matrix.py` 校验两者不漂移 —— 两份文件是同一事实的两个副本，矩阵改了 README 没跟上时**不会让任何测试变红**
- 用例 491 → **649**；`example` 用例 **85 → 175**，其中溢出矩阵 72 → **162**（新增弹层维度 90 条 = 10 种弹层 × 3 尺寸 × 3 字号 —— 页面扫描扫不到**新路由里的面板布局**，这是原有矩阵的真实盲区）
- 新增 `example/test/ink_no_color_test.dart`：墨水屏「不应出现彩色」回归测试（8 页 × 全树扫 `DecoratedBox`）。补的是一个此前无人守的洞 —— README 的墨水屏图集靠真机截图，而截图的失败方式是**看起来像主题没切**，实际主题切对了、彩色来自示例自绘的占位内容。判据迭代过两版：初版按「单块面积占比」放行小色块，**变异验证时它放过了真实缺陷**（曲线条是四条 `358×10`，每块只占 1% 屏，叠起来却是一整片彩带）；最终改成「默认必须灰，颜色即数据要显式申报」（`example/lib/ink_color_data.dart` 的 `InkColorData`），并对三处真实缺陷逐一做过变异验证
- 文档源抓取地址由 gitee 迁移到 GitCode（`raw.gitcode.com` / `api.gitcode.com` 是不同 host），动因是旧地址的目录 API 已全线 403、而那正是「不猜文件名」的依据
- 构建链的环境坑已记录：`hvigor` 的 `ohpm install` 与 `SignHap` 都要删除中间产物，撞上批量删除保护后，报错分别写成 `ohpm install failed`（附「检查网络/仓库地址」）与 `Error Code: 00308018 Unknown Error` —— **两处都完全指不到真正的失败原因**。构建时去掉注入的 `NODE_OPTIONS` 即可通过

## v0.4.0

Release date: 2026-10-30

### Features

- 拖动放大镜：`OhosMagnifier`（48vp 圆泡，内容用 `text` 或 `child`；`monochrome` 下换 1px 纯黑描边并关掉入场动画）、`OhosMagnifierController`（`show` / `update` / `hide`，泡泡进根 `Overlay`，可画在宿主之外，`IgnorePointer` 不抢手势）、`OhosMagnifierPosition.resolve`（纯函数落点：手指四角各留 `gap`，放不下自动换角 / 换行）
- 索引条增强：`OhosAlphabetIndexer` 新增 `selectedIndex`（代码发起的定位与手指点亮同一个字母，受控期间拖动仍即时高亮）、`onSelectEnd`（交互结束恰好一次，带回最终字母）、`showMagnifier`（默认 `true`，仅拖动时显示）与 `magnifierBuilder`（自定义泡泡内容）
- 标题栏增强：`OhosAppBar.statusBarBackgroundColor` 把背景拆成「状态栏段 + 工具栏段」（沉浸式页面常见的「状态栏 = 页面底色、工具栏 = 卡片色」），内边距仍由组件吸收、总高不变，与 `scrollEffect` / `lightMaterial` 叠加时该段保持纯色；新增静态 `OhosAppBar.heightOf` 给出含状态栏内边距的总高，`toolbarHeight` 作为 `height` 的别名
- 示例：展示类新增「放大镜 OhosMagnifier」章节，索引条演示补齐拖动放大镜 / 自定义泡泡 / `selectedIndex` 代码定位；导航类新增「状态栏分段着色 / heightOf」章节

### Bugfix

- 修复 `OhosAlphabetIndexer` 点「当前已高亮的字母」被静默忽略：改为 tap 一律回调、drag 只在跨格时回调（逐帧通知会把调用方的 `jumpTo` 打成连续滚动）
- 修复索引条命中区只有字形那一条窄缝：改为 `HitTestBehavior.opaque` 整条命中，两侧留白与字间空隙不再把事件漏给下层列表
- 修复父级高度小于 `size.height` 时索引条 `RenderFlex overflowed`：整条与字号跟随父级约束缩小，并去掉切换时会闪黄黑条纹的 200ms 隐式动画
- 修复 `OhosScaffold` 的 body 子树仍读到已被认领的 `MediaQuery.padding`：四条边统一从 body 子树摘掉，body 里再包 `SafeArea` 不再叠出第二份内边距（有 `appBar` 时凭空多一条状态栏高度的空白）；需要贴边绘制时改读 `View.of(context).padding`

### Breaking changes

- 删除 `OhosAlphabetIndexer.itemHeight`：槽位高度改由父级约束决定（无界时退回 `size.height`），同一个 slot 同时供布局、字号与 `dy → 字母` 命中使用；旧写法 `itemHeight: perLetter` + `size` 高 `perLetter × 字母数` 结果不变，删掉这个实参即可

## v0.3.0

Release date: 2026-10-22

### Features

- 墨水屏（e-ink）主题：新增 `OhosThemeData.ink()`、`monochrome` 能力开关与纯黑字阶 `OhosTypography.monochrome`；光感材质自动退化为纯色，弹窗与常驻通知补 1px 纯黑描边
- 标题栏增强：`OhosAppBar` 新增 `primary`、`titleAlignment`、`titlePadding`、`leadingWidth`、`bottom`、`systemOverlayStyle`，改为单行 Row 布局，可在标题位放搜索框、底部挂子页签
- 输入组件增强：`OhosTextField` 新增 `variant`（下划线 / 填充 / 胶囊）、`suffixIcon` 与外部 `focusNode`；`OhosSearchBar` 新增 `focusNode`、`onClear`、`onCancel` / `cancelText`
- 容器与操作增强：`OhosAlertDialog.contentWidget` 表单内容槽、`OhosListTile.density`、`showOhosBottomSheet(level / lightMaterial)`、`showOhosSnackBar(customMessenger)`
- 窄屏与无障碍适配：`OhosActionBar` 次要操作横向滚动、`OhosChipGroup` 放不下时横向滚动、`OhosNavigationBar` 胶囊标签省略、`OhosAlphabetIndexer` 字号按高度自适应；新增 `OhosNavigationBar.maxTextScaleFactor`（默认 1.15，传 `null` 关闭钳制）

### Bugfix

- 修复 `OhosTextField` / `OhosSearchBar` 外部 `focusNode` / `controller` 中途更换时的同步与所有权问题，只释放组件自建实例
- 修复 `OhosSearchBar` 换节点后焦点态过期；取消按钮改为可访问的 `TextButton`（48×40vp 命中区）
- 修复 `OhosDataPanel` 整格 `FittedBox` 导致的静默缩字：标签保持有界省略，仅数值按比例缩放
- 修复 `OhosAlertDialog.contentWidget` 在窄屏 / 大字号下的纵向溢出，内容区可滚动
- 修复 `OhosAppBar` 沉浸式状态栏遮挡、标题被右侧操作覆盖，以及 `scrollEffect` 缺少 controller 时静默失效
- 修复窄屏叠加 1.15x / 1.3x 系统字号时示例与组件的多处 `RenderFlex overflowed`
- 修复墨主题下错误态底线仍为红色、弹出气泡 / 滑块气泡阴影不可见

### Breaking changes

- `OhosAppBar.primary` 默认 `true`，会吸收 `MediaQuery.padding.top`；外层已套 `SafeArea` 或标题栏不在屏幕顶部时传 `false`
- `OhosAppBar` 标题居中基准由整栏中轴改为 leading 与 actions 之间；`OhosDivider.indent` 默认值由 16 改为 0
- `OhosChipGroup.scrollable: false` 现在表示“放得下时不加滚动视图”，放不下仍会横向滚动
- `OhosDataPanel` 不再整体等比缩放，长标签省略、数值单独缩放

### Optimization

- 库测试由 48 条增至 62 条，覆盖 focusNode / controller 切换、ink 渲染、弹窗滚动等路径
- 示例新增 8 页 × 3 宽度 × 3 字号溢出矩阵（72 条），并接入 CI 执行

## v0.2.0

Release date: 2026-10-21

### Features

- UI Design Kit 增强组件（对照华为「UI Design Kit 能力」文档）：
  - 点光源：`OhosLightSource` + `OhosIlluminated`，5 种受光类型，支持强度/光柱高度调节
  - 按压阴影：`OhosPressShadow`（`blendWhite` / `blendGradient`）
  - 侧边栏/侧边菜单：`OhosSideBar` + `OhosSideMenu` / `OhosSideMenuItem` / `OhosSideMenuSubItem`（一/二/三级菜单、角标、overlay 悬浮）
  - 横滑列表项：`OhosListItem` 左滑操作按钮 + 整划删除（`fullDelete`）
  - 常驻通知：`showOhosSnackBar(resident: true)`，图标 + 标题 + 描述结构
  - 子页签分割线：`OhosTabBar` 新增 `divider`（`OhosTabBarDividerOptions`）常显/常隐/跟手三模式
  - 颜色选择器增强：`OhosColorPicker` 网格/光谱/滑块三模式 + 收藏管理
  - 动态模糊标题栏：`OhosAppBar(scrollEffect:)`，内容穿透滚动 + 模糊背板按进度淡入
  - 可展开操作栏：`OhosActionBar(expandable: true)` 悬浮宫格形态
  - 分层图标 `OhosLayeredIcon` 与应用内多窗入口 `OhosMultiWindowEntry`（无能力设备自动禁用）
- 沉浸光感材质增强：彩色光池（glow pools）跟随交互、镜头高光与焦散（lens/caustics）、光感漫射（`scatterScale`）、`OhosLightEffectTuning` 六项倍率调参

### Bugfix

- 修复 gallery 示例 8 处问题：导航页签 label、菜单锚定位置、SnackBar 展示、空白占位、标题栏布局、分段按钮选中态、颜色选择器模式切换、共享元素转场

## v0.1.0

Release date: 2026-10-08

### Features

- 首个版本：Material/Cupertino 风格的 Flutter 组件库，实现 HarmonyOS 设计语言（华为「设计入门」规范）
- 完整覆盖官方「控件概览」6 大类 42 个控件：导航、展示、操作、输入、选择、容器
- HarmonyOS 设计令牌：主题色 `#0A59F7` / `#317AF7`、11 色多彩色板、四级文字/图标透明度、组件分层背景、品牌高亮背景与交互事件色，对齐官方色彩 Token 表
- 明暗双主题：`OhosTheme` / `OhosThemeData.light()` / `OhosThemeData.dark()`，支持 `copyWith` 定制
- 沉浸光感材质（基础版）：`OhosLightMaterial` ULTRA_THIN … ULTRA_THICK 五档毛玻璃背板，支持顶部/底部渐变模糊
- 响应式布局：`OhosResponsiveBuilder` + `OhosGrid` / `OhosGridItem`，600/840vp 断点（4/8/12 列）、16/24/32vp 边距、8/12/16vp 槽宽
- 转场动效：`OhosGeometry` 弹簧/缓出/共享元素曲线与 90/200/300/400ms 时长
- 配套图标包 `ohos_icons`（HarmonyOS Symbol 字体图标，已发布 pub.dev）
- gallery 示例应用：6 大控件分类 + 布局与动效共 7 个入口，全部在 OpenHarmony 模拟器（API 26，1280×2832）实机验证并截图

### Bugfix

- `OhosScaffold` 将 `OhosAppBar` 与 `body` 改为 Column 布局（v0.1.0 之前为 Stack 叠加），修复首页顶部内容被标题栏遮挡的问题

### Optimization

- 示例工程改用已发布的 `ohos_icons ^0.1.0`，移除同目录仓库依赖
