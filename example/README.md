# harmony_ui 组件画廊示例

展示 `harmony_ui` 全部组件的画廊应用，可在 HarmonyOS 模拟器 / 真机、桌面和 Web 上运行。

在线演示：<https://shaohushuo.github.io/harmony_ui/>

## 截图

| 主页 | 导航类 | 布局与动效 | 输入类 |
| --- | --- | --- | --- |
| <img src="https://cdn.jsdelivr.net/gh/shaohushuo/harmony_ui@main/doc/screenshots/gallery_home.png" width="150"/> | <img src="https://cdn.jsdelivr.net/gh/shaohushuo/harmony_ui@main/doc/screenshots/gallery_navigation.png" width="150"/> | <img src="https://cdn.jsdelivr.net/gh/shaohushuo/harmony_ui@main/doc/screenshots/gallery_layout_light.png" width="150"/> | <img src="https://cdn.jsdelivr.net/gh/shaohushuo/harmony_ui@main/doc/screenshots/gallery_input.png" width="150"/> |

## 运行（HarmonyOS）

需要鸿蒙社区 Flutter 分叉（CPF-Flutter `oh-3.35.7-release`，推荐用 fvm 管理），
以及 DevEco Studio 的 node / ohpm / hvigor 工具链：

```bash
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
export JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home
export PATH=/Applications/DevEco-Studio.app/Contents/tools/node/bin:/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin:/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin:$PATH

fvm flutter pub get
fvm flutter build hap --debug --no-codesign
hdc install -r build/ohos/hap/entry-default-unsigned.hap
hdc shell aa start -a EntryAbility -b com.example.ohos_ui_example
```

## 运行（桌面 / 其他平台）

```bash
fvm flutter run -d macos   # 或 -d chrome 等
```

构建可部署的 Web 版本：

```bash
fvm flutter build web --release --no-tree-shake-icons --base-href /harmony_ui/
```

`--no-tree-shake-icons` 是因为 `harmony_icons` 中存在非 const 的 `IconData`
getter；缺少该参数时 Flutter Web release 构建会失败。发布流程与本地验收见
[`doc/DEMO-DEPLOYMENT.md`](../doc/DEMO-DEPLOYMENT.md)。

> 示例同时依赖 `harmony_icons`（HarmonyOS Symbol 图标，来自 pub.dev）与 `harmony_ui`。原 `ohos_icons` 已改名为 `harmony_icons`。
