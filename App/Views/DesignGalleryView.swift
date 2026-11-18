import SwiftUI

/// Design Gallery：在真机上逐项检查色板、表面、字号、动效和核心状态。
/// 故意做成 Release 也能进——只在 Debug 里能看的画廊，等于没验证过。
struct DesignGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var swatches: [(String, Color)] {
        [
            ("obsidian", Fluid.Palette.obsidian),
            ("graphite", Fluid.Palette.graphite),
            ("text", Fluid.Palette.text),
            ("mist", Fluid.Palette.mist),
            ("slate", Fluid.Palette.slate),
            ("iceBlue", Fluid.Palette.iceBlue),
            ("mint", Fluid.Palette.mint),
            ("amber", Fluid.Palette.amber),
            ("coral", Fluid.Palette.coral),
            ("hairline", Fluid.Palette.hairline)
        ]
    }

    private let motionRows: [(String, String)] = [
        ("press", "0.12s · 按压"),
        ("select", "0.18s · 轻量选择"),
        ("panel", "0.34s · 面板展开"),
        ("dock", "0.40s · Dock 形变"),
        ("spatial", "0.46s · 页面空间转换"),
        ("state", "0.24s · 状态过渡")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    palette
                    surfaces
                    typography
                    cores
                    motion
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background(Fluid.Palette.obsidian)
            .navigationTitle("设计系统")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fluid Intelligence")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(Fluid.Palette.mist)
            Text("当前外观：\(scheme == .dark ? "深色" : "浅色")")
                .font(Fluid.Typography.caption)
                .foregroundStyle(Fluid.Palette.slate)
            Text("在这里改系统的深色/浅色、Reduce Motion、Reduce Transparency，下面的每一项都应该跟着变。")
                .font(Fluid.Typography.caption)
                .foregroundStyle(Fluid.Palette.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var palette: some View {
        block("色板") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(Array(swatches.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(item.1)
                            .frame(width: 34, height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Fluid.Palette.slate.opacity(0.4), lineWidth: 0.5)
                            )
                        Text(item.0)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Fluid.Palette.mist)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var surfaces: some View {
        block("内容表面") {
            VStack(alignment: .leading, spacing: 10) {
                Text("内容层用实色 + 0.5pt 细线，不铺玻璃。")
                    .font(Fluid.Typography.secondary)
                    .foregroundStyle(Fluid.Palette.mist)

                HStack(spacing: 10) {
                    Text("card 16")
                        .font(Fluid.Typography.caption)
                        .foregroundStyle(Fluid.Palette.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .fluidSurface()

                    Text("panel 22")
                        .font(Fluid.Typography.caption)
                        .foregroundStyle(Fluid.Palette.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .fluidSurface(cornerRadius: Fluid.Shape.panel)
                }
            }
        }
    }

    private var typography: some View {
        block("字号") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Display · NcnsDSH").font(Fluid.Typography.display).foregroundStyle(Fluid.Palette.text)
                Text("Body · 正文用系统正文样式").font(Fluid.Typography.body).foregroundStyle(Fluid.Palette.text)
                Text("Secondary · 次级说明").font(Fluid.Typography.secondary).foregroundStyle(Fluid.Palette.mist)
                Text("Caption · 辅助信息").font(Fluid.Typography.caption).foregroundStyle(Fluid.Palette.slate)
                Text("0123456789 · 01:24:09").font(Fluid.Typography.numeric).foregroundStyle(Fluid.Palette.text)
                Text("terminal --build --release").font(Fluid.Typography.technical).foregroundStyle(Fluid.Palette.mint)
            }
        }
    }

    private var cores: some View {
        block("智能核心 · 六个有真实信号的状态") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 14) {
                ForEach(CorePhase.allCases) { phase in
                    VStack(spacing: 8) {
                        IntelligenceCore(state: CoreState(phase: phase, runningCount: 1, remote: false), size: 40)
                        Text(phase.title)
                            .font(.system(size: 10))
                            .foregroundStyle(Fluid.Palette.mist)
                    }
                }
            }
        }
    }

    private var motion: some View {
        block("动效档位") {
            VStack(spacing: 8) {
                ForEach(Array(motionRows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.0)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Fluid.Palette.text)
                        Spacer()
                        Text(row.1)
                            .font(Fluid.Typography.caption)
                            .foregroundStyle(Fluid.Palette.mist)
                    }
                }
            }
        }
    }

    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Fluid.Palette.slate)

            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fluidSurface()
        }
    }
}
