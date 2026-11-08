# 42 控件对照官方文档复核清单（0.6.0）

> 复核时间：2026-11-07
> 复核对象：`lib/src/widgets/` 下与官方「控件概览」42 项对应的实现
> 官方依据：①设计规范 `developer.huawei.com/.../doccenter-ux-design/<slug>.md`（含文档内配图 608 张）
> ②设计文档末尾「开发文档」链接指向的组件参考文档（56 份，已快照到 `doc/reference/api/`）
> ③系统资源表 `doc/reference/resources/`（令牌真值）
> ④组件实现源码 `doc/reference/source/*.ets`

## 0. 复核方法与判据

### 0.1 三条依据的确定性分档

| 档 | 依据 | 能回答什么 | 不能回答什么 |
| --- | --- | --- | --- |
| A | 系统资源表 `float.json` / `float_sys.json` | **具体数值**（36.0vp / 0x19000000） | 语义、形态数量 |
| B | 组件参考文档（`doc/reference/api/*.md`） | 属性名、默认值、取值范围、枚举成员 | 令牌背后的真值（只给 `$r('sys.float.x')`） |
| C | 设计规范页（42 份，含配图） | 形态分类、使用场景、布局断点 | 单个属性的默认值 |

**判据按「哪个来源给得出具体数值就用哪个」，不按来源排序。** 上游已把不少常量从字面值改成令牌引用（`subheader.ets` 的 `lazyInit`、`chip.ets` 的 `$r('sys.float.chip_normal_height')`），此时源码答不出数值，必须回资源表。

### 0.2 本轮实际做的事

- 重抓 56 份组件参考文档（`./tool/fetch_reference.sh`，全部 200）
- 下载 42 份设计文档与**608 张配图**（`/tmp/ux/`）
- 机械抽取参考文档的 **1642 个属性/字段、279 个对象、58 个枚举、577 条带默认值属性**
- 抽取本库 **257 个公开类型、184 个构造器、48 个枚举（165 个成员）、13 个顶层函数**
- 逐条对照，并回溯到 `float.json` 取令牌真值

### 0.3 本轮**未能**做到的一件事

**配图无法机器读取。** 当前环境的视觉通道不可用（`ViewImage` 返回「the selected model cannot receive images」），608 张图只能做像素统计，读不出图上的标注文字。因此：

- 凡文档**正文**写了的数值，本清单都已核对；
- 凡**只存在于配图标注里**的规格（设计稿常见做法），本轮**未核对**，标注为 `⚠ 图注未核`。

图片本体（608 张、185MB）**不入库**，但索引已入库：`doc/ux-images.index.json` 记录了每张图的「所属文档 / 序号 / 官方原文上下文」，补齐时按它逐张下载并对照即可，不用重新解析文档。补齐命令：

```zsh
./tool/fetch_ux_images.sh          # 重下 42 份设计文档与 608 张配图到 doc/reference/design/
```

这一项需要在有视觉通道的环境补齐，不能当作「已核过」。

---

## 1. 结论摘要

| 判定 | 数量 | 说明 |
| --- | --- | --- |
| ✅ 准确 | **14** | 属性与默认值与官方一致（个别有无关紧要的多余项） |
| ⚠ 有偏差 | **21** | 单个数值或语义与官方不符 |
| ⚠⚠ 明显缺口 | **7** | 官方核心能力未实现（索引条 / 图片 / 下拉按钮 / 评分条 / 列表 / 即时操作 / 气泡提示） |
| 合 计 | **42** | 与官方「控件概览」42 项一一对应 |

**最该先修的五项**（用户可见度 × 修复成本）：

1. `OhosRatingBar` —— 分值是 `int`，官方最小步长 0.5，**半星根本表达不出来**
2. `OhosPopup` —— **没有箭头**（官方 `arrowWidth 16 / arrowHeight 8 / enableArrow true`），形态不是指向型气泡；圆角 16 vs 20；最大宽 260 vs 400
3. `OhosScrollbar` —— 热区 8vp，官方要求 **32vp**（触屏点不中）；条宽 8 vs 4
4. `OhosToast` —— 最大宽度 320 vs 官方 **400**；安全距离 20/14 vs 官方 **10vp**
5. `OhosIndexer` 索引条 —— 官方 4 个颜色属性 + `alignStyle` + `usingPopup` 气泡全部缺失

**另有两条不是「数值差」而是「形态差」，要特别警惕：**

- `OhosSnackBar` 用 Flutter `ScaffoldMessenger` 实现，**位置与宽度由框架决定**，官方「距底 92vp / 距页签 16vp / 上限 400vp」三条几何规格一条都做不到
- `OhosCounter` 用一个 `enabled` 取代官方 `enableInc` / `enableDec` 两个**独立开关**，「库存为 0 时只能减不能加」这类场景无法表达

---

## 2. 逐控件清单

字段说明：`官方` = 参考文档属性数；`本库` = 构造参数数；`偏差` 分「数值 / 语义 / 缺失」三类。

### 2.1 展示类（12 项）

#### ① 文本 `text` → `ohos_text.dart` ✅（受限）

- 官方 73 属性 / 本库 8 参数
- **准确**：`OhosTextLevel` 13 级字号取自官方排版令牌
- **平台差异**：`fontSize`/`fontWeight`/`textOverflow`/`maxLines` 等由 Flutter `Text` 与 `DefaultTextStyle` 承担，不必重复实现
- **缺失（有意）**：`textSelectable`/`copyOption`/`bindSelectionMenu`/`marqueeOptions` 等富文本能力未做
- 判定：**符合本库「主题绑定文本」的定位**，不按官方 73 项逐项对照

#### ② 分隔器 `divider` → `ohos_divider.dart` ⚠ 有偏差

| 官方属性 | 官方默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `strokeWidth` | **1px** | `thickness = 0.5` | ⚠ **数值不符**：1px 在 3.5 密度下 ≈ 0.286vp；本库 0.5 固定 |
| `color` | `'#33182431'` | `theme.dividerColor` = `0x19000000` | ⚠ 近似但不等（0x33 vs 0x19，透明度差一倍） |
| `vertical` | `false` | **缺** | ⚠⚠ 缺失：无竖线形态 |
| `lineCap` | `LineCapStyle.Butt` | **缺** | ⚠ 缺失 |

- 设计规范原文：「分割线默认使用 1px 高度」
- 本库注释写「[indent] 默认 0，与 Material Divider 一致」—— 理由成立，但**厚度与颜色未对齐官方**

#### ③ 子标题 `subheader` → `ohos_subheader.dart` ✅

- 官方 18 属性 / 本库 11 参数
- **准确**：栏高 56、右箭头 24/12/28/24vp 均经资源表核对
- **字号 18 是对的 —— 这是一次「设计规范 vs 组件令牌」的口径差，不是偏差**：
  - 设计规范页写「文字为 **15vp**」
  - 资源表 `subheader_title_font_size` = **18fp**
  - `subheader.ets` 同处注释 `// subheader_title_font_size: 125834265, 18`，且 `RESOURCE_CACHE_MAP` 里 `defaultValue: 18`
  - 本库 `_titleFontSize = 18` ✅
  - 结论：15vp 是**设计稿层面的视觉建议**，18fp 是**组件令牌真值**。本库实现的是组件，取令牌正确。
- **副标题 14** ✅（`_subtitleFontSize = 14`，对应 `subheader_subtitle_font_weight = 400` 的正文级）
- **缺失**：`operationType`/`operationItem`/`onSelect`（操作项组）未实现，本库用 `trailing` + `onTrailingTap` 简化

#### ④ 进度条 `progress` → `ohos_progress_indicator.dart` ✅ **准确**

全部 5 种形态（`linear`/`ring`/`eclipse`/`scaleRing`/`capsule`）与官方 `ProgressType` 一一对应，且枚举名逐字一致（`linear, ring, eclipse, scaleRing, capsule`）。

| 官方 | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `ProgressStyleOptions.strokeWidth` | 4.0vp | `thickness = 4` | ✅ |
| `ScaleRingStyleOptions.scaleWidth` | 2.0vp | `scaleWidth = 2` | ✅ |
| `CapsuleStyleOptions.borderWidth` | 1vp | `capsuleBorderWidth = 1` | ✅ |
| `CircleStyleOptions` 最小宽高 | 77vp | `scaleRingDiameter = 77` | ✅ |

- **缺失**：`total`（官方 `value` 的取值范围是 `[0, total]`，本库只有 0..1）、`status`（`LOADING`/`PROGRESSING`）、`enableScanEffect`、`enableSmoothEffect`、`strokeRadius`
- 其中 `total` 与 `status` 是**用户可感知的能力**（扫码动效、加载不定态），建议补

#### ⑤ 索引条 `alphabetindexer` → `ohos_alphabet_indexer.dart` ⚠⚠ 明显缺口

| 官方属性 | 官方默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `color` | `0x99182431` | `theme.textSecondaryColor` | ⚠⚠ **数值不符** |
| `selectedColor` | `0xFF007DFF` | `theme.highlightColor` | ⚠⚠ 数值不符（官方是固定蓝） |
| `selectedBackgroundColor` | `0x1A007DFF` | **缺**（无选中底色） | ⚠⚠ 缺失 |
| `popupColor` / `popupSelectedColor` / `popupUnselectedColor` | `0xFF007DFF` / `#FF182431` | **缺** | ⚠⚠ 缺失 |
| `itemSize` | `16.0` | 由父约束推算 | ⚠ 不能显式指定 |
| `usingPopup` | `false` | 换成 `showMagnifier` | ⚠ 语义替换（放大镜 ≠ 气泡） |
| `alignStyle` | `IndexerAlign.END` | **缺**（无 `OhosIndexerAlign` 枚举） | ⚠⚠ 缺失：无法左对齐 |
| `popupPosition` | `{x:60, y:48}` | **缺** | ⚠ 缺失 |

- 官方 `IndexerAlign` 有 4 个成员（`Left`/`Right`/`START`/`END`），本库**一个枚举都没有**
- 判定：**本库最大的规格缺口之一**

#### ⑥ 滚动条 `scrollbar` → `ohos_scrollbar.dart` ⚠ 有偏差

| 官方 / 设计规范 | 值 | 本库 | 结论 |
| --- | --- | --- | --- |
| 触屏热区（设计规范原文） | **32vp** | 无（`RawScrollbar` 默认 8vp 触区） | ⚠⚠ **点不中** |
| 条宽 | 4vp（`scrollbar_thumb_width`） | `thickness = 8` | ⚠ 数值不符（厚一倍） |
| `scrollBarColor` | `ColorMetrics.numeric(0x66182431)` | `textPrimaryColor.withValues(alpha:0.30)` ≈ `0x4D000000` | ⚠ 数值不符 |
| `enableNestedScroll` | `false` | **缺** | ⚠ 缺失 |

- 设计规范另有「无操作 2 秒后消失」——`RawScrollbar` 默认 3 秒淡出，未对齐

#### ⑦ 新事件标记 `badge` → `ohos_badge.dart` ⚠ 有偏差

| 官方 | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `BadgeStyle.badgeSize` | **16vp** | 硬编码 18（`minWidth/minHeight: 18`） | ⚠ **数值不符** |
| `BadgeStyle.fontSize` | **10vp** | 未显式设置（继承） | ⚠ 缺失 |
| `BadgeStyle.color`（文字色） | `Color.White` | 白 | ✅ |
| `BadgeStyle.badgeColor` | `Color.Red` | `theme.dangerColor` | ⚠ 近似 |
| `BadgeParam.position` | `BadgePosition.RightTop` | **缺**，固定 `Positioned(top, right)` | ⚠⚠ 缺失：没有 `Right`/`Left` |
| `count` 上限 | `maxCount` 默认 **99** | `maxCount = 99` | ✅ |
| `value`（字符串形态） | — | **缺**（只有 `count` int 与 `isDot`） | ⚠ 缺失 |

- 官方 `BadgePosition` 3 个成员，本库**无枚举**。设计要求「圆点标记在文本后方」无法表达

#### ⑧ 即时反馈 `toast` → `ohos_toast.dart` ⚠ 有偏差

| 设计规范原文 | 值 | 本库 | 结论 |
| --- | --- | --- | --- |
| 最大宽度 | **窗口宽 − 两侧 Margin，上限 400vp** | `maxWidth: 320` | ⚠⚠ **数值不符** |
| 文本安全距离 | **10vp**（上下左右） | `horizontal: 20, vertical: 14` | ⚠⚠ 数值不符 |
| 圆角 | — | 28 | 待核（图注未核） |

- 官方规格里**没有 320 这个数**。400 与 320 的差别在 360vp 屏上是「铺满 vs 留白」的差别，用户可见

#### ⑨ 二维码 `qrcode` → `ohos_qr_code.dart` ✅（一处多余）

| 官方 | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `color` | `'#ff000000'`（**不跟随深浅色**） | `theme.textPrimaryColor`（跟随主题） | ⚠ 语义不符（官方明确「不跟随系统深浅色模式切换而修改」） |
| `backgroundColor` | `'#ffffffff'`（不跟随） | `theme.cardColor`（跟随） | ⚠ 同上 |
| `contentOpacity` | `1` | **缺** | ⚠ 缺失 |
| 圆角 | 官方无此规格 | `borderRadius: 16` | ⚠ **多余规格**（凭空加的） |

#### ⑨′ 即时操作 `component_snackbar` → `ohos_snack_bar.dart` ⚠⚠ 明显缺口

| 设计规范原文 | 值 | 本库 | 结论 |
| --- | --- | --- | --- |
| 最大宽度 | **窗口宽 − 两侧 Margin，上限 400vp** | 无（用 Flutter `SnackBar` 的默认边距） | ⚠⚠ **数值不符** |
| 距底部导航条 | **92vp** | 无 | ⚠⚠ 缺失 |
| 底部页签场景 | 距页签 **16vp** | 无 | ⚠⚠ 缺失 |
| `SnackBarStyleOptions.duration` | **5000ms** | `Duration(seconds: 3)` | ⚠ 数值不符 |
| `blurStrategy` | `BlurStrategy.ADAPTIVE` | 无 | ⚠ 缺失 |
| `isHeightAdaptive` | `false` | 无 | ⚠ 缺失 |

- **实现方式差异**：本库用 Flutter `ScaffoldMessenger.showSnackBar` + `SnackBarBehavior.floating`，位置与宽度**由框架决定**，无法满足官方的 92vp / 16vp / 400vp 三条几何规格
- **官方独有能力（本库全缺）**：
  - `operationType`（`TEXT_BUTTON`/`ARROW_BUTTON`/`CLOSE_BUTTON` 等操作区形态）
  - `onArrowClick`/`onCloseButtonClick`/`onContentClick` 三个独立回调
  - `highlightBackBoardColor`（高亮背板）
  - `iconType`（`SnackBarIconType.SMALL`/其他）/ `iconBuilder`
  - `keyboardUpAvoidHeight`/`keyboardDownAvoidHeight`（键盘避让）
- 本库**做对的部分**：`duration -1` 语义（`resident`）对应官方 `duration` 特殊值；`show()`/`dismiss()` 有 `showOhosSnackBar` / `hideCurrentSnackBar` 对应
- 判定：**「能用但规格不符」**，属于换框架实现带来的系统性偏差

#### ⑨″ 气泡提示 `popup` → `ohos_popup.dart` ⚠⚠ 明显缺口

| 官方 `PopupCommonOptions` | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `radius` | **20vp** | `OhosGeometry.radiusMedium = 16` | ⚠ 数值不符 |
| `arrowWidth` | **16vp** | **无箭头** | ⚠⚠ 缺失 |
| `arrowHeight` | **8vp** | **无箭头** | ⚠⚠ 缺失 |
| `enableArrow` | `true` | 无（`OhosFloatingTabBar` 另处有，非此处） | ⚠⚠ 缺失 |
| `arrowPointPosition` | `CENTER`（3 档 `Start`/`Center`/`End`） | 无 | ⚠⚠ 缺失 |
| `targetSpace` | **8vp** | `anchor.dy - 12` + `Offset(0,-52)` | ⚠ 数值不符 |
| 最大宽度（设计规范） | 窗口宽 − Margin，上限 400vp | `maxWidth: 260` | ⚠⚠ 数值不符 |
| `placement` | `Bottom` | 固定上方（`-52`） | ⚠ 缺失（无法下方弹出） |
| `autoCancel` | `true` | 有（点击外部消失） | ✅ |
| `offset` | `{0,0}` | 无 | ⚠ 缺失 |

- 设计规范另写：「气泡到屏幕边缘最小 **6vp**」以保证尖角可对齐 → 无箭头则整条失效
- 判定：**本库实现的是「无箭头浮层提示」，不是官方定义的「指向型气泡」**。两者形态不同，不只是参数偏差

#### ⑩ 文本时钟 `textclock` → `ohos_text_clock.dart` ⚠ 有偏差

- 官方 14 属性 / 本库 4 参数
- 官方 `format` 默认 `aa hh:mm:ss`（12h）/ `HH:mm:ss`（24h）
- **缺失**：`fontColor`/`fontSize`/`fontStyle`/`fontWeight`/`fontFamily`/`textShadow`/`fontFeature`/`dateTimeOptions`/`start()`/`stop()`/`onDateChange`
- 其中 `start()`/`stop()` 是**功能缺失**（无法手动停表），`dateTimeOptions` 影响前导零

#### ⑪ 图片 `image` → `ohos_image.dart` ⚠⚠ 明显缺口

- 官方 28 属性 / 本库 8 参数
- **缺失的核心项**：`objectFit`（`ObjectFit` 5 档）、`syncLoad`、`alt`（占位图）、`onError`/`onComplete`（加载态回调）、`renderMode`、`interpolation`、`sourceSize`、`resizable`、`colorFilter`
- `objectFit` 与 `alt` 是**图片组件的核心语义**（裁切策略与加载失败兜底），缺失影响可用性

#### ⑫ 空白 `blank` → `ohos_blank.dart` ✅（一处缺失）

- 官方 1 属性 / 本库 1 参数（`minSize`）
- **缺失**：`color`（官方默认 `Color.Transparent`）
- 本库 `minSize` 是自加的（官方 `Blank()` 无参数，纯靠父容器主轴填充）
- 判定基本准确，`color` 影响「着色空白条」这一用法

#### ⑫′ 数据可视化 `datapanel` → `ohos_data_panel.dart` ✅

| 官方 | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `DataPanelOptions.max` | **100** | `max = 100` | ✅ |
| `DataPanelType` | `Line`/`Circle` | `OhosDataPanelType`（`line`/`circle`） | ✅ **逐字对上** |
| `strokeWidth` | 4vp（`Divider` 级） | `OhosDataPanelColor` + `strokeWidth` | ✅ |
| `valueColors` | 有 | `OhosDataPanelColor.solid` / `.gradient` | ✅ 且更强（支持渐变） |
| `trackBackgroundColor` | 有 | 有 | ✅ |
| `trackShadow` | `colors` | `OhosDataPanelShadow`（`radius=20`/`offsetX=5`/`offsetY=5`/`colors`） | ✅ |
| `closeEffect` | 有 | 有 | ✅ |
| `contentModifier` | 有 | 无（Flutter 侧用 builder 替代） | 🅿 平台差异 |

- 设计规范「横屏左右布局时，左右各减 48vp 边距后按比例等分」→ 属布局层，由使用方承担
- **⚠ 历史提醒**：0.6 把**旧的 KPI 网格**改名为 `OhosStatGrid`，`OhosDataPanel` 换成了这个官方占比图 —— 这是已记录的破坏性变更，别混淆

#### ⑫″ 文本选择菜单 `textselection` → `ohos_selection_toolbar.dart` ⚠ 有偏差

- 官方 `SelectionMenuOptions` 8 字段 + `EditorMenuOptions` 3 + `ExpandedMenuOptions` 1
- **准确**：8 个动作（`cut`/`copy`/`paste`/`selectAll`/`translate`/`share`/`search`/`more`）与官方 `EditorMenuOptions.action` 的语义一致
- **语义差异**：官方是「controller + 菜单项注册」模型（`SelectionMenuOptions.controller`、`onCopy`/`onPaste`/`onCut`/`onSelectAll` 四个独立回调），本库是「传入 `children` 由调用方自己拼」的纯视觉控件
  - 判定：**合理简化**（Flutter 的文本选择由 `SelectionArea`/`SelectableText` 承担），但 `expandedMenuOptions`（二级「更多」菜单）的官方分组规则未体现
- **缺失**：`EditorMenuOptions.builder`（自定义菜单项 UI）、`backgroundSystemMaterial`
- 判定：**视觉层准确，交互编排交给调用方**

---

### 2.2 导航类（4 项）

#### ⑬ 底部页签 `bottomtab` → `ohos_navigation_bar.dart` / `ohos_floating_tab_bar.dart` ✅（分层实现）

- 官方（`Tabs`）79 属性，本库拆成 `OhosNavigationBar`（平铺）+ `OhosFloatingTabBar`（悬浮）+ `OhosMiniBar`
- **准确**（逐条经资源表核对）：

| 规格 | 官方 | 本库 | 结论 |
| --- | --- | --- | --- |
| 平铺高度 | 48vp | 48 | ✅ |
| 悬浮高度 | 56vp | 56 | ✅ |
| ≥5 个 Tabs 最大宽 | **360vp** | 360 | ✅ |
| 4 个 Tabs 最大宽 | **328vp** | 328 | ✅ |
| 渐变蒙层高 | 栏高 + 16vp | 16 | ✅ |
| 蒙层色（浅/深） | `#CCF1F3F5` / `#99000000` | 一致 | ✅ |
| 悬浮栏左右边距 | 16 / 24 / 32 三档 | 三档 | ✅ |
| 模糊背板 1px 分割线 | 1px | 有 | ✅ |

- **未做**：`barMode: Scrollable/Fixed`（官方 `BarMode`）、`vertical`（侧边页签）、`barBackgroundBlurStyle` 的可配置化
- 判定：**本库覆盖质量最高的一组**

#### ⑭ 子页签 `chipsgroup` → `ohos_tab_bar.dart` / `ohos_chip_group.dart` ✅

- 官方 `ChipGroup` 10 字段
- **准确**：`startSpace`/`endSpace` = 16/16，`padding.top/bottom` = 14/14（均经 `float.json` 核对）
- **准确**：`selectedIndexes` 默认 `[0]`（已按官方改过，见 MIGRATION-0.6 §7）
- **缺失**：`multiple`（多选）、`allowClose`（可关闭 ×）、`suffixSymbol` 优先级
  - 其中 `allowClose` 在 `OhosChipItem` 里实现了，`multiple` 在 `OhosChipGroup` 里也有

#### ⑮ 标题栏 `titlebar` → `ohos_app_bar.dart` ⚠ 有偏差

- 官方（`Navigation`）67 属性 / 本库 19 参数
- **准确**：单行 56vp、强调型 112vp、渐变模糊层 32vp、1px 分割线
- 标题字号规范（设计文档原文）：
  - 单行 `19vp` → 放不下缩 `18vp` → `15vp` → 截断
  - 双行 `19vp`，不可换行，缩 `18vp` → `15vp` → 跑马灯
  - 辅助文本 `15vp` → 缩 `13vp` → 跑马灯
  - ⚠ 本库未见 `19/18/15` 三级缩放的实现（只有单一字号）
- **缺失**：`titleMode` 的 `FREE`/`FULL`/`MINI`/`MODAL` 只部分实现（`FREE`/`FULL`/`MODAL` 在矩阵里标 `○`）
- **缺失**：`menus`、`toolbarConfiguration`、`hideBackButton`、`onTitleModeChange`

#### ⑯ 导航点 `swiper` → `ohos_swiper.dart` ⚠ 有偏差

- 官方（`Swiper`）66 属性 / 本库 52 名字（实现 424 行，深度尚可）
- **缺失**：`displayCount`（一屏多页）、`displayMode`（`SwiperDisplayMode` 3 档）、`effectMode`（`EdgeEffect`）、`itemSpace`、`cachedCount`、`disableSwipe`、`vertical`
- 指示点：`OhosPageIndicatorType` 只有 `dot`/`digit`，官方 `SwiperIndicator` 还有 `indicatorStyle`（底/中/上）

---

### 2.3 操作类（7 项）

#### ⑰ 按钮 `button` → `ohos_button.dart` ⚠ 有偏差

| 设计规范原文 | 值 | 本库 | 结论 |
| --- | --- | --- | --- |
| 大屏最大宽度 | **448vp** | **无约束** | ⚠⚠ 缺失 |
| 窗口化场景 | 容器宽 − 两侧 16vp，仍 ≤448 | 无 | ⚠⚠ 缺失 |
| 默认字重 | **500** | 未显式 | ⚠ 缺失 |

- 官方 `ButtonType` 3 档（`Capsule`/`Circle`/`Normal`）→ 本库 `OhosButtonShape`（`capsule`/`rounded`/`circle`）✅ 对应
- 官方 `ButtonStyleMode` 4 档 → 本库 `OhosButtonStyle` 5 档（多出 `plain`）
- **缺失**：`controlSize`（`SMALL`/`NORMAL`）、`role`、`stateEffect`、`labelStyle`（字号/字重/字色不可配）

#### ⑱ 下拉按钮 `select` → `ohos_select.dart` ⚠⚠ 明显缺口

- 官方 35 属性 / 本库 16 参数
- **缺失的核心项**：
  - `optionWidth`/`optionHeight`（下拉项尺寸）
  - `selectedOptionBgColor`/`selectedOptionFontColor`/`optionBgColor`/`optionFontColor`（选中与常规配色）
  - `menuAlign`（菜单对齐 4 档）、`space`（默认 8vp，已核对官方）、`arrowPosition`
  - `divider`/`dividerStyle`、`showDefaultSelectedIcon`、`menuBackgroundColor`
- 判定：**样式可配置性严重不足**，官方几乎每个视觉参数都可配

#### ⑲ 状态按钮 `togglebutton` → `ohos_toggle_button.dart` ⚠ 有偏差

- 官方 `Toggle` 5 属性 / 本库 10 参数
- **缺失**：`selectedColor`（⚠ 本库用 `activeColor`，可对上）、`switchPointColor`（滑块色）、`switchStyle`（`pointRadius`/`unselectedColor`/`pointColor`/`trackBorderRadius` 4 字段全缺）
- 设计规范要求「自定义尺寸、圆角、手柄半径」→ 本库只能改整体 `size`，**手柄半径与轨道圆角不可配**

#### ⑳ 操作块 `chips` → `ohos_chip.dart` ⚠ 有偏差

- 官方 `ChipOptions` 11 字段 / 本库 10 参数
- **准确**：`size`（`ChipSize.NORMAL`/`SMALL`）、`enabled`、`activated` 三档齐
- **缺失**：`prefixIcon`/`prefixSymbol` 的双态图标（`normal`/`activated`）、`suffixSymbol`、`labelMargin`、`fontColor`/`fontSize`/`fontFamily`、`fillColor`（背景）、`backgroundSystemMaterial`
- 判定的准确性：`activated` 语义已核对（「允许激活」≠「已激活」），与官方 `ACTIVE` 一致

#### ㉑ 工具栏 `toolbar` → `ohos_toolbar.dart` ⚠ **文档冲突**

| 来源 | 高度 |
| --- | --- |
| 设计规范原文 | 「工具栏默认高度为 **52vp**」 |
| `toolbar.ets` `DEFAULT_TOOLBAR_HEIGHT` | **56** |
| `toolbarv2.ets` 同常量 | **56** |
| 本库 | `_height = 56` |

**这不是本库的错，是两份官方文档互相矛盾。** 源码（两版一致）说 56，设计文档说 52。
- 证据链判断：**取 56**（源码是编译产物的一手来源，设计文档可能是旧值；且 `toolbarv2` 同为 56）
- 但本库注释写「Official bar height」未标注这个冲突，**建议补注**，否则下一个人会以为漏查
- 其余：`_maxInline = 5`/`_moreIndex = 4` 与 `toolbar.ets` 一致 ✅

#### ㉒ 核心操作栏 `component_actionbar` → `ohos_action_bar.dart` ✅

- 官方 `HdsActionBar` `ActionBarStyle` 10 字段 / 本库 `OhosActionBarStyle`
- **准确**：`backgroundBlurStyle` 默认 `BlurStyle.COMPONENT_REGULAR`、`enabled` true、`isHorizontal` true、`isPrimaryIconChanged` false —— 四个默认值逐字对上
- **缺失**：`margin`（6.1.0 新增，上下边距）、`baseIconSymbolGlyphModifier`、`buttonModifier`

#### ㉓ 菜单 `menu` → `ohos_menu.dart` ⚠ 有偏差

| 设计规范原文 | 值 | 本库 | 结论 |
| --- | --- | --- | --- |
| 手机统一宽度 | **固定 224vp** | 无（`PopupMenu` 自适应） | ⚠⚠ 宽度不符 |
| 电脑最小宽度 | 224vp，可配但不低于 64vp | 无 | ⚠ 缺失 |
| `radius` | 2in1 = 8vp，其他 = **20vp** | `theme.outlineWidth` 相关，未见 20 | ⚠ 待核 |
| `fontSize`/`fontColor`/`font` | 有 | **缺** | ⚠ 缺失 |
| `menuItemDivider`/`menuItemGroupDivider` | 有 | **缺** | ⚠ 缺失 |

- 判定：**224vp 固定宽是菜单的核心规格**（官方写「泛手机统一宽度为固定 224vp」），未落实

---

### 2.4 输入类（8 项）

#### ㉔ 文本框 `textinput` → `ohos_text_field.dart` ⚠ 有偏差

- 官方 94 属性 / 本库 76 参数（覆盖率高）
- **准确**：`OhosTextFieldVariant` 4 档（`underline`/`filled`/`capsule`/`inline`）
- **缺失的核心项**：`showPassword`/`passwordIcon`（密码可见切换）、`showError`（错误态）、`showCounter`（字数计数）、`inputFilter`、`maxLength`、`onSubmit`、`enterKeyType`、`caretColor`/`caretStyle`、`placeholderColor`/`placeholderFont`、`underlineColor`
- 其中 `showCounter` 的 `InputCounterOptions`（`thresholdPercentage` 区间 `[1,100]`、`highlightBorder`）在 `ts-universal-attributes-text-style.md` 里有完整定义，**已抓取但未见实现**

#### ㉕ 搜索框 `search` → `ohos_search_bar.dart` ⚠ 有偏差

- 官方 66 属性 / 本库 25 参数
- **✅ 高度 40 是正确判断，本库已研究过并留痕**：
  - `float.json` 里 `ohos_id_search_height = **56.0vp**`、`ohos_id_search_default_height = **40.0vp**`
  - 本库注释：`search_height` 在 `search/` 的 13 个源文件里**一次都没被读**，`SearchTheme::GetHeight()` 只解析 `search_default_height`
  - 且官方每个设置 `searchButton` 的示例仍写 `.height(40)`
  - 结论：**40 是对的**。这条是本库「`GetAttr` ≠ 令牌生效」判据的正面案例 —— 令牌存在但无调用方，不能据此改实现
- **准确**（令牌逐条对上）：`search_button_space = 2`、`search_divider_side_space = 2`、`search_icon_left_space = 12`、`search_icon_right_space = 8`、`search_close_icon_size = 16`、`search_text_field_padding_left = 4`、`search_text_field_border_radius = 20`
- **缺失**：`placeholderColor`/`placeholderFont`、`textAlign`、`maxLength`、`dividerColor`、`decoration`、`onChange`/`onSubmit` 的官方命名
- 判定：**几何高度与间距层准确，缺的是文本样式配置**

#### ㉖ 数字加减 `counter` → `ohos_counter.dart` ⚠ 有偏差

| 官方 | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `enableInc` | `true` | **缺**（只有整体 `enabled`） | ⚠⚠ 语义缺失 |
| `enableDec` | `true` | **缺** | ⚠⚠ 同上 |
| `onInc` / `onDec` | 有 | `onChanged` 合一 | ⚠ 缺失 |

- ⚠ **重要**：官方是**两个独立开关**，本库一个 `enabled`。业务上「库存为 0 时只能减不能加」这类场景**无法表达**
- 官方 `CommonOptions.step` 默认 `1` → 本库 `step = 1` ✅
- `DateStyleOptions.year/month` 区间 `[1,5000]`/`[1,12]` → 本库无日期型计数器（`OhosDateCounter` 是另一个组件）

#### ㉗ 图案锁 `patternlock` → `ohos_pattern_lock.dart` ⚠ 有偏差

- 官方 16 属性 / 本库 24 名字
- **缺失**：`circleRadius`（官方区间 `(0, sideLength/11]`）、`regularColor`/`selectedColor`/`activeColor`/`pathColor`/`pathStrokeWidth` 的官方命名、`autoReset`、`activateCircleStyle`
- **缺失的方法**：`reset()`、`setChallengeResult()`、`onPatternComplete`/`onDotConnect` 回调
- 官方 `PatternLockChallengeResult` 2 档（`CORRECT`/`WRONG`）→ 本库有 `onError` 但无 `setChallengeResult`
- `skipUnselectedPoint` 缺失

#### ㉘ 勾选 `checkbox` → `ohos_checkbox.dart` ⚠ 有偏差

| 官方 | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `shape` | — （`CheckBoxShape` 圆/方） | **缺**（固定圆角 0.26×size） | ⚠⚠ 缺失：无法切方圆 |
| `mark` | `{strokeColor, strokeWidth, size:20vp}` | **缺**（写死 `Icons.check_rounded`） | ⚠⚠ 缺失：勾的形状/粗细不可配 |
| `select` | `false` | `value` | ✅ 对上 |
| `selectedColor` | — （`$r('sys.color...')`） | `activeColor` | ✅ 对上 |
| `unselectedColor` | — | **缺**（用 `theme.textTertiaryColor`） | ⚠ 缺失 |

- 资源表真值：`ohos_id_checkbox_size = 48vp`（热区）、`ohos_id_checkbox_default_size = 48`、`checkbox_default_size_twelve = 24vp`、`ohos_id_checkbox_border_width = 1vp`、`ohos_id_checkbox_stroke_width = 2vp`、`ohos_id_checkbox_focus_radius = 6vp`
- ⚠ 本库 `size = 24` ✅ 对上 `checkbox_default_size_twelve`；描边 `1.5` ⚠ 官方 1vp；勾粗 `2` ✅
- ⚠ **热区 48vp 未实现**（官方 `ohos_id_checkbox_hotzone_padding = 14vp`）

#### ㉙ 开关 `toggleswitch` → `ohos_switch.dart` ⚠ 有偏差

- 官方 `ToggleType` 3 档（`Checkbox`/`Switch`/`Button`）→ 本库只有开关形态，**另两种形态由 `OhosCheckbox` / `OhosToggleButton` 分文件承担**（合理）
- **缺失**：`switchPointColor`（滑块色，官方默认 `$r('sys.color.ohos_id_color_foreground_contrary')`）、`switchStyle`（4 字段全缺：`pointRadius`/`unselectedColor`/`pointColor`/`trackBorderRadius`）
- 设计规范要求「自定义尺寸、圆角、手柄半径」→ 本库只有整体 `size = Size(50, 30)`
- 官方 `SwitchStyle.unselectedColor` 默认 `0x337F7F7F` → 本库 `inactiveColor` 可对上

#### ㉚ 单选框 `radio` → `ohos_radio.dart` ✅

- 官方 `RadioIndicatorType` 3 档（`TICK`/`DOT`/`CUSTOM`）→ 本库 `OhosRadioIndicator`（`tick`/`dot`/`custom`）**逐字对上** ✅
- 本库另有 `checkedBackgroundColor`/`uncheckedBorderColor`/`indicatorColor`，比官方 `radioStyle` 更细 ✅
- **缺失**：`radioStyle` 的官方分组命名（`checkedBackgroundColor`/`uncheckedBorderColor`/`indicatorColor` 三件在官方确实叫这些，实为对上）

#### ㉛ 评分条 `rating` → `ohos_rating_bar.dart` ⚠⚠ 明显缺口

| 官方 | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `stars` | **5** | `count = 5` | ✅ |
| `stepSize` | **0.5**（区间 `[0.1, stars]`） | **缺**，`value` 是 `int` | ⚠⚠ **半星无法表达** |
| `starStyle` | `{backgroundUri, foregroundUri, secondaryUri}` | **缺**，写死 `Icons.star_rounded` | ⚠⚠ **不能用图片/自定义图标** |
| `onChange` | 有 | `onChanged` | ✅ |

- 设计规范原文：「评分步幅按照 **0.5** 为基础值为一个单位」
- 本库 `value: int` + `onChanged!(i == value ? i - 1 : i)` —— 连「再点一次取消」都是自加的语义，官方没有
- 另有：本库用 `IconButton`（热区 48vp）包裹 28vp 星，**实际点击区域比视觉大得多**，与官方规格不一致
- 判定：**规格偏差最严重的一项**

---

### 2.5 选择类（7 项）

#### ㉜ 滑动条 `slider` → `ohos_slider.dart` ✅ **准确（本库质量最高）**

| 官方 | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `trackThickness` | OutSet 4.0vp / InSet 20.0vp | 4 / 20 | ✅ |
| `blockSize` | OutSet `{18,18}` / InSet `{12,12}` | 同 | ✅ |
| `trackBorderRadius` | OutSet 2vp | 2 | ✅ |
| `stepSize` | `4vp`，区间 `[0, trackThickness)` | 4，`<=` 夹取 | ✅ |
| `showSteps` | `false` | `false` | ✅ |
| `showTips` | `false` | `showValueBubble = false` | ✅ |
| `SliderStyle` | `OutSet`/`InSet`/`NONE` | `outset`/`inset`/`none` | ✅ 逐字对上 |

- **缺失**：`blockColor`/`trackColor`/`selectedColor` 三色的官方令牌名对应（本库 `activeColor` 只覆盖选中色）、`blockBorderColor`/`blockBorderWidth`、`minResponsiveDistance`、`prefix`/`suffix`（已实现为 builder）、`slideRange`、`stepColor`
- 设计规范「上下图标区域支持点击，每次点击变化增减 5%」→ ⚠ 未实现（本库 `prefix`/`suffix` 只是装饰）

#### ㉝ 选择器 `picker` → `ohos_picker.dart` ✅

| 官方 | 默认 | 本库 | 结论 |
| --- | --- | --- | --- |
| `selectedIndex` | `0` | `initialIndexes` | ✅ |
| `canLoop` | `true`（<8 项时不循环） | `loop = true` + 硬条件已实现 | ✅ **硬条件已照做** |
| `itemHeight` | — | 由行高推算 | ⚠ 不能显式指定 |
| `displayedItemCount` | — | `visibleCount = 5` | ✅ 对上 |
| `selectionIndicator.type` | `PickerIndicatorType.BACKGROUND` | `OhosPickerIndicator.background` | ✅ |
| `selectionIndicator.strokeWidth` | `{2.0, px}` | 未见 2px | ⚠ 待核 |
| `enableHapticFeedback` | `true` | **缺** | ⚠ 缺失 |

- 设计规范「组合图像与文本时，图像高度 ≤40vp」→ 本库 `OhosPickerItem` 有 `subtitle` 但无图像支持

#### ㉞ 色彩选择器 `color-picker` → `ohos_color_picker.dart` ⚠ 有偏差

- 官方 7 属性 / 本库 9 参数（`OhosColorPickerTab` 3 档：`grid`/`spectrum`/`sliders`）
- **缺失**：`initialColor`、`initialFavoriteColors`、`onColorSelected`、`onFavoriteColorsUpdate`
- 设计规范「Popup 容器宽度默认 400vp，箭头距目标 8vp」→ ⚠ 本库容器宽度未对齐（同 §2.1⑧ Popup 的 400 问题）

#### ㉟ 分段按钮 `segmentbutton` → `ohos_segmented_button.dart` ⚠ 有偏差

| 设计规范原文 | 值 | 本库 | 结论 |
| --- | --- | --- | --- |
| 大屏最大宽度 | **448vp** | 无约束 | ⚠⚠ 缺失 |
| 半模态 480vp 场景 | 两侧各 16vp | 无 | ⚠⚠ 缺失 |
| 选中态距背板边距 | **4vp** | 未见 | ⚠ 待核 |
| 选中背景不透明度 | **<20%** | `theme.outlineWidth` 相关 | ⚠ 待核 |

- 官方 `SegmentButtonOptions` 有多套 `fontColor`/`fontSize`/`fontWeight`/`selectedFontColor`/`selectedFontSize`/`selectedFontWeight`/`imageSize`/`buttonPadding`/`textPadding`/`selectedBackgroundColor`/`backgroundSystemMaterial`
- 本库只有 `OhosSegmentType` 2 档（`tab`/`capsule`），**样式可配性严重不足**

#### ㊱ 列表 `list` → `ohos_list.dart` ⚠⚠ 明显缺口

- 官方（`List`）53 属性 / 本库 `OhosList` **仅 4 参数**（`children`/`header`/`headerPadding`/`divider`），81 行
- **缺失的核心项**：
  - `lanes`（多列）、`listDirection`（横向）、`scrollBar`、`edgeEffect`
  - `divider`（官方是 `{strokeWidth, color, startMargin, endMargin}`，本库只有 bool）
  - `sticky`（`StickyStyle` 4 档，本库有 `OhosListStickyStyle` 但不在 `OhosList` 上）
  - `onReachStart`/`onReachEnd`/`onScrollIndex`、`cachedCount`、`scrollSnapAlign`
  - `editMode`/`onItemMove`/`onItemDelete`（拖拽排序）
- 设计规范高度表：
  - 效率型：48 / 56 / 64 / 72 / 96vp
  - 内容型：64 / 72 / 80 / 96 / 120vp
  - ⚠ 本库 `cardItemHeight = 48` 只落实了最低一档，`OhosListItemCardMetrics.cardHeight = 72` 只对上效率型第三档
- 视觉规格（设计文档行内表格）：`Badge 8×8vp`、系统图标 16/24vp、头像 40/48/56vp、应用图标 48/56/64vp、1:1 预览图 48/56/72/96vp、16:9 保持最长边 96vp、13:18 与 3:4 小 64vp / 大 96vp
  - ⚠ 本库 `OhosListItemCardMetrics.iconSmall = 16` / `iconSystem = 24` ✅ 对上图标两项，其余头像/预览图尺寸**未见**

#### ㊲ 弹出框 `dialog` → `ohos_alert_dialog.dart` ✅ **准确**

| 官方 / 设计规范 | 值 | 本库 | 结论 |
| --- | --- | --- | --- |
| `dialog_container_max_width` | 400vp | `maxWidth = 400` | ✅ |
| 窄屏自适应 | 「360vp 缩小或拉伸时同样自适应，达到 400vp 不再伸缩」 | `_bounds` 两个条件取小 | ✅ **本轮刚修** |
| `dialog_container_margin_left/right` | 16vp × 2 | `sideMargin = 16` | ✅ |
| 圆角 | 32vp（`OhosDialogMetrics.borderRadius`） | 32 | ✅ |

- **缺失**：`close()`/`open()`（官方 `CustomDialogController` 的方法）、`gridCount` 的完整回落语义（已实现但见 CHANGELOG 说明）
- 判定：**已修到与官方一致**（前一轮用户报的回归已解决）

#### ㊳ 半模态面板 `bindsheet` → `ohos_bottom_sheet.dart` ✅

| 官方 / 设计规范 | 值 | 本库 | 结论 |
| --- | --- | --- | --- |
| 圆角 | 32vp（`SheetOptions.radius`） | `OhosSheetSpec.radius = 32` | ✅ |
| CENTER/POPUP 最小高 | 320vp | 320 | ✅ |
| 最大高比例 | 90% | `maxHeightRatio = 0.9` | ✅ |
| MEDIUM/LARGE 固定高 | 560vp | 560 | ✅ |
| CENTER 默认宽 | 480vp | 480 | ✅ |
| SIDE 宽（>md） | 400vp | `sideWideWidth = 400` | ✅ |
| 拖拽条高 | 16vp | 16 | ✅ |
| 操作区高 | 56vp | `operationHeight = 56` | ✅ |
| 挡位速度阈值 | 1000 px/s | 1000 | ✅ |
| 挡位距离阈值 | 50% | 0.5 | ✅ |
| `SheetSize` | `MEDIUM`/`LARGE`/`FIT_CONTENT` | `medium`/`large`/`fitContent` | ✅ 逐字对上 |
| `SheetType` | 5 档 | `bottom`/`center`/`popup`/`side`/`contentCover` | ✅ |

- **缺失**：`dragBar` 可关闭、`maskColor`、`onDisappear`、`systemMaterial`
- 判定：**本库覆盖最精确的一组**（每条都对到资源表或文档原文）

---

### 2.6 未被 42 项覆盖但已实现（供参考，不在本次判定内）

`OhosCard`、`OhosArc`、`OhosGauge`、`OhosDateCounter`、`OhosLoadingIndicator`、`OhosSelectionToolbar`、`OhosScaffold`、`OhosSideBar`、`OhosMultiWindowEntry`、`OhosPointLight`、`OhosPressShadow`、`OhosLightMaterial`、`OhosMagnifier`、`OhosStatGrid`、`OhosThemeToggleButton`、`OhosIconButton`、`OhosLayeredIcon`

---

## 3. 待办：本轮无法判定、需补充核对的项

| # | 项 | 为什么没定 | 怎么定 |
| --- | --- | --- | --- |
| 1 | 全部 `⚠ 图注未核` 的规格 | 视觉通道不可用，608 张配图读不出标注 | 换有视觉通道的环境，按 `doc/ux-images.index.json` 的上下文逐张看（先跑 `./tool/fetch_ux_images.sh`） |
| 2 | `OhosToolbar` 高度 52 vs 56 | **两份官方文档矛盾**，取 56 已定，但需在代码注释里留痕 | 补注释，避免下次重复排查 |

> **已排除的伪待办（本轮查证后确认不是问题）：**
> - `OhosSubheader` 字号 15 vs 18 → 资源表 `subheader_title_font_size = 18fp`，本库 18 正确（15vp 是设计稿建议）
> - `OhosSearchBar` 的 `search_height` 令牌 → 该令牌**零调用方**，本库已按 `search_default_height = 40` 实现且留了注释，正确
> - `OhosPicker` 分割线 2px → 本库注释已写 `2.0px`，与官方 `{value:2.0, unit:px}` 一致
> - `OhosMenu` 圆角 → 本库用 `OhosGeometry.radiusMedium = 16`；官方 2in1=8 / 其他=20，**两项都不是 16**，仍是真偏差（见 §2.3㉓）

---

## 4. 复核本身暴露的两个方法论问题

### 4.1 属性缺口数字不可直接引用

机械比对得出的「官方 79 / 本库 52，缺 76」这类数字**不能直接用**，原因有三：

1. **通用属性不是缺口**：`backgroundColor`/`borderRadius`/`onClick` 等由 Flutter 侧承担，官方把它们列在 `ts-component-general-attributes.md`，我只做了粗略的 `GENERIC` 过滤，仍会漏。
2. **`Tabs`/`Navigation` 的 API 面远大于「控件」**：官方文档是「组件参考」，含路由栈操作（`pushPath`/`pop`/`getAllPathName`），本库实现的是**视觉控件**，不该要求它实现路由。
3. **同名不同义**：`OhosBadge` 缺 `Badge`，其实是官方把 `Badge(param)` 的构造器名算成了一个「属性」。

所以本清单的判定**逐条手工确认过**，上表的数字只作排序参考。

### 4.2 「文档没有」必须限定层级

记忆里已有这条教训，本轮再次踩到：`OhosSubheader` 字号在设计规范有、开发文档无、资源表得查。**结论必须写清是哪一层没有**，否则下一轮会把「这一层没有」当成「整体没有」。

---

## 5. 建议的修复优先级

### P0（用户可见的功能缺失）

1. **`OhosRatingBar`**：`value` 改 `double`，补 `stepSize = 0.5`、`starStyle` 三 URI
2. **`OhosCounter`**：`enabled` 拆成 `enableInc` / `enableDec`
3. **`OhosScrollbar`**：热区补到 32vp，条宽 8 → 4
4. **`OhosBadge`**：补 `BadgePosition` 3 档、`badgeSize = 16`、`fontSize = 10`
5. **`OhosIndexer`**：补 4 个颜色属性 + `IndexerAlign` + `usingPopup` 气泡

### P1（数值不符，视觉可见）

6. `OhosToast` 320 → 400，padding 20/14 → 10
7. `OhosPopup` 圆角 16 → 20，补箭头 16×8，最大宽 260 → 400
8. `OhosMenu` 补 224vp 固定宽
9. `OhosButton` / `OhosSegmentedButton` 补 448vp 上限
10. `OhosDivider` 厚度/颜色对齐 `1px` / `#33182431`

### P2（可配置性）

11. `OhosSwitch` / `OhosToggleButton`：补 `switchStyle` 4 字段
12. `OhosCheckbox`：补 `shape`（圆/方）、`mark`（自定义勾）
13. `OhosSelect`：补选项配色、尺寸、对齐
14. `OhosChip`：补前后图标双态、`fillColor`、字号

### P3（结构缺口）

15. `OhosList` 从 4 参数扩到官方核心能力（`lanes`/`divider` 对象/`sticky`/滚动回调）
16. `OhosImage` 补 `objectFit` / `alt` / `onError` / `onComplete`
17. `OhosTextClock` 补 `start()` / `stop()`
18. `OhosActionBar` 补 `margin`

---

## 6. 修复状态（P0 / P1 / P2 / P3 已全部落地）

> 本节由实施轮次回填。**每项都做了变异验证**：把改动还原成老实现后，对应断言
> 必须变红，否则断言恒真、测不出缺陷。库测试 652 → **745**（含随后「配图数值核查」
> 一轮补的 6 条，见 `doc/AUDIT-IMAGE-SPECS.md`），example 183 不变。

### P0（5/5 完成）

| # | 控件 | 做了什么 | 变异验证 |
| --- | --- | --- | --- |
| 1 | `OhosRatingBar` | `value` → `double`、`stepSize = 0.5`、半星裁切、`indicator` 形态、换图标 | 6 条新断言 |
| 2 | `OhosCounter` | 拆 `enableInc` / `enableDec`、独立 `onInc` / `onDec` | 3 条新断言 |
| 3 | `OhosScrollbar` | 条宽 4、`minThumbLength = 48`、`timeToFade = 2s`、距边 4 | 2 条新断言 |
| 4 | `OhosBadge` | `size 16` / `fontSize 10` / `dotSize 6`、`OhosBadgePosition` 3 档、字符串 `value` | 2 条（16→18 变红） |
| 5 | `OhosIndexer` | 4 色 + `OhosIndexerAlign` 4 档 + `itemSize`；默认色改成主题来源 | 19 条既有用例回归 |

### P1（5/5 完成）

| # | 控件 | 做了什么 | 备注 |
| --- | --- | --- | --- |
| 6 | `OhosToast` | 400 上限 + 夹屏宽、padding **16/8**、圆角 18、距底 80 | ⚠ 审计原写的 10vp 出自**智能穿戴**段落，手机真值是资源表 `toast_padding_*_api_twelve` |
| 7 | `OhosPopup` | **重写为指向型气泡**：圆角 20、箭头 16×8、`targetSpace 8`、400 上限、`bottom`/`top` 两档、放不下自动翻边 | 形态差 → 形态对 |
| 8 | `OhosMenu` | 224 固定宽（手机），电脑 224 可配、下限 64 | |
| 9 | `OhosButton` / `OhosSegmentedButton` | 448 上限 | ⚠ **上限 ≠ 必然值**，见下 |
| 10 | `OhosDivider` | `1px` **物理像素**（`1 / dpr`）、`vertical`、`#33182431` | 0.5vp 在三档密度给出三种线 |

### P2（4/4 完成，但第 11 项只做了 Switch 侧）

| # | 控件 | 做了什么 | 偏离 |
| --- | --- | --- | --- |
| 11 | `OhosSwitch` | `OhosSwitchStyle{pointRadius, unselectedColor, pointColor, trackBorderRadius}` + `pointColor` | ✅ 官方 `switchStyle` 明写「仅当 type 为 Switch 生效」，**`OhosToggleButton` 不是该属性的目标**，故未加 —— 审计把两者合并为一项是对官方语义的宽松读法 |
| 12 | `OhosCheckbox` | `OhosCheckboxShape{circle, roundedSquare}`（**默认改 CIRCLE**）+ `OhosCheckboxMarkStyle{strokeColor, strokeWidth, size}` + `unselectedColor`；勾改手画 | 勾从 `Icons.check_rounded` 换成 `CustomPaint`：字体字形的线宽改不了，`mark.strokeWidth` 落不了地 |
| 13 | `OhosSelect` | 4 色 + `showDefaultSelectedIcon`（**默认改 false**）+ `OhosSelectMenuAlign` 3 档 + `OhosSelectArrowPosition` 2 档 + `optionWidth` / `optionHeight` / `showDivider` | `center` / `end` 对齐是**近似**：`showMenu` 定位先于布局，拿不到菜单实际宽度 |
| 14 | `OhosChip` | `suffixSelectedIcon`、`backgroundColor`、`activatedBackgroundColor`、`labelColor`、`activatedLabelColor`、`labelFontSize`、`labelFontFamily`；**字重双态 400/500** | 文字色与图标色**分成两条**（官方 `LabelOptions.fontColor` 与 `prefixIcon.fillColor` 默认值不同源，老实现绑在同一个 `fg` 上，文字常态偏淡一档） |

### P3（4/4 完成）

| # | 控件 | 做了什么 | 偏离 / 备注 |
| --- | --- | --- | --- |
| 15 | `OhosList` | 新增 **`OhosList.scrollable`** 形态：`CustomScrollView` + 固定高度；`OhosListLanes`（`OhosFixedLanes` 列数 / `OhosLanesByWidth` 最小列宽，`gutter` 间距）；`OhosListDivider` 对象形态（四字段）；`sticky` **广播**到每个 `OhosListGroup`；`onReachStart` / `onReachEnd` / `onScrollIndex` | ① 静态形态（原 4 参数）**保持 0.5 的观感**，滚动能力走新构造器 —— 直接改成滚动容器会让所有既有布局凭空多出一个视口高度；② 分割线默认**仍是 `true`**，与官方「默认无分割线」相反，要官方口径就传 `divider: null`；③ `sticky` 的 `footer` / `both` 传进来组尾仍不吸底（理由见下方 `OhosListGroupSliver` 的既有注释）；④ `onScrollIndex` 是**按等高项估算**的近似值；⑤ 多列**只能用 `SliverCrossAxisGroup`**，`SliverGrid` 会把行高钉死并溢出 |
| 16 | `OhosImage` | `OhosImageFit`（8 档，官方 `ImageFit` 语义）、`alt` → `placeholder`、`errorPlaceholder`（官方 `ImageAlt` 22+ 的第二张图）、`onError`（`OhosImageError`）、`onComplete`（`OhosImageLoadInfo` **9 字段**，`loadingStatus` 0 与 1 各回调一次） | ① 占位图与图片**共用同一个 `fit`**（官方原话「占位图支持使用 objectFit 设置填充效果，与图片的填充效果一致」）；② `ImageFit` **不能**用 `BoxFit` 顶替，新增 `original` 档（原尺寸且不裁，`BoxFit` 无对应值）；③ `onComplete` 在 Flutter 只有一次合成回调，本库**照官方的次数与顺序**连发两条 |
| 17 | `OhosTextClock` | `OhosTextClockController`（`start()` / `stop()`，默认 `started = true`）、`timeZoneOffset`（**官方符号**：东八区传 `-8`，范围 `[-14, 12]`，十个半小时档不取整）、`onDateChange`（Unix **秒**）、`hourFormat`（官方 `dateTimeOptions` 的两个取值）、官方 `format` 全部十个字母；不可见时停走（`TickerMode`） | ① 旧参数 `String? timeZone` **是空操作**（实现只做 `toUtc().toLocal()` 恒等变换），已替换为官方的 `timeZoneOffset`；② 星期名只覆盖中英两套 —— `flutter_test` 只装 `en` 一套 localization，`Localizations.localeOf` 恒给 `en_US`，故新增 `locale` 显式入口；③ 格式串**必须逐字符扫描**，链式 `replaceAll` 会让已吐出的结果被后续模式再吃一遍 |
| 18 | `OhosActionBar` | `margin`（官方 6.1.0(23)）| **本轮复核发现已经在 HEAD 里**（`OhosActionBarStyle.margin` + `EdgeInsets.symmetric(vertical:)`），语义与官方「上下边距」一致，无需改动 —— 审计 §5 这一条是过期待办 |

### 四条实施中才发现的新事实（P3 轮次）

1. **链式 `replaceAll` 做模板格式化是错的。** `OhosTextClock` 第一版按
   「长字母先替换、单字母后替换」写，`yyyy年M月d日 EEEE` 实测吐出
   `2026年11月7日 51下午t` —— `EEEE` 换成 `Sat` 之后，单字母 `a` 把 `Sat` 里的
   `a` 替换成「下午」、单字母 `S` 把 `S` 替换成毫秒。`aa hh:mm:ss` 同理被拆成
   「下午下午」。正确做法是**一次扫描、逐字符吐结果**：先吃同名字母的整段
   （`EEEE` 一段、`H` 一段），再查表。这在 Dart 上几乎不会自然想到，因为
   `replaceAll` 的直觉就是「顺序写对就行」。
2. **`SliverGrid` 的 `childAspectRatio` 会把行高钉死。** `OhosList` 的多列第一版
   用 `SliverGrid`，`example` 的溢出矩阵当场报 `RenderFlex overflowed by 13
   pixels`：360 屏两列时每格 160 宽、按 200/56 的比例只给 **44.8** 高，而
   `OhosListTile` 常规档自然高是 **53**。官方 `lanes` 只说列数、行高由
   `ListItem` 自己的高决定，所以改用 `SliverCrossAxisGroup` 按行并排、行高按
   内容。**这条只有「真 pump 到固定尺寸」的用例能抓到，静态分析看不见。**
3. **`Localizations.localeOf` 在 `flutter_test` 里恒给 `en_US`。**
   `MaterialApp(locale: Locale('zh'))` 解析出来仍是 `en_US` —— 默认的
   `GlobalMaterialLocalizations.delegate` 只带 `en` 一套支持列表，中文被
   「最近的可用语言」规则回落。想断中文星期名必须走显式参数。
   这是「测试环境与真机不同」的又一处，与既有的「`flutter_test` 默认
   `DefaultTextStyle` 带 `#FFFF00`」是同一类。
4. **`_componentSize` 不能靠 `context.findRenderObject()` 在首帧前读。**
   `OhosImage` 的 `onComplete` 第一版用 `SynchronousFuture` 交付图源，
   回调落在 `pumpWidget` 内部、还没布局，`componentWidth` 读到 0，所有
   偏移量的断言都是错的。异步交付才落在 `pump()` 之后。**「测出来的数不对」
   有时是实现问题，有时是测试的交付时机问题** —— 这一条与 `OhosButton`
   的 448 那次同类：先怀疑实现，其实要先确认观测点。


1. **紧约束下的「最大宽度」不存在。** `SizedBox(width: 700)` 给的是**紧约束**，
   `ConstrainedBox.maxWidth` 与 `Align(widthFactor:)` 都会被
   `constraints.constrain()` 夹回 700 —— 实测两种写法渲染都是 700。
   **没有任何 Widget 能在紧约束下变窄**。448vp 的真实语义是「父级不限宽时
   不无限拉伸」，所以断言必须用松约束父级（`Align`）去测。
   这一条把「实现没修好」与「测试写错了」区分开了：先后两次改实现都是 700，
   第三次才发现是断言本身在要求一个布局模型不允许的事。
2. **`SwitchStyle.pointRadius` 的默认值是算法不是常数**：`h/2 - 2*h/20`。
   30 高给 **12**（不是 13，一度算错），44 高给 17.6。老实现 `h - 4` 在 30 高
   给半径 13 —— **直径** 26 与 24 看起来接近，是半径口径不同。测试要挑 44 高
   才能把两条公式分开，只测 30 高的话两条都落在 12/13 附近，区分度不足。
3. **`policy.isMonochrome` 在组件层是禁用的**（`system_theme_test` 强制）。
   本轮重写 Toast 与改 Indexer 时各踩一次。正确判据是问策略「这个颜色能否在
   你那块屏上原样表达」：`policy.quantize(c) == c`（彩屏原样返回、灰阶必然不等）。
   `tint` **不能**用作这种探测：它的阈值是 ≤20%，而 toast 遮罩是 90%，两边都
   返回非透明，探不出差别。
