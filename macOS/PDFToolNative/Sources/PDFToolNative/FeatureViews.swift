import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Word

struct WordTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inputPath = ""
    @State private var outputPath = ""

    var body: some View {
        Form {
            Text("支持 .doc / .docx / .wps / .rtf 等。需安装 LibreOffice（推荐）或 Microsoft Word。")
                .foregroundStyle(.secondary)
            OpenFileRow(label: "源文件", path: $inputPath, allowedTypes: UTType.officeTypes) { picked in
                outputPath = (picked as NSString).deletingPathExtension + ".pdf"
            }
            FilePathRow(label: "输出 PDF", path: $outputPath, allowedTypes: [.pdf])
            HStack {
                Spacer()
                Button("开始转换") { convert() }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private func convert() {
        guard !inputPath.isEmpty, !outputPath.isEmpty else {
            appState.presentAlert(title: "提示", message: "请选择源文件和输出路径")
            return
        }
        appState.runTask("Word 转 PDF") {
            let data = try await EngineClient.run(command: "word", arguments: [
                "--input", inputPath,
                "--output", outputPath,
            ])
            let path = (data["path"] as? String) ?? outputPath
            return "已生成：\n\(path)"
        }
    }
}

// MARK: - Watermark

struct WatermarkTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inputPath = ""
    @State private var outputPath = ""
    @State private var modeText = true
    @State private var text = "机密"
    @State private var opacity = 0.25
    @State private var angle = 45.0
    @State private var fontSize = 48.0
    @State private var textPosition = "center"
    @State private var imagePath = ""
    @State private var scale = 0.25
    @State private var imagePosition = "center"
    @State private var imageAngle = 0.0
    @State private var layout = "single"

    private let positions = [
        "center", "top-left", "top-center", "top-right",
        "left-center", "right-center",
        "bottom-left", "bottom-center", "bottom-right",
    ]

    var body: some View {
        Form {
            OpenFileRow(label: "PDF 文件", path: $inputPath, allowedTypes: [.pdf]) { picked in
                outputPath = (picked as NSString).deletingPathExtension + "_watermark.pdf"
            }
            FilePathRow(label: "输出 PDF", path: $outputPath, allowedTypes: [.pdf])

            Picker("水印类型", selection: $modeText) {
                Text("文字").tag(true)
                Text("图片").tag(false)
            }
            .pickerStyle(.segmented)

            if modeText {
                Group {
                    TextField("水印文字", text: $text)
                    HStack {
                        Text("角度")
                        TextField("", value: $angle, format: .number)
                            .frame(width: 60)
                        Text("字号")
                        TextField("", value: $fontSize, format: .number)
                            .frame(width: 60)
                    }
                    Picker("文字位置", selection: $textPosition) {
                        ForEach(positions, id: \.self) { Text($0).tag($0) }
                    }
                }
            } else {
                Group {
                    OpenFileRow(label: "水印图片", path: $imagePath, allowedTypes: UTType.imageTypes)
                    HStack {
                        Text("相对大小")
                        Slider(value: $scale, in: 0.08...0.8)
                        Text(String(format: "%.0f%%", scale * 100))
                            .frame(width: 44)
                    }
                    Picker("位置", selection: $imagePosition) {
                        ForEach(positions, id: \.self) { Text($0).tag($0) }
                    }
                    HStack {
                        Text("角度")
                        TextField("", value: $imageAngle, format: .number)
                            .frame(width: 60)
                    }
                }
            }

            HStack {
                Text("透明度")
                Slider(value: $opacity, in: 0.05...0.9)
            }
            Picker("铺设模式", selection: $layout) {
                Text("single").tag("single")
                Text("grid").tag("grid")
                Text("tile").tag("tile")
            }

            HStack {
                Spacer()
                Button("添加水印") { runWatermark() }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private func runWatermark() {
        guard !inputPath.isEmpty, !outputPath.isEmpty else {
            appState.presentAlert(title: "提示", message: "请选择输入和输出 PDF")
            return
        }
        appState.runTask("添加水印") {
            if modeText {
                _ = try await EngineClient.run(command: "watermark-text", arguments: [
                    "--input", inputPath,
                    "--output", outputPath,
                    "--text", text,
                    "--opacity", String(opacity),
                    "--angle", String(angle),
                    "--font-size", String(Int(fontSize)),
                    "--position", textPosition,
                    "--layout", layout,
                ])
            } else {
                guard !imagePath.isEmpty else { throw EngineError.commandFailed("请选择水印图片") }
                _ = try await EngineClient.run(command: "watermark-image", arguments: [
                    "--input", inputPath,
                    "--output", outputPath,
                    "--image", imagePath,
                    "--opacity", String(opacity),
                    "--scale", String(scale),
                    "--angle", String(imageAngle),
                    "--position", imagePosition,
                    "--layout", layout,
                ])
            }
            return "已生成：\n\(outputPath)"
        }
    }
}

// MARK: - Compress

struct CompressTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inputPath = ""
    @State private var outputPath = ""
    @State private var level = "medium"

    var body: some View {
        Form {
            Text("轻/中：流压缩；强：图片重采样或 Ghostscript（若已安装）。")
                .foregroundStyle(.secondary)
            OpenFileRow(label: "PDF 文件", path: $inputPath, allowedTypes: [.pdf]) { picked in
                outputPath = (picked as NSString).deletingPathExtension + "_compressed.pdf"
            }
            FilePathRow(label: "输出 PDF", path: $outputPath, allowedTypes: [.pdf])
            Picker("压缩级别", selection: $level) {
                Text("轻").tag("light")
                Text("中（推荐）").tag("medium")
                Text("强").tag("strong")
            }
            .pickerStyle(.segmented)
            HStack {
                Spacer()
                Button("开始压缩") { compress() }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private func compress() {
        guard !inputPath.isEmpty, !outputPath.isEmpty else {
            appState.presentAlert(title: "提示", message: "请选择输入和输出 PDF")
            return
        }
        appState.runTask("PDF 压缩") {
            let data = try await EngineClient.run(command: "compress", arguments: [
                "--input", inputPath,
                "--output", outputPath,
                "--level", level,
            ])
            let before = (data["before"] as? Int) ?? 0
            let after = (data["after"] as? Int) ?? 0
            let ratio = (data["ratio"] as? Double) ?? 0
            let method = (data["method_label"] as? String) ?? ""
            return """
            方式：\(method)
            原始：\(formatBytes(before))
            压缩后：\(formatBytes(after))
            节省：\(formatBytes(max(0, before - after)))（\(String(format: "%.1f", ratio))%）

            \(outputPath)
            """
        }
    }

    private func formatBytes(_ n: Int) -> String {
        if n >= 1024 * 1024 { return String(format: "%.2f MB", Double(n) / 1024 / 1024) }
        if n >= 1024 { return String(format: "%.1f KB", Double(n) / 1024) }
        return "\(n) B"
    }
}

// MARK: - Merge

struct MergeTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var files: [String] = []
    @State private var outputPath = ""

    var body: some View {
        Form {
            Text("按列表顺序合并多个 PDF。")
                .foregroundStyle(.secondary)
            List {
                ForEach(Array(files.enumerated()), id: \.offset) { idx, path in
                    Text("\(idx + 1). \((path as NSString).lastPathComponent)")
                        .help(path)
                }
            }
            .frame(minHeight: 160)
            HStack {
                Button("添加文件") { addFiles() }
                Button("移除选中") { removeSelected() }
                Button("清空") { files.removeAll() }
            }
            FilePathRow(label: "输出 PDF", path: $outputPath, allowedTypes: [.pdf])
            HStack {
                Spacer()
                Button("合并") { merge() }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            files.append(contentsOf: panel.urls.map(\.path))
        }
    }

    private func removeSelected() {
        // SwiftUI List selection on macOS 12 is heavy; remove last for simplicity
        if !files.isEmpty { files.removeLast() }
    }

    private func merge() {
        guard files.count >= 2 else {
            appState.presentAlert(title: "提示", message: "请至少添加 2 个 PDF")
            return
        }
        guard !outputPath.isEmpty else {
            appState.presentAlert(title: "提示", message: "请选择输出路径")
            return
        }
        var args = ["--output", outputPath]
        args.append(contentsOf: ["--inputs"])
        args.append(contentsOf: files)
        appState.runTask("合并 PDF") {
            _ = try await EngineClient.run(command: "merge", arguments: args)
            return "已生成：\n\(outputPath)"
        }
    }
}

// MARK: - Split

struct SplitTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inputPath = ""
    @State private var outputDir = ""
    @State private var splitEach = false
    @State private var ranges = "1-1"

    var body: some View {
        Form {
            OpenFileRow(label: "PDF 文件", path: $inputPath, allowedTypes: [.pdf]) { picked in
                outputDir = (picked as NSString).deletingLastPathComponent
            }
            FilePathRow(label: "输出目录", path: $outputDir, isDirectory: true)
            Picker("拆分方式", selection: $splitEach) {
                Text("按页码范围").tag(false)
                Text("每页单独一个 PDF").tag(true)
            }
            .pickerStyle(.segmented)
            if !splitEach {
                TextField("页码范围（如 1-3,5-8）", text: $ranges)
            }
            HStack {
                Spacer()
                Button("拆分") { split() }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }

    private func split() {
        guard !inputPath.isEmpty, !outputDir.isEmpty else {
            appState.presentAlert(title: "提示", message: "请选择 PDF 和输出目录")
            return
        }
        appState.runTask("拆分 PDF") {
            let data: [String: Any]
            if splitEach {
                data = try await EngineClient.run(command: "split-each", arguments: [
                    "--input", inputPath,
                    "--output-dir", outputDir,
                ])
            } else {
                data = try await EngineClient.run(command: "split-range", arguments: [
                    "--input", inputPath,
                    "--output-dir", outputDir,
                    "--ranges", ranges,
                ])
            }
            let count = (data["count"] as? Int) ?? 0
            return "共生成 \(count) 个文件\n目录：\(outputDir)"
        }
    }
}
