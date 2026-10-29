#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
[[ "$(uname -s)" == Darwin ]] || { echo "macOS 14 or newer is required." >&2; exit 1; }
xcrun --find swiftc >/dev/null
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
CACHE_DIR="${CACHE_DIR:-${TMPDIR:-/tmp}/naidan-swift-cache}"
APP="$BUILD_DIR/Naidan Demo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$CACHE_DIR"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
xcrun swiftc "$ROOT/Sources/main.swift" -O -target "$(uname -m)-apple-macosx14.0" -module-cache-path "$CACHE_DIR" -o "$APP/Contents/MacOS/NaidanPet"
# Only explicitly supplied, user-owned animation frames are bundled.
if [[ -n "${FRAMES_DIR:-}" ]]; then
  [[ -d "$FRAMES_DIR" ]] || { echo "FRAMES_DIR does not exist" >&2; exit 1; }
  [[ ! -e "$APP/Contents/Resources/Frames" ]] || { echo "Use a fresh BUILD_DIR for custom frames" >&2; exit 1; }
  cp -R "$FRAMES_DIR" "$APP/Contents/Resources/Frames"
fi
# Remove macOS metadata sidecars created on exFAT build volumes.
find "$APP" -name '._*' -type f -delete
codesign --force --sign - "$APP"
echo "Built: $APP"
