import SwiftUI
import UIKit

/// 关于 NcnsDSH：品牌、版本、制作人、项目、致谢。
///
/// 版本和构建号一律从 Bundle 读，不写死；许可证是仓库里的 MIT。
/// 这一页是内容层：用实色表面和排版，不铺玻璃——玻璃留给导航和浮动控件。
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var appeared = false
    @State private var copied = false
    @State private var showLicense = false

    private let repository = URL(string: "https://github.com/NevercRyNow/ncnsdsh")!
    private let homepage = URL(string: "https://nevercrynow.github.io/openworld/")!

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var minimumOS: String {
        let raw = Bundle.main.infoDictionary?["MinimumOSVersion"] as? String
        return raw.map { "iOS \($0)" } ?? "iOS 17"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    hero
                    applicationSection
                    creditsSection
                    projectSection
                    acknowledgementsSection
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Fluid.Palette.obsidian)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showLicense) {
                LicenseSheet(openURL: openURL, repository: repository)
            }
        }
        .onAppear {
            withAnimation(Fluid.Motion.respecting(reduceMotion, Fluid.Motion.panel)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                BrandMark(size: 84)
                    .shadow(color: Fluid.Palette.iceBlue.opacity(0.22), radius: 26, y: 12)
                    .scaleEffect(reduceMotion ? 1 : (appeared ? 1 : 0.94))
                    .opacity(appeared ? 1 : 0)

                Spacer()

                Button {
                    copyVersion()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                        Text(copied ? "已复制" : "v" + version)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .contentTransition(.opacity)
                    }
                    .foregroundStyle(copied ? Fluid.Palette.mint : Fluid.Palette.mist)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Fluid.Palette.graphite, in: Capsule())
                    .overlay(Capsule().strokeBorder(Fluid.Palette.slate.opacity(0.4), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("版本 \(version)，构建号 \(build)")
                .accessibilityHint("轻点复制版本信息")
            }

            Text("NcnsDSH")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Fluid.Palette.text)
                .padding(.top, 20)

            Text("Fluid Intelligence")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .tracking(3.2)
                .foregroundStyle(Fluid.Palette.mist)
                .padding(.top, 6)

            Text("面向 iOS 的原生智能开发工作站。把对话、工具执行、文件与运行环境放进同一个工作空间。")
                .font(Fluid.Type.secondary)
                .foregroundStyle(Fluid.Palette.mist)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - Application

    private var applicationSection: some View {
        section("Application") {
            rows([
                ("版本", version),
                ("构建号", build),
                ("平台", "iOS · \(UIDevice.current.systemVersion)"),
                ("最低系统", minimumOS)
            ])
        }
        .entrance(appeared, index: 1, reduceMotion: reduceMotion)
    }

    // MARK: - Credits

    private var creditsSection: some View {
        section("Credits") {
            rows([
                ("设计与开发", "郑壹鸣"),
                ("Created by", "Zheng Yiming"),
                ("视觉方向", "Fluid Intelligence")
            ])
        }
        .entrance(appeared, index: 2, reduceMotion: reduceMotion)
    }

    // MARK: - Project

    private var projectSection: some View {
        section("Project") {
            VStack(spacing: 0) {
                Button {
                    openURL(repository)
                } label: {
                    row("源代码", "GitHub ↗", tint: Fluid.Palette.iceBlue)
                }
                .buttonStyle(.plain)

                divider

                Button {
                    showLicense = true
                } label: {
                    row("许可证", "MIT", tint: Fluid.Palette.iceBlue, accessory: "chevron.right")
                }
                .buttonStyle(.plain)

                divider

                Button {
                    openURL(homepage)
                } label: {
                    row("项目主页", "openworld ↗", tint: Fluid.Palette.mist)
                }
                .buttonStyle(.plain)

                divider

                HStack {
                    Text("第三方依赖")
                        .font(Fluid.Type.body)
                        .foregroundStyle(Fluid.Palette.text)
                    Spacer()
                    Text("无")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Fluid.Palette.mist)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .entrance(appeared, index: 3, reduceMotion: reduceMotion)
    }

    // MARK: - Acknowledgements

    private var acknowledgementsSection: some View {
        section("Acknowledgements") {
            VStack(alignment: .leading, spacing: 10) {
                Text("系统框架")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Fluid.Palette.mist)

                Text("SwiftUI · UIKit · WebKit · JavaScriptCore · AVFoundation · Vision · NaturalLanguage · AppIntents")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Fluid.Palette.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text("本工程没有引入任何第三方包：project.yml 里没有 package 声明，上面的框架全部来自系统。")
                    .font(Fluid.Type.caption)
                    .foregroundStyle(Fluid.Palette.mist)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .entrance(appeared, index: 4, reduceMotion: reduceMotion)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle()
                .fill(Fluid.Palette.hairline)
                .frame(height: 0.5)
                .padding(.bottom, 10)

            Text("© 2026 NevercRyNow · MIT License")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Fluid.Palette.slate)
            Text("郑壹鸣 设计与开发")
                .font(.system(size: 10))
                .foregroundStyle(Fluid.Palette.slate)
        }
        .entrance(appeared, index: 5, reduceMotion: reduceMotion)
    }

    // MARK: - Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Fluid.Palette.slate)
                .padding(.leading, 2)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .fluidSurface()
        }
    }

    private func rows(_ items: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.0)
                        .font(Fluid.Type.body)
                        .foregroundStyle(Fluid.Palette.text)
                    Spacer()
                    Text(item.1)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Fluid.Palette.mist)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if index != items.count - 1 { divider }
            }
        }
    }

    private func row(_ title: String, _ value: String, tint: Color, accessory: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(Fluid.Type.body)
                .foregroundStyle(Fluid.Palette.text)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
            if let accessory {
                Image(systemName: accessory)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Fluid.Palette.slate)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Rectangle()
            .fill(Fluid.Palette.hairline)
            .frame(height: 0.5)
            .padding(.leading, 14)
    }

    private func copyVersion() {
        UIPasteboard.general.string = "NcnsDSH \(version) (\(build))"
        Haptics.tap()
        withAnimation(Fluid.Motion.respecting(reduceMotion, Fluid.Motion.state)) { copied = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(Fluid.Motion.state) { copied = false }
        }
    }
}

private extension View {
    /// 分区依次入场。Reduce Motion 时只淡入，不位移。
    func entrance(_ appeared: Bool, index: Int, reduceMotion: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (appeared ? 0 : 12))
            .animation(
                Fluid.Motion.respecting(reduceMotion, Fluid.Motion.panel).delay(reduceMotion ? 0 : Double(index) * 0.05),
                value: appeared
            )
    }
}

/// MIT 许可全文。文本直接写在 App 里，不依赖网络。
private struct LicenseSheet: View {
    let openURL: OpenURLAction
    let repository: URL

    @Environment(\.dismiss) private var dismiss

    private let text = """
    MIT License

    Copyright (c) 2026 NevercRyNow

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Fluid.Palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .background(Fluid.Palette.obsidian)
            .navigationTitle("MIT License")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
