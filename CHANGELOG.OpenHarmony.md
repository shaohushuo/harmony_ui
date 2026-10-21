# CHANGELOG

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
