import SwiftUI

/// 智能核心的状态。**只包含代码里真有信号的状态**，没有信号的（比如 paused/completed）
/// 不画，也不假装在思考。
enum CorePhase: String, CaseIterable, Identifiable {
    case idle
    case running
    case streaming
    case executing
    case awaiting
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle: return "空闲"
        case .running: return "会话运行中"
        case .streaming: return "流式输出"
        case .executing: return "工具调用"
        case .awaiting: return "等待确认"
        case .failed: return "上次执行失败"
        }
    }

    var tint: Color {
        switch self {
        case .idle: return Fluid.Palette.slate
        case .running, .streaming: return Fluid.Palette.iceBlue
        case .executing: return Fluid.Palette.mint
        case .awaiting: return Fluid.Palette.amber
        case .failed: return Fluid.Palette.coral
        }
    }

    /// 只有真的在动的时候才转。
    var isActive: Bool {
        self == .running || self == .streaming || self == .executing
    }
}

struct CoreState: Equatable {
    var phase: CorePhase = .idle
    var runningCount = 0
    var remote = false

    var tint: Color { phase.tint }

    var detail: String {
        switch phase {
        case .idle: return remote ? "远程已连接，没有正在执行的任务" : "没有正在执行的任务"
        case .running: return "\(runningCount) 个会话正在运行"
        case .streaming: return "模型正在输出"
        case .executing: return "工具调用进行中"
        case .awaiting: return "有操作在等你确认"
        case .failed: return "最后一次工具调用失败"
        }
    }

    /// 全部来自真实状态：
    /// - `demo.approval` → 等待确认
    /// - 最后一条消息里 `ToolStatus.running` → 工具调用
    /// - 最后一条消息 `isStreaming` → 流式输出
    /// - `demo.runningCount` → 会话运行中
    /// - 最后一条消息最后一个工具 `failed` → 失败
    /// - 其余 → 空闲
    @MainActor
    static func derive(demo: DemoStore, remote: Bool) -> CoreState {
        var state = CoreState()
        state.remote = remote
        state.runningCount = demo.runningCount

        let latest = demo.messages.values.flatMap { $0 }.max { $0.date < $1.date }
        let toolRunning = latest?.tools.contains(where: { $0.status == .running }) ?? false
        let lastStatus: ToolStatus? = latest?.tools.last?.status
        let toolFailed = lastStatus == .failed

        if demo.approval != nil {
            state.phase = .awaiting
        } else if toolRunning {
            state.phase = .executing
        } else if latest?.isStreaming == true {
            state.phase = .streaming
        } else if demo.runningCount > 0 {
            state.phase = .running
        } else if toolFailed {
            state.phase = .failed
        } else {
            state.phase = .idle
        }
        return state
    }
}

/// Intelligence Core：一个由真实状态驱动的球。
/// 动的时候只有一条弧在转；不动的时候就真的静止，不转圈骗人。
struct IntelligenceCore: View {
    var state: CoreState
    var size: CGFloat = 34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel("智能核心，\(state.phase.title)")
    }

    @ViewBuilder
    private var content: some View {
        if state.phase.isActive && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                orb(angle: context.date.timeIntervalSinceReferenceDate * 90)
            }
        } else {
            orb(angle: state.phase == .awaiting ? 45 : 0)
        }
    }

    private func orb(angle: Double) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [state.tint.opacity(0.80), state.tint.opacity(0.14)],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.58
                    )
                )

            Circle()
                .strokeBorder(state.tint.opacity(0.30), lineWidth: 0.5)

            Circle()
                .trim(from: 0, to: state.phase == .idle ? 0.16 : 0.30)
                .stroke(
                    state.tint,
                    style: StrokeStyle(lineWidth: max(1.5, size * 0.055), lineCap: .round)
                )
                .rotationEffect(.degrees(angle))
                .padding(size * 0.08)

            Circle()
                .fill(Color.white.opacity(0.50))
                .frame(width: size * 0.15, height: size * 0.15)
                .blur(radius: size * 0.05)
                .offset(x: -size * 0.10, y: -size * 0.12)
        }
    }
}
