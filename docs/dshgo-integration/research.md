# DSH Go 研究（Phase 1）

日期：2026-11-18 · 参考：`ccch1mneyyy/dsh-Go`、`Anrylin/dsh-go-ios`

## 许可与使用边界

| 仓库 | 语言 | 许可 | 体积 |
|---|---|---|---|
| ccch1mneyyy/dsh-Go | Dart / Flutter | **AGPL-3.0** | 683 MB |
| Anrylin/dsh-go-ios | Dart / Flutter | **AGPL-3.0** | 14 MB |

**只取架构与协议结论，不复制任何代码、资源或品牌资产。** 我们的实现是 Swift 重写，
不引入 AGPL 代码，也不嵌入 Flutter 引擎。

## 读到的事实

来源：`docs/architecture.md`、`README-IOS.md`、`CHANGELOG-IOS.md`（逐条有提交号）。

### 分层

```
Flutter UI ──Riverpod──> dsh_client（纯 Dart，RPC/mux/事件）
      │                        │ HTTP + WS
      └ MethodChannel ─> 原生层（Kotlin / Swift）
                         runtime / phone / notify / files / media / voice / update
```

- **`dsh_client`** 是纯 Dart 的 DSH Web API 客户端，本机与远程共用，可单测；
  会话靠 `session/follow` 事件流，UI 折叠成 `ChatState`。
- **引擎桥 `/dsh-go/v1/*`**：插件 contributions / invoke / stream，App 只读渲染。
- **远程**：SSH 或 WebRTC/中继，复用同一个 `DshClient`。

### iOS 端（fork 的改动，均为真机或 CI 验证）

| 能力 | 状态 |
|---|---|
| 后台保活 | ✅ 内存生成 1 秒静音 WAV + `UIBackgroundModes=audio`，离开前台开、回前台关 |
| 灵动岛 / 实时活动 | ⚠️ 实现完成，但免费证书无法注册扩展 App ID，表现为黑胶囊，另出 `no-island` 分支 |
| 今日用量 | ✅ 按会话 × 本地日累加 `UsageChunk` |
| 侧边栏连接状态 | ✅ 有活连接显示「已连接」 |
| 抽屉手势 | ✅ 仅左缘 32px 起手，避免抢横滑 |
| 上一条提问 | ✅ 连续上翻 |
| Codemagic 构建 | ✅ 新增 |
| 本机引擎（nodejs-mobile） | ⚠️ 实验分支 `local-engine`，**未跑通** |

### Android 独有（iOS 没有、也不该假装有）

- PRoot Ubuntu 24.04 + Node 本机引擎；
- 无障碍服务、Shizuku、ADB 的手机操控；
- APK 自更新与安装器。

## 对我们的结论

1. **本机模式不可能是 Linux**：iOS 沙盒内没有 PRoot。我们继续用原生 Swift 工具，
   并明确写「没有任意子进程执行」。
2. **后台保活方案与我们已实现的一致**（静音 WAV + audio 模式），说明这条路是稳的；
   fork 自己也标注了 3–5%/小时耗电与审核风险，应保持默认关闭。
3. **实时活动受签名限制**：免费证书不可用。我们暂不做 Widget / Live Activity。
4. **协议优先级**：`dsh_client` 的 `session/follow` + `/dsh-go/v1/*` 桥是远程能力的
   真实入口；NcnsDSH 的远端适配层应按这个形状设计，而不是自创 REST。
5. **不要抄 Flutter 页面**：视觉由我们自己的 Liquid Glass 设计系统决定。
