#!/usr/bin/env python3
"""把 `doc/ux-specs/*.md` 汇总成「配图数值总清单」。

为什么不手抄：27 个文件共 233 条记录，手抄必然漏项，而且分类账一错就整篇
结论都不可信（本项目已经因为手推统计连错两轮）。这里所有数字都由脚本从
各控件文件重新数出来。

核心判断：**按形态分组**。官方「控件规格」分 手机 / 电脑 / 智能穿戴 三节，
穿戴形态的数值不能拿来和手机令牌对照 —— `subheader` 的手表「安全距离 10」
曾被误当成手机 `subheader_title_margin_bottom = 12vp` 的问题项。

用法：
    python3 tool/make_spec_summary.py
"""

from __future__ import annotations

import glob
import json
import os
from collections import Counter, defaultdict

SPEC_DIR = "doc/ux-specs"
OUT = "doc/UX-SPEC-FROM-IMAGES.md"


def form_of(cell: str) -> str:
    t = cell.lower()
    if any(k in t for k in ("穿戴", "手表", "圆形表", "方形表", "wearable", "watch")):
        return "wearable"
    if any(k in t for k in ("平板", "tablet", "foldable", "折叠")):
        return "tablet"
    if any(k in t for k in ("手机", "phone", "portrait", "landscape")):
        return "phone"
    if any(k in t for k in ("电脑", "pc", "2in1")):
        return "pc"
    return "unknown"


def clean(s: str) -> str:
    """表格单元格里的竖线会打破 Markdown 表，也会让 awk 按字段统计时位移。"""
    return s.replace("|", "／").strip()


def load() -> dict[str, list[tuple[str, str, str, str, str]]]:
    """返回 {slug: [(图, 标注原文, 数值, 指向部位, 形态)]}。"""
    out: dict[str, list] = {}
    for path in sorted(glob.glob(os.path.join(SPEC_DIR, "*.md"))):
        slug = os.path.basename(path)[:-3]
        if slug.startswith("batch_"):
            continue
        rows = []
        for line in open(path, encoding="utf-8"):
            if not line.startswith("| `"):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) < 4:
                continue
            img = cells[0].strip("`")
            rows.append(
                (
                    img,
                    clean(cells[1]),
                    clean(cells[2]),
                    clean(cells[3]),
                    cells[4] if len(cells) > 4 else "",
                )
            )
        if rows:
            out[slug] = rows
    return out


CONFLICTS = """\
| 控件 | 图上 | 出处 | 冲突点 | 核查结论 |
| --- | --- | --- | --- | --- |
| `bottomtab` | `360vp` | `bottomtab_19/28.png` | 正文与实现均「≥4 页签一律 ≤328」，图上 5 页签给 360 | **未决**：`80n+8` 能复现 2/3/4 页签，唯独 5 页签断裂；360 恰等于 `88×4+8` |
| `bottomtab` | `248/168/272/184` | `bottomtab_21/22.png` | 与正文公式 `76n+8`/`80n+8` 每页签差 4vp | **已判**：设计稿按 80/88 排，组件默认取正文 76/80 |
| `bottomtab` | 平铺间距 `4` | `bottomtab_05.png` | 另一张平铺图 `bottomtab_31` 同一处读作 `2` | **未决**：两张同形态图互不一致，令牌 `bottom_tab_bar_space = 2` 站 `_31` |
| `list` | 第四档行高 `64` | `list_20.png` | 正文五档写 `48/56/64/72/96`，图上只有四个不同值 | **已判**：图不是五档的 1:1 图示，`72` 在图里没有对应行 |
| `list` | `40` | `list_08/10.png` | 无法确认是图标本体宽还是热区宽 | **已判**：令牌层无任何侧滑项，`20/24/40/48` 都只能从图里取 |

`segmentbutton` 那条（图 `448` vs 正文 `480`）已撤销 —— `480 − 2×16 = 448`，
是同一句话的两端，不是冲突。逐条依据见 `doc/AUDIT-IMAGE-SPECS.md`。

**核查后改过代码的有三处**（细节见 `AUDIT-IMAGE-SPECS.md` 与 `CHANGELOG.md`）：
半模态 `LARGE` 挡补 8vp 顶距（`bindsheet_16` / `button_39` / `segmentbutton_10`）、
菜单内容左右 16vp 显式化（原先吃框架默认 12）、悬浮栏两套宽度写进注释。
另两条明确不做：列表行高五档是内容自然高的结果、文本渐隐依附滚动文本。

已按「只考虑较大设备」剔除的三条（穿戴形态，**本轮不核**）：

| 控件 | 图上 | 剔除原因 |
| --- | --- | --- |
| `toast` | 左右 `26vp` 与正文「上下左右 10vp」冲突 | 该控件 4 条图值全是手表形态 |
| `dialog` | `181`/`40` 与 `dialog_23` 的 `198`/`10` 并存 | 两份都是穿戴弹框（手机形态只有 1 条） |
| `titlebar` | 标注被裁断只读出单字符 | 12 条里 11 条是圆形表 / 方形表形态 |
"""

TABLET_GAP = """\
## 平板 / 大屏：配图给不出数值

这是本轮最重要的一条边界：**配图精读只对手机形态有效**。

- 608 张里带「平板」上下文的只有 **16 张**，**全部 0 像素标注色**。
  抽验 `segmentbutton_11.png`：三台设备（平板横屏 / 平板横屏宽 / 平板竖屏）并排，
  只有界面示意，没有任何尺寸线。
- 「电脑设备」出现在 **20 份**文档里，「平板」12 份，但对应的图都是布局示意。
- **「智慧屏」在 42 份设计文档里 0 次出现**。官方用「大屏」表达，只有 5 份文档提到。

结论：平板 / 折叠 / 大屏的数值**写在正文表格里，不在图上**。例如：

| 控件 | 正文原话 | 出处 |
| --- | --- | --- |
| `segmentbutton` | 按钮保持最大 `448vp` 的宽度，不再跟随屏幕伸缩 | `segmentbutton_12` 的 ctx |
| `button` | 单按钮横竖屏切换最大扩展到 `448vp`，双按钮左右布局间距 `12vp` | `button_40` 的 ctx |
| `bottomtab` | Tabs 数量 ≥5 时最大宽 `360vp` | `bottomtab_20` 的 ctx |

要核这类规格，走**正文参数表 + 资源表令牌 + 源码**，不要再来图里找 ——
这一层（配图）对它们没有信息量。`doc/reference/api/*.md` 里对应章节是
「电脑设备」「平板设备适配」「大屏」。
"""

EXCLUDED_NOTE = """\
## 暂不考虑：穿戴形态（{n} 条）

按当前范围（手机 / 平板 / 大屏 / PC），手表形态的数值**本轮不核查**，
但仍然保留在 `doc/ux-specs/<slug>.md` 里，不删：

① 将来若加穿戴变体，这是现成的数值表；
② 它们是「不能拿来对手机令牌」的证据 —— 上一轮就是把穿戴子标题的「安全距离 10」
错当成了手机 `subheader_title_margin_bottom = 12vp` 的问题项。

| 控件 | 穿戴条数 | 该控件是否还有可核的手机值 |
| --- | --- | --- |
"""


PENDING = """\
以下是**机器未检出标注色**的图，本轮没有逐张精读，不计入上面的数字：

- 非候选 **{non_cand}** 张，其中 **{large}** 张是「大尺寸但无标注色」。抽样看过 `button_10`
  （NORMAL / SMALL 两态并排）、`patternlock_03`（六种状态并排）、`subheader_10`
  （圆形表 / 方形表对照）—— 都是形态示意，没有尺寸标注。
- 抽样不等于全量。**如果后续核查发现某一项在配图里找不到出处，可以回到这批图里补读**：
  `python3 tool/zoom_annotations.py --all` 只处理候选，单张补读直接给文件名即可。
- 判定口径本身也有已知偏差：判据只认玫红 `#E40078`。**若官方某批图改用别的标注色，
  会被整类漏掉**。已见的误命中反向说明这点 —— `color_02`～`color_11`（取色器色板）、
  `radio_05`（选中态强调色）、`search_15`（文本选择手柄）都是粉色内容被当成标注。
"""


def scan_stats() -> dict[str, int]:
    """从 `doc/ux-images.scan.json` 取「没读多少张」。

    这两个数**必须现算**：写死过一次，判据从 `b>190` 改成色相窗口后候选从 60 涨到
    113，而文档里仍写着旧的 548/213，看起来像结论、实际是过期快照。
    口径与 `scan_ux_images.py` 同源，不在这里另立判据。
    """
    d = json.load(open("doc/ux-images.scan.json", encoding="utf-8"))
    rows = d["images"]
    unread = [r for r in rows if not r["annotation"]]
    return {
        "total": len(rows),
        "cand": len(rows) - len(unread),
        "non_cand": len(unread),
        "large": len([r for r in unread if r.get("large_no_magenta")]),
    }


def main() -> int:
    data = load()
    all_rows = [(s, r) for s, rows in data.items() for r in rows]
    by_form = Counter(form_of(r[4]) for _, r in all_rows)
    total = len(all_rows)
    phone_rows = [(s, r) for s, r in all_rows if form_of(r[4]) == "phone"]
    wear_rows = [(s, r) for s, r in all_rows if form_of(r[4]) == "wearable"]

    lines: list[str] = []
    w = lines.append
    w("# 设计规范配图里的数值")
    w("")
    w("> 由 `tool/make_spec_summary.py` 从 `doc/ux-specs/*.md` 汇总生成，**不要手改**。")
    w("> 原始图片在 `doc/reference/design/img/`（不入库，用 `tool/fetch_ux_images.sh` 重新获取），")
    w("> 候选筛选见 `doc/UX-IMAGES-INDEX.md`，逐张结论见 `doc/ux-specs/<slug>.md`。")
    w("")
    w("## 为什么要做这一轮")
    w("")
    w("设计规范的**正文只写令牌名，具体数值常常只写在配图里**。只看 markdown 会漏掉一整类")
    w("规格，而且漏得很安静 —— 没有报错、没有空值，只是「没读到」。")
    w("")
    w("所以把 608 张配图按标注色筛出候选、逐张裁剪放大精读，得到下面这份数值清单。")
    w("它是「图 / 令牌 / 实现」三列对照的**前置工作面**，本身不下结论 ——")
    w("逐条核查结论见 **`doc/AUDIT-IMAGE-SPECS.md`**（84 条：17 一致 / 45 仅设计稿 /")
    w("8 冲突 / 4 读数不可靠 / 3 令牌未引用 / 7 非规格）。")
    w("")
    w("## 总量")
    w("")
    scan = json.load(open("doc/ux-images.scan.json", encoding="utf-8"))
    w(
        f"配图 {scan['total']} 张，其中检出标注色的候选 **{scan['annotation_candidates']}** 张，"
        f"逐张精读后得到 **{total} 条**带数值的记录："
    )
    w("")
    w("| 形态 | 条数 | 占比 | 处理 |")
    w("| --- | --- | --- | --- |")
    applicable = len(phone_rows) + by_form.get("tablet", 0) + by_form.get("pc", 0)
    for key, label, note in [
        ("phone", "手机", "**核查工作面**"),
        ("tablet", "平板", "**核查工作面**（本轮配图无产出，见下节）"),
        ("pc", "电脑 / 大屏", "**核查工作面**（本轮配图无产出，见下节）"),
        ("wearable", "穿戴（手表）", "按当前范围**排除**，仅存档"),
        ("unknown", "未定", "需回原文确认形态"),
    ]:
        n = by_form.get(key, 0)
        if n == 0 and key in ("tablet", "pc", "unknown"):
            continue
        w(f"| {label} | {n} | {n / total:.0%} | {note} |")
    w(f"| **合计** | **{total}** | 100% | 适用 {applicable} 条 / 排除 {by_form.get('wearable', 0)} 条 |")
    w("")
    w("范围：**手机 / 平板 / 大屏 / PC**，穿戴设备不做。")
    w("")
    w(TABLET_GAP)
    w("## 各控件在配图层的覆盖情况")
    w("")
    w("剔除穿戴后，有些控件**在配图里一条手机值都不剩** —— 那不是「没查」，是「这层查不到」，")
    w("必须换来源（正文参数表 / 资源表 / 源码）。")
    w("")
    w("| 控件 | 总条数 | 手机 | 穿戴（排除） | 剔除穿戴后 |")
    w("| --- | --- | --- | --- | --- |")
    per: dict[str, Counter] = defaultdict(Counter)
    for s, r in all_rows:
        per[s][form_of(r[4])] += 1
    barren = []
    for s, c in sorted(per.items(), key=lambda kv: -sum(kv[1].values())):
        n = sum(c.values())
        wc, pc = c.get("wearable", 0), c.get("phone", 0)
        if pc == 0:
            barren.append(s)
            verdict = "**零产出**，改走正文 / 令牌"
        elif wc > pc * 2:
            verdict = "手机值偏少，优先核这几条"
        else:
            verdict = "可直接核"
        w(f"| `{s}` | {n} | {pc} | {wc} | {verdict} |")
    w("")
    w(f"**配图对手机形态零产出的控件共 {len(barren)} 个**：")
    w("、".join(f"`{s}`" for s in barren) + "。")
    w("")
    w("这几个控件不要在这份清单里找规格 —— 它们的配图全是手表形态或纯示意，")
    w("数值只在正文参数表与资源表里。")
    w("")
    # 原先这里是「关键发现：六成以上是穿戴形态」+ 逐控件形态表，
    # 已合并进上面的「各控件在配图层的覆盖情况」（同一张表，多了零产出判定）。
    w("## 手机形态清单（核查工作面）")
    w("")
    w(f"下面 **{len(phone_rows)} 条**是可以直接对照令牌与实现的。建议按控件逐个过，")
    w("每个数值问三个问题：① 令牌表里有没有同名项？② 有的话值是否一致？")
    w("③ 实现有没有真的用到那个令牌（`GetAttr` 读进字段却零调用方是常见坑）？")
    w("")
    for slug in sorted({s for s, _ in phone_rows}):
        rows = [r for s, r in phone_rows if s == slug]
        w(f"### `{slug}`（{len(rows)} 条）")
        w("")
        w("| 图 | 标注原文 | 数值 | 指向部位 |")
        w("| --- | --- | --- | --- |")
        for img, raw, val, attr, _ in rows:
            w(f"| `{img}` | {raw} | {val} | {attr} |")
        w("")
    w("## 优先核查：图与正文 / 同组规格互相冲突的")
    w("")
    w("这些不是「还没比」，而是**读出来就已经矛盾**，价值最高：")
    w("")
    w(CONFLICTS)
    w(EXCLUDED_NOTE.replace("{n}", str(len(wear_rows))).rstrip())
    for slug in sorted({s for s, _ in wear_rows}):
        n_w = len([1 for s, _ in wear_rows if s == slug])
        pc = per[slug].get("phone", 0)
        w(f"| `{slug}` | {n_w} | {'有 ' + str(pc) + ' 条' if pc else '**无 —— 该控件在配图里只剩穿戴值**'} |")
    w("")
    w("逐条明细见各控件文件（`doc/ux-specs/<slug>.md`）的「图中规格」表最后一列。")
    w("")
    w("## 本轮没读的部分（诚实边界）")
    w("")
    st = scan_stats()
    w(PENDING.format(non_cand=st["non_cand"], large=st["large"]))
    w("## 怎么重跑")
    w("")
    w("```bash")
    w("./tool/upstream.sh ux                  # 抓图，落到 doc/reference/design/img/（别直接调 fetch_ux_images.sh）")
    w("python3 tool/scan_ux_images.py          # 筛候选 → doc/ux-images.scan.json")
    w("python3 tool/zoom_annotations.py --all  # 裁标注区 → /tmp/ux_zoom/")
    w("python3 tool/make_ux_batches.py         # 拆成任务卡 → /tmp/ux_batches/batch_*.md")
    w("# 逐张精读产生 doc/ux-specs/<slug>.md（这一步靠视觉读取，不是脚本）")
    w("python3 tool/make_spec_summary.py       # 汇总成本文件")
    w("./tool/upstream.sh manifest             # 数字变了就刷新清单，否则 verify 会误报")
    w("```")
    w("")

    open(OUT, "w", encoding="utf-8").write("\n".join(lines))
    print(f"{OUT}: {total} 条（穿戴 {by_form.get('wearable',0)} / 手机 {len(phone_rows)}）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
