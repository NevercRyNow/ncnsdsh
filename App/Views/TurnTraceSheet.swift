import SwiftUI

/// 本轮轨迹：耗时、模型/工具占比、每步时长、token 与首字延迟。
struct TurnTraceSheet: View {
    @EnvironmentObject private var local: LocalStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                content(now: context.date)
            }
            .background(DSH.Palette.canvas)
            .navigationTitle("本轮轨迹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let trace = local.trace {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(trace: trace, now: now)
                    split(trace: trace, now: now)
                    steps(trace: trace, now: now)
                    footer(trace: trace)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        } else {
            EmptyStateView(
                symbol: "chart.bar.xaxis",
                title: "还没有轨迹",
                message: "发一条消息，这里会显示本轮的耗时与 token。",
                actionTitle: nil,
                action: nil
            )
        }
    }

    private func header(trace: TurnTrace, now: Date) -> some View {
        let running = local.runningID != nil
        let elapsed = running ? now.timeIntervalSince(trace.startedAt) : max(trace.elapsed, 0)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(clock(elapsed))
                    .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(DSH.Palette.text)
                Text(running ? "进行中" : "已完成")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(running ? DSH.Palette.accent : DSH.Palette.success)
            }
            Text("本轮轨迹")
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.tertiary)
        }
    }

    private func split(trace: TurnTrace, now: Date) -> some View {
        let model = trace.modelTime
        let tool = trace.toolTime
        let total = max(model + tool, 0.001)

        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    Capsule()
                        .fill(DSH.Palette.accent)
                        .frame(width: proxy.size.width * model / total)
                    Capsule()
                        .fill(DSH.Palette.warning)
                        .frame(width: proxy.size.width * tool / total)
                }
            }
            .frame(height: 5)

            HStack(spacing: 16) {
                legend(DSH.Palette.accent, "模型", clock(model))
                legend(DSH.Palette.warning, "工具", clock(tool))
            }
        }
    }

    private func legend(_ tint: Color, _ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(DSH.Palette.secondary)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DSH.Palette.tertiary)
        }
    }

    private func steps(trace: TurnTrace, now: Date) -> some View {
        let longest = trace.steps.map { $0.end == nil ? now.timeIntervalSince($0.start) : $0.duration }.max() ?? 1

        return VStack(spacing: 0) {
            ForEach(Array(trace.steps.enumerated()), id: \.element.id) { index, step in
                let duration = step.end == nil ? now.timeIntervalSince(step.start) : step.duration
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: symbol(for: step.kind))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint(for: step.kind))
                            .frame(width: 30, height: 30)
                            .background(tint(for: step.kind).opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(step.label)
                            .font(DSH.TypeScale.body)
                            .foregroundStyle(DSH.Palette.text)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(clock(duration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(step.end == nil ? DSH.Palette.accent : DSH.Palette.tertiary)
                    }

                    GeometryReader { proxy in
                        Capsule()
                            .fill(step.end == nil ? DSH.Palette.accent.opacity(0.7) : DSH.Palette.raised)
                            .frame(width: max(2, proxy.size.width * duration / max(longest, 0.001)))
                    }
                    .frame(height: 3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if index != trace.steps.count - 1 {
                    Divider().overlay(DSH.Palette.hairline).padding(.leading, 54)
                }
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func footer(trace: TurnTrace) -> some View {
        let hitRate = trace.promptTokens > 0 ? Double(trace.cacheHit) / Double(trace.promptTokens) : 0
        let firstByte: String = {
            guard let first = trace.firstTokenAt else { return "—" }
            return String(format: "%.1f 秒", first.timeIntervalSince(trace.startedAt))
        }()

        return HStack(spacing: 0) {
            stat(short(trace.promptTokens), "输入")
            divider
            stat(String(format: "%.0f%%", hitRate * 100), "缓存命中")
            divider
            stat(short(trace.completionTokens), "输出")
            divider
            stat(firstByte, "首字")
        }
        .padding(.vertical, 14)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            Text("输入含缓存命中")
                .font(.system(size: 9))
                .foregroundStyle(DSH.Palette.tertiary)
                .padding(.leading, 16)
                .padding(.bottom, 6)
        }
    }

    private var divider: some View {
        Rectangle().fill(DSH.Palette.hairline).frame(width: 0.5, height: 26)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(DSH.Palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(DSH.Palette.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func symbol(for kind: TraceKind) -> String {
        switch kind {
        case .thinking: return "brain"
        case .generation: return "text.alignleft"
        case .tool: return "wrench.and.screwdriver"
        }
    }

    private func tint(for kind: TraceKind) -> Color {
        switch kind {
        case .thinking: return DSH.Palette.info
        case .generation: return DSH.Palette.accent
        case .tool: return DSH.Palette.warning
        }
    }

    private func clock(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return String(format: "%.0f 秒", seconds) }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }

    private func short(_ value: Int) -> String {
        if value >= 1000 { return String(format: "%.1fK", Double(value) / 1000) }
        return "\(value)"
    }
}
