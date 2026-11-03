#!/bin/zsh
# 抓取 ArkUI 组件的**实现源码**到 doc/source/。
#
# 第三条链路，与 tool/fetch_reference.sh 的链路 1/2 不同：
#
#   fetch_reference.sh 抓的是「文档」（markdown），回答「有哪些属性、默认值是什么」；
#   本脚本抓的是「实现」（ArkTS 源码），回答「这个组件到底画成什么样」——
#   高度、圆角、内边距、文本边距、断点宽度这些**几何数值**只在源码里能读到。
#
# 为什么必须要有这一层：
#   官方文档大量写「默认值：$r('sys.float.chip_normal_height')」，把一个资源令牌
#   当答案给你，而令牌的真实数值编在系统资源的二进制 resources.index 里（RestoolV2
#   格式，本机 SDK 的 previewer/common/resources/resources.index）。我们能读到的
#   只是令牌名，读不到 40vp 还是 36vp。源码里的**硬编码**部分因此是不可替代的。
#   能拿到硬编码数值的典型：Chip 的 minLabelWidth=12 / borderWidth=2 /
#   normalMargin 6/6 / breakPointMinWidth=128、ChipGroup 的 36/28 与 8/16/16、
#   半模态的 DEFAULT_DIVIDER_HEIGHT=12.0vp 等。
#
# 源码位置：
#   advanced_ui_component/<组件>/source/<组件>.ets   —— ArkTS 实现的进阶组件
#   frameworks/core/components_ng/pattern/<组件>/     —— C++ 实现的系统组件
#
# 只抓 ArkTS 那部分：C++ 侧几何值几乎全走 theme->GetAttr(...)，即同样退回资源令牌，
# 抓下来能提供的硬编码信息极少（已实测 search_layout_algorithm.cpp 仅一条
# DEFAULT_DIVIDER_HEIGHT）。ArkTS 侧的 defaultTheme 常量块是可直接抄的。
#
# 用法：./tool/fetch_source.sh
set -e
cd "$(dirname "$0")/.."

RAW="https://gitee.com/openharmony/arkui_ace_engine/raw/master/advanced_ui_component"
OUT=doc/source
mkdir -p "$OUT"

# 与官方「控件概览」相关的进阶组件（对应 advanced_ui_component 下的目录名）。
# 用官方目录名原样拼，不做任何猜测 —— 上两轮的教训就是「猜名字」不可信。
COMPONENTS=(
  chip            # 子页签 / 标签
  chipgroup       # 子页签（胶囊组，容器间距与高度在这）
  segmentbutton   # 分段按钮
  segmentbuttonv2
  dialog          # 弹出框
  dialogv2
  progressbutton  # 进度按钮
  progressbuttonv2
  subheader       # 小标题
  toolbar         # 工具栏
  toolbarv2
  selectionmenu   # 文本选择菜单
  counter         # 计数器
  arcbutton       # 弧形按钮
  arcslider       # 弧形滑块
  editabletitlebar # 可编辑标题栏（文档侧唯一确认缺失，源码却存在）
  selecttitlebar  # 选择标题栏
  tabtitlebar     # 页签标题栏
  composetitlebar # 组合标题栏
  composelistitem # 组合列表项
  popup           # 气泡
  exceptionprompt # 异常提示
  treeview        # 树视图
  swiperefresher  # 下拉刷新
  filter          # 筛选器
  multinavigation # 多级导航
  splitlayout     # 分栏
  foldsplitcontainer
  gridobjectsortcomponent
)

fail=0
for n in $COMPONENTS; do
  out="$OUT/$n.ets"
  # 不猜文件名。目录名与文件名并不一致，且不一致的方式还不统一：
  #   chip/source/chip.ets                          目录名 = 文件名
  #   gridobjectsortcomponent/source/GridObjectSortComponent.ets   驼峰
  # 本轮先试「首字母大写」猜法，对 gridobjectsortcomponent 仍然 404 ——
  # 因为它是驼峰，不是简单首字母大写。于是改成**列目录取 .ets**：
  # 用 API 拿到真实文件名，这就不存在「猜」这个动作了。
  # 上一轮「猜 slug」的教训在这里再验证了一遍。
  list=$(curl -sL --max-time 60 "https://gitee.com/api/v5/repos/openharmony/arkui_ace_engine/contents/advanced_ui_component/$n/source?ref=master")
  fn=$(echo "$list" | sed -n 's/.*"name":"\([^"]*\.ets\)".*/\1/p' | head -1)
  # sed 在单行 JSON 上只能取到最后一个，改用 grep -o 逐个抓再取首个
  if [[ -z "$fn" ]]; then
    fn=$(echo "$list" | tr '{' '\n' | grep -o '"name":"[^"]*\.ets"' | head -1 | sed 's/"name":"//;s/"$//')
  fi
  ok=0
  if [[ -n "$fn" ]]; then
    code=$(curl -sL --max-time 60 -o "$out" -w "%{http_code}" "$RAW/$n/source/$fn")
    if [[ "$code" == "200" ]] && head -3 "$out" | grep -qE '^/\*|^import |^export '; then
      ok=1
    fi
  fi
  if [[ "$ok" != "1" ]]; then
    echo "FAIL $code $n (fn=${fn:-未取到文件名})"
    rm -f "$out"
    fail=1
  fi
done

count=$(ls "$OUT"/*.ets 2>/dev/null | wc -l | tr -d ' ')
echo "已抓取 ${count} 份组件源码 → $OUT"
[[ "$fail" == "0" ]] || { echo "有组件抓取失败，见上方 FAIL 行"; exit 1; }