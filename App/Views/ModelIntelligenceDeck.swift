import SwiftUI

/// 模型控制台：横向模型轨道、执行模式、权限、工具开关。
/// 每一条都接到真实配置上——不支持的模型不会显示成可用。
struct ModelIntelligenceDeck: View {
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var config: ModelConfigurationStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var scrollID: String?
    @State private var appeared = false
    @Namespace private var modeNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 参考片（/tmp/ref.mp4，1180×2556，内层实际 30fps：相邻两帧常常完全相同）量出来的三个数：
    /// 1. 入场：0.067s 列表还只有影子，0.100s 五行全出来，0.233s 稳定；
    ///    期间整排字往上走了约 20px（面板高度的 4%），没有缩放、没有旋转、没有斜向扫光；
    /// 2. 列表 → 胶囊的切换在 1.433s（列表最后一帧）到 1.567s（胶囊已成形）之间，
    ///    中间只有一帧半透明过渡，连收敛一起 0.27s；
    /// 3. 高光在条带顶部：紫条的逐行亮度 63 → 43（顶亮底暗），而同一帧面板底色的
    ///    166 → 173（基本平），所以那是 UI 的顶部镜面（90°），不是屏幕反光；
    ///    条带本身的颜色是 0° 横向渐变：#1B3D97 → #4E2D8D。
    private enum Measured {
        static let settle = Animation.spring(response: 0.32, dampingFraction: 0.82)
        /// 参考片里没有级联，留 20ms 只是不让整排同一帧闪出来。
        static let stagger = 0.02
        static let enterScale: CGFloat = 0.97
        /// 入场时整排往上滑的距离，按量到的 4% 面板高度取 5pt。
        static let enterRise: CGFloat = 5
        static let recedeScale: CGFloat = 0.94
        static let recedeOpacity: Double = 0.85
        static let accentLead = Color(red: 0.106, green: 0.239, blue: 0.592)  // #1B3D97
        static let accentTrail = Color(red: 0.306, green: 0.176, blue: 0.553) // #4E2D8D
    }

    private var models: [String] {
        let all = account.models.isEmpty ? ["deepseek-chat"] : account.models
        guard !query.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private var capability: ModelCapability { ModelCapability.forModel(config.model) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    rail
                    reasoning
                    executionMode
                    permission
                    tools
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("模型控制台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                appeared = true
                if account.models.isEmpty {
                    Task { await account.refreshModels() }
                }
                scrollID = config.model
            }
        }
    }

    // MARK: - Rail

    private var rail: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle("模型")
                Spacer()
                Text("\(models.count) 个可用")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DSH.Palette.tertiary)
            }

            searchField

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(models.enumerated()), id: \.element) { index, model in
                        card(model, index: index)
                            .id(model)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 6)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollID)
            .scrollIndicators(.hidden)
            .onChange(of: scrollID) { _, value in
                guard let value, value != config.model else { return }
                config.model = value
                Haptics.tap()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(DSH.Palette.tertiary)
            TextField("搜索模型", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(DSH.TypeScale.callout)
                .foregroundStyle(DSH.Palette.text)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DSH.Palette.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func card(_ model: String, index: Int) -> some View {
        let selected = model == config.model
        let cap = ModelCapability.forModel(model)

        return Button {
            config.model = model
            withAnimation(DSH.Motion.snap) { scrollID = model }
            Haptics.tap()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "cpu")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? DSH.Palette.accent : DSH.Palette.tertiary)
                    Spacer()
                    Text("DeepSeek")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(DSH.Palette.tertiary)
                }

                Text(model)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DSH.Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 4) {
                    chip(cap.supportsTools ? "工具" : "无工具", on: cap.supportsTools)
                    chip(cap.reasoningLevels.isEmpty ? "默认推理" : "推理", on: !cap.reasoningLevels.isEmpty)
                }
            }
            .padding(12)
            .frame(width: 158, height: 104, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? DSH.Palette.raised : DSH.Palette.surface)
            )
            // 选中底纹：量出来的 0° 横向渐变（深蓝 → 紫），压低不透明度让白字仍然够亮。
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Measured.accentLead, Measured.accentTrail],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(selected ? 0.55 : 0)
            )
            // 顶部镜面：沿上边缘一道 1pt 白线，往下淡出——这就是 90° 的那条高光。
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(selected ? 0.40 : 0.10),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.8
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? DSH.Palette.accent.opacity(0.45) : DSH.Palette.hairline, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            // 选中形变：选中的留在原位，其余缩小 6%、压到 85% 透明度——参考片里是别的行直接收起。
            .scaleEffect(appeared ? (selected ? 1.0 : Measured.recedeScale) : (reduceMotion ? 1.0 : Measured.enterScale))
            .offset(y: reduceMotion ? 0 : (appeared ? 0 : Measured.enterRise))
            .opacity(appeared ? (selected ? 1 : Measured.recedeOpacity) : 0)
            .animation(Fluid.Motion.respecting(reduceMotion, Measured.settle).delay(reduceMotion ? 0 : Double(index) * Measured.stagger), value: appeared)
            .animation(Fluid.Motion.respecting(reduceMotion, Measured.settle), value: selected)
        }
        .buttonStyle(.plain)
    }

    private func chip(_ text: String, on: Bool) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(on ? DSH.Palette.secondary : DSH.Palette.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(DSH.Palette.raised, in: Capsule())
    }

    // MARK: - Reasoning

    private var reasoning: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("推理强度")

            if capability.reasoningLevels.isEmpty {
                Text("\(config.model) 没有声明推理档位，请求里不会发送相关参数。")
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("该模型支持：\(capability.reasoningLevels.joined(separator: " / "))")
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.secondary)
            }
        }
    }

    // MARK: - Execution mode

    private var executionMode: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("执行模式")

            HStack(spacing: 6) {
                ForEach(ExecutionMode.allCases) { mode in
                    Button {
                        config.mode = mode
                        Haptics.tap()
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(config.mode == mode ? Color.white : DSH.Palette.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if config.mode == mode {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(DSH.Palette.accent)
                                        .matchedGeometryEffect(id: "modePill", in: modeNamespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(config.mode.summary + " · " + (config.mode.allowsTools ? "可调用工具" : "不调用工具") + (config.mode.allowsWrites ? " · 可写文件" : ""))
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.tertiary)

            if !capability.supportsTools {
                Label("\(config.model) 不支持函数调用，AGENT 模式的工具不会生效。", systemImage: "exclamationmark.triangle")
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.warning)
            }
        }
    }

    // MARK: - Permission

    private var permission: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("权限")

            VStack(spacing: 0) {
                ForEach(PermissionProfile.allCases) { profile in
                    Button {
                        config.permission = profile
                        Haptics.tap()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: config.permission == profile ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(config.permission == profile ? DSH.Palette.accent : DSH.Palette.tertiary)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(profile.title)
                                    .font(DSH.TypeScale.body)
                                    .foregroundStyle(DSH.Palette.text)
                                Text(profile.detail)
                                    .font(DSH.TypeScale.footnote)
                                    .foregroundStyle(DSH.Palette.tertiary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if profile != PermissionProfile.allCases.last {
                        Divider().overlay(DSH.Palette.hairline).padding(.leading, 40)
                    }
                }
            }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Tools

    private var tools: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("工具能力")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(ToolCapability.allCases) { tool in
                    toolCapsule(tool)
                }
            }

            Text("只有「文件 / 设备 / 系统 / 分析」接进了模型；其余是 App 内的工作台能力，模型无法调用，因此不可开启。")
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toolCapsule(_ tool: ToolCapability) -> some View {
        let on = config.enabledTools.contains(tool)
        let enabled = tool.wiredToModel

        return Button {
            guard enabled else { return }
            if on { config.enabledTools.remove(tool) } else { config.enabledTools.insert(tool) }
            Haptics.light()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: tool.symbol)
                    .font(.system(size: 12))
                Text(tool.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if !enabled {
                    Text("未接入")
                        .font(.system(size: 8))
                        .foregroundStyle(DSH.Palette.tertiary)
                }
            }
            .foregroundStyle(enabled ? (on ? DSH.Palette.text : DSH.Palette.secondary) : DSH.Palette.tertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                (on && enabled ? DSH.Palette.accent.opacity(0.18) : DSH.Palette.surface),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    on && enabled ? DSH.Palette.accent.opacity(0.5) : DSH.Palette.hairline,
                    lineWidth: 0.5
                )
            )
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Text(tool.note)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DSH.Palette.tertiary)
            .textCase(.uppercase)
            .tracking(1.1)
    }
}
