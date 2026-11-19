import Compression
import CryptoKit
import Foundation

/// 随包 runtime.zip 的读取与安装。
///
/// 归档格式由 dsh-Go 的 `tooling/ios` 生成：第一个成员是 **stored** 的 `manifest.json`，
/// 其余是 `files/<path>` 的 deflate。这里按同一约定读取，逐文件校验长度与 SHA-256，
/// 解到 `<base>/tree` 后再交给引擎当 `runtime_root`。
struct RuntimeFile: Codable, Equatable {
    let path: String
    let size: Int
    let sha256: String
}

struct RuntimeManifest: Codable {
    let schema: Int
    let runtimeVersion: String
    let dshVersion: String?
    let nodeVersion: String
    let files: [RuntimeFile]

    var isValid: Bool {
        schema == 1 && !runtimeVersion.isEmpty && !files.isEmpty
    }
}

enum RuntimeArchiveError: LocalizedError {
    case invalid(String)
    case sizeMismatch(String)
    case digestMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let detail): return "运行时归档无效：\(detail)"
        case .sizeMismatch(let path): return "运行时文件长度不符：\(path)"
        case .digestMismatch(let path): return "运行时文件校验失败：\(path)"
        }
    }
}

struct RuntimeArchive {
    private struct Entry {
        let method: Int
        let packedSize: Int
        let size: Int
        let dataOffset: Int
    }

    let manifest: RuntimeManifest
    private let bytes: Data
    private let entries: [String: Entry]

    private static let maxManifest = 16 * 1024 * 1024
    private static let maxFile = 512 * 1024 * 1024

    init(url: URL) throws {
        let data = try Data(contentsOf: url, options: .alwaysMapped)
        guard data.count >= 22 else { throw RuntimeArchiveError.invalid("文件太短") }

        func u16(_ at: Int) -> Int { Int(data[at]) | Int(data[at + 1]) << 8 }
        func u32(_ at: Int) -> Int { u16(at) | u16(at + 2) << 16 }

        // EOCD 紧贴文件末尾（生成器不写注释）。
        let footer = data.count - 22
        guard u32(footer) == 0x0605_4b50 else { throw RuntimeArchiveError.invalid("找不到中央目录") }
        let count = u16(footer + 10)
        let directoryOffset = u32(footer + 16)
        guard count >= 2, directoryOffset < footer else { throw RuntimeArchiveError.invalid("条目数量异常") }

        var entries: [String: Entry] = [:]
        var ordered: [String] = []
        var cursor = directoryOffset
        for index in 0..<count {
            guard cursor + 46 <= footer, u32(cursor) == 0x0201_4b50 else {
                throw RuntimeArchiveError.invalid("中央目录损坏")
            }
            let method = u16(cursor + 10)
            let packedSize = u32(cursor + 20)
            let size = u32(cursor + 24)
            let nameLength = u16(cursor + 28)
            let headerOffset = u32(cursor + 42)
            guard nameLength > 0, size <= RuntimeArchive.maxFile,
                  let name = String(data: data[(cursor + 46)..<(cursor + 46 + nameLength)], encoding: .utf8),
                  entries[name] == nil, !name.contains(".."), !name.hasPrefix("/")
            else { throw RuntimeArchiveError.invalid("条目名不合法") }

            guard headerOffset + 30 + nameLength <= directoryOffset, u32(headerOffset) == 0x0403_4b50 else {
                throw RuntimeArchiveError.invalid("本地头损坏")
            }
            let dataOffset = headerOffset + 30 + nameLength
            guard dataOffset + packedSize <= directoryOffset else {
                throw RuntimeArchiveError.invalid("数据越界")
            }
            if index == 0 {
                guard name == "manifest.json", method == 0, size <= RuntimeArchive.maxManifest else {
                    throw RuntimeArchiveError.invalid("清单不是第一个 stored 成员")
                }
            }
            entries[name] = Entry(method: method, packedSize: packedSize, size: size, dataOffset: dataOffset)
            ordered.append(name)
            cursor += 46 + nameLength
        }

        guard let first = entries["manifest.json"] else { throw RuntimeArchiveError.invalid("缺少清单") }
        let manifestData = data[first.dataOffset..<(first.dataOffset + first.size)]
        guard let manifest = try? JSONDecoder().decode(RuntimeManifest.self, from: manifestData),
              manifest.isValid
        else { throw RuntimeArchiveError.invalid("清单解析失败") }
        self.bytes = data
        self.manifest = manifest
        self.entries = entries
    }

    /// 解出整个 runtime 到 `root`（调用方保证目录已存在且为空）。
    func extractAll(to root: URL) throws {
        let fm = FileManager.default
        for file in manifest.files {
            guard let entry = entries["files/" + file.path] else {
                throw RuntimeArchiveError.invalid("清单里的 \(file.path) 不在归档中")
            }
            let target = root.appendingPathComponent(file.path)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)

            let data = try inflate(entry)
            guard data.count == file.size else { throw RuntimeArchiveError.sizeMismatch(file.path) }
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard digest == file.sha256 else { throw RuntimeArchiveError.digestMismatch(file.path) }
            try data.write(to: target, options: .atomic)
        }
    }

    private func inflate(_ entry: Entry) throws -> Data {
        let source = bytes.subdata(in: entry.dataOffset..<(entry.dataOffset + entry.packedSize))
        if entry.method == 0 { return source }

        var output = Data()
        var produced = 0
        let chunk = 256 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunk)
        defer { buffer.deallocate() }
        let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { stream.deallocate() }
        guard compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            throw RuntimeArchiveError.invalid("解压初始化失败")
        }
        defer { compression_stream_destroy(stream) }

        try source.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else {
                throw RuntimeArchiveError.invalid("压缩流为空")
            }
            stream.pointee.src_ptr = UnsafePointer(base)
            stream.pointee.src_size = entry.packedSize
            repeat {
                stream.pointee.dst_ptr = buffer
                stream.pointee.dst_size = chunk
                let status = compression_stream_process(stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                guard status == COMPRESSION_STATUS_OK || status == COMPRESSION_STATUS_END else {
                    throw RuntimeArchiveError.invalid("压缩流异常结束")
                }
                let count = chunk - stream.pointee.dst_size
                produced += count
                guard produced <= entry.size else { throw RuntimeArchiveError.sizeMismatch("超出清单长度") }
                if count > 0 { output.append(buffer, count: count) }
                if status == COMPRESSION_STATUS_END { break }
            } while true
        }
        return output
    }
}

/// 安装/升级 runtime：解到临时目录再整体换位，避免半装状态被引擎读到。
struct RuntimeInstaller {
    let base: URL
    private let fm = FileManager.default

    init(base: URL) { self.base = base }

    var root: URL { base.appendingPathComponent("tree", isDirectory: true) }

    var installedVersion: String? {
        let marker = base.appendingPathComponent("version.txt")
        return try? String(contentsOf: marker, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func install(from zip: URL, progress: ((Double) -> Void)? = nil) throws -> RuntimeManifest {
        let archive = try RuntimeArchive(url: zip)
        let staging = base.appendingPathComponent("staging-\(archive.manifest.runtimeVersion)", isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        try? fm.removeItem(at: staging)

        if installedVersion == archive.manifest.runtimeVersion, fm.fileExists(atPath: root.path) {
            return archive.manifest
        }

        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        try archive.extractAll(to: staging)
        progress?(1)

        try? fm.removeItem(at: root)
        try fm.moveItem(at: staging, to: root)
        try archive.manifest.runtimeVersion.write(
            to: base.appendingPathComponent("version.txt"), atomically: true, encoding: .utf8
        )
        return archive.manifest
    }
}
