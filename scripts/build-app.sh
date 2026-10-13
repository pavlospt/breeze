#!/bin/bash
# Builds Breeze.app (release) and installs it into ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

# SwiftUI's macros (e.g. @State in the macOS 27 SDK) ship only with Xcode, so prefer
# Xcode's toolchain even when xcode-select points at the Command Line Tools.
if [ -z "${DEVELOPER_DIR:-}" ]; then
  XCODE=$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null | head -1)
  if [ -n "$XCODE" ]; then export DEVELOPER_DIR="$XCODE/Contents/Developer"; fi
fi

swift build -c release --product Breeze

APP="$HOME/Applications/Breeze.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Breeze "$APP/Contents/MacOS/Breeze"
cp Support/Info.plist "$APP/Contents/Info.plist"
[ -f Support/AppIcon.icns ] || swift scripts/make-icon.swift Support/AppIcon.icns
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: fine for running locally; use a Developer ID to distribute.
codesign --force --sign - "$APP"
echo "Installed: $APP"
