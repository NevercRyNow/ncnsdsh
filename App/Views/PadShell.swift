import SwiftUI

/// iPad / 横屏：左侧常驻导航，右侧内容。
struct PadShell: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var chrome: AppChrome

    @State private var selection: AppTab = .home

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("NcnsDSH") {
                    ForEach(AppTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.symbol)
                            .tag(tab)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(DSH.Palette.canvas)
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
