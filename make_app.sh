#!/bin/bash
set -e

APP="Photogrill.app"
CONTENTS="$APP/Contents"
BINARY_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
BUILD_DIR=".build/release"

echo "→ Building release binary..."
swift build -c release

echo "→ Assembling $APP..."
rm -rf "$APP"
mkdir -p "$BINARY_DIR" "$RESOURCES_DIR"

# Binary
cp "$BUILD_DIR/Photogrill" "$BINARY_DIR/Photogrill"

# Info.plist (kept at project root, outside SPM's resource processing)
cp Info.plist "$CONTENTS/Info.plist"
# Substitute the EXECUTABLE_NAME placeholder
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Photogrill" "$CONTENTS/Info.plist"

# App icon
cp Photogrill.icns "$RESOURCES_DIR/AppIcon.icns"

# Compiled asset catalog (Assets.car) from the build products
ASSETS_CAR=$(find "$BUILD_DIR" -name "Assets.car" 2>/dev/null | head -1)
if [ -n "$ASSETS_CAR" ]; then
    cp "$ASSETS_CAR" "$RESOURCES_DIR/Assets.car"
fi

# Ad-hoc sign so macOS will run it
echo "→ Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP"

echo "→ Done: $APP"
echo ""
echo "To distribute: right-click $APP → Compress, then share the zip."
echo "Recipient: right-click the .app → Open (first launch only, to bypass Gatekeeper)."
