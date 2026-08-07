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
        // The `galleypdf` command. Deliberately free of Sparkle and CSynctex so
        // it stays a few milliseconds of process start; it only builds a
        // galleypdf:// URL and hands it to LaunchServices.
        //
        // The product is named GalleyPDFCLI rather than galleypdf because the
        // build directory is case-insensitive on APFS and would collide with
        // the GalleyPDF executable. The Makefile installs it into the bundle
        // under its real name.
        .executableTarget(
            name: "GalleyPDFCLI",
            path: "Sources/GalleyPDFCLI"
        ),
    ]
)
