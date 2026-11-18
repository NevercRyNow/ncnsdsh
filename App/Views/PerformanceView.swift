import SwiftUI

/// 性能面板：只显示能确证的数值，不做假图表。
struct PerformanceView: View {
    @EnvironmentObject private var perf: PerformanceCenter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    metrics
                    legend
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("性能")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear { perf.start() }
        }
        .preferredColorScheme(.dark)
    }

    private var metrics: some View {
        VStack(spacing: 0) {
            bar("CPU", value: perf.cpuPercent, unit: "%", upper: 100, tint: DSH.Palette.accent, detail: "进程内所有线程合计")
            divider
            bar("内存", value: perf.memoryMB, unit: "MB", upper: 1024, tint: DSH.Palette.info, detail: "phys_footprint")
            divider
            row("热状态", perf.thermalLabel, tint: thermalTint)
            divider
            row("低电量模式", perf.lowPower ? "开" : "关", tint: perf.lowPower ? DSH.Palette.warning : DSH.Palette.secondary)
            divider
            row("电池", perf.batteryLabel, tint: DSH.Palette.secondary)
            divider
            row("网络", perf.networkLabel, tint: perf.networkStatus == .satisfied ? DSH.Palette.success : DSH.Palette.tertiary)
            if perf.networkStatus == .satisfied {
                divider
                row("网络计费", perf.networkExpensive ? "按流量" : "不限量", tint: DSH.Palette.tertiary)
                divider
                row("受限网络", perf.networkConstrained ? "是" : "否", tint: DSH.Palette.tertiary)
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var thermalTint: Color {
        switch perf.thermal {
        case .nominal: return DSH.Palette.success
        case .fair: return DSH.Palette.warning
        case .serious, .critical: return DSH.Palette.danger
        @unknown default: return DSH.Palette.secondary
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("说明")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSH.Palette.tertiary)
            Text("每 2 秒采样一次。CPU 是进程内各线程瞬时占用之和，会略高于活动监视器的平滑值；网络只报告连接类型与是否计费，不提供延迟或带宽——系统没有公开这两个数字。")
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DSH.Palette.hairline)
            .frame(height: 0.5)
            .padding(.leading, 16)
    }

    private func bar(_ title: String, value: Double, unit: String, upper: Double, tint: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                Spacer()
                Text(String(format: "%.1f%@", value, unit))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DSH.Palette.raised)
                    Capsule()
                        .fill(tint)
                        .frame(width: Swift.max(2, proxy.size.width * Swift.min(1, value / upper)))
                }
            }
            .frame(height: 4)
            Text(detail)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(DSH.Palette.tertiary)
        }
        .padding(14)
    }

    private func row(_ title: String, _ value: String, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(DSH.TypeScale.body)
                .foregroundStyle(DSH.Palette.text)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
