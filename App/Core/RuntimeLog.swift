import SwiftUI

/// 本机运行时日志：环形缓冲，只记录真实发生的事。
@MainActor
final class RuntimeLog: ObservableObject {
    enum Level: String {
        case info
        case warn
        case error

        var tint: Color {
            switch self {
            case .info: return DSH.Palette.secondary
            case .warn: return DSH.Palette.warning
            case .error: return DSH.Palette.danger
            }
        }
    }

    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let level: Level
        let text: String
    }

    static let shared = RuntimeLog()

    @Published private(set) var entries: [Entry] = []
    private let limit = 300

    func log(_ text: String, level: Level = .info) {
        entries.append(Entry(date: Date(), level: level, text: text))
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
    }

    func clear() {
        entries.removeAll()
    }

    var plainText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return entries.map { "\(formatter.string(from: $0.date)) [\($0.level.rawValue.uppercased())] \($0.text)" }
            .joined(separator: "\n")
    }
}
