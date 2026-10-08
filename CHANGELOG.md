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
