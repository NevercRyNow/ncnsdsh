# Runtime 架构

## 形状

```
RuntimeManager
 ├── NativeRuntime   ✅ 可执行（Swift 工具 + 沙箱）
 ├── LinuxRuntime    ⛔ unsupported（iOS 无 guest）
 └── RemoteRuntime   ⏳ unsupported（协议未接）
```

`RuntimeProvider` 协议：`status / start / stop / pause / resume / install / upgrade / execute / diagnostics`。
**不支持的能力抛 `RuntimeError.unsupported(reason)`，UI 显示原因，不假装成功。**

## 为什么不实现 Linux

审计见 `audit.md`：dsh-Go 的 guest rootfs 源码自带注释
「Apple SDK compilation and device execution have not been verified」，
且需要 ARM64 rootfs、内核访问租约与预构建 Node runtime。
我们没有这些产物，也不打算伪造一个 Shell。

## 与现有代码的关系

| 关注点 | 位置 |
|---|---|
| 沙箱 | `App/Core/Sandbox.swift`（read-only / workspace-write / danger-full-access） |
| 工具 | `App/Local/LocalTools.swift`（全部过沙箱） |
| 执行 | `App/Local/LocalEngine.swift`（SSE + usage + 工具循环） |
| 队列 | `LocalStore.queue` + `interrupt()` |
| 状态展示 | `App/Views/LocalRuntimeView.swift` |

## 后续

1. `RemoteRuntime` 接 `dsh_client` 形状（HTTP+WS、`session/follow`）；
2. 工具协议 `ToolManifest/ToolResult` 统一 Swift 工具与未来的 MCP 工具；
3. Linux 若要做，必须先有可验证的 rootfs 与内核访问方案——在那之前保持 unsupported。
