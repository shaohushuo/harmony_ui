## 0.3.0 (unreleased)
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
