import SwiftUI
import UIKit

struct BuildTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied: Int?

    private struct Step: Identifiable {
        let id: Int
        let title: String
        let body: String
        var code: String?
        var copyable: Bool = false
    }

    private let steps: [Step] = [
        Step(
            id: 1,
            title: "这个按钮到底做了什么",
            body: "它用你的 GitHub Token 调 GitHub Actions：在你自己的仓库里起一台 macOS 机器，编译 NcnsDSH，把产出的无签名 IPA 挂到一个 Release 上，再下载回这台手机。整个过程不经过任何第三方服务器。"
        ),
        Step(
            id: 2,
            title: "准备一个仓库",
            body: "仓库里要有 NcnsDSH 的源码，以及 .github/workflows/ios26.yml（真玻璃，Xcode 26）或 .github/workflows/ios.yml（回退版）。fork 一份官方仓库最省事。",
            code: "NevercRyNow/ncnsdsh"
        ),
        Step(
            id: 3,
            title: "建一个细粒度 Token",
            body: "去 GitHub 设置 → Developer settings → Fine-grained tokens。只勾选这个仓库，权限给两类：Actions 选 Read and write（要触发构建），Contents 选 Read（读代码和 Release）。生成后复制，只显示一次。",
            code: "Actions: Read and write\nContents: Read"
        ),
        Step(
            id: 4,
            title: "填配置，点开始构建",
            body: "Owner / Repo 填仓库，Workflow 填文件名（例如 ios26.yml），分支默认 main。点「开始构建」后，这里会实时显示 GitHub 的每一步：装 XcodeGen、生成工程、编译、打包、上传。通常 3–5 分钟。"
        ),
        Step(
            id: 5,
            title: "下载并安装",
            body: "成功后点「下载 IPA」，文件会存到 App 的 Documents/NcnsDSH/builds。用分享按钮存到「文件」，再用 Sideloadly 或 AltStore 用你的 Apple ID 签一次名就能装。免费 Apple ID 签 7 天，到期重签即可。"
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    ForEach(steps) { step in
                        card(step)
                    }
                    faq
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Theme.ink.ignoresSafeArea())
            .navigationTitle("3 分钟教程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("在自己手机上出一个 IPA")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Fluid.Palette.text)
            Text("不需要 Mac。GitHub 提供 macOS 机器，你只需要一个仓库和一个 Token。")
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 6)
    }

    private func card(_ step: Step) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(step.id)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24, height: 24)
                    .background(Theme.accent.opacity(0.22), in: Circle())

                Text(step.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Fluid.Palette.text)
            }

            Text(step.body)
                .font(DSH.TypeScale.footnote)
                .lineSpacing(3)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if let code = step.code {
                HStack(alignment: .top, spacing: 8) {
                    Text(code)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Fluid.Palette.text.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        UIPasteboard.general.string = code
                        Haptics.success()
                        copied = step.id
                    } label: {
                        Image(systemName: copied == step.id ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(copied == step.id ? Theme.mint : Theme.muted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var faq: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("常见问题")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Fluid.Palette.text)

            row("403 权限不够", "Token 里 Actions 必须是 Read and write，不是 Read。")
            row("404 找不到仓库", "Owner / Repo 拼错，或者 Token 没勾这个仓库。")
            row("422 不能触发", "这个分支上没有 workflow_dispatch，确认文件名和分支。")
            row("构建失败", "点「看日志」跳 GitHub，通常是 Swift 编译错误。")
            row("私有的仓库", "当前只支持公开仓库下载 Release 资产。")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 6)
    }

    private func row(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Fluid.Palette.text.opacity(0.92))
            Text(body)
                .font(DSH.TypeScale.caption)
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
