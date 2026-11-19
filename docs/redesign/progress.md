# Fluid Intelligence 重构 · 进度与变更记录

以每次成功出包为准，没出包的改动不算完成。

| 版本 | 提交 | 内容 | 验证 |
| --- | --- | --- | --- |
| 2.13.0 | `ebb35ec` | 模型卡斜向扫光 | **从未构建成功**（`FileBrowserPane` 引用不存在的 `$editing`/`url`） |
| 2.14.0 | `4523848` | 按参考片重做模型卡动效；删斜向扫光与 3D 倾斜 | 被下一次推送取消，未单独验证 |
| 2.15.0 | `163648d` | Fluid token 层、About 重做、CI 排队治理 | 同上，被取消 |
| 2.16.0 | `e649497` | Liquid Command Dock | 编译失败：`Fluid.Type` 与 `.Type` 元类型语法冲突 |
| 2.16.1 | `d61e198` | 改名 `Fluid.Typography` | **成功**，IPA 校验通过（2.16.1 / build 5） |
| 2.17.0 | `e16ac18` | Intelligence Core、Design Gallery | 被下一次推送取消 |
| 2.17.1 | `6d3dbc8` | 动态色 token、去掉 13 处 `.preferredColorScheme(.dark)` | 编译失败：`ToolStatus` 未遵循 `Equatable` |
| 2.17.2–2.17.5 | `f635aa7`…`d4c545e5` | Core / 浅色 / 工作台 / Runtime / 设置 / **Dock 回退** | 多次排队被清；最终 2.17.6 一次成功 |

## 2.17.2 的设计与工程变更

### 设计系统

- `App/DesignSystem/Fluid.swift`（新）
  - **动态语义色**：`UIColor { trait in … }`，深/浅两套真实值；不是把深色反相。
  - **动效按目的分档**：press 0.12s / select 0.18s / panel 0.34s / dock 0.40s /
    spatial 0.46s / state 0.24s，落在设计指令 5.3 给的区间里；`respecting(_:)`
    在 Reduce Motion 下退成 0.18s 淡入。
  - **内容表面** `fluidSurface()`：实色 + 0.5pt 细线，**不用玻璃**。依据是 HIG
    「Don't use Liquid Glass in the content layer」，见 `design-research.md`。
  - 带 Reduce Transparency / Increase Contrast 分支。
- `App/DesignSystem/DSH.swift`：Palette 全部换成动态色，深色值与 2.16.x 逐值一致
  （所以深色观感不变），浅色是新的正式配色。
- 去掉 13 处逐页 `.preferredColorScheme(.dark)`，外观设置第一次真正生效。

### 品牌与导航

- `App/Views/AboutView.swift`（重做）：Hero + 版本芯片（点按复制 `NcnsDSH 2.17.x (n)`）
  + Application / Credits / Project / Acknowledgements，内置 MIT 全文；分区依次入场，
  Reduce Motion 下只淡入。版本、构建号、最低系统全部从 Bundle 读。
- ~~自绘悬浮 Dock~~：2.16.1 装机后出现**两条 Dock**（系统 TabBar 没有被
  `.toolbar(.hidden, for: .tabBar)` 藏住），2.17.5 已整体回退：删掉 `LiquidDock.swift`，
  `MainShell` 恢复系统 TabBar，mini bar 的底部距离回到 58pt。用户明确要原来的 Dock。

### 状态表达

- `App/Views/IntelligenceCore.swift`（新）：核心的六个状态全部能指到真实信号——
  `demo.approval`（等待确认）、`ToolStatus.running`（工具调用）、`message.isStreaming`
  （流式）、`demo.runningCount`（运行中）、最后一个工具 failed（失败）、其余空闲。
  没有 paused/completed，因为没有东西会产出这两个状态，不画假动画。
  只在 active 时转动，Reduce Motion 下静止。

### 工作台

- `App/Workbench/WorkbenchView.swift`：pane 一旦访问就留在 ZStack 里，切工具不再重建
  终端/浏览器/文件列表（滚动位置、当前目录、页面都保住）；标签胶囊连续滑动；
  新增专注模式（收起标题与标签栏，`spatial` 弹簧）。

### 验收工具

- `App/Views/DesignGalleryView.swift`（新）：Release 也能进（更多 → 设计系统）。
  色板、内容表面、字号、六个核心状态、动效档位、活的 Dock。
  只在 Debug 里能看的画廊，CI 永远验证不到。

### CI

- `.github/workflows/ios.yml`：cron 从每 30 分钟改成每天一次；`cancel-in-progress: true`。
  之前定时任务和 push 抢同一个 concurrency 组，排队会一直堆。

## 还没做的（按总指令）

1. **Runtime 页面**（PART 07.4）：三栏（原生/Linux/远程）现在是混在一个页面里，
   没有按「环境 → 能力 → 日志 → 限制」重排；Linux 明确 unsupported，需要把
   「为什么不能」做成正经的信息设计而不是一行字。
2. **Model Rail 视觉统一**：卡片动效已按参考片量过，但整页还在用旧的 DSH 分层，
   没并入 Fluid token；Reasoning / Capability 也没有拆成独立 rail。
3. **Settings 分区重排**（PART 07.7）：现在仍是一长串分组列表。
4. **Morphing Workspace 全手势**：目前是「pane 常驻 + 专注模式」，
   还没有从 Dock 到工作台的连续形变与速度吸附。
5. **Dynamic Type / VoiceOver 全量审计**：新写的页面用了 Dynamic Type，
   老页面还有死字号。
6. **浅色模式验收**：配色是新做的，**没有在真机上用眼睛看过**。
7. **性能**：玻璃与 TimelineView 的实际开销没测（本机无法运行）。
8. **插件页 / 设备页 / 构建页**：仍是旧骨架。

## 本机限制（每次都要说明）

这个会话跑在 iPhone 上的 DSH 里：没有 Swift 编译器、没有 Xcode、没有模拟器。
编译只能交给 GitHub Actions 的 macOS runner；「运行验收」只能做到出包 + 解包校验
Info.plist 与 SHA256。SwiftUI 的观感必须由人装在手机上确认。

## 当前状态：GitHub 不可达（2026-11-18 起）

| 位置 | 版本 |
| --- | --- |
| 本地 `main` | 2.17.4（build 10） |
| GitHub `main` | 2.17.2（`f635aa7`） |

- `github.com`、`api.github.com` 在这台设备上被 TCP reset（DNS 把 github.com 指到
  `66.220.148.145`，真实 API IP 也连不上）。
- `raw.githubusercontent.com`、`objects.githubusercontent.com` 可以连——所以能读到
  GitHub 上的内容，但**不能 push、不能查 CI、不能取 release 资产**。
- 因此 2.17.2 之后的构建状态未知；**2.16.1 是最后一个验证过的包**。

本地已提交但没验证的改动：

- `f635aa7` 2.17.2 · `ToolStatus` 补 `Equatable`、工作台 pane 常驻 + 专注模式
- `242abc2` 2.17.3 · Runtime 页「能力与限制」
- `05e6e93` / `02350fb` 2.17.4 · 设置页分区 + `@ViewBuilder` 参数写法
- `126a731` · 装机验收清单 `acceptance-2.17.md`

网络恢复后的恢复步骤（脚本已经写好，`~/work/ship.sh`）：

1. `git push` 到 main（脚本会重试 5 次）；
2. 等新 run，**排队被 GitHub 清掉就自动 rerun**（macOS runner 现在排队超过 15 分钟会被清）；
3. 构建成功后跑 `verify_ipa.py`：下载 release 资产、比对 API digest、解包读
   `CFBundleShortVersionString` / `CFBundleVersion`。

恢复时要注意的一件事：4 个提交是一起进构建的，如果编译失败，先看日志里第一个
`error:` 的文件；已知的高风险点是 `App/Workbench/WorkbenchView.swift`（2.17.2 重写）
和 `App/Views/SettingsView.swift`（2.17.4 新加的分区 helper）。

## 2.17.6 验证结果（2026-11-19）

- GitHub Actions run `44428580998`：Build / Package / Upload / Release 全部 success。
- IPA：3,913,507 字节，SHA-256 `22c0459dc376ab6b420860336a72c08a56062d3eade93f973b70165412efc1ba`，
  与 GitHub release 资产 `digest` 一致。
- 解包读 `Payload/NcnsDSH.app/Info.plist`：`CFBundleShortVersionString = 2.17.6`，
  `CFBundleVersion = 12`，`MinimumOSVersion = 17.0`，可执行文件在包内。
- 构建日志里 2.17.5 唯一的错误是 `WorkbenchView` 用了不存在的
  `Fluid.Palette.canvas` / `.raised`（应为 `.obsidian` / `.graphite`），2.17.6 已修。

### 2026-11-19 上午：runner 恢复后的连续出包

| 版本 | 提交 | 内容 | 校验 |
| --- | --- | --- | --- |
| 2.17.6 | `479d616` | 修 `WorkbenchView` 里两个不存在的 palette 名（`canvas`/`raised`） | 成功，`2.17.6 / 12` |
| 2.17.7 | `8e6e1ff` | 旧 `Theme` 调色板也改成动态色（55 处调用点）；玻璃按钮不再写死白字；教程页文字跟随外观 | 成功，`2.17.7 / 13` |
| 2.17.8 | `90d6b89` | 定时任务的开关从 `.constant()` 假开关改成真正写回 `DemoStore` | 成功，`2.17.8 / 14` |
| 2.17.9 | `2c4b6cf` | 中断生成：`DemoStore.cancelStreaming` + 输入栏红色停止按钮 | 成功，`2.17.9 / 15` |

三个包的 SHA-256 都与 release 资产的 `digest` 一致，`Info.plist` 版本号解包核对过。

| 2.18.0 | `dab9ae9` | 运行中会话条拖动卡住：`minimumDistance` 0→8、复位挂到 `@GestureState` 释放、横移 36pt、去掉逐帧旋转 | 成功，`2.18.0 / 16` |
| 2.18.1 | 见提交 | 聊天/构建/连接页文字改成动态色（浅色下不再白字白底）；助手消息长按复制 | 成功，`2.18.1 / 17` |
