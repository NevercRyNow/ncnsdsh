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
| 2.17.2 | `f635aa7` | 修 Core 状态比较；工作台 pane 常驻 + 专注模式 | 见下方 |

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
- `App/Views/LiquidDock.swift`（新）：悬浮玻璃 Dock。选中胶囊 `matchedGeometryEffect`
  连续滑动，按压回弹，侧滑/长按切换。
- `App/Views/MainShell.swift`：**没有拆 TabView**，只隐藏系统 tab bar 并把 Dock 叠在上层，
  底部安全区 +64pt。导航与各 tab 的状态保持原样。

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
