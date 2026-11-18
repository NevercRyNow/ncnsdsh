import SwiftUI

/// 全 App 唯一的导航状态：Tab + 路由栈。深链、Intent、列表点击都走这里。
@MainActor
final class AppRouter: ObservableObject {
    @Published var tab: AppTab = .home
    @Published var path: [Route] = []

    func open(_ route: Route) {
        path.append(route)
    }

    func reset(to tab: AppTab) {
        self.tab = tab
        path = []
    }

    func handle(_ target: NcnsIntentTarget, demo: DemoStore) {
        switch target {
        case .new(let draft):
            tab = .home
            demo.newSession(draft: draft)
            if let id = demo.activeSessionID {
                path = [.session(id)]
            }
        case .recent:
            tab = .home
            if let id = demo.heroSession?.id {
                path = [.session(id)]
            }
        case .session(let id):
            tab = .home
            path = [.session(id)]
        }
    }
}
