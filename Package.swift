// swift-tools-version:5.1
import PackageDescription

let package = Package(name: "ApphudSDK",
                      platforms: [.iOS(.v13), .macOS(.v10_15)],
                      products: [.library(name: "ApphudSDK",
                                          targets: ["ApphudSDK"])],
                      targets: [.target(name: "ApphudSDK",
                                        path: "ApphudSDK",
                                        resources: [
                                            .process("PrivacyInfo.xcprivacy")
                                        ])],
                      swiftLanguageVersions: [.v5])
