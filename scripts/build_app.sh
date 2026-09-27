#!/bin/bash
set -e

# Build release binary
echo "Building Tucked binary..."
swift build -c release

# Paths
APP_DIR="build/Tucked.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Assemble bundle
echo "Assembling Tucked.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp .build/release/Tucked "$MACOS_DIR/Tucked"

cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Tucked</string>
    <key>CFBundleIdentifier</key>
    <string>ai.mpiv.Tucked</string>
    <key>CFBundleName</key>
    <string>Tucked</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Sign bundle ad-hoc for local execution
codesign --force --deep --sign - "$APP_DIR"

echo "Tucked.app successfully built at $APP_DIR"
