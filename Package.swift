// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WakeyWakey",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WakeyWakeyCore", targets: ["WakeyWakeyCore"]),
        .executable(name: "WakeyWakey", targets: ["WakeyWakey"]),
    ],
    targets: [
        // Pure logic: the sleep-assertion and the clock are injected. Fully unit-tested.
        .target(
            name: "WakeyWakeyCore",
            path: "Sources/WakeyWakeyCore"),
        // The menu bar app. Thin wiring over the core.
        .executableTarget(
            name: "WakeyWakey",
            dependencies: ["WakeyWakeyCore"],
            path: "Sources/WakeyWakey",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
            ]),
        .testTarget(
            name: "WakeyWakeyCoreTests",
            dependencies: ["WakeyWakeyCore"],
            path: "Tests/WakeyWakeyCoreTests"),
    ]
)
