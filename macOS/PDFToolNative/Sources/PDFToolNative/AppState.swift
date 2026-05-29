import CryptoKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var statusText = "就绪"
    @Published var isBusy = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var showAlert = false

    private static let passwordSHA256 = "a3dbd9941a7e6f31eecbdcf93ee8e822a1c3228f75fe3596ec2cd0de690d27d1"

    func verifyPassword(_ password: String) -> Bool {
        let digest = Self.sha256Hex(password)
        return digest == Self.passwordSHA256
    }

    func runTask(_ title: String, operation: @escaping () async throws -> String) {
        guard !isBusy else { return }
        isBusy = true
        statusText = "\(title) 处理中…"
        Task {
            do {
                let message = try await operation()
                statusText = "\(title) 完成"
                presentAlert(title: "完成", message: message)
            } catch {
                statusText = "\(title) 失败"
                presentAlert(title: "错误", message: error.localizedDescription)
            }
            isBusy = false
        }
    }

    func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    private static func sha256Hex(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
