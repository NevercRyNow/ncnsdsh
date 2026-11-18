import Foundation
import UIKit

/// App 在「文件」App 里露出来的那棵树：
/// On My iPhone → NcnsDSH → workspace / builds
enum AppFiles {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    static var root: URL {
        let url = documents.appendingPathComponent("NcnsDSH", isDirectory: true)
        ensure(url)
        return url
    }

    static var workspace: URL {
        let url = root.appendingPathComponent("workspace", isDirectory: true)
        ensure(url)
        return url
    }

    static var builds: URL {
        let url = root.appendingPathComponent("builds", isDirectory: true)
        ensure(url)
        return url
    }

    /// 备份不进「文件」App，放在 Application Support 下。
    static var backups: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = url.appendingPathComponent("NcnsDSH/backups", isDirectory: true)
        ensure(dir)
        return dir
    }

    /// 「文件」App 里看到的路径字样。
    static var displayPath: String {
        "On My iPhone/NcnsDSH"
    }

    /// 打开「文件」App（没有官方 API，这个 scheme 是系统自己的）。
    static func reveal() {
        guard let url = URL(string: "shareddocuments://") else { return }
        UIApplication.shared.open(url)
    }

    static func copyPath() {
        UIPasteboard.general.string = root.path
    }

    @discardableResult
    private static func ensure(_ url: URL) -> URL {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
