import SwiftUI

/// 内置引擎控制台。
///
/// 它**不是**聊天界面：引擎起来之后要跟它对话，需要一个本地传输层（端口 + 协议），
/// 这一层还没接。所以这里只展示引擎自己的真实状态和事件，不假装能聊天。
struct EngineConsoleView: View {
    @ObservedObject private var engine = EngineLauncher.shared
    @Environment(\.dismiss) private var dismiss

    @State private var events: String = ""
    @State private var bridgeLine: String = ""
    @State private var probing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusCard
                    if let url = engine.state.baseURL {
                        block("引擎地址", text: url.absoluteString + (engine.state.token.isEmpty ? "" : "\ntoken: \(engine.state.token)"))
                    }
                    if !bridgeLine.isEmpty {
                        block("桥探测", text: bridgeLine)
                    }
                    if let state = currentState {
                        block("状态", text: state)
                    }
                    if !events.isEmpty {
                        block("事件", text: events)
                    }
                    Text("引擎起来之后，与它对话所需的本地传输层（端口与协议）还没接；这里显示的是 dsh_host_state / dsh_host_drain 的原始输出。")
                        .font(Fluid.Typography.caption)
                        .foregroundStyle(Fluid.Palette.slate)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Fluid.Palette.obsidian)
            .navigationTitle("内置引擎")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task { refresh() }
        }
    }

    private var currentState: String? {
        if case .running(let state) = engine.phase { return state }
        return nil
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: engine.isRunning ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(engine.isRunning ? Fluid.Palette.mint : Fluid.Palette.slate)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Fluid.Palette.text)
                Spacer()
                Button(engine.isRunning ? "停止" : "启动") {
                    if engine.isRunning {
                        engine.stop()
                    } else {
                        Task { await engine.start(workspace: AppFiles.workspace) }
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(engine.isRunning ? Fluid.Palette.coral : Fluid.Palette.iceBlue)
            }

            Text(detail)
                .font(Fluid.Typography.caption)
                .foregroundStyle(Fluid.Palette.mist)
                .fixedSize(horizontal: false, vertical: true)

            if engine.isRunning {
                HStack(spacing: 14) {
                    Button("刷新事件") { refresh() }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Fluid.Palette.iceBlue)

                    Button(probing ? "探测中…" : "探测桥") {
                        probing = true
                        Task {
                            bridgeLine = await engine.probeBridge()
                            probing = false
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Fluid.Palette.iceBlue)
                    .disabled(probing)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluidSurface(cornerRadius: Fluid.Shape.panel)
    }

    private func block(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Fluid.Palette.slate)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Fluid.Palette.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluidSurface()
    }

    private var title: String {
        switch engine.phase {
        case .idle: return "未启动"
        case .installing: return "安装运行时"
        case .starting: return "启动中"
        case .running: return "运行中"
        case .failed: return "启动失败"
        }
    }

    private var detail: String {
        switch engine.phase {
        case .idle: return "点「启动」解压 runtime 并拉起内置引擎。"
        case .installing(let p): return "解压 runtime… \(Int(p * 100))%"
        case .starting: return "正在调用 dsh_host_start"
        case .running: return "dsh_host_start 已返回；下面是引擎自己报的状态。"
        case .failed(let reason): return reason
        }
    }

    private func refresh() {
        events = engine.drain() ?? ""
        engine.refreshState()
    }
}
