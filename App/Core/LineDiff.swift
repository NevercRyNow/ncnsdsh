import Foundation

enum DiffOp {
    case same(String)
    case added(String)
    case removed(String)

    var text: String {
        switch self {
        case .same(let line): return line
        case .added(let line): return line
        case .removed(let line): return line
        }
    }
}

struct FileDiff {
    let path: String
    var ops: [DiffOp]
    var added: Int
    var removed: Int
    var unchanged: Int
}

/// 简单的 LCS 行 diff。文件超过 4000 行时退化为「全删 + 全加」，避免 O(n²) 爆内存。
enum LineDiff {
    static func compute(old: String, new: String, path: String) -> FileDiff {
        let a = old.components(separatedBy: "\n")
        let b = new.components(separatedBy: "\n")
        guard a.count <= 4_000, b.count <= 4_000 else {
            return FileDiff(
                path: path,
                ops: a.map { .removed($0) } + b.map { .added($0) },
                added: b.count,
                removed: a.count,
                unchanged: 0
            )
        }

        var table = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in stride(from: a.count - 1, through: 0, by: -1) {
            for j in stride(from: b.count - 1, through: 0, by: -1) {
                table[i][j] = a[i] == b[j]
                    ? table[i + 1][j + 1] + 1
                    : max(table[i + 1][j], table[i][j + 1])
            }
        }

        var ops: [DiffOp] = []
        var added = 0
        var removed = 0
        var unchanged = 0
        var i = 0
        var j = 0

        while i < a.count && j < b.count {
            if a[i] == b[j] {
                ops.append(.same(a[i]))
                unchanged += 1
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                ops.append(.removed(a[i]))
                removed += 1
                i += 1
            } else {
                ops.append(.added(b[j]))
                added += 1
                j += 1
            }
        }
        while i < a.count {
            ops.append(.removed(a[i]))
            removed += 1
            i += 1
        }
        while j < b.count {
            ops.append(.added(b[j]))
            added += 1
            j += 1
        }

        return FileDiff(path: path, ops: ops, added: added, removed: removed, unchanged: unchanged)
    }
}
