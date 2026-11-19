import Foundation

/// DSH Go 插件市场的真实目录。
///
/// 数据来自 `https://go.dshtui.com/market/index.json`（由 `ccch1mneyyy/dsh-go-market`
/// 生成：41 个条目，精确版本，扫描结果写在 audit.json）。App 只读目录，
/// 不安装、不执行插件代码——安装发生在 DSH 那边。
struct MarketPlugin: Identifiable, Decodable, Hashable {
    struct Localized: Decodable, Hashable {
        let zh: String?
        let en: String?
        var display: String { zh ?? en ?? "" }
    }

    struct Meta: Decodable, Hashable {
        let category: String?
    }

    struct Version: Decodable, Hashable {
        let version: String
    }

    let name: String
    let title: Localized
    let description: Localized?
    let homepage: String?
    let metadata: Meta?
    let versions: [Version]

    var id: String { name }
    var version: String { versions.first?.version ?? "—" }
    var categoryKey: String { metadata?.category ?? "other" }
    var categoryLabel: String {
        switch categoryKey {
        case "tools": return "工具"
        case "media": return "媒体"
        case "productivity": return "效率"
        case "communication": return "沟通"
        default: return "其他"
        }
    }
    var homepageURL: URL? { homepage.flatMap(URL.init(string:)) }
}

struct MarketIndex: Decodable {
    let plugins: [MarketPlugin]
}

@MainActor
final class MarketStore: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var plugins: [MarketPlugin] = []
    @Published private(set) var fetchedAt: Date?

    private let endpoint = URL(string: "https://go.dshtui.com/market/index.json")!

    /// 视图在非 MainActor 上下文里建这个对象，显式给出 nonisolated 构造。
    nonisolated init() {}

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await refresh()
    }

    func refresh() async {
        state = .loading
        do {
            var request = URLRequest(url: endpoint)
            request.timeoutInterval = 20
            request.setValue("NcnsDSH/market", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                state = .failed("服务器返回 \( (response as? HTTPURLResponse)?.statusCode ?? 0 )")
                return
            }
            let index = try JSONDecoder().decode(MarketIndex.self, from: data)
            plugins = index.plugins.sorted { $0.title.display.localizedCompare($1.title.display) == .orderedAscending }
            fetchedAt = Date()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    var categories: [(key: String, label: String)] {
        var seen: [(String, String)] = []
        for plugin in plugins where !seen.contains(where: { $0.0 == plugin.categoryKey }) {
            seen.append((plugin.categoryKey, plugin.categoryLabel))
        }
        return seen.sorted { $0.1 < $1.1 }
    }

    func filter(_ query: String, category: String) -> [MarketPlugin] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return plugins.filter { plugin in
            if category != "全部", plugin.categoryKey != category { return false }
            guard !trimmed.isEmpty else { return true }
            let haystack = [
                plugin.name,
                plugin.title.display,
                plugin.title.en ?? "",
                plugin.description?.display ?? ""
            ].joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
