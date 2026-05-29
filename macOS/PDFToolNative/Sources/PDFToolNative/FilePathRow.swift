import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FilePathRow: View {
    let label: String
    @Binding var path: String
    var isDirectory = false
    var allowedTypes: [UTType] = [.pdf]
    var onPicked: ((String) -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 72, alignment: .leading)
            TextField("", text: $path)
                .textFieldStyle(.roundedBorder)
            Button("选择…") { pick() }
        }
    }

    private func pick() {
        if isDirectory {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.prompt = "选择"
            if panel.runModal() == .OK, let url = panel.url {
                path = url.path
                onPicked?(path)
            }
            return
        }
        let save = NSSavePanel()
        save.allowedContentTypes = allowedTypes
        save.canCreateDirectories = true
        if !path.isEmpty {
            save.directoryURL = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent)
            save.nameFieldStringValue = (path as NSString).lastPathComponent
        }
        if save.runModal() == .OK, let url = save.url {
            path = url.path
            onPicked?(path)
        }
    }
}

struct OpenFileRow: View {
    let label: String
    @Binding var path: String
    var allowedTypes: [UTType]
    var onPicked: ((String) -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 72, alignment: .leading)
            TextField("", text: $path)
                .textFieldStyle(.roundedBorder)
            Button("选择…") { pick() }
        }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedTypes
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
            onPicked?(path)
        }
    }
}

extension UTType {
    static let officeDoc = UTType(filenameExtension: "docx") ?? .data
    static let officeDocOld = UTType(filenameExtension: "doc") ?? .data
    static let officeTypes: [UTType] = [.officeDoc, .officeDocOld, .rtf, .plainText, .pdf]
    static let imageTypes: [UTType] = [
        .png, .jpeg, .bmp,
        UTType(filenameExtension: "webp") ?? .image,
    ]
}
