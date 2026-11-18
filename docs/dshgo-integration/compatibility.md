# DSH Go ↔ NcnsDSH 能力对照

图例：✅ 已实现 · 🟡 部分 · ⏳ 计划 · ⛔ 平台不支持（不装样子）

| DSH Go 能力 | iOS 现状 | NcnsDSH 目标 | 本轮 |
|---|---|---|---|
| 本机引擎（Node/PRoot） | ⛔ iOS 无 PRoot；fork 的 nodejs-mobile 未跑通 | 原生 Swift 运行时 | ✅ 原生工具 |
| 远程 Host（HTTP+WS） | ✅ `dsh_client` | `RemoteRuntime` 适配器 | ⏳ 协议未接 |
| SSH / 中继 | ✅ dartssh2 / Noise | 暂不做 | ⛔ |
| 会话队列 / 中断 | ✅ 队列 + INTERRUPT | ConversationQueue | ⏳ 下一阶段 |
| 插件 SDK 卡片 | ✅ contributions/invoke | 原生卡片 | ⏳ |
| 手机操控（Android） | ⛔ 无无障碍/Shizuku | 不做 | ⛔ |
| 文件 Provider | ✅ | 已具备工作区 | ✅ |
| 媒体处理 | ✅ | 图片 OCR、预览 | ✅ 部分 |
| 后台保活 | ✅ 静音音频 | 已有，默认关 | ✅ |
| 实时活动 | ⚠️ 签名受限 | 暂不做 | ⛔ |
| 今日用量 | ✅ | 会话内 token 统计 | 🟡 |
| 运行诊断 | 🟡 | RuntimeDiagnostics | ✅ 本轮 |
| 性能监控 | ❌ | PerformanceCenter | ✅ 本轮 |
| 自更新 | ⛔ APK 安装器 | 走 GitHub Release | ✅ 已有 |

## 明确不做的事

1. **不嵌 Flutter**、不用 WKWebView 当核心界面。
2. **不伪造 Linux**、不声称有任意子进程执行。
3. **不做手机操控**（读别的 App 屏幕、自动点击），iOS 不允许。
4. **不复制 AGPL 代码/资源**，只借鉴协议形状与交互逻辑。

## 远端协议前提

`dsh_client` 的关键形状（来自 `docs/architecture.md`）：

- 连接：HTTP + WebSocket 到 `dsh web`（默认 3080）；
- 会话：订阅 `session/follow` 事件流；
- 插件：`/dsh-go/v1/contributions|invoke|stream`；
- 鉴权：一次性 token 换持久 cookie。

NcnsDSH 的 `RemoteRuntime` 将按这个形状实现；未接上之前，远端环境显示
「未连接 · 去配对」，不返回假会话。
