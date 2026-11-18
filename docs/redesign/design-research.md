# Fluid Intelligence · 设计方向与实施落点

输入：Apple 官方文档（HIG / Liquid Glass / Motion / Typography / Accessibility）与 7 个开源实现的
实际代码审计。完整的引用式简报见 [`liquid-glass-brief.md`](liquid-glass-brief.md)。

## 0. 三条硬规则（研究结果直接改写了原方案）

1. **玻璃是功能层材质，不是卡片皮肤。**
   HIG 原文：*Don't use Liquid Glass in the content layer*。tab bar、sidebar、toolbar、
   浮动控件、弹出层用玻璃；正文、列表、终端、Diff、About 用标准材质或实色。
   → 原计划里「About 用玻璃卡片」「列表套玻璃」全部作废，改为实色 + 细线 + 排版。

2. **用 iOS 26 SDK 构建 ⇒ iOS 26 设备自动得到新观感，`#available` 只影响 17–25。**
   `UIDesignRequiresCompatibility` 只是临时开关，iOS 27 起被忽略。
   → 不能再把 iOS 17 当「降级路径」：两套观感都必须是正式设计，
   所以 token 必须是真正的动态色（`UIColor { trait in … }`），而不是「深色 + 反相」。

3. **两个无障碍开关是语义，不是选项。**
   Reduce Transparency ⇒ 半透明必须变成不透明；Reduce Motion ⇒ 去掉位移/缩放/三维，只留淡入。
   → 所有新组件默认带上这两个分支，不做事后补丁。

## 1. 三套方向

### A. Quiet Instrument（精密仪器）

- 色彩：石墨 + 单一冰蓝强调，几乎不渐变。
- 材质：无玻璃，全部实色 + 0.5pt 细线；只在下拉菜单和浮动工具条上用材质。
- 字体：大量等宽数字与 11pt 技术字号，Tabular 对齐。
- 构图：网格化，左侧标号 + 右侧数据，像 macOS 的「系统信息」。
- 动效：极短（90–180ms），主要是透明度与 1–2pt 位移。
- 优势：密度高、专业、长时间看不累；最贴合「开发工作站」。
- 风险：静态时偏冷，品牌辨识度弱，容易变成「好看的设置页」。

### B. Fluid Architecture（流体建筑）

- 色彩：石墨底 + 冰蓝/薄荷做状态，色只出现在「正在发生的事」上。
- 材质：功能层用真玻璃（`GlassEffectContainer` + `glassEffectID`），内容层实色。
- 字体：Display 用 rounded，技术内容用 mono；数字显式 tabular。
- 构图：以 Dock 和工作台为核心的空间构图，页面切换走共享元素。
- 动效：分目的的弹簧（按压 0.12s / 选择 0.18s / 面板 0.34s / Dock 0.40s / 空间 0.46s）。
- 优势：名字（Fluid Intelligence）与交互一致；Dock / 工作台 / 状态球能形成记忆点。
- 风险：动效预算高，容易过度；旧设备上连续 morph 最贵。

### C. Developer Atelier（开发者工坊）

- 色彩：暖灰底 + 纸感 + 单一强调色。
- 材质：纤维纹理、纸张阴影，几乎无玻璃。
- 字体：衬线标题 + 等宽正文的编辑式排版。
- 构图：杂志式大留白、单栏长文。
- 动效：翻页/纸张物理感。
- 优势：气质独特，与所有 AI 工具都不同。
- 风险：与「终端/工具执行」的冷峻能力冲突；纸感需要纹理资源，性能和一致性都难保证。

## 2. 选择：B 的骨架 + A 的纪律

**空间与导航按 B 做，排版与数据按 A 做。** 理由：

- 产品名就是 Fluid Intelligence，Dock → 工作台 → 会话的连续形变是唯一能把「流体」讲清楚的地方；
  把这套动效去掉，App 就退回成一个功能齐全的聊天客户端。
- 但 B 的风险全在「内容也动、也玻璃」。A 的纪律正好补上：内容层实色、数字等宽、动效只在状态变化处。
- 不选 C：纸张质感与「正在执行命令」的状态表达天然打架，而且要引入纹理资源。

**具体的落点：**

| 层 | 用什么 | 依据 |
| --- | --- | --- |
| Dock / 浮动控制 / 状态球 / 弹出面板 | `Glass`（iOS 26）/ `regularMaterial`（17–25） | HIG 功能层 |
| 列表 / 卡片 / 终端 / Diff / About | `Fluid.Palette.graphite` + 0.5pt 细线 | HIG 内容层禁用玻璃 |
| 强调色 | 冰蓝，只给当前状态和主操作 | 克制的强调色 |
| 状态色 | mint 正常 / amber 等待 / coral 失败 | 语义色不一色多用 |
| 动效 | 5 个弹簧 + 1 个 state ease，按目的取 | 指令 5.3 的区间 |

## 3. 分阶段落点（每一项都能被构建验证）

| 阶段 | 交付 | 文件 |
| --- | --- | --- |
| 3 Design System | 动态色 token、5 档 Motion、内容表面、Reduce Transparency/Motion 分支 | `DesignSystem/Fluid.swift` ✅ 2.15.0 |
| 3b Gallery | 一个只在 Debug 出现的组件画廊，检查材质/状态/深浅色 | `Views/DesignGalleryView.swift` |
| 4 Dock | 用 `GlassEffectContainer` 做悬浮 Dock，选中区用 `matchedGeometryEffect` 滑过去 | `Views/LiquidDock.swift` + `MainShell.swift` |
| 4 Core | Intelligence Core 由 `RuntimeManager` + 会话运行状态驱动，9 个状态 | `Views/IntelligenceCore.swift` |
| 5 Workspace | 工作台三态（compact/expanded/fullscreen），手势跟手 + 速度吸附 | `Workbench/WorkbenchView.swift` |
| 6 Model | Model Rail 并入新 token（已量出的 0.17s 入场 / 90° 顶部高光保留），Reasoning/Capability 分栏 | `Views/ModelIntelligenceDeck.swift` |
| 7 About/Settings | About 已重做；Settings 按分区重排 | `Views/AboutView.swift` ✅ / `Views/SettingsView.swift` |
| 8 验收 | 每次 push 由 macOS runner 构建；下载 IPA 校验 Info.plist 与 SHA256 | `.github/workflows/ios.yml` |

## 4. 开源实现审计（能不能拿）

| 仓库 | 结论 | 理由 |
| --- | --- | --- |
| Polarizz/Gelatin | 可集成 | MIT，iOS 16，零依赖；纯 SwiftUI 的跟手形变，可叠在真玻璃上 |
| Czajnikowski/GlassEffect | 可集成 | MIT，正好 iOS 17；`layerEffect` + 法线贴图做折射，单文件修饰器 |
| AndreFrelicot/paper-shaders-swift | 可集成 | Apache-2.0（须保留 NOTICE），iOS 15；工程化的 shader 管线比效果本身值钱 |
| devzahirul/AppleMapsSheet | 可集成 | MIT，iOS 14；但多数场景 `presentationDetents` 已够 |
| InsaneArts/shaderskit | 仅作参考 | MIT，但 199 个组件 + 生成代码，整包太重；只值单摘 GlassGlow 的边缘光做法 |
| GetStream/awesome-liquid-glass | 仅作参考 | 无 LICENSE、无工程，只有 `.glassEffect()` 的一行示例 |
| NDCSwift/Animations_SwiftUI | 不适用 | 无 LICENSE，iOS 18 起，教学 demo |

**本阶段不引入任何第三方依赖**：`project.yml` 里没有 package 声明，About 的致谢也照这个事实写。
上面四个「可集成」留作后续按需引入，引入时必须补 NOTICE 与致谢。

## 5. 引用

- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [Materials — HIG](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Motion — HIG](https://developer.apple.com/design/human-interface-guidelines/motion)
- [Accessibility — HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [reduceTransparency](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency)
- [UIDesignRequiresCompatibility](https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility)
- [Sheets — HIG](https://developer.apple.com/design/human-interface-guidelines/sheets)
- [Ornaments — HIG](https://developer.apple.com/design/human-interface-guidelines/ornaments)
