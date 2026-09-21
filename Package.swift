// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DisplayGate",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "displayctl", targets: ["displayctl"]),
        .executable(name: "DisplayGate", targets: ["DisplayGate"])
    ],
    targets: [
        .target(
            name: "SkyLightBridge",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .target(name: "DisplayCore", dependencies: ["SkyLightBridge"]),
        .executableTarget(name: "displayctl", dependencies: ["DisplayCore"]),
        .executableTarget(name: "DisplayGate", dependencies: ["DisplayCore"], linkerSettings: [.linkedFramework("Cocoa")])
    ]
)
