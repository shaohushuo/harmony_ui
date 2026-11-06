#!/bin/zsh
# 按主题批量采集分类页。
#
# 为什么按主题整轮跑，而不是「一页切一次皮」：切主题会重建整棵树，中途切容易
# 把滚动位置和页面栈搞混；一轮录到底再换皮，两套图的取景位置才可比。
#
# 为什么返回点标题栏左上角、不用 keyEvent Back：左上角在首页是房子图标（点了
# 没事），在分类页是 ←（pop 一层），一条规则两边都安全。而 Back 在首页上会
# 退出应用 —— 应用一被杀，内存里的主题档位就丢了，接着采的图会悄悄变回彩屏，
# 而这看上去和「采对了」一模一样。
#
# 用法：
#   ./tool/capture_theme.sh <light|ink>                # 全部 8 个分类
#   ./tool/capture_theme.sh <light|ink> 导航类          # 只采指定分类（可多个）
# 环境变量 SCREENS 可覆盖每分类屏数（默认 5，导航类 9 —— 见文件末尾「为什么」）。
set -e

HDC="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
BUNDLE=com.example.ohos_ui_example
cd "$(dirname "$0")/.."
mode="$1"
out="/tmp/cap2/$mode"
mkdir -p "$out"

shot() { ./tool/shot.sh "$1" >/dev/null; }
tap()  { "$HDC" shell "uitest uiInput click $1 $2" >/dev/null; }
swipe(){ "$HDC" shell "uitest uiInput swipe $1 $2 $3 $4" >/dev/null; }

# 一路点左上角回首页，再上划把 ListView 顶回顶部。
home_top() {
  local i=0
  while [ $i -lt 3 ]; do
    tap 90 234
    sleep 0.7
    i=$((i+1))
  done
  for i in 1 2 3 4; do
    swipe 640 900 640 2500
    sleep 0.3
  done
  sleep 0.6
}

capture() {
  local name="$1"
  local screens="${2:-${SCREENS:-5}}"
  ./tool/tap_text.sh "$name" >/dev/null || { echo "skip $name"; return; }
  sleep 1.8
  local i=1
  while [ $i -le "$screens" ]; do
    shot "$out/${name}_$(printf %02d $i).png"
    # 侧边栏那页的 overlay 是全屏可点击区域，会吞掉中间的纵向手势 ——
    # 走右侧留白（x≈1150）才能滚进去。
    swipe 1150 2200 1150 700
    sleep 0.9
    i=$((i+1))
  done
  echo "captured $name × $screens"
}

home_top

# 切主题。**这一步曾经漏掉**：旧版脚本收了 `$mode` 却只用它拼输出目录名，
# 从不真正切主题 —— 于是 `light` 与 `ink` 两套图除了顶部时钟几乎逐像素相同，
# 而文件名各自叫「light」「ink」，看起来完全像采对了。核对方式：对同名图做
# 像素差，若差异只落在顶部时钟区域（<0.5% 像素），就是主题没切。
#
# 主题按钮在标题栏右侧（点击循环 light → dark → ink → light）。
#
# **不能假定起点**：脚本可能从上一轮的任意档位开始跑。所以先「检测」再前进：
# 逐次点击直到截图满足目标特征（ink 是灰阶、light/dark 有彩色）。最多循环
# 3 次一定能到（3 次正好回到原点）。
#
# 判定要用**两个维度**：平均饱和度分「彩 / 灰」，平均亮度分「浅 / 深」。
#
# 早先只用饱和度，于是 `light` 与 `dark` 共用一条「有彩色」判据 —— 从深色档
# 启动时 `switch_theme light` 会判定「已经是浅色」直接返回，结果整套图在深色
# 主题下拍完、还都叫 `light_*`。这和旧版「收 $mode 却从不切主题」是同一类
# 失败：判据看起来在检查，实际检查不出这件事。深色主题也是低亮度，光看亮度
# 分不开 dark 与 ink；墨屏整屏 R=G=B，光看饱和度又分不开 light 与 dark ——
# 两个轴缺一不可。
theme_probe() {
  local shot_p="/tmp/_theme_probe.png"
  shot "$shot_p"
  python3 - "$shot_p" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGB').resize((64, 64))
px = list(im.get_flattened_data()) if hasattr(im, 'get_flattened_data') else list(im.getdata())
sat = []
lum = []
for r, g, b in px:
    mx = max(r, g, b)
    sat.append((mx - min(r, g, b)) / mx if mx else 0)
    lum.append((r * 0.299 + g * 0.587 + b * 0.114) / 255)
mean_sat = sum(sat) / len(sat)
mean_lum = sum(lum) / len(lum)
# 墨屏严格 R=G=B（留一点余量给抗锯齿）；彩屏平均亮度 0.5 一分为二。
gray = mean_sat < 0.005
if gray:
    print('gray')
else:
    print('light' if mean_lum > 0.5 else 'dark')
PY
}

switch_theme() {
  local want="$1"
  # **`ink` 与 `gray` 是两个词，说的是同一件事**。调用方写 `ink`（和 `mode`、目录名、
  # README 一致），探针只会输出 `gray`/`light`/`dark`（它比的是像素，不知道档位叫什么）。
  # 早先这里直接把两者 `=` 相比，于是 `./capture_theme.sh ink` 永远判「切不过去」：
  # 它其实每一轮都成功转到了墨屏，只是没有一次被认出来，最后 3 次点满绕回浅色。
  local target="$want"
  [ "$want" = "ink" ] && target=gray

  local i=0 kind
  # 探针 4 次、点击至多 3 次：点击是 3 态循环（light → dark → gray → light，实测），
  # 点满 3 次必定回到原点，所以 4 次探测正好覆盖「点 0/1/2/3 次之后」的每个状态。
  #
  # 早先写 `while [ $i -lt 3 ]` 且循环体是「探测 → 点击」，最后一次点击之后再没有
  # 探测 —— `kind` 停在点击前的值上。把上面的 `ink`/`gray` 修好之后这个差一错误才
  # 露出来：探到 gray 会立刻 return，反而看不见。
  while [ $i -le 3 ]; do
    kind="$(theme_probe)"
    if [ "$kind" = "$target" ]; then
      echo "theme → $want"
      return
    fi
    tap 1168 234
    sleep 1.2
    i=$((i+1))
  done
  # 不能只警告后继续：接下来每一张图都会被贴错主题标签，而文件名、目录名、
  # README 链接全都正常 —— 这正是本脚本反复要防的那类失败。直接停。
  echo "错误：3 次点击后仍未切到 $want（探针最后一次判为 $kind），停止采集以免产出错标主题的图" >&2
  exit 1
}

switch_theme "$mode"

# 每个分类要拍几屏 —— 不是「统一多拍点」就行。
#
# 导航类一页比别的分类长得多：前 5 屏只走到「子页签 / 胶囊 ChipGroup」，而本轮
# 阶段 E 交付的**悬浮页签栏**（`OhosFloatingTabBar`）与**迷你栏**（`OhosMiniBar`）
# 在它们后面。按 5 屏拍完，这两个组件在全部 45 张图里一次都不出现 —— 而
# README 的截图表里写着「平铺+悬浮底部页签」，文案有、图上无，属于最难发现的那种
# 缺图：文件存在、链接可点、只是拍的不是它。
#
# 反向的坑是「全局加屏数」：其余分类 5 屏就到页底，多拍的会是一串重复的
# 空白帧，既占体积又让归档时挑图变难。所以按分类给。
screens_for() {
  case "$1" in
    导航类) echo "${SCREENS:-11}" ;;
    # UI Design Kit 也有 10 个区块：点光源 / 按压阴影 / 侧边栏 / 横滑列表项 /
    # 常驻通知 / 子页签分割线 / 颜色选择器 / 模糊标题栏 / 操作栏 / 分层图标 /
    # 多窗入口。按 5 屏只到「常驻通知」，后 5 个组件一张图都没有 —— README 里
    # `kit_08_picker_picked` / `kit_09_blur_scrolled` / `kit_10_actionbar` /
    # `kit_11_bottom_sections` 四行因此长期对不上图（文件名在、内容是别的页）。
    "UI Design Kit") echo "${SCREENS:-11}" ;;
    *)      echo "${SCREENS:-5}" ;;
  esac
}

# 只有第一个位置参数是主题，其余当作「只采这几个分类」的过滤器。
shift
if [ $# -gt 0 ]; then
  cats=("$@")
else
  cats=(导航类 展示类 操作类 输入类 选择类 布局与动效 容器类 "UI Design Kit")
fi

for c in "${cats[@]}"; do
  capture "$c" "$(screens_for "$c")"
  home_top
done

echo "done → $out"