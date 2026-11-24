#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.moon/bin:$PATH"

echo "=== 1. Checking Toolchain ==="
if ! command -v moon >/dev/null 2>&1; then
  echo "Error: 'moon' CLI is required. Ensure MoonBit is installed." >&2
  exit 1
fi
echo "Using MoonBit: $(moon version)"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="PDF Watermark"
BUNDLE_ID="com.devops-guide.pdf-watermark"
VERSION="1.2.0"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME.app.zip"

echo "=== 2. Building Native MoonBit Binary (Release) ==="
moon build --target native --release

BIN_SOURCE="$ROOT_DIR/_build/native/release/build/app/app.exe"
if [[ ! -f "$BIN_SOURCE" ]]; then
  echo "Error: Compiled binary not found at $BIN_SOURCE" >&2
  exit 1
fi

echo "=== 3. Assembling macOS .app Bundle ==="
rm -rf "$APP_DIR" "$ZIP_PATH"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources/frontend"

# Copy binary & strip symbols
cp "$BIN_SOURCE" "$APP_DIR/Contents/MacOS/pdf-watermark"
chmod +x "$APP_DIR/Contents/MacOS/pdf-watermark"
strip "$APP_DIR/Contents/MacOS/pdf-watermark"

# Create Info.plist
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>pdf-watermark</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
</dict>
</plist>
EOF

# Copy Icon
if [[ -f "$ROOT_DIR/icons/logo.icns" ]]; then
  cp "$ROOT_DIR/icons/logo.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
elif [[ -f "$ROOT_DIR/frontend/logo.icns" ]]; then
  cp "$ROOT_DIR/frontend/logo.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Copy Frontend static assets
cp -R "$ROOT_DIR/frontend/"* "$APP_DIR/Contents/Resources/frontend/"

# Ad-hoc code sign for macOS Gatekeeper
echo "=== 4. Code Signing Bundle ==="
codesign --force --deep --sign - "$APP_DIR"

echo "=== 5. Creating Release Archive ==="
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

echo "=== Build Complete ==="
echo "App Bundle: $APP_DIR"
ls -lh "$APP_DIR/Contents/MacOS/pdf-watermark"
echo "Release Archive: $ZIP_PATH"
ls -lh "$ZIP_PATH"
