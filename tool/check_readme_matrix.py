#!/usr/bin/env python3
"""校验 README 的「控件覆盖」表与 doc/CONTROL-MATRIX.md 不漂移。

为什么需要这个脚本：README 的覆盖表原本只写类名，看不出「一个类覆盖官方几个
形态、做了几个」。改成逐项勾选后，**两份文件就成了同一事实的两个副本** ——
矩阵改了（某个形态从 ○ 转完整），README 如果没跟着改，读者看到的是一份过期
的覆盖率，而这种错不会让任何测试变红。

校验两件事：
1. 每个控件在 README 里打 `✓` 的项数，不得超过矩阵里该控件的完整行数
   （允许多个矩阵控件合并成一行，靠 MAP 显式声明，不靠子串猜 —— 猜的话
   「文本」会命中「文本框」，见本脚本的初版教训）；
2. README 顶部引用的矩阵统计（行数 / 完整数）与实际一致。

用法：
    python3 tool/check_readme_matrix.py          # 只校验
    python3 tool/check_readme_matrix.py --fix    # 同步 README 顶部的统计数字
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / "README.md"
MATRIX = ROOT / "doc" / "CONTROL-MATRIX.md"

# README 行名 → 矩阵里的控件名（可多个）。**显式声明**，不靠子串匹配：
# 「文本」子串会命中「文本框」，那会让校验把两个不相干的控件混成一个。
MAP: dict[str, list[str]] = {
    "标题栏": ["标题栏"],
    "子页签": ["子页签"],
    "底部页签": ["底部页签"],
    "导航点": ["导航点"],
    "轮播": [],
    "文本 / 子标题": ["文本", "子标题"],
    "图片": ["图片"],
    "分隔器": ["分隔器"],
    "进度条": ["进度条", "加载动效"],
    "新事件标记": ["新事件标记"],
    "索引条": ["索引条"],
    "放大镜": [],
    "滚动条": ["滚动条"],
    "即时反馈 / 即时操作": ["即时反馈", "即时操作"],
    "气泡提示": ["气泡提示"],
    "数据可视化": ["数据可视化"],
    "二维码": ["二维码"],
    "空白": ["空白"],
    "文本时钟": ["文本时钟"],
    "按钮": ["按钮"],
    "下拉按钮": ["下拉按钮"],
    "状态按钮": ["状态按钮"],
    "操作块": ["操作块"],
    "工具栏": ["工具栏"],
    "核心操作栏": ["核心操作栏"],
    "菜单": ["菜单"],
    "文本输入": ["文本框"],
    "密码输入": ["文本框"],
    "字数计数器": ["文本框"],
    "搜索框": ["搜索框"],
    "数字加减": ["数字加减"],
    "图案锁": ["图案锁"],
    "勾选框 / 单选按钮 / 开关": ["勾选", "单选框", "开关"],
    "评分条": ["评分条"],
    "滑动条": ["滑动条"],
    "选择器": ["选择器"],
    "颜色选择器": ["色彩选择器"],
    "分段按钮": ["分段按钮"],
    "列表 / 列表项": ["列表"],
    "列表分组": ["列表"],
    "列表卡片": ["列表卡片"],
    "卡片": [],
    "弹出框": ["弹出框"],
    "半模态面板": ["半模态面板"],
}


def parse_matrix() -> tuple[dict[str, tuple[int, int]], int, int]:
    """返回 {控件: (完整数, 总数)} 与 (总行数, 总完整数)。"""
    lines = MATRIX.read_text(encoding="utf-8").splitlines()
    rows: list[str] = []
    for line in lines:
        if line.startswith("## 统计"):
            break
        if line.startswith("| ") and not line.startswith("| 控件 ") and "---" not in line:
            rows.append(line)

    per: dict[str, list[int]] = {}
    total_full = 0
    for r in rows:
        parts = [p.strip() for p in r.split("|")]
        if len(parts) < 5:
            continue
        ctrl, impl = parts[1], parts[4]
        done = not impl.startswith(("○", "◐", "●", "—"))
        if done:
            total_full += 1
        slot = per.setdefault(ctrl, [0, 0])
        slot[1] += 1
        if done:
            slot[0] += 1

    return {k: (v[0], v[1]) for k, v in per.items()}, len(rows), total_full


def readme_blocks() -> list[tuple[str, str, str]]:
    """切出覆盖表里的 (行名, 形态列, 实现列)。"""
    text = README.read_text(encoding="utf-8")
    start = text.find("## 控件覆盖")
    end = text.find("## 设计语言实现")
    if start < 0 or end < 0:
        raise SystemExit("找不到 README 的覆盖表或其后的小节标题")
    out: list[tuple[str, str, str]] = []
    for line in text[start:end].splitlines():
        if not line.startswith("| ") or "官方形态" in line or "---" in line:
            continue
        parts = [p.strip() for p in line.split("|")]
        if len(parts) < 5:
            continue
        out.append((parts[1], parts[2], parts[3]))
    return out


def main() -> int:
    per, rows, full = parse_matrix()
    problems: list[str] = []

    for name, forms, _impl in readme_blocks():
        keys = MAP.get(name)
        if keys is None:
            problems.append(f"未在 MAP 里登记的行名「{name}」—— 新增控件请同时补 MAP，"
                            f"否则这一行不会被校验")
            continue
        if not keys:
            continue
        ticks = forms.count("✓")
        cap = sum(per.get(k, (0, 0))[0] for k in keys)
        if ticks > cap:
            detail = "、".join(f"{k} {per.get(k, (0, 0))[0]}/{per.get(k, (0, 0))[1]}"
                              for k in keys)
            problems.append(f"「{name}」打了 {ticks} 个 ✓，但矩阵里对应的完整行只有 {cap} 个"
                            f"（{detail}）")

    text = README.read_text(encoding="utf-8")
    m = re.search(r"当前 \*\*(\d+) 行 / 完整 (\d+)\*\*", text)
    if not m:
        problems.append("README 顶部找不到「当前 N 行 / 完整 M」这句统计引用")
    else:
        claimed_rows, claimed_full = int(m.group(1)), int(m.group(2))
        if claimed_rows != rows or claimed_full != full:
            problems.append(
                f"README 顶部引用 {claimed_rows} 行 / 完整 {claimed_full}，"
                f"实际是 {rows} 行 / 完整 {full}"
            )

    if problems:
        for p in problems:
            print(f"❌ {p}")
        return 1
    print(f"✅ README 覆盖表与矩阵一致（{rows} 行 / 完整 {full}）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
