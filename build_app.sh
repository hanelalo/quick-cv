#!/bin/bash

# Build the release version
echo "Building release version..."
swift build -c release --disable-sandbox

# Create the .app bundle structure
echo "Creating QuickCV.app bundle..."
APP_NAME="QuickCV.app"
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

# Copy the executable
cp .build/release/QuickCV "$APP_NAME/Contents/MacOS/"

# Copy app icon
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_NAME/Contents/Resources/AppIcon.icns"
fi

# Copy logo for popup
if [ -f "logo.png" ]; then
    cp logo.png "$APP_NAME/Contents/Resources/logo.png"
fi

# Create Info.plist
cat > "$APP_NAME/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>QuickCV</string>
    <key>CFBundleIdentifier</key>
    <string>com.hanelalo.QuickCV</string>
    <key>CFBundleName</key>
    <string>QuickCV</string>
    <key>CFBundleDisplayName</key>
    <string>QuickCV</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF

echo "Done! You can now move $APP_NAME to your /Applications folder."
