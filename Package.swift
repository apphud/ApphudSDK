// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "ApphudSDK",
    platforms: [
   		.iOS(.v11)
	],
    products: [
        .library(name: "ApphudSDK", targets: ["ApphudSDK"])
    ],
    targets: [
        .target(name: "ApphudSDK")
    ],
    swiftLanguageVersions: [.v4_2]
)
