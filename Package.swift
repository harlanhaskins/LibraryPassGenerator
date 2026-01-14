// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LibraryPassGen",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird", from: "2.13.0"),
        .package(url: "https://github.com/hiimtmac/pass-kit.git", branch: "main"),
        .package(url: "https://github.com/adam-fowler/swift-zip-archive.git", from: "0.6.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "LibraryPassGen",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "PassCore", package: "pass-kit"),
                .product(name: "ZipArchive", package: "swift-zip-archive"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
                .product(name: "X509", package: "swift-certificates"),
            ],
            path: "Sources"
        ),
    ]
)
