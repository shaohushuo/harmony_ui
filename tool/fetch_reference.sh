#!/bin/zsh
# 抓取 ArkUI 官方参考文档到 doc/reference/。
#
# 两条链路，别混：
#
# 1. 开源 ArkUI 组件 → OpenHarmony 文档仓库原文
#    中文站参考页（harmonyos-references/*）是 SPA，静态请求只会返回 404 页；
#    连页面里 `<link rel="alternate" type="text/markdown">` 指的那个 .md 地址
#    也是 404。所以改抓 OpenHarmony 仓库 —— 内容与官网同源，且自带完整的
#    ArkTS 示例代码（官网 SPA 渲染出来的就是这些）。
#
# 2. 闭源 HDS 组件 → developer.huawei.com 的 doccenter-references 前缀
#    HdsActionBar 这类组件不在 OpenHarmony 仓库里，但官网有一份 markdown 原文，
#    路径形如 `doccenter-references/api/ui-design-<小写slug>.md`，能直接 200 取回。
#    这条路径是 0.6 才发现的 —— 0.5 时期误以为「HDS 闭源 = 无文档」，直接按设计
#    规范猜规格，属于没查就说没有。slug 必须全小写，`ui-design-hdsActionBar.md`
#    会 404。同一前缀对 `ui-design-hdssearch` / `ui-design-hdsbutton` 等确实 404
#    （那些组件确实没有文档），所以取不到仍要当失败报出来，不能静默跳过。
#
# 用法：./tool/fetch_reference.sh
set -e
cd "$(dirname "$0")/.."

BASE="https://raw.gitcode.com/openharmony/docs/raw/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts"
HDS_BASE="https://developer.huawei.com/consumer/cn/doc/doccenter-references/api"
OUT=doc/reference
mkdir -p "$OUT"

# 与官方「控件概览」42 项对应的 ArkUI 组件。改这张表等于改对照范围。
#
# 注意：这里混了两类来源。多数 `ts-*` 来自 OpenHarmony 仓库；而
# `ohos-arkui-advanced-chipgroup` / `ts-methods-custom-dialog-box` /
# `ts-universal-attributes-sheet-transition` / `arkts-apis-uicontext-promptaction`
# 这 4 份在 OpenHarmony 仓库里没有对应文件名（或名字不同），是从设计文档末尾
# 「## 开发文档」的链接反查出来的，走官网 doccenter-references 前缀取。见下方
# HDS_COMPONENTS 之外的 SPEC_COMPONENTS。
COMPONENTS=(
  # 展示
  ts-basic-components-datapanel ts-basic-components-gauge ts-container-badge
  ts-container-alphabet-indexer ts-basic-components-blank ts-basic-components-divider
  ts-basic-components-image ts-basic-components-qrcode ts-basic-components-textclock
  ts-basic-components-text ts-basic-components-progress ts-basic-components-loadingprogress
  ts-basic-components-scrollbar
  # 导航
  ts-container-tabs ts-container-swiper ts-basic-components-navigation
  # 操作
  ts-basic-components-button ts-basic-components-select ts-basic-components-toggle
  ts-basic-components-menu ohos-arkui-advanced-Chip ohos-arkui-advanced-ToolBar
  ts-basic-components-toolbaritem ohos-arkui-advanced-SelectionMenu
  # 输入
  ts-basic-components-textinput ts-basic-components-search ohos-arkui-advanced-Counter
  ts-container-counter ts-basic-components-patternlock
  # 通用属性：TextInput 的 showCounter 配置项 InputCounterOptions 定义在这里，
  # 正文文档只写了「见 ts-universal-attributes-text-style.md#inputcounteroptions11」。
  # 少了它就查不到 thresholdPercentage 的有效区间 [1,100] 与 highlightBorder 默认值。
  ts-universal-attributes-text-style
  # 选择
  ts-basic-components-checkbox ts-basic-components-checkboxgroup ts-basic-components-radio
  ts-basic-components-rating ts-basic-components-slider ts-basic-components-calendarpicker
  ts-container-ui-picker-component ohos-arkui-advanced-SegmentButton
  # 容器
  ts-container-list ts-container-listitem ts-container-listitemgroup
  ohos-arkui-advanced-Dialog ohos-arkui-advanced-SubHeader ts-universal-attributes-popup
)

# 闭源 HDS 组件（@kit.UIDesignKit）。slug 全小写，见文件头注释。
# UI 组件外还有两份「非 UI 组件」：hdsnavigation 是导航根容器、hdsmaterial 是材质枚举，
# 两者都影响 UI 规格，所以一并抓。
HDS_COMPONENTS=(
  hdsactionbar hdssnackbar hdstabs hdsnavigation
  hdslistitem hdslistitemcard hdscolorpicker hdsmaterial
)

# 由设计文档「## 开发文档」链接反查得到、但 OpenHarmony 仓库里取不到的那几份。
# 单独列一张表，是为了让「这份文档是怎么找到的」在脚本里留痕 —— 上一轮正是因为
# 只在开源仓库里找了没找到，就写下了「该组件无文档」的错误结论。
SPEC_COMPONENTS=(
  ohos-arkui-advanced-chipgroup            # 子页签（官方链接实测大小写两种都能取）
  ts-methods-custom-dialog-box             # 弹出框
  ts-universal-attributes-sheet-transition # 半模态面板
  arkts-apis-uicontext-promptaction        # 即时反馈（Toast 在 UIContext 上）
)

fail=0
for n in $COMPONENTS; do
  code=$(curl -sL --max-time 60 -o "$OUT/$n.md" -w "%{http_code}" "$BASE/$n.md")
  # 404 时上游返回的是 47 字节的 "404: Not Found"，别把它当文档留在仓库里
  if [[ "$code" != "200" ]] || ! head -1 "$OUT/$n.md" | grep -q '^# '; then
    echo "FAIL $code $n"
    rm -f "$OUT/$n.md"
    fail=1
  fi
done

# HDS 文档 404 时上游返回的是完整 Angular 外壳（约 14KB HTML），比 OpenHarmony
# 那个 47 字节的提示更难发现，所以同样要靠「首行是不是 markdown 标题」来筛。
for n in $HDS_COMPONENTS; do
  out="$OUT/hds-$n.md"
  code=$(curl -sL --max-time 60 -o "$out" -w "%{http_code}" "$HDS_BASE/ui-design-$n.md")
  if [[ "$code" != "200" ]] || ! head -1 "$out" | grep -q '^# '; then
    echo "FAIL $code hds-$n"
    rm -f "$out"
    fail=1
  fi
done

# 由设计文档链接反查的那几份，走官网 doccenter-references 前缀（同 HDS 链路）。
for n in $SPEC_COMPONENTS; do
  out="$OUT/hds-$n.md"
  code=$(curl -sL --max-time 60 -o "$out" -w "%{http_code}" "$HDS_BASE/$n.md")
  if [[ "$code" != "200" ]] || ! head -1 "$out" | grep -q '^# '; then
    echo "FAIL $code hds-$n"
    rm -f "$out"
    fail=1
  fi
done

# 记录来源与时间，方便判断快照多旧。
# 放在 mkdir 之后、循环之前写一次即可 —— 注意本脚本会先删掉旧快照（见下），
# README.md 不入这份清单，别一起清掉。
cat > "$OUT/sources.json" <<JSON
{
  "overview": "https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design/general_overview-0000001929599380",
  "openHarmony": "$BASE",
  "hds": "$HDS_BASE",
  "fetchedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "_traceMethod": "权威清单来自 tool/trace_control_docs.sh：概览页 42 个控件的链接 → 各自设计文档末尾「## 开发文档」→ 组件参考文档。不要靠猜 slug。",
  "noDevDocLink": {
    "色彩选择器": "color-picker-0000002574393143.md 只有「如何使用/最佳实践/布局规则」三节，官方未给「开发文档」链接；但 ui-design-hdscolorpicker 参考文档确实存在（本快照已收录）。属于设计文档漏链接，不是文档缺失"
  },
  "confirmedAbsent": {
    "EditableTitleBar（仅限参考文档层）": "参考文档确实查不到：ui-design-editable-title-bar / ui-design-editabletitlebar / hdseditabletitlebar / hdseditabletitle-bar 均 404，HdsNavigation 里也无对应章节。**但规格并不缺** —— advanced_ui_component/editabletitlebar/source/editabletitlebar.ets 一直存在（958 行），栏高 56 / 标题 20vp / 副标题 14vp / 主副标题占宽 0.65:0.35，见 doc/source/README.md。「文档没有」不等于「没有规格」，本字段必须写明限定层级"
  }
}
JSON

count=$(ls "$OUT"/*.md 2>/dev/null | grep -v README | wc -l | tr -d ' ')
echo "已抓取 ${count} 份参考文档 → $OUT"
[[ "$fail" == "0" ]] || { echo "有组件抓取失败，见上方 FAIL 行"; exit 1; }