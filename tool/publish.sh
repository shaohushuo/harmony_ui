#!/usr/bin/env bash
# 本地发布 harmony_ui 到 pub.dev（已配置代理，避免连不上外网）
set -euo pipefail

export HTTP_PROXY=http://127.0.0.1:1087
export HTTPS_PROXY=http://127.0.0.1:1087
export ALL_PROXY=socks5://127.0.0.1:1080
export NO_PROXY=localhost,127.0.0.1

DART_BIN="${DART_BIN:-dart}"

echo "== dry run =="
"$DART_BIN" pub publish --dry-run

echo "== publish =="
"$DART_BIN" pub publish --force
