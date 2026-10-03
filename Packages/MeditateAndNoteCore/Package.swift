// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MeditateAndNoteCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MeditateAndNoteCore", targets: ["MeditateAndNoteCore"])
    ],
    targets: [
        .target(
            name: "MeditateAndNoteCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)