import Foundation

/// 本机会话的存储与运行状态。数据落在 Application Support 的 JSON 里，重启还在。
enum TraceKind {
    case thinking
    case generation
    case tool
}

struct TraceStep: Identifiable {
    let id = UUID()
    var label: String
    var kind: TraceKind
    var start: Date
    var end: Date?

    var duration: TimeInterval { (end ?? Date()).timeIntervalSince(start) }
}

struct TurnTrace {
    var startedAt: Date
    var steps: [TraceStep] = []
    var promptTokens = 0
    var completionTokens = 0
    var cacheHit = 0
    var firstTokenAt: Date?

    var elapsed: TimeInterval { Date().timeIntervalSince(startedAt) }

    var modelTime: TimeInterval {
        steps.filter { $0.kind != .tool }.reduce(0) { $0 + $1.duration }
    }

    var toolTime: TimeInterval {
        steps.filter { $0.kind == .tool }.reduce(0) { $0 + $1.duration }
    }
}

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

struct QueuedPrompt: Identifiable {
    let id = UUID()
    var text: String
    var model: String
    var key: String
    var tools: [String]
    var allowsWrite: Bool
    var modeHint: String?
    var sandboxMode: SandboxMode
}

@MainActor
final class LocalStore: ObservableObject {
    @Published private(set) var sessions: [LocalSession] = []
    @Published private(set) var runningID: UUID?
    @Published private(set) var stages: [LocalStage] = []
    @Published private(set) var trace: TurnTrace?
    @Published private(set) var queue: [QueuedPrompt] = []
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
        modeHint: String? = nil,
        sandboxMode: SandboxMode = .workspaceWrite
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
        Sandbox.shared.configure(mode: sandboxMode)
        stages = [.thinking]
        trace = TurnTrace(startedAt: Date(), steps: [
            TraceStep(label: "思考", kind: .thinking, start: Date(), end: nil)
        ])
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

    /// 运行中就排队，空闲就直接发。
    func submit(
        _ text: String,
        in id: UUID,
        model: String,
        key: String,
        tools: [String] = [],
        allowsWrite: Bool = true,
        modeHint: String? = nil,
        sandboxMode: SandboxMode = .workspaceWrite
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard runningID != nil else {
            send(trimmed, in: id, model: model, key: key, tools: tools, allowsWrite: allowsWrite, modeHint: modeHint, sandboxMode: sandboxMode)
            return
        }
        queue.append(
            QueuedPrompt(text: trimmed, model: model, key: key, tools: tools, allowsWrite: allowsWrite, modeHint: modeHint, sandboxMode: sandboxMode)
        )
        Haptics.tap()
    }

    func removeQueued(_ id: UUID) {
        queue.removeAll { $0.id == id }
    }

    func clearQueue() {
        queue.removeAll()
    }

    /// 中断当前轮，然后继续队列。
    func interrupt() {
        task?.cancel()
        task = nil
        if let id = runningID {
            stages.append(.failed("已中断"))
            finishRun(id)
        }
        drainQueue()
    }

    private func drainQueue() {
        guard runningID == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        guard let session = sessions.first(where: { !$0.messages.isEmpty }) ?? sessions.first else { return }
        send(
            next.text,
            in: session.id,
            model: next.model,
            key: next.key,
            tools: next.tools,
            allowsWrite: next.allowsWrite,
            modeHint: next.modeHint,
            sandboxMode: next.sandboxMode
        )
    }

    func stop() {
        task?.cancel()
        task = nil
        if let id = runningID {
            finishRun(id)
        }
    }

    private func closeTraceStep(kind: TraceKind) {
        guard var trace else { return }
        if let index = trace.steps.lastIndex(where: { $0.kind == kind && $0.end == nil }) {
            trace.steps[index].end = Date()
            self.trace = trace
        }
    }

    private func closeOpenTraceSteps() {
        guard var trace else { return }
        let now = Date()
        for index in trace.steps.indices where trace.steps[index].end == nil {
            trace.steps[index].end = now
        }
        self.trace = trace
    }

    private func finishRun(_ id: UUID) {
        closeOpenTraceSteps()
        runningID = nil
        DispatchQueue.main.async { [weak self] in
            self?.drainQueue()
        }
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
        case .usage(let prompt, let completion, let cacheHit):
            trace?.promptTokens = prompt
            trace?.completionTokens = completion
            trace?.cacheHit = cacheHit

        case .delta(let piece):
            if trace?.firstTokenAt == nil {
                trace?.firstTokenAt = Date()
                closeTraceStep(kind: .thinking)
                trace?.steps.append(TraceStep(label: "生成回复", kind: .generation, start: Date(), end: nil))
            }
            if !stages.contains(.streaming) { stages.append(.streaming) }
            if let messageIndex = sessions[index].messages.firstIndex(where: { $0.id == placeholder }) {
                sessions[index].messages[messageIndex].text += piece
            }

        case .toolStarted(let name, _):
            closeTraceStep(kind: .generation)
            trace?.steps.append(TraceStep(label: name, kind: .tool, start: Date(), end: nil))
            stages.append(.tool(name))
            let message = LocalMessage(role: .tool, text: "", toolName: name)
            pendingToolMessage = message.id
            sessions[index].messages.append(message)

        case .toolFinished(_, let output):
            closeTraceStep(kind: .tool)
            if let pending = pendingToolMessage,
               let messageIndex = sessions[index].messages.firstIndex(where: { $0.id == pending }) {
                sessions[index].messages[messageIndex].text = output
            }
            pendingToolMessage = nil

        case .done:
            closeOpenTraceSteps()
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
