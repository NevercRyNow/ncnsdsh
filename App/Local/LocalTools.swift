import Foundation
import UIKit
import UserNotifications
import AVFoundation
import NaturalLanguage
import Vision

/// 本机模式能动的只有这个沙盒工作区：`Documents/NcnsDSH/workspace`。
enum LocalTools {
    private static var speaker: AVSpeechSynthesizer?
    static var workspace: URL { AppFiles.workspace }

    static let names = ["list_files", "read_file", "write_file", "device_info", "open_url", "clipboard", "notify", "speak", "text_analysis", "image_analysis", "run_javascript"]

    /// 只返回当前模式、模型能力、用户开关都允许的工具。
    static func definitions(allowing names: [String]) -> [[String: Any]] {
        guard !names.isEmpty else { return [] }
        let set = Set(names)
        return definitions.filter { entry in
            guard let function = entry["function"] as? [String: Any],
                  let name = function["name"] as? String else { return false }
            return set.contains(name)
        }
    }

    static var definitions: [[String: Any]] {
        [
            [
                "type": "function",
                "function": [
                    "name": "list_files",
                    "description": "列出本机工作区里的文件和目录。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string", "description": "相对工作区的目录，默认根目录。"]
                        ]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "read_file",
                    "description": "读一个文本文件，最多 20 KB。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string", "description": "相对工作区的文件路径。"]
                        ],
                        "required": ["path"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "speak",
                    "description": "用系统语音把一段话读出来。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "text": ["type": "string", "description": "要朗读的文本，最多 600 字。"]
                        ],
                        "required": ["text"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "text_analysis",
                    "description": "识别一段文本的主要语言，并抽出人名、地名、机构名。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "text": ["type": "string", "description": "要分析的文本。"]
                        ],
                        "required": ["text"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "image_analysis",
                    "description": "识别工作区里一张图片上的文字（OCR）。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string", "description": "相对工作区的图片路径。"]
                        ],
                        "required": ["path"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "run_javascript",
                    "description": "在本机执行一段 JavaScript（JavaScriptCore，不是 Node）。可用 console.log、fs.read(path)、fs.write(path, text)。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "source": ["type": "string", "description": "要执行的 JS 源码。"]
                        ],
                        "required": ["source"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "device_info",
                    "description": "读取这台 iPhone 的型号、系统版本、电量和剩余存储。",
                    "parameters": ["type": "object", "properties": [:]]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "open_url",
                    "description": "用系统浏览器打开一个 http(s) 链接。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "url": ["type": "string", "description": "完整链接，必须带 https:// 或 http://。"]
                        ],
                        "required": ["url"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "clipboard",
                    "description": "读或写系统剪贴板。读是 get，写是 set。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "action": ["type": "string", "enum": ["get", "set"]],
                            "text": ["type": "string", "description": "action 为 set 时要写入的文本。"]
                        ],
                        "required": ["action"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "notify",
                    "description": "发一条本地通知，几秒后提醒用户。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string"],
                            "body": ["type": "string"],
                            "after_seconds": ["type": "number", "description": "多少秒后提醒，默认 3。"]
                        ],
                        "required": ["title", "body"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "write_file",
                    "description": "写一个文本文件（覆盖）。父目录会自动创建。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": ["type": "string", "description": "相对工作区的文件路径。"],
                            "content": ["type": "string", "description": "完整的文件内容。"]
                        ],
                        "required": ["path", "content"]
                    ]
                ]
            ],
        ]
    }

    static func run(name: String, arguments: String, allowsWrite: Bool = true) -> String {
        let args = (try? JSONSerialization.jsonObject(with: Data(arguments.utf8))) as? [String: Any] ?? [:]

        do {
            switch name {
            case "list_files":
                let relative = args["path"] as? String ?? ""
                let dir = try Sandbox.shared.resolve(relative, write: false, tool: "list_files")
                let items = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }
                if items.isEmpty { return "（空目录）" }
                return items.map { url in
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    return isDir ? "\(url.lastPathComponent)/" : url.lastPathComponent
                }.joined(separator: "\n")

            case "read_file":
                guard let relative = args["path"] as? String else { return "错误：缺少 path" }
                let url = try Sandbox.shared.resolve(relative, write: false, tool: "read_file")
                let data = try Data(contentsOf: url)
                let slice = data.prefix(20 * 1024)
                return String(decoding: slice, as: UTF8.self)

            case "write_file":
                guard allowsWrite else {
                    return "拒绝：当前权限不允许写入。需要切到 AGENT 模式并放开写权限。"
                }
                guard let relative = args["path"] as? String, let content = args["content"] as? String else {
                    return "错误：缺少 path 或 content"
                }
                let url = try Sandbox.shared.resolve(relative, write: true, tool: "write_file")
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(content.utf8).write(to: url, options: .atomic)
                return "已写入 \(url.lastPathComponent)（\(content.utf8.count) 字节）"

            case "device_info":
                let device = UIDevice.current
                let battery = device.batteryLevel >= 0 ? "\(Int(device.batteryLevel * 100))%" : "未知"
                let free = (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? Int64) ?? 0
                let freeText = ByteCountFormatter.string(fromByteCount: free ?? 0, countStyle: .file)
                return """
                型号：\(device.model)
                系统：\(device.systemName) \(device.systemVersion)
                电量：\(battery)
                剩余存储：\(freeText)
                工作区：\(workspace.lastPathComponent)
                """

            case "open_url":
                guard let string = args["url"] as? String, let url = URL(string: string),
                      let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
                    return "错误：需要一个 http(s) 链接"
                }
                DispatchQueue.main.async { UIApplication.shared.open(url) }
                return "已在系统中打开 \(url.absoluteString)"

            case "clipboard":
                let action = args["action"] as? String ?? "get"
                if action == "set" {
                    guard let text = args["text"] as? String else { return "错误：缺少 text" }
                    UIPasteboard.general.string = text
                    return "已写入剪贴板（\(text.count) 字符）"
                }
                let current = UIPasteboard.general.string ?? ""
                return current.isEmpty ? "（剪贴板是空的）" : String(current.prefix(2_000))

            case "notify":
                guard let title = args["title"] as? String, let body = args["body"] as? String else {
                    return "错误：缺少 title 或 body"
                }
                let seconds = max(1, (args["after_seconds"] as? Double) ?? 3)
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    guard granted else { return }
                    UNUserNotificationCenter.current().add(request)
                }
                return "已安排 \(Int(seconds)) 秒后通知：\(title)"

            case "run_javascript":
                guard let source = args["source"] as? String, !source.isEmpty else {
                    return "错误：缺少 source"
                }
                return JavaScriptTool.run(source, allowsWrite: allowsWrite)

            case "speak":
                guard let text = args["text"] as? String, !text.isEmpty else { return "错误：缺少 text" }
                let spoken = String(text.prefix(600))
                DispatchQueue.main.async {
                    let synthesizer = AVSpeechSynthesizer()
                    let utterance = AVSpeechUtterance(string: spoken)
                    utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
                    utterance.rate = 0.5
                    synthesizer.speak(utterance)
                    Self.speaker = synthesizer
                }
                return "开始朗读（\(spoken.count) 字）"

            case "text_analysis":
                guard let text = args["text"] as? String, !text.isEmpty else { return "错误：缺少 text" }
                let language = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue ?? "unknown"
                let tagger = NLTagger(tagSchemes: [.nameType])
                tagger.string = text
                var entities: [String] = []
                tagger.enumerateTags(
                    in: text.startIndex..<text.endIndex,
                    unit: .word,
                    scheme: .nameType,
                    options: [.omitPunctuation, .omitWhitespace]
                ) { tag, range in
                    if let tag, [.personalName, .placeName, .organizationName].contains(tag) {
                        entities.append("\(text[range])（\(tag.rawValue)）")
                    }
                    return true
                }
                let list = entities.isEmpty ? "（没有识别到实体）" : entities.prefix(20).joined(separator: "、")
                return "语言：\(language)\n实体：\(list)"

            case "image_analysis":
                guard let relative = args["path"] as? String else { return "错误：缺少 path" }
                let url = try Sandbox.shared.resolve(relative, write: false, tool: "image_analysis")
                guard let image = UIImage(contentsOfFile: url.path), let cgImage = image.cgImage else {
                    return "错误：读不了这张图片"
                }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["zh-Hans", "en-US"]
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                if lines.isEmpty { return "（没有识别到文字）" }
                return String(lines.joined(separator: "\n").prefix(3_000))

            default:
                return "错误：没有这个工具 \(name)"
            }
        } catch {
            return "错误：\(error.localizedDescription)"
        }
    }

    /// 所有文件操作都过沙箱：越界与只读在这里被拒绝，并记入审计。
    static func resolve(_ relative: String, write: Bool = false) throws -> URL {
        try Sandbox.shared.resolve(relative, write: write, tool: "resolve")
    }
}
