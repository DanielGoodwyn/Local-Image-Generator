#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Local Image Generator"
ROOT="/Users/danielgoodwyn/src/Local Image Generator"
DESKTOP_DIR="$ROOT/desktop"
BUILD_DIR="$DESKTOP_DIR/build"
ICON_SOURCE="$DESKTOP_DIR/assets/local-image-generator-app-icon.png"
ICONSET="$BUILD_DIR/LocalImageGenerator.iconset"
ICON_FILE="$BUILD_DIR/LocalImageGenerator.icns"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_BUNDLE="/Users/danielgoodwyn/Applications/$APP_NAME.app"
DESKTOP_LINK="/Users/danielgoodwyn/Desktop/$APP_NAME.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

if [ -f "$ICON_SOURCE" ]; then
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$ICON_FILE"
  cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/LocalImageGenerator.icns"
fi

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
  <string>Local Image Generator</string>
  <key>CFBundleExecutable</key>
  <string>LocalImageGenerator</string>
  <key>CFBundleIconFile</key>
  <string>LocalImageGenerator</string>
  <key>CFBundleIdentifier</key>
  <string>com.danielgoodwyn.local-image-generator</string>
  <key>CFBundleName</key>
  <string>Local Image Generator</string>
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
