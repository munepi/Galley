// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Leaf",
    platforms: [.macOS(.v11)],
    targets: [
        .target(
            name: "CSynctex",
            path: "Sources/CSynctex",
            publicHeadersPath: "."
        ),
        .executableTarget(
            name: "LeafPDF",
            dependencies: ["CSynctex"],
            path: "Sources/Leaf"
        ),
    ]
)
