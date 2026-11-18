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
# Rosetta reports AVX/AVX2 to the game and SKSE plugins (macOS 15+), as CrossOver does by default
export ROSETTA_ADVERTISE_AVX=1
export DXMT_WARM="${DXMT_WARM:-all}"
export DXMT_LOG_PATH="${DXMT_LOG_PATH:-Z:$HOME/Games/skyrim/logs}"
export DXMT_CONFIG="${DXMT_CONFIG:-d3d11.preferredMaxFrameRate=60;}"
# Rendering itself as upstream DXMT: the fork's draw/state/resource shortcuts were tuned on Guild Wars 2, and with them
# Skyrim lost actors and items (invisible). Pacing, warming and the stats above stay. Remove a line to retest that one.
export DXMT_GETDATA_SKIP_FLUSH=0 DXMT_SKIP_SAME_STATE=0 DXMT_SKIP_EMPTY_SLOTS=0 DXMT_SKIP_REBIND=0
export DXMT_PSO_MRU=0 DXMT_PSO_TOPOLOGY_KEEP=0 DXMT_DEPTH_PFV=1 DXMT_STENCIL_PFV=1
export DXMT_MAP_FAST=0 DXMT_UNRETAINED=0 DXMT_RELEASE_POOL=0 DXMT_RESIDENCY_SET=0 DXMT_VIEW_KEY_ARRAY_BIT=0 DXMT_METAL4=0
[ -f "$HOME/Games/skyrim/config/metal-hud" ] && export SKYRIMMT_METAL_HUD=1   # fps overlay (see skyrim-together.sh)
PREFS="$HOME/Games/skyrim/prefix/drive_c/users/${USER:-$(id -un)}/Documents/My Games/Skyrim Special Edition GOG/SkyrimPrefs.ini"
LAUNCHER="$HOME/Documents/Mac-Wine-References/SkyrimMT-source/scripts/skyrim.sh"

size=$(/usr/bin/osascript -l JavaScript -e 'ObjC.import("AppKit"); const f = $.NSScreen.mainScreen.frame; Math.round(f.size.width) + " " + Math.round(f.size.height)')
read -r w h <<< "$size"
if [ -f "$PREFS" ] && [ -n "${w:-}" ] && [ -n "${h:-}" ]; then
  /usr/bin/sed -i '' -E "s/^iSize W=[0-9]+/iSize W=$w/; s/^iSize H=[0-9]+/iSize H=$h/; s/^bBorderless=[01]/bBorderless=1/; s/^bFull Screen=[01]/bFull Screen=0/" "$PREFS"
fi
# SSE Engine Fixes: loaded for plain Skyrim only. With it loaded, Skyrim Together showed no NPCs or items, even with its
# allocator and form-caching options off (2026-11-18), so for Skyrim Together the plugin is set aside (EngineFixes.dll.off).
PLUGINS="$HOME/Games/skyrim/prefix/drive_c/GOG Games/Skyrim Special Edition/Data/SKSE/Plugins"
EF="$PLUGINS/EngineFixes.toml"
if [ "${1:-}" = together ]; then
  [ -f "$PLUGINS/EngineFixes.dll" ] && /bin/mv -f "$PLUGINS/EngineFixes.dll" "$PLUGINS/EngineFixes.dll.off"
else
  [ -f "$PLUGINS/EngineFixes.dll.off" ] && /bin/mv -f "$PLUGINS/EngineFixes.dll.off" "$PLUGINS/EngineFixes.dll"
  [ -f "$EF" ] && for k in bOverrideMemoryManager bOverrideScaleformAllocator bOverrideHavokMemorySystem bOverrideScrapHeap \
                           bOverrideRenderPassCache bReplaceImports bFormCaching bTreeLodReferenceCaching; do
    /usr/bin/sed -i '' -E "s/^($k)( *)= *(true|false)/\\1\\2= true/" "$EF"
  done
fi
case "${1:-}" in
  together) exec /bin/bash "$HOME/Games/skyrim-together.sh" ;;   # Skyrim Together (~/Desktop/Skyrim Together.app)
  *)        exec /bin/bash "$LAUNCHER" ;;
esac
