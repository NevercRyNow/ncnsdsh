import SwiftUI

/// 环境切换器：本机、电脑、服务器三类环境。
struct EnvironmentView: View {
    @EnvironmentObject private var manager: EnvironmentManager
    @EnvironmentObject private var store: HostStore
    @Environment(\.dismiss) private var dismiss

    @State private var showConnect = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(manager.profiles) { profile in
                        card(profile)
                    }

                    Button {
                        Haptics.tap()
                        showConnect = true
                    } label: {
                        Label("添加设备", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(DSH.Palette.text)
                    }
                    .buttonStyle(.plain)

                    Text("切环境不会清空会话。远端环境要先用 `dsh web` 起一个带 token 的网关，再扫码配对。")
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("环境")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showConnect) {
                ConnectView().environmentObject(store)
            }
            .onAppear {
                manager.sync(hosts: store.hosts, currentHost: store.current)
            }
            .onChange(of: store.hosts.count) { _, _ in
                manager.sync(hosts: store.hosts, currentHost: store.current)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func card(_ profile: EnvironmentProfile) -> some View {
        let status = manager.status(for: profile, hosts: store.hosts, currentHost: store.current)
        let selected = manager.currentID == profile.id

        return Button {
            guard status != .unsupported("暂未接入") else { return }
            manager.select(profile.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: profile.type.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selected ? DSH.Palette.accent : DSH.Palette.secondary)
                    .frame(width: 38, height: 38)
                    .background(DSH.Palette.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(profile.name)
                            .font(DSH.TypeScale.headline)
                            .foregroundStyle(DSH.Palette.text)
                            .lineLimit(1)
                        Circle()
                            .fill(status.tint)
                            .frame(width: 5, height: 5)
                    }

                    Text(profile.type.note)
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.tertiary)
                        .lineLimit(2)

                    Text(profile.workspace)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(DSH.Palette.tertiary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("v" + profile.runtimeVersion)
                        Text(status.label)
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(DSH.Palette.tertiary)
                }

                Spacer(minLength: 6)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DSH.Palette.accent)
                }
            }
            .padding(14)
            .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? DSH.Palette.accent.opacity(0.5) : Color.clear, lineWidth: 0.8)
            )
            .opacity(status == .unsupported("暂未接入") ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Text(profile.type.note)
            if profile.type == .remoteDSH {
                Button("断开", role: .destructive) {
                    store.current = nil
                }
            }
        }
    }
}
