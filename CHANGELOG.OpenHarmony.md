# CHANGELOG

## Unreleased

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
