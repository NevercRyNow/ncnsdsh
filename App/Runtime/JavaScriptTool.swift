import Foundation
import JavaScriptCore

/// 本机 JavaScript 执行器：用的是系统自带 JavaScriptCore，**不是 Node**。
/// 没有 npm、没有 require、没有子进程；只暴露 console 与受限的文件读写。
enum JavaScriptTool {
    static func run(_ source: String, allowsWrite: Bool) -> String {
        guard let context = JSContext() else {
            return "错误：JavaScriptCore 不可用"
        }

        var output: [String] = []
        let consoleLog: @convention(block) (String) -> Void = { line in
            if output.count < 200 { output.append(line) }
        }
        context.setObject(consoleLog, forKeyedSubscript: "consoleLog" as NSString)
        context.evaluateScript("var console = { log: function(s){ consoleLog(String(s)); } };")

        let readBlock: @convention(block) (String) -> String = { path in
            guard let url = try? Sandbox.shared.resolve(path, write: false, tool: "run_javascript"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
            return String(text.prefix(20_000))
        }
        context.setObject(readBlock, forKeyedSubscript: "nativeRead" as NSString)

        let writeBlock: @convention(block) (String, String) -> Bool = { path, text in
            guard allowsWrite,
                  let url = try? Sandbox.shared.resolve(path, write: true, tool: "run_javascript") else { return false }
            return (try? Data(text.utf8).write(to: url, options: .atomic)) != nil
        }
        context.setObject(writeBlock, forKeyedSubscript: "nativeWrite" as NSString)

        context.evaluateScript("""
        var fs = {
          read: function(p){ return nativeRead(p); },
          write: function(p, t){ return nativeWrite(p, String(t)); }
        };
        """)

        context.exception = nil
        let result = context.evaluateScript(source)
        if let exception = context.exception {
            let message = exception.toString() ?? "未知错误"
            return "错误：\(message)"
        }

        var lines = output
        if let value = result, !value.isUndefined, !value.isNull {
            lines.append(String(describing: value))
        }
        return lines.isEmpty ? "（无输出）" : lines.joined(separator: "\n")
    }
}
