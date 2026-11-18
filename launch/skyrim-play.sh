#!/bin/bash
# Start GOG Skyrim (SkyrimMT's launcher) at the Mac's current screen size: every launch reads the main screen's size
# in macOS points (what Wine shows Windows programs, Retina mode off) and writes it to SkyrimPrefs.ini as a
# borderless window, so the game always fills the screen even after the display settings change.
# Used by ~/Desktop/Skyrim.app; "skyrim-play.sh together" starts Skyrim Together instead (~/Desktop/Skyrim Together.app).
set -u
export WINEMSYNC=1   # msync for every Wine process of the prefix (see skyrim-together.sh); SkyrimMT records it per session
# DXMT (Metal renderer) = jdrly's gw2-on-mac fork build (~/Games/dxmt-builds/INSTALLED.txt): pre-build the pipelines
# recorded on earlier runs, log hitches/stats to ~/Games/skyrim/logs, and let Metal pace 60 fps (VSync is broken on
# ProMotion screens, DXMT issue #26). The previous DXMT is in ~/Games/skyrim/backups/dxmt-9839e55-skyrimmt.
export DXMT_WARM="${DXMT_WARM:-all}"
export DXMT_LOG_PATH="${DXMT_LOG_PATH:-Z:$HOME/Games/skyrim/logs}"
export DXMT_CONFIG="${DXMT_CONFIG:-d3d11.preferredMaxFrameRate=60;}"
[ -f "$HOME/Games/skyrim/config/metal-hud" ] && export SKYRIMMT_METAL_HUD=1   # fps overlay (see skyrim-together.sh)
PREFS="$HOME/Games/skyrim/prefix/drive_c/users/${USER:-$(id -un)}/Documents/My Games/Skyrim Special Edition GOG/SkyrimPrefs.ini"
LAUNCHER="$HOME/Documents/Mac-Wine-References/SkyrimMT-source/scripts/skyrim.sh"

size=$(/usr/bin/osascript -l JavaScript -e 'ObjC.import("AppKit"); const f = $.NSScreen.mainScreen.frame; Math.round(f.size.width) + " " + Math.round(f.size.height)')
read -r w h <<< "$size"
if [ -f "$PREFS" ] && [ -n "${w:-}" ] && [ -n "${h:-}" ]; then
  /usr/bin/sed -i '' -E "s/^iSize W=[0-9]+/iSize W=$w/; s/^iSize H=[0-9]+/iSize H=$h/; s/^bBorderless=[01]/bBorderless=1/; s/^bFull Screen=[01]/bFull Screen=0/" "$PREFS"
fi
# SSE Engine Fixes' memory-manager overrides: on for plain Skyrim, off for Skyrim Together (see skyrim-together.sh)
EF="$HOME/Games/skyrim/prefix/drive_c/GOG Games/Skyrim Special Edition/Data/SKSE/Plugins/EngineFixes.toml"
if [ -f "$EF" ]; then
  mm=true; [ "${1:-}" = together ] && mm=false
  /usr/bin/sed -i '' -E "s/^(bOverrideMemoryManager|bOverrideScaleformAllocator|bOverrideHavokMemorySystem)( *)= *(true|false)/\\1\\2= $mm/" "$EF"
fi
case "${1:-}" in
  together) exec /bin/bash "$HOME/Games/skyrim-together.sh" ;;   # Skyrim Together (~/Desktop/Skyrim Together.app)
  *)        exec /bin/bash "$LAUNCHER" ;;
esac
