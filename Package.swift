// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PasteIT",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "PasteIT",
            path: "Sources/PasteIT"
        )
    ]
)
