import SwiftUI

enum EnvironmentType: String, CaseIterable, Identifiable {
    case iPhone
    case remoteDSH
    case server

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iPhone: return "这台 iPhone"
        case .remoteDSH: return "电脑上的 DSH"
        case .server: return "服务器"
        }
    }

    var symbol: String {
        switch self {
        case .iPhone: return "iphone"
        case .remoteDSH: return "desktopcomputer"
        case .server: return "server.rack"
        }
    }

    var note: String {
        switch self {
        case .iPhone: return "本机运行，模型直连，工具在沙盒里"
        case .remoteDSH: return "通过 dsh web 连接，完整运行时"
        case .server: return "长任务与自动化，暂未接入"
        }
    }
}

enum EnvironmentStatus: Equatable {
    case online
    case connecting
    case offline
    case unsupported(String)

    var label: String {
        switch self {
        case .online: return "在线"
        case .connecting: return "连接中"
        case .offline: return "离线"
        case .unsupported(let reason): return reason
        }
    }

    var tint: Color {
        switch self {
        case .online: return DSH.Palette.success
        case .connecting: return DSH.Palette.warning
        case .offline: return DSH.Palette.tertiary
        case .unsupported: return DSH.Palette.tertiary
        }
    }
}

struct EnvironmentProfile: Identifiable, Equatable {
    let id: UUID
    var type: EnvironmentType
    var name: String
    var workspace: String
    var runtimeVersion: String
    var hostID: UUID?
    var lastUsed: Date?

    static let localID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

/// 环境管理：本机永远在，宿主随 HostStore 增减。
@MainActor
final class EnvironmentManager: ObservableObject {
    @Published private(set) var profiles: [EnvironmentProfile] = []
    @Published var currentID: UUID = EnvironmentProfile.localID

    private let defaults = UserDefaults.standard

    init() {
        let stored = defaults.string(forKey: "env.current").flatMap(UUID.init(uuidString:))
        currentID = stored ?? EnvironmentProfile.localID
    }

    var current: EnvironmentProfile? {
        profiles.first { $0.id == currentID }
    }

    /// 根据本机与宿主重建列表，保留当前选择（不存在的选择回落到本机）。
    func sync(hosts: [Host], currentHost: Host?) {
        var list: [EnvironmentProfile] = [
            EnvironmentProfile(
                id: EnvironmentProfile.localID,
                type: .iPhone,
                name: "这台 iPhone",
                workspace: "Documents/NcnsDSH/workspace",
                runtimeVersion: Bundle.main.appVersion,
                hostID: nil,
                lastUsed: Date()
            )
        ]

        for host in hosts {
            list.append(
                EnvironmentProfile(
                    id: host.id,
                    type: .remoteDSH,
                    name: host.displayName,
                    workspace: host.originText,
                    runtimeVersion: "未探测",
                    hostID: host.id,
                    lastUsed: nil
                )
            )
        }

        profiles = list

        if !list.contains(where: { $0.id == currentID }) {
            currentID = EnvironmentProfile.localID
        }
    }

    func select(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        currentID = id
        defaults.set(id.uuidString, forKey: "env.current")
        Haptics.medium()
    }

    func status(for profile: EnvironmentProfile, hosts: [Host], currentHost: Host?) -> EnvironmentStatus {
        switch profile.type {
        case .iPhone:
            return .online
        case .remoteDSH:
            guard let hostID = profile.hostID, let host = hosts.first(where: { $0.id == hostID }) else {
                return .offline
            }
            return host.id == currentHost?.id ? .online : .offline
        case .server:
            return .unsupported("暂未接入")
        }
    }
}
