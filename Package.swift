// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReceiptLedger",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ReceiptLedgerCore", targets: ["ReceiptLedgerCore"])
    ],
    targets: [
        .target(name: "ReceiptLedgerCore", path: "Sources/ReceiptLedgerCore"),
        .testTarget(name: "ReceiptLedgerCoreTests", dependencies: ["ReceiptLedgerCore"], path: "Tests/ReceiptLedgerCoreTests")
    ]
)
