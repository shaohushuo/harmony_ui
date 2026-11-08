#!/usr/bin/env python3
"""统计 doc/reference/ 四层上游资料，生成/核对 manifest.json。

为什么要这份清单：这四层都是**不入库的上游快照**，换台机器、清一次缓存就没了；
而「有没有抓全」在目录里看不出来 —— 少一份文档和根本没抓过，在 `ls` 里长得一样。
manifest 把「从哪抓、抓了多少、什么时间抓的」变成可 diff 的事实。

三种用法（`tool/upstream.sh` 分别对应 manifest / verify / status）：

    python3 tool/make_manifest.py            # 重算并写 doc/reference/manifest.json
    python3 tool/make_manifest.py --check    # 与现有 manifest 比对，不一致则非零退出
    python3 tool/make_manifest.py --print    # 只打印现状，不读也不写 manifest

`--check` 只比**数量与字节数**，不比时间戳：上游内容更新会让字节数变，这正是
需要重跑 `upstream.sh` 的信号；而 mtime 会被本地 checkout/解压改变，不可靠。
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
from datetime import datetime, timezone

REF = "doc/reference"
MANIFEST = os.path.join(REF, "manifest.json")

# 每层一份：目录、上游地址、文件匹配、这一层回答什么问题。
# 上游地址与 README 里写的必须一致 —— 改这里就要改 README，两处都指着同一件事。
LAYERS = [
    {
        "key": "api",
        "title": "开发参考文档",
        "path": f"{REF}/api",
        "glob": "*.md",
        "upstream": [
            "https://raw.gitcode.com/openharmony/docs/raw/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts",
            "https://developer.huawei.com/consumer/cn/doc/doccenter-references/api",
        ],
        "answers": "一个控件有几个形态、每个形态的属性与默认值、官方示例代码",
        "fetchedBy": "tool/fetch_reference.sh",
    },
    {
        "key": "design",
        "title": "设计规范与配图",
        "path": f"{REF}/design",
        "glob": "*.md",
        "upstream": ["https://developer.huawei.com/consumer/cn/doc/doccenter-ux-design"],
        "answers": "控件该怎么用、布局与间距的视觉规则；**具体数值常只写在配图里**",
        "fetchedBy": "tool/fetch_ux_images.sh",
        "extra": {"images": f"{REF}/design/img", "imageGlob": "*.png"},
    },
    {
        "key": "source",
        "title": "组件实现源码",
        "path": f"{REF}/source",
        "glob": "*.ets",
        "upstream": [
            "https://raw.gitcode.com/openharmony/arkui_ace_engine/raw/master/advanced_ui_component/<组件>/source"
        ],
        "answers": "源码里硬编码的几何常量（注意：上游已大量改成只写令牌名）",
        "fetchedBy": "tool/fetch_source.sh",
    },
    {
        "key": "resources",
        "title": "系统资源令牌表",
        "path": f"{REF}/resources",
        "glob": "*.json",
        "upstream": [
            "https://raw.gitcode.com/openharmony/global_system_resources/raw/master/systemres/main/resources/base/element"
        ],
        "answers": "`$r('sys.float.*')` 这类令牌的真实数值",
        "fetchedBy": "tool/fetch_sys_resources.sh",
    },
]

# 派生产物：不是上游原文，但同样要入库、同样会过期。
DERIVED = [
    ("doc/ux-images.index.json", "图 → 设计文档原文上下文（由 fetch_ux_images.sh 生成）"),
    ("doc/ux-images.scan.json", "每张图的元数据与标注判定（由 scan_ux_images.py 生成）"),
    ("doc/UX-SPEC-FROM-IMAGES.md", "从配图抽出的数值汇总（由 make_spec_summary.py 生成）"),
]


def count_examples(paths: list[str]) -> int:
    """数官方示例小节，口径与 README 一致。

    优先数 `### 示例N`；一份文档只有 `## 示例` 而没有三级小节时整份记 1。
    这个数字是「我们照官方做了多少个形态」的分母，所以口径必须写死在一处。
    """
    total = 0
    for p in paths:
        try:
            t = open(p, encoding="utf-8").read()
        except OSError:
            continue
        n = len(re.findall(r"^### 示例\d", t, re.M))
        if n == 0:
            n = len(re.findall(r"^## 示例", t, re.M))
        total += n
    return total


def layer_stats(layer: dict) -> dict:
    files = sorted(glob.glob(os.path.join(layer["path"], layer["glob"])))
    info = {
        "title": layer["title"],
        "path": layer["path"],
        "files": len(files),
        "bytes": sum(os.path.getsize(f) for f in files),
        "upstream": layer["upstream"],
        "answers": layer["answers"],
        "fetchedBy": layer["fetchedBy"],
    }
    if layer["key"] == "api":
        info["examples"] = count_examples(files)
    extra = layer.get("extra")
    if extra:
        imgs = sorted(glob.glob(os.path.join(extra["images"], extra["imageGlob"])))
        info["images"] = len(imgs)
        info["imageBytes"] = sum(os.path.getsize(f) for f in imgs)
        info["imagePath"] = extra["images"]
    stamps = [os.path.getmtime(f) for f in files]
    if stamps:
        info["newestFile"] = datetime.fromtimestamp(max(stamps), timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
    return info


def build() -> dict:
    layers = {l["key"]: layer_stats(l) for l in LAYERS}

    fetched_at = None
    src = os.path.join(REF, "sources.json")
    if os.path.exists(src):
        try:
            fetched_at = json.load(open(src, encoding="utf-8")).get("fetchedAt")
        except (OSError, ValueError):
            fetched_at = None

    derived = {}
    for path, desc in DERIVED:
        if not os.path.exists(path):
            derived[path] = {"exists": False, "desc": desc}
            continue
        entry = {
            "exists": True,
            "desc": desc,
            "bytes": os.path.getsize(path),
        }
        if path.endswith(".json"):
            try:
                d = json.load(open(path, encoding="utf-8"))
                if "images" in d and isinstance(d["images"], list):
                    entry["entries"] = len(d["images"])
                elif isinstance(d, dict) and all(isinstance(v, dict) for v in d.values()):
                    entry["docs"] = len(d)
                    entry["images"] = sum(
                        len(v.get("images", [])) for v in d.values() if isinstance(v, dict)
                    )
            except (OSError, ValueError):
                pass
        derived[path] = entry

    return {
        "_note": "由 tool/make_manifest.py 生成，不要手改。上游原文不入库，"
        "本文件是「有没有抓全」的唯一可 diff 记录。重抓后跑 "
        "`./tool/upstream.sh manifest` 刷新。",
        "referenceFetchedAt": fetched_at,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "layers": layers,
        "derived": derived,
    }


def compare(old: dict, new: dict) -> list[str]:
    """比对两层结构里「数量/字节」的差异，返回人话列表。"""
    diffs: list[str] = []
    for key, cur in new["layers"].items():
        prev = old.get("layers", {}).get(key)
        if prev is None:
            diffs.append(f"{key}: manifest 里没有这一层（新增？）")
            continue
        for field in ("files", "bytes", "images", "imageBytes", "examples"):
            if field not in (prev or {}) and field not in cur:
                continue
            a, b = (prev or {}).get(field), cur.get(field)
            if a != b:
                diffs.append(f"{key}.{field}: manifest={a} 实际={b}")
    for key in old.get("layers", {}):
        if key not in new["layers"]:
            diffs.append(f"{key}: manifest 里有、实际不存在")
    for path, cur in new["derived"].items():
        prev = old.get("derived", {}).get(path, {})
        if bool(prev.get("exists")) != bool(cur.get("exists")):
            diffs.append(f"{path}: 存在性变化")
    return diffs


def fmt(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.1f}{unit}" if unit != "B" else f"{n}B"
        n /= 1024
    return f"{n}B"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="与现有 manifest 比对")
    ap.add_argument("--print", dest="do_print", action="store_true", help="只打印现状")
    args = ap.parse_args()

    new = build()

    if args.do_print:
        print(f"{'层':<10}{'文件':>8}{'体积':>12}  {'最新文件':<22}说明")
        for key, v in new["layers"].items():
            size = v["bytes"] + v.get("imageBytes", 0)
            n = v["files"] + v.get("images", 0)
            extra = f"（含 {v['images']} 张图）" if v.get("images") else ""
            print(
                f"{key:<10}{n:>8}{fmt(size):>12}  "
                f"{v.get('newestFile', '—'):<22}{v['title']}{extra}"
            )
        for path, v in new["derived"].items():
            state = f"{v.get('entries', v.get('docs', '—'))} 条" if v["exists"] else "缺失"
            print(f"  派生 {path}: {state}")
        return 0

    if args.check:
        if not os.path.exists(MANIFEST):
            print(f"没有 {MANIFEST}，先跑 ./tool/upstream.sh manifest")
            return 1
        old = json.load(open(MANIFEST, encoding="utf-8"))
        diffs = compare(old, new)
        if diffs:
            print("与 manifest 不一致：")
            for d in diffs:
                print("  -", d)
            print("\n确认差异合理后跑 ./tool/upstream.sh manifest 刷新")
            return 1
        print(f"一致：4 层共 {sum(v['files'] for v in new['layers'].values())} 份文档")
        return 0

    json.dump(new, open(MANIFEST, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(f"已写入 {MANIFEST}")
    for key, v in new["layers"].items():
        n = v["files"] + v.get("images", 0)
        print(f"  {key:<10}{n:>5} 个文件  {fmt(v['bytes'] + v.get('imageBytes', 0)):>9}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
