import Foundation

enum LocalEvent {
    case delta(String)
    case toolStarted(name: String, arguments: String)
    case toolFinished(name: String, output: String)
    case done
}

struct LocalEngineError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// 直连 DeepSeek 的最小 agent loop：流式回复 + 工具调用，最多 4 轮。
final class LocalEngine {
    static let shared = LocalEngine()

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private let systemPrompt = """
    你是 NcnsDSH 的本机助手，跑在用户的 iPhone 上。
    你能动的只有 App 的沙盒工作区：list_files / read_file / write_file。
    回答简洁、具体；需要看文件就先调用工具，不要猜内容。用户用中文就回中文。
    """

    func stream(
        messages: [LocalMessage],
        model: String,
        key: String,
        tools: [String],
        allowsWrite: Bool,
        modeHint: String?
    ) -> AsyncThrowingStream<LocalEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await pump(
                        messages: messages,
                        model: model,
                        key: key,
                        tools: tools,
                        allowsWrite: allowsWrite,
                        modeHint: modeHint,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Loop

    private func pump(
        messages: [LocalMessage],
        model: String,
        key: String,
        tools: [String],
        allowsWrite: Bool,
        modeHint: String?,
        continuation: AsyncThrowingStream<LocalEvent, Error>.Continuation
    ) async throws {
        var working = messages
        var rounds = 0

        while rounds < 4 {
            rounds += 1
            if Task.isCancelled { throw CancellationError() }

            let (text, calls) = try await once(
                messages: working,
                model: model,
                key: key,
                tools: tools,
                modeHint: modeHint,
                continuation: continuation
            )

            if calls.isEmpty {
                continuation.yield(.done)
                return
            }

            var assistant = LocalMessage(role: .assistant, text: text)
            assistant.toolCalls = calls
            working.append(assistant)

            for call in calls {
                if Task.isCancelled { throw CancellationError() }
                continuation.yield(.toolStarted(name: call.name, arguments: call.arguments))
                let output = LocalTools.run(name: call.name, arguments: call.arguments, allowsWrite: allowsWrite)
                continuation.yield(.toolFinished(name: call.name, output: output))
                working.append(
                    LocalMessage(role: .tool, text: output, toolCallID: call.id, toolName: call.name)
                )
            }
        }

        continuation.yield(.done)
    }

    // MARK: - One model call

    private func once(
        messages: [LocalMessage],
        model: String,
        key: String,
        tools: [String],
        modeHint: String?,
        continuation: AsyncThrowingStream<LocalEvent, Error>.Continuation
    ) async throws -> (String, [LocalToolCall]) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120

        var body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": wire(messages, modeHint: modeHint),
        ]
        let filtered = LocalTools.definitions(allowing: tools)
        if !filtered.isEmpty {
            body["tools"] = filtered
        }
        body["temperature"] = 0.6
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LocalEngineError(message: "没有收到回答")
        }
        if http.statusCode == 401 {
            throw LocalEngineError(message: "Key 被拒绝（401），去设置里重新登录。")
        }
        if http.statusCode == 429 {
            throw LocalEngineError(message: "请求太频繁（429），等一会儿再试。")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LocalEngineError(message: "DeepSeek 返回 \(http.statusCode)")
        }

        var text = ""
        var calls: [Int: (id: String, name: String, args: String)] = [:]

        for try await line in bytes.lines {
            if Task.isCancelled { throw CancellationError() }
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(Chunk.self, from: data)
            else { continue }

            for choice in chunk.choices {
                if let piece = choice.delta?.content, !piece.isEmpty {
                    text += piece
                    continuation.yield(.delta(piece))
                }
                if let fragments = choice.delta?.tool_calls {
                    for fragment in fragments {
                        let index = fragment.index ?? 0
                        var current = calls[index] ?? (id: "", name: "", args: "")
                        if let id = fragment.id, !id.isEmpty { current.id = id }
                        if let name = fragment.function?.name, !name.isEmpty { current.name = name }
                        if let args = fragment.function?.arguments { current.args += args }
                        calls[index] = current
                    }
                }
            }
        }

        let ordered = calls.sorted { $0.key < $1.key }.map { _, value in
            LocalToolCall(
                id: value.id.isEmpty ? UUID().uuidString : value.id,
                name: value.name,
                arguments: value.args
            )
        }
        return (text, ordered)
    }

    // MARK: - Wire format

    private func wire(_ messages: [LocalMessage], modeHint: String?) -> [[String: Any]] {
        var prompt = systemPrompt
        if let modeHint { prompt += "\n" + modeHint }
        var out: [[String: Any]] = [["role": "system", "content": prompt]]
        for message in messages {
            switch message.role {
            case .user:
                out.append(["role": "user", "content": message.text])
            case .assistant:
                var entry: [String: Any] = ["role": "assistant", "content": message.text]
                if !message.toolCalls.isEmpty {
                    entry["tool_calls"] = message.toolCalls.map { call in
                        [
                            "id": call.id,
                            "type": "function",
                            "function": ["name": call.name, "arguments": call.arguments],
                        ]
                    }
                }
                out.append(entry)
            case .tool:
                out.append([
                    "role": "tool",
                    "tool_call_id": message.toolCallID ?? "",
                    "content": message.text,
                ])
            case .system:
                out.append(["role": "system", "content": message.text])
            }
        }
        return out
    }

    private struct Chunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                struct ToolCall: Decodable {
                    struct Function: Decodable {
                        let name: String?
                        let arguments: String?
                    }
                    let index: Int?
                    let id: String?
                    let function: Function?
                }
                let content: String?
                let tool_calls: [ToolCall]?
            }
            let delta: Delta?
            let finish_reason: String?
        }
        let choices: [Choice]
    }
}
