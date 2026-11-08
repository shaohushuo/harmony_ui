#!/bin/zsh
# 从官方「控件概览」出发，逐个控件解析其设计文档末尾的「## 开发文档」链接，
# 再验证这些组件参考文档是否真的可取。
#
# 为什么这么做，而不是猜 slug：
# 此前本项目直接拼 `doccenter-references/api/ui-design-<猜的slug>.md`，猜中 8 个、
# 猜空十几个，然后把「猜空」当成「该组件无文档」写进了规划 —— 结论是错的。
# 正确链路是单向可追溯的：
#   概览页 → 控件设计文档（doccenter-ux-design/<slug>-<id>.md）
#           → 该文档末尾「## 开发文档」里的链接（harmonyos-references/ui-design-<x>）
#           → 换成可直取的 .md 地址
# 链接是官方自己写的，不需要猜。
#
# 用法：./tool/trace_control_docs.sh          # 只解析并写报告
#       ./tool/trace_control_docs.sh --fetch  # 顺便把能取到的参考文档下到 doc/reference/api/
set -e
cd "$(dirname "$0")/.."

OUT=doc/reference/api
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

OVERVIEW="https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/general_overview-0000001929599380.md"
# 概览页里的控件链接是 design-guides/<slug>-<id>，换成 doccenter-ux-design/ 才能取到 md。
curl -sfL --max-time 60 -o "$TMP/overview.md" "$OVERVIEW"

grep -oE '\*\*\[[^]]+\]\(https://developer\.huawei\.com/consumer/cn/doc/design-guides/[^)]+\)\*\*' \
  "$TMP/overview.md" |
  sed -E 's/^\*\*\[([^]]+)\]\((.*)\)\*\*$/\1|\2/' > "$TMP/controls.txt"

echo "概览页解析出 $(wc -l < "$TMP/controls.txt" | tr -d ' ') 个控件"
echo

printf '%-12s | %-46s | %s\n' "控件" "开发文档（组件参考）" "状态"
echo "-------------|------------------------------------------------|------------------"

report=0
for line in "${(@f)$(<"$TMP/controls.txt")}"; do
  name="${line%%|*}"
  url="${line##*|}"
  slug="$(basename "$url")"                     # e.g. component_snackbar-0000002340726169
  doc="https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/$slug.md"

  if ! curl -sfL --max-time 40 -o "$TMP/$slug.md" "$doc"; then
    printf '%-12s | %-46s | %s\n' "$name" "-" "设计文档取不到"
    report=$((report + 1))
    continue
  fi

  # 末尾「## 开发文档」段落里的第一个链接；有的控件这一节可能不存在。
  dev=$(awk '/^## 开发文档/{f=1} f' "$TMP/$slug.md" | grep -oE '\(https://[^)]+\)' | head -1 | tr -d '()')

  if [[ -z "$dev" ]]; then
    printf '%-12s | %-46s | %s\n' "$name" "-" "设计文档无「开发文档」节"
    report=$((report + 1))
    continue
  fi

  # 参考页是 SPA，但换到 doccenter-references/api/ + .md 后能直接取回原文。
  # HDS 走这条；开源 ArkUI 组件（ts-*）另从 OpenHarmony 仓库取，这里只做可达性标记。
  # 官方链接常带锚点（#showtoast / #toolbarconfiguration10），取文档时要先剥掉，
  # 否则会把 anchor 当成文件名的一部分去请求，得到 200 + 一个壳页面。
  refname="${dev##*/}"
  refname="${refname%%#*}"          # 剥锚点
  mdurl="https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/$refname.md"
  code=$(curl -sL --max-time 40 -o "$TMP/ref-$refname.md" -w "%{http_code}" "$mdurl")
  if [[ "$code" == "200" ]] && head -1 "$TMP/ref-$refname.md" | grep -q '^# '; then
    printf '%-12s | %-46s | %s\n' "$name" "$refname" "OK"
    if [[ "$1" == "--fetch" ]]; then
      mkdir -p "$OUT"
      cp "$TMP/ref-$refname.md" "$OUT/hds-$refname.md" 2>/dev/null || true
    fi
  else
    printf '%-12s | %-46s | %s\n' "$name" "$refname" "无可直取原文（$code）"
    report=$((report + 1))
  fi
done

echo
echo "需要人工看一眼的：$report 个"