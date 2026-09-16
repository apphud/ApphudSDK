// swift-tools-version:5.9
import PackageDescription

let package = Package(name: "ApphudSDK",
                      // Must match ApphudSDK.podspec: an undeclared platform falls back to
                      // an ancient minimum and fails to build availability-gated code.
                      platforms: [.iOS(.v15), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
                      products: [.library(name: "ApphudSDK",
                                          targets: ["ApphudSDK"])],
                      targets: [.target(name: "ApphudSDK",
                                        path: "Sources",
                                        resources: [
                                            .process("PrivacyInfo.xcprivacy")
                                        ]),
                                .testTarget(name: "ApphudUnitTests",
                                            dependencies: ["ApphudSDK"],
                                            path: "Tests/ApphudUnitTests")],
                      swiftLanguageVersions: [.v5])
