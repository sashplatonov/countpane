// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Countpane",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Countpane", targets: ["Countpane"])],
    targets: [
        .executableTarget(
            name: "Countpane",
            path: "Sources/Countpane",
            exclude: ["Resources"]
        ),
        .testTarget(name: "CountpaneTests", dependencies: ["Countpane"], path: "Tests/CountpaneTests")
    ]
)
