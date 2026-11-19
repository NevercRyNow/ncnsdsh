import SwiftUI

/// 首页：Command Center。状态、快捷操作、最近项目、活动，按信息层次排布，不做满屏卡片。
struct HomeView: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var local: LocalStore
    @EnvironmentObject private var store: HostStore
    @EnvironmentObject private var build: BuildStore
    @EnvironmentObject private var plugins: PluginStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var settings: SettingsStore

    /// 一个 sheet 入口，避免同一层挂四个 .sheet(isPresented:) 互相抢。
    private enum Panel: String, Identifiable {
        case build, automation, workbench, engine
        var id: String { rawValue }
    }

    @State private var panel: Panel?

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    quickActions
                    currentSession
                    projectsShelf
                    activityList
                }
                .padding(.horizontal, DSH.Inset.gutter)
                .padding(.top, 6)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                RouteDestination(route: route)
            }
            .sheet(item: $panel) { panel in
                switch panel {
                case .build:
                    BuildView()
                case .automation:
                    ScheduleView().environmentObject(demo)
                case .workbench:
                    WorkbenchView(sessionID: nil)
                        .presentationDetents([.height(280), .medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackground(Fluid.Palette.obsidian)
                case .engine:
                    EngineConsoleView()
                }
            }
        }
    }

    // MARK: - Hero

    /// 顶部一块：品牌 + 环境、智能核心、三个计数。原来是三条独立的横条，
    /// 首屏被切成三段，信息权重拉不开。
    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            HStack(alignment: .center, spacing: 14) {
                IntelligenceCore(state: coreState, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(coreState.phase.title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Fluid.Palette.text)
                    Text(coreState.detail)
                        .font(Fluid.Typography.caption)
                        .foregroundStyle(Fluid.Palette.mist)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if coreState.remote {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Fluid.Palette.iceBlue)
                        .accessibilityLabel("远程主机已连接")
                }
            }

            Rectangle()
                .fill(Fluid.Palette.hairline)
                .frame(height: 0.5)

            HStack(spacing: 0) {
                metric("\(demo.runningCount)", "运行中", tint: Fluid.Palette.iceBlue)
                separator
                metric("\(build.recent.count)", "构建", tint: Fluid.Palette.mist)
                separator
                metric("\(plugins.installed.count)", "插件", tint: Fluid.Palette.mist)
            }
            // 读屏念一句「运行中 2，构建 5，插件 3」，而不是六个独立数字和标签。
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("运行中 \(demo.runningCount)，构建 \(build.recent.count)，插件 \(plugins.installed.count)")
        }
        .padding(16)
        .fluidSurface(cornerRadius: Fluid.Shape.panel)
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            BrandMark(size: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text("NcnsDSH")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DSH.Palette.text)
                Text(workspaceLine)
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Circle()
                    .fill(store.current == nil ? DSH.Palette.tertiary : DSH.Palette.success)
                    .frame(width: 6, height: 6)
                Text(store.current == nil ? "未连接" : "在线")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSH.Palette.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(DSH.Palette.surface, in: Capsule())
            .onTapGesture { router.tab = .more }
        }
    }

    // MARK: - Intelligence Core

    /// 六种状态的推导写在 `CoreState.derive`，这里只负责取数据。
    private var coreState: CoreState {
        CoreState.derive(demo: demo, remote: store.current != nil)
    }

    private var workspaceLine: String {
        if let host = store.current { return host.displayName }
        if account.isSignedIn { return "本机模式 · \(account.selectedModel)" }
        return "本机模式"
    }

    // MARK: - Status

    private var separator: some View {
        Rectangle()
            .fill(DSH.Palette.hairline)
            .frame(width: 0.5, height: 24)
    }

    private func metric(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.title3, design: .default).weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(DSH.TypeScale.caption)
                .foregroundStyle(DSH.Palette.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("快捷操作")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                // 配了 API Key 就开真实会话（LocalStore + LocalEngine）；
                // 没配才落到演示会话，演示会话的回复是脚本，不是模型生成的。
                action("新建会话", "square.and.pencil") {
                    // 设置里选了「内置引擎」就直接走引擎那条线，不再开网页也不再假装回复。
                    if settings.engineChoice == .embedded {
                        panel = .engine
                        Task { await EngineLauncher.shared.start(workspace: AppFiles.workspace) }
                        return
                    }
                    if !account.key.isEmpty {
                        let id = local.createSession(model: account.selectedModel)
                        router.open(.localSession(id))
                    } else {
                        demo.newSession()
                        if let id = demo.activeSessionID { router.open(.session(id)) }
                    }
                }
                // 工作台三档：小卡 / 半屏 / 全屏，靠系统 detents 与拖拽手势，
                // 不自己算逐帧位移（自己算的那套在玻璃容器里会卡）。
                action("终端", "terminal") {
                    panel = .workbench
                }
                action("文件", "folder") {
                    panel = .workbench
                }
                action("构建", "hammer") {
                    panel = .build
                }
                action("设备", "desktopcomputer") {
                    router.open(.devices)
                }
                action("自动化", "clock.arrow.circlepath") {
                    panel = .automation
                }
            }
        }
    }

    private func action(_ title: String, _ symbol: String, perform: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            perform()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(DSH.Palette.text)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSH.Palette.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: DSH.Radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current session

    @ViewBuilder
    private var currentSession: some View {
        // 之前这里要求「必须连着远端主机」，本机模式下首页永远不会出现「继续上次」。
        // 会话本来就是 App 自己的状态，跟有没有远端无关。
        if let session = demo.heroSession {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle(session.isRunning ? "正在运行" : "继续上次")

                Button {
                    Haptics.light()
                    router.open(.session(session.id))
                } label: {
                    HStack(spacing: 12) {
                        RemoteArtwork(
                            seed: session.title,
                            github: ProjectMeta.githubSlug(for: session.workspace),
                            cornerRadius: 10
                        )
                        .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.title)
                                .font(DSH.TypeScale.headline)
                                .foregroundStyle(DSH.Palette.text)
                                .lineLimit(1)
                            Text("\(session.workspace) · \(session.relativeTime)")
                                .font(DSH.TypeScale.footnote)
                                .foregroundStyle(DSH.Palette.tertiary)
                                .lineLimit(1)

                            if session.isRunning {
                                ProgressLine(progress: session.progress)
                                    .frame(width: 140)
                                    .padding(.top, 2)
                            }
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DSH.Palette.tertiary)
                    }
                    .padding(12)
                    .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: DSH.Radius.card, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else if let first = local.recent.first {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("继续上次")
                Button {
                    Haptics.light()
                    router.open(.localSession(first.id))
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DSH.Palette.success)
                            .frame(width: 52, height: 52)
                            .background(DSH.Palette.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(first.title)
                                .font(DSH.TypeScale.headline)
                                .foregroundStyle(DSH.Palette.text)
                                .lineLimit(1)
                            Text(first.preview)
                                .font(DSH.TypeScale.footnote)
                                .foregroundStyle(DSH.Palette.tertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DSH.Palette.tertiary)
                    }
                    .padding(12)
                    .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: DSH.Radius.card, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Projects

    private var projectsShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("项目")
                Spacer()
                Button("全部") {
                    Haptics.tap()
                    router.tab = .projects
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSH.Palette.accent)
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(demo.workspaces) { workspace in
                        NavigationLink(value: Route.project(workspace.id)) {
                            VStack(alignment: .leading, spacing: 8) {
                                RemoteArtwork(
                                    seed: workspace.name,
                                    github: ProjectMeta.githubSlug(for: workspace.name),
                                    cornerRadius: DSH.Radius.card
                                )
                                .frame(width: 150, height: 96)

                                HStack(spacing: 5) {
                                    Text(workspace.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(DSH.Palette.text)
                                        .lineLimit(1)
                                    if workspace.running > 0 {
                                        Circle()
                                            .fill(DSH.Palette.accent)
                                            .frame(width: 5, height: 5)
                                    }
                                }
                                Text("\(workspace.total) 个会话")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DSH.Palette.tertiary)
                            }
                            .frame(width: 150)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                Haptics.tap()
                                router.open(.project(workspace.id))
                            } label: {
                                Label("打开", systemImage: "arrow.up.forward.square")
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Activity

    private var activityItems: [ActivityItem] {
        var items: [ActivityItem] = []

        for record in build.recent.prefix(3) {
            items.append(
                ActivityItem(
                    id: "build-" + record.tag,
                    title: "构建完成",
                    detail: record.name,
                    date: record.date,
                    symbol: "hammer",
                    tint: DSH.Palette.accent
                )
            )
        }

        for session in local.recent.prefix(2) {
            items.append(
                ActivityItem(
                    id: "local-" + session.id.uuidString,
                    title: "本机会话更新",
                    detail: session.title,
                    date: session.updatedAt,
                    symbol: "cpu",
                    tint: DSH.Palette.success
                )
            )
        }

        for session in demo.sessions.prefix(3) {
            items.append(
                ActivityItem(
                    id: "remote-" + session.id.uuidString,
                    title: session.isRunning ? "会话运行中" : "会话活动",
                    detail: session.title,
                    date: session.lastActivity,
                    symbol: session.isRunning ? "bolt.horizontal" : "bubble.left",
                    tint: session.isRunning ? DSH.Palette.accent : DSH.Palette.tertiary
                )
            )
        }

        return Array(items.sorted { $0.date > $1.date }.prefix(6))
    }

    private var activityList: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("最近活动")

            VStack(spacing: 0) {
                ForEach(activityItems) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(item.tint)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DSH.Palette.text)
                            Text(item.detail)
                                .font(.system(size: 11))
                                .foregroundStyle(DSH.Palette.tertiary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Text(relative(item.date))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DSH.Palette.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if item.id != activityItems.last?.id {
                        Divider().overlay(DSH.Palette.hairline).padding(.leading, 48)
                    }
                }
            }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: DSH.Radius.card, style: .continuous))
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DSH.Palette.tertiary)
            .textCase(.uppercase)
            .tracking(1.1)
    }
}

struct ActivityItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let date: Date
    let symbol: String
    let tint: Color
}
