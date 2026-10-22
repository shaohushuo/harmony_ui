<p align="center"><b>harmony_ui</b></p>

## 简介

`harmony_ui` 是一个 Material/Cupertino 风格的 Flutter 组件库，完整实现了 **HarmonyOS 设计语言**（华为鸿蒙「设计入门」规范），覆盖官方「控件概览」文档中的 **6 大类 42 个控件**，并实现沉浸光感材质、响应式布局、转场动效，以及对照华为「UI Design Kit 能力」文档的点光源、按压阴影、侧边栏、常驻通知、动态模糊标题栏等增强能力。

组件命名与 API 对齐 Flutter 内置的 `Material*` / `Cupertino*` 组件，会写 Flutter 即可直接使用。纯 Dart / Flutter 实现，零平台通道调用，唯一第三方依赖为二维码生成 `qr` 包。

- 仓库（AtomGit）：[oh-flutter/harmony_ui](https://atomgit.com/oh-flutter/harmony_ui)
- 仓库（GitHub）：[shaohushuo/harmony_ui](https://github.com/shaohushuo/harmony_ui)
- 配套图标包：[ohos_icons](https://pub.dev/packages/ohos_icons)（HarmonyOS Symbol 字体图标，已发布 pub.dev）
- 更新日志：[CHANGELOG.OpenHarmony.md](./CHANGELOG.OpenHarmony.md)

## 下载安装

`pubspec.yaml` 中添加 git 依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  harmony_ui:
    git:
      url: https://atomgit.com/oh-flutter/harmony_ui.git
      ref: main
  ohos_icons: ^0.1.0   # 可选，配套 HarmonyOS Symbol 字体图标
```

拉取依赖：

```bash
flutter pub get
```

> 注意：本库要求使用鸿蒙社区 Flutter 分叉（[CPF-Flutter/flutter_flutter](https://atomgit.com/CPF-Flutter/flutter_flutter)），推荐分支 `oh-3.35.7-release`，建议用 [fvm](https://fvm.app) 管理：`fvm use ohos/oh-3.35.7-release`。纯 Dart 实现，在未含 ohos 平台的标准 Flutter 上亦可运行（仅用于跨平台调试，字体自动回退系统字体）。

当前版本与分支对照：

| 库版本 | 分支 / TAG | Flutter 版本 |
| --- | --- | --- |
| 0.3.0 | `main` / `v0.3.0` | oh-3.35.7-release |
| 0.2.0 | 历史提交 | oh-3.35.7-release |
| 0.1.0 | 历史提交 | oh-3.35.7-release |

## 约束与限制

### 兼容性

Flutter: oh-3.35.7-release（CPF-Flutter 社区分叉）, DevEco Studio: 5.0.0 release（需 node/ohpm/hvigor 工具链）, SDK: 26.0.0 (API 26), ROM: 5.1.0（OpenHarmony 模拟器 1280×2832 实测）。

### 权限要求

无。本库为纯 UI 组件库，不涉及任何系统权限。

## 使用示例

```dart
// 1. 导入模块
import 'package:flutter/material.dart';
import 'package:harmony_ui/harmony_ui.dart';

// 2. 初始化：OhosTheme 包裹应用根节点
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: OhosTheme(
        data: OhosThemeData.light(), // 或 OhosThemeData.dark()
        child: const HomePage(),
      ),
    );
  }
}

// 3. 功能实现：页面骨架 + 核心组件
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return OhosScaffold(
      appBar: OhosAppBar(
        title: const Text('我的应用'),
        lightMaterial: true, // 沉浸光感标题栏
      ),
      body: Center(
        child: OhosButton(
          onPressed: () {},
          child: const Text('开始使用'),
        ),
      ),
      bottomNavigationBar: OhosNavigationBar(
        currentIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const [
          OhosNavigationDestination(icon: Icon(Icons.home_filled), label: '首页'),
          OhosNavigationDestination(icon: Icon(Icons.person_filled), label: '我的'),
        ],
      ),
    );
  }
}
```

```bash
# 4. 结果输出：构建 HAP 并安装到 OpenHarmony 模拟器
cd example
fvm flutter create --platforms ohos .
fvm flutter build hap --debug --no-codesign
hdc install -r build/ohos/hap/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.example.ohos_ui_example
```

## 使用说明

1. **主题先行**：`MaterialApp` 内用 `OhosTheme` 包裹，`OhosThemeData.light()` / `dark()` 开箱即用，所有组件颜色走主题 Token，`copyWith` 可定制品牌色；
2. **逐控件替换**：`ElevatedButton` → `OhosButton`、`ListTile` → `OhosListTile` 等，API 命名一一对应，多数场景可全局替换；
3. **按需升级光感**：标题栏/底部页签/半模态打开 `lightMaterial: true` 即可获得沉浸光感效果；
4. **完整演示**：`example/` 下 gallery 应用覆盖全部控件（6 大分类 + 布局动效，7 个入口），可作为 API 速查。

## 接口说明

### 组件

控件清单（对应官方「控件概览」42 控件）：

| 分类 | 控件 | 实现 |
| --- | --- | --- |
| 导航 | 标题栏 | `OhosAppBar`（光感/动态模糊） |
| 导航 | 子页签 | `OhosTabBar`（下划线/胶囊、分割线跟手） |
| 导航 | 底部页签 | `OhosNavigationBar`（平铺/悬浮、光池、角标） |
| 导航 | 导航点 / 轮播 | `OhosPageIndicator` / `OhosSwiper` |
| 展示 | 文本 / 子标题 | `OhosText`（13 级字阶）/ `OhosSubheader` |
| 展示 | 图片 | `OhosImage`（选中描边/占位图） |
| 展示 | 分隔器 / 进度条 | `OhosDivider` / `OhosProgressIndicator` |
| 展示 | 新事件标记 / 索引条 | `OhosBadge` / `OhosAlphabetIndexer` |
| 展示 | 滚动条 / 即时反馈 | `OhosScrollbar` / `showOhosToast` |
| 展示 | 气泡提示 / 数据面板 | `showOhosPopup` / `OhosDataPanel` |
| 展示 | 二维码 / 空白 / 文本时钟 | `OhosQrCode` / `OhosBlank` / `OhosTextClock` |
| 操作 | 按钮 | `OhosButton`（5 样式 × 3 形状 + 加载态） |
| 操作 | 下拉按钮 / 状态按钮 | `OhosSelect` / `OhosToggleButton` |
| 操作 | 操作块 / 工具栏 | `OhosChip` / `OhosToolbar` |
| 操作 | 核心操作栏 / 菜单 | `OhosActionBar` / `showOhosMenu` |
| 输入 | 文本输入 / 搜索框 | `OhosTextField` / `OhosSearchBar` |
| 输入 | 数字加减 / 图案锁 | `OhosCounter` / `OhosPatternLock` |
| 选择 | 勾选 / 单选 / 开关 | `OhosCheckbox` / `OhosRadio` / `OhosSwitch` |
| 选择 | 评分条 / 滑动条 | `OhosRatingBar` / `OhosSlider` |
| 选择 | 选择器 / 颜色选择器 | `showOhosPicker` / `OhosColorPicker` |
| 选择 | 分段按钮 | `OhosSegmentedButton` |
| 容器 | 列表 / 列表项 | `OhosList` / `OhosListTile` |
| 容器 | 卡片 | `OhosCard` |
| 容器 | 弹出框 | `OhosAlertDialog` / `showOhosDialog` |
| 容器 | 气泡提示 / 半模态面板 | `showOhosPopup` / `showOhosBottomSheet` |

### 属性（主题）

```dart
final OhosThemeData theme = OhosTheme.of(context);
theme.highlightColor;        // 品牌色 #0A59F7
theme.backgroundColor;       // 页面背景
theme.cardColor;             // 卡片背景
theme.multiColors;           // 11 色多彩色板
theme.typography.bodyLarge;  // 文字样式
```

### API（UI Design Kit 增强）

| 能力 | 组件 / API |
| --- | --- |
| 点光源 | `OhosLightSource` + `OhosIlluminated` |
| 按压阴影 | `OhosPressShadow` |
| 侧边栏/侧边菜单 | `OhosSideBar` + `OhosSideMenu` |
| 横滑列表项 | `OhosListItem` |
| 常驻通知 | `showOhosSnackBar(resident: true)` |
| 子页签分割线 | `OhosTabBar(divider:)` |
| 动态模糊标题栏 | `OhosAppBar(scrollEffect:)` |
| 可展开操作栏 | `OhosActionBar(expandable: true)` |
| 分层图标 / 多窗入口 | `OhosLayeredIcon` / `OhosMultiWindowEntry` |
| 沉浸光感材质 | `OhosLightMaterial`（五档 + `OhosLightEffectTuning` 调参） |
| 响应式布局 | `OhosResponsiveBuilder` / `OhosGrid` / `OhosGridItem` |
| 转场动效 | `OhosGeometry`（spring/easeOut/sharedElement） |

## 新增特性

v0.3.0 新增墨水屏主题、标题栏布局与参数增强、输入 / 容器组件补齐，并完成窄屏 / 大字号适配与 focusNode 生命周期修复，详见 [CHANGELOG.OpenHarmony.md](./CHANGELOG.OpenHarmony.md)。

## 常见问题

- **构建时报 `npm not found`？** 需要把 DevEco Studio 内置工具（node/ohpm/hvigor）加入 PATH，仓库自带 `env.sh` 可直接 `source`。
- **`flutter build hap` 签名报错？** 使用 `--no-codesign` 构建后再 `hdc install`，模拟器免签名运行。
- **能在标准 Flutter（非鸿蒙分叉）上跑吗？** 能，纯 Dart 实现无平台通道调用；只是字体与系统光感效果有差异，正式运行建议用鸿蒙分叉 + OpenHarmony 平台。

## 目录结构

```
harmony_ui/
├── lib/
│   ├── harmony_ui.dart          # 统一导出
│   └── src/
│       ├── theme/               # 设计令牌：OhosColors / OhosThemeData / OhosGeometry
│       └── widgets/             # 50+ 组件：按钮/列表/导航/选择/弹层/光感/Kit
├── example/                     # gallery 画廊应用（7 个入口）
│   └── ohos/                    # flutter create --platforms ohos 生成的平台工程
├── test/                        # 组件测试
├── doc/screenshots/             # 模拟器实机截图
├── env.sh                       # DevEco 工具链环境变量
├── README.OpenHarmony.md        # 英文文档
├── README.OpenHarmony_CN.md     # 中文文档（本文件）
└── CHANGELOG.OpenHarmony.md     # 更新日志
```

## 贡献代码

欢迎提交 Issue 与 Pull Request：

- AtomGit 仓库 Issue：[oh-flutter/harmony_ui/issues](https://atomgit.com/oh-flutter/harmony_ui/issues)
- AtomGit 仓库 Pull Request：[oh-flutter/harmony_ui/pulls](https://atomgit.com/oh-flutter/harmony_ui/pulls)
- GitHub 仓库：[shaohushuo/harmony_ui](https://github.com/shaohushuo/harmony_ui)

参与 OpenHarmony 生态建设，可加入开源鸿蒙跨平台社区：<https://openharmonycrossplatform.csdn.net>

## 开源协议

[MIT](./LICENSE)
