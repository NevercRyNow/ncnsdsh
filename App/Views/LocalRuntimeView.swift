import SwiftUI

/// 本机运行时：状态、启停、日志、环境信息、重置。
/// 它不是 Node 引擎——没有端口、没有子进程；这里是 App 自己的运行时。
struct LocalRuntimeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var perf: PerformanceCenter
    @EnvironmentObject private var store: HostStore
    @EnvironmentObject private var environmentManager: EnvironmentManager
    @EnvironmentObject private var runtimes: RuntimeManager
    @EnvironmentObject private var local: LocalStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var log = RuntimeLog.shared

    @State private var confirmReset = false
    @State private var confirmUninstall = false
    @State private var showLinux = false
    @State private var pendingRemoval: Host?
    @State private var backups: [BackupInfo] = []
    @State private var restoreTarget: BackupInfo?

    private var running: Bool { settings.silentAudio || settings.keepRunning }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    controls
                    autoStart
                    runtimeSection
                    backupsSection
                    linuxSection
                    logCard
                    environment
                    danger
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("本机运行时")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                perf.start()
                if log.entries.isEmpty {
                    log.log("运行时视图打开 · \(Bundle.main.appVersion)")
                }
            }
        }
        .confirmationDialog("重置会清空日志、缓存与沙箱审计，不会删除工作区文件。", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("重置", role: .destructive) {
                reset()
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showLinux) {
            LinuxServerSheet().environmentObject(store).environmentObject(environmentManager)
        }
        .confirmationDialog(
            restoreTarget.map { "用 \($0.id) 覆盖当前工作区？" } ?? "",
            isPresented: Binding(
                get: { restoreTarget != nil },
                set: { if !$0 { restoreTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("恢复", role: .destructive) {
                if let info = restoreTarget {
                    do {
                        try WorkspaceBackup.restore(info)
                        Haptics.success()
                    } catch {
                        RuntimeLog.shared.log("恢复失败：\(error.localizedDescription)", level: .error)
                        Haptics.failure()
                    }
                    backups = WorkspaceBackup.list()
                }
                restoreTarget = nil
            }
            Button("取消", role: .cancel) { restoreTarget = nil }
        }
        .confirmationDialog(
            pendingRemoval.map { "移除 \($0.displayName)？" } ?? "",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("移除", role: .destructive) {
                if let host = pendingRemoval {
                    store.forget(host)
                    log.log("已移除 Linux 环境：\(host.displayName)", level: .warn)
                }
                pendingRemoval = nil
            }
            Button("取消", role: .cancel) { pendingRemoval = nil }
        }
        .confirmationDialog("卸载会删除工作区里的全部文件，无法恢复。", isPresented: $confirmUninstall, titleVisibility: .visible) {
            Button("删除工作区", role: .destructive) {
                uninstall()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "cpu")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(running ? DSH.Palette.accent : DSH.Palette.tertiary)
                .frame(width: 54, height: 54)
                .background(DSH.Palette.surface, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("本机运行时")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DSH.Palette.text)
                HStack(spacing: 6) {
                    Circle()
                        .fill(running ? DSH.Palette.success : DSH.Palette.tertiary)
                        .frame(width: 6, height: 6)
                    Text(running ? "运行中 · 进程内" : "未启动")
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.secondary)
                }
            }

            Spacer()
        }
        .padding(.top, 6)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            control("启动", "play", enabled: !running) { start() }
            control("停止", "stop", enabled: running) { stop() }
            control("重启", "arrow.clockwise", enabled: true) {
                stop()
                start()
            }
        }
    }

    private func control(_ title: String, _ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(enabled ? DSH.Palette.text : DSH.Palette.tertiary)
            .opacity(enabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var autoStart: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("打开 App 时自动启动")
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                Text("静音音频保活，会多耗电")
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.tertiary)
            }
            Spacer()
            Toggle("", isOn: $settings.keepRunning)
                .labelsHidden()
                .tint(DSH.Palette.accent)
        }
        .padding(16)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var runtimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("运行时")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSH.Palette.tertiary)
                .textCase(.uppercase)
                .tracking(1.1)

            VStack(spacing: 0) {
                ForEach(runtimes.statuses, id: \.kind) { status in
                    HStack(spacing: 12) {
                        Image(systemName: status.kind.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(status.state.isRunning ? DSH.Palette.accent : DSH.Palette.tertiary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(status.kind.title)
                                .font(DSH.TypeScale.body)
                                .foregroundStyle(DSH.Palette.text)
                            Text(status.detail)
                                .font(DSH.TypeScale.footnote)
                                .foregroundStyle(DSH.Palette.tertiary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 6)

                        Text(status.state.label)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(status.state.isRunning ? DSH.Palette.success : DSH.Palette.tertiary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)

                    if status.kind != runtimes.statuses.last?.kind {
                        divider
                    }
                }
            }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .onAppear {
            runtimes.refresh(host: store.current)
        }
    }

    private var backupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("工作区备份")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DSH.Palette.tertiary)
                    .textCase(.uppercase)
                    .tracking(1.1)
                Spacer()
                Button {
                    Haptics.light()
                    if let info = try? WorkspaceBackup.create() {
                        backups = WorkspaceBackup.list()
                        Haptics.success()
                        _ = info
                    }
                } label: {
                    Text("立即备份")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DSH.Palette.accent)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                if backups.isEmpty {
                    Text("还没有备份。备份会复制工作区到 Application Support，最多保留 5 份。")
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(backups.prefix(3)) { info in
                        HStack(spacing: 10) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 12))
                                .foregroundStyle(DSH.Palette.secondary)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(info.id)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(DSH.Palette.text)
                                    .lineLimit(1)
                                Text("\(info.files) 个文件 · \(byteText(info.bytes))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(DSH.Palette.tertiary)
                            }
                            Spacer()
                            Button("恢复") {
                                restoreTarget = info
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DSH.Palette.accent)
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if info.id != backups.prefix(3).last?.id {
                            divider
                        }
                    }
                }
            }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .onAppear {
            backups = WorkspaceBackup.list()
        }
    }

    private func byteText(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private var linuxHosts: [Host] {
        store.hosts.filter { $0.kind == .linux }
    }

    private var linuxSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linux 环境")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSH.Palette.tertiary)
                .textCase(.uppercase)
                .tracking(1.1)

            VStack(spacing: 0) {
                if linuxHosts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("还没有添加 Linux 服务器")
                            .font(DSH.TypeScale.body)
                            .foregroundStyle(DSH.Palette.text)
                        Text("Linux 跑在远端服务器上，App 里不安装 Linux 运行时。")
                            .font(DSH.TypeScale.footnote)
                            .foregroundStyle(DSH.Palette.tertiary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            Haptics.tap()
                            showLinux = true
                        } label: {
                            Text("添加 Linux 服务器")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DSH.Palette.accent)
                                .padding(.top, 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(linuxHosts) { host in
                        linuxRow(host)
                        if host.id != linuxHosts.last?.id {
                            divider
                        }
                    }
                }
            }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func linuxRow(_ host: Host) -> some View {
        VStack(spacing: 0) {
            info("地址", host.originText)
            divider
            info("系统", "未探测")
            divider
            info("连接", store.current?.id == host.id ? "已连接" : "离线")

            divider

            Button {
                Haptics.tap()
                pendingRemoval = host
            } label: {
                HStack {
                    Text("移除 Linux 环境")
                        .font(DSH.TypeScale.body)
                        .foregroundStyle(DSH.Palette.danger)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DSH.Palette.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("日志")
                    .font(DSH.TypeScale.headline)
                    .foregroundStyle(DSH.Palette.text)
                Text("\(log.entries.count) 行")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DSH.Palette.tertiary)

                Spacer()

                Button {
                    UIPasteboard.general.string = log.plainText
                    Haptics.success()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(DSH.Palette.secondary)
                }
                .buttonStyle(.plain)

                ShareLink(item: log.plainText.isEmpty ? "（暂无日志）" : log.plainText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(DSH.Palette.secondary)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if log.entries.isEmpty {
                        Text("还没有日志。")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DSH.Palette.tertiary)
                    } else {
                        ForEach(log.entries.suffix(120).reversed()) { entry in
                            Text("\(time(entry.date)) \(entry.text)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(entry.level.tint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(10)
            }
            .frame(height: 180)
            .background(Color(white: 0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var environment: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("运行环境")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSH.Palette.tertiary)
                .textCase(.uppercase)
                .tracking(1.1)

            VStack(spacing: 0) {
                info("版本", Bundle.main.appVersion)
                divider
                info("架构", "arm64")
                divider
                info("命令行", "内置 \(LocalTools.names.count) 个工具")
                divider
                info("脚本执行", "不支持")
                divider
                info("安装插件", "仅目录，无运行时")
                divider
                info("切到后台", "可能被系统暂停")
                divider
                info("今日用量", "\(local.todayTurns) 轮 · 入 \(local.todayInput) · 出 \(local.todayOutput)")
                divider
                info("沙箱模式", Sandbox.shared.policy.mode.title)
            }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var danger: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.tap()
                confirmReset = true
            } label: {
                dangerRow("重置运行环境", "清空日志、缓存与沙箱审计", symbol: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)

            divider

            Button {
                Haptics.tap()
                confirmUninstall = true
            } label: {
                dangerRow("删除工作区", "移除 Documents/NcnsDSH/workspace", symbol: "trash")
            }
            .buttonStyle(.plain)
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dangerRow(_ title: String, _ detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(DSH.Palette.danger)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.danger)
                Text(detail)
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle()
            .fill(DSH.Palette.hairline)
            .frame(height: 0.5)
            .padding(.leading, 14)
    }

    private func info(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(DSH.TypeScale.body)
                .foregroundStyle(DSH.Palette.text)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(DSH.Palette.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func start() {
        settings.keepRunning = true
        perf.start()
        log.log("运行时已启动（静音音频保活）")
    }

    private func stop() {
        settings.keepRunning = false
        settings.silentAudio = false
        perf.stop()
        log.log("运行时已停止", level: .warn)
    }

    private func reset() {
        log.clear()
        Sandbox.shared.clearAudit()
        URLCache.shared.removeAllCachedResponses()
        log.log("已重置：日志、缓存、沙箱审计")
        Haptics.success()
    }

    private func uninstall() {
        let manager = FileManager.default
        if let items = try? manager.contentsOfDirectory(at: AppFiles.workspace, includingPropertiesForKeys: nil) {
            for item in items {
                try? manager.removeItem(at: item)
            }
        }
        log.log("工作区已清空", level: .error)
        Haptics.failure()
    }
}
