# 上游资料知识库（官方镜像）

> 四层官方资料 + 一条刷新命令。**本目录是上游镜像**：只有 `README.md`、`sources.json`、
> `manifest.json`、`source/README.md` 四份说明性文件入库，其余全部由 `tool/upstream.sh` 重抓。
>
> 换机器、清缓存、隔几个月回来续做，都从这里开始。不要直接调 `tool/fetch_*.sh` ——
> 那条路径不写 `manifest.json`，快照会悄悄变旧而没人发现。

## 为什么是四层

四层不是「四个来源」，是四个**回答不同问题**的层。少一层不会报错，只会让判断静默降级成猜测。

| 目录 | 回答什么 | 上游 | 规模 | 抓取脚本 |
| --- | --- | --- | --- | --- |
| `design/` | 控件**怎么用**、视觉规则、布局与间距；**具体数值常只写在配图里** | `doccenter-ux-design/<slug>.md` | 42 份 + 608 张图，180MB | `fetch_ux_images.sh` |
| `api/` | 一个控件有**几个形态**、每个形态的**默认值**、官方示例代码 | OpenHarmony `docs` 仓 / `doccenter-references` | 56 份，442 个示例 | `fetch_reference.sh` |
| `source/` | 源码里**硬编码**的几何常量 | `arkui_ace_engine` 仓 `advanced_ui_component/` | 29 份 `.ets` | `fetch_source.sh` |
| `resources/` | `$r('sys.float.*')` 这类**令牌的真实数值** | `global_system_resources` 仓 | 3 份 JSON | `fetch_sys_resources.sh` |

具体到「查一个控件的规格」，顺序是：**先 `design/` 建立形态全集 → 再 `api/` 拿默认值 →
最后 `resources/`（必要时 `source/`）把令牌名换成数字**。

- 只有 `design/` → 知道长什么样，不知道默认值；
- 只有 `api/` → 知道属性表，不知道「同一个控件在三类设备上各有一套数值」；
- 只有 `source/` + `resources/` → 有数字，但不知道这些数字对应哪个形态。

拆成四层之前的教训值得留着：0.5 只读了设计规范（相当于只有 `design/`），于是把「滑块是单值还是双值」
「进度条有几种」「列表分组该长什么样」三件事全判错了 —— 缺的正是 `api/` 这一层。反过来，0.6 早期把
`HdsActionBar` 这类闭源组件判成「上游无文档、规格只能猜」，也是因为没找对路径
（`doccenter-references/api/ui-design-<slug>.md` 一直存在）。**「文档没有」和「没找到」是两件事，
后者更容易骗过自己。**

## 一条命令

```zsh
./tool/upstream.sh              # 四层全抓 + 重建派生索引 + 刷新清单
./tool/upstream.sh status       # 只看现状：每层多少文件、多大、最新文件时间
./tool/upstream.sh verify       # 重新统计并与 manifest 比对（不一致非零退出）
./tool/upstream.sh api|source|resources|ux   # 只刷某一层
./tool/upstream.sh index        # 不联网，重跑配图扫描与规格汇总
```

`status` 打印的就是 `manifest.json` 里的四层统计。`verify` 只比**数量与字节数**，不比 mtime
（本地 checkout 会改 mtime，不可靠）；**字节数变了就说明上游动过**，这正是该重跑的时机。

派生文件（入库，重抓后要一起提交）：

| 文件 | 内容 | 谁生成 |
| --- | --- | --- |
| `doc/ux-images.index.json` | 608 张图 → 所在文档的**原文上下文** | `fetch_ux_images.sh` |
| `doc/ux-images.scan.json` | 每张图的尺寸、彩色占比、**标注色判定** | `scan_ux_images.py` |
| `doc/UX-IMAGES-INDEX.md` | 上面那份的可读版 | `scan_ux_images.py` |
| `doc/ux-specs/<slug>.md` | 逐控件**人工精读**结论（27 份） | 逐张读图后手写 |
| `doc/UX-SPEC-FROM-IMAGES.md` | 233 条图值的汇总与形态分组 | `make_spec_summary.py` |

## 四条抓取链路（别混）

### 1. 开源 ArkUI 组件 → `raw.gitcode.com`

```
https://raw.gitcode.com/openharmony/docs/raw/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/<组件名>.md
```

> 2026-11 起 OpenHarmony 各仓在 GitCode（`https://gitcode.com/openharmony/<仓>`）。raw 直链**必须**用
> `raw.gitcode.com`：`gitcode.com/openharmony/docs/raw/...` 与 `.../-/raw/...` 都只返回一张 HTML 页面，
> **状态码仍是 200** —— 必须校验首行是不是 `# ` 才知道拿错了。
>
> 旧 gitee 地址已于同批迁移：`docs` 仓的 raw 尚可访问（302 到 `raw.giteeusercontent`），
> 但目录 API `api/v5/repos/.../contents` 已全线 `403 Rate Limit Exceeded`。
> `fetch_source.sh` 依赖目录 API 列真实文件名（不猜文件名），那边是非迁不可。

中文站参考页（`harmonyos-references/*`）是 SPA，静态抓取只会拿到 404 页；页面里
`<link rel="alternate" type="text/markdown">` 指向的 `.md` 地址同样返回 404。所以改抓 OpenHarmony
仓库 —— 内容与官网同源，且自带完整的 ArkTS 示例代码（官网 SPA 渲染出来的就是这些）。

高阶组件文件名是**大写开头**：`ohos-arkui-advanced-Chip.md`，小写会 404。

### 2. 闭源 HDS 组件 → `doccenter-references`

```
https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-<小写slug>.md
```

slug 必须全小写，`ui-design-hdsActionBar.md` 会 404。同一前缀下 `ui-design-hdssearch` /
`ui-design-hdsbutton` / `ui-design-hdsswitch` 确实 404（那些组件确实没有文档），
**所以抓取失败必须当失败报出来，不能静默跳过** —— 否则「真没有」和「抓丢了」分不开。

### 3. 设计规范 + 配图 → `doccenter-ux-design`

```
https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/<slug>.md
```

slug 来自概览页 `general_overview-*.md` 里的 42 个控件链接，**不要猜**（见 `tool/trace_control_docs.sh`）。

配图 URL 在正文 `![...](https://contentcenter...)` 里，按「文档短名_序号」落成
`design/img/<slug>_NN.png`。**图必须一起抓**：设计规范正文只写令牌名，具体数值往往只写在配图的标注里，
而且漏得很安静 —— 看起来「文档读过了」。

### 4. 源码与资源 → `raw.gitcode.com`（两个仓）

```
advanced_ui_component/<组件>/source/*.ets                          → source/
global_system_resources/.../systemres/main/resources/base/element/ → resources/
```

`resources.index` 是二进制（RestoolV2），`strings` 只读得到令牌名；但它就是上面三份 JSON 的编译产物，
**直接读源文件即可**。三份表键不重，**两张表都要查**：

| 文件 | 条目数 | 装什么 |
| --- | --- | --- |
| `pattern.json` | 67 | 组件主题模式（`ohos_search_pattern` 等） |
| `float.json` | 1080 | 基础设计令牌：`ohos_id_*` / `padding_levelN` / 字阶 |
| `float_sys.json` | 507 | 组件级令牌：`chip_*` / `search_*` / `subheader_*` |

> 别记行数（会因缩进空行虚涨），记条目数。查真值用：
>
> ```zsh
> for p in doc/reference/resources/*.json; do
>   echo "== $p"
>   P="$p" python3 -c "import json,os;d=json.load(open(os.environ['P']));\
> print([(i.get('name'),i.get('value')) for i in d.get('float') or [] if 'chip_normal' in str(i.get('name'))])"
> done
> ```

## 规模（`./tool/upstream.sh status` 现算，别手抄）

| 层 | 文件 | 体积 | 构成 |
| --- | --- | --- | --- |
| `api/` | 56 | 3.1MB | OpenHarmony 44 份 + HDS 8 份 + 反查 4 份 |
| `design/` | 42 + 608 张图 | 180.5MB | 42 份设计规范；608 张配图 |
| `source/` | 29 | 1.4MB | `.ets` |
| `resources/` | 3 | 553KB | `float` / `float_sys` / `pattern` |

`api/` 的 56 = 44（`ts-*` 37 + `ohos-arkui-advanced-*` 7）+ 8 份 HDS + 4 份反查。
**反查 4 份**是 `hds-ohos-arkui-advanced-chipgroup`（子页签）/ `hds-ts-methods-custom-dialog-box`（弹出框）/
`hds-ts-universal-attributes-sheet-transition`（半模态面板）/ `hds-arkts-apis-uicontext-promptaction`（即时反馈）——
它们在 OpenHarmony 仓里按原名取不到，是从设计文档末尾「## 开发文档」的链接反查出来的，
单独列在 `fetch_reference.sh` 的 `SPEC_COMPONENTS` 表里，为的是让「这份文档是怎么找到的」在脚本里留痕。

**示例数 442**（口径：优先数 `### 示例N`；一份文档只有 `## 示例` 而没有三级小节时整份记 1）。
这个数字是「我们照官方做了多少个形态」的分母。复核：

```zsh
cd doc/reference/api && total=0
for f in *.md; do
  n=$(grep -cE '^### 示例[0-9]' "$f"); h=$(grep -cE '^## 示例' "$f")
  [ "$n" -eq 0 ] && [ "$h" -gt 0 ] && n=$h
  total=$((total+n))
done; echo $total
```

> 这个数改过三次：369 → 402 → **442**。前两次是手抄漏项，这次是上游确实新增了示例。
> **只信 `./tool/upstream.sh status` 的输出**，别把数字抄到别处再引用。

## 已知缺口（都是「确实没有」，不是「没找到」）

- **`EditableTitleBar` 的参考文档确实 404** —— 试过 `ui-design-editable-title-bar` /
  `ui-design-editabletitlebar` / `hdseditabletitlebar` / `hdseditabletitle-bar` 全 404，
  `HdsNavigation` 里也无对应章节。**但规格并不缺**：`source/editabletitlebar.ets` 958 行，
  栏高 56 / 标题 20vp / 副标题 14vp / 主副标题占宽 0.65:0.35。引用时须写明「来自源码，不是参考文档」。
- **`HdsSearch` / `HdsButton` / `HdsSwitch` 确实没有文档**（对应 slug 全 404）。
- **平板 / 大屏在配图层零信息**：「智慧屏」在 42 份设计文档里出现 **0 次**（官方叫「大屏」）；
  带「平板」上下文的图 16 张，**全部 0 像素标注色**，抽验 `segmentbutton_11.png` 是三台设备并排的
  纯布局示意。这类规格只写在**正文表格**里（`segmentbutton` 448vp、`button` 448vp + 12vp、
  `bottomtab` 360vp），走 `design/*.md` 正文，不要指望配图。
- **5 个控件在配图层对手机零产出**：`alphabetindexer` / `scrollbar` / `subheader` / `toggleswitch` / `toast`
  —— 它们所有带标注的图都是手表形态。这些控件的手机值只能回 `api/` 与 `resources/`。
- `color-picker` 的设计文档没有「## 开发文档」链接（官方漏链接），但 `hds-hdscolorpicker.md` 确实存在，
  已收录。

## 配图层怎么再处理

```zsh
./tool/upstream.sh ux                   # 1. 抓 42 份规范 + 608 张图
python3 tool/scan_ux_images.py          # 2. 筛候选（标注色）→ scan.json + INDEX.md
python3 tool/zoom_annotations.py --all  # 3. 裁标注区放大 → /tmp/ux_zoom/
# 4. 逐张读 /tmp/ux_zoom/*.png（视觉读图），结论写 doc/ux-specs/<slug>.md
python3 tool/make_spec_summary.py       # 5. 汇总 → UX-SPEC-FROM-IMAGES.md
```

三个必须记住的判据：

- **标注色是 `#E40078`（228,0,120），不是纯洋红。** 按 `b>190` 判会让 `subheader_11` 得 0 像素
  —— 那张明明有三处标注。判据要用**色相窗口 300–350°** + 饱和度下限。
- **「大尺寸 + 灰阶」不能当「含标注」的判据**：会多给 194 张，抽验全是形态示意。
  尺寸只说明导出规格，不说明内容。
- **形态必须跟着数值走。** 官方「控件规格」按 手机 / 平板 / 大屏 / 智能穿戴 分节，同一控件各一套数值。
  233 条图值里 **149 条是穿戴形态（64%）**，只有 84 条能对手机令牌。混用会凭空造出「问题项」
  —— 已经犯过一次：把穿戴子标题的「安全距离 10」当成手机 `subheader_title_margin_bottom = 12vp`
  的问题项。当前范围只做手机 / 平板 / 大屏，**穿戴一律排除**。

标注文字在原图里只有 10–14px，直接看整张图读不出来，必须先裁剪放大 —— 这也是
`zoom_annotations.py` 存在的原因。`scan.json` 里每张图都带 `ctx`（所在段落的原文），
判断「这个数值属于哪个形态」靠它，不靠猜。

## 本目录的入库边界

| 入库 | 不入库（`.gitignore`） |
| --- | --- |
| `README.md`、`sources.json`、`manifest.json` | `api/`（56 份上游原文） |
| `source/README.md` | `design/`（42 份 + 608 张图，180MB） |
| `../ux-images.index.json`、`../ux-images.scan.json` | `source/*.ets` |
| `../ux-specs/*.md`、`../UX-SPEC-FROM-IMAGES.md` | `resources/`（3 份 JSON） |

判断依据：**提交「从哪抓、抓了多少、什么时候抓的」与「我们据此得出的结论」；不提交上游原文本身**
（会漂移、体积大、且有版权顾虑）。

## 文件名约定

与上游一致；HDS 与反查的 4 份加 `hds-` 前缀以免和 ArkUI 组件撞名；配图 `<文档短名>_NN.png`。
重抓时直接覆盖，不做增量合并 —— 增量合并会让「同一份文档里一半新一半旧」，比整份旧更危险。
