#!/bin/zsh
# 逐页滚动采集：每个分类页从头往下滚，每屏存一张。
#
# 之所以一次采多屏再挑：README 里那 30 张图对应的是「某个组件正好在屏上」的
# 时刻，靠固定滚动次数对不准。先全采，再从里面挑内容最完整的。
#
# 用法：./tool/capture_page.sh <页面名> <首页 y 坐标> <屏数>
set -e

HDC="${HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
BUNDLE=com.example.ohos_ui_example
name="$1"; y="$2"; n="$3"
out="/tmp/cap/$name"
mkdir -p "$out"

shot() { "$HDC" shell "snapshot_display -f /data/local/tmp/_s.jpeg" >/dev/null
         "$HDC" file recv /data/local/tmp/_s.jpeg "$1" >/dev/null; }

# 回首页：只按一次返回就够。之前连按三次会直接退出应用掉到桌面 ——
# 首页本身没有上一页，多按的都作用在系统层面。
"$HDC" shell "uitest uiInput keyEvent Back" >/dev/null 2>&1 || true
sleep 1

# 保险起见重新拉起并确认在前台（退出过的话 Back 已经把应用关了）
"$HDC" shell "aa start -a EntryAbility -b $BUNDLE" >/dev/null 2>&1 || true
sleep 2

# 进分类页
"$HDC" shell "uitest uiInput click 640 $y" >/dev/null
sleep 2

for i in $(seq 1 $n); do
  shot "$out/$(printf %02d $i).png"
  if [ "$i" -lt "$n" ]; then
    "$HDC" shell "uitest uiInput swipe 640 2200 640 700" >/dev/null
    sleep 1
  fi
done

echo "captured $n screens into $out"