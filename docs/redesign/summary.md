# 设计与工程变更总结（Fluid Intelligence 重构）

交付版本：**2.21.1 / build 36**（无签名 IPA，SHA-256 `da572650…`，与 release 的
`SHA256.txt` 一致）。
过程记录在 [progress.md](progress.md)，动效测量在 [model-deck-motion.md](model-deck-motion.md)，
研究引用在 [design-research.md](design-research.md)，无障碍在 [accessibility-audit.md](accessibility-audit.md)。

## 一、逐阶段交付

| 阶段 | 交付 | 状态 |
| --- | --- | --- |
| 1 审计 | [audit-2.14.md](audit-2.14.md)：79 文件 / 13,259 行、能力矩阵、CI 现状 | 完成 |
| 2 研究 | [design-research.md](design-research.md)：HIG / Liquid Glass 规则、7 个开源实现审计、三套方向与选型 | 完成 |
| 3 Design System | `Fluid.swift`：动态色（深浅两套真值）、6 档按目的 motion、内容表面、Reduce Transparency / Motion | 完成，待真机观感确认 |
| 3b Gallery | 更多 → 设计系统：色板、表面、字号、六态核心、动效表 | 完成 |
| 4 Dock | 自绘悬浮 Dock → **按用户要求回退**，回到系统 TabBar | 已回退 |
| 4 Core | `IntelligenceCore`：六态全部指到真实信号；无信号的状态不画 | 完成 |
| 5 Workspace | pane 常驻、标签连续滑动、专注模式、聊天内**两档 sheet**（medium/large，系统手势） | 部分完成 |
| 6 Model Rail | 参考片量出的动效（入场 0.17s / 形变 0.10–0.15s / 90° 顶部高光 + `#1B3D97→#4E2D8D`），整页并入 Fluid token | 完成 |
| 6 Runtime | 「能力与限制」卡 + 信息架构重排（状态 → 能力 → 环境 → Linux → 日志 → 备份 → 危险） | 完成 |
| 7 About | 版本块（34pt 等宽 + build + 复制）、制作人块（郑壹鸣 / Created by Zheng Yiming）、Project / 致谢 / MIT 全文 | 完成 |
| 7 Settings | 通用 / 连接 / 能力 / 关于四段；关于行显示真实版本 | 完成 |
| 7 插件 | 真实市场目录（41 条）+ 安装按钮（有主机则打开主机 DSH）+ 加载/失败/重试 | 完成 |
| 7 设备 | dsh-go 桥协议协商卡（协议 v1 / bridge 版本 / 能力数 / 具体失败原因） | 完成 |
| 7 构建 | 状态 → 本次步骤 → 操作 → 历史 → 仓库，整页 Fluid token | 完成 |
| 8 验收 | 每个版本在 macOS runner 构建；解包读 Info.plist；与 release 资产 digest / `SHA256.txt` 比对 | 每版执行 |

额外交付：启动动画（石墨底 → 玻璃面板 + 字标 → **霜化玻璃抬起、应用由朦胧变清晰**，3.0s，
Reduce Motion 1.4s）；浮条拖拽/点击卡住的两次修复（去掉自绘手势与玻璃形变）。

## 二、被证伪的假设（都留下证据）

1. **「2.13.0 在排队」是错的**：它编译失败——`FileBrowserPane` 引用不存在的 `$editing` / `url`。
2. **「隐藏系统 TabBar 就能叠自绘 Dock」是错的**：`.toolbar(.hidden, for: .tabBar)` 在 iOS 26
   真机没生效，2.16.1 装上去是两条 Dock。
3. **「每 30 分钟定时构建只是慢」是错的**：cron 与 push 抢同一个 concurrency 组，排队堆积；
   已改每日 + 手动。
4. **「浅色只是没设计」不完全对**：13 个页面各自把 `.preferredColorScheme(.dark)` 钉死，
   换动态色并去掉钉子后才真正生效。
5. **「拖动浮条卡住是复位没做好」是错的**：根因是它在 `GlassEffectContainer` 里逐帧改 offset，
   让容器重算玻璃形状；最终把拖拽与 matchedGeometry 形变整段删除才解决。

## 三、未完成清单

1. **工作台从底部导航的连续形变**：聊天内是两档 sheet，但从 tab 进入仍是普通页面；
   要做真正的形变得换掉系统 TabView 的呈现方式，风险高且必须真机看。
2. **浅色模式、200% 字号、读屏顺序的真机确认**：这三样只能在设备上判断，我这边看不到画面。
3. **性能**：玻璃、`TimelineView`、`matchedGeometryEffect` 的实际开销未测。
4. **dsh-Go 引擎嵌包**：许可证已改 AGPL-3.0，引擎在 CI 编译通过（见下），但**尚未嵌入 App**——
   需要决定是否接受 ~50MB 的包体与 15 分钟以上的构建时间。
5. 装饰性图标尚未全部标 `accessibilityHidden`；老页面还有少量写死字号。

## 四、dsh-Go 移植状态（另一条线）

- **许可证**：仓库已从 MIT 改为 **AGPL-3.0**（`LICENSE` 全文 + `NOTICE`），因为引擎是 AGPL。
  没有 vendor 它的源码。
- **引擎已能在 CI 编译**（run `44483918089`，全绿）：`prepare-engine.sh` 生成
  `NodeMobile.xcframework` + 45.9MB runtime 归档，`build-engine-native.sh iphoneos <out>`
  产出 `DshNodeHost.framework`、`DshFlock.framework`、`DshRequireBuiltin.framework`。
- **尚未做**：把 framework 与 runtime 打进 App、写 Swift 侧宿主胶水、真机启动验证。
  评估与路径见 [dsh-go-port-assessment.md](dsh-go-port-assessment.md)。

## 五、验收方式（可复现）

每个版本：

1. `xcodebuild` 在 GitHub `macos-latest`（Xcode 26.6 / iOS 26.5 SDK）构建成功；
2. 下载 release 的 `NcnsDSH-unsigned.ipa`；
3. `python3` 解包读 `Payload/NcnsDSH.app/Info.plist` 的 `CFBundleShortVersionString` / `CFBundleVersion`；
4. 计算 SHA-256，与 release 资产的 `digest`（2.21.0 起还有 `SHA256.txt`）比对。

本环境没有 Swift 编译器与模拟器，**「构建通过」与「观感正确」是两件事**——后者需要真机确认。
