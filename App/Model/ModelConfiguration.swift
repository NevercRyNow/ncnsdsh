import Foundation
import SwiftUI

// MARK: - Execution mode

enum ExecutionMode: String, CaseIterable, Identifiable {
    case ask
    case plan
    case agent
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: return "ASK"
        case .plan: return "PLAN"
        case .agent: return "AGENT"
        case .review: return "REVIEW"
        }
    }

    var summary: String {
        switch self {
        case .ask: return "只回答，不动文件"
        case .plan: return "先出方案，等你确认"
        case .agent: return "可以读写工作区"
        case .review: return "只读，用来审查"
        }
    }

    var allowsTools: Bool { self != .ask }

    var allowsWrites: Bool { self == .agent }

    var systemHint: String {
        switch self {
        case .ask: return "当前是 ASK 模式：不要调用任何工具，直接用你的知识回答。"
        case .plan: return "当前是 PLAN 模式：先给出分步计划，不要修改任何文件，等用户确认。"
        case .agent: return "当前是 AGENT 模式：可以调用工具读写工作区，写之前说明你要改什么。"
        case .review: return "当前是 REVIEW 模式：只读。看文件可以，不要写、不要删，输出审查意见。"
        }
    }
}

// MARK: - Permission

enum PermissionProfile: String, CaseIterable, Identifiable {
    case readOnly
    case workspace
    case askBeforeChanges

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readOnly: return "只读"
        case .workspace: return "工作区读写"
        case .askBeforeChanges: return "改动前确认"
        }
    }

    var detail: String {
        switch self {
        case .readOnly: return "只能看，不能写"
        case .workspace: return "可以写工作区里的文件"
        case .askBeforeChanges: return "写之前先问你"
        }
    }

    var allowsWrite: Bool { self != .readOnly }
}

// MARK: - Tools

enum ToolCapability: String, CaseIterable, Identifiable {
    case files
    case device
    case system
    case analysis
    case terminal
    case browser
    case search
    case plugins
    case mcp
    case context

    var id: String { rawValue }

    var title: String {
        switch self {
        case .files: return "文件"
        case .device: return "设备"
        case .system: return "系统"
        case .analysis: return "分析"
        case .terminal: return "终端"
        case .browser: return "浏览器"
        case .search: return "搜索"
        case .plugins: return "插件"
        case .mcp: return "MCP"
        case .context: return "项目上下文"
        }
    }

    var symbol: String {
        switch self {
        case .files: return "folder"
        case .device: return "iphone"
        case .system: return "gearshape.2"
        case .analysis: return "text.magnifyingglass"
        case .terminal: return "terminal"
        case .browser: return "globe"
        case .search: return "magnifyingglass"
        case .plugins: return "puzzlepiece.extension"
        case .mcp: return "point.3.connected.trianglepath.dotted"
        case .context: return "doc.text"
        }
    }

    /// 这个能力当前是否真的接到模型上。终端 / 浏览器 / 搜索 / 插件 / MCP / 上下文
    /// 目前只是 App 内的工作台能力，模型还不能调用——UI 必须如实标注。
    var wiredToModel: Bool {
        switch self {
        case .files, .device, .system, .analysis: return true
        default: return false
        }
    }

    var toolNames: [String] {
        switch self {
        case .files: return ["list_files", "read_file", "write_file", "image_analysis"]
        case .device: return ["device_info"]
        case .system: return ["open_url", "clipboard", "notify", "speak"]
        case .analysis: return ["text_analysis", "image_analysis"]
        default: return []
        }
    }

    var note: String {
        switch self {
        case .files: return "读写 App 沙盒里的 workspace"
        case .device: return "型号、电量、存储"
        case .system: return "打开链接、剪贴板、通知、朗读"
        case .analysis: return "语言识别、实体、图片 OCR"
        case .terminal: return "工作台内的迷你 shell，模型不能调用"
        case .browser: return "工作台内置浏览器，模型不能调用"
        case .search: return "尚未实现"
        case .plugins: return "插件只是目录，没有运行时"
        case .mcp: return "尚未连接任何 MCP 服务"
        case .context: return "会话内上下文统计"
        }
    }
}

// MARK: - Model capability

struct ModelCapability {
    var supportsTools: Bool
    var reasoningLevels: [String]
    var contextWindow: Int?
    var note: String?

    /// 只根据能确证的事实声明能力；不确定就给空，不猜。
    static func forModel(_ id: String) -> ModelCapability {
        switch id {
        case "deepseek-chat":
            return ModelCapability(supportsTools: true, reasoningLevels: [], contextWindow: nil, note: "支持函数调用；DeepSeek 未开放推理档位参数。")
        case "deepseek-reasoner":
            return ModelCapability(supportsTools: false, reasoningLevels: [], contextWindow: nil, note: "推理模型，当前接口不支持函数调用与推理档位。")
        default:
            return ModelCapability(supportsTools: true, reasoningLevels: [], contextWindow: nil, note: nil)
        }
    }
}

// MARK: - Configuration store

@MainActor
final class ModelConfigurationStore: ObservableObject {
    @Published var model: String { didSet { save() } }
    @Published var mode: ExecutionMode { didSet { save() } }
    @Published var permission: PermissionProfile { didSet { save() } }
    @Published var enabledTools: Set<ToolCapability> { didSet { save() } }

    private let defaults = UserDefaults.standard

    init() {
        model = defaults.string(forKey: "cfg.model") ?? "deepseek-chat"
        mode = ExecutionMode(rawValue: defaults.string(forKey: "cfg.mode") ?? "") ?? .agent
        permission = PermissionProfile(rawValue: defaults.string(forKey: "cfg.permission") ?? "") ?? .workspace
        let stored = defaults.stringArray(forKey: "cfg.tools") ?? ["files", "device", "system", "analysis"]
        enabledTools = Set(stored.compactMap { ToolCapability(rawValue: $0) })
    }

    var capability: ModelCapability { ModelCapability.forModel(model) }

    /// 真正发给模型的工具名：模式允许、模型支持、用户开启，三者同时成立。
    var activeToolNames: [String] {
        guard mode.allowsTools, capability.supportsTools else { return [] }
        return enabledTools
            .filter(\.wiredToModel)
            .flatMap(\.toolNames)
    }

    var sandboxMode: SandboxMode {
        switch permission {
        case .readOnly: return .readOnly
        case .workspace, .askBeforeChanges: return .workspaceWrite
        }
    }

    var allowsWrite: Bool {
        mode.allowsWrites && permission.allowsWrite && capability.supportsTools
    }

    private func save() {
        defaults.set(model, forKey: "cfg.model")
        defaults.set(mode.rawValue, forKey: "cfg.mode")
        defaults.set(permission.rawValue, forKey: "cfg.permission")
        defaults.set(enabledTools.map(\.rawValue), forKey: "cfg.tools")
    }
}
