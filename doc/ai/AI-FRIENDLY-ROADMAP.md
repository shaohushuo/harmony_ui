# 让 harmony_ui 对 AI 友好：诊断与分层方案

> 本文是方案与待办清单。已落地的部分标 ✅，后续项标 ⬜。
> 相关入口见根目录 `AGENTS.md`、`llms.txt`。

## 1. 诊断：问题不是「文档少」

先把现状量出来（全部由 `tool/gen_ai_catalog.py --stats` 与现场统计得出，不是引用旧文档）：

| 项目 | 实测 |
| --- | --- |
| barrel 导出的公开 dart 文件 | 79（`lib/src` 共 80 个，`ohos_arc.dart` 故意不导出） |
| 公开符号 | 239（163 class / 56 enum / 1 typedef / 19 顶层函数） |
| 公开构造器 | 188 |
| 源码里带 ```` ```dart ```` 的文档注释 | 26 处（24 个符号有可复制示例） |
| README 里的 Dart 示例块 | 27 个 / 1267 行 |
| 人读文档总量 | README 63 KB + CHANGELOG 166 KB + CONTROL-MATRIX 102 KB + ROADMAP 127 KB ≈ **460 KB**，另 655 张配图 |
| 标准 AI 入口文件 | **0 / 7**（`AGENTS.md` / `CLAUDE.md` / `.cursorrules` / `copilot-instructions.md` / `llms.txt` / `llms-full.txt` / `dartdoc_options.yaml` 全缺） |
| 描述**本库 API** 的 JSON | **0**（原有 7 个 JSON 全是上游配图索引与 OHOS 资源表） |
| 官方形态矩阵 | 102 KB Markdown，本次压成 94 个符号的 `officialForms` 字段 |

**源码注释质量其实很高**：`ohos_action_bar.dart` 写清「官方 17 个属性只落 12 个」「`adaptive` 读不到硬件档位所以与 `enabled` 等同，`OhosButtonMetrics` 写清「448vp 之外还要再夹一次容器宽」。这些恰恰是 AI 最容易踩的语义坑。它们的问题是**散在 81 个文件里、不可一次性检索**。

更危险的是文档之间的漂移，AI 对检索到的片段比人更盲从：

- `README.md` 升级段写「**7 处**破坏性变更 / 三处不报错」，而 `MIGRATION-0.6.md` 明确是「**12 处**」；按迁移表逐格现算，其中 9 处编译报错、**3 处完全静默**（#7/#10/#12）。旧笔记里的「2 处静默」只数了审计轮，是第三种口径。本次开发过程中这三套口径都差点被照抄进 AI 说明文档——所以 `breakingSummary` 一律由表格生成，不手写。
- `doc/CONTROL-MATRIX.md` **同一文件内**第 512 行写「本版用例 444 条」，第 532 行写「仓库有 365 条用例」。
- 官方规格按手机 / 电脑 / 穿戴分节，配图标注里 149/233 条属于穿戴；AI 抓到片段就会把 15vp 当手机值用。

### 五个具体失败模式

| # | 失败模式 | 为什么编译器抓不到 |
| --- | --- | --- |
| F1 | 幻觉出 `Ohos*` 符号与参数（按 ArkUI / Material 类比） | 编译期报错，但 AI 会「自信地」反复试错，消耗大量轮次 |
| F2 | 用了 0.5.x 的旧写法 | 12 处里 3 处**完全静默**，另有多处只改了默认观感，构建全绿 |
| F3 | 语义误用：`OhosDataPanel` 现在是官方占比图，旧 KPI 网格叫 `OhosStatGrid` | 类型完全合法 |
| F4 | 违反墨水屏 / `OhosVisualPolicy` 约束 | 类型完全合法，截图才看得见 |
| F5 | 检索到过时或不同设备形态的片段 | 无信号，且片段看起来很权威 |

### 核心论点

**AI 友好的本质不是「再写一份给 AI 看的文档」，而是把单一事实源从人读散文变成机器可校验的结构化契约，并让 CI 守住它不漂移。** 再写第 8 份 Markdown 只会制造第 8 个可能过时的副本。

由此推出三条设计原则：

1. **能自动派生就不手写。** API 清单来自 barrel + 源码；12 条迁移来自 `MIGRATION-0.6.md` 的一览表；形态矩阵来自 `CONTROL-MATRIX.md` 表格。只有「编译器查不出的语义约束」才允许手写（`contract.json`）。
2. **目录是索引，不是事实。** 每条记录带 `file:line` 回指 Dart 源码；细节不复制，按需读。解析不确定的构造器标 `confidence: low`。宁可缺项，不可猜——一份错的机器目录比没有目录更危险。
3. **防漂移优先于覆盖率。** 生成器输出确定性（无时间戳、稳定排序），`--check` 才能成为真门禁。

## 2. 分层方案

### L0 可发现 — 让 AI 在 10 秒内知道去哪查

| 产物 | 状态 | 说明 |
| --- | --- | --- |
| `AGENTS.md` | ✅ | 仓库级约定：导入边界、7 条铁律、版本口径、验证命令。刻意只写**稳定原则**，易变清单放生成物 |
| `llms.txt` | ✅ | 分级索引，把「小且安全」与「大且别整体加载」分开；由生成器产出 |
| `pubspec.yaml` 元数据 | ⬜ | 补 `homepage` / `documentation` / `screenshots`；现有 `description` 仍写「Material/Cupertino-style」，与实际定位有偏差，建议改。pub.dev 的 AI 抓取与搜索都吃这些字段 |
| `.github/copilot-instructions.md` | ⬜ | 内容不必重复，一行指向 `AGENTS.md` 即可（或软链） |
| `dartdoc_options.yaml` + Pages 上生成 API 文档 | ⬜ | 给外部 LLM 一个可 fetch 的权威 API 页；`llms.txt` 也应随 Pages 发布才有外部价值 |

### L1 契约 — 机器可读的 API 事实（本次核心）

| 产物 | 状态 | 说明 |
| --- | --- | --- |
| `tool/gen_ai_catalog.py` | ✅ | 以 barrel 为唯一公开边界，解析类/枚举/typedef/顶层函数、构造器参数与默认值、枚举值、文档示例、源码注释里的官方出处线索 |
| `doc/ai/catalog.json` | ✅ | 239 符号 + 188 构造器 + 12 条迁移 + 94 符号的官方形态 + demo/test 交叉引用 + 内嵌 `contract.json`；紧凑 JSON，约 300 KB，**按需查询** |
| `doc/ai/API-INDEX.md` | ✅ | 42 KB，一行一符号（含参数默认值、⚠ 迁移标记、`file:line`），适合整体塞进上下文 |
| `doc/ai/contract.json` | ✅ | 12 条手写语义不变量（I1–I12），每条带 `why` / `severity` / `symbols` / `detect`。生成器会校验 `symbols` 里的名字仍存在于公开 API，否则退出码 2 |
| `--check` 接入 CI | ⬜ | 在 `.github/workflows/ci.yml` 加一步 `python3 tool/gen_ai_catalog.py --check`。**本次按约定没动现有 workflow** |
| `--check` 覆盖「源码改了但生成器没跟上」 | ⬜ | 目前只能发现「生成物被改/源码变了导致输出变」；建议在 CI 里同时跑生成器并重跑测试，避免解析规则本身腐化 |

一个副产品：生成器自动排除了 `ohos_arc.dart` 里的 5 个内部函数，因为它们没有被 barrel 导出。这验证了「公开边界」不是靠人工维护的清单。

### L2 可执行正确性 — 把约束变成能失败的东西

| 产物 | 状态 | 判据 |
| --- | --- | --- |
| `doc/ai/recipes/*.dart` 可编译最小用法 | ⬜ | 每个控件一个片段，作为 example 的测试目标真实 `dart analyze` + `pumpWidget`，而不是文档里的代码块。AI 复制即可用 |
| `doc/ai/invalid/` 反例库（0.5.x 旧写法 → 期望的编译错误） | ⬜ | 12 处迁移各一条；静默变更用断言而非编译错误来钉 |
| `custom_lint` 或简单脚本规则 | ⬜ | 把 `contract.json` 的 `detect` 落到 lint：`theme.monochrome` 出现在 `lib/src/widgets/`、裸 `Text` 在定宽容器、旧参数名 |
| 构造器 `/// ```dart` 示例覆盖 | ⬜ | 现状 188 个构造器 / 26 个源码示例。优先补**有静默默认值变化**的控件（`OhosChipGroup` / `OhosSelect` / `OhosCheckbox` / `OhosActionBar`），收益最高 |
| `@Deprecated` 注解 | ⬜ | 0.6.0 是集中破坏而非渐进弃用，没有保留旧符号；未来若保留过渡期，注解能让 IDE 和 AI 立刻看到迁移提示 |

### L3 检索闭环 — 一次拿到刚好够的上下文

| 产物 | 状态 | 说明 |
| --- | --- | --- |
| `tool/ai_lookup.py <Symbol>` | ✅ | 输出构造签名 + 默认值 + 参数说明 + 可复制示例 + 官方形态 + 相关迁移 + 相关不变量 + **源码 `///` 全文** + demo/test 路径；不存在的符号会明确拒绝并给候选，而不是让 AI 猜 |
| `--search <关键词>` / `--breaking` / `--json` | ✅ | 支持中文关键词找控件、按机器可读格式输出 |
| `llms-full.txt` | ⬜ | 把 `API-INDEX.md` + 全部 `recipes` 合成单文件，供一次性抓取；控制在 200 KB 内 |
| MCP server（可选进阶） | ⬜ | 把 `ai_lookup` / `token_lookup` / `upstream.sh status` 暴露成工具，让 IDE 内 Agent 主动查。收益高但引入运行时依赖，建议在 L1/L2 稳定后再评估 |

### L4 治理 — 别让这套东西变成第 8 份过时文档

| 产物 | 状态 | 说明 |
| --- | --- | --- |
| 修掉已发现的漂移 | ⬜ | README「7 处」→ 12 处；CONTROL-MATRIX 444 / 365 用例数统一为脚本现算 |
| 统计数字改为脚本生成 | ⬜ | 仓库里多次出现写死的统计值。凡是「数量」都由命令算，文档只引用生成结果 |
| 给生成器写测试 | ⬜ | 至少覆盖：命名参数默认值、多行默认值、`super.key`、方法内局部变量不得污染字段类型、未导出文件不得进目录。本次开发过程中已真实踩到后两个 bug |
| AI 生成质量评测集 | ⬜ | 见下节 |

## 3. 怎么衡量「变好了」

不要凭感觉。沿用本仓库已有的方法论：**建一个依赖 harmony_ui 的真实 Flutter 工程来编译**（0.6.0 盘点破坏性变更时就是这么做的，读签名猜会漏掉静默变更）。

设计一个 20 题的固定评测集，每题是一个真实需求（「做一个默认不选中的胶囊子页签」「弹一个不带黄下划线的确认框」「在 360vp 屏上放一个最大宽 448 的按钮」），在两种条件下让同一个模型生成代码：

| 指标 | A：只有现有 README | B：有 L0–L1 层 |
| --- | --- | --- |
| 首次编译通过率 | 基线 | 期望显著提升 |
| **静默语义错误率**（编译过但行为/观感错） | 基线 | 这是关键指标，比编译率更能说明问题 |
| 用到的上下文 token 数 | 基线 | 期望下降一个量级（460 KB → 单符号查询） |
| 为查一个 API 发生的检索/试错轮次 | 基线 | 期望下降 |

评测集本身入库，回归时重跑；`catalog.json` 的 `howToUse` 和 `AGENTS.md` 都应作为 prompt 的一部分，这样也能反过来验证「写给 AI 的说明到底有没有用」。

## 4. 明确的反模式

- ❌ **再写一份「AI 速查手册」Markdown**。它会在下一个版本过时，且没有机制发现。
- ❌ **把源码注释全文复制进 catalog**。本次开发中 `catalog.json` 一度涨到 729 KB（比 README 还大）；改成「索引 + `file:line` 回指 + 按需读源码」后降到约 300 KB，配套的 `API-INDEX.md` 只有 42 KB。
- ❌ **让生成器猜解析不了的东西**。低置信度要显式标注，源码行号必须准确。
- ❌ **把易变内容写进 `AGENTS.md`**。它会被缓存、被复制到各种工具里；版本号、清单、统计数字都放生成物。
- ❌ **只加文档不改 CI**。没有 `--check` 门禁，三个月后这套东西就是新的漂移源。

## 5. 建议的推进顺序

1. **先跑通并验证本次最小闭环**（已完成）：`python3 tool/gen_ai_catalog.py --check` 应输出 OK；`python3 tool/ai_lookup.py OhosChipGroup` 应能看到「⚠ #7 静默」与 `selectedIndex = 0`。
2. **接入 CI 门禁 + 修 README / 矩阵漂移**（半天，改动小、收益直接）。
3. **补 4 个静默变更控件的构造器示例 + 反例库**（L2，专治 F2/F3/F4）。
4. **建评测集**，用真实工程编译量化效果，再决定是否投入 MCP / dartdoc Pages。
5. `llms-full.txt` 与 `custom_lint` 视评测结果排期。
