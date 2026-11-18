import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct LocalChatView: View {
    let sessionID: UUID

    @EnvironmentObject private var local: LocalStore
    @EnvironmentObject private var account: AccountStore
    @EnvironmentObject private var config: ModelConfigurationStore
    @EnvironmentObject private var chrome: AppChrome
    @Environment(\.scenePhase) private var scenePhase

    @State private var draft = ""
    @State private var showModelPicker = false
    @State private var showWorkbench = false
    @State private var pickedModel: String = ""
    @State private var stagesExpanded = true
    @State private var showExport = false
    @State private var showImporter = false
    @State private var showTrace = false
    @FocusState private var composerFocused: Bool

    private var session: LocalSession? { local.session(sessionID) }
    private var messages: [LocalMessage] { session?.messages ?? [] }
    private var isRunning: Bool { local.runningID == sessionID }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if !local.stages.isEmpty {
                        activityCard
                    }

                    if messages.isEmpty {
                        CodexIntro(model: pickedModel.isEmpty ? (session?.model ?? account.selectedModel) : pickedModel) {
                            showModelPicker = true
                        }
                    }

                    ForEach(messages) { message in
                        LocalMessageRow(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    .animation(Motion.panel, value: messages.count)

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.count) { _, _ in
                withAnimation(Motion.gentle) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: messages.last?.text.count ?? 0) { _, _ in
                if isRunning {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .background(DSH.Palette.canvas)
        .navigationTitle(session?.title ?? "本机会话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    showTrace = true
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                }
                .disabled(local.trace == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        draft = ""
                    } label: {
                        Label("清空输入", systemImage: "xmark.circle")
                    }
                    Button {
                        local.compress(sessionID)
                        Haptics.success()
                    } label: {
                        Label("压缩上下文", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                    Button {
                        UIPasteboard.general.string = exportText
                        Haptics.success()
                    } label: {
                        Label("复制全文", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: exportText) {
                        Label("导出会话", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    showWorkbench = true
                } label: {
                    Image(systemName: "rectangle.3.group")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isRunning {
                    Button("停止") {
                        Haptics.soft()
                        local.stop()
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
            }
        }
        .onAppear {
            if session?.model == nil || config.model.isEmpty {
                config.model = session?.model ?? account.selectedModel
            }
            pickedModel = config.model.isEmpty ? (session?.model ?? account.selectedModel) : config.model
            chrome.chatOpen = true
        }
        .onDisappear { chrome.chatOpen = false }
        .sheet(isPresented: $showWorkbench) {
            WorkbenchView(sessionID: sessionID)
        }
        .sheet(isPresented: $showTrace) {
            TurnTraceSheet()
        }
        .sheet(isPresented: $showModelPicker) {
            ModelIntelligenceDeck()
        }
        .onChange(of: pickedModel) { _, model in
            local.setModel(model, for: sessionID)
        }
        .onChange(of: config.model) { _, model in
            pickedModel = model
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let name = url.lastPathComponent
            let destination = LocalTools.workspace.appendingPathComponent(name)
            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: url, to: destination)
                draft += (draft.isEmpty ? "" : "\n") + "已附加：\(name)"
                Haptics.success()
            } catch {
                Haptics.failure()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if let error = local.error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0xFFB86B))
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                composer
            }
            .background(Theme.ink.opacity(0.001))
        }
    }

    private var exportText: String {
        let title = session?.title ?? "本机会话"
        let body = messages.map { message in
            switch message.role {
            case .user: return "你：" + message.text
            case .assistant: return "NcnsDSH：" + message.text
            case .tool: return "[工具 \(message.toolName ?? "")] " + message.text
            case .system: return "[系统] " + message.text
            }
        }.joined(separator: "\n\n")
        return "# \(title)\n\n" + body
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(DSH.Motion.snap) { stagesExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    if isRunning {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(DSH.Palette.accent)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DSH.Palette.success)
                    }

                    Text("Agent 活动")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DSH.Palette.secondary)

                    Text("\(local.stages.count) 步")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DSH.Palette.tertiary)

                    Spacer()

                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DSH.Palette.tertiary)
                        .rotationEffect(.degrees(stagesExpanded ? 0 : 180))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if stagesExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(local.stages) { stage in
                        HStack(spacing: 8) {
                            Image(systemName: stage.symbol)
                                .font(.system(size: 10))
                                .foregroundStyle(tint(for: stage))
                                .frame(width: 14)
                            Text(stage.label)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(DSH.Palette.secondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: DSH.Radius.card, style: .continuous))
    }

    private func tint(for stage: LocalStage) -> Color {
        switch stage {
        case .thinking: return DSH.Palette.tertiary
        case .streaming: return DSH.Palette.accent
        case .tool: return DSH.Palette.warning
        case .done: return DSH.Palette.success
        case .failed: return DSH.Palette.danger
        }
    }

    private var onboarding: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "cpu")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.mint)
            Text("本机模式")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("不连电脑，模型直连 DeepSeek。它能读写这个 App 的工作区（\(LocalTools.names.joined(separator: " / "))），文件放在「文件」App 的「我的 iPhone → NcnsDSH → workspace」里。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 28)
    }

    private var composer: some View {
        ComposerBar(
            text: $draft,
            placeholder: "让本机做点什么…",
            model: pickedModel.isEmpty ? (session?.model ?? account.selectedModel) : pickedModel,
            isBusy: isRunning,
            onSend: {
                let outgoing = draft
                draft = ""
                local.send(
                    outgoing,
                    in: sessionID,
                    model: config.model.isEmpty ? (session?.model ?? account.selectedModel) : config.model,
                    key: account.key,
                    tools: config.activeToolNames,
                    allowsWrite: config.allowsWrite,
                    modeHint: config.mode.systemHint
                )
            },
            onAttach: { showImporter = true },
            onModel: { showModelPicker = true },
            focused: $composerFocused
        )
    }

    private func send() {
        let text = draft
        draft = ""
        Haptics.soft()
        local.send(
            text,
            in: sessionID,
            model: config.model.isEmpty ? (session?.model ?? account.selectedModel) : config.model,
            key: account.key,
            tools: config.activeToolNames,
            allowsWrite: config.allowsWrite,
            modeHint: config.mode.systemHint
        )
    }
}

private struct LocalMessageRow: View {
    let message: LocalMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 56)
                Text(message.text)
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }

        case .tool:
            HStack(spacing: 10) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.mint)
                    .frame(width: 22, height: 22)
                    .background(Theme.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(message.toolName ?? "tool")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Text(message.text.replacingOccurrences(of: "\n", with: " · "))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: DSH.Radius.card, style: .continuous))

        case .assistant, .system:
            VStack(alignment: .leading, spacing: 8) {
                if message.text.isEmpty {
                    ShimmerLine(color: Theme.mint).frame(width: 120)
                } else {
                    Text(message.text)
                        .font(DSH.TypeScale.body)
                        .lineSpacing(5)
                        .foregroundStyle(.white.opacity(0.94))
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
