import Foundation

/// 统一的工具描述。Swift 工具与未来的 MCP 工具都走这一条。
struct ToolManifest: Identifiable {
    let id: String            // 工具名
    let title: String
    let summary: String
    let runtime: RuntimeKind
    let writes: Bool
}

struct ToolInvocation {
    let tool: String
    let arguments: String
    let runtime: RuntimeKind
}

struct ToolResult {
    let tool: String
    let output: String
    let isError: Bool
}

/// 工具注册表：把本机工具包成 manifest，并负责执行分发。
enum ToolRegistry {
    static let native: [ToolManifest] = [
        ToolManifest(id: "list_files", title: "列目录", summary: "列出工作区里的文件", runtime: .native, writes: false),
        ToolManifest(id: "read_file", title: "读文件", summary: "读取文本文件，最多 20 KB", runtime: .native, writes: false),
        ToolManifest(id: "write_file", title: "写文件", summary: "写入文本文件（覆盖）", runtime: .native, writes: true),
        ToolManifest(id: "device_info", title: "设备信息", summary: "型号、系统、电量、存储", runtime: .native, writes: false),
        ToolManifest(id: "open_url", title: "打开链接", summary: "用系统浏览器打开 http(s)", runtime: .native, writes: false),
        ToolManifest(id: "clipboard", title: "剪贴板", summary: "读写系统剪贴板", runtime: .native, writes: true),
        ToolManifest(id: "notify", title: "通知", summary: "安排一条本地通知", runtime: .native, writes: false),
        ToolManifest(id: "speak", title: "朗读", summary: "用系统语音朗读文本", runtime: .native, writes: false),
        ToolManifest(id: "text_analysis", title: "文本分析", summary: "语言与命名实体", runtime: .native, writes: false),
        ToolManifest(id: "image_analysis", title: "图片识别", summary: "识别图片里的文字", runtime: .native, writes: false)
    ]

    static func manifests(for names: [String]) -> [ToolManifest] {
        native.filter { names.contains($0.id) }
    }

    /// 发给模型的 definitions，只包含允许的工具。
    static func definitions(allowing names: [String]) -> [[String: Any]] {
        LocalTools.definitions(allowing: names)
    }

    static func invoke(_ invocation: ToolInvocation, allowsWrite: Bool) -> ToolResult {
        let output = LocalTools.run(
            name: invocation.tool,
            arguments: invocation.arguments,
            allowsWrite: allowsWrite
        )
        return ToolResult(tool: invocation.tool, output: output, isError: output.hasPrefix("错误：") || output.hasPrefix("拒绝："))
    }
}
