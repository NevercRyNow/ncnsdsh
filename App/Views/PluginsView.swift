import SwiftUI
import UIKit

struct PluginsView: View {
    @EnvironmentObject private var store: PluginStore
    @EnvironmentObject private var hosts: HostStore
    @StateObject private var market = MarketStore()

    enum Segment: String, CaseIterable {
        case installed = "已安装"
        case market = "市场"
    }

    @State private var segment: Segment = .installed
    @State private var query = ""
    @State private var category = "全部"
    @State private var installing: Set<String> = []
    @State private var marketCategory = "全部"
    @State private var copiedPackage: String?
    @State private var webHost: Host?
    @State private var showNeedHost = false
    @State private var pendingInstall: MarketPlugin?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundStyle(DSH.Palette.tertiary)
                        TextField("搜索插件、厂商或分类", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(DSH.TypeScale.callout)
                            .foregroundStyle(DSH.Palette.text)
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(DSH.Palette.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    chips

                    Picker("", selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    if segment == .installed {
                        list(filter(store.installed), empty: query.isEmpty ? "还没有装插件。去市场看看。" : "没有匹配的已安装插件。")
                    } else {
                        marketSection
                    }
                }
                .padding(.horizontal, DSH.Inset.gutter)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .sheet(item: $webHost) { host in
                WebScreen(host: host)
            }
            .alert("安装要在主机上完成", isPresented: $showNeedHost) {
                Button("复制包名") {
                    if let plugin = pendingInstall {
                        UIPasteboard.general.string = "\(plugin.name)@\(plugin.version)"
                    }
                }
                Button("好", role: .cancel) {}
            } message: {
                Text("插件跑在 DSH 主机上，App 不能替你安装。先在「更多 → 设备」连一台主机，之后按「安装」会直接打开那台机器的 DSH。")
            }
            .navigationTitle("插件")
            .navigationBarTitleDisplayMode(.large)
            .task(id: segment) {
                if segment == .market { await market.loadIfNeeded() }
            }
        }
    }

    // MARK: - Market（真实目录）

    /// 市场数据来自 go.dshtui.com/market/index.json；App 只展示，不安装、不执行。
    @ViewBuilder
    private var marketSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch market.state {
            case .idle, .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在读取插件市场…")
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.secondary)
                }
                .padding(.vertical, 20)

            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text("市场暂时读不到")
                        .font(DSH.TypeScale.headline)
                        .foregroundStyle(DSH.Palette.text)
                    Text(message)
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.tertiary)
                    Button("重试") { Task { await market.refresh() } }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DSH.Palette.accent)
                }
                .padding(.vertical, 16)

            case .loaded:
                marketChips

                let items = market.filter(query, category: marketCategory)
                if items.isEmpty {
                    Text("没有匹配的插件。")
                        .font(DSH.TypeScale.callout)
                        .foregroundStyle(DSH.Palette.secondary)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(items) { plugin in
                            marketRow(plugin)
                            if plugin.id != items.last?.id {
                                Divider().overlay(DSH.Palette.hairline).padding(.leading, 62)
                            }
                        }
                    }
                    .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let fetchedAt = market.fetchedAt {
                    Text("\(market.plugins.count) 个条目 · 目录更新于 \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 10))
                        .foregroundStyle(DSH.Palette.tertiary)
                }
            }
        }
    }

    private var marketChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chipButton("全部", key: "全部")
                ForEach(market.categories, id: \.key) { item in
                    chipButton(item.label, key: item.key)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func chipButton(_ title: String, key: String) -> some View {
        Button {
            Haptics.tap()
            marketCategory = key
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(marketCategory == key ? Color.black : DSH.Palette.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(marketCategory == key ? Color.white : DSH.Palette.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func marketRow(_ plugin: MarketPlugin) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(plugin.title.display.prefix(1)))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Fluid.Palette.iceBlue.opacity(0.22), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(plugin.title.display)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Fluid.Palette.text)
                        .lineLimit(1)
                    Text(plugin.version)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Fluid.Palette.slate)
                    Spacer(minLength: 4)
                    Text(plugin.categoryLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Fluid.Palette.mist)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Fluid.Palette.graphite, in: Capsule())
                }

                Text(plugin.description?.display ?? "")
                    .font(Fluid.Typography.caption)
                    .foregroundStyle(Fluid.Palette.mist)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    // 安装这件事属于主机上的 DSH，App 只是客户端：
                    // 有主机就打开主机的 DSH 页面去装，没有主机就说明清楚并给出包名。
                    Button {
                        Haptics.tap()
                        if let host = hosts.current {
                            webHost = host
                        } else {
                            pendingInstall = plugin
                            showNeedHost = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("安装")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Fluid.Palette.iceBlue, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIPasteboard.general.string = "\(plugin.name)@\(plugin.version)"
                        Haptics.tap()
                        copiedPackage = plugin.id
                        Task {
                            try? await Task.sleep(nanoseconds: 1_400_000_000)
                            if copiedPackage == plugin.id { copiedPackage = nil }
                        }
                    } label: {
                        Text(copiedPackage == plugin.id ? "已复制" : "复制包名")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(copiedPackage == plugin.id ? Fluid.Palette.mint : Fluid.Palette.mist)
                    }
                    .buttonStyle(.plain)

                    if let url = plugin.homepageURL {
                        Link(destination: url) {
                            Text("主页 ↗").font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Fluid.Palette.mist)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
    }

    private var categories: [String] {
        ["全部"] + Array(Set(DSHPlugin.catalog.map(\.category))).sorted()
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { item in
                    Button {
                        Haptics.tap()
                        category = item
                    } label: {
                        Text(item)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(category == item ? Color.black : DSH.Palette.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(category == item ? Color.white : DSH.Palette.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func filter(_ plugins: [DSHPlugin]) -> [DSHPlugin] {
        let key = query.trimmingCharacters(in: .whitespaces)
        return plugins.filter { plugin in
            let categoryOK = category == "全部" || plugin.category == category
            let queryOK = key.isEmpty
                || plugin.name.localizedCaseInsensitiveContains(key)
                || plugin.summary.localizedCaseInsensitiveContains(key)
                || plugin.vendor.localizedCaseInsensitiveContains(key)
                || plugin.category.contains(key)
            return categoryOK && queryOK
        }
    }

    @ViewBuilder
    private func list(_ plugins: [DSHPlugin], empty: String) -> some View {
        if plugins.isEmpty {
            Text(empty)
                .font(DSH.TypeScale.callout)
                .foregroundStyle(DSH.Palette.secondary)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(plugins) { plugin in
                    row(plugin)
                    if plugin.id != plugins.last?.id {
                        Divider().overlay(DSH.Palette.hairline).padding(.leading, 70)
                    }
                }
            }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func row(_ plugin: DSHPlugin) -> some View {
        let isInstalling = installing.contains(plugin.id)

        return HStack(alignment: .top, spacing: 12) {
            Text(plugin.glyph)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(tileColor(plugin), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(plugin.name)
                        .font(DSH.TypeScale.headline)
                        .foregroundStyle(DSH.Palette.text)
                        .lineLimit(1)
                    if plugin.official {
                        badge("官方", color: DSH.Palette.accent)
                    }
                    if plugin.recommended {
                        badge("推荐", color: DSH.Palette.warning)
                    }
                }

                Text(plugin.summary)
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text("\(plugin.vendor) · v\(plugin.version)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DSH.Palette.tertiary)
                    badge(plugin.risk.label, color: riskColor(plugin.risk))
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 6)

            Button {
                install(plugin)
            } label: {
                Text(isInstalling ? "安装中" : (plugin.installed ? "已安装" : "获取"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(plugin.installed ? DSH.Palette.secondary : .white)
                    .frame(width: 62)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(plugin.installed || isInstalling ? DSH.Palette.raised : DSH.Palette.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isInstalling)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .contextMenu {
            if !plugin.permissions.isEmpty {
                Text("权限：" + plugin.permissions.joined(separator: "、"))
            }
            Text(plugin.risk.label + " · 由声明的权限推导")
            Button(plugin.installed ? "移除" : "安装") {
                store.toggle(plugin)
            }
        }
    }

    private func install(_ plugin: DSHPlugin) {
        guard !plugin.installed else {
            store.toggle(plugin)
            Haptics.tap()
            return
        }
        guard !installing.contains(plugin.id) else { return }
        installing.insert(plugin.id)
        Haptics.light()
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            store.toggle(plugin)
            installing.remove(plugin.id)
            Haptics.success()
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    private func riskColor(_ risk: PluginRisk) -> Color {
        switch risk {
        case .low: return DSH.Palette.success
        case .medium: return DSH.Palette.warning
        case .high: return DSH.Palette.danger
        }
    }

    private func tileColor(_ plugin: DSHPlugin) -> Color {
        switch plugin.category {
        case "开发": return Color(red: 0.18, green: 0.42, blue: 0.62)
        case "创作": return Color(red: 0.45, green: 0.27, blue: 0.42)
        case "连接": return Color(red: 0.20, green: 0.45, blue: 0.40)
        case "本机": return Color(red: 0.32, green: 0.30, blue: 0.55)
        case "文档": return Color(red: 0.55, green: 0.38, blue: 0.18)
        default: return Color(red: 0.26, green: 0.28, blue: 0.32)
        }
    }
}
