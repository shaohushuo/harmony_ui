#!/bin/zsh
# 按控件文字点按 —— 不写死坐标，找不到就滚着找。
#
# 为什么按文字找：首页的分类卡片 y 随滚动位置变，写死的坐标在滚动过几次之后
# 就会点到隔壁那一项，而点错了看起来和点对了长得一样（都是进了一个分类页），
# 排查时极难发现。dumpLayout 的 bounds 是当前帧的真实位置。
#
# 为什么自带滚动：一屏放不下 8 个分类，尾部两项（容器类 / UI Design Kit）在
# 顶部时压根不在布局树里 —— 此时「找不到」不代表「没有」，得先往下滚。
#
# 用法：
#   ./tool/tap_text.sh <文字前缀>      # 点第一个以该前缀开头的可点击节点
#   ./tool/tap_text.sh --any <子串>    # 子串匹配
#   ./tool/tap_text.sh --list          # 只列出当前可点击文字
set -e

HDC="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
TMP=/data/local/tmp/_layout.json

mode=prefix
if [ "$1" = "--any" ]; then mode=any; shift; fi
if [ "$1" = "--list" ]; then mode=list; fi
needle="${1:-}"

find_and_click() {
  "$HDC" shell "uitest dumpLayout -p $TMP" >/dev/null
  "$HDC" file recv "$TMP" /tmp/_layout_local.json >/dev/null
  python3 - "$mode" "$needle" <<'PY'
import json, sys, subprocess
mode, needle = sys.argv[1], sys.argv[2]
d = json.load(open('/tmp/_layout_local.json'))
hits = []
def walk(n):
    a = n.get('attributes', {})
    t = str(a.get('text', '')).strip()
    if t:
        hits.append((t, a.get('bounds', ''), a.get('clickable') == 'true'))
    for c in n.get('children', []):
        walk(c)
walk(d)

import re
def center(b):
    # "[56,801][1224,1165]" → (640, 983)。直接 split 会把 '[' 留在数字里。
    l, t, r, bt = (int(v) for v in re.findall(r'\d+', b)[:4])
    return (l + r) // 2, (t + bt) // 2

if mode == 'list':
    for t, b, ck in hits:
        print(f"{'*' if ck else ' '} {b}  {t[:50]!r}")
    sys.exit(0)

cands = [(t, b) for t, b, ck in hits if ck or '\n' in t]
for t, b in cands:
    first = t.split('\n')[0]
    if (mode == 'prefix' and first.startswith(needle)) or (mode == 'any' and needle in t):
        x, y = center(b)
        print(f"{first}  @ {x},{y}")
        subprocess.run(['/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc',
                        'shell', f'uitest uiInput click {x} {y}'], check=True)
        sys.exit(0)

sys.exit(3)
PY
}

if [ "$mode" = "list" ]; then find_and_click; exit 0; fi

# 先往上归位（可能停在下半屏），再逐屏往下找。
for i in 1 2 3 4; do
  "$HDC" shell "uitest uiInput swipe 640 900 640 2500" >/dev/null
  sleep 0.3
done
for i in 0 1 2 3 4; do
  if find_and_click; then exit 0; fi
  "$HDC" shell "uitest uiInput swipe 640 2200 640 900" >/dev/null
  sleep 0.7
done

echo "NOT FOUND: $needle" >&2
./tool/tap_text.sh --list 2>&1 | head -25 >&2
exit 1