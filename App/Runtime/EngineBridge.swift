import Foundation
import Darwin

/// 内置引擎（dsh-Go 的 iOS host）的加载器。
///
/// 刻意用 `dlopen`/`dlsym` 而不是链接：没把引擎打进包时，App 照常能编、能跑，
/// 只是这里如实报「未嵌入」，而不是链接期就炸。
///
/// C 接口来自 dsh-Go `runtime/ios/host/ios_host.cc`（AGPL-3.0，见 NOTICE）：
///
///     int   dsh_host_start(const char* runtime_root, const char* guest_root,
///                          const char* dsh_home, const char* cache_dir,
///                          const char* native_library_dir, const char* workspace,
///                          int env_count, const char** env_keys,
///                          const char** env_values,
///                          char** error_code, char** error_message);
///     void  dsh_host_stop(void);
///     char* dsh_host_state(void);
///     char* dsh_host_drain(void);
///     void  dsh_host_free(char*);
struct EngineStartError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class EngineBridge {
    enum Status: Equatable {
        case notBundled
        case loaded(version: String)
        case failed(String)
    }

    static let shared = EngineBridge()

    private var handle: UnsafeMutableRawPointer?
    private(set) var status: Status = .notBundled

    private typealias StartFn = @convention(c) (
        UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?,
        UnsafePointer<CChar>?, UnsafePointer<CChar>?, UnsafePointer<CChar>?,
        Int32, UnsafeMutablePointer<UnsafePointer<CChar>?>?,
        UnsafeMutablePointer<UnsafePointer<CChar>?>?,
        UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?,
        UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
    ) -> Int32
    private typealias StopFn = @convention(c) () -> Void
    private typealias StateFn = @convention(c) () -> UnsafeMutablePointer<CChar>?
    private typealias FreeFn = @convention(c) (UnsafeMutablePointer<CChar>?) -> Void

    private var startFn: StartFn?
    private var stopFn: StopFn?
    private var stateFn: StateFn?
    private var freeFn: FreeFn?

    private init() {
        load()
    }

    /// 应用启动时调用一次：把 framework 装进来，确认 C 符号齐全。
    func load() {
        guard handle == nil else { return }

        guard let frameworks = Bundle.main.privateFrameworksPath else {
            status = .failed("包内没有 Frameworks 目录")
            return
        }
        let binary = frameworks + "/DshNodeHost.framework/DshNodeHost"
        guard FileManager.default.fileExists(atPath: binary) else {
            status = .notBundled
            return
        }

        guard let dl = dlopen(binary, RTLD_NOW) else {
            let reason = dlerror().map { String(cString: $0) } ?? "unknown"
            status = .failed("dlopen 失败：\(reason)")
            return
        }

        guard let start = dlsym(dl, "dsh_host_start"),
              let stop = dlsym(dl, "dsh_host_stop"),
              let state = dlsym(dl, "dsh_host_state") else {
            dlclose(dl)
            status = .failed("framework 里没有 dsh_host_start / stop / state")
            return
        }

        handle = dl
        startFn = unsafeBitCast(start, to: StartFn.self)
        stopFn = unsafeBitCast(stop, to: StopFn.self)
        stateFn = unsafeBitCast(state, to: StateFn.self)
        if let freed = dlsym(dl, "dsh_host_free") {
            freeFn = unsafeBitCast(freed, to: FreeFn.self)
        }

        let version = (Bundle(path: frameworks + "/DshNodeHost.framework")?
            .infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
        status = .loaded(version: version)
    }

    var isReady: Bool {
        if case .loaded = status { return true }
        return false
    }

    /// 启动引擎。路径语义与 dsh-Go 的 `EngineChannel.begin` 一致：
    /// runtime 是解出来的 runtime 树，frameworks 由 Bundle 提供，workspace 是会话可写的根。
    func start(runtime: URL, guest: URL?, home: URL, cache: URL, workspace: URL) throws {
        guard let startFn, let frameworks = Bundle.main.privateFrameworksPath else {
            throw EngineStartError(message: "引擎未加载")
        }
        var code: UnsafeMutablePointer<CChar>?
        var message: UnsafeMutablePointer<CChar>?
        let guestPath = guest?.path ?? ""

        let result = frameworks.withCString { fw in
            runtime.path.withCString { rt in
                guestPath.withCString { gr in
                    home.path.withCString { hm in
                        cache.path.withCString { ca in
                            workspace.path.withCString { ws in
                                startFn(rt, gr, hm, ca, fw, ws, 0, nil, nil, &code, &message)
                            }
                        }
                    }
                }
            }
        }

        if result != 0 {
            let reason = message.map { String(cString: $0) } ?? "启动失败"
            let id = code.map { String(cString: $0) } ?? "ios_native_start"
            free(code)
            free(message)
            throw EngineStartError(message: "\(id)：\(reason)")
        }
    }

    /// 引擎当前的 JSON 状态（没有引擎或没启动时返回 nil）。
    func state() -> String? {
        guard let stateFn else { return nil }
        guard let pointer = stateFn() else { return nil }
        defer { freeFn?(pointer) }
        return String(cString: pointer)
    }

    func stop() {
        stopFn?()
    }
}
