#!/bin/bash
set -e

echo "Building Retot..."
xcodebuild -scheme Retot -configuration Debug build 2>&1 | tail -3

APP_SRC="$HOME/Library/Developer/Xcode/DerivedData/Retot-gqjndgxlznulpzdtqkhcrnohmwtq/Build/Products/Debug/Retot.app"
APP_DST="/Applications/Retot.app"

# Kill ALL running Retot instances (graceful then force)
pkill -f "Retot.app/Contents/MacOS/Retot" 2>/dev/null || true
sleep 1
pkill -9 -f "Retot.app/Contents/MacOS/Retot" 2>/dev/null || true
sleep 1

# Copy to /Applications
echo "Installing to /Applications..."
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

# Launch
echo "Launching Retot..."
open "$APP_DST"
