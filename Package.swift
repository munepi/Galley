// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Leaf",
    platforms: [.macOS(.v11)],
    targets: [
        // 1. C言語専用のターゲット
        .target(
            name: "CSynctex",
            path: "Sources/CSynctex",
            publicHeadersPath: "."
        ),
        // 2. 本体のSwiftターゲット
        .executableTarget(
            name: "Leaf",
            dependencies: ["CSynctex"], // ここでCライブラリをリンク
            path: "Sources/Leaf"
        ),
    ]
)
