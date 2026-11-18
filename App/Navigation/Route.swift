import SwiftUI

enum AppTab: String, Hashable, CaseIterable, Identifiable {
    case home
    case projects
    case sessions
    case workbench
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .projects: return "项目"
        case .sessions: return "会话"
        case .workbench: return "工作台"
        case .more: return "更多"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "square.grid.2x2"
        case .projects: return "folder"
        case .sessions: return "bubble.left.and.bubble.right"
        case .workbench: return "terminal"
        case .more: return "ellipsis.circle"
        }
    }
}

/// 全 App 唯一的导航目标。深链、Intent、列表点击都转成它。
enum Route: Hashable {
    case session(UUID)
    case localSession(UUID)
    case project(UUID)
    case build
    case settings
    case devices

    static func from(_ url: URL) -> Route? {
        guard let scheme = url.scheme, scheme == "ncnsdsh" || scheme == "dsh" else { return nil }
        let parts = url.pathComponents.dropFirst()
        switch url.host {
        case "session":
            guard let first = parts.first, let id = UUID(uuidString: first) else { return nil }
            return .session(id)
        case "local":
            guard let first = parts.first, let id = UUID(uuidString: first) else { return nil }
            return .localSession(id)
        case "project":
            guard let first = parts.first, let id = UUID(uuidString: first) else { return nil }
            return .project(id)
        case "build": return .build
        case "settings": return .settings
        default: return nil
        }
    }
}

/// 把 Route 变成视图。所有 NavigationStack 共用这一处。
struct RouteDestination: View {
    let route: Route

    @EnvironmentObject private var demo: DemoStore

    var body: some View {
        switch route {
        case .session(let id):
            ChatView(sessionID: id)
        case .localSession(let id):
            LocalChatView(sessionID: id)
        case .project(let id):
            if let workspace = demo.workspaces.first(where: { $0.id == id }) {
                WorkspaceDetailView(workspace: workspace)
            } else {
                EmptyStateView(
                    symbol: "folder.badge.questionmark",
                    title: "项目不存在",
                    message: "它可能已经被移除。",
                    actionTitle: nil,
                    action: nil
                )
            }
        case .build:
            BuildView()
        case .settings:
            SettingsView()
        case .devices:
            DevicesView()
        }
    }
}
