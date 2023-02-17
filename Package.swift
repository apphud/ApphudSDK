// swift-tools-version:5.1
import PackageDescription

let package = Package(name: "ApphudSDK",
                      platforms: [.iOS("13.0")],
                      products: [.library(name: "ApphudSDK",
                                          targets: ["ApphudSDK"])],
                      targets: [.target(name: "ApphudSDK",
                                        path: "ApphudSDK")],
                      swiftLanguageVersions: [.v5])
