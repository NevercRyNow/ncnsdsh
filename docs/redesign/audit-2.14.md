# 2.14.0 现状审计（Fluid Intelligence 重构的起点）

审计对象：仓库 `NevercRyNow/ncnsdsh`，提交 `28e3e05`（2.14.0）。
所有结论来自读代码，不来自规划文档；读不出来的就写「没有」。

## 1. 构建与发布

| 项 | 事实 |
| --- | --- |
| 版本 / 构建号 | `MARKETING_VERSION = 2.14.0`，`CURRENT_PROJECT_VERSION = 2`（`project.yml`） |
| Bundle ID | `com.nevercrynow.ncnsdsh` |
| Deployment Target | iOS **17.0** |
| Swift | 5.9 语言模式 |
| 签名 | 无签名 IPA（`CODE_SIGNING_ALLOWED=NO`） |
| CI | `.github/workflows/ios.yml`：push（`App/**`、`project.yml`、自身）+ 每 30 分钟 cron + 手动；`macos-latest`，Xcode 26.6，SDK iPhoneOS 26.5 |
| 产物 | `NcnsDSH-unsigned.ipa` 挂到 release `latest-build`，artifact 保留 14 天 |
| 并发 | `group: ncnsdsh-ipa`，`cancel-in-progress: false` → 新提交只能排队，不能顶掉旧排队 |
| 第二条流水线 | `ios26.yml` 仅手动触发，同样跑 macOS runner |

**已知事实：2.13.0 从未构建成功。** 失败点在 `App/Workbench/FileBrowserPane.swift`：
`.sheet(isPresented: $editing) { FileEditorView(url: url) }` 里 `$editing`、`url` 在该结构体
不存在（那套编辑器 sheet 属于 `FilePreview`，已经有一份）。2.14.0 删掉了这段重复挂载，
2.13.0 之前最后一个能装的包是 2.9.0。

## 2. 代码规模与结构

- 79 个 Swift 文件，13,259 行。
- `App/Views` 29 个文件、`App/Model` 14 个、`App/Workbench` 6 个、`App/DesignSystem` 8 个、
  `App/Core` 6 个、`App/Runtime` 4 个、`App/Local` 3 个、`App/Build` 3 个。
- 最大的几个：`LocalRuntimeView` 579、`BuildView` 516、`HomeView` 431、`LocalChatView` 416、
  `LocalStore` 411、`SettingsView` 407、`ModelIntelligenceDeck` 402、`WebView` 354。

## 3. 导航与页面

- iPhone：`MainShell` 用系统 `TabView`，5 个 tab：首页 / 项目 / 会话 / 工作台 / 更多
  （`AppTab`，`App/Navigation/Route.swift`）。**不是**悬浮 Dock，也没有选中区连续移动。
- iPad（`horizontalSizeClass == .regular`）：`PadShell`。
- 统一路由：`Route` 枚举（session / localSession / project / build / settings / devices），
  深链 `ncnsdsh://`、`dsh://`，Intent 都转成 `Route`。
- 常驻 mini bar：有运行中的会话时，底部浮一条 `matchedGeometryEffect` 的 mini bar，
  点开变成全屏 `ChatView`。这是目前唯一的「空间连续」交互。

## 4. 状态

`RootView` 一次性注入 13 个 `EnvironmentObject`：`HostStore`（外部）、`DemoStore`、`AppRouter`、
`AccountStore`、`LocalStore`、`BuildStore`、`PluginStore`、`PhoneAuth`、`AppChrome`、
`SettingsStore`、`ModelConfigurationStore`、`EnvironmentManager`、`PerformanceCenter`、`RuntimeManager`。
没有单一 AppState，页面之间靠这些 store 交叉读取。

## 5. 能力矩阵（代码里实际是什么）

| 能力 | 真实状态 | 依据 |
| --- | --- | --- |
| 模型列表 | 真：`GET https://api.deepseek.com/models` | `AccountStore:62` |
| 模型能力（工具/推理档） | 本地表 `ModelCapability.forModel` | `ModelConfiguration.swift` |
| 原生运行时 | 只能走工具调用，不接受任意命令 | `RuntimeProvider:107` |
| Linux 运行时 | **明确 unsupported**：「不安装 rootfs，不伪造 Shell」 | `RuntimeProvider:131` |
| 远程运行时 | 有 `RemoteProbe` / `HostStore`，需用户填地址与 token | `Runtime/HostStore` |
| 执行模式 | ASK / PLAN / AGENT / REVIEW，各自 `allowsTools` / `allowsWrites` | `ModelConfiguration:6-34` |
| 权限档 | 只读 / 工作区读写 / 改动前确认 | `ModelConfiguration:48` |
| 工具开关 | 10 个能力，只有 files/device/system/analysis 接到模型，其余标「未接入」且不可开 | `ToolCapability` + `ModelIntelligenceDeck` |
| 沙箱 | read-only / workspace-write / danger-full-access 三档，越界拒绝并记审计 | `Core/Sandbox.swift` |
| 文件编辑 | 有 `FileEditorView`，从 `FilePreview` 的「编辑」进 | `Workbench/FileBrowserPane.swift` |
| 终端 | 有 `TerminalPane`，跑的是工具调用，不是真 shell | `Workbench/TerminalPane.swift` |

## 6. 设计系统现状（重构的靶子）

- `DSH.swift`：Palette 11 个语义色（canvas 硬编码 `Color.black`）、Radius 3 个、Inset 3 个、
  Motion 3 个（snap 0.28/0.86、flow 0.42/0.90、fade 0.18）、TypeScale 7 个（全部 Dynamic Type）。
- `Theme.swift` 里还有一套并行的 `Motion`（snappy/panel/gentle）→ **两套 motion token 并存**。
- `Glass.swift`：`GlassBackground` 在 `#if compiler(>=6.2)` + `#available(iOS 26.0, *)` 时走
  `.glassEffect`，否则退 `.ultraThinMaterial`；`ncnsGlass` / `ncnsPill` 两个入口。
- 全仓 `glassEffect|ncnsGlass` 只有 11 处 → 玻璃基本没铺开，主体还是纯黑画布 + 白色透明度分层。
- 没有 Design Gallery，没有 Reduce Motion / Reduce Transparency 分支，没有浅色模式 token
  （`RootView` 直接 `.preferredColorScheme(settings.appearance.scheme ?? .dark)`）。
- 每个页面都是「标题 + 圆角卡片 + 列表」的同一套骨架：`HomeView`、`MoreView`、`SettingsView`、
  `PluginsView`、`DevicesView` 结构高度相似。

## 7. 与目标差距（按总指令的八个阶段）

| 阶段 | 现状 | 缺口 |
| --- | --- | --- |
| 1 审计 | 本文 | — |
| 2 研究 | 无 | 需要 HIG / Liquid Glass / 开源实现的可引用研究 |
| 3 Design System | 有 token 雏形，两套 Motion，无 Gallery | 统一 token、材质四件套、形状语法、Gallery |
| 4 品牌 / Dock / Core | 系统 TabBar；无 Intelligence Core | 整套重做 |
| 5 工作台 | 5 个 pane 已有，`WorkbenchView` 单态 | Compact/Expanded/Fullscreen 三态形变 |
| 6 Model / Runtime | Model Rail 已有（2.14.0 刚按参考片改了动效） | 并入新 Design System；Reasoning/Capability 未分栏 |
| 7 About / Settings | `AboutView` 已有但结构简单；`MoreView` 的「关于」版本号刚改成读 bundle | About 需按 PART 08 重做（Hero、Credits、License、致谢） |
| 8 验收 | CI 只能出包 | **本机不能编译、不能跑模拟器**（见下） |

## 8. 环境限制（必须写在最前面的事实）

这套会话跑在 iPhone 上的 DSH 里：没有 Swift 编译器、没有 Xcode、没有模拟器，
`swift`/`clang`/`xcodebuild` 都不存在，也不能装。因此：

- 编译只能交给 GitHub Actions 的 macOS runner，一次排队 + 构建约 15–40 分钟；
- 「实际运行项目」在本机做不到，只能：CI 出包 → 下载 IPA → 校验 Info.plist 版本与 SHA256；
- 界面不能在本机截图，SwiftUI 的观感只能靠代码审查 + 装机后人工确认。

不把 CI 出包说成「已运行」，也不把色板预览图说成 App 截图。
