import SwiftUI

/// 关于：品牌、版本、制作人员、能力清单。独立视窗，玻璃质感。
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let features: [(String, String, String)] = [
        ("bubble.left.and.bubble.right", "会话", "流式回复、工具调用、活动时间线"),
        ("rectangle.3.group", "工作台", "终端、文件、浏览器、改动、上下文"),
        ("puzzlepiece.extension", "插件", "目录、分类、按权限推导的风险"),
        ("hammer", "构建", "GitHub Actions 出包与下载"),
        ("speedometer", "性能", "内存、CPU、热状态、网络"),
        ("server.rack", "环境", "本机、电脑、Linux 服务器")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    creditsCard
                    featuresCard
                    linksCard
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 12) {
            BrandMark(size: 72)
                .shadow(color: DSH.Palette.accent.opacity(0.35), radius: 26, y: 10)

            Text("NcnsDSH")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(DSH.Palette.text)

            Text("v" + Bundle.main.appVersion)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DSH.Palette.tertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(DSH.Palette.surface, in: Capsule())

            Text("原生 iOS AI 工作终端")
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var creditsCard: some View {
        VStack(spacing: 0) {
            row("设计与开发", "郑壹鸣")
            divider
            row("品牌与视觉", "郑壹鸣")
            divider
            row("工程架构", "郑壹鸣")
            divider
            row("许可", "MIT")
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 12) {
                    Image(systemName: item.0)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DSH.Palette.accent)
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.1)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DSH.Palette.text)
                        Text(item.2)
                            .font(.system(size: 11))
                            .foregroundStyle(DSH.Palette.tertiary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                if index != features.count - 1 {
                    divider
                }
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            Link(destination: URL(string: "https://github.com/NevercRyNow/ncnsdsh")!) {
                row("源代码", "GitHub ↗", tint: DSH.Palette.accent)
            }
            divider
            Link(destination: URL(string: "https://nevercrynow.github.io/openworld/")!) {
                row("项目主页", "openworld ↗", tint: DSH.Palette.accent)
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("© 2026 NevercRyNow")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DSH.Palette.tertiary)
            Text("保留所有权利")
                .font(.system(size: 9))
                .foregroundStyle(DSH.Palette.tertiary.opacity(0.8))
        }
        .padding(.top, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(DSH.Palette.hairline)
            .frame(height: 0.5)
            .padding(.leading, 50)
    }

    private func row(_ title: String, _ value: String, tint: Color = DSH.Palette.secondary) -> some View {
        HStack {
            Text(title)
                .font(DSH.TypeScale.body)
                .foregroundStyle(DSH.Palette.text)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
