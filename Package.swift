// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "FountainStudioEditorKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "FountainStudioEditorCore", targets: ["FountainStudioEditorCore"]),
        .library(name: "FountainStudioEditorAppKit", targets: ["FountainStudioEditorAppKit"]),
        .library(name: "FountainStudioEditorSwiftUI", targets: ["FountainStudioEditorSwiftUI"]),
        .library(name: "FountainStudioEditorTesting", targets: ["FountainStudioEditorTesting"])
    ],
    targets: [
        .target(
            name: "FountainStudioEditorCore"
        ),
        .target(
            name: "FountainStudioEditorAppKit",
            dependencies: ["FountainStudioEditorCore"]
        ),
        .target(
            name: "FountainStudioEditorSwiftUI",
            dependencies: [
                "FountainStudioEditorCore",
                "FountainStudioEditorAppKit"
            ]
        ),
        .target(
            name: "FountainStudioEditorTesting",
            dependencies: [
                "FountainStudioEditorCore"
            ]
        ),
        .testTarget(
            name: "FountainStudioEditorCoreTests",
            dependencies: ["FountainStudioEditorCore"]
        ),
        .testTarget(
            name: "FountainStudioEditorAppKitTests",
            dependencies: [
                "FountainStudioEditorAppKit",
                "FountainStudioEditorCore"
            ]
        ),
        .testTarget(
            name: "FountainStudioEditorSwiftUITests",
            dependencies: [
                "FountainStudioEditorSwiftUI",
                "FountainStudioEditorCore"
            ]
        )
    ]
)
