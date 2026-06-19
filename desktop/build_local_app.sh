#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Local image generator"
ROOT="/Users/danielgoodwyn/src/Fooocus"
DESKTOP_DIR="$ROOT/desktop"
BUILD_DIR="$DESKTOP_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_BUNDLE="/Users/danielgoodwyn/Applications/$APP_NAME.app"
DESKTOP_LINK="/Users/danielgoodwyn/Desktop/$APP_NAME.app"

mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

swiftc "$DESKTOP_DIR/LocalImageGeneratorApp.swift" \
  -o "$APP_BUNDLE/Contents/MacOS/LocalImageGenerator" \
  -framework AppKit \
  -framework WebKit

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Local image generator</string>
  <key>CFBundleExecutable</key>
  <string>LocalImageGenerator</string>
  <key>CFBundleIdentifier</key>
  <string>com.danielgoodwyn.local-image-generator</string>
  <key>CFBundleName</key>
  <string>Local image generator</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

rm -rf "$INSTALL_BUNDLE"
cp -R "$APP_BUNDLE" "$INSTALL_BUNDLE"
xattr -cr "$INSTALL_BUNDLE"
codesign --force --deep --sign - "$INSTALL_BUNDLE"

rm -f "$DESKTOP_LINK"
ln -s "$INSTALL_BUNDLE" "$DESKTOP_LINK"

codesign --verify --deep --strict "$INSTALL_BUNDLE"
echo "Installed $INSTALL_BUNDLE"
echo "Desktop shortcut $DESKTOP_LINK"
