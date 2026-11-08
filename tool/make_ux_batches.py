#!/usr/bin/env python3
"""把精读任务拆成自包含的任务卡，供并行子 agent 逐批执行。

为什么要拆：113 张原图共 271 个标注簇，单会话逐张读会把上下文塞满。
拆成 N 批并行后，每个 agent 只看到自己那批的路径与上下文，结论直接落盘。

约束：**按控件（slug）完整分组** —— 同一个控件的所有图必须在同一批，
否则两个 agent 会写同一个 `doc/ux-specs/<slug>.md`。

用法：
    python3 tool/make_ux_batches.py --batches 6
"""

from __future__ import annotations

import argparse
import json
import os
from collections import defaultdict

SCAN_JSON = "doc/ux-images.scan.json"
ZOOM_DIR = "/tmp/ux_zoom"
# 任务卡是一次性中间产物（含 /tmp 路径，重跑可再生产），不放进 `doc/` ——
# `doc/ux-specs/` 只留逐控件的结论。
SPEC_DIR = "/tmp/ux_batches"
ROOT = os.path.abspath(".")

HEADER = """# 精读任务 · __TITLE__

> 由 `tool/make_ux_batches.py` 生成。结论写入 `doc/ux-specs/<slug>.md`，**不要改 `lib/` 任何代码**。

## 怎么读

1. 下面每张图给了**已裁剪放大的标注图**（`/tmp/ux_zoom/...`）。**先看裁剪图**，
   标注文字在宽 1920 的原图里只有 10–14px，直接看原图读不出来。
2. 裁剪图里可能只包含一两个标注，看不清归属时再打开原图对照整体版式。
3. 标注色是**玫红 `#E40078`**。图上其它粉色块可能是内容本身（色板、红点），不是标注。

## 怎么写

对每个控件输出一个 `doc/ux-specs/<slug>.md`，结构：

```markdown
# {slug}

来源：设计规范配图（`tool/fetch_ux_images.sh` 抓取），原文 `doc/reference/design/`。

## 图中规格

| 图 | 标注原文 | 数值 | 指向部位 | 适用形态 |
| --- | --- | --- | --- | --- |
| `xxx_03.png` | 安全距离 10 | 10vp | 组标题与下方内容 | 穿戴（见 ctx） |

## 没有数值的图

| 图 | 内容 |
| --- | --- |
| `xxx_05.png` | 三种按钮状态并排，无尺寸标注 |

## 存疑

- 读不准、被裁断、或与 ctx 矛盾的，逐条列出，不要猜。
```

要点：

- **数值必须逐字照抄图上的写法**（`10`、`12vp`、`#E40078`、`15fp`），不要换算、不要补单位。
- **「适用形态」必须依据原文上下文（ctx）判断**。设计规范里「穿戴设备」段的数值
  与手机令牌不是一回事，混用会得出错误结论。ctx 里出现「穿戴」「手表」就写 wearable。
- 图上只有编号（①②③）没有数字的，**不算数值**，记到「没有数值的图」并写明编号指向什么。
- 判断不出就写进「存疑」。**不要为了凑满表格而编造数值。**

"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--batches", type=int, default=6)
    args = ap.parse_args()

    scan = json.load(open(SCAN_JSON, encoding="utf-8"))
    by_slug: dict[str, list] = defaultdict(list)
    for r in scan["images"]:
        if r["annotation"]:
            by_slug[r["slug"]].append(r)
    for v in by_slug.values():
        v.sort(key=lambda r: r["n"])

    # 贪心均衡：按图数从多到少，放进当前最轻的批
    order = sorted(by_slug.items(), key=lambda kv: -len(kv[1]))
    batches: list[list[tuple[str, list]]] = [[] for _ in range(args.batches)]
    loads = [0] * args.batches
    for slug, rows in order:
        i = loads.index(min(loads))
        batches[i].append((slug, rows))
        loads[i] += len(rows)

    os.makedirs(SPEC_DIR, exist_ok=True)
    manifest = []
    for bi, group in enumerate(batches, 1):
        if not group:
            continue
        group.sort(key=lambda kv: kv[0])
        lines = [HEADER.replace("__TITLE__", f"batch {bi}（{len(group)} 个控件 / {sum(len(r) for _, r in group)} 张图）")]
        for slug, rows in group:
            lines.append(f"\n## `{slug}`（{len(rows)} 张）\n")
            for r in rows:
                zooms = sorted(
                    f for f in os.listdir(ZOOM_DIR) if f.startswith(r["file"][:-4] + "__")
                ) if os.path.isdir(ZOOM_DIR) else []
                lines.append(f"### `{r['file']}`（{r['width']}×{r['height']}，{r['class']}）\n")
                lines.append(f"- 原图：`{ROOT}/doc/reference/design/img/{r['file']}`")
                if zooms:
                    lines.append("- 裁剪放大图（先看这些）：")
                    for z in zooms:
                        lines.append(f"  - `{ZOOM_DIR}/{z}`")
                else:
                    lines.append("- 裁剪放大图：**无**（自动定位未找到标注区，直接看原图）")
                ctx = r.get("ctx", "").replace("\n", " ").strip()
                if len(ctx) > 260:
                    ctx = ctx[:260] + "…"
                lines.append(f"- 原文上下文：`{ctx}`" if ctx else "- 原文上下文：（空）")
                lines.append("")
        path = os.path.join(SPEC_DIR, f"batch_{bi}.md")
        open(path, "w", encoding="utf-8").write("\n".join(lines))
        manifest.append(
            {
                "batch": bi,
                "file": path,
                "slugs": [s for s, _ in group],
                "images": sum(len(r) for _, r in group),
            }
        )
        print(f"batch_{bi}.md  控件 {len(group)}  图 {sum(len(r) for _, r in group)}  负载 {loads[bi-1]}")

    json.dump(manifest, open(os.path.join(SPEC_DIR, "_manifest.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print(f"共 {len(manifest)} 批，任务卡在 {SPEC_DIR}/batch_*.md")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
