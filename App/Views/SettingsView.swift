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

    @State private var showAccount = false
    @State private var showPlugins = false
    @State private var showAutomation = false
    @State private var showPhone = false
    @State private var showCredits = false
    @State private var showConnect = false
    @State private var showAdvanced = false
    @State private var showWeb = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    accountRow
                    entryGroup
                    backgroundGroup
                    widgetGroup
                    appearanceGroup
                    hostGroup
                    tailGroup
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
        .sheet(isPresented: $showAccount) {
            AccountView().environmentObject(account)
        }
        .sheet(isPresented: $showPhone) {
            PhoneLoginView().environmentObject(phone)
        }
        .sheet(isPresented: $showCredits) {
            AboutView()
        }
        .sheet(isPresented: $showConnect) {
            ConnectView().environmentObject(store)
        }
        .sheet(isPresented: $showPlugins) {
            PluginsView().environmentObject(plugins)
        }
        .sheet(isPresented: $showAutomation) {
            ScheduleView().environmentObject(demo)
        }
        .sheet(isPresented: $showAdvanced) {
            advancedSheet
        }
        .sheet(isPresented: $showWeb) {
            if let host = store.current {
                WebScreen(host: host).preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Account

    private var accountRow: some View {
        Button {
            Haptics.tap()
            showAccount = true
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
                showPlugins = true
            }
            divider
            row(icon: "arrow.triangle.2.circlepath", title: "自动化", value: "\(demo.schedules.count) 个") {
                showAutomation = true
            }
            divider
            row(icon: "iphone", title: "手机号", value: phone.signedIn ? phone.masked : "未登录") {
                showPhone = true
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
                showConnect = true
            }
            divider
            row(icon: "folder", title: "文件", value: AppFiles.displayPath) {
                AppFiles.reveal()
            }
            if store.current != nil {
                divider
                row(icon: "globe", title: "网页版", value: "插件页 / 终端") {
                    showWeb = true
                }
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tailGroup: some View {
        VStack(spacing: 0) {
            row(icon: "screwdriver", title: "高级", value: "") {
                showAdvanced = true
            }
            divider
            row(icon: "info.circle", title: "关于", value: "郑壹鸣") {
                showCredits = true
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
                }
                .padding(20)
            }
            .background(DSH.Palette.canvas)
            .navigationTitle("高级")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showAdvanced = false }
                }
            }
        }
        .preferredColorScheme(.dark)
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

            Toggle("", isOn: isOn)
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
