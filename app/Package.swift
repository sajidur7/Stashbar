// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StashBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "StashBar",
            path: "Sources/StashBar",
            // Resources are copied into StashBar.app/Contents/Resources by scripts/build_app.sh
            // (SwiftPM resource bundles break code signing inside a .app).
            exclude: ["Resources"],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "StashBarTests",
            dependencies: ["StashBar"],
            path: "Tests/StashBarTests"
        ),
    ]
)
