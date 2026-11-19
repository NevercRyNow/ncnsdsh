import SwiftUI

/// 浮条按下时轻微回弹。浮条不再支持拖动——它在 GlassEffectContainer 里，
/// 每帧移动都会让容器重算玻璃形状，真机上表现为跟手迟滞甚至停住。
struct MiniBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

struct MainShell: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var chrome: AppChrome
    @Environment(\.horizontalSizeClass) private var sizeClass


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
            // 运行中的浮条会压住页面最后一段内容（更多页的签名、首页的活动列表都中过招）。
            // 在 TabView 上统一让出这段高度，各个页面不用各自打补丁。
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: (liveSession != nil && !chrome.chatOpen) ? 64 : 0)
            }

            if let session = liveSession, !chrome.chatOpen {
                GlassGroup(spacing: 10) {
                    miniBar(session)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 58)
                .zIndex(1)
            }
        }
        .background(DSH.Palette.canvas.ignoresSafeArea())
        .onChange(of: router.tab) { _, _ in
            chrome.chatOpen = false
            router.path = []
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

    /// 运行中会话的浮条。**不支持拖动**：它在 `GlassEffectContainer` 里，
    /// 每帧改 offset 都会让容器重算玻璃形状，真机上就是拖不动/迟滞；
    /// 点一下展开成全屏对话，这也是它唯一的用途。
    private func miniBar(_ session: ChatSession) -> some View {
        Button {
            expand(session)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cpu")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DSH.Palette.accent)
                    .frame(width: 32, height: 32)
                    .background(DSH.Palette.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DSH.Palette.text)
                        .lineLimit(1)
                    Text("正在工作 · \(Int(session.progress * 100))%")
                        .font(.system(size: 10))
                        .foregroundStyle(DSH.Palette.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Circle()
                    .fill(DSH.Palette.accent)
                    .frame(width: 6, height: 6)

                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(DSH.Palette.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(white: 0.075).opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(MiniBarButtonStyle())
        .accessibilityLabel("\(session.title)，正在工作")
        .accessibilityHint("轻点展开对话")
    }

    /// 点浮条 = 打开这个会话。用的是普通的路由 push（带返回按钮的原生转场），
    /// 不再把玻璃条 matchedGeometry 成整屏——那一下要在 GlassEffectContainer 里
    /// 重算整块玻璃，真机上就是「点一下卡住」。
    private func expand(_ session: ChatSession) {
        Haptics.soft()
        if router.tab != .home { router.tab = .home }
        DispatchQueue.main.async {
            router.path = [.session(session.id)]
        }
    }

}
