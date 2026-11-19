import Foundation

/// dsh-go 桥的原生客户端（协议来自公开文档 `docs/design/bridge-contract.md`，
/// 这里是按契约自己实现的 Swift 客户端，没有搬运它的 Dart/TS 代码）。
///
/// 现在只做能力协商：连上主机后问一次 `/dsh-go/v1/capabilities`，
/// 用它判断这台主机是「带桥的新版」还是「只有网页的旧版」。
struct BridgeCapabilities: Equatable {
    let protocolVersion: Int
    let bridgeVersion: String
    let capabilities: [String]
}

enum BridgeError: LocalizedError, Equatable {
    case notDshHost
    case oldBridge
    case unauthorized
    case protocolError(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notDshHost: return "这台主机不是 dsh web（没有响应）"
        case .oldBridge: return "旧版 dsh web：没有 /dsh-go/v1 桥"
        case .unauthorized: return "token 被拒绝"
        case .protocolError(let detail): return "协议错误：\(detail)"
        case .transport(let detail): return "连接失败：\(detail)"
        }
    }
}

enum DshBridge {
    private struct Payload: Decodable {
        struct Inner: Decodable {
            let code: String
            let message: String
        }
        let v: Int?
        let bridge: String?
        let capabilities: [String]?
        let error: Inner?
    }

    /// 先按 `?token=` 试，401/403 再按 `Authorization: Bearer` 试一次；
    /// 两条都不通就如实报 token 被拒绝。
    static func capabilities(for host: Host) async throws -> BridgeCapabilities {
        var lastError: BridgeError = .notDshHost

        for style in AuthStyle.allCases {
            do {
                return try await probe(host: host, style: style)
            } catch let error as BridgeError {
                if case .unauthorized = error {
                    lastError = error
                    continue
                }
                throw error
            }
        }
        throw lastError
    }

    private enum AuthStyle: CaseIterable {
        case query
        case bearer
    }

    private static func probe(host: Host, style: AuthStyle) async throws -> BridgeCapabilities {
        guard var components = URLComponents(url: host.baseURL, resolvingAgainstBaseURL: false) else {
            throw BridgeError.transport("地址无法解析")
        }

        var basePath = components.path
        while basePath.hasSuffix("/") { basePath.removeLast() }
        components.path = basePath + "/dsh-go/v1/capabilities"
        if style == .query, !host.token.isEmpty {
            var items = components.queryItems ?? []
            items.removeAll { $0.name == "token" }
            items.append(URLQueryItem(name: "token", value: host.token))
            components.queryItems = items
        } else {
            components.queryItems = components.queryItems?.filter { $0.name != "token" }
        }

        guard let url = components.url else { throw BridgeError.transport("地址无法拼出请求") }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("NcnsDSH/bridge", forHTTPHeaderField: "User-Agent")
        if style == .bearer, !host.token.isEmpty {
            request.setValue("Bearer \(host.token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw BridgeError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw BridgeError.transport("没有 HTTP 响应")
        }

        switch http.statusCode {
        case 401, 403:
            throw BridgeError.unauthorized
        case 404:
            // 文档：只有「无机器码」或 route-not-found 的 404 才代表旧桥/未协商。
            if let payload = try? JSONDecoder().decode(Payload.self, from: data),
               let code = payload.error?.code, code != "route-not-found" {
                throw BridgeError.protocolError(code)
            }
            throw BridgeError.oldBridge
        case 200..<300:
            let payload: Payload
            do {
                payload = try JSONDecoder().decode(Payload.self, from: data)
            } catch {
                throw BridgeError.protocolError("响应不是能力 JSON")
            }
            guard let version = payload.v else {
                throw BridgeError.protocolError("缺少协议主版本 v")
            }
            guard version == 1 else {
                throw BridgeError.protocolError("不支持的协议主版本 \(version)")
            }
            return BridgeCapabilities(
                protocolVersion: version,
                bridgeVersion: payload.bridge ?? "—",
                capabilities: payload.capabilities ?? []
            )
        default:
            if let payload = try? JSONDecoder().decode(Payload.self, from: data),
               let message = payload.error?.message {
                throw BridgeError.protocolError("\(payload.error?.code ?? "http-\(http.statusCode)")：\(message)")
            }
            throw BridgeError.protocolError("HTTP \(http.statusCode)")
        }
    }
}
