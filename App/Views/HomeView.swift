import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var store: HostStore
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var local: LocalStore
    @State private var showAccount = false
    @State private var showConnect = false
    @State private var collapsed = false

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: proxy.frame(in: .named("homeScroll")).minY
                        )
                    }
                    .frame(height: 0)

                    topBar

                    if store.current == nil && local.recent.isEmpty {
                        onboarding
                    } else {
                        if let hero = demo.heroSession, store.current != nil {
                            heroCard(hero)
                        } else if let first = local.recent.first {
                            localHeroCard(first)
                        }

                        if store.current != nil {
                            continueShelf.riseIn(delay: 0.04)
                        }

                        localShelf.riseIn(delay: 0.10)

                        if store.current != nil {
                            workspaceShelf.riseIn(delay: 0.16)
                            recentShelf.riseIn(delay: 0.22)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: "homeScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                let next = offset < -48
                if next != collapsed {
                    withAnimation(DSH.Motion.snap) { collapsed = next }
                }
            }
            .background(DSH.Palette.canvas)
            .navigationDestination(for: Route.self) { route in
                RouteDestination(route: route)
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
                    .environmentObject(account)
            }
            .sheet(isPresented: $showConnect) {
                ConnectView()
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                if !collapsed {
                    Text("NcnsDSH")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DSH.Palette.tertiary)
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .transition(.opacity)
                }
                Text("会话")
                    .font(collapsed ? DSH.TypeScale.title : DSH.TypeScale.display)
                    .foregroundStyle(DSH.Palette.text)
            }
            .animation(DSH.Motion.snap, value: collapsed)

            Spacer()

            HStack(spacing: 10) {
                if demo.runningCount > 0 {
                    HStack(spacing: 6) {
                        StatusDot()
                        Text("\(demo.runningCount) 个在跑")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .ncnsPill()
                }

                Menu {
                    if account.isSignedIn {
                        Button {
                            let id = local.createSession(model: account.selectedModel)
                            router.path.append(.localSession(id))
                        } label: {
                            Label("本机会话", systemImage: "cpu")
                        }
                    } else {
                        Button {
                            showAccount = true
                        } label: {
                            Label("登录 DeepSeek", systemImage: "person.crop.circle")
                        }
                    }

                    Button {
                        demo.newSession()
                        if let id = demo.activeSessionID {
                            router.path.append(.session(id))
                        }
                    } label: {
                        Label("演示会话", systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .ncnsPill()
            }
        }
    }

    // MARK: - Hero

    private func heroCard(_ session: ChatSession) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteArtwork(seed: session.title, github: ProjectMeta.githubSlug(for: session.workspace), cornerRadius: 26)
                .frame(height: 320)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.10), Color.black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    StatusDot(color: session.isRunning ? Theme.mint : Color.white.opacity(0.6), pulsing: session.isRunning)
                    Text(session.isRunning ? "正在运行" : "上次活动")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.4))
                    Text(session.relativeTime)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text(session.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text("\(session.workspace) · \(session.preview)")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Button("继续") {
                        Haptics.soft()
                        router.path.append(.session(session.id))
                    }
                    .buttonStyle(.ncnsProminent)

                    Button("新会话") {
                        Haptics.soft()
                        demo.newSession()
                        if let id = demo.activeSessionID {
                            router.path.append(.session(id))
                        }
                    }
                    .buttonStyle(.ncnsGlass)
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .frame(height: 320)
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                .opacity(phase.isIdentity ? 1 : 0.78)
        }
        .liquidDrag(threshold: 120)
    }

    // MARK: - Shelves

    private var continueShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "继续")

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(demo.continueSessions) { session in
                        NavigationLink(value: Route.session(session.id)) {
                            continueCard(session)
                        }
                        .buttonStyle(CardPressStyle())
                        .contextMenu {
                            Button {
                                demo.togglePinned(session.id)
                            } label: {
                                Label(session.pinned ? "取消置顶" : "置顶", systemImage: "pin")
                            }
                            Button(role: .destructive) {
                                demo.archive(session.id)
                            } label: {
                                Label("归档", systemImage: "archivebox")
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func continueCard(_ session: ChatSession) -> some View {
        ZStack(alignment: .bottomLeading) {
            RemoteArtwork(seed: session.title, github: ProjectMeta.githubSlug(for: session.workspace), cornerRadius: 20)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                HStack(spacing: 6) {
                    if session.isRunning {
                        StatusDot()
                    }
                    Text(session.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(session.workspace)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                if session.isRunning {
                    ProgressLine(progress: session.progress)
                }
            }
            .padding(14)
        }
        .frame(width: 280, height: 180)
    }

    private var workspaceShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "工作区")

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(demo.workspaces) { workspace in
                        VStack(alignment: .leading, spacing: 0) {
                            RemoteArtwork(seed: workspace.name, github: ProjectMeta.githubSlug(for: workspace.name), cornerRadius: 18)
                                .frame(width: 160, height: 200)

                            HStack(spacing: 6) {
                                Text(workspace.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if workspace.running > 0 {
                                    StatusDot()
                                }
                            }
                            .padding(.top, 8)

                            Text("\(workspace.total) 个会话")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                        }
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var recentShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "最近完成")

            VStack(spacing: 0) {
                ForEach(Array(demo.sessions.dropFirst(2).prefix(4))) { session in
                    NavigationLink(value: Route.session(session.id)) {
                        HStack(spacing: 12) {
                            RemoteArtwork(seed: session.title, github: ProjectMeta.githubSlug(for: session.workspace), cornerRadius: 10)
                                .frame(width: 46, height: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text("\(session.workspace) · \(session.relativeTime)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.dim)
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if session.id != demo.sessions.dropFirst(2).prefix(4).last?.id {
                        Divider().overlay(Theme.hairline).padding(.leading, 58)
                    }
                }
            }
        }
    }

    // MARK: - Onboarding

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                ArtworkView(index: 0, initial: "N", cornerRadius: 26)
                    .frame(height: 240)

                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("NcnsDSH")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(1.4)
                    Text("从这儿开始")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("不用先登录。本机直接聊，或者连上那台跑 dsh web 的电脑。")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(22)
            }
            .frame(height: 240)

            HStack(spacing: 10) {
                Button(account.isSignedIn ? "新建本机会话" : "登录 DeepSeek") {
                    Haptics.soft()
                    if account.isSignedIn {
                        let id = local.createSession(model: account.selectedModel)
                        router.path.append(.localSession(id))
                    } else {
                        showAccount = true
                    }
                }
                .buttonStyle(.ncnsProminent)

                Button("连接电脑") {
                    Haptics.tap()
                    showConnect = true
                }
                .buttonStyle(.ncnsGlass)
            }
            .padding(.top, 18)
        }
    }

    private func localHeroCard(_ session: LocalSession) -> some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(index: session.title.count, initial: session.initial, cornerRadius: 26)
                .frame(height: 300)

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.80)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 11, weight: .semibold))
                    Text("本机 · \(session.model)")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.78))

                Text(session.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(session.preview)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Button("继续") {
                        Haptics.soft()
                        router.path.append(.localSession(session.id))
                    }
                    .buttonStyle(.ncnsProminent)

                    Button("新会话") {
                        Haptics.soft()
                        let id = local.createSession(model: account.selectedModel)
                        router.path.append(.localSession(id))
                    }
                    .buttonStyle(.ncnsGlass)
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .frame(height: 300)
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.95)
                .opacity(phase.isIdentity ? 1 : 0.8)
        }
        .liquidDrag(threshold: 120)
    }

    // MARK: - Local

    @ViewBuilder
    private var localShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("本机")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Text("不连电脑")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.dim)
                Spacer()
                if account.isSignedIn {
                    Button("新建") {
                        let id = local.createSession(model: account.selectedModel)
                        router.path.append(.localSession(id))
                    }
                    .buttonStyle(NcnsGlassButtonStyle(compact: true))
                } else {
                    Button("登录") { showAccount = true }
                        .buttonStyle(NcnsGlassButtonStyle(compact: true))
                }
            }

            if !account.isSignedIn {
                EmptyHint(text: "登录 DeepSeek 后，就能在这台手机上直接对话，让它读写本机工作区。")
            } else if local.recent.isEmpty {
                EmptyHint(text: "还没有本机会话。点「新建」开始。")
            } else {
                VStack(spacing: 0) {
                    ForEach(local.recent.prefix(3)) { session in
                        NavigationLink(value: Route.localSession(session.id)) {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.artwork(session.title.count))
                                    .frame(width: 46, height: 46)
                                    .overlay(
                                        Text(session.initial)
                                            .font(.system(size: 17, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.9))
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(session.preview)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.muted)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 8)

                                Text(session.model)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Theme.dim)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.dim)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if session.id != local.recent.prefix(3).last?.id {
                            Divider().overlay(Theme.hairline).padding(.leading, 58)
                        }
                    }
                }
            }
        }
    }

}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// 卡片按下时轻微收缩，配合玻璃高光。
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
            }
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}
