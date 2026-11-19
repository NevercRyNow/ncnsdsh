import SwiftUI
import UIKit
import Foundation

struct ChatView: View {
    let sessionID: UUID

    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var chrome: AppChrome
    @EnvironmentObject private var account: AccountStore
    @State private var draft = ""
    @State private var showModelPicker = false
    @State private var showWorkbench = false
    @FocusState private var composerFocused: Bool

    private var session: ChatSession? { demo.session(sessionID) }
    private var messages: [ChatMessage] { demo.messages(for: sessionID) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if messages.isEmpty {
                        EmptyHint(text: "说一句话，它就开始干活。")
                            .padding(.top, 40)
                    }

                    ForEach(messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    .animation(Motion.panel, value: messages.count)

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .defaultScrollAnchor(.bottom)
            .onChange(of: messages.count) { _, _ in
                withAnimation(Motion.gentle) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .background(DSH.Palette.canvas)
        .navigationTitle(session?.title ?? "会话")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    showWorkbench = true
                } label: {
                    Image(systemName: "rectangle.3.group")
                }
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text(session?.title ?? "会话")
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    if session?.isRunning == true {
                        StatusDot()
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .onAppear {
            chrome.chatOpen = true
            if let incoming = demo.pendingDraft {
                draft = incoming
                demo.pendingDraft = nil
                composerFocused = true
            }
        }
        .onDisappear { chrome.chatOpen = false }
        .sheet(isPresented: $showWorkbench) {
            WorkbenchView(sessionID: sessionID)
        }
        .sheet(isPresented: $showModelPicker) {
            ModelPicker(selection: $account.selectedModel, models: account.models)
        }
        .sheet(item: $demo.approval) { request in
            ApprovalSheet(request: request)
                .environmentObject(demo)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        ComposerBar(
            text: $draft,
            placeholder: "问点什么…",
            model: account.selectedModel,
            isBusy: session?.isRunning == true,
            onSend: {
                let outgoing = draft
                draft = ""
                demo.send(outgoing, in: sessionID)
            },
            onModel: { showModelPicker = true },
            onStop: { demo.cancelStreaming(in: sessionID) },
            focused: $composerFocused
        )
    }

    private func send() {
        let text = draft
        draft = ""
        Haptics.soft()
        demo.send(text, in: sessionID)
    }
}

// MARK: - Message

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        if message.role == .user {
            HStack {
                Spacer(minLength: 56)
                Text(message.text)
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if message.text.isEmpty {
                    ShimmerLine(color: Theme.mint)
                        .frame(width: 120)
                } else {
                    Text(message.text)
                        .font(DSH.TypeScale.body)
                        .lineSpacing(5)
                        .foregroundStyle(Fluid.Palette.text.opacity(0.94))
                        .textSelection(.enabled)
                }

                ForEach(message.tools) { tool in
                    ToolRow(tool: tool)
                }

                if message.isStreaming {
                    ShimmerLine(color: Theme.mint)
                        .frame(width: 84)
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contextMenu {
                if !message.text.isEmpty {
                    Button {
                        UIPasteboard.general.string = message.text
                        Haptics.tap()
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

// MARK: - Tool

private struct ToolRow: View {
    let tool: ToolRun

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Motion.snappy) { expanded.toggle() }
                Haptics.soft()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 22, height: 22)
                        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(tool.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Fluid.Palette.text.opacity(0.92))
                        Text(tool.detail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(color)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.dim)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Text(tool.output.isEmpty ? "（还没有输出）" : tool.output)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Fluid.Palette.text.opacity(0.72))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: DSH.Radius.card, style: .continuous))
        .overlay(alignment: .top) {
            if tool.status == .running {
                ShimmerLine()
                    .clipShape(RoundedRectangle(cornerRadius: DSH.Radius.card, style: .continuous))
            }
        }
    }

    private var icon: String {
        switch tool.status {
        case .running: return "bolt.fill"
        case .done: return "checkmark"
        case .failed: return "xmark"
        }
    }

    private var color: Color {
        switch tool.status {
        case .running: return Theme.mint
        case .done: return Color.white.opacity(0.6)
        case .failed: return Color(hex: 0xFF6B6B)
        }
    }

    private var statusText: String {
        switch tool.status {
        case .running: return "运行中"
        case .done: return String(format: "%.1fs", tool.seconds)
        case .failed: return "失败"
        }
    }
}

// MARK: - Approval

struct ApprovalSheet: View {
    let request: ApprovalRequest

    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var chrome: AppChrome
    @EnvironmentObject private var account: AccountStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)

            Text(request.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Fluid.Palette.text)

            Text(request.detail)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Text(request.command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Fluid.Palette.text.opacity(0.9))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button("拒绝") {
                    demo.deny()
                    dismiss()
                }
                .buttonStyle(.ncnsGlass)

                Button("允许") {
                    demo.approve()
                    dismiss()
                }
                .buttonStyle(.ncnsProminent)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ncnsGlass(cornerRadius: 28)
        .padding(10)
        .presentationDetents([.height(320)])
        .presentationBackground(.clear)
        .presentationDragIndicator(.hidden)
    }
}
