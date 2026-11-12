# AGENTS.md — harmony_ui 的 AI 编码约定

适用对象：在这个仓库里写代码、改组件、答 API 问题的 AI 编码助手（以及新来的开发者）。
版本口径以 `pubspec.yaml` 为准；本文不复制 API 清单，清单由生成器维护。

## 这个库是什么

HarmonyOS 设计语言的 Flutter 组件库，对齐官方「控件概览」42 个控件。它**不是** Material 组件的换皮，也**不是** ArkUI API 的直译：这是一层有自己取舍的翻译层，很多参数被有意删掉或改名，理由写在源码 `///` 注释里。

定位上它**面向 HarmonyOS 7 与 Flutter 3.50**：前者带来了「沉浸光感」等新设计理念（本库已有 `OhosLightMaterial` / `OhosPointLight` / `OhosPressShadow` 的 Flutter 侧近似），后者把 UI 拆成独立的 `material_ui` / `cupertino_ui`，从此设计语言可以脱离框架发版节奏演进 —— 这是这类第三方 UI 库在架构上的立足点。**但现状与目标有差距，回答 API 问题时别把方向当事实**：`lib/` 下 84 个 Dart 文件里仍有 78 个 `import 'package:flutter/material.dart'`（`material_ui` 迁移未做），官方的「非线性形变」与整个「空间计算」能力本库都没有。

- 唯一公开入口：`import 'package:harmony_ui/harmony_ui.dart';`
- `lib/src/**` 是内部实现。**不要**从外部 import `package:harmony_ui/src/...`；`lib/harmony_ui.dart` 的 export 列表是「公开」的唯一定义（`lib/src/widgets/ohos_arc.dart` 就故意没有导出）。
- 图标来自 `harmony_icons` 包，类名仍是 `OhosIcons`；旧的 `ohos_icons` 已弃用。

## 先查，再写

**不要凭名字猜 `Ohos*` 符号或参数。** 这个库最容易产生的错误不是语法错，而是「按 ArkUI / Material 类比编出一个看起来合理的参数」——`selected`、`isExpand`、`borderRadius`、`timeZone`、`fit: BoxFit` 正是 0.6.0 移除或改名的那批。

```bash
python3 tool/ai_lookup.py OhosButton        # 一个控件的完整契约 + 源码行号
python3 tool/ai_lookup.py --search 下拉      # 不知道叫什么时按关键词找
python3 tool/ai_lookup.py --breaking        # 12 处破坏性变更（标注哪几条静默）
python3 tool/ai_lookup.py OhosButton --json # 给程序消费的原始记录
```

- `doc/ai/API-INDEX.md`（约 42 KB）：一行一个公开符号，含构造参数默认值与源码行号，适合整体加载。
- `doc/ai/catalog.json`：完整索引（239 个公开符号、188 个构造器、官方形态矩阵、破坏性变更、demo/测试引用）。**按需查询，别整体塞进上下文。**
- `doc/ai/contract.json`：`flutter analyze` 查不出来的语义约束。
- `doc/ai/AI-FRIENDLY-ROADMAP.md`：这套 AI 层的分层方案与后续待办。

生成物 `doc/ai/catalog.json`、`doc/ai/API-INDEX.md`、`llms.txt` **不要手改**；改了源码后跑 `python3 tool/gen_ai_catalog.py`，CI 可用 `--check` 拦住漂移。细节（为什么某个默认值是这个、官方出处、明确不做的部分）只存在于源码 `///` 注释里，catalog 不复制它们——按 `file:line` 回去读，或让 `ai_lookup.py` 打印。

## 铁律：这些写出来能编译，但是错的

1. **组件层禁止读 `theme.monochrome` 做分支。** 铺底用 `policy.tint`，画线用 `policy.line`，投影/模糊/波纹/动效查 `allows*`，禁用态用 `disabledFill`，描边用 `usesOutlines`。`OhosThemeData` 答「什么颜色」，`OhosVisualPolicy` 答「怎么表现才读得懂」，两者正交。新增的主题值对象必须实现 `==`/`hashCode`，否则 `updateShouldNotify` 静默失效；消费侧不要穷举枚举。
2. **墨水屏 16 级灰**：≤20% 的黑与白底不可分。改用留白 + 1px 实线；半透明线要合成成实色。阴影、`BackdropFilter`、水波纹、长动画在真机上等于不存在。描边走 `ohosStrokeWidth` / `ohosBorderSide`（整数像素、`strokeAlignInside`）。
3. **`showOhosDialog` 的内容必须显式包 `DefaultTextStyle`。** `showDialog` 挂在 Navigator Overlay，没有 `Material` 祖先，会吃到 `DefaultTextStyle.fallback` 的 `#FFFF00` 双下划线警报色。`showOhosMenu` / `showOhosBottomSheet` / Toast / Popup 自带 `Material`，不需要。单测也测不出来（测试默认样式同样是黄的），只有真机截图能抓到。
4. **「最大宽度」是上限，不是必然宽度**：还要与「可用宽度 − 边距」取小。`RenderFlex` 挤出屏幕不会报错。这一条已经在 328vp 列表卡片和 400vp 弹窗上各翻车一次。
5. **固定宽度容器里的文案**用 `Expanded` + `maxLines: 1` + `TextOverflow.ellipsis`。菜单固定 224vp，裸 `Text` 只溢出几像素，肉眼几乎看不出。
6. **官方规格按设备形态分节**（手机 / 电脑 / 智能穿戴 / 大屏）。本库范围只有手机、平板、大屏；标注配图里大部分数值来自穿戴章节，**别把穿戴值用到手机布局**。
7. **查数值的优先级**：`pattern.json` → `float_sys.json` → `float.json` → `source/*.ets` → 标注配图。设计稿建议值不等于组件令牌。资源表里没有的项（如半模态 8vp 顶距、按钮 448vp 上限、菜单 12vp 左右留白）写成带出处的常量就是对的，**不要编造 `sys.float.*` 名字**。查令牌用 `tool/token_lookup.py`。
8. **不要手改 `doc/reference/`**（官方镜像）。刷新只用 `./tool/upstream.sh`，直接跑 `fetch_*.sh` 不写 manifest。

## 版本与破坏性变更

当前是 **0.6.x**。从 0.5.x 升级共有 **12 处**破坏性变更，按 `catalog.json.breakingSummary` 从迁移表**现算**：

- 9 处会编译报错；
- **3 处完全不报错**：#7 `OhosChipGroup` 默认选中第 0 颗、#10 `OhosCheckbox` 默认形状改圆形、#12 `OhosSelect` 默认不再画勾；
- 另有 6 处（#1/#3/#4/#5/#8/#11）即使修好编译错误，观感仍会变。

> ⚠️ `README.md` 的「升级」段仍写「7 处」「三处不报错」，是主体轮次的旧口径；**以 `doc/MIGRATION-0.6.md` 和 `catalog.json.breakingChanges` 为准**。旧笔记里的「2 处静默」只统计了审计轮（第 8–12 条），不是全 12 条的口径——这类数字一律用 `python3 tool/ai_lookup.py --breaking` 现算。同理，`doc/CONTROL-MATRIX.md` 同一文件里既写「本版 444 条用例」又写「仓库有 365 条用例」，统计数字**不要引用文档里的写死值**。

`flutter analyze` 通过不等于升级正确：先跑 `python3 tool/ai_lookup.py --breaking`，再对照 `doc/MIGRATION-0.6.md`。顶层 `showOhos*` 函数只新增了可选参数，没有删参数。

## 不要加载、不要轻信

`README.md`(63 KB) / `CHANGELOG.md`(166 KB) / `doc/CONTROL-MATRIX.md`(102 KB) / `doc/ROADMAP-0.6.md`(127 KB) 合计约 460 KB，加 655 张配图。它们是给人读的历史与规格资料，**不要整体加载**；检索到片段时先确认它的适用范围（设备形态）和时效（版本）。仓库里 7 个 JSON 此前全是上游配图索引与 OHOS 资源表，描述本库 API 的只有 `doc/ai/catalog.json`。

## 验证

```bash
# 改了 lib/ 之后
python3 tool/gen_ai_catalog.py             # 重新生成 AI 目录
python3 tool/gen_ai_catalog.py --check     # 漂移自检（应输出 OK）
flutter analyze
dart format --output=none --set-exit-if-changed lib test
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY flutter test
```

测试基线：库 745 条、example 183 条（example 要 `cd example` 再跑）。Flutter 版本按 `.fvmrc` 用 `ohos/oh-3.35.7-release`；CI 跑上游 stable 3.47.x，**本地 analyze 干净不代表 CI 绿**——碰 SDK API 时先想「3.35.7 有没有、3.47 弃没弃」。构建 hap 要 `env -u NODE_OPTIONS`。跑测试必须清代理，否则 `WebSocketException`。
