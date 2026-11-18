import SwiftUI

/// 文本编辑：保存前过沙箱（只读模式直接拒绝），大文件不允许编辑。
struct FileEditorView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var original = ""
    @State private var error: String?

    private var relativePath: String {
        url.path.replacingOccurrences(of: AppFiles.workspace.path + "/", with: "")
    }

    private var canEdit: Bool {
        (try? Data(contentsOf: url).count).map { $0 <= 200_000 } ?? false
    }

    private var dirty: Bool { text != original }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(DSH.Palette.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }

                TextEditor(text: $text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DSH.Palette.text)
                    .scrollContentBackground(.hidden)
                    .background(DSH.Palette.canvas)
                    .disabled(!canEdit)
            }
            .background(DSH.Palette.canvas)
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!dirty || !canEdit)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
        .preferredColorScheme(.dark)
    }

    private func load() {
        guard canEdit else {
            error = "文件超过 200 KB，只读。"
            return
        }
        let value = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        text = value
        original = value
    }

    private func save() {
        do {
            let checked = try Sandbox.shared.resolve(relativePath, write: true, tool: "editor")
            try Data(text.utf8).write(to: checked, options: .atomic)
            original = text
            Haptics.success()
            RuntimeLog.shared.log("保存 \(relativePath)（\(text.utf8.count) 字节）")
            dismiss()
        } catch {
            self.error = error.localizedDescription
            Haptics.failure()
        }
    }
}
