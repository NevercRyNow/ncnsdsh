import SwiftUI

/// 工作区详情：一张封面 + 三个数字 + 这个工作区里的会话。
struct WorkspaceDetailView: View {
    let workspace: Workspace

    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var local: LocalStore

    private var sessions: [ChatSession] {
        demo.sessions.filter { $0.workspace == workspace.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                cover
                numbers
                sessionList
            }
            .padding(.horizontal, DSH.Inset.gutter)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(DSH.Palette.canvas.ignoresSafeArea())
        .navigationTitle(workspace.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cover: some View {
        RemoteArtwork(seed: workspace.name, github: ProjectMeta.githubSlug(for: workspace.name), cornerRadius: DSH.Radius.card, showsScrim: true)
            .frame(height: 220)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name)
                        .font(DSH.TypeScale.title)
                        .foregroundStyle(DSH.Palette.text)
                    Text(workspace.path)
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.secondary)
                        .lineLimit(1)
                }
                .padding(16)
            }
    }

    private var numbers: some View {
        HStack(spacing: 0) {
            stat("\(sessions.count)", "会话")
            divider
            stat("\(workspace.running)", "在跑")
            divider
            stat("\(local.recent.count)", "本机")
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: DSH.Radius.card, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(DSH.Palette.hairline)
            .frame(width: 0.5, height: 26)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundStyle(DSH.Palette.text)
            Text(label)
                .font(DSH.TypeScale.caption)
                .foregroundStyle(DSH.Palette.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var sessionList: some View {
        if sessions.isEmpty {
            Text("这个工作区还没有会话。")
                .font(DSH.TypeScale.callout)
                .foregroundStyle(DSH.Palette.secondary)
                .padding(.vertical, 20)
        } else {
            VStack(spacing: 0) {
                ForEach(sessions) { session in
                    NavigationLink(value: Route.session(session.id)) {
                        row(session)
                    }
                    .buttonStyle(.plain)

                    if session.id != sessions.last?.id {
                        Divider()
                            .overlay(DSH.Palette.hairline)
                            .padding(.leading, 68)
                    }
                }
            }
        }
    }

    private func row(_ session: ChatSession) -> some View {
        HStack(spacing: 12) {
            RemoteArtwork(seed: session.title, github: ProjectMeta.githubSlug(for: session.workspace), cornerRadius: DSH.Radius.small)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                    .lineLimit(1)
                Text(session.preview)
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if session.isRunning {
                Circle()
                    .fill(DSH.Palette.accent)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
