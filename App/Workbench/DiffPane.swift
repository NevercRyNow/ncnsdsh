import SwiftUI

/// 改动：当前工作区 vs 最近一次备份。没有备份就先建一份基线。
struct DiffPane: View {
    @State private var diff: [FileDiff] = []
    @State private var selected: FileDiff?
    @State private var baseline: BackupInfo?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DSH.Palette.hairline)

            if diff.isEmpty {
                empty
            } else {
                list
            }
        }
        .task { reload() }
        .sheet(item: $selected) { item in
            detailSheet(item)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(baseline == nil ? "还没有基线" : "对比 \(baseline?.id ?? "")")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DSH.Palette.tertiary)
                .lineLimit(1)

            Spacer()

            Button {
                Haptics.light()
                _ = try? WorkspaceBackup.create()
                reload()
            } label: {
                Text("建立基线")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DSH.Palette.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var empty: some View {
        EmptyStateView(
            symbol: "arrow.left.arrow.right",
            title: baseline == nil ? "先建一份基线" : "没有改动",
            message: baseline == nil
                ? "建立基线后，工作区里的每个改动都会和它对比。"
                : "当前工作区与基线一致。",
            actionTitle: baseline == nil ? "建立基线" : nil,
            action: baseline == nil ? {
                _ = try? WorkspaceBackup.create()
                reload()
            } : nil
        )
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(diff) { file in
                    Button {
                        selected = file
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 12))
                                .foregroundStyle(DSH.Palette.secondary)
                                .frame(width: 20)

                            Text(file.path)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(DSH.Palette.text)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text("+\(file.added)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(DSH.Palette.success)
                            Text("−\(file.removed)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(DSH.Palette.danger)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(DSH.Palette.hairline).padding(.leading, 46)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func detail(_ file: FileDiff) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(file.ops.enumerated()), id: \.offset) { _, op in
                    HStack(spacing: 6) {
                        Text(prefix(op))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(tint(op))
                            .frame(width: 10, alignment: .leading)
                        Text(op.text)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(tint(op))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 1)
                    .background(background(op))
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func detailSheet(_ file: FileDiff) -> some View {
        NavigationStack {
            detail(file)
                .background(DSH.Palette.canvas)
                .navigationTitle(file.path)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { selected = nil }
                    }
                }
        }
    }

    private func prefix(_ op: DiffOp) -> String {
        switch op {
        case .same: return " "
        case .added: return "+"
        case .removed: return "−"
        }
    }

    private func tint(_ op: DiffOp) -> Color {
        switch op {
        case .same: return DSH.Palette.tertiary
        case .added: return DSH.Palette.success
        case .removed: return DSH.Palette.danger
        }
    }

    private func background(_ op: DiffOp) -> Color {
        switch op {
        case .same: return .clear
        case .added: return DSH.Palette.success.opacity(0.08)
        case .removed: return DSH.Palette.danger.opacity(0.08)
        }
    }

    // MARK: - Loading

    private func reload() {
        let backups = WorkspaceBackup.list()
        baseline = backups.first
        guard let baseline else {
            diff = []
            return
        }

        let baseDir = baseline.url.appendingPathComponent("workspace", isDirectory: true)
        let current = AppFiles.workspace

        let baseFiles = relativeFiles(baseDir)
        let currentFiles = relativeFiles(current)

        var result: [FileDiff] = []
        for path in currentFiles.sorted() {
            let oldText = (try? String(contentsOf: baseDir.appendingPathComponent(path), encoding: .utf8)) ?? ""
            let newText = (try? String(contentsOf: current.appendingPathComponent(path), encoding: .utf8)) ?? ""
            guard oldText != newText else { continue }
            result.append(LineDiff.compute(old: oldText, new: newText, path: path))
        }
        for path in baseFiles.subtracting(currentFiles).sorted() {
            let oldText = (try? String(contentsOf: baseDir.appendingPathComponent(path), encoding: .utf8)) ?? ""
            result.append(LineDiff.compute(old: oldText, new: "", path: path))
        }

        diff = result.sorted { $0.added + $0.removed > $1.added + $1.removed }
    }

    private func relativeFiles(_ root: URL) -> Set<String> {
        var set = Set<String>()
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return set
        }
        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                set.insert(url.path.replacingOccurrences(of: root.path + "/", with: ""))
            }
        }
        return set
    }
}

extension FileDiff: Identifiable {
    var id: String { path }
}
