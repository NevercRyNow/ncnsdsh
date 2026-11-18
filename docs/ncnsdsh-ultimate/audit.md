# DSH Go `feat/ios-foundation` 审计

分支：`ccch1mneyyy/dsh-Go@feat/ios-foundation`（AGPL-3.0）
审计方式：GitHub API 读 `git/trees` 与原始文件，只看真实源码与文档。

## 1. 引擎运行时

| 事实 | 来源 |
|---|---|
| runtime 以 **manifest** 描述：schema、runtimeVersion、dshVersion、nodeVersion、files[path,size,sha256] | `EngineRuntime.swift` |
| 清单强制 `nodeVersion == "24.22.1"`，路径、sha256、目录冲突都校验 | 同上 |
| addon 以 `.framework` 嵌入（`DshFlock`、`DshRequireBuiltin`、`DshNodeHost`），必须与 runtime ZIP 同一布局，旧布局直接失败 | `app/ios/README.md` |
| 无签名构建仍产出未签名嵌套 framework，安装前必须重签 | 同上 |

**结论**：这是一套"预构建 runtime 包 + 校验 + 嵌入"的机制，不是源码内编译。
移植到 NcnsDSH 需要同样的产物体系，而我们没有 Node 引擎——所以本机不提供 DSH 引擎。

## 2. Linux 用户态

| 能力 | 源码 | 状态 |
|---|---|---|
| rootfs 安装（staging → rootfs，trash 回滚） | `GuestRootfsInstaller.swift` | 实现存在 |
| 崩溃门 / 挂起恢复（`isSuspended` / `resume`） | `GuestKernelAccess.swift` | 接口 + 实现 |
| 内核访问租约（`GuestRootfsLease`） | 同上 | 实现存在 |
| Apple SDK 编译与真机执行 | 文件头注释 | **未验证**（原文："Apple SDK compilation and device execution have not been verified."） |

**结论**：Linux guest 是真实代码，但作者自己标注未在 Apple SDK 下编译验证。
这属于「已实现但尚未验证」，不能标记为可用。

## 3. 手机操控

| 能力 | 源码 | 依赖 |
|---|---|---|
| 屏幕/点击/滑动/输入 | `IOSPhoneActions.swift`、`IOSPhoneScreen.swift` | 端上 XCTest 运行器 |
| 自运行器 | `IOSPhoneSelfRunner.swift` | `DSH_PHONE_SELF_RUNNER` 编译开关 + 共享原生库 |
| CoreDevice / DDI | `IOSPhoneCoreDevice.swift`、`IOSPhoneDDI.swift` | 开发者镜像、配对文件、LocalDevVPN |
| 配对存储 | `IOSPhonePairingStore.swift` | 配对凭证 |
| 审批 | `IOSPhoneTaskConsent.swift` | 每任务一次授权，最长 30 分钟 |

**结论**：依赖 XCTest/CoreDevice/私有通道，属于侧载与开发者配置路径，
**不可用于 App Store 发行**。NcnsDSH 不做这一块。

## 4. 通道覆盖

`tooling/ios/CHANNEL_COVERAGE.md` 记录：`app/lib` 声明 43 条 `dsh/*` 通道，iOS 注册或显式空事件流 35 条；缺 8 条（附件、动态取色、视频预览、手机预览、快捷方式、密钥、自更新、WebView 文件选择）。
文档明确："这个清单只证明通道注册与静态调用关系，不证明真实设备行为。"

## 5. 能力矩阵（结论）

| NcnsDSH 模块 | 可移植方式 | 本轮 |
|---|---|---|
| 本机 Swift 工具 | 已有 | ✅ |
| DSH Node 引擎 | 需要预构建 runtime + addon，我们无产物 | ⛔ |
| Linux rootfs | 需 ARM64 rootfs + guest 内核访问，且上游未验证 | ⛔ |
| 手机操控 | XCTest/CoreDevice/私有 API，不可发行 | ⛔ |
| 插件协议 | 可借鉴 schema，独立实现 | ⏳ |
| 远程主机 | HTTP+WS，可独立实现 | ⏳ |
| 性能监控 | 已有 Swift 实现 | ✅ |
| 环境更新/备份 | 可借鉴"staging + 校验 + 回滚" | ⏳ |

## 6. 与现有 NcnsDSH 的关系

NcnsDSH 是 SwiftUI 原生客户端 + DeepSeek 直连 + 原生工具。
DSH Go 是 Flutter + Node 引擎 + 本地 Linux。
两者共享的是**协议与交互经验**，不是运行时。因此本次升级做：
统一 Runtime 抽象 + 明确 unsupported，不伪造 Linux/Node/手机操控。
