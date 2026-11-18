# NcnsDSH 2.0 · 架构

原则：**保留已经跑通的东西，新增模块挂在同一套路由与数据层上。**
不推倒重来，不重复 Router，不换掉 XcodeGen。

## 1. 目录

```
App/
├── Core/                 # 无 UI：错误、日志、格式化、环境
│   ├── Haptics.swift
│   ├── AppError.swift
│   └── Formatters.swift
├── DesignSystem/         # 颜色/字体/间距/玻璃/封面
│   ├── Theme.swift  DSH.swift  Glass.swift  RemoteArtwork.swift
│   └── Components/（Row, StatusDot, SectionHeader, EmptyState, Toast）
├── Navigation/           # AppRouter、Route、深链、Intent 桥
│   ├── AppRouter.swift
│   └── Routes.swift
├── Models/               # 领域模型（ChatSession, LocalSession, DSHPlugin…）
├── Networking/           # GitHubAPI、DeepSeekAPI、未来的 MobileGateway
├── Persistence/          # Keychain、AppFiles、LocalStore、SettingsStore
├── Features/
│   ├── Home/
│   ├── Projects/
│   ├── Sessions/
│   ├── Workbench/
│   ├── Automations/
│   ├── Devices/
│   ├── Plugins/
│   ├── Builds/
│   └── Settings/
└── App/                  # DSHApp、RootView、MainShell/PadShell
```

现状映射：现有 `Model/`、`Views/`、`Local/`、`Build/`、`Workbench/` 按目标目录**逐步迁移**，
每迁一个模块都必须能编译，不做一次性大搬家。

## 2. 导航

- 唯一入口 `AppRouter`：`@Published tab` + `@Published path: [Route]`。
- `Route` 是枚举（session / project / plugin / build / settings / device…），
  深链 `ncnsdsh://session/<id>`、App Intents、通知点击全部转成 `Route`。
- iPhone：`TabView`（Home / Projects / Sessions / Workbench / More）。
- iPad：`NavigationSplitView`，侧栏是同一份 `Route` 列表。
- 页面状态恢复：`AppRouter` 持久化 `tab + path` 到 UserDefaults，冷启动可还原。
- **禁止**页面内部自己 push 到别的 Tab；跨模块跳转一律 `router.open(route)`。

## 3. 数据层

| 层 | 现状 | 目标 |
|---|---|---|
| 本机会话 | `LocalStore`（JSON 持久化） | 保留，补迁移版本号 |
| 远端会话 | `DemoStore`（演示数据） | 换成 `MobileGatewayClient`，DemoStore 保留为预览 |
| 设置 | `SettingsStore` | 保留，增加 schema 版本 |
| 构建 | `BuildStore`（GitHub API） | 保留，补队列与历史 |
| 插件 | `PluginStore`（本地目录） | 保留，补远端索引 |
| 设备 | 无 | `DeviceStore` + 配对/连接状态机 |

**接缝规则**：视图只调 `Store` 的方法，`Store` 只调 `Client`。新协议先在 `Networking/`
定义 `protocol`，未连接时返回 `.unavailable`，**不伪造数据**。

## 4. 远端协议

先读 `dsh-plugin-mobile-gateway` 的客户端契约，再写适配层：

- 一次性 token → cookie 的配对语义不能改；
- 消息流是独立帧（assistant-stream），客户端要按 rc.2 指南订阅；
- 能力发现：客户端启动时拉 capabilities，不支持的功能隐藏入口；
- 断线：指数退避重连，前台恢复立即重连；
- 所有写操作带 `idempotencyKey`，重试不重复执行。

未接上之前，远端页面显示「未连接」空状态 + 去配对入口，不用假会话填充。

## 5. 错误 / 加载 / Toast / 确认

统一四个类型，避免每个页面自己弹 alert：

```swift
enum AppError: LocalizedError { case network(String), auth(String), notFound(String), unavailable(String) }
enum LoadState<Value> { case idle, loading, loaded(Value), failed(AppError) }
struct Toast { enum Kind { case info, success, warning, error } ; let kind: Kind; let text: String }
```

- Toast 由 `ToastCenter` 统一展示，玻璃胶囊 + 2.4s 自动消失。
- 破坏性操作统一 `ConfirmDialog`，文案包含对象名与后果。
- 网络错误给「重试」，权限错误给「去设置」。

## 6. 并发与性能

- Swift 6 并发：Store 标 `@MainActor`，网络 Client 为 `actor` 或 `Sendable struct`。
- 流式文本合并到 30Hz 刷新，不逐 token 触发重绘。
- 列表用稳定 id；图片走 `ArtworkCache`（内存 + 磁盘）。
- 长任务用 `Task` + 取消；页面消失时取消订阅。
- 禁止在主线程做文件遍历与 JSON 解码大文件。

## 7. 安全

- Key / Token 只进 Keychain（`afterFirstUnlockThisDeviceOnly`）。
- 工作区路径解析统一走 `AppFiles`，禁止 `..` 穿越。
- 终端只允许白名单命令，不执行任意进程。
- 网页/封面等外部请求不携带任何凭据。

## 8. 测试

- 单元：token 估算、路径解析、GitHub 错误映射、会话压缩、设置持久化。
- 快照/布局：小屏（SE）、大屏（Pro Max）、iPad 三档。
- 交互：mini bar 展开、模型切换、构建状态机（用 mock client）。
- CI：`xcodegen` + `xcodebuild build`；测试目标随模块增加。

## 9. 迁移顺序

1. Core（Haptics/Error）→ 2. DesignSystem 组件 → 3. Navigation 收口 →
4. Home → 5. Sessions → 6. Workbench → 7. Projects → 8. More（Plugins/Builds/Devices/Automations）→ 9. Settings。

每一步可独立编译、独立回滚；旧文件在模块迁移完成后删除，不做并行两套。
