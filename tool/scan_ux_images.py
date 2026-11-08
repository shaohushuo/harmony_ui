#!/usr/bin/env python3
"""扫描设计规范配图，产出可核对的元数据清单。

为什么要这个脚本：设计规范正文只给令牌名，具体数值往往**只写在配图里**
（`tool/fetch_ux_images.sh` 抓下来的 608 张）。只看 markdown 会漏掉一整类
规格，而且漏得很安静 —— 没有报错、没有空值，只是「没读到」。

本脚本不解释图片内容（那要靠逐张精读），只做三件事：
  1. 把「哪些图里可能有数值标注」变成可数的候选集（标注文字/标注线是洋红色）；
  2. 把每张图与它所在文档段落绑定（段落决定数值的适用形态，见 `ctx`）；
  3. 记录图片自身属性（尺寸、彩色占比、是否全灰），便于后续判重与筛选。

输出 `doc/ux-images.scan.json`（入库）与 `doc/UX-IMAGES-INDEX.md`（可读版）。

用法：
    python3 tool/scan_ux_images.py            # 扫描并写两份产物
    python3 tool/scan_ux_images.py --check    # 只报告数量，不写文件
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

IMG_DIR = "doc/reference/design/img"
INDEX_JSON = "doc/ux-images.index.json"
OUT_JSON = "doc/ux-images.scan.json"
OUT_MD = "doc/UX-IMAGES-INDEX.md"

# 标注色实测为 #E40078（228,0,120），是**玫红/品红**而不是纯洋红 (255,0,255)。
# 一开始按 (r>190, g<130, b>190) 判，`subheader_11` 得 0 像素 —— 那张图明明有
# 「安全距离 10」「边距2」「边距3」三处标注，只因 b=120 低于 190 就被整类排掉。
# 现改为色相窗口：品红区间 300–350°，饱和度高、亮度不极暗（保留抗锯齿中间色）。
HUE_MIN, HUE_MAX = 300.0, 350.0
SAT_MIN = 0.5
LIGHT_MIN = 0.15
# 缩到 640 宽后仍保留的标注像素下限。实测 subheader_11 缩放后约 200 像素。
MAGENTA_MIN_PIXELS = 20


def _is_magenta(r: int, g: int, b: int) -> bool:
    """快速判「品红标注色」。先做廉价排除，避免每像素都算色相。"""
    if r < 110 or g > 90 or b < 40:
        return False
    if not (r > b > g):  # 品红的通道序：R 最大、G 最小、B 居中
        return False
    h = 60.0 * (6.0 - (b - g) / float(r - g))
    if h >= 360.0:
        h -= 360.0
    if not (HUE_MIN <= h <= HUE_MAX):
        return False
    if (r - g) / float(r) < SAT_MIN:
        return False
    return (r + g + b) / 3.0 / 255.0 >= LIGHT_MIN

# 段落关键词 → 该图数值的适用形态。设计规范里「穿戴设备」段落的数值
# 与手机令牌**不能**直接对比 —— 已因此误判过一次（手表子标题「安全距离 10」）。
CONTEXT_TAGS = [
    ("穿戴", "wearable"),
    ("手表", "wearable"),
    ("平板", "tablet"),
    ("PC", "pc"),
    ("2in1", "pc"),
    ("视觉规则", "visual-rule"),
    ("边距", "spacing"),
    ("间距", "spacing"),
    ("安全距离", "spacing"),
    ("字号", "typography"),
    ("字重", "typography"),
    ("圆角", "corner"),
    ("投影", "shadow"),
    ("颜色", "color"),
    ("动效", "motion"),
]


def classify_width(w: int) -> str:
    """按像素宽推断图的用途。3840/1920 多是标注大图，1440 是常规示意。"""
    if w >= 3800:
        return "huge"
    if w >= 1900:
        return "large"
    if w >= 1400:
        return "diagram"
    if w >= 800:
        return "medium"
    return "small"


def scan_one(path: str) -> dict | None:
    from PIL import Image

    try:
        im = Image.open(path)
    except Exception as exc:  # 损坏或缺文件不中断整轮
        return {"error": str(exc)}

    w, h = im.size
    rgb = im.convert("RGB")
    # 缩到 640 宽做统计：洋红标注是细线+小字，再缩小就统计不到了。
    if w > 640:
        rgb = rgb.resize((640, max(1, round(h * 640 / w))), Image.LANCZOS)

    data = rgb.tobytes()
    total = len(data) // 3
    magenta = colorful = near_white = dark = 0
    for i in range(0, len(data), 3):
        r = data[i]
        g = data[i + 1]
        b = data[i + 2]
        if _is_magenta(r, g, b):
            magenta += 1
        lo = r if r < g else g
        if b < lo:
            lo = b
        hi = r if r > g else g
        if b > hi:
            hi = b
        if hi - lo > 25:
            colorful += 1
        if r > 240 and g > 240 and b > 240:
            near_white += 1
        if r < 40 and g < 40 and b < 40:
            dark += 1

    return {
        "width": w,
        "height": h,
        "class": classify_width(w),
        "magenta": magenta,
        "magenta_ratio": round(magenta / total, 5),
        "colorful_ratio": round(colorful / total, 4),
        "white_ratio": round(near_white / total, 3),
        "dark_ratio": round(dark / total, 3),
    }


def is_annotation_candidate(meta: dict) -> bool:
    """判定「含数值标注」。

    判据只有一条：**检出品红标注色 `#E40078`**。设计稿用这个颜色写尺寸
    标注（`安全距离 10`、`边距2`），是 608 张里唯一可靠的机器可判信号。

    为什么不用「大尺寸 + 灰阶」：一开始那样判会给 305 张，抽验后发现
    `button_10`（large，纯示意）、`patternlock_03`（huge，六种状态并排）
    都没有任何数值 —— 规范里大量示意稿本身就是 1920/3840 导出的。
    尺寸只说明导出规格，不说明内容。

    上界 0.08 是为了排掉**整图彩色**的色卡（`color_01` 这类纯色卡整图
    都是彩色，ratio 极高）。下界见 `MAGENTA_MIN_PIXELS`。
    """
    if meta.get("error"):
        return False
    mr = meta["magenta_ratio"]
    return 0.0 < mr < 0.08 and meta["magenta"] >= MAGENTA_MIN_PIXELS


def is_large_without_magenta(meta: dict) -> bool:
    """大尺寸但无标注色的图：本轮不作为精读对象，但记录数量。

    抽样（`button_10` / `patternlock_03`）确认这类多数是形态示意。保留这个
    字段是为了让「哪些图没读」也是可数的 —— 否则「全部读完」这句话无法核对。
    """
    return (
        not meta.get("error")
        and meta["magenta"] == 0
        and meta["class"] in ("large", "huge")
        and meta["colorful_ratio"] < 0.9
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="只报告数量，不写文件")
    args = ap.parse_args()

    if not os.path.isdir(IMG_DIR):
        print(f"缺少图片目录 {IMG_DIR}（先跑 tool/fetch_ux_images.sh）", file=sys.stderr)
        return 1

    index = json.load(open(INDEX_JSON, encoding="utf-8"))
    ctx_of: dict[tuple[str, int], str] = {}
    for slug, doc in index.items():
        for item in doc.get("images", []):
            ctx_of[(slug, item["n"])] = item.get("ctx", "")

    rows = []
    for name in sorted(os.listdir(IMG_DIR)):
        if not name.endswith(".png"):
            continue
        stem = name[:-4]
        m = re.match(r"^(.*)_(\d{2,3})$", stem)
        if not m:
            print(f"文件名不合约定，跳过：{name}", file=sys.stderr)
            continue
        slug, seq = m.group(1), int(m.group(2))
        ctx = ctx_of.get((slug, seq), "")
        meta = scan_one(os.path.join(IMG_DIR, name)) or {}
        tags = sorted({tag for kw, tag in CONTEXT_TAGS if kw in ctx})
        rows.append(
            {
                "slug": slug,
                "n": seq,
                "file": name,
                "ctx": ctx,
                "tags": tags,
                "annotation": is_annotation_candidate(meta),
                "large_no_magenta": is_large_without_magenta(meta),
                **meta,
            }
        )

    total = len(rows)
    cand = [r for r in rows if r["annotation"]]
    unread = [r for r in rows if not r["annotation"]]
    by_slug: dict[str, int] = {}
    for r in cand:
        by_slug[r["slug"]] = by_slug.get(r["slug"], 0) + 1

    print(f"图片 {total} 张，标注候选 {len(cand)} 张，覆盖 {len(by_slug)} 个控件")
    large_unread = [r for r in unread if r["large_no_magenta"]]
    print(f"非候选 {len(unread)} 张（其中大尺寸无标注色 {len(large_unread)} 张）")
    errs = [r for r in rows if r.get("error")]
    if errs:
        print(f"读取失败 {len(errs)} 张：{[r['file'] for r in errs][:5]}", file=sys.stderr)

    if args.check:
        return 0

    json.dump(
        {
            "source": IMG_DIR,
            "total": total,
            "annotation_candidates": len(cand),
            "non_candidates": len(unread),
            "large_without_magenta": len(large_unread),
            "note": (
                "annotation=true 表示图里检出洋红标注色，是精读对象；"
                "其余图机器未检出标注，抽样确认多为形态示意。"
            ),
            "images": rows,
        },
        open(OUT_JSON, "w", encoding="utf-8"),
        ensure_ascii=False,
        indent=1,
    )

    lines = [
        "# 设计规范配图索引",
        "",
        "> 由 `tool/scan_ux_images.py` 生成，**不要手改**。原始图片在 `doc/reference/design/img/`（不入库，",
        "> 用 `tool/fetch_ux_images.sh` 重新获取）。逐张精读的结论写 `doc/ux-specs/<slug>.md`，",
        "> 三列对照见 `doc/UX-SPEC-FROM-IMAGES.md`。",
        "",
        f"- 图片总数 **{total}**",
        f"- 标注候选 **{len(cand)}**（判据：检出洋红标注色，见脚本 `is_annotation_candidate`）",
        f"- 非候选 **{len(unread)}**，其中大尺寸无标注色 **{len(large_unread)}** 张（抽样确认为形态示意，未逐张精读）",
        "",
        "## 逐控件",
        "",
        "| 控件 | 图数 | 标注候选 | 候选编号 | 段落标签 |",
        "| --- | --- | --- | --- | --- |",
    ]
    for slug in sorted({r["slug"] for r in rows}):
        group = [r for r in rows if r["slug"] == slug]
        marked = sorted(r["n"] for r in group if r["annotation"])
        tags = sorted({t for r in group for t in r["tags"]})
        nums = "、".join(f"{n:02d}" for n in marked) or "—"
        lines.append(f"| `{slug}` | {len(group)} | {len(marked)} | {nums} | {'、'.join(tags) or '—'} |")
    lines.append("")

    open(OUT_MD, "w", encoding="utf-8").write("\n".join(lines))
    print(f"已写 {OUT_JSON} 与 {OUT_MD}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
