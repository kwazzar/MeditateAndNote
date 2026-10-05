// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MeditateAndNoteCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        // Xcode/app builds link this one; static is the right default there.
        .library(name: "MeditateAndNoteCore", targets: ["MeditateAndNoteCore"]),
        // Android needs a loadable .so for jniLibs, and SwiftPM only emits one
        // for a product declared `.dynamic`. Same target, so the iOS/macOS
        // static product is unaffected.
        .library(name: "MeditateAndNoteCoreDynamic", type: .dynamic, targets: ["MeditateAndNoteCore"])
    ],
    targets: [
        .target(
            name: "MeditateAndNoteCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)