# NcnsDSH 2.0 · 设计系统

目标：像 Apple 自带工具，而不是 AI 聊天产品。**内容优先，chrome 其次，玻璃只属于 chrome。**

## 1. 颜色

深色为默认画布 `#000000`；浅色是 `#F5F4F0`（呼应 shio 的双值 token 思路）。

| Token | 深色 | 浅色 | 用途 |
|---|---|---|---|
| `canvas` | `#000000` | `#F5F4F0` | 页面底 |
| `surface` | `white 6%` | `black 4%` | 卡片、行、输入底座 |
| `raised` | `white 10%` | `black 7%` | 选中行、悬停 |
| `hairline` | `white 12%` | `black 10%` | 0.5pt 分隔线 |
| `text` | `white 96%` | `#0E0E10` | 正文与标题 |
| `secondary` | `white 60%` | `#636368` | 次要信息 |
| `tertiary` | `white 36%` | `#8E8E93` | 元数据、时间 |
| `accent` | `#0A84FF` | `#0A84FF` | 关键操作、当前选中 |
| `success` | `#3FB868` | `#1F9A4E` | 完成态 |
| `warning` | `#E0913A` | `#B9741A` | 待审批、降级 |
| `danger` | `#E0584F` | `#C0413A` | 失败、危险操作 |

规则：

- **一屏只有一处实心 accent**，其余用 accent 10–15% 的底或描边。
- 状态色只出现在状态点、图标、细描边；不做满屏彩色标签。
- 浅色下状态色加深（对比度 ≥ 4.5:1）。

## 2. 排版

全部使用 `Font.system(_ style:)`，随 Dynamic Type 缩放，禁止写死 `.system(size:)` 作为正文。

| 层级 | TextStyle | 用途 |
|---|---|---|
| `display` | `.largeTitle` bold | 首页大标题（仅一处） |
| `title` | `.title2` semibold | 分组标题、详情页标题 |
| `headline` | `.headline` | 行标题、卡片标题 |
| `body` | `.body` | 正文、消息 |
| `callout` | `.callout` | 次要正文 |
| `footnote` | `.footnote` | 说明、元信息 |
| `caption` | `.caption2` + `monospacedDigit` | 时间、计数、路径 |

数字（token 计数、百分比、耗时）一律 `monospacedDigit`，避免抖动。

## 3. 间距 / 圆角

- 间距阶：4 / 8 / 12 / 16 / 20 / 24 / 32 / 44。
- 圆角：**12**（卡片、输入、列表块）/ 8（小控件、图标底）/ 22（sheet）/ full（胶囊）。
- 行高：标准行 44–52pt；列表内边距 16；分组间距 24。

## 4. 材质与玻璃

| 场景 | 用法 |
|---|---|
| 导航栏 / Tab bar | 系统自带（iOS 26 自动玻璃），不自己叠 |
| 浮动 Dock / mini bar | `.glassEffect(.regular.interactive(), in: .capsule)`，包在 `GlassEffectContainer` |
| 工具栏成组按钮 | `GlassEffectContainer(spacing: 8–12)` + `.buttonStyle(.glass)` |
| 弹出面板 / 审批 | `.regularMaterial` 或玻璃 + `.presentationDetents` |
| 卡片 / 行 / 内容 | **实色 surface + hairline**，不用玻璃 |

形变：

```swift
@Namespace private var ns
GlassEffectContainer(spacing: 16) {
    if expanded {
        panel.glassEffect(.regular, in: .rect(cornerRadius: 24)).glassEffectID("dock", in: ns)
    } else {
        capsule.glassEffect(.regular.interactive(), in: .capsule).glassEffectID("dock", in: ns)
    }
}
```

规范：

1. 玻璃只出现在导航、工具栏、浮动控件、弹出面板。
2. 相邻玻璃件放同一个 `GlassEffectContainer`，spacing = 融合距离。
3. 只有可点的控件加 `.interactive()`。
4. 玻璃不压正文；正文区要么实色，要么加 scrim。
5. 所有玻璃在 `Reduce Transparency` 下退化为 `.regularMaterial` 不透明面板。
6. 兼容：`#if compiler(>=6.2)` + `#available(iOS 26)`，否则 `.ultraThinMaterial`。

## 5. 动效

| 名称 | 曲线 | 用途 |
|---|---|---|
| `snap` | `.spring(response: 0.28, dampingFraction: 0.86)` | 按压、选中、开关 |
| `flow` | `.spring(response: 0.42, dampingFraction: 0.90)` | 展开/收起、布局变化、形变 |
| `fade` | `.easeOut(duration: 0.18)` | 透明度、高光 |

- 阻尼 ≥ 0.85；不做果冻回弹。
- 所有动画 `Reduce Motion` 下降级为 `.opacity` 或 nil。
- 不用常驻循环动画装饰；只有真实状态（运行中/等待）才有呼吸或流光。
- 列表插入用 `.opacity + .offset(y: 8)`，删除用 `.opacity`。

## 6. 触觉

集中到 `Core/Haptics.swift`，六档，`prepare()` 预热：

| API | 触发 |
|---|---|
| `tap()` | 离散控件、选择器、Tab 切换 |
| `light()` | 提交类操作（保存、发送） |
| `medium()` | 连接成功/断开、面板收放 |
| `notifySuccess()` | 构建成功、登录成功 |
| `notifyWarning()` | 待审批、降级连接 |
| `notifyError()` | 失败、鉴权错误 |

禁止每个按钮都震动；同一动作 300ms 内不重复触发。

## 7. 图标

- 只用 SF Symbols，`weight` 跟随文字层级（正文 `.regular`，强调 `.semibold`）。
- 状态变化用 `symbolEffect(.bounce/.variableColor)`，不换图标做假动画。
- 禁止机器人、星星、魔法棒等 AI 隐喻。

## 8. 空状态

每个模块都必须有：首次使用 / 无数据 / 搜索无结果 / 加载 / 网络错误 / 权限不足 / 设备离线 / 成功。
每类空状态至少给一个真实操作入口（新建、重试、去设置），不允许纯插画。

## 9. 禁止清单

紫色渐变背景、发光边框、满屏玻璃、每块都是卡片、夸张标题、彩色标签墙、
装饰性按钮、无意义动画、假运行状态、假数据冒充真实数据。
