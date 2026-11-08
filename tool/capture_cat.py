#!/usr/bin/env python3
"""稳健的分类页滚动采集。

capture_theme.sh 的固定坐标 swipe 会被页面里的内层可滚动区域（新的
OhosList.scrollable 全宽区块、Kit 的横滑列表项）吃掉手势，导致后续帧全部
卡在同一位置。本脚本每滑一步都做像素差校验：页面没动就换滑动起点重试
（右缘 x=1240 → 左缘 x=36 → 底缘 y=2760 → 顶缘 y=600）。

用法: python3 tool/capture_cat.py <输出目录> <帧数>
先假设应用已在前台且位于目标分类页顶部。
"""
import os
import subprocess
import sys
import time

HDC = os.environ.get(
    'HDC',
    '/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/'
    'toolchains/hdc',
)
REMOTE = '/data/local/tmp/_cap.jpeg'
PROBE = '/tmp/_cap_probe.png'


def sh(cmd: str) -> None:
    subprocess.run([HDC, 'shell', cmd], capture_output=True)


def shot(out: str) -> None:
    sh(f'snapshot_display -f {REMOTE}')
    subprocess.run([HDC, 'file', 'recv', REMOTE, out], capture_output=True)


def swipe(x1: int, y1: int, x2: int, y2: int, vel: int = 400) -> None:
    sh(f'uitest uiInput swipe {x1} {y1} {x2} {y2} {vel}')


def gray(path: str, size: int = 48) -> list[int]:
    from PIL import Image

    im = Image.open(path).convert('L').resize((size, size))
    return list(im.get_flattened_data()) if hasattr(
        im, 'get_flattened_data'
    ) else list(im.getdata())


def diff(a: list[int], b: list[int]) -> float:
    return sum(abs(x - y) for x, y in zip(a, b)) / len(a)


def scroll_once(before: list[int]) -> bool:
    """尝试从多个起点滑动，直到屏幕真的变化。返回是否成功。"""
    for (x, y) in (
        (1240, 2200),
        (36, 2200),
        (640, 2760),
        (1240, 1200),
        (36, 1200),
        (640, 600),
    ):
        swipe(x, y, x, max(y - 1500, 120))
        time.sleep(1.2)
        shot(PROBE)
        if diff(before, gray(PROBE)) > 2.0:
            return True
    return False


def main() -> None:
    out_dir = sys.argv[1]
    n = int(sys.argv[2])
    os.makedirs(out_dir, exist_ok=True)
    time.sleep(1.0)

    prev = None
    for i in range(1, n + 1):
        out = os.path.join(out_dir, f'{i:02d}.png')
        shot(out)
        cur = gray(out)
        if prev is not None and diff(prev, cur) < 1.0:
            print(f'frame {i} duplicates previous - stop')
            os.remove(out)
            break
        prev = cur
        print(f'captured {out}')
        if i < n and not scroll_once(cur):
            print(f'page would not scroll before frame {i + 1} - stop')
            break


if __name__ == '__main__':
    main()
