## 0.5.0

Release date: 2026-11-01

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
