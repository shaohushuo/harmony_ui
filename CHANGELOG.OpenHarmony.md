# CHANGELOG

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
