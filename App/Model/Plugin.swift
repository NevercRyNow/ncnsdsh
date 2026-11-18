import Foundation

/// 插件条目：本地目录 + 商店目录共用一套结构。
struct DSHPlugin: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var vendor: String
    var summary: String
    var version: String
    var symbol: String
    var category: String
    var installed: Bool
    var official: Bool
    var permissions: [String]
}

enum PluginRisk: Int, Comparable {
    case low = 0, medium = 1, high = 2

    static func < (lhs: PluginRisk, rhs: PluginRisk) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .low: return "低风险"
        case .medium: return "中风险"
        case .high: return "高风险"
        }
    }
}

extension DSHPlugin {
    /// 风险由声明的权限推导，不是随便贴标签。
    var risk: PluginRisk {
        let high: Set<String> = ["子进程", "账号", "会话"]
        let medium: Set<String> = ["文件", "相机", "照片", "日历", "提醒事项", "剪贴板", "通知"]
        if permissions.contains(where: { high.contains($0) }) { return .high }
        if permissions.contains(where: { medium.contains($0) }) { return .medium }
        return .low
    }

    var recommended: Bool {
        ["dsh-drawai", "dsh-image", "dsh-mcp", "dsh-ocr", "dsh-mobile-gateway"].contains(id)
    }

    var glyph: String {
        String(name.first ?? "·")
    }

    static let catalog: [DSHPlugin] = [
        DSHPlugin(
            id: "dsh-mobile-gateway",
            name: "Mobile Gateway",
            vendor: "Clarklevis1995",
            summary: "把宿主会话通过 WebSocket 暴露给手机，支持配对码与可信设备。",
            version: "0.12.1",
            symbol: "antenna.radiowaves.left.and.right",
            category: "连接",
            installed: true,
            official: false,
            permissions: ["网络", "会话"]
        ),
        DSHPlugin(
            id: "dsh-drawai",
            name: "DrawAI",
            vendor: "DeepSeek",
            summary: "在会话里直接读写 .drawio 画布、导出 PNG/SVG、做分镜板。",
            version: "0.9.3",
            symbol: "pencil.and.ruler",
            category: "创作",
            installed: true,
            official: true,
            permissions: ["文件", "画布"]
        ),
        DSHPlugin(
            id: "dsh-web-search",
            name: "Web Search",
            vendor: "DeepSeek",
            summary: "给智能体一个联网搜索工具，带来源引用。",
            version: "1.4.0",
            symbol: "magnifyingglass",
            category: "工具",
            installed: true,
            official: true,
            permissions: ["网络"]
        ),
        DSHPlugin(
            id: "dsh-schedule",
            name: "Schedule",
            vendor: "DeepSeek",
            summary: "定时触发会话：每天汇总、每周清理，都能挂在本机跑。",
            version: "0.6.2",
            symbol: "clock.arrow.circlepath",
            category: "自动化",
            installed: false,
            official: true,
            permissions: ["后台", "会话"]
        ),
        DSHPlugin(
            id: "dsh-git",
            name: "Git",
            vendor: "community",
            summary: "提交、分支、diff 预览；危险命令会先问一次。",
            version: "0.4.5",
            symbol: "arrow.triangle.branch",
            category: "开发",
            installed: false,
            official: false,
            permissions: ["文件", "子进程"]
        ),
        DSHPlugin(
            id: "dsh-office",
            name: "Office",
            vendor: "DeepSeek",
            summary: "读写 docx / xlsx / pptx，导出 PDF。",
            version: "1.1.0",
            symbol: "doc.richtext",
            category: "文档",
            installed: false,
            official: true,
            permissions: ["文件"]
        ),
        DSHPlugin(
            id: "dsh-voice",
            name: "Voice",
            vendor: "community",
            summary: "语音输入与朗读，支持中文音色。",
            version: "0.3.0",
            symbol: "waveform",
            category: "输入",
            installed: false,
            official: false,
            permissions: ["麦克风"]
        ),
        DSHPlugin(
            id: "dsh-remote",
            name: "Remote Access",
            vendor: "liguobao",
            summary: "P2P 端到端加密通道，出门也能连回家里的 DSH。",
            version: "0.6.5",
            symbol: "network",
            category: "连接",
            installed: false,
            official: false,
            permissions: ["网络", "后台"]
        ),

        DSHPlugin(
            id: "dsh-translator",
            name: "Translator",
            vendor: "community",
            summary: "中英日互译，保留代码块与 Markdown 结构。",
            version: "0.5.1",
            symbol: "character.bubble",
            category: "创作",
            installed: false,
            official: false,
            permissions: ["网络"]
        ),
        DSHPlugin(
            id: "dsh-image",
            name: "Image Studio",
            vendor: "community",
            summary: "在会话里生成配图、图标与封面，支持比例预设。",
            version: "0.8.0",
            symbol: "photo.on.rectangle.angled",
            category: "创作",
            installed: false,
            official: false,
            permissions: ["网络", "文件"]
        ),
        DSHPlugin(
            id: "dsh-ocr",
            name: "OCR",
            vendor: "DeepSeek",
            summary: "本机识别图片里的文字，支持中英混排与表格。",
            version: "1.0.2",
            symbol: "text.viewfinder",
            category: "识别",
            installed: false,
            official: true,
            permissions: ["相机", "照片"]
        ),
        DSHPlugin(
            id: "dsh-calendar",
            name: "Calendar",
            vendor: "DeepSeek",
            summary: "读写日历：排期、提醒、把会议塞进今天。",
            version: "0.7.3",
            symbol: "calendar",
            category: "本机",
            installed: false,
            official: true,
            permissions: ["日历"]
        ),
        DSHPlugin(
            id: "dsh-reminders",
            name: "Reminders",
            vendor: "DeepSeek",
            summary: "把待办写进提醒事项，支持截止时间与清单。",
            version: "0.7.1",
            symbol: "checklist",
            category: "本机",
            installed: false,
            official: true,
            permissions: ["提醒事项"]
        ),
        DSHPlugin(
            id: "dsh-terminal",
            name: "Terminal",
            vendor: "DeepSeek",
            summary: "在会话里跑本机命令，危险操作先确认。",
            version: "0.9.0",
            symbol: "terminal",
            category: "开发",
            installed: false,
            official: true,
            permissions: ["文件", "子进程"]
        ),
        DSHPlugin(
            id: "dsh-lsp",
            name: "Code Index",
            vendor: "community",
            summary: "为工作区建符号索引，跳转、引用、补全都能问。",
            version: "0.4.0",
            symbol: "text.magnifyingglass",
            category: "开发",
            installed: false,
            official: false,
            permissions: ["文件"]
        ),
        DSHPlugin(
            id: "dsh-pdf",
            name: "PDF",
            vendor: "DeepSeek",
            summary: "解析 PDF 的文字与表格，也能导出带目录的版本。",
            version: "1.2.0",
            symbol: "doc.text.magnifyingglass",
            category: "文档",
            installed: false,
            official: true,
            permissions: ["文件"]
        ),
        DSHPlugin(
            id: "dsh-mcp",
            name: "MCP Connectors",
            vendor: "DeepSeek",
            summary: "接入 GitHub、Notion、Linear 等 MCP 服务。",
            version: "1.0.0",
            symbol: "point.3.connected.trianglepath.dotted",
            category: "连接",
            installed: false,
            official: true,
            permissions: ["网络", "账号"]
        ),
        DSHPlugin(
            id: "dsh-liveshare",
            name: "Live Share",
            vendor: "community",
            summary: "把会话共享给同事，一起看同一个工作区。",
            version: "0.2.4",
            symbol: "person.2.wave.2",
            category: "协作",
            installed: false,
            official: false,
            permissions: ["网络", "会话"]
        ),
    ]
}
