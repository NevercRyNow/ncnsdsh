import SwiftUI

struct PluginsView: View {
    @EnvironmentObject private var store: PluginStore

    enum Segment: String, CaseIterable {
        case installed = "已安装"
        case market = "商店"
    }

    @State private var segment: Segment = .installed
    @State private var query = ""
    @State private var category = "全部"
    @State private var installing: Set<String> = []

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
                        list(filter(store.installed), empty: query.isEmpty ? "还没有装插件。去商店看看。" : "没有匹配的已安装插件。")
                    } else {
                        list(filter(store.store), empty: query.isEmpty ? "商店里的都装上了。" : "没有匹配的插件。")
                    }
                }
                .padding(.horizontal, DSH.Inset.gutter)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("插件")
            .navigationBarTitleDisplayMode(.large)
        }
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
