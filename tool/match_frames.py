#!/usr/bin/env python3
"""把 doc/screenshots 的旧图与 /tmp/cap2/<mode>/ 新帧做相似度匹配。

用法: python3 tool/match_frames.py <mode> [旧图名 ...]
不给旧图名则匹配全部。输出每张旧图的最佳 3 个新帧（余弦相似度，降采样 64x64 灰度）。
帧目录里的子目录（如 操作类_v2/）会展开为「子目录/帧名」。
"""
import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_gray(path: str) -> list[float]:
    im = Image.open(path).convert('L').resize((64, 64))
    return [v / 255.0 for v in im.getdata()]


def cosine(a: list[float], b: list[float]) -> float:
    na = sum(x * x for x in a) ** 0.5
    nb = sum(x * x for x in b) ** 0.5
    if na == 0 or nb == 0:
        return 0.0
    return sum(x * y for x, y in zip(a, b)) / (na * nb)


def collect_frames(cap_dir: str) -> dict[str, str]:
    frames: dict[str, str] = {}
    for root, _dirs, files in os.walk(cap_dir):
        for f in sorted(files):
            if not f.endswith('.png'):
                continue
            full = os.path.join(root, f)
            rel = os.path.relpath(full, cap_dir)
            frames[rel] = full
    return frames


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else 'light'
    cap_dir = f'/tmp/cap2/{mode}'
    frames = collect_frames(cap_dir)
    if not frames:
        print(f'NO FRAMES in {cap_dir}')
        sys.exit(1)

    targets = sys.argv[2:] or sorted(
        f for f in os.listdir(os.path.join(REPO, 'doc/screenshots'))
        if f.endswith('.png')
    )
    vecs = {k: load_gray(v) for k, v in frames.items()}
    for t in targets:
        old = load_gray(os.path.join(REPO, 'doc/screenshots', t))
        scored = sorted(
            ((cosine(old, v), k) for k, v in vecs.items()), reverse=True
        )
        top = '  '.join(f'{k}:{s:.4f}' for s, k in scored[:3])
        print(f'{t:40s} {top}')


if __name__ == '__main__':
    main()
