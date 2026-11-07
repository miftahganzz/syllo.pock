#!/bin/bash
set -e
cd /Users/miftah/Downloads/lirik

SDK_PATH=$(xcrun --show-sdk-path)
MODULES_DIR="/tmp/build_modules"

SOURCES=$(find Sources -name "*.swift")

echo "==> Compiling x86_64..."
swiftc -emit-library -target x86_64-apple-macos13.0 \
  -sdk "$SDK_PATH" \
  -I "$MODULES_DIR/x86_64" \
  -L "$MODULES_DIR/x86_64" \
  -lPockKit -lTinyConstraints \
  -module-name syllo \
  $SOURCES \
  -o /tmp/syllo_x86_64.dylib

echo "==> Compiling arm64..."
swiftc -emit-library -target arm64-apple-macos13.0 \
  -sdk "$SDK_PATH" \
  -I "$MODULES_DIR/arm64" \
  -L "$MODULES_DIR/arm64" \
  -lPockKit -lTinyConstraints \
  -module-name syllo \
  $SOURCES \
  -o /tmp/syllo_arm64.dylib

echo "==> Creating Universal Binary..."
lipo -create /tmp/syllo_x86_64.dylib /tmp/syllo_arm64.dylib -output dist/Syllo.pock/Contents/MacOS/syllo

echo "==> Fixing dylib dependencies to use @rpath (portable & reboot-safe)..."
TARGET="dist/Syllo.pock/Contents/MacOS/syllo"
install_name_tool -id @rpath/syllo "$TARGET"
install_name_tool -change /tmp/build_modules/x86_64/libPockKit.dylib @rpath/PockKit.framework/Versions/A/PockKit "$TARGET" 2>/dev/null || true
install_name_tool -change /tmp/build_modules/x86_64/libTinyConstraints.dylib @rpath/TinyConstraints.framework/Versions/A/TinyConstraints "$TARGET" 2>/dev/null || true
install_name_tool -change /tmp/build_modules/arm64/libPockKit.dylib @rpath/PockKit.framework/Versions/A/PockKit "$TARGET" 2>/dev/null || true
install_name_tool -change /tmp/build_modules/arm64/libTinyConstraints.dylib @rpath/TinyConstraints.framework/Versions/A/TinyConstraints "$TARGET" 2>/dev/null || true

install_name_tool -add_rpath @executable_path/../Frameworks "$TARGET" 2>/dev/null || true
install_name_tool -add_rpath /Applications/Pock.app/Contents/Frameworks "$TARGET" 2>/dev/null || true

echo "==> Codesigning dist/Syllo.pock..."
codesign -f -s - dist/Syllo.pock

echo "==> Deploying to ~/Library/Application Support/Pock/Widgets..."
mkdir -p "$HOME/Library/Application Support/Pock/Widgets"
rm -rf "$HOME/Library/Application Support/Pock/Widgets/Syllo.pock"
cp -R dist/Syllo.pock "$HOME/Library/Application Support/Pock/Widgets/"
xattr -cr "$HOME/Library/Application Support/Pock/Widgets/Syllo.pock"

echo "==> Packaging release zip & dmg..."
cd dist
rm -f syllo-ventura13.zip
zip -r -y syllo-ventura13.zip Syllo.pock
cd ..
/tmp/create_dmg.sh

echo "==> Restarting Pock..."
killall Pock 2>/dev/null || true
open -a Pock || true

echo "==> Build, deployment and packaging SUCCESS!"
