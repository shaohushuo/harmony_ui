# 控件形态覆盖矩阵

每一行 = 官方参考文档里明确列出的一个**形态**（不是"一个控件"）。这张表的用途是让「全覆盖」这句话可被核对：谁声称覆盖，就在对应行的 `本库实现` 与 `测试` 两列填上。

- 依据：`doc/reference/` 里的参考文档（`枚举说明` / `对象说明` 章节）与设计规范页。参考文档来自两条链路 —— 开源 ArkUI 组件取自 OpenHarmony 仓库，闭源 HDS 组件（`Hds*`）取自官网 `doccenter-references/api/ui-design-<slug>.md`；两者都是官方原文。
- **「依据」列的确定性分三档，不要混着自称「照官方做的」：**①写 `Hds*` / `ts-*` 等组件名 = 有组件级 API 文档；②写「设计规范」= 只有 UX 页描述、没有 API 级规格；③写**令牌名**（如 `search_default_height`）= 数值取自**系统资源表**（`global_system_resources` 的 `pattern.json` → `float_sys.json` → `float.json`，`tool/fetch_sys_resources.sh` 可复跑）。第三档比前两档都硬 —— 它是构建 `resources.index` 的源文件，不是对它的描述。
- `—` 表示该项无需实现（例如纯平台能力）。
- 空 `测试` 列 = 有实现但缺可失败的用例，属于未完成。

更新时间以外的改动请连带改 `CHANGELOG`。

## 导航类

| 控件 | 官方形态 | 依据 | 本库实现 | 测试 |
| --- | --- | --- | --- | --- |
| 底部页签 | 平铺 48vp | 设计规范 | `OhosNavigationBar(tile)` | |
| 底部页签 | 悬浮 56vp + 沉浸光感 | 设计规范 | `OhosNavigationBar(float)` | |
| 底部页签 | 三档宽度 small/medium/large | `HdsTabs` `HdsBarWidthRangeOptions` | `OhosFloatingTabBar` + `OhosTabsWidthDefaults` | 6 条纯函数 + 3 条布局；≥4 个直接取 328（非算完再夹）；高宽比 = 高÷宽 |
| 底部页签 | 渐变蒙层（浅 `#CCF1F3F5` / 深 `#99000000`，高 = 栏高 + 16vp） | `HdsTabs.barFloatingStyle.gradientMask` | `OhosFloatingTabBarStyle.showMask` / `maskColor` / `maskHeight` | 2 条：默认画蒙层、`showMask: false` 不画 |
| 底部页签 | 悬浮栏左右边距三档 16 / 24 / 32 | `HdsTabs.barFloatingStyle.barSideMargin` | `OhosFloatingTabBarStyle.sideMargin`（null = 自动分档） | 2 条：三档分档 + 显式值不参与分档 |
| 底部页签 | 悬浮栏栏高 56vp | `HdsTabs.barHeight` | `OhosFloatingTabBarStyle.height` | 1 条 |
| 底部页签 | 迷你栏（折叠 / 展开 / 自定义内容） | `HdsTabsMiniBar` | `OhosMiniBar` + `OhosMiniBarStyle` | 8 条：折叠 56 / 展开分档 / 不超容器宽 / 首次创建三例 / 背景开关 / 裁剪开关 |
| 底部页签 | 迷你栏与页签栏水平 / 垂直布局 | `HdsBarLayoutMode` | `OhosMiniBarScaffold.layoutMode` | 3 条：440–600 折叠者贴边 / <440 整体居中 / 垂直上下 |
| 底部页签 | 迷你栏居中规则（440vp 换口径） | `HdsTabsMiniBar` 说明段 | `OhosMiniBarAlign` + `alignFor` | 4 条纯函数：<440 整体 / 440–600 仅展开者 / 同展开 / 同折叠 |
| 底部页签 | 控制器：折叠 / 展开与动效 | `applyMiniBarStyle` / `applyHideAnimation` / `applyShowAnimation` | `OhosTabsController` | 5 条：状态变更才通知 / 两个 applyXxx / 同状态不通知 / `lastAnimationMode` / 控制器驱动布局切换 |
| 底部页签 | 滚动联动 | `bindScroller` / `unbindScroller` | `OhosTabsController.bindScroller` / `unbindScroller` | 4 条：登记 / 解绑 / 重复绑定不叠加 / 不接管滚动 |
| 子页签 | 文本型 | `Tabs` SubTabBarStyle | `OhosTabBar` | |
| 子页签 | 胶囊型 | `ChipGroup` | `OhosChipGroup` | |
| 子页签 | 分割线 3 模式 | 设计规范 | `OhosTabBarDividerMode` | |
| 子页签 | 胶囊左右内边距 `startSpace`/`endSpace`（默认 16/16） | `chipGroupSpace` | `OhosChipGroup` + `OhosTabBar(capsule)` | 新增 `startSpace`/`endSpace`；页签形态显式归零（两端已由 TabBar 自己的 16 表达） |
| 子页签 | 胶囊上下内边距（默认 14/14） | `chipGroupPadding` | `OhosChipGroup` | 新增 `padding`，整组高 36 + 28 = 64；页签形态归零（48 高栏里塞不下） |
| 子页签 | 默认选中首个（`selectedIndexes` 默认 `[0]`） | `selectedIndexes` | `OhosChipGroup` | `selectedIndex` 默认 `0`，`multiple` 时 null → `{0}`；传 `-1`/空集可退回旧表现 |
| 子页签 | 可关闭 ×（`allowClose`） | `allowClose` | `OhosChipItem` | 默认 `false`，与 ArkUI 同向 |
| 子页签 | 后缀图标优先级 `suffixSymbol` > `suffixImageIcon` > `allowClose` | 三属性互斥 | `OhosChipItem` | 给了 `suffixIcon` 就不画内置 × |
| 标题栏 | 普通 | `HdsNavigation` Title | `OhosAppBar` | |
| 标题栏 | FREE（滚动缩小） | `HdsNavigationTitleMode.FREE` | ○ | |
| 标题栏 | FULL 大标题（112 / 138vp） | `HdsNavigationTitleMode.FULL` | ○ | |
| 标题栏 | MINI 小标题（56vp） | `HdsNavigationTitleMode.MINI` | `OhosAppBar` | |
| 标题栏 | MODAL 半模态（6.0.0+） | `HdsNavigationTitleMode.MODAL` | ○ | |
| 标题栏 | 底部自定义区 `bottomBuilder` | `BottomBuilderParams` | ○ | |
| 标题栏 | 动态模糊两套样式线性过渡 | `ScrollEffectOptions` | ◐ `OhosAppBar.scrollEffect` | |
| 标题栏 | 可编辑 | `EditableTitleBar`（**源码有，文档无**） | ○ | 官方 SDK 的 `advanced_ui_component/editabletitlebar/source/editabletitlebar.ets` 存在（958 行），规格可直接读：栏高 56、标题 20vp、副标题 14vp、主标题最多占 65% / 副标题 35%、头像 64vp、编辑弹窗 216–256vp。**「确认无文档」只对参考文档成立，不等于无规格** |
| 导航点 | 圆点 | `DotIndicator` | `OhosPageIndicator` | 未选中 6×6、选中 **12×6**、间距 8；**选中是变宽不是变大**（官方示例 `selectedItemWidth(16).selectedItemHeight(8)`） |
| 导航点 | 数字 | `DigitIndicator` | `OhosPageIndicator(type: digit)` | `当前/总数` 从 1 起；14fp/**w400**，当前页与总数只差颜色 |
| 导航点 | 箭头 | `ArrowStyle` + `displayArrow` | `OhosSwiper(showArrows:)` | 底板 32、箭头取 3/4、底板色 10% 黑；单页时不画（官方行为） |
| 导航点 | 超长显示（`maxDisplayCount` 6–9） | `DotIndicator.maxDisplayCount` | ○ | 点超出页面时折叠成超长样式，且**不支持交互** |
| 导航点 | 蒙版样式（`mask`） | `DotIndicator.mask` | ○ | |
| 导航点 | 按压 1.33 倍放大 | `swiper_indicator_scale` | ○ | 墨屏已用 1.33 表达「当前项」，但是静态加长而非按压放大 |
| 导航点 | 任意位置 / 尺寸（`left`/`top`/`right`/`bottom`） | `Indicator` 基类 | ○ | 官方另有 32vp 默认交互区，故无法完全贴底 |
| 导航点 | 逐项自定义的 `IndicatorComponent` | `IndicatorComponent` | ○ | |

## 展示类

| 控件 | 官方形态 | 依据 | 本库实现 | 测试 |
| --- | --- | --- | --- | --- |
| 文本 | 单行 / 多行 / 省略 | `Text` | `OhosText` | |
| 文本 | 跑马灯 | `TextMarqueeOptions` | ○ | |
| 分隔器 | 横向 | `Divider` | `OhosDivider` | |
| 分隔器 | 纵向 | `Divider.vertical` | `OhosDivider` | |
| 分隔器 | lineCap | `Divider.lineCap` | ○ | |
| 子标题 | 列表型 | `SubHeader` | `OhosSubheader` | `OhosSubheader` 组 10 条 |
| 子标题 | 内容型（主 + 副双行） | `subheader.ets:654` `SubTitleStyle` | `OhosSubheader` | 双行字阶、2vp 间距、`type` 推导三条 |
| 子标题 | 右侧 0/1/2+ 操作 | `SubHeader` `operationType` 四值 | ◐ 仅 `TEXT_ARROW`/`BUTTON` 单条文本 | `showTrailingArrow` 对应两值；`ICON_GROUP` / `LOADING` / `select` 未实现 |
| 子标题 | 高度三档：单标题 **56** / 单副标题 **56** / 双行 **72** | `subheader_single_title_height` / `_single_subtitle_height` / `_double_height` | `OhosSubheader` | 三档各断一次；数值经 `subheader.ets` 的 `RESOURCE_CACHE_MAP` 与 `float.json` 双路互证 |
| 子标题 | 副标题行（字号 14、双行权重 **400**、`titles_space` **2**） | `Subtitle_S` / `_subtitle_font_weight` / `_titles_space` | `OhosSubheader` | 双行 400 与单行 500 各断一次（官方权重随形态变） |
| 子标题 | 左图标（`left_icon_size` **16**、图标与文字间距 **8**） | `_left_icon_size` / `_left_icon_end_margin` | `OhosSubheader.icon` | 16×16 + 间距 8；**仅 `secondaryTitle` 存在时才出现**（与 `leftArea()` 优先级链一致） |
| 子标题 | 左右边距 **16/16**、内容 padding **8** | `subheader_content_margin_start/end` / `_content_padding` | `OhosSubheader` | 外边距 16；副标题单行形态额外 +12（`subheader_single_subtitle_padding`） |
| 进度条 | Linear | `ProgressType.Linear` | `OhosProgressIndicator.linear` | `OhosProgressIndicator` 组 21 条 |
| 进度条 | Ring | `ProgressType.Ring` | `OhosProgressIndicator.ring`（`.circular` 为旧名别名） | 同上 |
| 进度条 | Eclipse（月相） | `ProgressType.Eclipse` | `OhosProgressIndicator.eclipse` | 同上 |
| 进度条 | ScaleRing（带刻度） | `ProgressType.ScaleRing` | `OhosProgressIndicator.scaleRing` | 同上 |
| 进度条 | Capsule（头尾弧形） | `ProgressType.Capsule` | `OhosProgressIndicator.capsule` | 同上 |
| 进度条 | 厚度 **4vp**、默认直径 **72vp**、线性默认宽 **300vp** | `ohos_id_progress_thickness` / `_default_diameter` / `_default_width` | `OhosProgressMetrics` | 三个常量直断；线性无界时退回 300（`UnconstrainedBox` 下才走得到） |
| 进度条 | 三种「进度」语义各不同：线性/胶囊量**长度**、环/刻度环量**角度**、月相量**面积** | `progress_modifier.cpp` | 各 painter 分别实现 | 月相用 `Path.contains` 采样：`0→0 / 0.5→整左半圆 / 1→满圆` |
| 进度条 | 月相靠两条弧非零环绕相减（≤0.5 反向、>0.5 同向），不是画扇形 | `PaintMoon` | `ohosEclipsePath` | 三档端点 + 单调推进（非阶跃） |
| 进度条 | 刻度环进度是**刻度换色**不是刻度增减：先整圈铺底色再覆盖前 N 弧度 | `PaintScaleRing` | `_ScaleRingPainter` | 刻度数恒为 120，只有颜色分段变化 |
| 进度条 | 刻度数上界 `min(w,h)/scaleWidth/2/π`，越界即退化 | 文档「ScaleRing 默认宽高最小 77vp」 | `ohosScaleRingDegrades` | 半径 36 退化 / 38.5 不退化 —— **77 这个下界就是该不等式的反解** |
| 进度条 | 刻度环退化时画环而非留白 | —（自定） | `_ScaleRingPainter` | 空画布会被读成渲染失败 |
| 进度条 | 胶囊内描边 **1vp `#33007DFF`**、文字 12fp `#FF182431` | `ohos_id_float_progress_border_width`（注意源码另有 `DEFAULT_CAPSULE_BORDER_WIDTH = 0.0`，那是绘制函数形参兜底） | `OhosProgressMetrics.capsuleBorderWidth` | 1vp 直断；三档分流（月牙 / 中段矩形 / 收口）各断一次 |
| 进度条 | 环形阴影仅在 `radius > 10` 时画；厚度 + 阴影超半径时厚度压成半径一半 | `RING_SHADOW_VALID_RADIUS_MIN` | `_RingPainter` | 16vp 无阴影 / 100vp 有阴影；半径 12 时厚度 4 → 9 |
| 进度条 | 墨屏：轨道不铺 15% 底，改画 1px 实线 | `OhosVisualPolicy` | `_TrackStyle.of` | `policy.tint` 返透明 ⇒ `policy.line` |
| 加载动效 | LoadingProgress（无明确进度、不可设 value） | `LoadingProgress` | `OhosLoadingIndicator` | `OhosLoadingIndicator` 组 6 条 |
| 加载动效 | 默认 **32vp** / 线宽 **3** / 周期 **2000ms** / 颜色 `#FF666666` | `LoadingProgress` 文档默认值 | `OhosLoadingIndicatorMetrics` | 尺寸与线宽生效、颜色取**中性提示色而非品牌色** |
| 加载动效 | `enableLoading: false` 仍占位（区别于 `Visibility.hidden`） | `enableLoading` | `OhosLoadingIndicator` | 有不转的静止弧，且尺寸不塌 |
| 加载动效 | 墨屏停转但弧保留 | —（本库策略） | `_syncAnimation` 读 `policy.scaleMotion` | 相位不推进，painter 仍在 |
| 索引条 | 弹出气泡 | `AlphabetIndexer` | `OhosAlphabetIndexer` | |
| 滚动条 | 有子节点 | `ScrollBar` | `OhosScrollbar` | |
| 滚动条 | 无子节点 | `ScrollBar` | ○ | |
| 新事件标记 | 数字 | `Badge` | `OhosBadge` | |
| 新事件标记 | 圆点 | `Badge` | `OhosBadge` | |
| 即时反馈 | Toast | `PromptAction` | `showOhosToast` | |
| 即时操作 | 文本按钮 `TEXT_ONLY` | `SnackBarOperationType` | `showOhosSnackBar(actionLabel)` | |
| 即时操作 | 关闭按钮 `CLOSE_BUTTON_ONLY` | `SnackBarOperationType` | `showOhosSnackBar(resident)` | |
| 即时操作 | 带右箭头文本 `TEXT_WITH_ARROW` | `SnackBarOperationType` | ○ | |
| 即时操作 | 文本+关闭 `TEXT_WITH_CLOSE` | `SnackBarOperationType` | ○ | |
| 即时操作 | 高亮文本+关闭 `HIGHLIGHT_TEXT_WITH_CLOSE` | `SnackBarOperationType` | ○ | |
| 即时操作 | `duration` 默认 5000ms / ≤0 常驻 | `SnackBarStyleOptions.duration` | ◐ 语义近似，值不同（默认 3s） | |
| 即时操作 | 高度自适应文本 | `isHeightAdaptive`（6.1.0+） | ○ | |
| 气泡提示 | 气泡 | `bindPopup` | `showOhosPopup` | |
| 气泡提示 | 自定义内容 | `CustomPopupOptions` | ○ | |
| 数据可视化 | 环形占比（`Circle`） | `DataPanel.type` | `OhosDataPanel` | `OhosDataPanel` 组 8 条 |
| 数据可视化 | 线形占比（`Line`） | `DataPanel.type` | `OhosDataPanel(type: line)` | 同上（含墨屏描边分支） |
| 数据可视化 | 数据值最多 **9** 段、负值置 0 | `DataPanelOptions.values` | `OhosDataPanel.effectiveValues` | 11 项取前 9、`[-1, 2]` → `[0, 2]` |
| 数据可视化 | `max` 两段语义（>0 标尺 / ≤0 按和归一） | `DataPanelOptions.max` | `OhosDataPanel.effectiveMax` | 75/100 留底槽、和/和 铺满、全零不除零 |
| 数据可视化 | 圆环粗细默认 **24**，大于半径时收成半径的 **12%** | `strokeWidth` / `ohos_id_datapanel_circle_thickness` | `OhosDataPanel.effectiveStrokeWidth` | ≤0 → 24；200 / 半径 80 → **9.6** |
| 数据可视化 | 底板色默认 **`#08182431`** | `trackBackgroundColor` | `OhosDataPanel.defaultTrackColor` | 色值直断；墨屏改画 1px 线 |
| 数据可视化 | 九段默认渐变（色值逐个取自文档） | `valueColors` | `OhosDataPanel.defaultColors` | 首末两段四色直断 |
| 数据可视化 | 投影（`colors` 缺省等于 `valueColors`，多退少不补） | `trackShadow` | `OhosDataPanelShadow` | 墨屏不画 |
| 数据可视化 | 关闭旋转动效与投影（`closeEffect`） | `closeEffect` | `OhosDataPanel.closeEffect` | |
| 数据可视化 | 量规图 | `Gauge` | `OhosGauge` | `OhosGauge` 组 12 条 |
| 数据可视化 | 角度语义：钟面 0 点为 0 度、顺时针为正、**只减法不回绕** | `startAngle` / `endAngle` | `OhosGauge` + `ohosSweepRadians` | 350 → 10 断 **20°**、0 → 360 断整圈、0 度退 90° |
| 数据可视化 | 环厚默认 **4**，超半径按半径处理 | `strokeWidth` | `OhosGauge.strokeWidth` | |
| 数据可视化 | 分段色 ≤9、比重 0 不显示、全 0 整环不显示 | `Gauge.colors` | `OhosGaugeSegment` | `isVisible` 两条 + 全 0 仍可绘制 |
| 数据可视化 | 指针可关（`indicator(null)`） | `indicator` | `OhosGauge.showIndicator` | |
| 数据可视化 | 说明区：不设则**看是否设了 min/max**（设了就显示量程，没设就不显示） | `description` | `OhosGauge.description` | 无 min/max 时零文本、给了显示 `0   100` |
| 数据可视化 | 量规图投影（**颜色随环**，不是黑色投影） | `trackShadow` | `OhosGaugeShadow` | 墨屏不画 |
| 数据可视化 | 线形数据条圆角 **4** | `datapanel_corner_radius` → `ohos_id_corner_radius_default_xs` | `OhosDataPanel` | |
| 二维码 | — | `QRCode` | `OhosQrCode` | |
| 文本时钟 | — | `TextClock` | `OhosTextClock` | |
| 图片 | — | `Image` | `OhosImage` | |
| 空白 | — | `Blank` | `OhosBlank` | |

## 操作类

| 控件 | 官方形态 | 依据 | 本库实现 | 测试 |
| --- | --- | --- | --- | --- |
| 按钮 | filled / tonal / outlined / text / plain | `ButtonStyleMode` | `OhosButton` | |
| 按钮 | 胶囊 / 圆角 / 圆形 | `ButtonType` | `OhosButtonShape` | |
| 按钮 | 3 尺寸 | `ControlSize` | ○ | |
| 下拉按钮 | — | `Select` | `OhosSelect` | |
| 状态按钮 | 开关 | `ToggleType.Switch` | `OhosSwitch` | |
| 状态按钮 | 勾选 | `ToggleType.Checkbox` | ○ | |
| 状态按钮 | 按钮 | `ToggleType.Button` | `OhosToggleButton` | |
| 操作块 | 基础（NORMAL / SMALL） | `Chip` `ChipSize` | `OhosChip` | |
| 操作块 | 尺寸 NORMAL 高 **36** / 圆角 **18** / 文字 padding **16** / 字号 **14fp** | `chip_normal_height` / `chip_normal_radius` / `chip_normal_text_padding` / `chip_normal_font_size` | `OhosChip` + `OhosChipGroup` | 36 / 18 / 16 / 14 全部对齐（数值集中在 `OhosChipMetrics`） |
| 操作块 | 尺寸 SMALL 高 **28** / 圆角 **14** / 文字 padding **12** / 图标 **16** | `chip_small_height` / `chip_small_radius` / `chip_small_text_padding` / `chip_small_icon_size` | `OhosChip` + `OhosChipGroup` | 28 / 14 / 12 / 16 全部对齐 |
| 操作块 | 图标与文字间距 NORMAL **6** / SMALL **4** | `chip_normal_text_margin` / `chip_small_text_margin` | `OhosChip` + `OhosChipGroup` | 6 / 4 对齐（原 4 / 2） |
| 操作块 | 默认无描边（`chip_border_width` = 0） | `chip_border_width` | ● 有意偏离 | 未选中态画了描边：墨水屏 `compBackgroundGrayColor` 就是纸色，无线则芯片散成纯文字 |
| 操作块 | 可关闭（allowClose） | `ChipOptions.allowClose` | `OhosChip` + `OhosChipItem` | 已实现，默认 `false`（有意偏离独立 Chip 的 `true`，见 ROADMAP §1.4） |
| 操作块 | 后缀图标（`suffixSymbol` > `suffixImageIcon` > `allowClose`） | `ChipOptions.suffixIcon` | `OhosChip` + `OhosChipItem` | 优先级已实现：给了 `suffixIcon` 就不画内置 × |
| 操作块 | 前图标（含 `normal`/`activated` 双态） | `ChipOptions.prefixSymbol` | `OhosChip` + `OhosChipItem` | `icon` / `selectedIcon` 双态；只给 `icon` 时选中态回落（有意偏离 `hasPrefix()` 的「选中即消失」） |
| 操作块 | 筛选型 | 设计规范 | ○ | |
| 工具栏 | 图标 + 文本（官方只有这一种，`button` 为自定义 slot） | `ToolBar` / `ToolBarOption.text` | `OhosToolbar` | `OhosToolbar` 组 11 条 |
| 工具栏 | ItemState 启用/禁用/激活 | `ItemState` 三值 | `OhosToolbarItemState` | 三值齐；两条独立维度（能不能点 / 允不允许激活），非互斥开关 |
| 工具栏 | 激活项 | `activateIndex` + `ItemState.ACTIVATE` | `OhosToolbar.activeIndex` | 双条件各断一次（只给 `activeIndex` 不点亮，是官方行为） |
| 工具栏 | 几何：栏高 **56** + 1px 分割线、图标 **24**、图标与文字间距 **2**、标签 **10fp**/w500、圆角 **8** | `DEFAULT_TOOLBAR_HEIGHT` / `IMAGE_SIZE` / `padding_level1` / `ohos_id_text_size_caption1` / `ohos_id_corner_radius_clicked` | `OhosToolbar` | 整条断 57；标签 10fp 而非 Material caption 的 12fp |
| 工具栏 | 超过 5 项收纳为「更多」（前 4 保留） | `TOOLBAR_MAX_LENGTH = 5` / `moreIndex = 4` | `OhosToolbar` | 6 项断「前 4 + 更多」，正好 5 项收入线内 |
| 工具栏 | 侧边距 **24** 仅在 `< 5` 项时生效 | `padding_level12` | `OhosToolbar` | `< 5` 断 24、`== 5` 断 0（条件是 `<`，不是 `<=`） |
| 工具栏 | 自定义 `button` slot（非图标 + 文字） | `ToolBarOption.button` | ○ | |
| 工具栏 | 长按 / 无障碍描述逐项 | `ToolBarOption` 无对应 | ○ | |
| 核心操作栏 | 默认（主按钮 + 两端按钮组） | `HdsActionBar` | `OhosActionBar`（`startButtons` + 主按钮 + `endButtons`） | `ohos_ui_test.dart` OhosActionBar 组 13 条：三段分布 / 去主按钮 / 总开关 / 逐按钮禁用 / 双图标切换 / 缺 altIcon 回落 / isExpand 默认收起 / 竖直时 startSpace 落到上边框 / 彩屏模糊 + 墨屏描边 / blurStrategy 关断 / 自定义主按钮 + 宽度 / 逐按钮 width / 样式值相等 |
| 核心操作栏 | 去主按钮 | `HdsActionBar.primaryButton` 可选 | `OhosActionBar(primaryButton: null)` | 同组「去掉主按钮时只画两端按钮组」 |
| 核心操作栏 | 起始按钮组 `startButtons` | `HdsActionBar.startButtons` | `OhosActionBar.startButtons` | 同组「三段分布」 |
| 核心操作栏 | 末尾按钮组 `endButtons` | `HdsActionBar.endButtons` | `OhosActionBar.endButtons` | 同组「三段分布」「isExpand 默认收起」 |
| 核心操作栏 | 竖直排列 | `ActionBarStyle.isHorizontal: false` | `OhosActionBarStyle.isHorizontal` | **`startSpace` / `endSpace` 在竖直时落到上下边框** —— 官方在参数说明里明文写了这条映射，最容易按名字固定成 left/right |
| 核心操作栏 | 自定义主按钮 + 宽度 | `primaryButtonBuilder` + `primaryButtonBuilderWidth` | `OhosActionBar.primaryButtonBuilder` | 优先级高于 `primaryButton`；缺宽度触发 assert（官方「必须同时设置」） |
| 核心操作栏 | 主按钮双图标切换 | `baseIcon` / `altIcon` + `isPrimaryIconChanged` | `OhosActionBarButton.icon` / `altIcon` + `OhosActionBarStyle.isPrimaryIconChanged` | 缺 `altIcon` 时回落 `baseIcon`（与 `OhosChip.selectedIcon` 同一条规则） |
| 核心操作栏 | 逐按钮 width / 背景 / 图标尺寸 | `ActionBarButton` | `OhosActionBarButton`（12 个属性） | 同组「逐按钮 width 覆盖默认圆直径」 |
| 核心操作栏 | 逐按钮阴影 `shadowStyle` | `ActionBarButton.shadowStyle`（默认 `OUTER_DEFAULT_LG`） | ○ | **不做**：`ShadowStyle` 枚举只给「大阴影」这种定性描述，`OUTER_DEFAULT_LG = 3` 只是枚举序号；`shadow.h` 里也无数值表。与 `textfield_error_spacing` 同类 —— 有名字、无值 |
| 核心操作栏 | 逐按钮禁用 | `ActionBarButton.enabled` | `OhosActionBarButton.enabled` | 同组「逐按钮禁用不影响同栏其它按钮」 |
| 核心操作栏 | 整体禁用 | `ActionBarStyle.enabled` | `OhosActionBarStyle.enabled` | **总开关**：背板与所有按钮一起失效（官方原文） |
| 核心操作栏 | 悬浮提示 `hoverTips` | `ActionBarButton.hoverTips` | `OhosActionBarButton.tooltip` | 走 `Tooltip` |
| 核心操作栏 | 默认模糊 `COMPONENT_REGULAR` | `ActionBarStyle.backgroundBlurStyle` | `OhosActionBarStyle.blurStyle` = `OhosLightMaterialLevel.regular` | **默认真开**（设计规范「组件背板默认带有模糊材质和投影」）；墨屏退化实色 + 1vp 描边，`blurStrategy: disabled` 同路径 |
| 核心操作栏 | 间距 height/innerSpace/startSpace/endSpace/margin | `ActionBarStyle` | `OhosActionBarStyle` 五个字段 | 几何全部自拟 —— 三张资源表搜 `actionbar` **零命中**，293 行文档只列属性不给数值 |
| 核心操作栏 | 模糊生效策略 | `blurStrategy`（`ADAPTIVE` 默认） | `OhosBlurStrategy` | `adaptive` 与 `enabled` 等同：Flutter 读不到系统性能档位，写清「读不到」而非假装做了自适应 |
| 核心操作栏 | 无障碍文本 | `ActionBarButton.accessibilityText` | `OhosActionBarButton.accessibilityLabel` | `accessibilityDescription` / `accessibilityLevel` 无 Flutter 对应 |
| 菜单 | 列表 | `Menu` | `showOhosMenu` | |
| 菜单 | 宫格 | `Menu` | `showOhosMenu` | |
| 菜单 | 子菜单 | `SubMenuExpandingMode` | ○ | |
| 文本选择菜单 | 一级（剪切/复制/粘贴/全选） | `SelectionMenu` | `OhosSelectionToolbar` | `OhosSelectionToolbar` 组 10 条：固定四项顺序（框架原始序列是 `cut/copy/paste/share/selectAll`，我们丢掉自带的 `share` 才得到这个顺序）、40×40 + 图标 24、`anchored` 形态 |
| 文本选择菜单 | 更多 → 二级 | `ExpandedMenuOptions` | `OhosSelectionToolbar` + `showOhosMenu` | 有扩展项才画「更多」、点了弹二级菜单、扩展项不进一级、无 `onSelected` 渲染成不可点 |
| 文本选择菜单 | 容器几何：按钮 **40**、图标 **24**、圆角 **8**、内边距与间距 **4** | `buttonSize` / `imageSize` / `corner_radius_level4` / `expandedOptionPadding` | `OhosSelectionToolbar` | 40 / 24 / 8 / 4 全部对齐（`selectionmenu.ets` 的 `defaultTheme`） |
| 文本选择菜单 | 默认开模糊 + 弹窗底色投影 | `iconPanelShadowStyle` = `OUTER_DEFAULT_SM` | `OhosSelectionToolbar` | 彩屏走 `OhosLightMaterial(thick)`；墨屏无模糊、改画 1vp 实线（`ohosBorderSide`） |

## 输入类

| 控件 | 官方形态 | 依据 | 本库实现 | 测试 |
| --- | --- | --- | --- | --- |
| 文本框 | 下划线（showUnderline，48vp） | `TextInput.showUnderline` | `OhosTextFieldVariant.underline` | 实测高 48 = `padding_level6`(12) × 2 + `content_height`(24) |
| 文本框 | 填充圆角 | 设计规范 | `OhosTextFieldVariant.filled` | 实测高 **40** = `padding_level4`(8) × 2 + 24；圆角 **20** |
| 文本框 | 胶囊 | 设计规范 | `OhosTextFieldVariant.capsule` | 实测高 40；圆角走 `radiusCapsule`（官方无独立胶囊令牌） |
| 文本框 | 内联（TextContentStyle） | `TextInput.style` | `OhosTextFieldVariant.inline` | 实测高 **24**（上下内边距 0）；圆角 4；左右 2 / 12 不对称 |
| 文本框 | 密码模式 | `InputType.Password` | `OhosTextFieldObscurePassword` 一组字段 | 遮蔽 + 末尾 24vp 眼睛 + 40 命中区；容器高 **48**（`password_style_height`） |
| 文本框 | 字数计数器（showCounter） | `TextInput.showCounter` | `OhosTextField.showCounter` + `OhosInputCounterOptions` | 四条件：showCounter + maxLength + 非内联非密码 + 过阈值；字号 10fp |
| 文本框 | 错误态（showError） | `TextInput.showError` | `OhosTextField.errorText` | 描边 **1vp**（`textfield_error_border_width`）、字号 **12fp**、左对齐 |
| 文本框 | 容器高 **40** / 内容高 **24** | `textfield_height` / `textfield_content_height` | `OhosTextFieldMetrics.height` / `.contentHeight` | ● 已对齐。**须开 `isDense`**，否则 `InputDecorator` 的 `kMinInteractiveDimension`(48) 兜底会无条件撑高 |
| 文本框 | 填充内边距 **16 / 8** | `textfield_padding_horizontal`(→`padding_level8`) / `textfield_padding_vertical`(→`padding_level4`) | `paddingHorizontal` / `paddingVertical` | 已接进 `contentPadding`（原为自拟 14/14，实测高 52） |
| 文本框 | 下划线内边距 **12 / 0** | `textfield_underline_padding_vertical`(→`padding_level6`) / `..._horizontal`(→`padding_level0`) | `underlinePaddingVertical` | 12 × 2 + 24 = 48 |
| 文本框 | 容器圆角 **20** | `textfield_border_radius` → `corner_radius_level10` | `OhosTextFieldMetrics.containerRadius` | ● 已对齐（原取主题 `radiusMedium` = 16，差 4）。源码 `text_field_pattern.cpp` 的 `IsUnderlineMode() ? ZERO : borderRadius` 证明下划线形态显式归零 |
| 文本框 | 内联圆角 **4** | `inline_radius_size` → `corner_radius_level2` | `inlineRadius` | 已对齐 |
| 文本框 | 尾部图标 **24** / 命中区 **40** | `textfield_icon_size` / `textfield_icon_hot_zone_size` | `iconSize` / `iconHotZone` | 已对齐；须显式传空 `suffixIconConstraints`，否则被 Material 默认的 48×48 撑开 |
| 文本框 | 计数器字号 **10fp** | `count_text_font_size` → `ohos_id_text_size_caption1` | `counterFontSize` | 已对齐 |

> **文本框有两个令牌不进数据行，理由各不相同。**
>
> 1. **`border_radius_size`（12）是死令牌。** `textfield_theme.h` 里确有 `borderRadiusSize_` 成员和 `GetBorderRadiusSize()` 访问器（源码默认 20.0_vp，与 `pattern.json` 追到的 12 还不一致），但在 `components_ng/pattern/text_field/` 整个目录 grep `GetBorderRadiusSize` **零命中** —— 没有任何一处把它写进 renderContext。这跟搜索框的 `search_text_field_padding_left` 是同一类病：**表里有、没人读**。常量保留只为记录结论，矩阵不给它开行。
> 2. **`error_text/error_underline` 这一族不算几何。** 它们是颜色令牌（`error_text_border_color` = `alert`），错误态的醒目靠**换色**而不是加宽描边 —— 所以 `errorBorder.width` 是 1 而不是 1.5（原实现写 1.5 会让错误框比聚焦框粗，视觉上跳动）。
> 3. **`textfield_error_spacing`（8）暂不接。** 它决定错误提示与输入框的间距，但 Flutter 侧这个间距是 `InputDecorator.subtextGap`，M3 下写死 4、M2 下 8，没有 decoration 级入口。要对齐只能自己画错误提示（绕开 `decoration.errorText`），那会连带失去 `_hasError` 的自动推导 —— 收益不足以抵这次改动的风险，故本版记「未接」，常量保留在 `errorSpacing` 备后续。
| 搜索框 | 取消按钮 / 清除按钮 | `Search` | `OhosSearchBar` | |
| 搜索框 | 默认高 **40** / 圆角 **20** / 无描边（`search_border_width` = 0） | `search_default_height` / `search_text_field_border_radius` / `search_border_width` | ● 高与圆角已对齐；描边有意偏离 | 高度 40 ✓、圆角 `radiusSearch=20` 显式对齐 ✓（不再靠 `height/2` 巧合）；墨水屏补 1px 描边 |
| 搜索框 | 放大镜图标 **16**，图标距左 **12**、距文字 **8** | `search_icon_size` / `search_icon_left_space` / `search_icon_right_space` | `OhosSearchBar` | 图标 16 ✓、左距 12 ✓、文字间距 8 ✓ |
| 搜索框 | 清除按钮图标 **16**、命中区 **40** | `search_close_icon_size` / `search_close_icon_hot_zone_horizontal` | `OhosSearchBar` | 图标 16 ✓、命中区 40 ✓（原 32，真机偏窄） |

> **不计入表格的死令牌：`search_height` = 56。** 早前矩阵里有一行「带搜索按钮时整栏高 56」，本版已删除 —— 它不属于「完整 / 部分 / 缺失 / 有意偏离」任何一类，因为它描述的能力**根本不存在**：13 份 `search/` 源文件里 `grep -rn search_height` 零命中，`SearchTheme::GetHeight()` 只解析 `search_default_height`（= 40），官方配了 `.searchButton()` 的示例全都写 `.height(40)`。同一类的还有 `search_text_field_padding_left` = 4，处置方式相同（移出表格，改注记）。详见 `ROADMAP-0.6.md` §1.4(c) 的两段纠正。
| 搜索框 | 右侧搜索按钮形态 | `Search.searchButton` | `OhosSearchBar` | 新增 `searchButtonText` |
| 搜索框 | 搜索按钮文字 padding **14**、按钮间距 **2**、分隔线两侧 **2**、按钮高 **36** | `search_button_text_padding` / `search_button_space` / `search_divider_side_space` | `OhosSearchBar` | 14 / 2 / 2 / 36 全部对齐 |
| 搜索框 | 无内容时按钮置灰不可点（`autoDisable`，API 18+，默认 `false`） | `SearchButtonOptions.autoDisable` | `OhosSearchBar` | 新增 `autoDisable`；默认关闭=官方默认，置灰取 `textTertiaryColor` |

> **`search_text_field_padding_left` 是死令牌，不列成数据行。** `search_theme.h:71` 把它读进 `leftPadding_`，但 `GetLeftPadding()` 在整个 `search/` 目录**零调用方**（pattern / layout_algorithm / model_ng / text_field / render_search 全查过），是旧框架 `frameworks/core/components/search` 的遗留字段。真正的水平几何在 `LayoutSearchIcon` / `LayoutTextField`，用的是 `search_icon_left_space`(12) + `search_icon_right_space`(8)。上一版本表曾把它记成「输入区左 padding 官方 4、本库多 8」，那个缺口**不存在**。

| 数字加减 | 数字 | `advanced.Counter` | `OhosCounter` | |
| 数字加减 | 日期（`CounterType.INLINE_DATE`） | `DateStyleOptions` / `counter.ets` | `OhosDateCounter` + `OhosDate` | 20 条（`OhosDate` 9 / `OhosDateCounter` 11） |
| 数字加减 | 日期容器几何（高 **32**、圆角 **8**、1vp 描边、日期组 **92**、段输入高 **20**、分隔符宽 **8**、箭头列 **32**、箭头图标 **12**） | `COUNTER_INLINE_*` 常量 + `border_width` | `OhosDateCounter` | 全部对齐；箭头两半走 `Expanded`（官方 16+1+16=33 溢出 32 盒，ArkUI 的边框不占内容区） |
| 数字加减 | 年夹取 `[1, 5000]` / 月回绕不进位 / 日按当月长度回绕 | `addDate` `subDate` `getDayNumber` | `OhosDate.addYears/addMonths/addDays` | ✓（三种回绕各有用例） |
| 数字加减 | 换月后日收敛到月末（`updateDay`） | `counter.ets:1071` | `OhosDate._clampedDay` | ✓（1/31 → 2/29、2/28） |
| 数字加减 | 段内直接输入（满位才提交） | `TextInput.onChange` | `OhosDateCounter` 三个 `TextField` | ✓（年满 4 位、日越界整段回退） |
| 数字加减 | 聚焦段底色反转 | `hasFocusText*` | `OhosDateCounter` | ✓（彩屏品牌蓝、墨屏黑块反白，无 policy 分支） |
| 数字加减 | 长按连续加减 | `LongPressGesture({repeat:true})` | ○ | |
| 数字加减 | 列表型 / 紧凑型 / 数字内联型（`LIST` / `COMPACT` / `INLINE`） | `NumberStyleOptions` / `InlineStyleOptions` | ○ | 本库现有 `OhosCounter` 是自拟的数字步进器，不是这三种形态中的任何一个 |
| 图案锁 | — | `PatternLock` | `OhosPatternLock` | |

## 选择类

| 控件 | 官方形态 | 依据 | 本库实现 | 测试 |
| --- | --- | --- | --- | --- |
| 勾选 | 单个 | `Checkbox` | `OhosCheckbox` | |
| 勾选 | 全选组（全选/半选） | `CheckboxGroup`（**子组件：无**） | `OhosCheckboxGroup` | 三态 `All/Part/None` 由 `OhosCheckboxGroupController` 算，半选画**一横**（`Icons.remove_rounded`）而非勾；`Semantics(mixed:)` 单独报半选。官方靠 `group` 字符串隐式配对、文档明写「子组件：无」，硬造「包住就自动分组」会漏算 `ListView` 懒加载项（官方示例 4 本身就在讲这个坑）⇒ 改为显式受控 |
| 开关 | — | `Toggle` | `OhosSwitch` | |
| 单选框 | 圆形 | `Radio` | `OhosRadio` | 容器 24（`radio_container_size`）/ 描边 1（`ohos_id_radio_border_width`）/ 内部图形 0.5 比值（`ohos_id_radio_inner_size_ratio`）。**选中是「实心底板 + 反差图形」**：`RadioStyle` 同时给了 `checkedBackgroundColor`（底板）与 `indicatorColor`（图形）两个默认值，若是旧实现的「空心环 + 品牌色圆点」则前者无处可画。**命中区未按官方加宽**（`hotzone_padding` 14 ⇒ 52）：加宽要么改布局尺寸让调用方按 24 排的间距失效，要么靠 `Stack` 溢出绘制被父级 clip 切掉 |
| 单选框 | 自定义 indicator | `RadioIndicatorType` | `OhosRadioIndicator` + `OhosRadio.indicatorBuilder` | **默认值是 TICK 不是 DOT**：文档开头明写「API version 12 开始，Radio选中默认样式由 DOT 变为 TICK」，沿旧实现当默认会让按新文档写代码的人看到另一套图形。`custom` 没给 builder 时回落 TICK（「indicatorBuilder设置为undefined时，按照 RadioIndicatorType.TICK 进行显示」），否则会画出一个「已选中但空无一物」的实底圆。点已选中项**不回调** —— 单选框没有「取消选中」，旧实现给 `false` 会让一组里一个都不选 |
| 评分条 | 整星 / 半星 | `Rating` | `OhosRatingBar` | |
| 滑动条 | OutSet | `SliderStyle.OutSet` | `OhosSlider` | 轨道 4 / 滑块 16 / 命中区 40（`slider_outset_*`） |
| 滑动条 | InSet | `SliderStyle.InSet` | `OhosSlider(style: inset)` | 轨道 20 / 滑块 12 / 命中区 32；圆角 10 = 轨道粗细的一半 |
| 滑动条 | NONE（无滑块） | `SliderStyle.NONE` | `OhosSlider(style: none)` | `blockSize` 不生效但命中区仍有 40；外层补 `minHeight`，否则父容器按 0 高测量 |
| 滑动条 | 步点显示（showSteps） | `Slider.showSteps` | `OhosSlider(showSteps)` | **必须同时有 `divisions`**：没有步长不知道该在哪画点。`stepSize` 是**直径**（默认 4、范围 `[0, 轨道粗细)`），Material 的 `RoundSliderTickMarkShape` 取的是半径 ⇒ 自写 shape |
| 滑动条 | 前后缀（prefix/suffix） | `Slider.prefix` | `OhosSlider(prefix:)` | 包在固定高 = 命中区的 `SizedBox` + `Center` 里，防大字号把整条顶高 |
| 滑动条 | 有效区间（slideRange） | `Slider.slideRange` | ○ | |
| 选择器 | 滚轮（自定义维度） | `UIPickerComponent` | `OhosWheelPicker` + `OhosPickerColumn` | 行高**固定 40**、最多 7 项、建议高 **200**（=5×40）、文本 **20fp**、子组件对齐固定居中（`align` 不生效）。**少于 8 项无条件不循环**：官方「如果子组件的个数小于8个，无论isLoop设置为true还是false，都不会循环滚动」—— 这是硬条件，不提供覆盖开关。多列靠横向并排多个容器实现 ⇒ 本库显式化为「一列一个 `OhosPickerColumn`」。**不模拟 3D 透视**：官方说「实际可视高度会小于 40vp」（旋转后投影变薄），Flutter 侧要逐项矩阵且与滚动物理耦合，按 5 行落地、「最多 7 项」改为可调 `visibleCount` |
| 选择器 | 时间日期 | `UIPickerComponent` | `OhosTimePicker` / `OhosDatePicker` | **时间**：24 小时制 0–23、12 小时制 **1–12**（含 0 会让 12 小时制出现「00 点」），`second != null` 才有第三列。**不做 AM/PM 列**：官方 `TimePicker` 有独立列，但它需要额外的「上午/下午」状态，调用方拿 0–23 自己换算更直接。**日期**：改年/月时「日」**收敛到当月末**而非进位 —— 3 月 31 日改 2 月得 28/29 日，照搬 `DateTime` 会得到 3 月 3 日。年列 flex 2（年份最长） |
| 选择器 | 月历视图 | `CalendarPicker` | ○ | |
| 色彩选择器 | 网格 / 光谱 / 滑块 | `HdsColorPickerTabType` | `OhosColorPicker` | |
| 色彩选择器 | 收藏（上限 72） | `initialFavoriteColors` / `onFavoriteColorsUpdate` | `OhosColorPicker.favoriteColors` | |
| 色彩选择器 | 不透明度 | 设计规范（组件未提供） | ○ | |
| 色彩选择器 | 屏幕取色 | 设计规范（组件未提供） | ○ | |
| 色彩选择器 | 色值输入 | 设计规范（组件未提供） | ○ | |
| 分段按钮 | tab 型（单选，白背板） | `SegmentButtonOptions.type` | `OhosSegmentedButton(type: tab)` | 选中是**白背板**不是品牌色；`buttons` 类型上没有图标字段 ⇒ 静默忽略 `icon`；`multiply` 在官方源码里写在 `if (type === 'capsule')` 分支内 ⇒ tab 型即使传 `true` 也走单选 |
| 分段按钮 | capsule 单选 | `type: capsule` | `OhosSegmentedButton` | 选中是品牌色药丸（`emphasizeTertiary`），整体圆角 |
| 分段按钮 | capsule 多选（multiply） | `multiply` | `OhosSegmentedButton(multiply: true)` | 底板内边距归 0（单选 2）；**只有首末段有外侧圆角**，中间段 `setLeft/RightCorners(0)` |
| 分段按钮 | 2–5 个按钮限制 | `ItemRestriction` | `OhosSegmentedButton`（构造期断言） | 官方在**类型层面**就是 5 项元组，第 6 项传不进去；本库改为构造期 `assert` 当场报错 —— 「静默截断」会让调用方看到第 6 项凭空消失而没有任何提示。`build` 里的 `SizedBox.shrink()` 只兜 release（release 不执行 assert） |

## 容器类

| 控件 | 官方形态 | 依据 | 本库实现 | 测试 |
| --- | --- | --- | --- | --- |
| 列表 | 平铺 | `List` | `OhosList` | |
| 列表 | 分组 + 组头 / 组尾 builder | `ListItemGroupOptions.header` / `footer` | `OhosListGroup` + `OhosListGroupSliver` | 盒子与 sliver 两形态共用同一行渲染函数；`headerComponent`/`footerComponent`（13+）只是同一形态的另一种传参，不另立行 |
| 列表 | 分组 `space`：只作用于**项与项之间** | `ListItemGroupOptions.space`（默认 0） | `OhosListGroup.space` | 组头→首行、末行→组尾**不受影响**（最易与「给每行加 padding」混淆）；负数按 0；`spaceWidth`（26+）是同一形态的优先版，不另立行 |
| 列表 | 组内分割线（**默认无**） | `ListItemGroup.divider`（默认 `null`） | `OhosGroupDivider` | 与 `OhosList.divider`（默认 `true`）反；组接管后行内 tile 自带那条被压掉 |
| 列表 | 分组卡片（`style: CARD`） | `ListItemGroupStyle.CARD` | `OhosListGroup` / `OhosListGroupSliver` | 左右外边距 **12** + 上下左右内边距 **4** + 圆角 **24**；三个数分处「令牌 / 文档正文 / 令牌」三个来源，复核方式不同（前者可跑 `fetch_sys_resources.sh`，中者只能对文档） |
| 列表 | 项卡片（`itemStyle: CARD`） | `ListItemStyle.CARD` | `OhosListGroupItemStyle.card` | 高 **48**、左右内边距 **8**（只在文档正文，无令牌）；与 `group.style` 是**两个独立参数**，官方示例 2 的四种组合都出现过（`CARD+CARD` / `CARD+NONE` / `NONE+CARD`） |
| 列表 | 吸顶组头（`StickyStyle.Header`） | `StickyStyle.Header` | `OhosListGroupSliver(sticky: header)` | 粒度差异：官方挂在 `List` 上整表一次，本库逐组声明，逐组能表达的集合**严格更大**。**吸顶必须自带背板** —— 官方 `ApplyHeaderFooterStyle`（`list_item_group_pattern.cpp:900`）先补分组圆角再套 `UiMaterialStyle::THICK` 沉浸材质，照文档做会得到一个浮起来却透明的组头 |
| 列表 | 吸底组尾（`StickyStyle.Footer` / `BOTH`） | `StickyStyle.Footer` / `BOTH`（20+） | ○ | `SliverMainAxisGroup` 内部拿不到可靠的视口末端距离：`remainingPaintExtent` 已被同组前面的子 sliver 扣掉、且滑出视口时被夹到 0。留 `○` 而非「多数情况看着对」的实现，用例钉住缺口 |
| 列表 | 组头 / 组尾悬浮（`FLOATING`） | `headerStyle` / `footerStyle`（26.0.0+，默认 `NONE`） | ○ | 与 `sticky` 是两套机制：`sticky` 挂在 List 上管所有组，`FLOATING` 逐组声明 |
| 列表 | 多列布局（`lanes`） | `List.lanes` | ○ | 官方示例 4 用它演示分组在多列下的表现；与分组正交，属 List 层而非组层 |
| 列表 | 主轴尺寸预估 | `ListItemGroup.childrenMainSize`（12+） | — | ArkUI 的 `List` 需预声明子项尺寸才能精确跳转，Flutter 的 `SliverList` 逐项测量，无对应需求 |
| 列表 | 横滑操作 | `HdsListItem` / `SwipeAction` | `OhosListItem` | |
| 列表 | 横滑删除触发类型 | `SwipeDeleteTriggerType`（6.1.0+） | ○ | |
| 列表 | A 区前缀（**7 种**） | `PrefixItem` 一族：`PrefixImage` / `PrefixIcon` / `PrefixBadge` / `PrefixSwitch` / `PrefixToggleButton` / `PrefixButton` / `PrefixCustomBuilder` | `OhosListItemCardPrefix` | `^## Prefix` 共 10 条，扣掉基类 `PrefixItem`、`PrefixIconOptions`、`PrefixIconType` 两个类型定义 —— **上一版写「8 种」是把类型定义当形态数了**。本库收成「一个 Widget 槽位 + 两档尺寸」，理由同「C 区后缀」 |
| 列表卡片 | A 区图标尺寸两档 | `IconSize.SMALL_ICON` / `SYSTEM_ICON` | `OhosListItemCardIconSize` | **16 / 24**，官方明文，也是全篇仅有的两处数字之一（另一处是穿戴设备 `PrefixImage` 固定 46×46，属 wearable 适配，不在本库范围） |
| 列表卡片 | B 区三层文本**并列** | `primaryText` / `secondaryText` / `description` | `title` / `subtitle` / `description` | 三者是并列字段，**不是二选一** —— 官方示意代码三层同时出现。字阶按语义分 `bodyLarge` / `bodySmall` / `bodySmall` |
| 列表卡片 | B 区主标题左右 Symbol | `primaryPrefixSymbol` / `primarySuffixSymbol` | `primaryPrefix` / `primarySuffix` | 官方要求传 `TextSymbolGlyph`，本库收 Widget，`Icon` 也能塞 |
| 列表卡片 | B 区**副 Symbol**（各层左右，共 8 个） | `*PrefixSubSymbol` / `*SuffixSubSymbol` | ○ | 官方写明「仅在左侧第一个 Symbol 存在时才显示」，是给两层图标叠放留的位置；在 16vp 图标旁再叠一个只会挤成一团 |
| 列表卡片 | B 区 `customBuilder` **优先级更高** | `TextItemOptions.customBuilder` | `contentBuilder` | 官方原话「优先级高于其它接口」：给了就整块替换 B 区，三层文本与主标题图标一起让位 |
| 列表 | C 区后缀（**17 种**） | `SuffixItem` 一族：`Text` / `Image` / `LoadingProgress` / `Radio` / `Checkbox` / `Switch` / `Arrow` / `Badge` / `Button` / `Icon` / `SubIcon` / `Select` / `ToggleButton` / `BadgeAndArrow` / `TextAndArrow` / `ArrowIconText` / `CustomBuilder` | `OhosListItemCardSuffix` 9 具名构造器 + `custom` | `^## Suffix` 共 21 条，扣掉基类与 3 个 `*Options` = **17** —— 上一版写「19 种」同样把类型定义数了进去。落地 9 个「有明确形态依据」的，其余 7 个是组合型 / 需 Symbol 字体，用 `custom` 拼 `Row` 更直接 |
| 列表卡片 | C 区后缀最大宽 | **官方无对应属性** | `suffixMaxWidth = 160` | 本库防呆值：防一个长文本后缀把 B 区挤到只剩几像素 |
| 列表卡片 | 卡片高度 / 宽度 | `cardHeight` / `cardWidth` | `height` / `width` | 官方只写「Dimension，不支持 Percentage」，**不给默认值**。本库取 72 —— 这个数不能凭感觉：64 时三层文本溢出 6vp（见 `cardHeight` 的注释） |
| 列表卡片 | 卡片底色 / 圆角 | `cardBackgroundColor` / `cardBorderRadius` | `backgroundColor` / `borderRadius` | 默认卡面色 `cardColor` + 圆角 24（与 `OhosListGroup` 分组卡片同曲率）。墨屏改描边：16 级灰里浅色底板与纸面分不开 |
| 列表卡片 | 左右外边距 | `cardPrefixMargin` / `cardSuffixMargin` | `prefixMargin` / `suffixMargin` | 文档**只说明这两个属性存在、不给默认值**，本库取 12 与 `ohos_id_card_margin_start/end` 对齐 |
| 列表卡片 | 悬浮态圆角 | `hoverBorderRadius` | ○ | Flutter 的点按反馈是水波纹 / `highlightColor`，没有「hover 时单独换圆角」的机制；墨屏还会把波纹退化成拖尾灰块，本库直接关掉 |
| 列表卡片 | 点击回调 | `onClick` | `onTap` | `null` 时无点击反馈，与官方缺省一致 |
| 列表卡片 | 启用开关 | `enable`（默认 `true`） | `enabled` | 禁用时**整块 40% 不透明 + `IgnorePointer`**，而不是逐元素换色 —— 三区分属不同色相，逐个换色会得到一块说不清哪里变了的区域 |
| 列表卡片 | 卡片 Id | `cardId` | — | Flutter 侧用 `Widget.key` 表达同一诉求（稳定身份），语义不同不另立 API |
| 列表卡片 | 无障碍播放 / 组合聚焦（6.1.0+） | `accessibilityOptions`（`isGroup` / `stateControllerId` / `actionControllerId`） | `semanticLabel` + 自动拼接 | 官方 6.1 起会自动把 A/C 区可点元素合成一次播报；本库用 `container: true` + `excludeSemantics: true` 把整行收成一个语义边界，**否则读屏会把拼好的标签与三行原文各念一遍**（实测过） |
| 列表 | 列表项选中态 | `HdsListItem.isSelected`（6.1.0+） | ○ | |
| 列表 | 预览菜单 | `menuStyle` / `menuBuilder`（6.1.0+） | ○ | |
| 弹出框 | Tips | `TipsDialog` | ◐ | |
| 弹出框 | Select | `SelectDialog` | ○ | |
| 弹出框 | Confirm | `ConfirmDialog` | `OhosAlertDialog` | |
| 弹出框 | Alert | `AlertDialog` | `OhosAlertDialog` | |
| 弹出框 | Loading | `LoadingDialog` | ○ | |
| 弹出框 | CustomContent | `CustomContentDialog` | `OhosAlertDialog.contentWidget` | |
| 弹出框 | 自定义容器（圆角/边框/背板）**默认不可改** | `customStyle: false` → 圆角恒 **32vp**，背板色 `Transparent` | `OhosAlertDialog.customStyle` | `false` 时圆角 32（原为自拟的 28）；`true` 时**圆角归 0、背板透明、壳交出去**，不再补墨屏描边 |
| 弹出框 | 宽度上限 **400vp** / 高度上限 `0.9×(窗口高−安全区)` | `width` / `height` 默认最大值 | `OhosDialogMetrics.maxWidth` / `.maxHeightFactor` | 400 是**上限不是固定值**：显式 `width: 800` 会被夹回 400；高度乘的是「窗口高 − 安全区」，PC 上要避让标题栏 |
| 弹出框 | 栅格宽度 `gridCount`（8+） | `gridCount`（默认按窗口自适应） | `OhosAlertDialog.gridCount` | 按断点取 4/8/12 列算列宽；**超界回落到默认路径而不是夹到边界**（官方「异常值按默认值处理」），否则 999 会悄悄变成占满整屏 |
| 弹出框 | 非模态（`isModal: false` 无遮罩、可点周围） | `isModal`（默认 true） | `OhosAlertDialog.isModal` | 直接构造时真非模态；**`showOhosDialog` 里只表达「不画遮罩」**，下层仍被 `ModalBarrier` 挡住 —— 已在 dartdoc 写明两档差异，不假装支持 |
| 弹出框 | 遮罩色/遮罩区域 | `maskColor`（默认 `0x33000000`）/ `maskRect` | `OhosAlertDialog.maskColor` + `showOhosDialog(barrierColor:)` | 20% 黑，与 Material 的 `black54` 差一倍多；`maskRect` 记 `○`（事件透传按区域切开在 Flutter 需自定义 `HitTestBehavior` 分区，收益低） |
| 弹出框 | 子窗口弹出（10+） | `showInSubWindow` / `displayModeInSubWindow` | ○ | 当前只能在本窗口内 |
| 弹出框 | 悬停态（14+） | `enableHoverMode`（默认 false）/ `hoverModeArea` | ○ | 折叠屏半折场景 |
| 弹出框 | 四段生命周期回调（19+） | `onWillAppear`→`onDidAppear`→`onWillDisappear`→`onDidDisappear` | `OhosDialogLifecycle` | 顺序照官方；官方那条「入场动效被打断则 `onDidAppear` 不触发」用「首帧后 `mounted` 仍为真」近似 |
| 弹出框 | 交互式关闭拦截（12+） | `onWillDismiss` + `DismissDialogAction.reason` | `onWillDismiss` + `OhosDismissDialogAction` | **不调 `dismiss()` 就不关**，与 Flutter「返回 false 才拦」相反；`OhosDismissReason` 只产 `pressBack` / `touchOutside` / `closeButton` 三个（`slideDown` / `slide` 官方注明仅半模态可用） |
| 半模态面板 | 底部弹窗（BOTTOM） | `SheetType.BOTTOM` | `showOhosBottomSheet` | 只圆上面两角（官方「底部 2 个圆角即使设置也不生效」） |
| 半模态面板 | 居中弹窗（CENTER） | `SheetType.CENTER` | `showOhosBottomSheet(type: center)` | 实测居中；默认宽 480vp、最小 320vp、最大窗口短边 90%；`LARGE`/`MEDIUM` 无效（恒 560vp） |
| 半模态面板 | 跟手弹窗（POPUP） | `SheetType.POPUP` | `showOhosBottomSheet(type: popup)` | 同一版面板；面板不支持跟手滑动，下滑不关闭 |
| 半模态面板 | 侧边弹窗（SIDE，20+） | `SheetType.SIDE` | `showOhosBottomSheet(type: side)` | 实测靠右、无控制条、高度恒全屏；宽度 md 断点 1/2 窗口，>md 恒 400vp |
| 半模态面板 | 全屏弹窗（CONTENT_COVER，20+） | `SheetType.CONTENT_COVER` | `showOhosBottomSheet(type: contentCover)` | 实测无标题栏/无关闭按钮/无蒙层、宽高恒全屏 |
| 半模态面板 | 多挡位 `detents`（最多 3 挡） | `detents` / `detentSelection` | `OhosSheetDetent` + `OhosSheetSpec.resolveDetent` | `detents` 生效时 `height` 失效（实测取首挡）；速度阈值 1000px/s、距离阈值 1/2；`SIDE`/`CONTENT_COVER` 忽略 |
| 半模态面板 | 宽度响应式默认形态 | `preferType` | `OhosSheetSpec.defaultTypeFor` | <600vp 默认 BOTTOM；600–840 默认 CENTER；≥840 默认 POPUP |

---

## 统计

| 状态 | 数量 |
| --- | --- |
| 完整（本库实现列只写类名、不加符号） | 204 |
| `◐` 部分实现 | 4 |
| `○` 缺失 | 44 |
| `●` 有意偏离官方（偏离理由写在备注列） | 2 |
| `—` 无需实现（平台能力差异） | 2 |
| 数据行合计 | 256 |

复核方式（改完矩阵请重跑，别手抄数字）：

```zsh
awk '/^## 统计/{exit} /^\| / && !/^\| 控件 / && !/^\| --- /' doc/CONTROL-MATRIX.md > /tmp/rows.txt
grep -c . /tmp/rows.txt                      # 合计
awk -F'|' '{s=$5; gsub(/^ +| +$/,"",s); print s}' /tmp/rows.txt \
  | awk '{ if ($0 ~ /^○/) print "○"; else if ($0 ~ /^◐/) print "◐"; else if ($0 ~ /^●/) print "●"; else if ($0 ~ /^—/) print "—"; else print "完整" }' \
  | sort | uniq -c | sort -k2                # 五种状态一次数清
```

**别在这条管道里加 `sed -n '3,$p'` 之类的跳行。** 表头两行已经被 `!/^\| 控件 /` 与 `!/^\| --- /` 滤掉了，
再跳 3 行就是丢掉矩阵**前 2 行数据**。这个 bug 曾经存在过一版：合计 175、各类和 173，
看起来像「有一行状态写成了 `—`」，实际是管道少了两行、同时另有一行状态异常，两个错误互相掩盖。
**每次都要把四类相加与 `grep -c .` 对一次，差值非 0 就是管道或符号有问题，不是数据。**

> **不要写死行号**（`NR<190` 之类）。本轮吃过一次：先用 `NR<180` 数出 139 行，随后新增 7 行半模态 + 5 行子页签，命令没改，数字当场错 12 行。上面的写法以 `## 统计` 为终点，加多少行都不会漂。
>
> **也别用 `grep -c '○'` 数缺失**：`grep` 是按**整行**匹配，一行里同时出现 `○` 与 `◐`（备注文字里提到过）会被重复计入。用 `-F'|'` 单独取「本库实现」列再分类，才是准的。
>
> **最后一个坑：`else` 兜底必须指向「完整」，不能指向某个符号。** 上一版命令写的是
> `if($0=="")print "完整"; else if(~/^○/)... else if(~/^◐/)... else if(~/^●/)...`，
> 而「完整」行的实现列里**有内容**（就一个类名，如 `` `OhosButton` ``），`$0==""` 永远不成立，
> 于是 62 行完整项全部落到四个分支之外、被 `awk` 静默丢弃 —— 输出只剩 111 行。
> 那次「57 / 15 / 100 / 2 合计 174」里的 57 是**扣出来的**（174−15−100−2），不是数出来的；
> 真实值是 62，而 `◐` 也不是 15 而是 9（本轮把搜索框 3 行、芯片 3 行的偏差修掉后少了 6）。
> 教训：**统计命令也要验证「各类之和 == 行数」**，别只看某一类的值像不像。
>
> **本版：158 / 7 / 72 / 2 / 2，合计 241。** 相对上一版 227：列表卡片 `HdsListItemCard` 由 **2 行拆成 16 行**（+14）。那两行（「A 区前缀（8 种）」「C 区后缀（19 种）」）**不是转完整，是原数字就错** —— 见下面 ①。拆完的账：原 2 行 `○` 转完整（完整 +2、`○` −2），新增 14 行里 **11 行完整** + **2 行 `○`**（副 Symbol、`hoverBorderRadius`）+ **1 行 `—`**（`cardId`）。合计：完整 `145 + 2 + 11 = 158`、`○` `72 − 2 + 2 = 72`、`—` `1 + 1 = 2`、行数 `227 + 14 = 241`；`158 + 7 + 72 + 2 + 2 = 241` ✓（命令连跑三次一致）。
>
> 这一批只有一处判断来自文档，其余全是**「文档沉默」**，值得单独记：
> ① **上一版「8 种 / 19 种」两个数字都是错的，而且错法相同**：把 `*Options` / `*Type` 这些**类型定义**也当成了形态。`^## Prefix` 清点得 10 条，扣掉基类 `PrefixItem`、`PrefixIconOptions`、`PrefixIconType` 是 **7**；`^## Suffix` 得 21 条，扣掉基类与 3 个 `*Options` 是 **17**。这条与仓库里已有的「别猜名字」是同一族错误 —— 那次是「按目录名推文件名」，这次是「按章节标题数列形态」。**清点必须逐条读定义句（「定义 Xxx 类，A 区…元素」），不能只数标题。**
> ② **HDS 组件在资源表里查无此物**：`pattern.json` / `float_sys.json` / `float.json` 三张表搜 `list_item_card` / `listitem` / `hds` **全部零命中**。这与 `OhosListGroup` 那批（12/4/24 大多能指到令牌）是**相反的情形**：HDS 是闭源组件，几何不走资源令牌。全篇 1944 行只给了两处数字 —— `IconSize` 的 16 / 24，以及穿戴设备 `PrefixImage` 固定 46×46。所以 `OhosListItemCardMetrics` 里除这两个之外**每一个值都必须标注「文档未给，自拟」**，不能让后人误以为是官方默认值。
> ③ **`cardHeight` 取 64 是错的，实测溢出 6vp**。这是「照抄常量前先算」的第二次翻车：`bodyLarge` = 16×1.5 = 24、`bodySmall` = 14×1.5 = 21，三层 + 两个 2vp 间距 = **70**，而 64 只够两行。算错的原因是把**字号当成了行高**。改用 72（70 + 2 呼吸），并加了一条用例钉住「三层同时出现不溢出」。
> ④ **无障碍标签会念两遍**。`Semantics(label: ...)` 默认不是语义边界，实测节点标签是 `无线网络，已连接，信号强\n无线网络\n已连接\n信号强` —— 拼好的那句后面跟着三条子节点原文。加 `container: true` + `excludeSemantics: true` 才收成一个边界。官方 `accessibilityOptions` 的 `isGroup` 做的就是这件事，文档只说「组合聚焦播报」，没说「不加就会重复」。
>
> 一处**主动放弃**：**副 Symbol（8 个字段）标 `○`**。官方写明「仅在左侧第一个 Symbol 存在时才显示」，用途是两层图标叠放；本库主标题旁的图标只有 16vp，再叠一个必然挤成一团。**A 区 7 种 / C 区 17 种也没有逐一照搬成 7 + 17 个类**：ArkTS 单字段单类型才需要那么多子类，Flutter 的 `Widget` 本身就是共同类型，照搬只会得到一堆只装一个 Widget 的空壳。收成 `Prefix(child, size)` + `Suffix` 具名构造器（9 种，每种**强制**收自己需要的内容），`custom` 兜住其余组合型。
>
> **本版：168 / 7 / 69 / 2 / 2，合计 248。** 相对上一版 241：输入类 `OhosTextField` 由 **7 行拆成 14 行**（+7）。原 7 行里「内联 / 密码 / 计数器」三行是 `○`，本版全部转完整；新增的 7 行全部为完整，`●` 数量不变（2）。账：完整 `158 + 3 + 7 = 168`、`○` `72 − 3 = 69`、行数 `241 + 7 = 248`；`168 + 7 + 69 + 2 + 2 = 248` ✓（命令连跑三次一致）。
>
> 这一批最重要的是**把「令牌有值」和「令牌生效」分开验了**，结果发现自己踩的正是这个坑：
> ① **填充形态实测渲染 52vp，官方 40**。`contentPadding` 是早前自拟的 `14/14`，而 `textfield_padding_horizontal/vertical` 的令牌值 16/8 从来没接上 —— 8 + 24 + 8 = 40 才对。改回令牌后仍不对（48），挖出第二层原因：`InputDecorator` 在 `isDense == false` 时把容器高夹到 `kMinInteractiveDimension`(48) 以上，**40 的规格被无障碍兜底无条件覆盖**。要拿到 40 必须显式开 `isDense`。这两层任何一层没查出来，都会得出「官方 40 做不到」的错误结论。
> ② **`border_radius_size`(12) 是死令牌，`textfield_border_radius`(20) 才是容器圆角**。先前按名字猜成「12 是容器、20 是别的」，实测两个都对不上（代码里用的是主题的 `radiusMedium` = 16）。去读源码才定论：`text_field_pattern.cpp` 里 `auto radius = theme->GetBorderRadius();` 后面紧跟 `IsUnderlineMode() ? ZERO_BORDER_RADIUS_PROPERTY : borderRadius` —— 非下划线用 `textfield_border_radius`，下划线显式归零；而 `GetBorderRadiusSize()` 在整个 `text_field/` 目录**零调用方**。这与搜索框的 `search_text_field_padding_left` 是同一类：**表里有、没人读**。
> ③ **密码形态的 48 不随底板变化**。`password_style_height` 是独立的容器高，只在「内边距恰好算成 48」的下划线形态上碰巧成立；填充底板上按内边距算是 40，必须单独加最小高度约束才符合官方。
> ④ **本轮 7 条新用例全部量真实渲染尺寸**（`tester.getSize` / `decoration.isDense` / `errorBorder.width`），而不是像原来那条「几何令牌逐条可查」只断言常量字面值 —— 后者在 52vp 偏差存在时**依然全绿**，正是「常量写对了 ≠ 常量被用上了」。`textfield_error_spacing`(8) 这条路走不通（Flutter 侧是 `InputDecorator.subtextGap`，M3 写死 4、无 decoration 级入口），已明写「未接」而非假装实现。
>
> **本版：193 / 4 / 52 / 2 / 2，合计 253。** 相对上一版 189 / 4 / 54 / 2 / 2：底部页签由 **4 行改写成 6 行**（+2）。逐条对：「三档宽度」「渐变蒙层」两行由 `○` 转完整（`○` −2、完整 +2）；新增 2 行都是完整（`barSideMargin` 三档边距、悬浮栏 56vp 栏高）；迷你栏两行仍 `○`。账：完整 `189 + 2 + 2 = 193`、`○` `54 − 2 = 52`、行数 `251 + 2 = 253`；`193 + 4 + 52 + 2 + 2 = 253` ✓（命令连跑两次一致）。
>
> 这一版最值得记的是**一个归属错误，它改变了整项的落点**。三档宽度、`gradientMask`、迷你栏这三项原本都排进了「往 `OhosTabBar` 上加参数」，实际它们全部挂在 `barFloatingStyle` 之下 —— 也就是说描述的是**悬浮页签栏**这个本库此前没有的形态，而平铺栏的 `barWidth` 是单个 `Length`，与三档无关。证据是「只被谁引用」：`HdsBarWidthRangeOptions` 全文只出现在 `HdsTabsFloatingStyle.barWidth` 与 `HdsTabsMiniBar.miniBarWidth` 两处。**上一版是「都是 tabs 家族的，所以算在已有组件头上」——按类名归类，而不是按属性找宿主。**
>
> 同时纠正了上一版的一处「更正」：`gradientMask` 的默认值（`#CCF1F3F5` / `#99000000`，栏高 + 16vp）**本来就是对的**。上一版把它改成 `#CCFFFFFF` / `#CC000000` / +32vp，那是另一个 API `barBackgroundStyle` 的值。两者共用 `HdsTabsBackgroundStyle` 类型，但**按属性读默认值，不能按类型读** —— 同名类型被多处引用时，把一处默认值套到另一处，看起来像「查过文档」，实际是抹掉了一个真实存在的项。
>
> 规矩：**先跑命令，再拿命令输出反推逐条，推不通就说明有一行的归属判断错了**。本版第一次手推得到 `189 / 4 / 53`，与命令的 `54` 差 1，追下去发现「逐按钮阴影」被写在了合并行里记为完整 —— 它其实没做（`ShadowStyle.OUTER_DEFAULT_LG` 只有枚举名和序号 3，没有数值表），拆出来单独记 `○` 才对。
>
> 这段对账刻意保留了「先手推、再以命令为准」的过程，因为**手推账与命令输出不一致是常态而不是意外**——只要矩阵动过行，手推就会漏掉「一行拆两行」这种结构变化。规矩是：**先跑命令，再拿命令的输出反推逐条，推不通就说明有一行的归属判断错了**。上一版（操作栏那次）第一次手推得到 `189 / 4 / 53`，与命令的 `54` 差 1，追下去发现「阴影未做」那行被我写成完整（记在了合并行里）—— 拆出来单独记 `○` 才对，改完两边一致。
>
> **本版：204 / 4 / 44 / 2 / 2，合计 256。** 相对上一轮 198 / 4 / 50 / 2 / 2：半模态面板 6 行 `○` 转完整（`○` −6、完整 +6），行数不变。`204 + 4 + 44 + 2 + 2 = 256` ✓（命令连跑两次一致）。
>
> 这一版最该记住的是**「5 种形态」不是 5 种皮肤，而是 5 套能力矩阵**。上一版只有 BOTTOM 一种、且把「画什么」写死在渲染里（顶部一条描边、无条件画控制条、标题栏必出、圆角固定 `BorderRadius.vertical(top:)`）。加形态时若只换对齐方式，会在这四处同时出错：
>
> | 形态 | 圆角 | 蒙层 | 标题/关闭 | 控制条 | 挡位 | 宽高 |
> | --- | --- | --- | --- | --- | --- | --- |
> | BOTTOM | 仅上面两角 | 有 | 有 | 有 | 有 | 内容高 |
> | CENTER | 四角 | 有 | 有 | 有 | 有 | 480 宽 / 夹取高 |
> | POPUP | 四角 | 有 | 有 | 有 | 有 | 同上 |
> | SIDE | 四角 | 有 | 有 | **无** | **无** | 固定宽 / 全屏高 |
> | CONTENT_COVER | **无** | **无** | **无** | **无** | **无** | 全屏 |
>
> 三条容易写的判据：①**CENTER / POPUP 下 `MEDIUM`/`LARGE` 无效、恒 560vp**（写成「按 60% / 100% 算」看起来更合理，实际是错的）；②**挡位切换是速度优先**——速度过 1000px/s 直接按手速方向切挡、**不看距离**，写成「两个条件都要满足」会让快速轻扫失效；③`detents` 生效时 **`height` 直接失效**，不是「两者取小」。
>
> 另修一处真实偏差：圆角原实现是 **24vp**，官方 `SheetOptions.radius` 默认 **32vp**。24 是 `float.json` 里 `ohos_id_corner_radius_dialog`（**对话框**圆角）的值 —— 同一个「圆角」概念、数值都在 20–30 区间，拿错一个看起来完全合理。
>
> 上一轮记录（底部页签）：「折叠 / 展开」与「滚动联动」是两套机制，别合并成一个状态机 —— 前者是离散跳变（动效只是附庸），后者是连续位置（绑内容区滚动体，与折叠状态无关）。`bindScroller` 只挂只读监听、绝不 `hold()`（曾写成 `scroller.position.hold()`，会让内容区滚动卡住不动）；`applyMiniBarStyle` 状态没变时不通知；动效时长走 `policy.scaleMotion`，墨水屏返回 `Duration.zero` 直接定格。
>
> 这一版最该记住的是**官方在 440vp 处换了居中口径**，两条规则长得几乎一样、结论相反：
>
> > * 宽度 **小于 440vp**，且一展一折 →「页签栏和迷你栏将**整体**底部居中显示」
> > * 宽度 **440–600vp**，且一展一折 →「**展开的**页签栏或迷你栏将底部居中显示」
>
> 读快一点就会把两条并成「都居中」，而它们的差别是**折叠者跟着走还是贴边**。已抽成纯函数 `OhosMiniBar.alignFor` 单独守（4 条用例），不塞进布局里 —— 塞进布局就只能靠量像素反推，看不出是哪条规则错了。
>
> 另有两个真实缺陷只有**真跑布局**才暴露：① 440–600vp 用 `Row + Spacer` 让折叠者占掉了流式布局的空间，展开者中心被推偏 28vp，「居中」在这里必须相对**容器**而不是相对兄弟节点；② 两个栏宽度各自独立算出，**合计可能超容器**（320vp 屏上 `200 + 8 + 220 = 428`），`Row` 不折行、静态分析不报错，example 溢出矩阵直接报 `RenderFlex overflowed by 68 pixels`。
>
> 上一版最该记住的是**「文档列了属性」与「文档给了数值」是两件事**。`HdsActionBar` 有 293 行参考文档、`ActionBarButton` 更列了 17 个属性，但**一个默认值数值都没有**；三张系统资源表（`pattern.json` / `float_sys.json` / `float.json`）搜 `actionbar` / `action_bar` **全部零命中**，连 `hds` 前缀都一个不存在；设计规范 `component_actionbar` 只有定性描述（「悬浮于页面底部」「默认带有模糊材质和投影」）。这与 `OhosListGroup`（12 / 4 / 24 大多能指到令牌）是**相反的情形**，与 `OhosListItemCard` 相同 —— 所以 `OhosActionBarMetrics` 里每个数都单独标了「自拟」，不能让后人误以为是官方默认值转述。**悬浮页签栏与迷你栏同型**：`minibar` / `mini_bar` / `hds` 在三张资源表里**零命中**（`floating` 有 18 条，但全是 `ohos_id_shadow_floating_sm_*` 这类通用阴影，与页签栏无关），迷你栏折叠态宽度 56 是**自拟** —— 官方只给了展开态的分档宽度（`miniBarWidth`），折叠态全文未给。
>
> 另有两处**靠文档正文而不是靠直觉**定下来的语义：① `startSpace` / `endSpace` 的说明里明写「水平排列时为左边框，竖直排列时为上边框」，所以竖直排列要把它们映射到 `top` / `bottom` —— 按名字固定成 left/right 是个很容易犯、且视觉上不易察觉的错。② `enabled` 是**总开关**而非背板开关，官方原文「`enabled=false` 则背板不启用并且所有按钮都不启用；`enabled=true` 时每个按钮可以单独设置」。两处都写了用例。
>
> 还有一个**因祸得福的发现**：改完操作栏跑 `example` 的溢出矩阵，`container` 页整片变红，报「Vertical viewport was given unbounded height」。根因不是操作栏 —— 是上一版（D-4/D-5）往 `container_page` 加的 `OhosListItemCardList`：它内部是 `ListView`，而 `DemoScaffold` 本身就是纵向 `ListView`，两个纵向视口嵌套。`shrinkWrap` 参数本来就有（默认 `false`），example 里没传。**上一版改完 example 没跑溢出矩阵**，这个错误被漏了整整一轮 —— 与「`flutter analyze` 看不见布局问题」是同一条教训的第三次出现。本次已补 `shrinkWrap: true` + `NeverScrollableScrollPhysics`。
>
> **上一版：175 / 7 / 62 / 2 / 2，合计 248。** 相对上一版 168 / 7 / 69 / 2 / 2：弹出框 7 行由 `○` 转完整（圆角/背板、宽高上限、`gridCount`、`isModal`、遮罩色、四段生命周期、`onWillDismiss`），行数不变、`○` 减 7、完整加 7。账：`168 + 7 = 175`、`69 − 7 = 62`、行数仍 248；`175 + 7 + 62 + 2 + 2 = 248` ✓（命令连跑三次一致）。
>
> 这一批有一条**实现 bug 是被测试抓出来的**，值得单独记：`Center(child: Stack(...))` 里的 `Positioned.fill` 遮罩**不会铺满全屏** —— `Center` 给子节点的是松约束，`Stack` 会收缩到弹窗那么大，于是「全屏遮罩」实际只有弹窗大小，点弹窗外面根本命中不到它。实测 `Positioned.fill` 那层量出来是 **179×124**（弹窗尺寸），不是 400×800。修法是外面套 `SizedBox.expand`。这个偏差 `flutter analyze` 完全看不出、静态阅读代码也很难发现——只有「点遮罩应该关」这条用例跑起来才暴露。
>
> 另有三处**测试自身写错了**，一并记下以免后人重犯：
> ① **量错了对象**。第一版断言 `tester.getSize(find.byType(OhosAlertDialog)).width ≤ 400`，而根节点为了居中铺满整个约束（`Center`），量出来永远等于窗口宽 —— 断言恒真，是**假绿**。真实壳是那层 `ClipRRect`，改成量它才测得到东西。
> ② **`setSurfaceSize` 不改 `MediaQuery`**。栅格用例设了 400×800 渲染面，但 `MediaQuery.sizeOf` 读到的仍是默认 **800×600**，于是断点判成 medium（8 列）、算出 179 而不是 180。栅格宽度是**按窗口宽算的**，窗口宽喂错，「碰巧接近」的断言证明不了公式对。改成同时设 `tester.view.physicalSize`。
> ③ **嵌入式构造测不了路由关闭**。`onWillDismiss` 的 `dismiss()` 放行后由弹窗调 `Navigator.maybePop` 完成关闭，而嵌入式构造（只是 `Center` 里的一个 widget）没有可 pop 的路由 —— 那种场景下「关闭」得由持有它的父级负责。改用 `showOhosDialog` 才是这条链路的真实场景。
>
> **本版用例 649 条**（上版 617，+32：半模态形态规格 15 条 + 形态渲染 7 条 + 阶段 E 控制器与滚动联动 10 条）。

> **本版用例 570 条**（上版 555，+15：`OhosAlertDialog`）。
>
> **本版用例 555 条**（上版 548，+7：填充/胶囊实测高度 1 + 下划线实测高度 1 + 密码跨底板 1 + 容器圆角 1 + 错误描边 1 + 错误字号 1 + `isDense` 1）。
>
> **本版用例 524 条**（上版 491，+33：`OhosListItemCard` 29 + `OhosListItemCardList` 4）。
>
> **上一版：145 / 7 / 72 / 2 / 1，合计 227。** 相对上一版 219：容器类的「列表」由 **4 行拆成 11 行**（+7，另「平铺」与「横滑操作」原样保留）。逐条对：原「分组卡片（CARD）」「吸顶组头」两行 `○` 全部转完整，「列表项选中态」等四行未动；新增 7 行中 **6 行完整**（组头/组尾 builder、`space`、组内分割线、组卡片、项卡片、吸顶组头）、**1 行 `○`**（吸底组尾）、**1 行 `—`**（`childrenMainSize` 在 Flutter 无对应需求）。合计：完整 `139 + 6 = 145`、`○` `71 + 1 = 72`、`—` `0 + 1 = 1`、行数 `219 + 8 = 227`；`145 + 7 + 72 + 2 + 1 = 227` ✓（命令连跑两次一致）。
>
> 这一批的三处判断值得记下来，因为它们都是「照文档做会错」：
> ① **`sticky` 是 `List` 的属性，不是 `ListItemGroup` 的**。它写在 `ts-container-list.md` 的 `List` 属性章节，`StickyStyle` 枚举也在那一页 —— 这不是文档排版失误，是规格事实：一次管住列表内所有分组。据此把组件拆成 `OhosListGroup`（盒子）与 `OhosListGroupSliver`（sliver）两个类，`sticky` **只出现在后者**。盒子形态根本无处可吸（吸顶是 sliver 行为），传了会得到一个「传了但没反应」的开关，那比不支持更坏。粒度上本库逐组声明，官方整表一次 —— 逐组能表达的集合严格更大（每组可各选吸顶或不吸）。
> ② **吸顶组头必须自带背板，而文档完全没提这件事**。`PinnedHeaderSliver` 只负责钉住、不负责遮挡，照文档做会得到一个浮起来却透明的组头，下面的行从它身上穿过去。真实规格在源码：`ListItemGroupPattern::ApplyHeaderFooterStyle`（`list_item_group_pattern.cpp:900`）先 `UpdateBorderRadius(GetItemGroupDefaultBorderRadius())` 补分组圆角，再套 `UiMaterial::IMMERSIVE / THICK` 沉浸材质 —— 本库对应 `OhosLightMaterial(level: thick)`。这类「文档只讲交互、不讲视觉」的缺口，四层对照里只有第四层能补。
> ③ **卡片样式的 12 / 4 / 24 三个数分处三个来源**，复核方式因此不同：`cardMargin = 12` 走资源表（`ohos_id_card_margin_start/_end`，`list_item_pattern.item_margin_left/right` 指向它，`float.json` 两值都是 `12.0vp`）；`cardPadding = 4` **只在文档正文**（「卡片样式下…上下左右内边距 4vp」），资源表无令牌；`cardRadius = 24` 走 `list_item_pattern.item_border_radius → ohos_id_corner_radius_default_l`（`24.0vp`）。行级 CARD 的 **48 / 8** 同样只在文档正文（「高度 48vp、宽 100%、左右内边距 8vp」）—— 所以这五个数里只有三个能用 `fetch_sys_resources.sh` 复跑，另外两个只能对文档。
>
> 一处**主动放弃**，理由写在这里免得下次又被当成遗漏：**吸底组尾（`Footer` / `BOTH`）标 `○`**。实现了，但不可靠 —— `SliverMainAxisGroup` 内部拿不到可靠的视口末端距离：`remainingPaintExtent` 已被同组前面的子 sliver 扣掉、且滑出视口时被夹到 0，「组尾原来在视口下方多少」这条关键信息恰好在需要它时丢失；改用 `precedingScrollExtent` 与视口滚动量之差方向是对的，但分组内部同样拿不到视口自己的滚动量，仍然是在猜。留 `○` + 一条钉住缺口的用例（组尾应 `findsNothing`：它落在视口外根本没被构建 —— 真吸底了就一定被构建），好过留一个「多数情况看着对、滚到某些位置就错位」的实现。
>
> **本版用例 491 条**（上版 471，+20：`OhosListGroup` 13 + `OhosListGroupSliver` 7）。
>
> **上一版：139 / 7 / 71 / 2，合计 219。** 相对上一版 207：进度条与加载动效由 **6 行拆成 18 行**（+12），其中 4 行 `○` 全部转完整、另新增 12 行完整 —— 合计：完整 `123 + 16 = 139`、`○` `75 − 4 = 71`、行数 `207 + 12 = 219`；`139 + 7 + 71 + 2 = 219` ✓（命令连跑两次一致）。
>
> 这一批的难点全在**第四层（源码）**，文档三句话说不清三种几何：
> ① **五种形态不是五种涂装，是三种度量**。线性/胶囊量**长度**、环/刻度环量**角度**、月相（Eclipse）量**面积**。把月相当扇形画（「从 -90° 扫 value×360°」）三档端点会全错 —— 实测 `Path.contains` 采样：`0 → 0,0,0,0,0`、`0.5 → 1,1,0,0,0`（**整个左半圆**，不是零也不是一半）、`1 → 1,1,1,1,0`。源码 `PaintMoon` 是「左半圆 + 一条宽度随 value 变的椭圆弧」走非零环绕，`value ≤ 0.5` 时椭圆弧**逆时针**（与左半圆反向 ⇒ 相减出月牙）、`> 0.5` 时顺时针（同向 ⇒ 相加补右半圆）。
> ② **刻度环的进度靠换色，不靠刻度变多**。源码先整圈用背景色画 120 个刻度，再用前景色覆盖前 `angle` 弧度那一段。照「沿长度填色」的直觉做会画出一条越来越长的弧 —— 这是这批里最容易做反的一条，用例直接钉「刻度数恒为 120，只有颜色分段变化」。
> ③ **`77vp` 这个看着像随手取的数，是 `scaleCount` 上界的反解**。刻度数按键值范围 `[2, min(w,h)/scaleWidth/2/π]`；直径 72（半径 36）+ 120 刻度 + 宽 2 ⇒ 间距 1.88 < 2 ⇒ 退化；77（半径 38.5）⇒ 2.02 > 2 ⇒ 正好越过临界。用例把 36 / 38.5 两个半径的判定都钉住了。
>
> 两个陷阱记一下：**`DEFAULT_CAPSULE_BORDER_WIDTH = 0.0` 与 `progress_border_width = 1vp` 同名反值** —— 前者是绘制函数形参的兜底，后者才是进到组件里的主题令牌，照前者写会少一圈内描边。**`Path.getBounds()` 不能量填充面积**，它把弧的控制点也算进包围盒，于是 `eclipse(0)` 与 `eclipse(0.25)` 给出同一个矩形 —— 必须用 `Path.contains` 采样。
>
> **本版用例 471 条**（上版 444，+27：进度条 21 + 加载动效 6）。
>
> **上一版：123 / 7 / 75 / 2，合计 207。** 行数不变，11 行由 `○` 转完整 —— **阶段 C 全部完成**（分段按钮 4 行 + 滑动条 4 行 + 勾选组 1 行 + 单选框 2 行 + 选择器 2 行 − 2 行本已完整）。`123 + 7 + 75 + 2 = 207` ✓（命令连跑两次一致）。
>
> 那一批有五处「文档/框架说的和字面意思不一致」，都逐条验证过：
> ① **`stepSize` 是直径不是半径**。Material 的 `RoundSliderTickMarkShape` 半径取 `trackHeight/4`，照抄会差一个 2 倍；官方 `stepSize` 默认 `4vp`、范围 `[0, trackThickness)`（`0` 不显示、负数取默认、超轨道粗细回夹）。自写 `_OhosTickMarkShape` 直接画，少一次除法就少一个错。
> ② **`SegmentedButton` 的 tab 型与 capsule 型差别是结构性的，不是视觉开关**。官方的 `multiply` 写在 `if (this.type === 'capsule')` 分支内，tab 型传了也白传；且 tab 型 `buttons` 的类型（`ItemRestriction<SegmentButtonTextItem>`）上**没有图标字段**。
> ③ **`CheckboxGroup` 官方文档明写「子组件：无」**，靠 `group` 字符串隐式配对。硬造「包住就自动分组」会漏算 `ListView` 懒加载项（官方示例 4 讲的正是这个坑），所以改为显式受控（`Controller` + `Scope`）。
> ④ **`Radio` 的默认选中图形在 API 12 已由 `DOT` 换成 `TICK`**。而且 `RadioStyle` 同时给了 `checkedBackgroundColor`（底板）与 `indicatorColor`（图形）两个默认值 —— 这是「选中态是实心底板 + 反差图形」而非「空心环 + 品牌圆点」的结构性证据，旧实现两者都不是。
> ⑤ **`UIPickerComponent` 的「7 项 / 200vp」不矛盾**：文档说「实际可视高度会小于 40vp」（非选中项按角度旋转、投影变薄），所以 7 × 40 = 280 可以落在 200 里。本库不模拟透视，按 5 行落地，「最多 7 项」改为可调 `visibleCount` —— 这是唯一一处**有意偏离**（写进代码 dartdoc，不进矩阵 `●`，因为偏的是渲染手法而非规格值）。
>
> **本版用例 444 条**（上版 365，+79：分段按钮 13 + 滑动条 8 + 勾选组 24 + 单选框 11 + 选择器 23）。
>
> **上一版：112 / 7 / 86 / 2，合计 207。** 相对 205：文本选择菜单由 **2 行拆成 4 行**（+2），四行全部完整 —— 原 2 行均为 `○`，本版补上实现并新增「容器几何」「默认开模糊」两行。合计：完整 `108 + 4 = 112`、`○` `88 − 2 = 86`、行数 `205 + 2 = 207`；`112 + 7 + 86 + 2 = 207` ✓（命令连跑两次一致）。
>
> 这一批的实现有一处**框架行为必须先查清才能写测试**：`EditableText.getEditableButtonItems` 在 Android 上把 `share` 塞在 `selectAll` **前面**，原始序列是 `cut/copy/paste/share/selectAll`；而 `clipboardStatus == unknown` 时整个列表会是空的（「don't render anything until the state of the clipboard is known」）。所以「固定四项顺序」这条用例若不模拟剪贴板，会连粘贴项都看不到，测试变成**假绿**。
>
> **上一版（108 / 7 / 88 / 2 = 205）**相对再上一版（91 / 7 / 93 / 2 = 193）：数据可视化由 **5 行拆成 17 行**（+12）。逐条对：原 5 行全为 `○`，其中「进度形（环形）」「进度形（线形）」「占比形」「范围形（Gauge）」四行被拆细并转为完整，「线形数据条（4vp 圆角）」一行保留但转为完整。新增的 12 行里 **12 行完整、0 行 `○`** —— 这一批全部有实现。合计：完整 `91 + 17 = 108`、`○` `93 − 5 = 88`、行数 `193 + 12 = 205`；`108 + 7 + 88 + 2 = 205` ✓（命令连跑两次一致）。
>
> **这一版还有一处命名纠正，不是实现退步**：`OhosDataPanel` 原本是 KPI 卡片网格，与 ArkUI 的 `DataPanel`（占比图）**语义完全不同** —— 前者在本表里从来没有对应行，后者一直没有实现。名字还给占比图后，卡片网格改名 `OhosStatGrid`（视觉不变）。所以矩阵里「数据可视化」整块是**新写的代码**，不是把旧实现重新归了类。

> **上一版（91 / 7 / 93 / 2 = 193）**相对再上一版（85 / 7 / 92 / 2 = 186）：数字加减由 **2 行拆成 9 行**（+7）。逐条对：原「日期」行由 `○` 转完整（`OhosDateCounter` + `OhosDate`）→ 完整 +1、`○` −1；新增 7 行中 **5 行完整**（容器几何、三种回绕、换月收敛、段内输入、聚焦底色反转）、**2 行 `○`**（长按连续加减、列表型 / 紧凑型 / 数字内联型三种形态）。合计：完整 `85 + 1 + 5 = 91`、`○` `92 − 1 + 2 = 93`、行数 `186 + 7 = 193`；`91 + 7 + 93 + 2 = 193` ✓（命令连跑两次一致）。
>
> **同时更正上一版的一处表述**：上一版「日期（DateStyle）」那行的依据写的是 `CounterType` —— `CounterType` 是类型枚举本身，不是形态；真正的日期形态是 `CounterType.INLINE_DATE` + `DateStyleOptions`，本版已写清。
>
> 上一版（85 / 7 / 92 / 2 = 186）相对再上一版（83 / 7 / 89 / 2 = 181）：导航点由 3 行拆成 8 行，其中「数字」「箭头」两行由 `○` 转完整，另新增 3 行记 `○`（超长显示、蒙版、任意位置）。逐条对：`83 + 2 = 85` 完整、`89 + 3 = 92` `○`、`181 + 5 = 186` 行；`85 + 7 + 92 + 2 = 186` ✓。
>
> 上一版（83 / 7 / 89 / 2 = 181）相对再上一版（78 / 7 / 88 / 2 = 175）：工具栏由 2 行拆成 8 行，5 行转完整、2 行记 `○`、1 行沿用原完整行。
>
> **同时修掉复核命令的一个陈旧 bug**：上一版写的分类管道前面多了 `sed -n '3,$p'`，而表头两行**已经被 `!/^\| 控件 /` 与 `!/^\| --- /` 滤掉了** —— 那一步等于把矩阵前 2 行数据一起丢掉，合计与各类各自看都像对的，加起来却差 2。**统计命令本身也要验和**，这条与上面那条是同一个教训的第二次出现。

**关于「测试」列**：目前只有 `OhosActionBar`、子标题、工具栏、导航点、日期加减、文本选择菜单与数据可视化那几行填了用例名，其余为空。这不是「没测试」——仓库有 **365** 条用例，只是还没有人把「哪个用例守住哪个形态」逐行填上。按本文件开头的定义，空着就算未完成：**这条列空着时，「覆盖」仍然只是实现层面的声明，不是回归保护。**

**「依据」列的四种确定性不同，别混着读：**

| 依据写法 | 含义 | 确定性 |
| --- | --- | --- |
| `Hds*` / `ts-*` 等组件名 | 有组件级参考文档，属性与默认值可查 | 高 |
| **令牌名**（如 `search_default_height`） | 数值来自**系统资源表**：`pattern.json` → `float_sys.json` → `float.json`，`tool/fetch_sys_resources.sh` 可复跑 | **最高 —— 这是构建 `resources.index` 的源文件本身** |
| 「设计规范」 | 只有 UX 页描述，没有对应组件文档 | 中 |
| 直接写数值（如双行 **72**） | 来自**实现源码**的硬编码常量（`tool/fetch_source.sh`），文档只给令牌名 | 高 —— 但源码是「当前实现」，可能与已发布版本有出入 |

> 0.6 新增的令牌名一档解决了一个此前明确放弃的缺口。上一版写「`Search` 的圆角/高度拿不到，`resources.index` 是 RestoolV2 二进制、本机解不出」，据此把这些行标成「只能以设计稿为准」。实际上 `resources.index` 只是 `global_system_resources` 三份 JSON 的编译产物，读源文件即可 —— **又一次「没找到就说没有」**，与 §0.2 同型。

> 0.5 声称「42 控件全覆盖」，按**形态**统计实际有 98 项缺失。差异的来源是"按控件名统计"与"按官方形态统计"两种口径 —— 后者才是可核对的。
>
> 0.6 补上 HDS 文档后缺口数字大幅上升，主因是**口径变严**（底部页签、列表项、核心操作栏、即时操作从各 1–2 行拆成 5–13 行；半模态从 1 行 `●` 拆成 7 行 `○`；子页签从 3 行拆成 8 行；弹出框从 6 行拆成 15 行；子标题与工具栏各从 3 行、2 行拆成 8 行），不是实现退步。同一份代码在两套口径下会得出完全不同的结论 —— 这正是这张表存在的理由。
>
> 两个被清掉的 `●` 值得单独记住：**半模态面板**只实现了官方 5 种 `SheetType` 里的 1 种，**子页签**连主文档（`ChipGroup`）都没抓过（抓取表里误写成了单个 `Chip`）。两者都不是「以前做对了、后来退步」，而是**从来没对过**，只是当时没有可核对的依据。