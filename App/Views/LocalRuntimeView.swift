import SwiftUI

/// 本机运行时：状态、启停、日志、环境信息、重置。
/// 它不是 Node 引擎——没有端口、没有子进程；这里是 App 自己的运行时。
struct LocalRuntimeView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var perf: PerformanceCenter
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var log = RuntimeLog.shared

    @State private var confirmReset = false
    @State private var confirmUninstall = false

    private var running: Bool { settings.silentAudio || settings.keepRunning }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    controls
                    autoStart
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
        .preferredColorScheme(.dark)
        .confirmationDialog("重置会清空日志、缓存与沙箱审计，不会删除工作区文件。", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("重置", role: .destructive) {
                reset()
            }
            Button("取消", role: .cancel) {}
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
