// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "md2loop",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "md2loop",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ]
        ),
    ]
)
