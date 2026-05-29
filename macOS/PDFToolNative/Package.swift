// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PDFToolNative",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PDFToolNative", targets: ["PDFToolNative"]),
    ],
    targets: [
        .executableTarget(
            name: "PDFToolNative",
            path: "Sources/PDFToolNative"
        ),
    ]
)
