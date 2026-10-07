# ohos_ui 组件画廊示例

展示 `ohos_ui` 全部组件的画廊应用，可在 HarmonyOS 模拟器 / 真机上运行。

## 截图

| 组件 | 表单 | 反馈 | 关于 |
| --- | --- | --- | --- |
| <img src="https://cdn.jsdelivr.net/gh/shaohushuo/ohos_ui@main/doc/screenshots/gallery_home.png" width="150"/> | <img src="https://cdn.jsdelivr.net/gh/shaohushuo/ohos_ui@main/doc/screenshots/gallery_form.png" width="150"/> | <img src="https://cdn.jsdelivr.net/gh/shaohushuo/ohos_ui@main/doc/screenshots/gallery_feedback.png" width="150"/> | <img src="https://cdn.jsdelivr.net/gh/shaohushuo/ohos_ui@main/doc/screenshots/gallery_about.png" width="150"/> |

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

> 示例同时依赖 `ohos_icons`（HarmonyOS Symbol 图标）与 `ohos_ui`。
