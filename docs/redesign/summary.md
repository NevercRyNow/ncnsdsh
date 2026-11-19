# 设计与工程变更总结（Fluid Intelligence 重构）

这份是交付总结；过程记录在 [progress.md](progress.md)，动效测量在
[model-deck-motion.md](model-deck-motion.md)，研究引用在 [design-research.md](design-research.md)。

## 一、做了什么

| 阶段 | 交付 | 状态 |
| --- | --- | --- |
| 1 审计 | [audit-2.14.md](audit-2.14.md)：79 文件 / 13,259 行，能力矩阵，CI 现状 | 完成 |
| 2 研究 | [design-research.md](design-research.md)：Apple HIG / Liquid Glass / 7 个开源实现审计；三套方向与选型 | 完成 |
| 3 Design System | `Fluid.swift`：动态色（深/浅两套真值）、按目的分档的 5+1 个 motion、内容表面、Reduce Transparency / Motion 分支 | 代码完成，待真机验收 |
| 3b Gallery | 更多 → 设计系统：色板、表面、字号、六个核心状态、动效表 | 代码完成，待真机验收 |
| 4 Dock | 自绘悬浮 Dock → **已回退**（装机出现两条 Dock，用户要原来的系统栏） | 已回退 |
| 4 Core | `IntelligenceCore`：六态全部指到真实信号，没有信号的状态不画 | 代码完成，待验收 |
| 5 Workspace | pane 常驻（切工具不重建）、标签胶囊连续滑动、专注模式 | 代码完成，待验收 |
| 6 Model Rail | 按参考片量出的动效：入场 0.17s / 形变 0.10–0.15s / 90° 顶部高光 + `#1B3D97→#4E2D8D` | 已验证（2.16.1） |
| 6 Runtime | 「能力与限制」卡：原生只走工具调用、Linux 本机不可用、远程需要 `dsh web` | 代码完成 |
| 7 About | Hero、可复制版本胶囊、Application/Credits/Project/Acknowledgements、内置 MIT | 已验证（2.16.1 的骨架），2.17 版待验收 |
| 7 Settings | 通用 / 连接 / 能力 / 关于四段；关于行显示真实版本 | 代码完成 |

## 二、被证伪的假设

1. **「2.13.0 在排队」是错的**：它其实编译失败——`FileBrowserPane` 引用不存在的
   `$editing` / `url`。修掉之后才有 2.14 之后的版本。
2. **「隐藏系统 TabBar 就能叠自绘 Dock」是错的**：`.toolbar(.hidden, for: .tabBar)`
   在真机（iOS 26）上没有生效，2.16.1 装上去是两条 Dock。已整体回退。
3. **「每 30 分钟定时构建」在拖后腿**：cron 和 push 抢同一个 concurrency 组，排队堆积。
   已改成每天一次。
4. **「浅色只是没设计」不完全对**：13 个页面各自 `.preferredColorScheme(.dark)` 钉死，
   即使选了浅色也不会变。换成动态色 + 去掉钉子后才真正生效。

## 三、未完成清单

1. **Morphing Workspace 的连续形变**：目前是「pane 常驻 + 专注模式」，没有从底部
   导航到工作台的手势驱动形变与速度吸附。自绘 Dock 回退后，这一条需要重新设计入口。
2. **Runtime 页整体信息架构**：加了三档能力说明，但页面仍是「状态 → 控制 → 日志」平铺，
   没有按「环境 / 能力 / 资源 / 日志 / 限制」重排。
3. **Model Rail 并入 Fluid token**：卡片动效是新的，但整页仍用旧的 `DSH` 分层。
4. **插件 / 设备 / 构建页**：仍是旧骨架。
5. **Dynamic Type 与 VoiceOver 全量审计**：新页面走 Dynamic Type，老页面还有死字号。
6. **浅色模式真机验收**：配色是新做的，没有在设备上看过。
7. **性能**：玻璃、`TimelineView`、`matchedGeometryEffect` 的实际开销未测。
8. **每个阶段的独立构建验证**：受 runner 排队影响，2.17.x 多次被平台清掉。

## 四、工程与 CI

- `project.yml`：2.13.0 → 2.17.5，`CURRENT_PROJECT_VERSION` 1 → 11。
- `.github/workflows/ios.yml`：cron `*/30` → 每日；`cancel-in-progress` 在诊断排队问题时
  先关掉（定时任务已不再堆积）。
- 新增 `.github/workflows/validate.yml`：macos-15 上只做编译验证，不出包。
- 新增 `docs/redesign/` 五份文档；`~/work/verify_ipa.py` 负责解包校验版本与哈希。

## 五、环境限制

本会话跑在 iPhone 上的 DSH 里：没有 Swift 编译器、没有 Xcode、没有模拟器。
编译只能交给 GitHub Actions 的 macOS runner；「运行验收」只能做到出包 + 解包校验
Info.plist 与 SHA256。SwiftUI 的观感必须由人装在手机上确认——所以才有
[acceptance-2.17.md](acceptance-2.17.md)。

## 六、当前进度（2026-11-19）

| 项 | 状态 |
| --- | --- |
| 交付版本 | **2.19.6 / build 30**（每次出包都核对 Info.plist 与 release digest） |
| 启动动画 | 已实现：石墨底 → 玻璃面板 + 字标 → **霜化玻璃抬起、应用由朦胧变清晰**（3.0s，Reduce Motion 1.4s） |
| 插件市场 | 接真实目录（41 个条目），每行有「安装」，有主机时打开主机 DSH |
| 关于 | 版本块（34pt 等宽 + build + 复制）与制作人块（郑壹鸣 / Created by Zheng Yiming）独立成块 |
| 工作台 | pane 常驻 + 专注模式；聊天里的工作台现在是**两档 sheet**（medium / large，系统拖拽） |
| 底部遮挡 | 浮条出现时 TabView 统一让出 64pt，不再逐页打补丁 |
| dsh-Go 引擎 | 许可证已改 AGPL-3.0；引擎在 CI 编译通过（NodeMobile + 三个 framework + 45.9MB runtime），**尚未嵌入 App** |

仍未完成：工作台从底部导航的连续形变、Model Rail 全页并入 Fluid token、
插件/设备/构建页的完整重构、Dynamic Type 与 VoiceOver 全量审计、
浅色模式的真机观感确认。
