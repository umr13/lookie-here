#!/bin/bash
set -euo pipefail

VERSION="${1:-0.1.0}"
ARCH=$(uname -m)  # arm64 or x86_64
BUILD_DIR=".build/release-pkg"
APP_NAME="Lookie Here"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CLI_NAME="lookie"

echo "==> Building release binaries (v$VERSION)..."
swift build -c release --product lookie
swift build -c release --product LookieHereApp

echo "==> Creating $APP_NAME.app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binaries
cp .build/release/LookieHereApp "$APP_BUNDLE/Contents/MacOS/LookieHereApp"
cp .build/release/lookie "$BUILD_DIR/lookie"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Lookie Here</string>
    <key>CFBundleDisplayName</key>
    <string>Lookie Here</string>
    <key>CFBundleIdentifier</key>
    <string>com.lookie-here.lookie-here</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>LookieHereApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>Lookie Here uses the camera to detect which monitor you are facing.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc code sign
echo "==> Code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --force --sign - "$BUILD_DIR/lookie"

# Create zip for GitHub release
echo "==> Creating release archives..."
RELEASE_DIR=".build/releases"
mkdir -p "$RELEASE_DIR"

# App zip (for cask)
cd "$BUILD_DIR"
zip -r -y "../../$RELEASE_DIR/LookieHere-${VERSION}-${ARCH}.zip" "$APP_NAME.app"
cd -

# CLI zip (for formula)
cd "$BUILD_DIR"
zip -r -y "../../$RELEASE_DIR/lookie-${VERSION}-${ARCH}.zip" lookie
cd -

echo ""
echo "==> Done! Release artifacts:"
echo "    $RELEASE_DIR/LookieHere-${VERSION}-${ARCH}.zip  (menu bar app)"
echo "    $RELEASE_DIR/lookie-${VERSION}-${ARCH}.zip             (CLI)"
echo ""
echo "Next steps:"
echo "  1. Push to GitHub:  git remote add origin <url> && git push -u origin main"
echo "  2. Create release:  gh release create v${VERSION} $RELEASE_DIR/*.zip --title 'v${VERSION}'"
echo "  3. Get the zip URL and SHA256:"
echo "     shasum -a 256 $RELEASE_DIR/LookieHere-${VERSION}-${ARCH}.zip"
echo "  4. Update the Homebrew tap formula with the URL + SHA"
