# NcnsDSH 2.0 · 研究（Phase 0）

日期：2026-11-18 · 版本基线：0.4.0 (5)

## 方法

拉取 7 个候选仓库的源码（`codeload` tarball），只读 Swift 源码，不复制实现。
两个仓库（GetStream/awesome-liquid-glass、vscarpenter/gsd-iosapp）因体积/网络未能下载，
先用其余五个建立结论；这两个后续用 GitHub API 逐文件补齐，不阻塞设计。

| 仓库 | 许可证 | 抓到的 Swift 文件 | 结论 |
|---|---|---|---|
| pchelnikov/liquid-glass-examples | MIT | 42 | 玻璃 API 的用法字典：容器、形变、按钮、徽章 |
| shio-sh/shio | MIT | 148 | 产品级架构：主题 token、集中触觉、配对、项目、Live Activity |
| Aeastr/SettingsKit | MIT | — | 设置页的树形 DSL + 样式 + 搜索索引 |
| mertozseven/LiquidGlassSwiftUI | 无 | 7 | 动作按钮组的玻璃容器示例 |
| veersr9/Liquid-Glass-Reference | 无 | 9 | 仅作视觉参考，不借鉴代码 |
| GetStream/awesome-liquid-glass | — | 未下载 | 列表型资源，后续补 |
| vscarpenter/gsd-iosapp | — | 未下载 | 后续补 |

## 逐个项目

### pchelnikov/liquid-glass-examples（MIT）

- **ExpandablePlayerExample**：用 `GlassEffectContainer(spacing: 24)` 包住一个圆按钮与一块面板，
  两者共享 `glassEffectID("player", in: namespace)`，点击时 `withAnimation(reduceMotion ? nil : .spring(0.5, 0.82))`
  在「圆 → 面板」之间形变。**这正是我们 mini bar 展开该用的写法**。
- **ContainersExample**：`GlassEffectContainer(spacing: blendingDistance)` 的 spacing 就是融合距离。
- **ButtonStylesExample**：`.buttonStyle(.glass)` / `.glassProminent` / `.buttonBorderShape(.circle)`。
- **FloatingActionsExample / GlassBadgesExample**：多个玻璃件之间 `spacing: 8–12`，靠近自然融合。
- 可取：容器包裹 + 共享 id 形变 + Reduce Motion 三元表达式。
- 不取：它把玻璃铺满整屏的背景，和「玻璃只给 chrome」相冲突。

### mertozseven/LiquidGlassSwiftUI（无许可证）

- `ActionButtonsView` 用 `GlassEffectContainer(spacing: 20)` 包一组动作按钮，
  `ExpandedActionsView` 在展开时增删按钮，靠容器统一融合。
- 只读结构，代码不采用（无许可证）。

### shio-sh/shio（MIT，148 文件）

产品级参考，结构最值得学：

- `Shio/Core/Design/ShioTheme.swift`：一套 **light/dark 双值 token**（`Color(light:dark:)`），
  背景/表面/文字三级/线/状态色各自成对；状态色在浅色下加深保证对比度。
- `Shio/Core/Haptics/Haptics.swift`：集中式触觉，`UISelectionFeedbackGenerator` +
  `prepare()` 预热，`tap / light / medium / notifySuccess / notifyWarning / notifyError` 六档，
  全局一处可静音。**我们当前的 Haptics 是散在 Theme.swift 里的三个函数，要按这个重构**。
- `Shio/Core/Design/ProjectAvatar.swift`、`ProjectIdentity.swift`：项目身份（图标/配色）独立成类型。
- `Shio/Core/Pairing/PairingService.swift`、`LocalNetworkPrimer.swift`：配对与本地网络权限的完整处理。
- `Shio/Core/LiveActivities/*`、`ShioWidgets/*`：小组件与灵动岛的真实实现，正好补我们的空白。
- 结论：采用它的「Core 层不放 UI、主题双值 token、触觉集中」三条纪律。

### Aeastr/SettingsKit（MIT）

- 结构：`Components/{SettingsView, SettingsGroup, CustomSettingsGroup, SettingsIntroduction}`、
  `Styles/{SettingsStyle, SidebarSettingsStyle, SingleColumnSettingsStyle}`、
  `Search/DefaultSettingsSearch`、`Indexing/{SettingsContent, SettingsNode, …}`。
- 模式：设置页是**结果构建的树**（`SettingsContentBuilder`），每个节点可被索引，
  搜索直接在索引上过滤；样式决定 iPhone 单列还是 iPad 侧栏。
- 结论：我们的设置页现在是手写卡片堆，PHASE 10 应按这个思路改成
  「声明式分组 + 索引 + 搜索」，但**不引入这个包**（自己写轻量版，避免依赖）。

## 横向结论（直接影响设计系统）

1. **玻璃的三种正确用法**：单个交互控件（`.glassEffect(.regular.interactive())`）、
   成组控件的容器（`GlassEffectContainer(spacing:)`）、跨状态形变（共享 `glassEffectID` + namespace）。
2. **玻璃不做内容背景**——五个项目里做得最好看的 shio，正文区全是实色与细线。
3. **动效一律走 spring，且用 Reduce Motion 三元式降级**；没有常驻动画。
4. **触觉集中管理并预热**，不是每个按钮各自 `UIImpactFeedbackGenerator()`。
5. **主题 token 双值**（light/dark 成对），状态色在浅色下加深。
6. **设置/导航用声明式结构 + 索引**，不手写重复布局。

## 我们不采纳的

- 任何项目里的品牌资产、图标、文案。
- pchelnikov 的整屏玻璃背景、mertozseven/veersr9 的代码（无许可证）。
- 引入 SettingsKit 作为依赖（会带来自己的样式体系，和我们的设计系统冲突）。

## 下一步

按 `design-system.md` 落地 token 与触觉层，再按 `roadmap.md` 推进首页、导航、会话、工作台。
