# 无障碍审计（第一轮）

目标是两条：VoiceOver 能把每个控件读明白；正文跟随 Dynamic Type。
这一轮只做能**读代码验证**的部分，真机读屏与放大字号仍需人工确认。

## 已做

### VoiceOver 标签

| 位置 | 控件 | 标签 |
| --- | --- | --- |
| ChatView 工具栏 | 工作台图标 | 打开工作台 |
| WebScreen | 后退 / 前进 / 更多 | 后退 / 前进 / 更多操作 |
| LiquidDock（已下线） | — | — |
| 工作台 | 专注模式 / 退出专注 / 关闭 | 已有 |
| 关于 | 版本胶囊 | 「版本 x，构建号 y」+ 轻点提示 |
| 首页 | 远程连接图标 | 远程主机已连接 |
| 插件市场 | 安装 / 复制包名 | 有可见文字，读屏直接用文字 |

### Dynamic Type

把「段落型文字」（有 `fixedSize(horizontal: false, vertical: true)` 的那些）从写死字号换成
语义字号，跟随系统字号：

- `BuildTutorialView`：正文 13 → `.footnote`，说明 12 → `.caption`
- `BuildView`：三处说明 12 → `.caption`
- `ChatView` / `LocalChatView`：正文 14/13 → `.footnote`

## 还没做（下一轮）

1. **图标按钮**全量：`Image(systemName:)` 共 95 处，只有一部分有标签；列表行里的
   图标是装饰，应标 `.accessibilityHidden(true)`，避免读屏把「cpu」「folder」念出来。
2. **对比度**：浅色模式没有在真机上量过，`.tertiary` 在浅色下是黑 44%，小字可能不够 4.5:1。
3. **放大字号**：把系统字号调到 200% 后，卡片与市场行的截断情况没有验证。
4. **Reduce Motion**：新页面已接，老页面（构建、插件、连接）里的 `withAnimation` 仍是无条件播放。
5. **VoiceOver 顺序**：首页 hero 里的三个计数目前是三个独立元素，应合并成一句
   「运行中 2，构建 5，插件 3」。
