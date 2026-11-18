# NcnsDSH 环境与性能架构

## 目标形状

```
AppRouter
   ↓
EnvironmentManager            ← 当前环境、配置、状态
   ↓
ExecutionCoordinator          ← 路由一次请求到具体运行时
   ├── LocalRuntime            ← 本机 DeepSeek + 原生工具（已有）
   ├── RemoteRuntime           ← dsh web（协议未接，返回 .unavailable）
   └── ServerRuntime           ← 长任务（未接，返回 .unavailable）
        ↓
   ToolRegistry（按环境过滤）
        ↓
   AgentEventStream（阶段、工具、审批）
        ↓
   SwiftUI
```

本轮先把 `EnvironmentManager` 与 `PerformanceCenter` 落地，运行时适配器保持
「已声明、未连接」的诚实状态。

## 数据模型

```swift
enum EnvironmentType { case iPhone, remoteDSH, server }
struct EnvironmentProfile {
    let id: UUID
    var type: EnvironmentType
    var name: String
    var workspace: String
    var runtimeVersion: String
    var hostID: UUID?        // 远端时指向 HostStore 里的宿主
    var lastUsed: Date?
}
enum EnvironmentStatus { case online, connecting, offline, unsupported(String) }
```

- 本机环境永远存在，不可删除；
- 每个宿主（Host）对应一个 remote 环境，随 HostStore 增删；
- 切换环境**不清会话**：会话仍按 sessionID 存储，列表里按环境分组显示；
- 环境配置持久化在 UserDefaults（`env.current`）。

## 运行时诊断

`RuntimeDiagnostics` 收集：

| 项 | 来源 | 说明 |
|---|---|---|
| 运行时版本 | Bundle 版本 | 真实 |
| 工具注册表 | `LocalTools.names` | 真实 |
| 工具健康 | 最近 50 次调用成功/失败 | 引擎内计数 |
| 工作区 | `AppFiles.workspace` | 真实路径 |
| 缓存占用 | 目录大小 | 真实 |
| 依赖状态 | 系统版本 / 权限 | 真实 |

## 性能中心

| 指标 | API | 备注 |
|---|---|---|
| 内存 | `task_vm_info.phys_footprint` | 进程真实占用 |
| CPU | `task_threads` + `thread_basic_info.cpu_usage` | 采样瞬时值，非精确均值 |
| 热状态 | `ProcessInfo.thermalState` | 系统值 |
| 低电量模式 | `ProcessInfo.isLowPowerModeEnabled` | 系统值 |
| 电池 | `UIDevice.batteryLevel`（需开启监测） | 系统值 |
| 网络 | `NWPathMonitor` | 类型 / 是否昂贵 / 是否受限 |

**不伪造延迟与带宽**：NWPathMonitor 不提供这些数据，UI 只展示能确证的状态。

## 自动优化（下一阶段）

数据先标定，再做策略，且策略必须可观测：

1. 内存 > 阈值 → 清空图片缓存、释放预览；
2. 热状态 ≥ `.serious` → 降低非必要动画、限制并发；
3. 网络昂贵/受限 → 不预取封面、复用连接；
4. 会话数 > 50 → 分页加载。

任何策略都只影响缓存与渲染，不删除用户数据。

## 与 DSH Go 的差异

- 不嵌 Flutter，不做 PRoot；
- 远程走 `dsh_client` 同形协议（session/follow + /dsh-go/v1/*），但由 Swift 实现；
- 实时活动因签名限制暂不做。
