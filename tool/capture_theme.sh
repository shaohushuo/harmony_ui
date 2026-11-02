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
# 用法：./tool/capture_theme.sh <light|ink>
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
  ./tool/tap_text.sh "$name" >/dev/null || { echo "skip $name"; return; }
  sleep 1.8
  local i=1
  while [ $i -le 5 ]; do
    shot "$out/${name}_$(printf %02d $i).png"
    # 侧边栏那页的 overlay 是全屏可点击区域，会吞掉中间的纵向手势 ——
    # 走右侧留白（x≈1150）才能滚进去。
    swipe 1150 2200 1150 700
    sleep 0.9
    i=$((i+1))
  done
  echo "captured $name"
}

home_top
for c in 导航类 展示类 操作类 输入类 选择类 布局与动效 容器类 "UI Design Kit"; do
  capture "$c"
  home_top
done

echo "done → $out"