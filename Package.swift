// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Galley",
    platforms: [.macOS(.v11)],
    targets: [
        .target(
            name: "CSynctex",
            path: "Sources/CSynctex",
            publicHeadersPath: "."
        ),
        .executableTarget(
            name: "GalleyPDF",
            dependencies: ["CSynctex"],
            path: "Sources/Galley"
        ),
    ]
)
