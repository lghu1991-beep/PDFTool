import SwiftUI

@main
struct PDFToolNativeApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
            .frame(minWidth: 780, minHeight: 620)
        }
        .windowStyle(.automatic)
    }
}

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var password = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PDFTool")
                .font(.largeTitle.bold())
            Text("请输入使用密码")
                .foregroundStyle(.secondary)
            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(confirm)
            HStack {
                Spacer()
                Button("进入") { confirm() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 380)
        .onAppear { focused = true }
    }

    private func confirm() {
        if appState.verifyPassword(password) {
            appState.isAuthenticated = true
        } else {
            appState.presentAlert(title: "错误", message: "密码错误，请重试。")
        }
    }
}
