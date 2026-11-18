import SwiftUI

/// iPad / 横屏：左侧常驻导航，右侧内容。侧栏不是 List 选择，避免 iOS 上不可用的 selection 初始化器。
struct PadShell: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var chrome: AppChrome

    @State private var selection: AppTab = .home

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("NcnsDSH")
        } detail: {
            detail
        }
        .tint(DSH.Palette.accent)
        .onChange(of: selection) { _, value in
            router.tab = value
            router.path = []
            chrome.chatOpen = false
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(AppTab.allCases) { tab in
                    Button {
                        Haptics.tap()
                        selection = tab
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 15, weight: .medium))
                                .frame(width: 22)
                            Text(tab.title)
                                .font(DSH.TypeScale.body)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(selection == tab ? DSH.Palette.text : DSH.Palette.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            selection == tab ? DSH.Palette.raised : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .scrollIndicators(.hidden)
        .background(DSH.Palette.canvas)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .home:
            HomeView()
        case .projects:
            WorkspacesView()
        case .sessions:
            padStack { SessionsListView() }
        case .workbench:
            padStack { WorkbenchView(sessionID: nil) }
        case .more:
            padStack { MoreView() }
        }
    }

    private func padStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: $router.path) {
            content()
                .navigationDestination(for: Route.self) { route in
                    RouteDestination(route: route)
                }
        }
    }
}
