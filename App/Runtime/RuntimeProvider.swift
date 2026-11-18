import Foundation

enum RuntimeKind: String, CaseIterable, Identifiable {
    case native
    case linux
    case remote

    var id: String { rawValue }

    var title: String {
        switch self {
        case .native: return "原生运行时"
        case .linux: return "Linux 运行时"
        case .remote: return "远程运行时"
        }
    }

    var symbol: String {
        switch self {
        case .native: return "cpu"
        case .linux: return "server.rack"
        case .remote: return "desktopcomputer"
        }
    }
}

enum RuntimeState: Equatable {
    case notInstalled
    case running
    case stopped
    case unsupported(String)
    case failed(String)

    var label: String {
        switch self {
        case .notInstalled: return "未安装"
        case .running: return "运行中"
        case .stopped: return "已停止"
        case .unsupported(let reason): return "不可用 · " + reason
        case .failed(let reason): return "失败 · " + reason
        }
    }

    var isRunning: Bool { self == .running }
}

struct RuntimeStatus {
    let kind: RuntimeKind
    let state: RuntimeState
    let version: String
    let detail: String
}

enum RuntimeError: LocalizedError {
    case unsupported(String)
    case notRunning

    var errorDescription: String? {
        switch self {
        case .unsupported(let reason): return reason
        case .notRunning: return "运行时没有在跑"
        }
    }
}

/// 所有执行环境共用的协议。不支持的能力必须返回 unsupported，不许假装成功。
protocol RuntimeProvider {
    var kind: RuntimeKind { get }
    func status() -> RuntimeStatus
    func start() async throws
    func stop() async throws
    func pause() async throws
    func resume() async throws
    func install() async throws
    func upgrade() async throws
    func execute(_ command: String) async throws -> String
    func diagnostics() -> [String: String]
}

// MARK: - Native

/// 原生运行时：Swift 工具 + iOS 沙盒。这是唯一真正可执行的环境。
final class NativeRuntime: RuntimeProvider {
    let kind: RuntimeKind = .native
    private var running = true

    func status() -> RuntimeStatus {
        RuntimeStatus(
            kind: .native,
            state: running ? .running : .stopped,
            version: Bundle.main.appVersion,
            detail: "\(LocalTools.names.count) 个工具 · 沙箱 \(Sandbox.shared.policy.mode.title)"
        )
    }

    func start() async throws { running = true }
    func stop() async throws { running = false }
    func pause() async throws { running = false }
    func resume() async throws { running = true }
    func install() async throws { running = true }

    func upgrade() async throws {
        throw RuntimeError.unsupported("原生运行时随 App 更新，不能独立升级")
    }

    func execute(_ command: String) async throws -> String {
        throw RuntimeError.unsupported("原生运行时只接受工具调用，不执行任意命令")
    }

    func diagnostics() -> [String: String] {
        [
            "工具数量": "\(LocalTools.names.count)",
            "沙箱模式": Sandbox.shared.policy.mode.rawValue,
            "沙箱拒绝": "\(Sandbox.shared.denialCount)",
            "工作区": AppFiles.workspace.lastPathComponent
        ]
    }
}

// MARK: - Linux

/// Linux 运行时：iOS 上没有可用实现。
/// dsh-Go 的 guest rootfs 在源码里标注「Apple SDK 编译与真机执行未验证」，
/// 我们没有可用的 ARM64 rootfs 与内核访问，所以这里只能是 unsupported。
final class LinuxRuntime: RuntimeProvider {
    let kind: RuntimeKind = .linux

    private let reason = "iOS 没有可用的 Linux guest"

    func status() -> RuntimeStatus {
        RuntimeStatus(kind: .linux, state: .unsupported(reason), version: "—", detail: "不安装 rootfs，不伪造 Shell")
    }

    func start() async throws { throw RuntimeError.unsupported(reason) }
    func stop() async throws { throw RuntimeError.unsupported(reason) }
    func pause() async throws { throw RuntimeError.unsupported(reason) }
    func resume() async throws { throw RuntimeError.unsupported(reason) }
    func install() async throws { throw RuntimeError.unsupported(reason) }
    func upgrade() async throws { throw RuntimeError.unsupported(reason) }
    func execute(_ command: String) async throws -> String { throw RuntimeError.unsupported(reason) }

    func diagnostics() -> [String: String] {
        ["状态": reason, "来源": "dsh-Go feat/ios-foundation（未验证）"]
    }
}

// MARK: - Remote

/// 远程运行时：宿主连接存在，但 dsh_client 协议尚未接入。
final class RemoteRuntime: RuntimeProvider {
    let kind: RuntimeKind = .remote
    private var host: Host?
    private var lastProbe: RemoteProbeResult?

    func update(host: Host?) {
        self.host = host
    }

    /// 真实 HTTP 探测：只证明「这张地址现在通不通」，不证明协议已接入。
    func probe() async -> RemoteProbeResult? {
        guard let host else { return nil }
        let result = await RemoteProbe.probe(host)
        lastProbe = result
        return result
    }

    func status() -> RuntimeStatus {
        guard let host else {
            return RuntimeStatus(kind: .remote, state: .unsupported("未添加主机"), version: "—", detail: "先配对一台电脑或服务器")
        }
        let state: RuntimeState
        if let probe = lastProbe, probe.reachable {
            state = .unsupported("协议未接入")
        } else if let probe = lastProbe {
            state = .failed("不可达 · \(probe.detail)")
        } else {
            state = .unsupported("未探测")
        }
        return RuntimeStatus(
            kind: .remote,
            state: state,
            version: "未探测",
            detail: host.originText + (lastProbe.map { " · \($0.detail)" } ?? "")
        )
    }

    func start() async throws {
        guard host != nil else { throw RuntimeError.unsupported("先配对一台电脑或服务器") }
        let result = await probe()
        guard result?.reachable == true else {
            throw RuntimeError.unsupported("无法连接：\(result?.detail ?? "未探测")")
        }
        throw RuntimeError.unsupported("地址可达，但 session/follow 协议尚未接入")
    }
    func stop() async throws { throw RuntimeError.unsupported("远程协议尚未接入") }
    func pause() async throws { throw RuntimeError.unsupported("远程协议尚未接入") }
    func resume() async throws { throw RuntimeError.unsupported("远程协议尚未接入") }
    func install() async throws { throw RuntimeError.unsupported("远程环境由服务器自己安装") }
    func upgrade() async throws { throw RuntimeError.unsupported("远程环境由服务器自己升级") }
    func execute(_ command: String) async throws -> String { throw RuntimeError.unsupported("远程执行尚未接入") }

    func diagnostics() -> [String: String] {
        ["主机": host?.displayName ?? "—", "协议": "session/follow 未接入"]
    }
}

// MARK: - Manager

@MainActor
final class RuntimeManager: ObservableObject {
    private let native = NativeRuntime()
    private let linux = LinuxRuntime()
    private let remote = RemoteRuntime()

    @Published private(set) var statuses: [RuntimeStatus] = []

    init() {
        refresh()
    }

    func refresh(host: Host? = nil) {
        if let host { remote.update(host: host) }
        statuses = [native.status(), linux.status(), remote.status()]
    }

    func provider(for kind: RuntimeKind) -> RuntimeProvider {
        switch kind {
        case .native: return native
        case .linux: return linux
        case .remote: return remote
        }
    }
}
