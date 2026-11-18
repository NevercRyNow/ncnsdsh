import Foundation

/// 本机会话的存储与运行状态。数据落在 Application Support 的 JSON 里，重启还在。
enum LocalStage: Identifiable, Equatable {
    case thinking
    case streaming
    case tool(String)
    case done
    case failed(String)

    var id: String {
        switch self {
        case .thinking: return "thinking"
        case .streaming: return "streaming"
        case .tool(let name): return "tool-" + name
        case .done: return "done"
        case .failed: return "failed"
        }
    }

    var label: String {
        switch self {
        case .thinking: return "思考"
        case .streaming: return "生成回复"
        case .tool(let name): return "调用 \(name)"
        case .done: return "完成"
        case .failed: return "失败"
        }
    }

    var symbol: String {
        switch self {
        case .thinking: return "brain"
        case .streaming: return "text.alignleft"
        case .tool: return "wrench.and.screwdriver"
        case .done: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        }
    }
}

@MainActor
final class LocalStore: ObservableObject {
    @Published private(set) var sessions: [LocalSession] = []
    @Published private(set) var runningID: UUID?
    @Published private(set) var stages: [LocalStage] = []
    @Published var error: String?

    private var task: Task<Void, Never>?
    private var pendingToolMessage: UUID?
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("NcnsDSH", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("local-sessions.json")
        load()
    }

    // MARK: - Reads

    func session(_ id: UUID) -> LocalSession? {
        sessions.first { $0.id == id }
    }

    var recent: [LocalSession] {
        sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Writes

    @discardableResult
    func createSession(model: String) -> UUID {
        let session = LocalSession(title: "本机会话", model: model)
        sessions.insert(session, at: 0)
        persist()
        return session.id
    }

    func delete(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }

    func compress(_ id: UUID, keep: Int = 12) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let messages = sessions[index].messages
        guard messages.count > keep else { return }
        sessions[index].messages = Array(messages.suffix(keep))
        sessions[index].updatedAt = Date()
        persist()
    }

    func setModel(_ model: String, for id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].model = model
        persist()
    }

    func rename(_ id: UUID, to title: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].title = title
        persist()
    }

    func send(
        _ text: String,
        in id: UUID,
        model: String,
        key: String,
        tools: [String] = [],
        allowsWrite: Bool = true,
        modeHint: String? = nil
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, runningID == nil else { return }
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }

        sessions[index].messages.append(LocalMessage(role: .user, text: trimmed))
        if sessions[index].title == "本机会话" {
            sessions[index].title = String(trimmed.prefix(24))
        }
        sessions[index].updatedAt = Date()

        let history = sessions[index].messages
        let placeholder = LocalMessage(role: .assistant)
        sessions[index].messages.append(placeholder)
        persist()

        runningID = id
        stages = [.thinking]
        error = nil
        pendingToolMessage = nil

        task = Task { [weak self] in
            guard let self else { return }
            do {
                for try await event in LocalEngine.shared.stream(
                    messages: history,
                    model: model,
                    key: key,
                    tools: tools,
                    allowsWrite: allowsWrite,
                    modeHint: modeHint
                ) {
                    if Task.isCancelled { break }
                    self.apply(event, to: id, placeholder: placeholder.id)
                }
            } catch {
                self.error = error.localizedDescription
                self.stages.append(.failed(error.localizedDescription))
            }
            self.finishRun(id)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        if let id = runningID {
            finishRun(id)
        }
    }

    private func finishRun(_ id: UUID) {
        runningID = nil
        if let last = stages.last, last != .done {
            stages.append(.done)
        }
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].updatedAt = Date()
        }
        persist()
    }

    private func apply(_ event: LocalEvent, to id: UUID, placeholder: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }

        switch event {
        case .delta(let piece):
            if !stages.contains(.streaming) { stages.append(.streaming) }
            if let messageIndex = sessions[index].messages.firstIndex(where: { $0.id == placeholder }) {
                sessions[index].messages[messageIndex].text += piece
            }

        case .toolStarted(let name, _):
            stages.append(.tool(name))
            let message = LocalMessage(role: .tool, text: "", toolName: name)
            pendingToolMessage = message.id
            sessions[index].messages.append(message)

        case .toolFinished(_, let output):
            if let pending = pendingToolMessage,
               let messageIndex = sessions[index].messages.firstIndex(where: { $0.id == pending }) {
                sessions[index].messages[messageIndex].text = output
            }
            pendingToolMessage = nil

        case .done:
            stages.append(.done)
            if let messageIndex = sessions[index].messages.firstIndex(where: { $0.id == placeholder }),
               sessions[index].messages[messageIndex].text.isEmpty {
                sessions[index].messages[messageIndex].text = "（模型没有返回内容）"
            }
        }

        sessions[index].updatedAt = Date()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sessions = (try? decoder.decode([LocalSession].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
