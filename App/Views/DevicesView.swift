import SwiftUI

/// 设备中心：已配对的宿主、连接状态、重连与诊断。
struct DevicesView: View {
    @EnvironmentObject private var store: HostStore
    @State private var showConnect = false
    @State private var bridge: BridgeCapabilities?
    @State private var bridgeError: String?
    @State private var probing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.current != nil {
                    bridgeCard
                }

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
        .task(id: store.current?.id) {
            guard let host = store.current else { return }
            await probe(host)
        }
    }

    /// 原生桥协商：问一次 `/dsh-go/v1/capabilities`。
    /// 这不是猜——协议按 dsh-go 的公开契约实现，拿不到就如实说拿不到。
    private var bridgeCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: bridge != nil ? "checkmark.seal.fill" : (probing ? "hourglass" : "exclamationmark.triangle.fill"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(bridge != nil ? Fluid.Palette.mint : (probing ? Fluid.Palette.mist : Fluid.Palette.amber))
                .frame(width: 34, height: 34)
                .background((bridge != nil ? Fluid.Palette.mint : Fluid.Palette.amber).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(bridge != nil ? "原生桥可用" : (probing ? "正在协商协议…" : "原生桥不可用"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Fluid.Palette.text)
                Text(bridge.map { "协议 v\($0.protocolVersion) · bridge \($0.bridgeVersion) · \($0.capabilities.count) 项能力" } ?? bridgeError ?? "")
                    .font(Fluid.Typography.caption)
                    .foregroundStyle(Fluid.Palette.mist)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if !probing, let host = store.current {
                Button("重试") {
                    Task { await probe(host) }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Fluid.Palette.iceBlue)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluidSurface()
    }

    private func probe(_ host: Host) async {
        probing = true
        bridge = nil
        bridgeError = nil
        do {
            bridge = try await DshBridge.capabilities(for: host)
        } catch {
            bridgeError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        probing = false
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
        // 整行念成一句：主机名、地址、是否已连接。
        .accessibilityElement(children: .contain)
    }
}
