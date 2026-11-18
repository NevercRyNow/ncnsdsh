import SwiftUI
import QuickLook
import UIKit

/// 文件浏览器：从工作区开始，可进目录、可预览文本或图片。
struct FileBrowserPane: View {
    var sortByDate = false
    var title: String?

    @State private var directory: URL = AppFiles.workspace
    @State private var entries: [Entry] = []
    @State private var preview: URL?

    struct Entry: Identifiable {
        var id: String { url.path }
        let url: URL
        let isDirectory: Bool
        let size: Int
        let modified: Date
    }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumb
            Divider().overlay(DSH.Palette.hairline)

            if entries.isEmpty {
                Text("这个文件夹是空的。")
                    .font(DSH.TypeScale.footnote)
                    .foregroundStyle(DSH.Palette.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            row(entry)
                            Divider().overlay(DSH.Palette.hairline).padding(.leading, 44)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: directory) { _, _ in load() }
        .sheet(item: $preview) { url in
            FilePreview(url: url)
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Button {
                directory = AppFiles.workspace
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DSH.Palette.secondary)

            Text(relativePath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DSH.Palette.tertiary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var relativePath: String {
        let base = AppFiles.workspace.path
        let path = directory.path
        if path == base { return "workspace" }
        return "workspace" + path.replacingOccurrences(of: base, with: "")
    }

    private func row(_ entry: Entry) -> some View {
        Button {
            if entry.isDirectory {
                directory = entry.url
            } else {
                preview = entry.url
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: entry.isDirectory ? "folder" : "doc.text")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(entry.isDirectory ? DSH.Palette.accent : DSH.Palette.secondary)
                    .frame(width: 22)

                Text(entry.url.lastPathComponent)
                    .font(.system(size: 14))
                    .foregroundStyle(DSH.Palette.text)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if !entry.isDirectory {
                    Text(byteText(entry.size))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(DSH.Palette.tertiary)
                }

                if sortByDate {
                    Text(timeText(entry.modified))
                        .font(.system(size: 11))
                        .foregroundStyle(DSH.Palette.tertiary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DSH.Palette.tertiary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)) ?? []

        entries = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return Entry(
                url: url,
                isDirectory: values.isDirectory ?? false,
                size: values.fileSize ?? 0,
                modified: values.contentModificationDate ?? .distantPast
            )
        }
        .sorted { left, right in
            if left.isDirectory != right.isDirectory { return left.isDirectory }
            return sortByDate
                ? left.modified > right.modified
                : left.url.lastPathComponent < right.url.lastPathComponent
        }
    }

    private func byteText(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}

/// 文本直接读出来显示，图片用 QuickLook。
struct FilePreview: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var text: String?
    @State private var editing = false

    var body: some View {
        NavigationStack {
            Group {
                if let text {
                    ScrollView {
                        Text(text)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(DSH.Palette.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .textSelection(.enabled)
                    }
                } else {
                    QuickLookPreview(url: url)
                        .ignoresSafeArea()
                }
            }
            .background(DSH.Palette.canvas)
            .navigationTitle(url.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if text != nil {
                        Button("编辑") { editing = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $editing) {
            FileEditorView(url: url)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: url), data.count < 400_000 else { return }
        guard let text = String(data: data, encoding: .utf8), !text.contains("\u{0}") else { return }
        self.text = text
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
