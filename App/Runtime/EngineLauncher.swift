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

    var runtimeVersion: String? { manifest?.runtimeVersion }
    var nodeVersion: String? { manifest?.nodeVersion }

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
            let result = EngineBridge.shared.start(
                runtime: installer.root,
                guest: guest,
                home: home,
                cache: cache,
                workspace: workspace
            )
            switch result {
            case .success:
                phase = .running(EngineBridge.shared.state() ?? "{\"phase\":\"starting\"}")
            case .failure(let reason):
                phase = .failed(reason)
            }
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func stop() {
        EngineBridge.shared.stop()
        phase = .idle
    }

    func refreshState() {
        guard isRunning, let state = EngineBridge.shared.state() else { return }
        phase = .running(state)
    }
}
