#!/bin/sh

set -eo pipefail

pushd `dirname $0`
trap popd EXIT

NAME="anoncreds_uniffi"
VERSION=${1:-"1.0"} # first arg or "1.0"
BUNDLE_IDENTIFIER="org.hyperledger.anoncreds-uniffi"
LIBRARY_NAME="lib$NAME.a"
FRAMEWORK_LIBRARY_NAME=${NAME}FFI
FRAMEWORK_NAME="$FRAMEWORK_LIBRARY_NAME.framework"
XC_FRAMEWORK_NAME="$FRAMEWORK_LIBRARY_NAME.xcframework"
HEADER_NAME="${NAME}FFI.h"
OUT_PATH="out"
MIN_IOS_VERSION="17.5"
MACOSX_DEPLOYMENT_TARGET="14.5"
WRAPPER_PATH="../swift/Sources/Anoncreds"

AARCH64_APPLE_IOS_PATH="./target/aarch64-apple-ios/release"
AARCH64_APPLE_IOS_SIM_PATH="./target/aarch64-apple-ios-sim/release"
X86_64_APPLE_IOS_PATH="./target/x86_64-apple-ios/release"
AARCH64_APPLE_DARWIN_PATH="./target/aarch64-apple-darwin/release"
X86_64_APPLE_DARWIN_PATH="./target/x86_64-apple-darwin/release"

targets=("aarch64-apple-ios" "aarch64-apple-ios-sim" "x86_64-apple-ios" "aarch64-apple-darwin" "x86_64-apple-darwin")

# Set iOS deployment target for linker
export IPHONEOS_DEPLOYMENT_TARGET=$MIN_IOS_VERSION
export MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET

# 타겟별 RUSTFLAGS 환경 변수 설정
export CARGO_TARGET_AARCH64_APPLE_IOS_RUSTFLAGS="-C link-arg=-mios-version-min=$MIN_IOS_VERSION"
export CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS="-C link-arg=-mios-version-min=$MIN_IOS_VERSION"
export CARGO_TARGET_X86_64_APPLE_IOS_RUSTFLAGS="-C link-arg=-mios-version-min=$MIN_IOS_VERSION"
export CARGO_TARGET_AARCH64_APPLE_DARWIN_RUSTFLAGS="-C link-arg=-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
export CARGO_TARGET_X86_64_APPLE_DARWIN_RUSTFLAGS="-C link-arg=-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"



# Build for all targets
cargo clean

for target in "${targets[@]}"; do
  echo "Building for $target..."
  rustup target add $target

  if [[ "$target" == *"ios"* ]]; then
    echo "DEBUG: Building for iOS target: $target"
    echo "DEBUG: RUSTFLAGS will be applied via environment variables."
    cargo build --release --target $target -vv
  elif [[ "$target" == *"darwin"* ]]; then
    echo "DEBUG: Building for macOS target: $target"
    echo "DEBUG: RUSTFLAGS will be applied via environment variables."
    cargo build --release --target $target -vv
  else
    echo "DEBUG: Building for other target: $target"
    cargo build --release --target $target -v # -v 옵션 추가
  fi
done

#for target in "${targets[@]}"; do
#  echo "Building for $target..."
#  rustup target add $target
#  cargo build --release --target $target
#done

# Generate swift wrapper
echo "Generating swift wrapper..."
mkdir -p $OUT_PATH
mkdir -p $WRAPPER_PATH
CURRENT_ARCH=$(rustc --version --verbose | grep host | cut -f2 -d' ')
cargo run --bin uniffi-bindgen generate uniffi/anoncreds_uniffi.udl --language swift -o $OUT_PATH --lib-file ./target/$CURRENT_ARCH/release/$LIBRARY_NAME

# Merge libraries with lipo
echo "Merging libraries with lipo..."
lipo -create $AARCH64_APPLE_IOS_SIM_PATH/$LIBRARY_NAME \
             $X86_64_APPLE_IOS_PATH/$LIBRARY_NAME \
     -output $OUT_PATH/sim-$LIBRARY_NAME
lipo -create $AARCH64_APPLE_DARWIN_PATH/$LIBRARY_NAME \
             $X86_64_APPLE_DARWIN_PATH/$LIBRARY_NAME \
     -output $OUT_PATH/macos-$LIBRARY_NAME

# Create framework template
rm -rf $OUT_PATH/$FRAMEWORK_NAME
mkdir -p $OUT_PATH/$FRAMEWORK_NAME/Headers
mkdir -p $OUT_PATH/$FRAMEWORK_NAME/Modules
cp $OUT_PATH/$HEADER_NAME $OUT_PATH/$FRAMEWORK_NAME/Headers
cat <<EOT > $OUT_PATH/$FRAMEWORK_NAME/Modules/module.modulemap
framework module $FRAMEWORK_LIBRARY_NAME {
  umbrella header "$HEADER_NAME"

  export *
  module * { export * }
}
EOT

cat <<EOT > $OUT_PATH/$FRAMEWORK_NAME/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$FRAMEWORK_LIBRARY_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_IDENTIFIER</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$FRAMEWORK_LIBRARY_NAME</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>$VERSION</string>
	<key>NSPrincipalClass</key>
	<string></string>
	<key>MinimumOSVersion</key>
	<string>$MIN_IOS_VERSION</string>
</dict>
</plist>
EOT

# Prepare frameworks for each platform
rm -rf $OUT_PATH/frameworks
mkdir -p $OUT_PATH/frameworks/sim
mkdir -p $OUT_PATH/frameworks/ios
mkdir -p $OUT_PATH/frameworks/macos
cp -r $OUT_PATH/$FRAMEWORK_NAME $OUT_PATH/frameworks/sim/
cp -r $OUT_PATH/$FRAMEWORK_NAME $OUT_PATH/frameworks/ios/
cp -r $OUT_PATH/$FRAMEWORK_NAME $OUT_PATH/frameworks/macos/
mv $OUT_PATH/sim-$LIBRARY_NAME $OUT_PATH/frameworks/sim/$FRAMEWORK_NAME/$FRAMEWORK_LIBRARY_NAME
mv $OUT_PATH/macos-$LIBRARY_NAME $OUT_PATH/frameworks/macos/$FRAMEWORK_NAME/$FRAMEWORK_LIBRARY_NAME
cp $AARCH64_APPLE_IOS_PATH/$LIBRARY_NAME $OUT_PATH/frameworks/ios/$FRAMEWORK_NAME/$FRAMEWORK_LIBRARY_NAME

# Create xcframework
echo "Creating xcframework..."
rm -rf $OUT_PATH/$XC_FRAMEWORK_NAME
xcodebuild -create-xcframework \
    -framework $OUT_PATH/frameworks/sim/$FRAMEWORK_NAME \
    -framework $OUT_PATH/frameworks/ios/$FRAMEWORK_NAME \
    -framework $OUT_PATH/frameworks/macos/$FRAMEWORK_NAME \
    -output $OUT_PATH/$XC_FRAMEWORK_NAME

# Copy swift wrapper
# Need some temporary workarounds to compile swift wrapper
# https://github.com/rust-lang/cargo/issues/11953
cat <<EOT > $OUT_PATH/import.txt
#if os(macOS)
import SystemConfiguration
#endif
EOT
cat $OUT_PATH/import.txt $OUT_PATH/$NAME.swift > $WRAPPER_PATH/$NAME.swift
