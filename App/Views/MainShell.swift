import SwiftUI

struct MainShell: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var chrome: AppChrome
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var expanded: UUID?
    @Namespace private var miniNamespace

    private var liveSession: ChatSession? {
        demo.sessions.first { $0.isRunning }
    }

    var body: some View {
        if sizeClass == .regular {
            PadShell()
        } else {
            phoneShell
        }
    }

    private var phoneShell: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $router.tab) {
                tab(.home) { HomeView() }
                tab(.projects) { WorkspacesView() }
                tab(.sessions) { stacked { SessionsListView() } }
                tab(.workbench) { stacked { WorkbenchView(sessionID: nil) } }
                tab(.more) { stacked { MoreView() } }
            }
            .tint(DSH.Palette.accent)
            .sensoryFeedback(.selection, trigger: router.tab)

            if let session = liveSession, !chrome.chatOpen {
                if expanded == session.id {
                    ChatView(sessionID: session.id)
                        .matchedGeometryEffect(id: "liveSession", in: miniNamespace)
                        .transition(.opacity)
                        .zIndex(2)
                        .overlay(alignment: .topTrailing) {
                            collapseButton
                        }
                } else {
                    GlassGroup(spacing: 10) {
                        miniBar(session)
                    }
                    .matchedGeometryEffect(id: "liveSession", in: miniNamespace)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 58)
                    .zIndex(1)
                }
            }
        }
        .animation(DSH.Motion.flow, value: expanded)
        .background(DSH.Palette.canvas.ignoresSafeArea())
        .onChange(of: router.tab) { _, _ in
            chrome.chatOpen = false
            router.path = []
        }
        .onChange(of: demo.sessions.first(where: { $0.isRunning })?.id) { _, id in
            if id == nil { expanded = nil }
        }
    }

    private func tab<Content: View>(_ value: AppTab, @ViewBuilder content: () -> Content) -> some View {
        content()
            .tabItem { Label(value.title, systemImage: value.symbol) }
            .tag(value)
    }

    /// 给自带导航栈的页面（首页、项目）之外的 Tab 提供栈与路由。
    private func stacked<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: $router.path) {
            content()
                .navigationDestination(for: Route.self) { route in
                    RouteDestination(route: route)
                }
        }
    }

    // MARK: - Mini bar

    private func miniBar(_ session: ChatSession) -> some View {
        Button {
            Haptics.soft()
            withAnimation(DSH.Motion.flow) {
                expanded = session.id
            }
        } label: {
            HStack(spacing: 10) {
                RemoteArtwork(seed: session.title, github: ProjectMeta.githubSlug(for: session.workspace), cornerRadius: 6)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 0) {
                    Text(session.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DSH.Palette.text)
                        .lineLimit(1)
                    Text("正在工作 · \(Int(session.progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(DSH.Palette.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Circle()
                    .fill(DSH.Palette.accent)
                    .frame(width: 7, height: 7)

                Image(systemName: "chevron.up")
                    .font(.caption2.bold())
                    .foregroundStyle(DSH.Palette.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .ncnsPill()
            .overlay(Capsule().strokeBorder(DSH.Palette.hairline, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var collapseButton: some View {
        Button {
            Haptics.soft()
            withAnimation(DSH.Motion.flow) {
                expanded = nil
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DSH.Palette.text)
                .frame(width: 32, height: 32)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.top, 8)
    }
}
