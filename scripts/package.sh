#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "🔨 Building MacRouter Swift binary..."
cd "$REPO_DIR"
swift build -c release

APP_NAME="MacRouter.app"
BUNDLE_DIR="$REPO_DIR/$APP_NAME"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating macOS App Bundle ($APP_NAME)..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
BIN_PATH="$(swift build -c release --show-bin-path)"
cp "$BIN_PATH/MacRouter" "$MACOS_DIR/MacRouter"
chmod +x "$MACOS_DIR/MacRouter"

# Copy AppIcon.icns
if [ -f "$REPO_DIR/AppIcon.icns" ]; then
    echo "🎨 Bundling AppIcon.icns..."
    cp "$REPO_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.plist">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacRouter</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>dev.9router.macrouter</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MacRouter</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "ZIPing MacRouter.app for release..."
cd "$REPO_DIR"
rm -f "MacRouter-macOS.zip"
zip -r9 "MacRouter-macOS.zip" "$APP_NAME"

echo "✅ App bundle created successfully: $REPO_DIR/$APP_NAME"
echo "✅ Release zip created: $REPO_DIR/MacRouter-macOS.zip"
