import SwiftUI

/// 设备中心：已配对的宿主、连接状态、重连与诊断。
struct DevicesView: View {
    @EnvironmentObject private var store: HostStore
    @State private var showConnect = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.hosts.isEmpty {
                    EmptyStateView(
                        symbol: "desktopcomputer",
                        title: "还没有设备",
                        message: "在电脑上运行 `dsh web --host <局域网地址>`，然后把带 token 的地址扫进来。",
                        actionTitle: "连接电脑",
                        action: { showConnect = true }
                    )
                    .frame(height: 360)
                } else {
                    VStack(spacing: 0) {
                        ForEach(store.hosts) { host in
                            row(host)
                            if host.id != store.hosts.last?.id {
                                Divider().overlay(DSH.Palette.hairline).padding(.leading, 62)
                            }
                        }
                    }
                    .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            }
            .padding(.horizontal, DSH.Inset.gutter)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(DSH.Palette.canvas)
        .navigationTitle("设备")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showConnect) {
            ConnectView().environmentObject(store)
        }
    }

    private func row(_ host: Host) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(store.current?.id == host.id ? DSH.Palette.success : DSH.Palette.tertiary)
                .frame(width: 36, height: 36)
                .background(DSH.Palette.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(host.displayName)
                    .font(DSH.TypeScale.body)
                    .foregroundStyle(DSH.Palette.text)
                    .lineLimit(1)
                Text(host.originText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DSH.Palette.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if store.current?.id == host.id {
                Text("已连接")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DSH.Palette.success)
            } else {
                Button("连接") {
                    Haptics.tap()
                    store.open(host)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DSH.Palette.accent)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }
}
