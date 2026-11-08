# GitHub Pages 在线演示方案

在线画廊：<https://shaohushuo.github.io/harmony_ui/>

> 上面的正式地址使用 `shaohushuo.github.io`；部署成功后，仓库首页的 Pages
> 入口也会显示同一个站点的 URL。

## 目标

- 把 `example/` 作为 `harmony_ui` 的公开 Web 演示站。
- 演示站与 HAP、桌面端共用同一套示例源码，不维护第二份展示页面。
- 构建产物不提交进主分支，也不进入 AtomGit 镜像。
- GitHub 仓库名、fork、自定义域名变化时，无需手工修改资源路径。

## 技术选型

| 项目 | 选择 | 原因 |
| --- | --- | --- |
| 构建 SDK | 官方 Flutter `3.35.7` stable | 示例与组件库是纯 Dart/Flutter；Web 构建不需要 OHOS SDK |
| 构建入口 | `example/` | 直接复用完整组件画廊，避免演示与真实用法漂移 |
| 发布方式 | GitHub Actions Pages artifact | 原子发布，不需要维护 `gh-pages` 分支或提交生成文件 |
| 资源路径 | `actions/configure-pages` 的 `base_path` | 自动适配 `/<repo>/` 项目站点和根路径自定义域名 |
| 路由兜底 | 构建时复制 `index.html` 为 `404.html` | 直接访问子路径时仍能回到 Flutter 应用 |

示例当前只使用 Navigator 页面栈，不依赖 URL 路由，因此不需要额外引入
`go_router`；`404.html` 是后续启用深链时的轻量兜底。

## 发布流程

```text
push main / manual dispatch
          │
          ▼
official Flutter 3.35.7
          │
          ▼
cd example && flutter pub get
          │
          ▼
flutter build web --release
  --base-href <Pages base path>
  --no-tree-shake-icons
          │
          ▼
build/web ──upload-pages-artifact──▶ GitHub Pages
```

工作流位于 `.github/workflows/pages.yml`：

- 推送 `main` 且命中 `lib/**`、`example/**`、`pubspec.yaml` 或工作流自身时触发；
- 支持 `workflow_dispatch` 手工重发；
- 使用 `pages: write` 与 `id-token: write`，不依赖长期 PAT；
- deploy job 绑定 `github-pages` environment，发布记录可在 Actions 中审计。

## 为什么不用 `gh-pages` 分支

`gh-pages` 分支方式需要把 `build/web` 再提交一次，并推送到 GitHub。这个仓库还会
镜像到 AtomGit，生成文件会带来三个问题：

1. 每次构建都制造一个与源码无关的提交；
2. 双远端同步时容易把生成分支带到错误的地方；
3. 构建产物占用仓库历史体积，回滚也不直观。

Actions artifact 方式只在 Pages 的部署存储中保留当前版本，源码仓库保持干净。

## 首次配置

仓库管理员只需做一次：

1. 打开 GitHub 仓库的 **Settings → Pages**；
2. 将 **Build and deployment → Source** 设为 **GitHub Actions**；
3. 推送 `main`，或在 **Actions → Deploy web demo to GitHub Pages** 中执行
   **Run workflow**；
4. 在 Actions 的 deploy job 或 Pages 设置页确认站点 URL。

无需配置 `gh-pages` 分支、自定义域名或额外 Secret。

## 本地验证

```bash
cd example
flutter pub get
flutter build web \
  --release \
  --no-source-maps \
  --no-tree-shake-icons \
  --base-href /harmony_ui/
```

用与服务端相同的子路径启动：

```bash
tmpdir="$(mktemp -d)"
ln -s "$PWD/build/web" "$tmpdir/harmony_ui"
python3 -m http.server 8080 --directory "$tmpdir"
# 打开 http://127.0.0.1:8080/harmony_ui/
```

只做开发热重载时可直接运行：

```bash
flutter run -d chrome
```

## 已知约束

### `harmony_icons` 与图标 tree-shaking

`harmony_icons` 的 `OhosIconMeta.icon` 是非 const `IconData` getter，Flutter Web
的 icon tree shaker 会在 release 构建中拒绝它。因此 Pages 构建显式使用：

```bash
--no-tree-shake-icons
```

这不影响页面功能。代价是 Material Icons 字体不裁剪，镜像中约多出 1.5 MB。
如果后续上游图标包把动态 getter 改成可静态分析的 const 数据，可以移除此参数。

### 网络资源

示例「展示类」中有一张 `picsum.photos` 网络图片；离线或该站点不可达时只影响该
示例，不会阻塞其他页面。演示站本身不依赖后端服务或平台通道。

### 体积

Flutter Web release 产物约 30–35 MB，主要来自 CanvasKit/Skwasm 多套渲染引擎，
不是组件库体积。GitHub Pages 的项目站点限制远超这个量级，当前无需拆分。

## 发布验收清单

- 首页、8 个分类页均可打开；
- 顶栏主题按钮可循环切换浅色、深色、墨水屏；
- 浏览器控制台无 404 资源错误；
- `/harmony_ui/` 下的 `main.dart.js`、字体、CanvasKit 均从同一 base path 加载；
- 手机窄屏和桌面宽屏都能正常滚动、返回上一页；
- 构建日志中没有 tree-shaking 失败。
