# 组件实现源码（本地快照）

`*.ets` 由 `tool/fetch_source.sh` 生成，`systemres/*.json` 由 `tool/fetch_sys_resources.sh` 生成，**均已加入 `.gitignore`，不入库**（上游内容、约 1.6MB、会与上游漂移）。本 README 入库，说明来源与这两层各解决什么问题。

## 这一层解决什么问题

前两层（设计规范、组件参考文档）回答「有哪些属性和形态、默认值是什么」，但**答不了「具体画多大」**：

> 官方 `Chip` 文档写：「高度默认值：`$r('sys.float.chip_normal_height')`」

这不是数值，是一个资源令牌的**引用**。要拿到真值有两条路，本目录两种快照各管一半：

| 快照 | 回答 | 来源 |
| --- | --- | --- |
| `*.ets` | 源码里**硬编码**的部分 | `raw.gitcode.com/openharmony/arkui_ace_engine/raw/master/advanced_ui_component/<组件>/source/*.ets` |
| `systemres/*.json` | **令牌**的真实值 | `raw.gitcode.com/openharmony/global_system_resources/raw/master/systemres/main/resources/base/element/` |

> **仓址（2026-11 迁到 GitCode）。** 旧地址 `gitee.com/openharmony/arkui_ace_engine` 已作废，新仓 <https://gitcode.com/openharmony/arkui_ace_engine>。raw 直链必须走 `raw.gitcode.com`（`gitcode.com/<仓>/raw/...` 与 `/-/raw/...` 只返回 HTML，状态码仍 200）；目录列表 API 走 `api.gitcode.com/api/v5/repos/.../contents/<路径>?ref=master`，与 raw 是**不同 host**。迁移的动因是旧 gitee 的目录 API 已全线 403 —— 而那正是本层「不猜文件名」的依据。

> **这张表的分工是按「上游当时怎么写的」分的，不是按「来源」分的。** 原来的说法是「源码答硬编码、资源表答令牌」，但 2026-11 上游连续把常量从字面值改成了令牌引用——
>
> - `subheader.ets`：`const OPERATE_ITEM_LENGTH = lazyInit<number>(() => getResourceValue('sys.float.subheader_right_arrow_height'));`
> - `chip.ets`：高度从 `enum ChipGroupHeight { NORMAL = 36, SMALL = 28 }` 改成 `size: ChipSize.NORMAL` + `normalHeight: $r('sys.float.chip_normal_height')`
>
> —— 源码现在**只说令牌名**，真值要回到 `float.json` / `float_sys.json` 查。所以判据应当是：**同一个字段，哪个来源给得出具体数值就用哪个**，给不出就换另一边。本轮已核对这两批令牌的真值与原来的硬编码**完全一致**（subheader 24 / 12 / 28 / 24vp，chip 36vp / 28lpx），故既有实现无需改动。

硬编码的典型例子（**只给查找键，不给行号** —— 见下方说明）：

- `chipgroup.ets`：`chipGroupSpace: { itemSpace: 8, startSpace: 16, endSpace: 16 }`
- `chip.ets`：`minLabelWidth: 12`、`borderWidth: 2`、`normalMargin 6/6`、`breakPoint MinWidth 128 / Sm 156 / Md 280 / Lg 400`
- `editabletitlebar.ets`：`DEFAULT_TITLE_BAR_HEIGHT = 56`、`TITLE 20vp`、`SUBTITLE 14vp`、主副标题 0.65/0.35
- `counter.ets`：`COUNTER_LIST_HEIGHT = '48vp'`、`COUNTER_LIST_PADDING = 12`、`INLINE_BUTTON_ICON 24vp × 12vp`

> **别再往这里抄行号。** 上一版写的是「`chipgroup.ets` 第 46 行」「第 63 行」「`chip.ets` 第 371 行」——2026-11 一次同步之后三个全部失效：`chipGroupSpace` 往后漂了几行，`chip.ets` 那批常量则落在文件三分之一处而非三百七十行。这批 `.ets` 本就**随上游漂移、不入库**，行号是最脆弱的定位方式。要定位就直接搜键名：
>
> ```zsh
> python3 -c "import io,sys;t=io.open('doc/source/chip.ets',encoding='utf-8').read().split(chr(10));[print(i+1,l.strip()) for i,l in enumerate(t) if 'minLabelWidth' in l]"
> ```

> **`chipgroup.ets` 的 `enum ChipGroupHeight { NORMAL = 36, SMALL = 28 }` 已不存在（2026-11）。** 上游把尺寸枚举并进了 `chip.ets` 的 `ChipSize`，而且它的成员是**字符串**：
>
> ```
> export enum ChipSize { NORMAL = "NORMAL", SMALL = "SMALL" }
> ```
>
> 真值不再由枚举给出，而是 `chip.ets` 通过 `normalHeight: $r('sys.float.chip_normal_height')` / `smallHeight: $r('sys.float.chip_small_height')` 引用令牌。**注意这与 `subheader.ets` 是同一类变化**：源码从「写字面值」退化为「只写令牌名」，所以源码层现在对 chip 高度**不再答得出具体数值**，必须回 `float_sys.json` 查（36vp / 28lpx），本库实现的 36/28 经核对**未变**。

`subheader.ets` 还额外带一张 `RESOURCE_CACHE_MAP`，把「令牌 → 真实值」直接列出来。**旧版记的是「28 条」，2026-11 已增至 59 个不同的 `sys.float.*` 键**（其中 47 个是 `subheader_*`，其余是 `padding_levelN` / `margin_*` / `corner_radius_level4` 这类基础令牌）。数字会随上游漂移，用到时现数：

```zsh
python3 -c "import io,re;t=io.open('doc/source/subheader.ets',encoding='utf-8').read();print(len(set(re.findall(r'sys\.float\.([a-z0-9_]+)',t))))"
```

## 令牌的真值：`resources.index` 不是黑盒

上一版这里写着「`Search` 这类系统组件的高度/圆角，本快照仍然拿不到确切数值，只能给到令牌名」—— **这是错的**，和「闭源 ⇒ 无文档」是同一个错误模式。

`resources.index` 确实是二进制（RestoolV2），`strings` 只读得到令牌名。但它就是 `global_system_resources` 仓库里三份 JSON 的编译产物，**直接读源文件即可**：

```
systemres/main/resources/base/element/pattern.json    67 条   组件主题模式（ohos_search_pattern 等）
systemres/main/resources/base/element/float.json    1080 条  基础设计令牌：ohos_id_* / padding_levelN / 字阶
systemres/main/resources/base/element/float_sys.json  507 条  组件级令牌：chip_* / search_* / subheader_*
```

> **数条目，别数行。** 上一版这里记的是行数（9701 / 4112 / 1816），2026-11 一次同步后变成 10208 / 4324 / 2032 —— 行数取决于上游的格式化，`float_sys.json` 甚至因为多了空行和缩进写法就涨了 12%，条目数却只增不减、更适合作为基准。现数：
>
> ```zsh
> python3 -c "
> import json, glob
> for p in sorted(glob.glob('doc/source/systemres/*.json')):
>     d = json.load(open(p, encoding='utf-8'))
>     print(p, len(d[list(d)[0]]), '条')
> "
> ```

**两张 float 表合起来才构成 `sys.float` 命名空间，键不重复，别以为一张是另一张的索引**（我第一版就这么以为，写错了）：

| 键 | 在哪张表 | 值 |
| --- | --- | --- |
| `search_default_height` | `float_sys.json` | `$float:ohos_id_search_default_height`（别名） |
| `ohos_id_search_default_height` | `float.json` | `40.0vp`（真值） |
| `chip_normal_height` | `float_sys.json` | `36.0vp`（**直接是数字**，无别名） |
| `chip_normal_text_padding` | `float_sys.json` | `16`（直接是数字） |
| `subheader_single_title_height` | `float.json` | `56vp`（就在这张表里） |

所以「`float_sys` 是别名表、`float` 是真实值」只对了一半 —— 有些键在 `float_sys` 里就是最终数字（`chip_*` 几乎全是）。**解析器必须两张表都查**，不能规定哪张只能当跳板。

> 单位坑：`chip_small_height` 与 `chip_activated_small_height` 写作 **`28.0lpx`**，全表仅此两处用 `lpx`。`lpx` 是逻辑像素，默认配置下数值与 vp 相等，但不随字体缩放。按 **28** 处理即可，**别在代码注释里写成「28vp」** —— 单位语义不同。

解析步骤（`tool/fetch_sys_resources.sh` 已实现）。以 `Search` 高度为例：

```
search_theme.h 读 "search_default_height"
  → pattern.json  ohos_search_pattern 里            $float:search_default_height
  → float_sys.json                                  $float:ohos_id_search_default_height
  → float.json                                      40.0vp
```

> **坑**：pattern 层与 float_sys 层的键**可能同名**。若解析器在 pattern 里反复回查就会自引用成环，输出一长串 `-> $float:xxx -> $float:xxx ...`。正确做法是 pattern 层只跳一次，之后只查 float_sys / float。

### `Search` 全部尺寸（`search_theme.h` 逐个 `GetAttr` 的键）

| 令牌 | 值 | 含义 |
| --- | --- | --- |
| `search_text_field_border_radius` | 20 | 圆角 |
| `search_default_height` | 40 | 默认高度 |
| `search_height` | 56 | **死令牌，无调用方** —— 见下 |
| `search_icon_size` / `search_icon_height` | 16 / 16 | 放大镜图标 |
| `search_icon_left_space` / `_right_space` | 12 / 8 | 图标左距 / 图标与文字间距 |
| `search_close_icon_size` | 16 | 清除按钮图标 |
| `search_close_icon_hot_zone_horizontal` | 40 | 清除按钮命中区 |
| `search_text_field_padding_left` | 4 | **死令牌，无调用方** —— 见下 |
| `search_text_field_right_padding_without_button` | 12 | 无按钮时右边距 |
| `search_text_field_right_padding_with_button` | 0 | 有按钮时右边距 |
| `search_button_space` / `search_divider_side_space` | 2 / 2 | 按钮、分隔线间距 |
| `search_button_text_padding` | 14 | 搜索按钮文字 padding |
| `search_border_width` | 0 | 默认无描边 |
| `search_focus_padding` | 1 | 聚焦光边厚度 |

### `Chip` 全部尺寸

| 令牌 | 值 |
| --- | --- |
| `chip_normal_height` / `chip_activated_normal_height` | 36vp |
| `chip_small_height` / `chip_activated_small_height` | 28 **lpx**（非 vp） |
| `chip_normal_radius` / `chip_border_radius_normal` | 18 |
| `chip_small_radius` / `chip_border_radius_small` | 14 |
| `chip_normal_text_padding` / `chip_small_text_padding` | 16 / 12 |
| `chip_normal_text_margin` / `chip_small_text_margin` | 6 / 4 |
| `chip_normal_icon_size` / `chip_small_icon_size` | 16 / 16 |
| `chip_normal_font_size` / `chip_small_font_size` | 14fp |
| `chip_border_width` | 0 |
| `chip_normal_shadow_style` / `chip_small_shadow_style` | -1（无阴影） |
| `chip_focused_btn_scale` | 1（聚焦不放大） |
| `chip_show_close_icon_margin` | 0（决定后缀图标的焦点/回车删除行为，不是尺寸） |
| `chip_activated_normal_text_padding` / `chip_activated_small_text_padding` | 16 / 12 |
| `chip_activated_border_width` | 0 |

> **第二处死令牌：`search_height = 56`。** 它与 `search_text_field_padding_left` 形状完全一致 ——
> 在 `ohos_search_pattern` 里有值（`$float:ohos_id_search_height` → `56.0vp`）、被编译进
> `resources.index`，看起来完全「生效」，唯独没有调用方：
>
> - `grep -rn search_height` 在 13 份 `search/` 源文件（`search_theme.h` / `search_pattern.cpp` /
>   `search_layout_algorithm.cpp` / `search_model_ng.cpp` / `search_model_static.cpp` / `search_node.cpp` /
>   `search_pattern_multi_thread.cpp` / `search_textfield.cpp` / `search_gesture_event_hub.cpp` /
>   `render_search.cpp` / `rosen_render_search.cpp` / `search_pattern.h` / `search_layout_property.h`）**零命中**。
> - `SearchTheme::height_` 只有**一个**赋值来源：`search_theme.h:65` 的 `search_default_height`（= 40）。
>   `GetHeight()` 的 5 个调用点（`:134` `:324` `:328` `:452` `:561`）读的全是它。
> - 官方 30 个 `Search` 示例里配了 `.searchButton()` 的 3 处**全都写 `.height(40)`**。
>
> 所以「带搜索按钮时整栏高 56」这个说法不成立，本库栏高保持 40。**这也给出一条好用的交叉验证：
> 官方示例是给人抄的，作者会把生效值直接写出来；示例里的 `.height()` 与某个令牌对不上时，
> 多半是令牌没被用，而不是示例写错了。**

> **`search_text_field_padding_left = 4` 是死令牌。** `search_theme.h:71` 把它读进 `leftPadding_`，但
> `GetLeftPadding()` 在整个 `search/` 目录**零调用方**（`search_pattern.cpp`、`search_layout_algorithm.cpp`、
> `search_model_ng.cpp`、`search_text_field.cpp`、`search_pattern.h`、`search_layout_property.h`、
> `search_node.cpp` 逐个查过），是旧框架 `frameworks/core/components/search` 的遗留字段。
>
> 真正的水平几何在 `search_layout_algorithm.cpp` 的 `LayoutSearchIcon`(`:738`) / `LayoutTextField`(`:929`)：
> ```
> iconX  = padding.left + search_icon_left_space           // 12
> fieldX = iconWidth + search_icon_left_space + search_icon_right_space  // 12 + 8
> ```
> 所以**判「令牌是否生效」不能只 grep `GetAttr`，必须再 grep 调用方** —— 命中 `GetXxx()` 的定义不算证据。
> 对照之下 `GetRightPaddingWithoutButton` / `WithButton` 是**有**调用方的（`:223` / `:227`），但它们只参与
> 「算 textField 可用宽度」，也不是盒内 padding，不能一刀切地按「有没有调用方」判断。

## 子标题的真实数值（`subheader.ets` 的 `RESOURCE_CACHE_MAP`）

| 令牌 | 值 | 含义 |
| --- | --- | --- |
| `subheader_single_title_height` | 56 | 单标题行高 |
| `subheader_single_subtitle_height` | 56 | 单副标题行高 |
| `subheader_double_height` | 72 | 主副标题双行 |
| `subheader_title_font_size` | 18 | 标题字号 |
| `Subtitle_S` | 14 | 副标题字号 |
| `subheader_subtitle_font_weight` | 400 | 副标题字重 |
| `subheader_title_font_weight` | 700 | 标题字重 |
| `subheader_titles_space` | 2 | 主副标题间距 |
| `subheader_left_icon_size` | 16 | 左图标尺寸 |
| `subheader_left_icon_end_margin` | 8 | 图标与文字间距 |
| `subheader_content_margin_start` / `_end` | 16 / 16 | 内容左右边距 |
| `subheader_content_padding` | 8 | 内容 padding |
| `subheader_single_subtitle_padding` | 12 | 单副标题 padding |
| `subheader_select_padding` | 4 | 选择区 padding |
| `padding_level0..6,8` | 0 / 2 / 4 / 6 / 8 / 12 / 16 | 通用间距阶梯 |
| `corner_radius_level4` | 8 | 圆角 |
| `Body_L` | 16 | 正文字号 |

**这张表与 `float.json` 逐个吻合**（56 / 56 / 72 / 18 / 14 / 2 / 16 / 8 / 16 全对），两条独立链路互证，说明上面的解析路径可靠。

## 抓取范围

`*.ets` 只抓 **ArkTS 实现的进阶组件**（`advanced_ui_component/<组件>/source/*.ets`），共 29 份。

系统组件的 C++ 侧（`frameworks/core/components_ng/pattern/<组件>/`）几何值几乎全走 `theme->GetAttr("...")`，硬编码极少 —— 实测 `search_layout_algorithm.cpp` 1056 行里只有一条 `DEFAULT_DIVIDER_HEIGHT = 12.0_vp`，`search_theme.h` 431 行全是 `GetAttr(..., 0.0_vp)` 兜底。**所以 C++ 侧不必抓**：数值不在那里，在 `systemres/*.json` 里。

## 文件名不一定等于目录名

**这是本层最容易踩的坑**，且不一致的方式还不统一：

| 目录 | 实际文件名 |
| --- | --- |
| `chip` | `chip.ets` |
| `gridobjectsortcomponent` | `GridObjectSortComponent.ets` |

试「首字母大写」对后者仍然 404（它是全驼峰，不是简单首字母大写）。所以脚本**用 API 列目录取真实 `.ets` 文件名**，不猜。

同理，`search_theme.h` **不在** `components_ng/pattern/search/`（该目录 21 个文件，无 theme），实际在 `components/search/search_theme.h`。这是同一个错误的第四次出现。

## 用法

```zsh
./tool/fetch_source.sh         # 重抓 ArkTS 源码；失败打印 FAIL 行并非零退出
./tool/fetch_sys_resources.sh  # 重抓 systemres/*.json 并打印 search/chip/subheader 真值
./tool/fetch_sys_resources.sh search_   # 只看指定前缀
```

两个脚本都会重新下载并覆盖，`README.md` 不在清理范围内。