import Foundation

/// 把「解 runtime + 起引擎」这两步串起来。
///
/// 所有路径都落在 App 自己的容器里：App Support 放 runtime 树与引擎 home，
/// Caches 放引擎缓存，workspace 用 App 的工作区目录。失败原样抛出原因，不吞。
@MainActor
final class EngineLauncher: ObservableObject {
    enum Phase: Equatable {
        case idle
        case installing(Double)
        case starting
        case running(String)
        case failed(String)
    }

    static let shared = EngineLauncher()

    @Published private(set) var phase: Phase = .idle

    private var installer: RuntimeInstaller?
    private var manifest: RuntimeManifest?

    /// 视图在非 MainActor 上下文里建这个对象。
    nonisolated init() {}

    private var support: URL {
        URL.applicationSupportDirectory.appendingPathComponent("Engine", isDirectory: true)
    }
    private var cache: URL {
        URL.cachesDirectory.appendingPathComponent("Engine", isDirectory: true)
    }
    private var home: URL { support.appendingPathComponent("home", isDirectory: true) }
    private var guest: URL? {
        let url = support.appendingPathComponent("guest", isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// 引擎自己报的状态（dsh_host_state 的 JSON 解出来的）。
    struct EngineState: Equatable {
        var phase = ""
        var baseURL: URL?
        var token = ""
        var errorCode = ""
        var errorMessage = ""
    }

    @Published private(set) var state = EngineState()

    var runtimeVersion: String? { manifest?.runtimeVersion }
    var nodeVersion: String? { manifest?.nodeVersion }
    var fileCount: Int? { manifest?.files.count }

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    /// 随包的 runtime.zip。没有就说明这个包是远程专用包。
    private var bundledArchive: URL? {
        Bundle.main.url(forResource: "runtime", withExtension: "zip")
    }

    var archiveAvailable: Bool { bundledArchive != nil }

    func start(workspace: URL) async {
        guard EngineBridge.shared.isReady else {
            phase = .failed("这个包没有内置引擎二进制")
            return
        }
        guard let archive = bundledArchive else {
            phase = .failed("这个包没有随附 runtime.zip")
            return
        }

        do {
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)

            phase = .installing(0)
            let installer = RuntimeInstaller(base: support)
            // 45MB / 一万多个文件，解压不能占着主线程，否则界面会整段卡死。
            let manifest = try await Task.detached(priority: .userInitiated) {
                try installer.install(from: archive)
            }.value
            self.installer = installer
            self.manifest = manifest

            phase = .starting
            try EngineBridge.shared.start(
                runtime: installer.root,
                guest: guest,
                home: home,
                cache: cache,
                workspace: workspace
            )
            let raw = EngineBridge.shared.state() ?? "{}"
            state = Self.parse(raw)
            phase = .running(raw)
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// 删掉已解出的 runtime 树，下次启动重新解一遍。用来处理「解压到一半」的状态。
    func forgetRuntime() {
        let fm = FileManager.default
        try? fm.removeItem(at: support.appendingPathComponent("tree", isDirectory: true))
        try? fm.removeItem(at: support.appendingPathComponent("version.txt"))
        manifest = nil
        phase = .idle
    }

    func stop() {
        EngineBridge.shared.stop()
        phase = .idle
    }

    /// 拉一次事件（dsh_host_drain），返回原始 JSON 文本。
    func drain() -> String? { EngineBridge.shared.drain() }

    func refreshState() {
        guard isRunning, let raw = EngineBridge.shared.state() else { return }
        state = Self.parse(raw)
        phase = .running(raw)
    }

    /// 状态就是一行 JSON：phase / baseUrl / token / errorCode / errorMessage / exitCode。
    static func parse(_ raw: String) -> EngineState {
        var result = EngineState()
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return result }
        result.phase = object["phase"] as? String ?? ""
        result.token = object["token"] as? String ?? ""
        result.errorCode = object["errorCode"] as? String ?? ""
        result.errorMessage = object["errorMessage"] as? String ?? ""
        if let text = object["baseUrl"] as? String, !text.isEmpty {
            result.baseURL = URL(string: text)
        }
        return result
    }

    /// 用引擎自己给的 baseUrl + token 探测 /dsh-go/v1/capabilities。
    func probeBridge() async -> String {
        guard let url = state.baseURL else { return "引擎还没报出地址" }
        let host = Host(id: UUID(), name: "内置引擎", baseURL: url, token: state.token)
        do {
            let caps = try await DshBridge.capabilities(for: host)
            return "协议 v\(caps.protocolVersion) · bridge \(caps.bridgeVersion) · \(caps.capabilities.count) 项能力"
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
