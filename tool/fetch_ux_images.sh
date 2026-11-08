#!/bin/zsh
# 抓取 42 份官方 UX 设计文档与其中全部配图。
#
# 为什么单独成脚本：
#   设计规范页里的**具体数值经常只写在配图上**（设计稿标注），正文只给描述。
#   只读 markdown 会漏掉一整类规格，而且漏得很安静 —— 看起来「文档读过了」。
#   所以配图必须一起抓下来看。图本体不入库（185MB、随上游漂移），
#   索引 doc/ux-images.index.json 入库，记录每张图属于哪份文档、上下文是哪句原文。
#
# 权威清单来源：概览页 → 42 个控件链接 → doccenter-ux-design/<slug>.md
# 不要猜 slug（见 tool/trace_control_docs.sh 的注释）。
#
# 用法：./tool/fetch_ux_images.sh
# 产物：doc/reference/design/*.md（42 份设计文档）、doc/reference/design/img/*.png（608 张图）
set -e
cd "$(dirname "$0")/.."

OUT="doc/reference/design"
IMG="$OUT/img"
OVERVIEW="https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/general_overview-0000001929599380.md"
BASE="https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design"

mkdir -p "$IMG"

# 1. 概览页 → 控件清单
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -sfL --max-time 60 -o "$TMP/overview.md" "$OVERVIEW"
grep -oE '\*\*\[[^]]+\]\(https://developer\.huawei\.com/consumer/cn/doc/design-guides/[^)]+\)\*\*' \
  "$TMP/overview.md" |
  sed -E 's/^\*\*\[([^]]+)\]\(.*\/(.*)\)\*\*$/\1|\2/' > "$TMP/controls.txt"
echo "概览页解析出 $(wc -l < "$TMP/controls.txt" | tr -d ' ') 个控件"

# 2. 逐控件下载设计文档。取不到仍要报出来，不能静默跳过。
fail=0
while IFS= read -r line; do
  name="${line%%|*}"
  slug="${line##*|}"
  code=$(curl -sL --max-time 40 -o "$OUT/$slug.md" -w "%{http_code}" "$BASE/$slug.md")
  # 404 时上游返回 HTML 外壳，状态码仍可能 200，所以还要看首行是不是 markdown 标题
  if [[ "$code" != "200" ]] || ! head -1 "$OUT/$slug.md" | grep -q '^# '; then
    echo "FAIL $code $name $slug"
    rm -f "$OUT/$slug.md"
    fail=1
  fi
done < "$TMP/controls.txt"

# 3. 抽出每份文档的图片 URL，按「文档短名_序号」命名。
#    一行可能有多张图，用 finditer 而不是按行 match。
python3 - "$OUT" <<'PY'
import re, sys, os, json, glob
out = sys.argv[1]
jobs = []
for f in sorted(glob.glob(os.path.join(out, '*.md'))):
    slug = os.path.basename(f)[:-3]
    short = slug.split('-')[0]
    t = open(f, encoding='utf-8').read()
    n = 0
    for line in t.splitlines():
        for m in re.finditer(r'!\[[^\]]*\]\((https://contentcenter[^)\s"]+)', line):
            n += 1
            jobs.append((m.group(1), os.path.join(out, 'img', f'{short}_{n:02d}.png')))
json.dump(jobs, open(os.path.join(out, 'jobs.json'), 'w'))
print(f'待下载 {len(jobs)} 张图')
PY

# 4. 并发下载
python3 - "$OUT" <<'PY'
import json, subprocess, os, sys
from concurrent.futures import ThreadPoolExecutor
out = sys.argv[1]
jobs = json.load(open(os.path.join(out, 'jobs.json')))
def get(j):
    u, p = j
    r = subprocess.run(['curl', '-sfL', '--max-time', '60', '-o', p, u])
    return p, (os.path.getsize(p) if r.returncode == 0 and os.path.exists(p) else -1)
ok = bad = 0
with ThreadPoolExecutor(max_workers=8) as ex:
    for p, sz in ex.map(get, jobs):
        if sz > 0:
            ok += 1
        else:
            bad += 1
            print('FAIL', p)
print(f'图片下载成功 {ok} / 失败 {bad}')
PY

# 5. 重建「图 → 上下文」索引（入库的那份）
python3 - "$OUT" <<'PY'
import re, json, glob, os, sys
out = sys.argv[1]
idx = {}
for f in sorted(glob.glob(os.path.join(out, '*.md'))):
    slug = os.path.basename(f)[:-3]
    short = slug.split('-')[0]
    lines = open(f, encoding='utf-8').read().splitlines()
    entries, n = [], 0
    for i, l in enumerate(lines):
        for m in re.finditer(r'!\[[^\]]*\]\((https://contentcenter[^)\s"]+)', l):
            n += 1
            ctx = []
            pre = l[:m.start()].strip()
            if pre:
                ctx.append(pre)
            for j in range(i - 1, max(-1, i - 8), -1):
                s = lines[j].strip()
                if not s or s.startswith('!['):
                    continue
                if s.startswith('|') or s.startswith('>'):
                    ctx.append(s); break
                if s:
                    ctx.append(s)
                if len(ctx) >= 3:
                    break
            ctx = re.sub(r'\s+', ' ', ' '.join(reversed(ctx)))[:180]
            entries.append({'n': n, 'ctx': ctx})
    idx[short] = {'doc': slug, 'images': entries}
p = os.path.join('doc', 'ux-images.index.json')
json.dump(idx, open(p, 'w'), ensure_ascii=False, indent=1)
print(f'索引已更新 {p}（{len(idx)} 份文档 / '
      f'{sum(len(v["images"]) for v in idx.values())} 张图）')
PY

[[ "$fail" == "0" ]] || { echo "有设计文档抓取失败，见上方 FAIL 行"; exit 1; }
echo "完成：$OUT"
