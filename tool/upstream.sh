#!/bin/zsh
# 上游资料知识库的唯一入口：抓取 / 重建索引 / 核对 / 看现状。
#
# 为什么需要它：四层资料（开发文档、设计规范+配图、组件源码、令牌表）原先各有
# 一个 fetch_* 脚本，分散在三处目录，谁也说不清「现在这份快照是什么时候、抓全了没有」。
# doc/reference/ 现在是四层的唯一根，本脚本是它的唯一入口 ——
# **不要直接调 tool/fetch_*.sh**，那条路径不写 manifest，快照会悄悄变旧。
#
# 用法：
#   ./tool/upstream.sh                 # 全部重抓 + 重建索引 + 刷新清单
#   ./tool/upstream.sh api             # 只抓开发参考文档
#   ./tool/upstream.sh ux              # 只抓设计规范与 608 张配图
#   ./tool/upstream.sh index           # 不联网，重跑配图扫描与规格汇总
#   ./tool/upstream.sh verify          # 重新统计并与 manifest 比对（CI 用，非零退出）
#   ./tool/upstream.sh status          # 只看现状：每层多少文件、多大、什么时候抓的
set -u
cd "$(dirname "$0")/.."

REF=doc/reference
fails=()

need() {
  # 抓取前先确认目标目录在，否则脚本会往一个不存在的路径里写
  [[ -d "$1" ]] || { echo "缺少 $1（先跑 ./tool/upstream.sh 完整抓一次）"; return 1; }
}

do_api() {
  echo "── 开发参考文档 → $REF/api"
  ./tool/fetch_reference.sh
}

do_source() {
  echo "── 组件实现源码 → $REF/source"
  ./tool/fetch_source.sh
}

do_resources() {
  echo "── 系统资源令牌表 → $REF/resources"
  ./tool/fetch_sys_resources.sh
}

do_ux() {
  echo "── 设计规范 + 配图 → $REF/design"
  ./tool/fetch_ux_images.sh
}

do_index() {
  echo "── 重建派生索引（离线）"
  # 顺序固定：scan 产出的 doc/ux-images.scan.json 是 make_spec_summary 的输入之一
  python3 tool/scan_ux_images.py
  python3 tool/make_spec_summary.py
}

do_manifest() {
  python3 tool/make_manifest.py
}

run() {
  # 单个子命令失败不中断整轮：抓取失败最该被看见，而不是让后面几层都不跑
  local name=$1
  shift
  if ! "$@"; then
    fails+=("$name")
  fi
}

cmd="${1:-all}"
case "$cmd" in
  all)
    run api do_api
    run source do_source
    run resources do_resources
    run ux do_ux
    [[ ${#fails[@]} -eq 0 ]] && run index do_index
    do_manifest
    ;;
  api)       do_api ;;
  source)    do_source ;;
  resources) do_resources ;;
  ux)        do_ux ;;
  index)     do_index ;;
  manifest)  do_manifest ;;
  # 这两个是「查询」命令：退出码就是结论，必须原样透传 ——
  # 曾经在这里写成普通 case 分支，`verify` 报出差异后又被结尾的 fails 汇总
  # 覆盖成 0，CI 上看起来是绿的。
  verify)    python3 tool/make_manifest.py --check; exit $? ;;
  status)    python3 tool/make_manifest.py --print; exit $? ;;
  -h|--help|help)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "未知子命令：$cmd"
    echo "可用：all | api | source | resources | ux | index | manifest | verify | status"
    exit 2
    ;;
esac

if [[ ${#fails[@]} -gt 0 ]]; then
  echo ""
  echo "以下步骤失败：${fails[*]}"
  echo "上游内容会随版本漂移，失败项必须重跑到全绿，不要用半份快照继续核对。"
  exit 1
fi
