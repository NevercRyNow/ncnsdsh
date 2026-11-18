import Foundation

/// 远程可达性探测：只做真实的 HTTP 探测，不猜协议。
struct RemoteProbeResult {
    let reachable: Bool
    let statusCode: Int
    let latencyMS: Int
    let detail: String
}

enum RemoteProbe {
    static func probe(_ host: Host) async -> RemoteProbeResult {
        var request = URLRequest(url: host.webURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("NcnsDSH/\(Bundle.main.appVersion)", forHTTPHeaderField: "User-Agent")

        let started = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            guard let http = response as? HTTPURLResponse else {
                return RemoteProbeResult(reachable: false, statusCode: 0, latencyMS: ms, detail: "没有 HTTP 响应")
            }
            let ok = (200..<400).contains(http.statusCode)
            return RemoteProbeResult(
                reachable: ok,
                statusCode: http.statusCode,
                latencyMS: ms,
                detail: ok ? "HTTP \(http.statusCode) · \(ms) ms" : "HTTP \(http.statusCode)"
            )
        } catch {
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            return RemoteProbeResult(reachable: false, statusCode: 0, latencyMS: ms, detail: error.localizedDescription)
        }
    }
}
