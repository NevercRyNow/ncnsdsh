# NcnsDSH · Liquid Glass 设计研究简报

> 来源以 Apple 官方文档 / HIG 为主（含 2025-09-09 的 HIG 修订）。凡推断处标「推断」，无法核实处标「未核实」。

## 1. Liquid Glass 作为 API 到底是什么

一个动态材质：模糊背后内容、反射周围颜色与光、对触摸与指针实时响应。入口是 `.glassEffect(_:in:)`，默认用 `Glass.regular` + `Capsule`，`in:` 可换形状（如 `.rect(cornerRadius: 16)`）；`glassEffect` 会抓取视图 bounds，所以 padding 要加在它之前。[Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)

- 配置：`.regular` / `.clear` 两个变体；`.tint(_:)` 表强调；`.interactive()` 让自定义控件获得与系统按钮相同的触摸反应。官方示例即 `.glassEffect(.regular.tint(.orange).interactive())`。（同上）
- 组合与形变：`GlassEffectContainer(spacing:)` 让同一容器内的多个 glass 视图在转场时融合形状、互相 morph；`glassEffectID(_:in:)` 配 `@Namespace` 标记身份；`glassEffectTransition(.matchedGeometry / .materialize)` 选转场；`glassEffectUnion(id:namespace:)` 让不在同一布局容器里的视图合并成一个形状。（同上）
- 可用性：iOS / iPadOS / Mac Catalyst / macOS / tvOS / watchOS **26.0+**。[glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))、[Glass](https://developer.apple.com/documentation/swiftui/glass)
- 性能：Apple 说容器存在的理由之一就是「最佳渲染性能」，容器过多、容器外特效过多会掉性能。（Applying 一文）

## 2. HIG 的硬规则

**位置（最重要）**：HIG 把界面分成两层——Liquid Glass 是「功能层」，浮在内容层之上（tab bar、sidebar、toolbar）；「**Don't use Liquid Glass in the content layer**」，内容层（含 app 背景）应使用标准材质。唯一例外是 slider/toggle 这类瞬时交互控件在激活时短暂变成 glass。同时要求「use sparingly」，过度使用会分散对内容的注意。[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

**变体选择**：`regular` 会模糊并调整背景亮度以保证可读性，文字量大（alert、sidebar、popover）就该用它；`clear` 只用于漂浮在照片/视频等丰富媒体之上，且背景偏亮时要垫一层 **35% 不透明度的暗化层**，否则改用自带暗化的 AVKit 控件。（同上）

**层次与滚动**：减少自定义背景，否则会盖掉系统 scroll edge effect；内容滚到栏下时用 `scrollEdgeEffectStyle(_:for:)` 保可读；圆角要与容器同心（concentric）；**不要**把 glass 元素层层叠在彼此之上。[Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)

**动效**：要有目的、别为动而动；高频交互不要加动效；反馈动画要短要精确；**不要让人等动画放完才能操作**（可打断/可取消）；动效不能是唯一的信息通道，要配 haptic / audio。visionOS 还提醒周边视野的运动易致不适。[Motion](https://developer.apple.com/design/human-interface-guidelines/motion)

**排版**：iOS 正文默认 17pt、最小 11pt；只有用系统 text style 才自动吃到 Dynamic Type；自定义字体要自己实现 Dynamic Type 与 Bold Text。[Typography](https://developer.apple.com/design/human-interface-guidelines/typography)

**无障碍**：小于 17pt 需 4.5:1，≥18pt 或 bold 需 3:1，且 Increase Contrast 打开时要给更高对比的方案；Dynamic Type 目标支持放大到 **200%**（watchOS 140%），放大时不许截断、图标要跟着放大；每个图标都要有 accessibility label（VoiceOver）。[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

**两个系统开关的语义可直接映射成代码**：`accessibilityReduceTransparency` = 半透明背景**必须变不透明**；`accessibilityReduceMotion` = 避免大动画、尤其模拟三维的。[reduceTransparency](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency)、[reduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)

## 3. iOS 17 部署目标 + iOS 26 SDK：正确回退

**已核实**：`glassEffect` / `Glass` / `GlassEffectContainer` 全部标 26.0+，所以必须走 `if #available(iOS 26.0, *)`。更关键的是——用 iOS 26 SDK 构建时，**即使 deployment target 是 17**，App 在 iOS 26 设备上也会自动套用新设计（标准组件自动换观感），这是由 SDK 决定的，不是 deployment target。`UIDesignRequiresCompatibility = YES` 是官方给的**临时**「旧观感」开关，默认 NO，且系统在 **iOS 27+ 起直接忽略该键**。[UIDesignRequiresCompatibility](https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility)

**推断（非 Apple 原文的推荐结构）**：写一个 `GlassSurface` ViewModifier，把形状/圆角/tint 作为参数，内部 `if #available(iOS 26.0, *)` 用 `.glassEffect(.regular.tint(t))`，else 用 `.background(.regularMaterial, in: shape)` 再加一圈细描边；调用点零分支。之所以说这个 fallback 合法，依据是 HIG 明确写 iOS/iPadOS 在 26 上「继续提供」ultra-thin / thin / regular / thick 四种标准材质 —— 退回 `.regularMaterial` 是 Apple 认可的语义，不是自创。（Materials 页）

**未核实**：Apple 没有公开任何 glass → material 的官方映射表或 fallback 示例。

## 4. 可借鉴的交互模式（学机制，不抄皮）

- **morphing dock**：tab bar HIG 写了「带附属件的 tab bar（如 Music 的 MiniPlayer）可随滚动最小化、把附属件内联，点 tab 或滚到顶恢复」——[Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars)。机制上就是「共享 ID 的形状融合」，正好对应 `GlassEffectContainer` + `glassEffectID`。Music 的 mini→full 展开是否已用这套新 API：未核实。
- **sheet 变全屏**：别自己写拖拽。HIG 的 detents 就是答案——`medium` ≈ 半屏、`large` = 全高，grabber 可拖动也可点击循环，且对 VoiceOver 可操作，并支持渐进披露。[Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)、[presentationDetents](https://developer.apple.com/documentation/swiftui/view/presentationdetents(_:))。Maps 式多档位与该描述一致，但 Maps 内部实现未公开（未核实）。
- **TV**：tvOS 用 parallax + elevation 表达焦点，HIG 要求优先用系统焦点效果，万不得已才自定义。[Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection)
- **visionOS**：ornament 是「平行于窗口、略沿 z 轴前置」的浮动层，HIG 直接点名 **Music 用 ornament 放 Now Playing 控件**，且宽度不得超过窗口。[Ornaments](https://developer.apple.com/design/human-interface-guidelines/ornaments)
- **状态球**：没有可直接对照的 Apple 先例。推断做法：形状固定、只改 tint 与内部符号（`symbolEffect`），Reduce Motion 时降级为淡入淡出，并始终配一条文字或 haptic 的第二通道。

## 5. 坑

1. **过糊**：`clear` 用在亮背景上不加深色层 → 文字直接不可读（HIG 要求 35% 暗化）。
2. **glass 套 glass**：Adopting 明确要求不要叠，嵌套同时毁层次与性能。
3. **内容层误用**：正文卡片上 glass 会与「功能层」信号打架，对比度也不可控。
4. **忘了 Reduce Transparency / Increase Contrast**：不透明化后依赖模糊遮罩的布局会露馅，对比度要重测。
5. **性能**：成本主要在容器数量与同屏特效数量；旧设备上连续 morph 最贵——这句是**推断**，Apple 只说了「限制同屏特效」。
6. **container spacing 大于内部 stack spacing** → 静止时形状就糊在一起，这是文档点名的坑。

---

首发时间线：Liquid Glass 于 2025-06-09 随新设计语言公布。[Apple Newsroom](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
