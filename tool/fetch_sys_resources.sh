#!/usr/bin/env zsh
# 抓取 OpenHarmony 系统资源明文表，并解析组件令牌的真值。
#
# 为什么需要这个脚本：
#   官方文档把尺寸写成 `$r('sys.float.search_default_height')` 这样的令牌引用，
#   真值编在 SDK 的 `resources.index`（RestoolV2 二进制）里，`strings` 只读得到
#   令牌名、读不到 40vp。但它不是黑盒 —— 它就是 global_system_resources 仓库里
#   三份 JSON 的编译产物，直接读源文件即可。
#
# 三层解析链（缺一不可）：
#   pattern.json   组件主题模式，如 ohos_search_pattern 里 `search_default_height`
#                  → `$float:search_default_height`
#   float_sys.json 组件级令牌（chip_* / search_* / subheader_*）
#   float.json     基础设计令牌（ohos_id_* / padding_levelN / 字阶）
#
# 两张 float 表的键**不重复**，合起来才构成 sys.float 命名空间 —— 不是
# 「索引 + 内容」的关系。有些键在 float_sys 里就是最终数字（chip_normal_height
# 直接是 36.0vp，压根不在 float.json 里），有些只在 float.json 里
# （subheader_single_title_height = 56vp）。所以必须两张表都查；
# 曾把 float_sys 一律当别名表，结果 chip_* 全部查不到。
#
# 坑：pattern 层的键与 float_sys 层的键可能同名，若解析时在 pattern 里反复回查
# 会自引用成环。本脚本只在 pattern 层跳一次，之后只查 float_sys / float。
#
# 用法：
#   tool/fetch_sys_resources.sh              # 抓取 + 打印 search / chip / subheader 摘要
#   tool/fetch_sys_resources.sh search_      # 只看指定前缀
#
# 输出落到 doc/source/systemres/（已被 .gitignore 挡住，见 README）。
set -u

RAW="https://gitee.com/openharmony/global_system_resources/raw/master/systemres/main/resources/base/element"
OUT="$(cd "$(dirname "$0")/.." && pwd)/doc/source/systemres"
mkdir -p "$OUT"

FILES=(pattern.json float.json float_sys.json)
fail=0
for f in $FILES; do
  code=$(curl -sL --max-time 90 -o "$OUT/$f" -w "%{http_code}" "$RAW/$f")
  # 校验首字符是 `{`，否则拿到的是错误页（这类接口 200 也可能返 HTML）
  if [[ "$code" == "200" ]] && [[ "$(head -c 1 "$OUT/$f")" == "{" ]]; then
    printf '  ok   %-16s %6s 行\n' "$f" "$(wc -l < "$OUT/$f" | tr -d ' ')"
  else
    printf '  FAIL %-16s http=%s\n' "$f" "$code"
    fail=1
  fi
done

[[ $fail -ne 0 ]] && { print -u2 "抓取失败，未继续解析"; exit 1; }

prefix="${1:-}"
OUT="$OUT" prefix="$prefix" python3 - <<'PY'
import json, os, re, sys

out = os.environ['OUT']
prefix = os.environ.get('prefix', '')

base = {x['name']: x['value'] for x in json.load(open(f'{out}/float.json'))['float']}
alias = {x['name']: x['value'] for x in json.load(open(f'{out}/float_sys.json'))['float']}

pats = {}
for item in json.load(open(f'{out}/pattern.json'))['pattern']:
    pats[item['name']] = {v['name']: v.get('value') for v in item.get('value', [])}

MAX_DEPTH = 8

def from_float(key, depth=0):
    """在 float_sys / float 之间解析别名链，不会回查 pattern。"""
    if depth > MAX_DEPTH:
        return '<环>'
    val = alias.get(key, base.get(key))
    if val is None:
        return None
    m = re.match(r'\$float:(\S+)', str(val))
    if m:
        nxt = from_float(m.group(1), depth + 1)
        return f'{val} -> {nxt}' if nxt else val
    return val

def resolve(pattern_name, key):
    """先查 pattern（只跳一次），再走 float 链。key 不存在时直接查 float。"""
    val = pats.get(pattern_name, {}).get(key)
    if val is None:
        return from_float(key)
    m = re.match(r'\$float:(\S+)', str(val))
    if m:
        nxt = from_float(m.group(1))
        return f'{val} -> {nxt}' if nxt else val
    return val

queries = [
    ('ohos_search_pattern', [
        'search_default_height', 'search_height', 'search_text_field_border_radius',
        'search_icon_size', 'search_icon_height', 'search_icon_left_space',
        'search_icon_right_space', 'search_close_icon_size',
        'search_close_icon_hot_zone_horizontal', 'search_text_field_padding_left',
        'search_text_field_padding_right', 'search_text_field_right_padding_without_button',
        'search_text_field_right_padding_with_button', 'search_button_space',
        'search_button_text_padding', 'search_divider_side_space',
        'search_border_width', 'search_focus_glow_padding', 'search_cancel_button_style',
    ]),
    (None, [
        'chip_normal_height', 'chip_small_height', 'chip_activated_normal_height',
        'chip_activated_small_height', 'chip_normal_radius', 'chip_small_radius',
        'chip_border_radius_normal', 'chip_border_radius_small',
        'chip_normal_text_padding', 'chip_small_text_padding',
        'chip_normal_text_margin', 'chip_small_text_margin',
        'chip_normal_icon_size', 'chip_small_icon_size',
        'chip_normal_font_size', 'chip_small_font_size', 'chip_border_width',
    ]),
    (None, [
        'subheader_single_title_height', 'subheader_single_subtitle_height',
        'subheader_double_height', 'subheader_title_font_size',
        'subheader_titles_space', 'subheader_left_icon_size',
        'subheader_left_icon_end_margin', 'subheader_content_margin_start',
        'subheader_content_margin_end', 'subheader_content_padding',
    ]),
]

for pattern_name, keys in queries:
    if prefix and not any(k.startswith(prefix) for k in keys):
        continue
    title = pattern_name or 'float.json 直接查'
    print(f'\n=== {title} ===')
    for k in keys:
        if prefix and not k.startswith(prefix):
            continue
        v = resolve(pattern_name, k) if pattern_name else from_float(k)
        print(f'  {k:46s} = {v if v is not None else "<表中无此键>"}')

print(f'\n提示：以上 "->" 链的末端就是真值。单位 vp 是逻辑像素，fp 是字号。')
print('注意：chip_small_height 的单位是 lpx（全表仅两处），数值等同 vp 但语义不同，')
print('      写代码注释时别写成 vp。')
PY