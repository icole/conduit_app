// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HOAChat",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/hotwired/hotwire-native-ios", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "HOAChat",
            dependencies: [
                .product(name: "HotwireNative", package: "hotwire-native-ios")
            ]
        )
    ]
)