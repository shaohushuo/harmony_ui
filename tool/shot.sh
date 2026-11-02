#!/bin/zsh
# 在鸿蒙模拟器上抓图的小工具。
#
# 之所以留在这里而不是 /tmp：README 的截图要用它重拍，未来换主题/换机型时还得再跑。
#
# 用法：
#   ./tool/shot.sh <输出文件>          # 抓当前屏
#   ./tool/shot.sh tap <x> <y>         # 点一下
#   ./tool/shot.sh swipe <x1> <y1> <x2> <y2>
#   ./tool/shot.sh dump <文件>         # 导出当前布局（找控件坐标用）
set -e

HDC="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
REMOTE=/data/local/tmp/_shot.jpeg

cmd="$1"

case "$cmd" in
  tap)
    "$HDC" shell "uitest uiInput click $2 $3" >/dev/null
    ;;
  swipe)
    "$HDC" shell "uitest uiInput swipe $2 $3 $4 $5" >/dev/null
    ;;
  dump)
    "$HDC" shell "uitest dumpLayout -p /data/local/tmp/_layout.json" >/dev/null
    "$HDC" file recv /data/local/tmp/_layout.json "$2" >/dev/null
    ;;
  *)
    # 默认当输出路径。先抓 PNG（无损），再带回来。
    out="$1"
    "$HDC" shell "snapshot_display -f $REMOTE" >/dev/null
    "$HDC" file recv "$REMOTE" "$out" >/dev/null
    echo "$out"
    ;;
esac