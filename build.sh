#!/bin/bash
set -e
cd /Users/miftah/Downloads/lirik

SDK_PATH=$(xcrun --show-sdk-path)
MODULES_DIR="/Users/miftah/Downloads/lirik/.build_modules"

# Ensure build modules exist
if [ ! -f "$MODULES_DIR/x86_64/PockKit.swiftmodule" ] || [ ! -f "$MODULES_DIR/arm64/PockKit.swiftmodule" ]; then
  echo "==> Building PockKit & TinyConstraints modules..."
  mkdir -p "$MODULES_DIR/x86_64" "$MODULES_DIR/arm64"
  rm -rf /tmp/tinyconstraints /tmp/pockkit
  git clone --depth 1 https://github.com/roberthein/TinyConstraints.git /tmp/tinyconstraints
  git clone --depth 1 https://github.com/pock/PockKit.git /tmp/pockkit
  swiftc -target x86_64-apple-macos13.0 -module-name TinyConstraints -emit-module -emit-module-path "$MODULES_DIR/x86_64/TinyConstraints.swiftmodule" -emit-library /tmp/tinyconstraints/TinyConstraints/Classes/*.swift -o "$MODULES_DIR/x86_64/libTinyConstraints.dylib"
  swiftc -target arm64-apple-macos13.0 -module-name TinyConstraints -emit-module -emit-module-path "$MODULES_DIR/arm64/TinyConstraints.swiftmodule" -emit-library /tmp/tinyconstraints/TinyConstraints/Classes/*.swift -o "$MODULES_DIR/arm64/libTinyConstraints.dylib"
  swiftc -target x86_64-apple-macos13.0 -module-name PockKit -emit-module -emit-module-path "$MODULES_DIR/x86_64/PockKit.swiftmodule" -emit-library -I "$MODULES_DIR/x86_64" -L "$MODULES_DIR/x86_64" -lTinyConstraints $(find /tmp/pockkit/PockKit -name "*.swift") -o "$MODULES_DIR/x86_64/libPockKit.dylib"
  swiftc -target arm64-apple-macos13.0 -module-name PockKit -emit-module -emit-module-path "$MODULES_DIR/arm64/PockKit.swiftmodule" -emit-library -I "$MODULES_DIR/arm64" -L "$MODULES_DIR/arm64" -lTinyConstraints $(find /tmp/pockkit/PockKit -name "*.swift") -o "$MODULES_DIR/arm64/libPockKit.dylib"
  install_name_tool -id @rpath/PockKit.framework/Versions/A/PockKit "$MODULES_DIR/x86_64/libPockKit.dylib"
  install_name_tool -id @rpath/PockKit.framework/Versions/A/PockKit "$MODULES_DIR/arm64/libPockKit.dylib"
  install_name_tool -id @rpath/TinyConstraints.framework/Versions/A/TinyConstraints "$MODULES_DIR/x86_64/libTinyConstraints.dylib"
  install_name_tool -id @rpath/TinyConstraints.framework/Versions/A/TinyConstraints "$MODULES_DIR/arm64/libTinyConstraints.dylib"
fi

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
install_name_tool -change .build_modules/x86_64/libPockKit.dylib @rpath/PockKit.framework/Versions/A/PockKit "$TARGET" 2>/dev/null || true
install_name_tool -change .build_modules/x86_64/libTinyConstraints.dylib @rpath/TinyConstraints.framework/Versions/A/TinyConstraints "$TARGET" 2>/dev/null || true
install_name_tool -change .build_modules/arm64/libPockKit.dylib @rpath/PockKit.framework/Versions/A/PockKit "$TARGET" 2>/dev/null || true
install_name_tool -change .build_modules/arm64/libTinyConstraints.dylib @rpath/TinyConstraints.framework/Versions/A/TinyConstraints "$TARGET" 2>/dev/null || true
install_name_tool -change /Users/miftah/Downloads/lirik/.build_modules/x86_64/libPockKit.dylib @rpath/PockKit.framework/Versions/A/PockKit "$TARGET" 2>/dev/null || true
install_name_tool -change /Users/miftah/Downloads/lirik/.build_modules/x86_64/libTinyConstraints.dylib @rpath/TinyConstraints.framework/Versions/A/TinyConstraints "$TARGET" 2>/dev/null || true
install_name_tool -change /Users/miftah/Downloads/lirik/.build_modules/arm64/libPockKit.dylib @rpath/PockKit.framework/Versions/A/PockKit "$TARGET" 2>/dev/null || true
install_name_tool -change /Users/miftah/Downloads/lirik/.build_modules/arm64/libTinyConstraints.dylib @rpath/TinyConstraints.framework/Versions/A/TinyConstraints "$TARGET" 2>/dev/null || true

install_name_tool -add_rpath @executable_path/../Frameworks "$TARGET" 2>/dev/null || true
install_name_tool -add_rpath /Applications/Pock.app/Contents/Frameworks "$TARGET" 2>/dev/null || true

echo "==> Codesigning dist/Syllo.pock..."
codesign -f -s - dist/Syllo.pock

echo "==> Deploying to ~/Library/Application Support/Pock/Widgets..."
mkdir -p "$HOME/Library/Application Support/Pock/Widgets"
rm -rf "$HOME/Library/Application Support/Pock/Widgets/Syllo.pock"
cp -R dist/Syllo.pock "$HOME/Library/Application Support/Pock/Widgets/"
xattr -cr "$HOME/Library/Application Support/Pock/Widgets/Syllo.pock"

echo "==> Packaging syllo-ventura13.zip..."
cd dist
rm -f syllo-ventura13.zip
zip -r -y syllo-ventura13.zip Syllo.pock

echo "==> Packaging Syllo-v2.0.0.dmg..."
DMG_STAGING="/tmp/syllo_dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R Syllo.pock "$DMG_STAGING/"

cat << 'README_TXT' > "$DMG_STAGING/Cara Install (ID).txt"
Cara Pasang Syllo pada Touch Bar (Pock):
1. Salin (drag / copy) 'Syllo.pock' ke folder Pock Widgets:
   ~/Library/Application Support/Pock/Widgets/

2. Buka Terminal jika Touch Bar tidak mendeteksi (bypass Gatekeeper macOS):
   xattr -cr ~/Library/Application\ Support/Pock/Widgets/Syllo.pock

3. Restart Pock:
   killall Pock && open -a Pock
README_TXT

cat << 'README_EN' > "$DMG_STAGING/Install Instructions (EN).txt"
How to Install Syllo on Pock Touch Bar:
1. Copy 'Syllo.pock' into:
   ~/Library/Application Support/Pock/Widgets/

2. If blocked by macOS Gatekeeper, run in Terminal:
   xattr -cr ~/Library/Application\ Support/Pock/Widgets/Syllo.pock

3. Restart Pock:
   killall Pock && open -a Pock
README_EN

rm -f Syllo-v2.0.0.dmg
hdiutil create -volname "Syllo Widget v2.0" -srcfolder "$DMG_STAGING" -ov -format UDZO Syllo-v2.0.0.dmg
rm -rf "$DMG_STAGING"

cd ..

echo "==> Restarting Pock..."
killall Pock 2>/dev/null || true
open -a Pock || true

echo "==> Build, deployment and packaging SUCCESS!"
