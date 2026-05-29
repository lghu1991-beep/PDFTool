import Foundation

enum EngineError: LocalizedError {
    case engineNotFound
    case badResponse(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .engineNotFound:
            return "未找到 PDF 处理引擎。请先执行 ./build-native-mac.sh 打包，或在项目根目录设置 PDFTOOL_ROOT 后用 ./run-native-mac.sh 运行。"
        case .badResponse(let msg):
            return "引擎返回异常：\(msg)"
        case .commandFailed(let msg):
            return msg
        }
    }
}

struct EngineClient {
    static func run(command: String, arguments: [String]) async throws -> [String: Any] {
        let (executable, prefixArgs) = try resolveEngine()
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = prefixArgs + [command] + arguments
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.environment = ProcessInfo.processInfo.environment

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        guard let line = stdout.split(separator: "\n").last.map(String.init),
              let jsonData = line.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            let hint = stderr.isEmpty ? stdout : stderr
            throw EngineError.badResponse(hint.isEmpty ? "无输出" : hint)
        }

        let ok = (root["ok"] as? Bool) ?? false
        if !ok {
            throw EngineError.commandFailed((root["error"] as? String) ?? "未知错误")
        }
        return (root["data"] as? [String: Any]) ?? [:]
    }

    private static func resolveEngine() throws -> (String, [String]) {
        if let bundled = Bundle.main.path(forResource: "PDFToolEngine", ofType: nil),
           FileManager.default.isExecutableFile(atPath: bundled) {
            return (bundled, [])
        }

        if let envRoot = ProcessInfo.processInfo.environment["PDFTOOL_ROOT"] {
            let cli = (envRoot as NSString).appendingPathComponent("src/engine_cli.py")
            if FileManager.default.fileExists(atPath: cli) {
                return (try python3Path(), [cli])
            }
        }

        let repoRoot = findRepoRoot()
        if let repoRoot {
            let cli = repoRoot.appendingPathComponent("src/engine_cli.py").path
            if FileManager.default.fileExists(atPath: cli) {
                return (try python3Path(), [cli])
            }
        }

        throw EngineError.engineNotFound
    }

    private static func python3Path() throws -> String {
        for candidate in ["/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"] {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        throw EngineError.engineNotFound
    }

    private static func findRepoRoot() -> URL? {
        var url = Bundle.main.bundleURL
        for _ in 0..<8 {
            let engine = url.appendingPathComponent("src/engine_cli.py")
            if FileManager.default.fileExists(atPath: engine.path) {
                return url
            }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if FileManager.default.fileExists(atPath: cwd.appendingPathComponent("src/engine_cli.py").path) {
            return cwd
        }
        return nil
    }
}
