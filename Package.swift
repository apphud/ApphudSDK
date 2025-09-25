// swift-tools-version:5.9
import PackageDescription

let package = Package(name: "ApphudSDK",
                      platforms: [.iOS(.v15), .macOS(.v10_15), .watchOS(.v9)],
                      products: [.library(name: "ApphudSDK",
                                          targets: ["ApphudSDK"])],
                      targets: [.target(name: "ApphudSDK",
                                        path: "Sources",
                                        resources: [
                                            .process("PrivacyInfo.xcprivacy")
                                        ])],
                      swiftLanguageVersions: [.v5])
