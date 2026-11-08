#!/usr/bin/env python3
"""资源令牌查询：把 pattern / float_sys / float 三层拉平并解析引用链。

用法：
  python3 tool/token_lookup.py <pattern分组名>          # 打印该分组全部字段（已解析引用）
  python3 tool/token_lookup.py --grep <正则>            # 按键名搜所有层
  python3 tool/token_lookup.py --value <数值>           # 按数值反查（含近似）
  python3 tool/token_lookup.py --raw <键名>             # 单键：原始值 + 解析值 + 来源层
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "doc/reference/resources"


def load():
    pat = json.load(open(RES / "pattern.json"))["pattern"]
    fsys = json.load(open(RES / "float_sys.json"))["float"]
    flt = json.load(open(RES / "float.json"))["float"]
    return pat, {e["name"]: e["value"] for e in fsys}, {e["name"]: e["value"] for e in flt}


PAT, FSYS, FLT = load()


def numeric(value):
    """把 "48.0vp" / "16fp" / "2.0f" 这类带单位的值转成 float；转不了返回 None。"""
    if isinstance(value, (int, float)):
        return float(value)
    if not isinstance(value, str):
        return None
    m = re.match(r"^(-?\d+(?:\.\d+)?)\s*(vp|fp|px|f|lpx)?$", value.strip())
    return float(m.group(1)) if m else None


def resolve(value, depth=0):
    """解析 $float:xxx 引用链。两表键不重，回查成环只跳一次。"""
    if not isinstance(value, str) or depth > 4:
        return value, ""
    m = re.match(r"^\$float:(.+)$", value)
    if not m:
        return value, ""
    key = m.group(1)
    for layer, table in (("float_sys", FSYS), ("float", FLT)):
        if key in table:
            v, _ = resolve(table[key], depth + 1)
            return v, layer
    return value, "MISSING"


def dump_group(name):
    for e in PAT:
        if e["name"] != name:
            continue
        print(f"## {name}  ({len(e['value'])} 项)")
        for f in e["value"]:
            raw = f["value"]
            v, layer = resolve(raw)
            ref = f"  <- {raw}" if raw != v else ""
            print(f"  {f['name']:<46} = {v!s:<28}{ref}")
        return
    print(f"没有分组 {name}")


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    if a[0] == "--grep":
        rx = re.compile(a[1], re.I)
        for layer, table in (("pattern", {f["name"]: f["value"] for e in PAT for f in e["value"]}),
                             ("float_sys", FSYS), ("float", FLT)):
            hits = [(k, v) for k, v in table.items() if rx.search(k)]
            for k, v in hits:
                rv, _ = resolve(v)
                print(f"{layer:<10} {k:<48} = {rv}")
        return
    if a[0] == "--value":
        target = float(a[1])
        tol = float(a[2]) if len(a) > 2 else 0.01
        print(f"== 数值 {target} ± {tol} ==")
        for layer, table in (("float_sys", FSYS), ("float", FLT)):
            for k, v in table.items():
                rv, _ = resolve(v)
                n = numeric(rv)
                if n is not None and abs(n - target) <= tol:
                    print(f"{layer:<10} {k:<48} = {rv}")
        # pattern 层按解析后的值反查
        for e in PAT:
            for f in e["value"]:
                rv, _ = resolve(f["value"])
                n = numeric(rv)
                if n is not None and abs(n - target) <= tol:
                    print(f"{'pattern':<10} {e['name']}.{f['name']:<34} = {rv}")
        return
    if a[0] == "--raw":
        key = a[1]
        for layer, table in (("float_sys", FSYS), ("float", FLT)):
            if key in table:
                rv, src = resolve(table[key])
                print(f"{layer:<10} {key} = {table[key]}  →  {rv}  (from {src or layer})")
                return
        for e in PAT:
            for f in e["value"]:
                if f["name"] == key:
                    rv, src = resolve(f["value"])
                    print(f"pattern    {e['name']}.{key} = {f['value']}  →  {rv}  (from {src or 'inline'})")
        return
    dump_group(a[0])


if __name__ == "__main__":
    main()
