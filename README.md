# ohos_ui

<p align="center">
  <img src="https://cdn.jsdelivr.net/gh/shaohushuo/ohos_ui@main/doc/screenshots/gallery_home.png" alt="ohos_ui gallery home" width="260"/>
  <img src="https://cdn.jsdelivr.net/gh/shaohushuo/ohos_ui@main/doc/screenshots/gallery_form.png" alt="ohos_ui gallery form" width="260"/>
  <img src="https://cdn.jsdelivr.net/gh/shaohushuo/ohos_ui@main/doc/screenshots/gallery_about.png" alt="ohos_ui gallery about" width="260"/>
</p>

[![pub package](https://img.shields.io/pub/v/ohos_ui.svg)](https://pub.dev/packages/ohos_ui)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/shaohushuo/ohos_ui/actions/workflows/ci.yml/badge.svg)](https://github.com/shaohushuo/ohos_ui/actions/workflows/ci.yml)

Material / Cupertino 风格的 Flutter 组件库，实现了 **HarmonyOS 设计语言**（华为鸿蒙「设计入门」规范）。组件命名与 API 尽可能对齐 Flutter 内置的 `Material*` / `Cupertino*` 组件，方便迁移：

| Material / Cupertino | ohos_ui |
| --- | --- |
| `Theme` / `ThemeData` | `OhosTheme` / `OhosThemeData` |
| `Scaffold` / `AppBar` | `OhosScaffold` / `OhosAppBar` |
| `ElevatedButton` / `CupertinoButton` | `OhosButton` |
| `ListTile` / `CupertinoListTile` | `OhosListTile` |
| `Card` | `OhosCard` |
| `Switch` / `Checkbox` / `Radio` | `OhosSwitch` / `OhosCheckbox` / `OhosRadio` |
| `TextField` / `SearchBar` | `OhosTextField` / `OhosSearchBar` |
| `NavigationBar` | `OhosNavigationBar` |
| `TabBar` | `OhosTabBar` |
| `CircularProgressIndicator` / `LinearProgressIndicator` | `OhosProgressIndicator` |
| `AlertDialog` / `showDialog` | `OhosAlertDialog` / `showOhosDialog` |
| `Badge` | `OhosBadge` |
| `FilterChip` / `ActionChip` | `OhosChip` |
| `Divider` | `OhosDivider` |
| `IconButton` | `OhosIconButton` |

配套图标包：[ohos_icons](https://pub.dev/packages/ohos_icons)（HarmonyOS Symbol 字体图标）。

## 特性

- **HarmonyOS 设计令牌**：主题色 `#0A59F7` / `#317AF7`、11 色多彩色板、功能色（成功/警告/危险）、文字三级透明度、24vp 卡片圆角、胶囊按钮、弹性按压曲线，全部来自鸿蒙官方设计规范。
- **明暗双主题**：`OhosThemeData.light()` / `OhosThemeData.dark()` 开箱即用。
- **API 对齐 Flutter**：使用方式与 Material/Cupertino 组件一致，学习成本低。
- **原生字体**：默认使用 HarmonyOS 系统字体 `HarmonyOS Sans`（非鸿蒙平台自动回退系统字体）。
- **零额外依赖**：只依赖 Flutter SDK。

## 安装

```bash
fvm flutter pub add ohos_ui
# 或直接运行
flutter pub add ohos_ui
```

## 快速开始

```dart
import 'package:flutter/material.dart';
import 'package:ohos_ui/ohos_ui.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: OhosTheme(
        data: OhosThemeData.light(), // 或 OhosThemeData.dark()
        child: OhosScaffold(
          appBar: OhosAppBar(title: const Text('我的应用')),
          body: Center(
            child: OhosButton(
              onPressed: () {},
              child: const Text('开始使用'),
            ),
          ),
          bottomNavigationBar: OhosNavigationBar(
            currentIndex: 0,
            onDestinationSelected: (int index) {},
            destinations: const [
              OhosNavigationDestination(icon: Icon(Icons.home), label: '首页'),
              OhosNavigationDestination(icon: Icon(Icons.person), label: '我的'),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 组件速览

### 主题

```dart
final OhosThemeData theme = OhosTheme.of(context); // 任意组件内获取
theme.highlightColor;   // 品牌色
theme.backgroundColor;  // 页面背景
theme.cardColor;        // 卡片背景
theme.multiColors;      // 11 色多彩色板
theme.typography.bodyLarge; // 文字样式
```

自定义主题：

```dart
OhosTheme(
  data: OhosThemeData.dark().copyWith(
    highlightColor: const Color(0xFF0A59F7),
    dangerColor: const Color(0xFFE84026),
  ),
  child: const MyApp(),
)
```

### 按钮

```dart
OhosButton(onPressed: _save, child: const Text('保存'));              // 填充（强调）
OhosButton(
  onPressed: _save,
  style: OhosButtonStyle.tonal,   // 次级
  child: const Text('保存'),
);
OhosButton(
  onPressed: _cancel,
  style: OhosButtonStyle.outlined, // 描边
  shape: OhosButtonShape.rounded,  // 24vp 圆角方块
  child: const Text('取消'),
);
OhosButton(
  onPressed: _refresh,
  loading: true,                  // 加载态
  icon: const Icon(Icons.refresh),
  child: const Text('刷新'),
);
```

### 底部导航

```dart
OhosNavigationBar(
  currentIndex: _index,
  onDestinationSelected: (int i) => setState(() => _index = i),
  destinations: const [
    OhosNavigationDestination(icon: Icon(OhosIcons.square_grid_2x2), label: '组件'),
    OhosNavigationDestination(
      icon: Icon(OhosIcons.person),
      label: '我的',
      badge: OhosBadge(count: 5), // 可选角标
    ),
  ],
)
```

### 列表

```dart
OhosCard(
  padding: EdgeInsets.zero,
  child: Column(children: const [
    OhosListTile(
      leading: Icon(OhosIcons.wifi),
      title: Text('无线网络'),
      subtitle: Text('已连接'),
      trailing: Icon(OhosIcons.chevron_right),
      onTap: _openWifi,
    ),
    OhosListTile(
      leading: Icon(OhosIcons.moon_fill),
      title: Text('深色模式'),
      selected: true, // 选中态品牌色高亮
      trailing: OhosSwitch(value: true, onChanged: _onDarkMode),
    ),
  ]),
)
```

### 表单

```dart
OhosSearchBar(
  hintText: '搜索',
  onChanged: (String query) {},
  onSubmitted: (String query) {},
);

OhosTextField(
  labelText: '用户名',
  prefixIcon: const Icon(Icons.person),
  onChanged: (String v) {},
);

OhosTextField(
  labelText: '密码',
  obscureText: true,
  errorText: '密码至少 8 位', // 错误态
);

OhosSwitch(value: _wifi, onChanged: (bool v) {});
OhosCheckbox(value: _agree, onChanged: (bool v) {});
OhosRadio(value: _sex == 0, onChanged: (bool v) {});
```

### 对话框

```dart
final bool? ok = await showOhosDialog<bool>(
  context: context,
  title: '删除文件？',
  content: '删除后无法恢复，请确认是否继续。',
  actions: [
    OhosDialogAction(label: '取消', onPressed: () => Navigator.pop(context, false)),
    OhosDialogAction(label: '删除', danger: true, onPressed: () => Navigator.pop(context, true)),
  ],
);
```

### 进度 / 反馈

```dart
const OhosProgressIndicator.circular();          // 无限转圈
OhosProgressIndicator.circular(value: 0.6);      // 确定进度
const OhosProgressIndicator.linear();            // 线性
OhosProgressIndicator.linear(value: 0.6);

OhosBadge(count: 12, child: Icon(Icons.message)); // 数字角标
const OhosBadge(isDot: true);                     // 红点
```

### 选项卡 / 标签

```dart
DefaultTabController(
  length: 3,
  child: const OhosTabBar(tabs: [Tab(text: '推荐'), Tab(text: '关注'), Tab(text: '热榜')]),
)

OhosChip(
  label: const Text('全部'),
  selected: _selected == '全部',
  onPressed: () => setState(() {}),
);
```

## 在 HarmonyOS 上运行

要求使用鸿蒙社区 Flutter 分叉（CPF-Flutter）：

- 仓库：`https://atomgit.com/CPF-Flutter/flutter_flutter`
- 推荐分支：`oh-3.35.7-release`
- 通过 [fvm](https://fvm.app) 管理：`fvm use ohos/oh-3.35.7-release`

```bash
# 生成 ohos 平台工程（需要 DevEco 的 node / ohpm / hvigor 在 PATH 中）
fvm flutter create --platforms ohos .

# 构建并安装到模拟器 / 真机（免签名）
fvm flutter build hap --debug --no-codesign
hdc install -r build/ohos/hap/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.example.my_app
```

> 字体：鸿蒙设备自带 `HarmonyOS Sans`，ohos_ui 会自动使用；其他平台自动回退系统字体。

## 完整示例

`example/` 目录是一个展示全部组件的画廊应用，包含 4 个标签页（组件 / 表单 / 反馈 / 关于），运行方式：

```bash
cd example
fvm flutter pub get
fvm flutter build hap --debug --no-codesign
hdc install -r build/ohos/hap/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.example.ohos_ui_example
```

## 设计来源

- 华为鸿蒙设计入门文档：https://developer.huawei.com/consumer/cn/design/devstart/
- HarmonyOS-Design（设计原则 Skill 库）：https://github.com/dososo/HarmonyOS-Design
- HarmonyOS 官方 AppIcon 设计源文件（Sketch）

## 常见问题

- **部署时报 `npm not found`？** 需要把 DevEco Studio 内置工具加入 PATH：node、ohpm、hvigor 所在目录。
- **`flutter run` 报签名错误？** 使用 `flutter build hap --debug --no-codesign` 构建后 `hdc install`，模拟器免签名运行。

## License

MIT
