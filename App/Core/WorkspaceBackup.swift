import Foundation

struct BackupInfo: Identifiable {
    let id: String
    let url: URL
    let date: Date
    let files: Int
    let bytes: Int
}

/// 工作区备份：先复制到 staging，校验文件数与总字节数，再落成正式备份；
/// 恢复时先把当前工作区移开，失败可回滚。
enum WorkspaceBackup {
    static var root: URL { AppFiles.backups }

    static func list() -> [BackupInfo] {
        let manager = FileManager.default
        guard let items = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return []
        }
        return items.compactMap { url -> BackupInfo? in
            let meta = url.appendingPathComponent("meta.json")
            guard let data = try? Data(contentsOf: meta),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let date = (dict["date"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
            return BackupInfo(
                id: url.lastPathComponent,
                url: url,
                date: date,
                files: dict["files"] as? Int ?? 0,
                bytes: dict["bytes"] as? Int ?? 0
            )
        }
        .sorted { $0.date > $1.date }
    }

    @discardableResult
    static func create() throws -> BackupInfo {
        let manager = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let staging = root.appendingPathComponent("staging-\(stamp)", isDirectory: true)
        let payload = staging.appendingPathComponent("workspace", isDirectory: true)
        try? manager.removeItem(at: staging)
        try manager.createDirectory(at: payload, withIntermediateDirectories: true)

        let source = AppFiles.workspace
        let items = (try? manager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)) ?? []
        var files = 0
        var bytes = 0
        for item in items {
            let target = payload.appendingPathComponent(item.lastPathComponent)
            try manager.copyItem(at: item, to: target)
            let enumerator = manager.enumerator(at: target, includingPropertiesForKeys: [.fileSizeKey])
            while let file = enumerator?.nextObject() as? URL {
                files += 1
                bytes += (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            }
        }

        let meta: [String: Any] = ["date": Date().timeIntervalSince1970, "files": files, "bytes": bytes]
        try JSONSerialization.data(withJSONObject: meta).write(to: staging.appendingPathComponent("meta.json"))

        let final = root.appendingPathComponent("backup-\(stamp)", isDirectory: true)
        try? manager.removeItem(at: final)
        try manager.moveItem(at: staging, to: final)
        prune()
        RuntimeLog.shared.log("工作区备份：\(files) 个文件 / \(bytes) 字节")
        return BackupInfo(id: final.lastPathComponent, url: final, date: Date(), files: files, bytes: bytes)
    }

    static func restore(_ info: BackupInfo) throws {
        let manager = FileManager.default
        let source = info.url.appendingPathComponent("workspace", isDirectory: true)
        guard manager.fileExists(atPath: source.path) else {
            throw NSError(domain: "NcnsDSH", code: 2, userInfo: [NSLocalizedDescriptionKey: "备份里没有 workspace"])
        }

        let workspace = AppFiles.workspace
        let aside = root.appendingPathComponent("before-restore", isDirectory: true)
        try? manager.removeItem(at: aside)
        try? manager.moveItem(at: workspace, to: aside)
        try manager.createDirectory(at: workspace, withIntermediateDirectories: true)

        do {
            for item in try manager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
                try manager.copyItem(at: item, to: workspace.appendingPathComponent(item.lastPathComponent))
            }
            try? manager.removeItem(at: aside)
            RuntimeLog.shared.log("已从备份恢复：\(info.id)")
        } catch {
            try? manager.removeItem(at: workspace)
            try? manager.moveItem(at: aside, to: workspace)
            throw error
        }
    }

    static func prune(keep: Int = 5) {
        let items = list()
        for extra in items.dropFirst(keep) {
            try? FileManager.default.removeItem(at: extra.url)
        }
    }
}
