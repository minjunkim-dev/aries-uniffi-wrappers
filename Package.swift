// swift-tools-version: 5.7
import PackageDescription

import class Foundation.ProcessInfo

var package = Package(
  name: "aries-uniffi-wrappers",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v15),
  ],
  products: [
    .library(
      name: "Anoncreds",
      targets: ["Anoncreds"]),
    .library(
      name: "Askar",
      targets: ["Askar"]),
    .library(
      name: "IndyVdr",
      targets: ["IndyVdr"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "Anoncreds",
      path: "swift/Sources/Anoncreds"),
    .testTarget(
      name: "AnoncredsTests",
      dependencies: ["Anoncreds"],
      path: "swift/Tests/AnoncredsTests"),
    .binaryTarget(
      name: "anoncreds_uniffiFFI",
      url:
        "https://github.com/minjunkim-dev/aries-uniffi-wrappers/releases/download/0.2.3-binary/anoncreds_uniffiFFI.xcframework.zip",
      checksum: "5b40cc2f5aea9605172100aa6f1909d23a9c6341ccd6b1ecad897313e405e749"),
    .target(
      name: "Askar",
      path: "swift/Sources/Askar"),
    .testTarget(
      name: "AskarTests",
      dependencies: ["Askar"],
      path: "swift/Tests/AskarTests",
      resources: [
        .copy("resources/indy_wallet_sqlite.db")
      ]),
    .binaryTarget(
      name: "askar_uniffiFFI",
      url:
        "https://github.com/hyperledger/aries-uniffi-wrappers/releases/download/0.2.2-binary/askar_uniffiFFI.xcframework.zip",
      checksum: "ec94f384e406600573cb730fe63d57f4a0dbe74074a98e8fd082ab0f382207af"),
    .target(
      name: "IndyVdr",
      path: "swift/Sources/IndyVdr"),
    .testTarget(
      name: "IndyVdrTests",
      dependencies: ["IndyVdr"],
      path: "swift/Tests/IndyVdrTests",
      resources: [
        .copy("resources/genesis_sov_buildernet.txn")
      ]),
    .binaryTarget(
      name: "indy_vdr_uniffiFFI",
      url:
        "https://github.com/hyperledger/aries-uniffi-wrappers/releases/download/0.2.1-binary/indy_vdr_uniffiFFI.xcframework.zip",
      checksum: "fcaf8df60f41a149d1f496e494499f8645f971a68e9c024b0498271756180a4e"),
  ]
)

let anoncredsTarget = package.targets.first(where: { $0.name == "Anoncreds" })
let askarTarget = package.targets.first(where: { $0.name == "Askar" })
let indyVdrTarget = package.targets.first(where: { $0.name == "IndyVdr" })

if ProcessInfo.processInfo.environment["USE_LOCAL_XCFRAMEWORK"] == nil {
  anoncredsTarget?.dependencies.append("anoncreds_uniffiFFI")
  askarTarget?.dependencies.append("askar_uniffiFFI")
  indyVdrTarget?.dependencies.append("indy_vdr_uniffiFFI")
} else {
  package.targets.append(
    .binaryTarget(
      name: "anoncreds_uniffiFFI_local",
      path: "anoncreds/out/anoncreds_uniffiFFI.xcframework"))
  package.targets.append(
    .binaryTarget(
      name: "askar_uniffiFFI_local",
      path: "askar/out/askar_uniffiFFI.xcframework"))
  package.targets.append(
    .binaryTarget(
      name: "indy_vdr_uniffiFFI_local",
      path: "indy-vdr/out/indy_vdr_uniffiFFI.xcframework"))

  anoncredsTarget?.dependencies.append("anoncreds_uniffiFFI_local")
  askarTarget?.dependencies.append("askar_uniffiFFI_local")
  indyVdrTarget?.dependencies.append("indy_vdr_uniffiFFI_local")
}
