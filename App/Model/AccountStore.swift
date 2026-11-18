import Foundation
import SwiftUI

/// DeepSeek 账号：只保存 API Key（钥匙串），用它换模型列表做一次校验。
@MainActor
final class AccountStore: ObservableObject {
    enum State: Equatable {
        case signedOut
        case checking
        case signedIn([String])
        case failed(String)
    }

    @Published private(set) var state: State = .signedOut
    @Published private(set) var key: String = ""
    @Published var selectedModel: String = "deepseek-chat"
    @Published private(set) var balance: Balance?
    @Published private(set) var balanceError: String?

    private let keychainAccount = "deepseek.apiKey"

    init() {
        if let saved = Keychain.get(keychainAccount), !saved.isEmpty {
            key = saved
            state = .checking
            Task { await refreshModels() }
        }
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    var models: [String] {
        if case .signedIn(let list) = state, !list.isEmpty { return list }
        return ["deepseek-chat", "deepseek-reasoner"]
    }

    func signIn(_ raw: String) async {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .failed("Key 不能为空")
            return
        }
        key = trimmed
        state = .checking
        await refreshModels()
    }

    func signOut() {
        Keychain.delete(keychainAccount)
        key = ""
        state = .signedOut
    }

    func refreshModels() async {
        guard !key.isEmpty else {
            state = .signedOut
            return
        }
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                state = .failed("没有收到宿主的回答")
                return
            }
            if http.statusCode == 401 {
                state = .failed("Key 被拒绝（401）。检查是否复制完整。")
                return
            }
            guard http.statusCode == 200 else {
                state = .failed("DeepSeek 返回 \(http.statusCode)")
                return
            }
            let payload = try JSONDecoder().decode(ModelList.self, from: data)
            let ids = payload.data.map(\.id).filter { $0.hasPrefix("deepseek") }
            Keychain.set(key, for: keychainAccount)
            state = .signedIn(ids.isEmpty ? ["deepseek-chat"] : ids)
            await loadBalance()
            if !ids.contains(selectedModel) {
                selectedModel = ids.first ?? "deepseek-chat"
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    struct Balance: Decodable {
        struct Info: Decodable {
            let currency: String
            let total_balance: String
            let granted_balance: String?
            let topped_up_balance: String?
        }
        let is_available: Bool?
        let balance_infos: [Info]?
    }

    /// DeepSeek 的余额接口：GET /user/balance。
    func loadBalance() async {
        guard !key.isEmpty else { return }
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/user/balance")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                balanceError = "余额接口返回 \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                return
            }
            balance = try JSONDecoder().decode(Balance.self, from: data)
            balanceError = nil
        } catch {
            balanceError = error.localizedDescription
        }
    }

    private struct ModelList: Decodable {
        struct Model: Decodable { let id: String }
        let data: [Model]
    }
}
