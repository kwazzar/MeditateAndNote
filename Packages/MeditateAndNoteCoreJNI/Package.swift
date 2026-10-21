// swift-tools-version:6.0
import PackageDescription
import Foundation

// The swift-java checkout that owns the JNI thunks. Kept out of
// MeditateAndNoteCore on purpose: that package is linked by the Xcode app build
// and has to stay free of a path dependency pointing outside the repo.
// Override with SWIFT_JAVA_PATH for a checkout somewhere else.
let swiftJavaPath = ProcessInfo.processInfo.environment["SWIFT_JAVA_PATH"] ?? "\(NSHomeDirectory())/Developer/swift-java"

let package = Package(
    name: "MeditateAndNoteCoreJNI",
    platforms: [.macOS(.v14)],
    products: [
        // The product name determines the .so filename, and it cannot be
        // "MeditateAndNoteCore": SwiftPM rejects two products with the same name
        // across a package graph ("Found multiple targets named
        // 'MeditateAndNoteCore-product'"). build-android.sh rewrites LIB_NAME in
        // the generated Java to match.
        .library(
            name: "MeditateAndNoteCoreJNI",
            type: .dynamic,
            targets: ["MeditateAndNoteCoreJNI"]
        )
    ],
    dependencies: [
        .package(path: "../MeditateAndNoteCore"),
        .package(path: swiftJavaPath),
    ],
    targets: [
        // zlib C shim for the minimal EPUB zip reader (`MiniZipReader`): the
        // NDK sysroot ships zlib.h and libz, so no pkg-config is needed.
        .systemLibrary(name: "CZlib"),
        .target(
            name: "MeditateAndNoteCoreJNI",
            dependencies: [
                .product(name: "MeditateAndNoteCore", package: "MeditateAndNoteCore"),
                .product(name: "SwiftJavaStatic", package: "swift-java"),
                "CZlib",
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)