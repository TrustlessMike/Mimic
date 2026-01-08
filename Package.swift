// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mimic",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Mimic",
            targets: ["Mimic"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.20.0"),
        .package(url: "https://github.com/TrustlessMike/solana-swift.git", branch: "main")
    ],
    targets: [
        .target(
            name: "Mimic",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "SolanaSwift", package: "solana-swift")
            ],
            path: "Sources/Mimic",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MimicTests",
            dependencies: ["Mimic"],
            path: "Tests/MimicTests"
        ),
    ]
)
