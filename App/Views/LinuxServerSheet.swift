import SwiftUI

/// 添加一台远程 Linux：跑 `dsh web --host 0.0.0.0`，填地址与 token。
struct LinuxServerSheet: View {
    @EnvironmentObject private var store: HostStore
    @EnvironmentObject private var manager: EnvironmentManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var token = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("在 Linux 上运行 dsh web --host 0.0.0.0 --port 3080，把打印出来的地址和 token 填在这里。")
                        .font(DSH.TypeScale.footnote)
                        .foregroundStyle(DSH.Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    field("名称（可选）", text: $name, placeholder: "build-box")
                    field("地址", text: $address, placeholder: "10.0.0.8:3080")
                    field("Token", text: $token, placeholder: "dsh web 启动时打印的 token")

                    Button {
                        add()
                    } label: {
                        Text("添加并连接")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(DSH.Palette.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(address.isEmpty || token.isEmpty)

                    if let error = store.lastError {
                        Text(error)
                            .font(DSH.TypeScale.footnote)
                            .foregroundStyle(DSH.Palette.danger)
                    }

                    Text("Linux 只跑在服务器上。iPhone 本地没有 Linux 运行时，App 也不会假装有。")
                        .font(.system(size: 10))
                        .foregroundStyle(DSH.Palette.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(DSH.Palette.canvas)
            .navigationTitle("添加 Linux 服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DSH.Palette.tertiary)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(DSH.Palette.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(DSH.Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func add() {
        store.connect(address: address, token: token, kind: .linux)
        guard store.lastError == nil else {
            Haptics.failure()
            return
        }
        if !name.trimmingCharacters(in: .whitespaces).isEmpty, let host = store.current {
            store.rename(host, to: name.trimmingCharacters(in: .whitespaces))
        }
        manager.sync(hosts: store.hosts, currentHost: store.current)
        if let id = store.current?.id { manager.select(id) }
        Haptics.success()
        dismiss()
    }
}
