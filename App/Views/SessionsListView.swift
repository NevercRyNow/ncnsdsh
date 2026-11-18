import SwiftUI

/// 会话列表：远端（演示数据）与本机会话放在同一页，可搜索、可跳转。
struct SessionsListView: View {
    @EnvironmentObject private var demo: DemoStore
    @EnvironmentObject private var local: LocalStore

    @State private var query = ""

    private var remoteSessions: [ChatSession] {
        guard !query.isEmpty else { return demo.sessions }
        return demo.sessions.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.workspace.localizedCaseInsensitiveContains(query)
        }
    }

    private var localSessions: [LocalSession] {
        guard !query.isEmpty else { return local.recent }
        return local.recent.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                searchField

                if !localSessions.isEmpty {
                    section("本机") {
                        ForEach(localSessions) { session in
                            NavigationLink(value: Route.localSession(session.id)) {
                                localRow(session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !remoteSessions.isEmpty {
                    section("远端") {
                        ForEach(remoteSessions) { session in
                            NavigationLink(value: Route.session(session.id)) {
                                remoteRow(session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if localSessions.isEmpty && remoteSessions.isEmpty {
                    EmptyStateView(
                        symbol: "bubble.left.and.bubble.right",
                        title: query.isEmpty ? "还没有会话" : "没有匹配的会话",
                        message: query.isEmpty ? "从首页或项目里开一个。" : "换个关键词试试。",
                        actionTitle: nil,
                        action: nil
                    )
                    .frame(height: 320)
                }
            }
            .padding(.horizontal, DSH.Inset.gutter)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(DSH.Palette.canvas)
        .navigationTitle("会话")
        .navigationBarTitleDisplayMode(.large)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(DSH.Palette.tertiary)
            TextField("搜索会话或项目", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(DSH.TypeScale.callout)
                .foregroundStyle(DSH.Palette.text)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DSH.Palette.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DSH.TypeScale.footnote)
                .foregroundStyle(DSH.Palette.tertiary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func remoteRow(_ session: ChatSession) -> some View {
        HStack(spacing: 12) {
            RemoteArtwork(seed: session.title, github: ProjectMeta.githubSlug(for: session.workspace), cornerRadius: 8)
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                    .lineLimit(1)
                Text("\(session.workspace) · \(session.relativeTime)")
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if session.isRunning {
                Circle()
                    .fill(DSH.Palette.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    private func localRow(_ session: LocalSession) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DSH.Palette.success)
                .frame(width: 42, height: 42)
                .background(DSH.Palette.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                    .lineLimit(1)
                Text(session.preview)
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(session.model)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(DSH.Palette.tertiary)
        }
        .padding(12)
        .contentShape(Rectangle())
    }
}
