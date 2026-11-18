import Foundation

/// 沙箱模式，和 DSH 的三档一致：read-only / workspace-write / danger-full-access。
enum SandboxMode: String, CaseIterable, Identifiable {
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"
    case dangerFullAccess = "danger-full-access"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readOnly: return "只读"
        case .workspaceWrite: return "工作区可写"
        case .dangerFullAccess: return "完全访问"
        }
    }

    var detail: String {
        switch self {
        case .readOnly: return "只能读取工作区，任何写入被拒绝"
        case .workspaceWrite: return "工作区内可读写，越界一律拒绝"
        case .dangerFullAccess: return "可写工作区外，仍受 iOS 沙盒限制"
        }
    }

    var allowsWrite: Bool { self != .readOnly }
}

struct SandboxPolicy {
    var mode: SandboxMode
    var writesOutsideWorkspace: Bool { mode == .dangerFullAccess }
}

struct SandboxAuditEntry: Identifiable {
    enum Outcome {
        case allowed
        case denied(String)
    }

    let id = UUID()
    let date: Date
    let tool: String
    let path: String
    let outcome: Outcome
}

enum SandboxError: LocalizedError {
    case outsideWorkspace(String)
    case readOnly(String)
    case missing(String)

    var errorDescription: String? {
        switch self {
        case .outsideWorkspace(let path): return "路径不在工作区里：\(path)"
        case .readOnly(let path): return "当前沙箱模式不允许写入：\(path)"
        case .missing(let path): return "文件不存在：\(path)"
        }
    }
}

/// 文件效果的围栏。和 DSH 一样是 **partial enforcement**：
/// 文件读写被限制在允许的根目录内，网络不受限制（这一点必须如实说明）。
final class Sandbox {
    static let shared = Sandbox()

    private(set) var policy = SandboxPolicy(mode: .workspaceWrite)
    private(set) var audit: [SandboxAuditEntry] = []
    private let limit = 120

    var workspace: URL { AppFiles.workspace }

    func configure(mode: SandboxMode) {
        policy = SandboxPolicy(mode: mode)
    }

    /// 解析相对路径；写操作在这里就被拒，不依赖调用方自觉。
    func resolve(_ relative: String, write: Bool, tool: String) throws -> URL {
        let base = workspace.standardizedFileURL
        let candidate = relative.isEmpty
            ? base
            : base.appendingPathComponent(relative).standardizedFileURL

        let inside = candidate.path == base.path || candidate.path.hasPrefix(base.path + "/")
        guard inside || policy.writesOutsideWorkspace else {
            record(tool: tool, path: relative, outcome: .denied("越界"))
            throw SandboxError.outsideWorkspace(relative)
        }

        if write && !policy.mode.allowsWrite {
            record(tool: tool, path: relative, outcome: .denied("只读模式"))
            throw SandboxError.readOnly(relative)
        }

        record(tool: tool, path: relative, outcome: .allowed)
        return candidate
    }

    func record(tool: String, path: String, outcome: SandboxAuditEntry.Outcome) {
        audit.append(SandboxAuditEntry(date: Date(), tool: tool, path: path, outcome: outcome))
        if case .denied(let reason) = outcome {
            Task { @MainActor in
                RuntimeLog.shared.log("沙箱拒绝 \(tool) \(path)（\(reason)）", level: .error)
            }
        }
        if audit.count > limit {
            audit.removeFirst(audit.count - limit)
        }
    }

    func clearAudit() {
        audit.removeAll()
    }

    var denialCount: Int {
        audit.filter {
            if case .denied = $0.outcome { return true }
            return false
        }.count
    }
}
