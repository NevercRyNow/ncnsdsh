import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: HostStore
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var local: LocalStore
    @EnvironmentObject private var phone: PhoneAuth
    @EnvironmentObject private var plugins: PluginStore
    @EnvironmentObject private var settings: SettingsStore

    /// 和「更多」一样：一个 item sheet，而不是八个 .sheet(isPresented:) 抢同一层。
    private enum Panel: String, Identifiable {
        case account, phone, about, connect, plugins, automation, advanced, web
        var id: String { rawValue }
    }

    @State private var panel: Panel?


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    accountRow
                    section("通用") { appearanceGroup }
                    section("连接") { hostGroup }
                    section("能力") { entryGroup }
                    backgroundGroup
                    widgetGroup
                    section("关于") { tailGroup }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $panel) { panel in
            switch panel {
            case .account:
                AccountView().environmentObject(account)
            case .phone:
                PhoneLoginView().environmentObject(phone)
            case .about:
                AboutView()
            case .connect:
                ConnectView().environmentObject(store)
            case .plugins:
                PluginsView().environmentObject(plugins).environmentObject(store)
            case .automation:
                ScheduleView().environmentObject(demo)
            case .advanced:
                advancedSheet
            case .web:
                if let host = store.current {
                    WebScreen(host: host)
                }
            }
        }
    }

    // MARK: - Account

    private var accountRow: some View {
        Button {
            Haptics.tap()
            panel = .account
        } label: {
            HStack(spacing: 12) {
                Image(systemName: account.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                    .font(.system(size: 30))
                    .foregroundStyle(account.isSignedIn ? DSH.Palette.accent : DSH.Palette.tertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.isSignedIn ? "已登录 DeepSeek" : "登录 DeepSeek")
                        .font(DSH.TypeScale.headline)
                        .foregroundStyle(DSH.Palette.text)
                    Text(account.isSignedIn ? balanceLine : "账号与余额 · 未登录")
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DSH.Palette.tertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var balanceLine: String {
        guard let info = account.balance?.balance_infos?.first else { return "账号与余额" }
        let symbol = info.currency.uppercased() == "CNY" ? "¥" : "$"
        return "余额 \(symbol)\(info.total_balance)"
    }

    // MARK: - Entries

    private var entryGroup: some View {
        VStack(spacing: 0) {
            row(icon: "puzzlepiece.extension", title: "插件", value: "\(plugins.installed.count) 个") {
                panel = .plugins
            }
            divider
            row(icon: "arrow.triangle.2.circlepath", title: "自动化", value: "\(demo.schedules.count) 个") {
                panel = .automation
            }
            divider
            row(icon: "iphone", title: "手机号", value: phone.signedIn ? phone.masked : "未登录") {
                panel = .phone
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var backgroundGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("后台运行")

            VStack(spacing: 0) {
                toggleRow(icon: "speaker.slash", title: "静音音频", isOn: $settings.silentAudio)
                divider
                toggleRow(icon: "hourglass", title: "任务续跑", isOn: $settings.keepRunning)
            }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("离开 App 后播放无声音频，任务、自动化和开发服务器都不停，会多耗一些电。音频被来电等打断时，进行中的任务仍会继续跑完。")
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    private var widgetGroup: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("小组件")

            toggleRow(icon: "eye", title: "显示会话标题", isOn: $settings.showSessionTitles)
                .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("关掉后，主屏幕和锁屏小组件只显示数量和状态。设备锁定时，标题总会被打码。")
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    private var appearanceGroup: some View {
        VStack(spacing: 0) {
            menuRow(icon: "circle.lefthalf.filled", title: "外观", value: settings.appearance.label) {
                ForEach(SettingsStore.Appearance.allCases) { item in
                    Button(item.label) { settings.appearance = item }
                }
            }
            divider
            menuRow(icon: "globe", title: "语言", value: settings.language.label) {
                ForEach(SettingsStore.Language.allCases) { item in
                    Button(item.label) { settings.language = item }
                }
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var hostGroup: some View {
        VStack(spacing: 0) {
            row(icon: "desktopcomputer", title: "远端宿主", value: store.current?.displayName ?? "未连接") {
                panel = .connect
            }
            divider
            row(icon: "folder", title: "文件", value: AppFiles.displayPath) {
                AppFiles.reveal()
            }
            if store.current != nil {
                divider
                row(icon: "globe", title: "网页版", value: "插件页 / 终端") {
                    panel = .web
                }
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tailGroup: some View {
        VStack(spacing: 0) {
            row(icon: "screwdriver", title: "高级", value: "") {
                panel = .advanced
            }
            divider
            row(icon: "info.circle", title: "关于", value: Bundle.main.appVersion) {
                panel = .about
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Advanced

    private var advancedSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    infoLine("版本", Bundle.main.appVersion)
                    infoLine("本机工作区", AppFiles.workspace.path)
                    infoLine("构建产物", AppFiles.builds.path)
                    infoLine("宿主", store.current?.originText ?? "—")
                    infoLine("插件", "\(plugins.installed.count) 装 / \(plugins.store.count) 可装")
                    infoLine("本机会话", "\(local.recent.count) 个")
                    infoLine("外观", settings.appearance.label)
                    infoLine("语言", settings.language.label)
                    infoLine("后台音频", settings.silentAudio ? "开" : "关")
                    infoLine("沙箱模式", Sandbox.shared.policy.mode.title)
                    infoLine("沙箱拒绝次数", "\(Sandbox.shared.denialCount)")

                    if !Sandbox.shared.audit.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("最近的文件操作")
                                .font(DSH.TypeScale.footnote)
                                .foregroundStyle(DSH.Palette.tertiary)

                            ForEach(Sandbox.shared.audit.suffix(8).reversed()) { entry in
                                HStack(spacing: 8) {
                                    Text(entry.tool)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(DSH.Palette.secondary)
                                        .frame(width: 96, alignment: .leading)
                                    Text(entry.path)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(DSH.Palette.tertiary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(label(for: entry.outcome))
                                        .font(.system(size: 9))
                                        .foregroundStyle(tint(for: entry.outcome))
                                }
                            }
                        }
                        .padding(14)
                        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(DSH.Palette.canvas)
            .navigationTitle("高级")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { panel = nil }
                }
            }
        }
    }

    private func label(for outcome: SandboxAuditEntry.Outcome) -> String {
        switch outcome {
        case .allowed: return "允许"
        case .denied(let reason): return "拒绝 · " + reason
        }
    }

    private func tint(for outcome: SandboxAuditEntry.Outcome) -> Color {
        switch outcome {
        case .allowed: return DSH.Palette.success
        case .denied: return DSH.Palette.danger
        }
    }

    private func infoLine(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.tertiary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DSH.Palette.text)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Pieces

    /// 分区标题 + 内容。设置页按「通用 / 连接 / 能力 / 后台 / 小组件 / 关于」排，
    /// 不是把七组卡片平铺成一个长列表。
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            content()
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(DSH.TypeScale.footnote)
            .foregroundStyle(DSH.Palette.tertiary)
            .padding(.horizontal, 4)
    }

    private var divider: some View {
        Rectangle()
            .fill(DSH.Palette.hairline)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    private func row(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DSH.Palette.text)
                    .frame(width: 26)

                Text(title)
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)

                Spacer(minLength: 8)

                Text(value)
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.tertiary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DSH.Palette.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DSH.Palette.text)
                .frame(width: 26)

            Text(title)
                .font(DSH.TypeScale.body)
                .foregroundStyle(DSH.Palette.text)

            Spacer()

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(DSH.Palette.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func menuRow<Content: View>(icon: String, title: String, value: String, @ViewBuilder menu: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DSH.Palette.text)
                .frame(width: 26)

            Text(title)
                .font(DSH.TypeScale.body)
                .foregroundStyle(DSH.Palette.text)

            Spacer()

            Menu {
                menu()
            } label: {
                HStack(spacing: 4) {
                    Text(value)
                        .font(DSH.TypeScale.footnote)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(DSH.Palette.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

extension Bundle {
    var appVersion: String {
        let short = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}
