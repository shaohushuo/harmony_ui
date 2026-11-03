# 官方参考文档（本地快照）

`*.md` 与 `sources.json` 由 `tool/fetch_reference.sh` 生成，**已加入 `.gitignore`，不入库**（上游内容、约 2.9MB、会与上游漂移）。本 README 与 `sources.json` 保留在版本控制里，负责说明来源与缺口。

## 为什么需要这份快照

0.5 只读了设计规范页，0.6 补上参考文档与其中示例 —— 这是两层完全不同的信息：设计规范回答「有哪些控件、怎么用」，参考文档回答「一个控件有几个形态、每个形态的默认值是多少」。上一轮的三处错误判断（滑块双值、进度条 3 种、列表分组自拟视觉）就是因为缺第二层。

## 两条抓取链路

两条都必须走，**不能混**：

### 1. 开源 ArkUI 组件 → OpenHarmony 文档仓库

```
https://gitee.com/openharmony/docs/raw/master/zh-cn/application-dev/reference/apis-arkui/arkui-ts/<组件名>.md
```

中文站参考页（`developer.huawei.com/consumer/cn/doc/harmonyos-references/*`）是 SPA，静态抓取只会拿到 404 页；页面里 `<link rel="alternate" type="text/markdown">` 指向的 `.md` 地址同样返回 404。所以改抓 OpenHarmony 仓库 —— 内容与官网同源，且自带完整的 ArkTS 示例代码（官网 SPA 渲染出来的就是这些）。

注意高阶组件文件名是**大写开头**：`ohos-arkui-advanced-Chip.md`，小写会 404。

### 2. 闭源 HDS 组件 → 官网 doccenter-references 前缀

```
https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/ui-design-<小写slug>.md
```

`HdsActionBar` 这类组件不在 OpenHarmony 仓库里，但官网有一份 markdown 原文可以直接 200 取回。

**这条路径是 0.6 才发现的。** 在此之前本项目在 `ROADMAP` / `CONTROL-MATRIX` / 本文件里都写着「HDS 闭源 = 上游无文档」，据此把核心操作栏、即时操作等归为「无参考文档可依、规格只能猜」。实际上文档一直存在，只是没找对路径 —— 这属于**没查就说没有**，比查了没查到更需要警惕，因为它会让后续所有判断自动降级为猜测。

slug 必须全小写，`ui-design-hdsActionBar.md` 会 404。同一前缀下 `ui-design-hdssearch` / `ui-design-hdsbutton` / `ui-design-hdsswitch` 确实 404（那些组件确实没有文档），所以抓取失败仍要当失败报出来，不能静默跳过。

## 规模

| 来源 | 文档数 | 示例小节 |
| --- | --- | --- |
| OpenHarmony 仓库（`ts-*` / `ohos-arkui-advanced-*`） | 43 | 364 |
| HDS 闭源组件（`ui-design-hds*`） | 8 | 7 |
| 反查项（设计文档末尾链接指向的组件） | 4 | 31 |
| 合计 | 55 | 402 |

示例的统计口径：**优先数 `### 示例N`；若一份文档只有 `## 示例` 而没有三级小节，整份记 1**。这个数字是「我们照官方做了多少个形态」的分母（`TextInput` 32、`Search` 30、`Image` 30、`Text` 29、`Tabs` 23…）。

复核命令（改完抓取表请重跑，别手抄）：

```zsh
cd doc/reference && for f in *.md; do
  [ "$f" = README.md ] && continue
  n=$(grep -cE '^### 示例[0-9]' "$f"); h=$(grep -cE '^## 示例' "$f")
  [ "$n" -eq 0 ] && [ "$h" -gt 0 ] && n=$h
  echo "$n $f"
done | awk '{s+=$1} END {print s}'
```

> 上一轮这里写的是「51 份 / 369 示例」，两个数字都低估了：差集比对后补了 4 份反查文档（`ChipGroup` / `custom-dialog-box` / `sheet-transition` / `promptaction`），示例随之从 369 涨到 402。**其中 31 个示例来自新增的 4 份** —— 也就是说「分母」里最缺的一块，正是子页签与半模态这两个形态最多的组件。

HDS 8 份：`HdsActionBar` / `HdsSnackBar` / `HdsTabs` / `HdsNavigation` / `HdsListItem` / `HdsListItemCard` / `HdsColorPicker` / `hdsMaterial`。其中 `hdsMaterial` 是纯枚举、无示例小节。

反查 4 份：`ohos-arkui-advanced-ChipGroup`（子页签）/ `ts-methods-custom-dialog-box`（弹出框）/ `ts-universal-attributes-sheet-transition`（半模态面板）/ `arkts-apis-uicontext-promptaction`（即时反馈）。这 4 份**在 OpenHarmony 仓库里按原名取不到**，是从设计文档末尾「## 开发文档」反查出来的。

## 已知缺口

`EditableTitleBar`（标题栏的可编辑形态）—— 试过 `ui-design-editable-title-bar` / `ui-design-editabletitlebar` / `hdseditabletitlebar` 等 slug 全 404，`HdsNavigation` 文档里也没有对应章节。这一项**确实**只有设计规范，规格确定性低于其他组件，规划里单独标注。

## 用法

```zsh
./tool/fetch_reference.sh    # 重抓全部；失败会打印 FAIL 行并以非零码退出
```

脚本会先删旧快照再抓，`README.md` 不在清理范围内。

## 文件名

与上游一致（HDS 加 `hds-` 前缀以避免和 ArkUI 组件撞名），重抓时能直接覆盖。