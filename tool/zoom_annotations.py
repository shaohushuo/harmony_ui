#!/usr/bin/env python3
"""把配图里的品红标注区自动裁出来并放大，供逐张精读。

要解决的问题：标注文字在 1920 宽的图里只有 10–14px，直接看整张图读不出
（`subheader_11` 第一次读只看到模糊一团，放大 2 倍后才读出「安全距离 10」
「边距2」「边距3」）。逐张手写裁剪坐标不可维护，所以按标注色自动定位。

做法：找出所有品红像素（与 `scan_ux_images.py` 同一判据，`#E40078` 系），
按 64px 网格做连通簇合并，每簇裁出外扩 24px 的框，放大到宽 ≥ 900px。

输出到 `--out`（默认 /tmp/ux_zoom/），文件名为 `<原图名>__<簇号>.png`，
并打印每个簇的 bbox 与裁剪图路径，便于逐张喂给视觉读取。

用法：
    python3 tool/zoom_annotations.py subheader_11.png
    python3 tool/zoom_annotations.py --all              # 处理扫描判定的全部候选
    python3 tool/zoom_annotations.py --all --out /tmp/z
"""

from __future__ import annotations

import argparse
import json
import os
import sys

IMG_DIR = "doc/reference/design/img"
SCAN_JSON = "doc/ux-images.scan.json"

HUE_MIN, HUE_MAX = 300.0, 350.0
SAT_MIN = 0.5
LIGHT_MIN = 0.15
CELL = 64  # 聚类网格边长（原图像素）
PAD = 24  # 裁框外扩
MIN_BOX = (24, 10)  # 小于此的簇多半是噪点
SCAN_STEP = 2  # 隔像素扫描，标注线宽 ≥2px，不影响定位


def is_magenta(r: int, g: int, b: int) -> bool:
    if r < 110 or g > 90 or b < 40:
        return False
    if not (r > b > g):
        return False
    h = 60.0 * (6.0 - (b - g) / float(r - g))
    if h >= 360.0:
        h -= 360.0
    if not (HUE_MIN <= h <= HUE_MAX):
        return False
    if (r - g) / float(r) < SAT_MIN:
        return False
    return (r + g + b) / 3.0 / 255.0 >= LIGHT_MIN


def find_clusters(path: str) -> list[tuple[int, int, int, int]]:
    """返回若干 bbox (x0, y0, x1, y1)，按面积从大到小。"""
    from PIL import Image

    im = Image.open(path).convert("RGB")
    w, h = im.size
    data = im.tobytes()

    cells: set[tuple[int, int]] = set()
    for y in range(0, h, SCAN_STEP):
        row = y * w
        for x in range(0, w, SCAN_STEP):
            i = (row + x) * 3
            if is_magenta(data[i], data[i + 1], data[i + 2]):
                cells.add((x // CELL, y // CELL))
    if not cells:
        return []

    # 8 邻域 BFS 合并网格，得到标注簇
    seen: set[tuple[int, int]] = set()
    boxes = []
    for start in cells:
        if start in seen:
            continue
        stack = [start]
        seen.add(start)
        xs0 = ys0 = 1 << 30
        xs1 = ys1 = -1
        while stack:
            cx, cy = stack.pop()
            xs0 = min(xs0, cx * CELL)
            ys0 = min(ys0, cy * CELL)
            xs1 = max(xs1, (cx + 1) * CELL)
            ys1 = max(ys1, (cy + 1) * CELL)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nb = (cx + dx, cy + dy)
                    if nb in cells and nb not in seen:
                        seen.add(nb)
                        stack.append(nb)
        x0 = max(0, xs0 - PAD)
        y0 = max(0, ys0 - PAD)
        x1 = min(w, xs1 + PAD)
        y1 = min(h, ys1 + PAD)
        if (x1 - x0) >= MIN_BOX[0] and (y1 - y0) >= MIN_BOX[1]:
            boxes.append((x0, y0, x1, y1))

    boxes.sort(key=lambda b: (b[1], b[0]))  # 从上到下、从左到右，便于按序叙述
    return boxes


def zoom(path: str, out_dir: str) -> list[str]:
    from PIL import Image

    im = Image.open(path).convert("RGB")
    stem = os.path.basename(path)[:-4]
    outs = []
    for k, box in enumerate(find_clusters(path), 1):
        crop = im.crop(box)
        scale = max(3, -(-900 // max(1, crop.width)))  # 至少 900 宽，至少 3 倍
        big = crop.resize((crop.width * scale, crop.height * scale), Image.LANCZOS)
        name = f"{stem}__{k}.png"
        dest = os.path.join(out_dir, name)
        big.save(dest)
        print(f"{name}\tbox={box}\tscale={scale}\tsize={big.width}x{big.height}")
        outs.append(dest)
    if not outs:
        print(f"{stem}\t无标注簇")
    return outs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*", help="图片文件名（不含目录）")
    ap.add_argument("--all", action="store_true", help="处理扫描结果里的全部标注候选")
    ap.add_argument("--out", default="/tmp/ux_zoom")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    names = list(args.files)
    if args.all:
        scan = json.load(open(SCAN_JSON, encoding="utf-8"))
        names += [r["file"] for r in scan["images"] if r["annotation"]]
    if not names:
        ap.error("给出图片名，或用 --all")

    total = 0
    for n in names:
        p = os.path.join(IMG_DIR, n)
        if not os.path.exists(p):
            print(f"缺文件：{n}", file=sys.stderr)
            continue
        total += len(zoom(p, args.out))
    print(f"共 {total} 张裁剪图在 {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
