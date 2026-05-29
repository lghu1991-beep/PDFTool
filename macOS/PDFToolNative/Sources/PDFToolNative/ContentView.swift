import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                WordTabView()
                    .tabItem { Label("Word 转 PDF", systemImage: "doc.text") }
                WatermarkTabView()
                    .tabItem { Label("水印", systemImage: "drop") }
                CompressTabView()
                    .tabItem { Label("压缩", systemImage: "arrow.down.doc") }
                MergeTabView()
                    .tabItem { Label("合并", systemImage: "doc.on.doc") }
                SplitTabView()
                    .tabItem { Label("拆分", systemImage: "square.split.2x1") }
            }
            .padding(12)

            Divider()
            HStack {
                if appState.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 6)
                }
                Text(appState.statusText)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("macOS 原生版")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .alert(appState.alertTitle, isPresented: $appState.showAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(appState.alertMessage)
        }
        .disabled(appState.isBusy)
    }
}
