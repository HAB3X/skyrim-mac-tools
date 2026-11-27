#!/bin/bash
# Builds "Skyrim Together.app" into the repo's build/ folder and prints its path. The app runs the scripts in this
# repo's launch/ folder; its Info.plist records where that is (STLaunchFolder), so rebuild after moving the repo.
#   mac-app/build.sh                      for this Mac: runs the scripts in this repo (runs the tests first)
#   mac-app/build.sh --release plus.5     for the release zip: carries its own copy of launch/ and fix-input.exe
set -euo pipefail
RELEASE=""
if [ "${1:-}" = --release ]; then
  RELEASE=${2:?"usage: build.sh --release <version, e.g. plus.5>"}
fi

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
APP="$REPO/build${RELEASE:+/release}/Skyrim Together.app"   # a release build never replaces this Mac's own
LOG="$REPO/build/mac-app-build.log"
mkdir -p "$(dirname "$APP")"
cd "$HERE"

swift test > "$LOG" 2>&1 || { grep -E 'error|✘' "$LOG" | head -20; echo "FAIL tests (full log: $LOG)"; exit 1; }
swift build -c release --product SkyrimTogether >> "$LOG" 2>&1 || { grep error "$LOG" | head -20; echo "FAIL build (full log: $LOG)"; exit 1; }
BIN="$(swift build -c release --show-bin-path)/SkyrimTogether"

/bin/rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/SkyrimTogether"
COMMIT=$(git -C "$REPO" rev-parse --short HEAD)
if [ -n "$RELEASE" ]; then
  # The scripts travel inside the app; the app finds them there when Info.plist names no launch folder
  mkdir -p "$APP/Contents/Resources/launch/tools"
  cp "$REPO"/launch/*.sh "$APP/Contents/Resources/launch/" && rm "$APP/Contents/Resources/launch/check-host-world.sh"   # a test, not for players
  x86_64-w64-mingw32-gcc -O2 -s "$REPO/launch/fix-input.c" -o "$APP/Contents/Resources/launch/tools/fix-input.exe" \
    -luser32 -lpsapi >> "$LOG" 2>&1 || { echo "FAIL fix-input.exe (full log: $LOG)"; exit 1; }
  VERSION=$RELEASE
  LAUNCH_KEY=""
else
  VERSION=1.0
  LAUNCH_KEY="<key>STLaunchFolder</key><string>$REPO/launch</string>"
fi
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.hab3x.skyrim-together</string>
  <key>CFBundleName</key><string>Skyrim Together</string>
  <key>CFBundleDisplayName</key><string>Skyrim Together</string>
  <key>CFBundleExecutable</key><string>SkyrimTogether</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$COMMIT</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Skyrim Together brings the game's window to the front once it opens.</string>
  $LAUNCH_KEY
</dict>
</plist>
PLIST
plutil -lint -s "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >> "$LOG" 2>&1 || { echo "FAIL codesign (full log: $LOG)"; exit 1; }
echo "$APP"
