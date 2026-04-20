// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Galley",
    platforms: [.macOS(.v11)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1"),
    ],
    targets: [
        .target(
            name: "CSynctex",
            path: "Sources/CSynctex",
            publicHeadersPath: "."
        ),
        .executableTarget(
            name: "GalleyPDF",
            dependencies: [
                "CSynctex",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Galley",
            linkerSettings: [
                .unsafeFlags(["-Wl,-rpath,@executable_path/../Frameworks"]),
            ]
        ),
    ]
)
