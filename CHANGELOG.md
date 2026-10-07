## 0.1.1 (unreleased)

- 对齐官方色彩 Token 表：新增 `comp_background_primary/gray`、`comp_emphasize_secondary/tertiary`（20%/10% 品牌高亮）、`interactive_hover/pressed/focus/select`、四级文字 `textFourth`，修正深色主文字透明度
- 沉浸光感：新增 `OhosLightMaterial`（ULTRA_THIN…ULTRA_THICK 五档 + 渐变模糊），`OhosAppBar(lightMaterial:)`、`OhosNavigationBar(lightMaterial:)`、`OhosBottomSheet`（ULTRA_THICK）开箱即用
- 响应式布局：新增 `OhosResponsiveBuilder`、`OhosWindowSize`、`OhosGrid`/`OhosGridItem`，实现 600/840vp 断点与 4/8/12 列栅格（16/24/32vp 边距、8/12/16vp 槽宽）
- 子页签：`OhosTabBar` 支持 `OhosTabBarType.capsule`（品牌色填充 + 灰底未激活 + 8vp 间距）；新增 `OhosChipGroup`（单选/多选、普通/小尺寸）
- 底部页签：`OhosNavigationBar` 支持平铺式 48vp / 悬浮式 56vp，激活项 20% 品牌高亮胶囊、图标 24vp
- 转场动效：`OhosGeometry` 新增 `sharedElement` 曲线、`durationLong`、沉浸光感模糊强度映射
- 示例：新增「布局与动效」分类页（栅格/响应式断点/沉浸光感/一镜到底/曲线对比），导航页升级为双样式子页签与双样式底部页签，新增模拟器截图

## 0.1.0
