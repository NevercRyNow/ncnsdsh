import SwiftUI

struct BuildView: View {
    @EnvironmentObject private var build: BuildStore

    @State private var showToken = false
    @State private var showTutorial = false
    @State private var tokenInput = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    statusCard
                    recentCard
                    if !build.steps.isEmpty {
                        stepsCard
                    }
                    repoCard
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("构建")
            .navigationBarTitleDisplayMode(.large)
            .task { await build.loadRecent() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showTutorial = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showTutorial) {
            BuildTutorialView()
        }
        .sheet(isPresented: $showToken) {
            tokenSheet
                .presentationDetents([.height(340)])
                .presentationBackground(.clear)
                .environmentObject(build)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("让 GitHub 帮你造一个 IPA")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                Image(systemName: build.hasToken ? "checkmark.seal.fill" : "person.badge.key")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(build.hasToken ? Theme.mint : Theme.accent)
                Text(build.hasToken ? (build.login.map { "已连接 @\($0)" } ?? "Token 已验证") : "还没连 GitHub")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Fluid.Palette.text.opacity(0.85))
                Spacer()
                Button(build.hasToken ? "换 Token" : "连接") {
                    tokenInput = ""
                    showToken = true
                }
                .buttonStyle(NcnsGlassButtonStyle(compact: true))
            }
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.16))
                        .frame(width: 54, height: 54)
                    if build.phase.isBusy {
                        ProgressView()
                            .tint(statusColor)
                    } else {
                        Image(systemName: statusIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Fluid.Palette.text)
                    Text(statusDetail)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if build.phase.isBusy {
                    Text(timeText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
            }

            if case .failed(let reason) = build.phase {
                Text(reason)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0xFFB86B))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message = build.message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0xFFB86B))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if build.phase == .succeeded || build.phase == .downloading || build.phase == .ready {
                HStack(spacing: 10) {
                    if build.phase == .ready, let artifact = build.artifact {
                        ShareLink(item: artifact.url) {
                            Label("分享 IPA", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Theme.mint.opacity(0.20), in: Capsule())
                                .foregroundStyle(Fluid.Palette.text)
                        }
                        Text(byteText(artifact.size))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.dim)

                        Button {
                            AppFiles.reveal()
                        } label: {
                            Label("在文件中查看", systemImage: "folder")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            Task { await build.download() }
                        } label: {
                            Label("下载 IPA", systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Theme.mint.opacity(0.20), in: Capsule())
                                .foregroundStyle(Fluid.Palette.text)
                        }
                        .buttonStyle(.plain)
                    }

                    if let url = build.runURL {
                        Link(destination: url) {
                            Label("看日志", systemImage: "arrow.up.right.square")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ncnsGlass(cornerRadius: 24)
    }

    // MARK: - Steps

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("步骤")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.bottom, 10)

            ForEach(build.steps) { step in
                HStack(spacing: 12) {
                    Circle()
                        .fill(dotColor(step))
                        .frame(width: 8, height: 8)

                    Text(step.name)
                        .font(.system(size: 14))
                        .foregroundStyle(step.status == "completed" ? Color.white.opacity(0.9) : Color.white.opacity(0.6))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if step.status != "completed" {
                        Text(step.status == "in_progress" ? "进行中" : "等待")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.dim)
                    } else if step.failed {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: 0xFF6B6B))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.mint)
                    }
                }
                .padding(.vertical, 7)

                if step.id != build.steps.last?.id {
                    Divider().overlay(Theme.hairline).padding(.leading, 20)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Repo

    private var repoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("构建配置")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .textCase(.uppercase)
                .tracking(1.2)

            Picker("变体", selection: $build.workflow) {
                Text("标准").tag("ios.yml")
                Text("玻璃").tag("ios26.yml")
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                field("Owner", text: $build.owner)
                field("Repo", text: $build.repo)
            }
            HStack(spacing: 10) {
                field("Workflow", text: $build.workflow)
                field("分支", text: $build.ref)
            }

            Text("workflow 填文件名，例如 `ios26.yml`。分支默认 main。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.dim)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.dim)
                .textCase(.uppercase)
            TextField(label, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Fluid.Palette.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.soft()
                build.start()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: build.phase == .succeeded ? "arrow.clockwise" : "hammer.fill")
                    Text(build.phase == .succeeded ? "再构建一次" : "开始构建")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.ncnsProminent)
            .disabled(!build.canStart)

            if build.phase.isBusy {
                Button("取消") {
                    Haptics.soft()
                    build.cancel()
                }
                .buttonStyle(.ncnsGlass)
            }

            Button {
                showTutorial = true
            } label: {
                Text("第一次用？看 3 分钟教程")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            BrandBadge()
                .padding(.top, 10)
        }
    }

    // MARK: - Token sheet

    private var tokenSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)

            Text("GitHub Token")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Fluid.Palette.text)

            Text("细粒度 Token，权限只需要 Actions: Read and write、Contents: Read。只存在这台手机的钥匙串里。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("github_pat_…", text: $tokenInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Fluid.Palette.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .ncnsGlass(cornerRadius: 12, interactive: true)

            HStack(spacing: 10) {
                if build.hasToken {
                    Button("退出登录") {
                        build.signOut()
                        showToken = false
                    }
                    .buttonStyle(NcnsGlassButtonStyle(compact: true))
                }

                Spacer()

                Button {
                    Task {
                        await build.saveToken(tokenInput)
                        if build.login != nil { showToken = false }
                    }
                } label: {
                    Text("保存")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(tokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: 0x141420))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(10)
    }

    // MARK: - Bits

    private var timeText: String {
        let total = Int(build.elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var statusTitle: String {
        switch build.phase {
        case .idle: return "还没开始"
        case .dispatching: return "正在触发…"
        case .running: return "构建中"
        case .succeeded: return "构建成功"
        case .failed: return "构建失败"
        case .downloading: return "下载中…"
        case .ready: return "IPA 已就绪"
        }
    }

    private var statusDetail: String {
        switch build.phase {
        case .idle:
            return build.hasToken ? "配好仓库，点下面的按钮" : "先在右上角连上 GitHub"
        case .dispatching:
            return "让 GitHub 起一台 macOS runner"
        case .running:
            return build.runNumber.map { "第 \($0) 次构建 · 大约 3–5 分钟" } ?? "正在编译"
        case .succeeded:
            return "点「下载 IPA」，然后侧载安装"
        case .failed:
            return "看日志找原因，改完再跑"
        case .downloading:
            return "正在从 Release 拉取"
        case .ready:
            return "文件在 App 的 Documents/NcnsDSH/builds 里"
        }
    }

    private var statusIcon: String {
        switch build.phase {
        case .idle: return "hammer"
        case .dispatching, .running, .downloading: return "clock"
        case .succeeded, .ready: return "checkmark.seal.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }

    private var statusColor: Color {
        switch build.phase {
        case .failed: return Color(hex: 0xFF6B6B)
        case .succeeded, .ready: return Theme.mint
        default: return Theme.accent
        }
    }

    @ViewBuilder
    private var recentCard: some View {
        if !build.recent.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("最近构建")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .textCase(.uppercase)
                    .tracking(1.2)

                ForEach(build.recent) { record in
                    Button {
                        Task { await build.download(record) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DSH.Palette.accent)
                                .frame(width: 28, height: 28)
                                .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(record.name)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(DSH.Palette.text)
                                    .lineLimit(1)
                                Text("\(record.tag) · \(dateText(record.date))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(DSH.Palette.tertiary)
                            }

                            Spacer(minLength: 6)

                            Text(byteText(record.size))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(DSH.Palette.tertiary)

                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(DSH.Palette.accent)
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func byteText(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    private func dotColor(_ step: BuildStep) -> Color {
        if step.failed { return Color(hex: 0xFF6B6B) }
        if step.status == "completed" { return Theme.mint }
        if step.status == "in_progress" { return Theme.accent }
        return Color.white.opacity(0.2)
    }

}

#Preview {
    BuildView().environmentObject(BuildStore())
}
