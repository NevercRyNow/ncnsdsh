# dsh-Go 引擎与 Linux 移植：可行性评估

对象：`github.com/ccch1mneyyy/dsh-Go`，分支 `ios/shared-runtime-after-ohos`
（HEAD `4533645b20`：*fix(ios): the engine starts again on the shared host after the HarmonyOS merge*）。

## 1. 它实际是什么（读代码/文档得到的）

`docs/architecture.md` 的 iOS 段落写得很清楚：

```text
Flutter Dart ── MethodChannel ──> Swift（DshPlugin / EngineChannel）
      │                                  ├─ 同进程 NodeMobile + 专门生成的 runtime.zip
      │                                  ├─ 可选 iSH Linux guest（DshGuest.framework）
      │                                  ├─ CoreDevice / XCTest PhoneRunner 手机操控
      │                                  └─ WidgetKit 伙伴小组件、语音、可选宠物 PiP
      └──────── DshClient ── 127.0.0.1 本机引擎或远程 Host
```

也就是说：

- **“引擎重构”** = 把官方 DSH 引擎放进 iOS 进程内跑，靠的是 **NodeMobile**（iOS 版 Node）
  加一份构建时生成的 `runtime.zip`，再通过 `EngineChannel` 和 Flutter 通信。
- **“Linux 移植”** = **iSH**（x86 用户态模拟器）作为可选 guest 跑在 App 里，
  不是原生 Linux——iOS 不允许 fork/exec，也没有 rootfs。
- 宿主是 Flutter + Swift；我们这套是纯 SwiftUI。

## 2. 三个硬约束（不是难度问题，是能不能做的问题）

### 2.1 许可证

- `dsh-Go`：**AGPL-3.0**（`GET /repos/ccch1mneyyy/dsh-Go/license` → `AGPL-3.0`）。
- 本仓库：**MIT**。
- AGPL 是强 copyleft：把它的代码/衍生作品链进 App，整个 App 的发布就必须按 AGPL 开源，
  包括我们自己的 SwiftUI 代码；而 MIT 与 AGPL 不能“各留各的”。
- iSH 本体是 GPL-2.0，链路同理。

**这条只能由你决定**：要么把 NcnsDSH 整体改为 AGPL-3.0 并公开全部源码，
要么只做“协议层对接”（见 §3），不复制它们任何代码。

### 2.2 原生二进制

NodeMobile 是预编译的 iOS framework（不是 Swift Package），iSH 也是 framework。
接进 `project.yml` 需要：framework 二进制、Xcode 的 embed & sign 配置、
以及一份随包分发的 `runtime.zip`。这些在我这个环境里**无法构建或验证**——
这里没有 Xcode、没有模拟器，只有 GitHub Actions 的 macOS runner（且排队不稳定）。

### 2.3 运行验证

即便代码接上了，Node 引擎在 iOS 上的启动、sandbox 权限、后台保活、
以及 iSH guest 的可用性，都必须在真机上验证。我这边最多能出包和校验版本哈希。

## 3. 不碰许可证也能往前走的一步

现在这个 App 的本机引擎是 `App/Local/LocalEngine.swift`：**直连 DeepSeek API 的
最小 agent loop**（流式 + 三个文件工具），JS 片段走 `JavaScriptCore`，不是 Node。

可行的中间态：

1. 把引擎抽象成 `protocol HarnessEngine`（`stream(messages:model:…)` + 工具回调），
   现在的 `LocalEngine` 作为它的第一个实现；
2. 预留 `NodeEngine` 实现位（NodeMobile 接入后再填），UI 与工具层不动；
3. 真正的 DSH 引擎通信协议（HTTP + WS、`/dsh-go/v1/*`）按 dsh-Go 的**协议文档**
   自己实现客户端——协议不受 AGPL 传染，代码可以独立写。

这样今天就能落地 1，等许可证决定和 framework 到位再做 2。

## 4. 结论

- “把 dsh-Go 的引擎和 Linux 直接搬过来”：**在 MIT 仓库里做不到**，先卡在 AGPL；
  且需要预编译 framework 与真机验证，本环境不具备。
- 可以马上做：引擎抽象层（§3.1）；插件市场（已完成，见 2.19.0）。
- 需要你回答：**许可证要不要改成 AGPL-3.0**；以及是否接受随包分发 NodeMobile/iSH 的二进制。

## 5. 已做的第一段（clean-room，不涉及 AGPL）

按它公开的 `docs/design/bridge-contract.md`，在 Swift 里自己实现了桥客户端的第一段：

- `App/Runtime/DshBridge.swift`：`GET {host}/dsh-go/v1/capabilities`，
  解析 `{v, bridge, capabilities}`；`v != 1` 报不支持；404 且 `error.code == route-not-found`
  视为旧桥；401/403 先重试 Bearer，再如实报 token 被拒。
- `App/Views/DevicesView.swift`：连上主机后自动协商一次，显示
  「协议 v1 · bridge 0.4.0 · N 项能力」，失败显示具体原因并给重试。

这不是「移植它的代码」——协议是对外契约，客户端按契约独立实现；AGPL 的部分（引擎、
NodeMobile、iSH）仍然没有引入。
