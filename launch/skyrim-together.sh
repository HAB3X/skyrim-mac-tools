#!/bin/bash
# Skyrim Together Reborn on this Mac: the GOG Skyrim in SkyrimMT's Wine prefix (~/Games/skyrim), no Steam.
#   skyrim-together.sh            install/update the mod into the game if needed, then start Skyrim Together
#   skyrim-together.sh server     run a Skyrim Together server here (port 10578, UDP) for friends to join
#   skyrim-together.sh check      report what is ready and what is missing; changes nothing
set -u

ST_VERSION=${ST_VERSION:-1.8.4}   # "1.8.4-plus" picks the Plus build (Desktop: Skyrim Together Plus.app)

SKYRIM_HOME="$HOME/Games/skyrim"
export WINEPREFIX="$SKYRIM_HOME/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="$SKYRIM_HOME/wine/lib:/usr/lib"
export WINEDEBUG="${WINEDEBUG:--all}"
# msync: Wine synchronisation through Mach ports instead of wineserver round trips (much less stutter). Every Wine
# process of this prefix must agree (game, server, Chromium UI, SkyrimMT launches via skyrim-play.sh), so both scripts set it.
export WINEMSYNC=1
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
# Apple's Metal HUD (fps, frame times) while ~/Games/skyrim/config/metal-hud exists: touch it to show, delete it to hide.
[ -f "$SKYRIM_HOME/config/metal-hud" ] && export MTL_HUD_ENABLED=1
WINE="$SKYRIM_HOME/wine/bin/wine"
WINESERVER="$SKYRIM_HOME/wine/bin/wineserver"
LOGS="$SKYRIM_HOME/logs"
PLUGINS_TXT="$WINEPREFIX/drive_c/users/${USER:-$(id -un)}/AppData/Local/Skyrim Special Edition GOG/plugins.txt"
ST_PLUGINS=(SkyrimTogether.esp SkyrimTogetherQuestPatches.esp)

fail() { echo "FAIL $1"; exit 1; }

# The GOG install: the folder holding SkyrimSE.exe under C:\GOG Games (SkyrimMT's install-gog.sh puts it there).
GAMEDIR=$(/usr/bin/find "$WINEPREFIX/drive_c/GOG Games" -maxdepth 2 -name SkyrimSE.exe -print -quit 2>/dev/null)
GAMEDIR=${GAMEDIR%/SkyrimSE.exe}
DATA="$GAMEDIR/Data"

# FileVersion of a Windows executable (VS_FIXEDFILEINFO), e.g. 1.7.104.0
exe_version() {
  python3 -I -c 'import sys,struct
d=open(sys.argv[1],"rb").read(); i=d.find(b"\xbd\x04\xef\xfe")
ms,ls=struct.unpack("<II",d[i+8:i+16]) if i>=0 else (0,0)
print(f"{ms>>16}.{ms&0xffff}.{ls>>16}.{ls&0xffff}" if i>=0 else "")' "$1"
}

# Skyrim Together ships one build per game runtime: the default one for 1.7.104 (Steam and GOG) and an "sse1.6.1170"
# one for 1.6.1170 (Steam) / 1.6.1179 (GOG). Pick the build and Address Library file that match the installed game.
INSTALLED_VERSION=$([ -n "$GAMEDIR" ] && exe_version "$GAMEDIR/SkyrimSE.exe")
case "$INSTALLED_VERSION" in
  1.6.1170.0|1.6.1179.0) ST_FILES="$HOME/Games/skyrim-together-$ST_VERSION-sse1.6.1170/files"; GAME_VERSION=$INSTALLED_VERSION ;;
  *)                     ST_FILES="$HOME/Games/skyrim-together-$ST_VERSION/files"; GAME_VERSION=1.7.104.0 ;;
esac
# A Mac (Wine) build of that release, when there is one, is preferred: the official launcher dies at start-up under
# Wine (see the README.txt next to the Mac build).
[ -d "${ST_FILES%/files}-mac/files" ] && ST_FILES="${ST_FILES%/files}-mac/files"
ADDRLIB="versionlib-$(printf '%s' "$GAME_VERSION" | tr . -).bin"
ADDRLIB_SRC="$HOME/Games/address-library/$ADDRLIB"         # copied into Data/SKSE/Plugins when the game lacks it

check() {   # prints one line per requirement; returns 1 when any is missing
  local bad=0 v
  [ -x "$WINE" ] && echo "OK   Wine runtime" || { echo "MISS Wine runtime (run SkyrimMT setup)"; bad=1; }
  [ -d "$ST_FILES/SkyrimTogetherReborn" ] && echo "OK   Skyrim Together $ST_VERSION files" \
    || { echo "MISS Skyrim Together files in $ST_FILES"; bad=1; }
  if [ -z "$GAMEDIR" ]; then echo "MISS Skyrim (GOG) — not installed in the prefix yet"; return 1; fi
  echo "OK   Skyrim at $GAMEDIR"
  v=$(exe_version "$GAMEDIR/SkyrimSE.exe")
  [ "$v" = "$GAME_VERSION" ] && echo "OK   game version $v" \
    || { echo "MISS game version $v — Skyrim Together $ST_VERSION needs $GAME_VERSION"; bad=1; }
  [ -f "$DATA/SKSE/Plugins/$ADDRLIB" ] && echo "OK   Address Library ($ADDRLIB)" \
    || { echo "MISS Address Library: put $ADDRLIB in $DATA/SKSE/Plugins (Nexus: Address Library for SKSE Plugins, All in one)"; bad=1; }
  return $bad
}

# Copy the release into Data (APFS clones: instant, no extra space). Only files that differ are replaced.
install_mod() {
  local stamp="$DATA/SkyrimTogetherReborn/.installed-version" want
  want=$(basename "${ST_FILES%/files}")   # which build: release + game runtime (+ -mac)
  [ "$(cat "$stamp" 2>/dev/null)" = "$want" ] && return 0
  echo "installing $want into $DATA"
  /bin/cp -cR "$ST_FILES/" "$DATA/" || fail "could not copy Skyrim Together into $DATA"
  echo "$want" > "$stamp"
}

# Turn the mod's plugins on (AE plugins.txt: "*Name.esp" = enabled), keeping every other line as it is.
enable_plugins() {
  mkdir -p "$(dirname "$PLUGINS_TXT")" && touch "$PLUGINS_TXT" || fail "cannot write $PLUGINS_TXT"
  # The file has Windows line endings: compare names without "\r" and the leading "*". Drop the mod's entries
  # (enabled or not), then append them enabled, so a rerun leaves the file unchanged.
  local names; names=$(printf '%s\n' "${ST_PLUGINS[@]}")
  NAMES="$names" /usr/bin/awk 'BEGIN { n = split(tolower(ENVIRON["NAMES"]), a, "\n"); for (i = 1; i <= n; i++) mod[a[i]] = 1 }
    { k = tolower($0); sub(/\r$/, "", k); sub(/^\*/, "", k); if (!(k in mod)) print }' "$PLUGINS_TXT" > "$PLUGINS_TXT.tmp" \
    && printf '*%s\r\n' "${ST_PLUGINS[@]}" >> "$PLUGINS_TXT.tmp" && mv "$PLUGINS_TXT.tmp" "$PLUGINS_TXT" \
    || fail "could not update $PLUGINS_TXT"
}

win_path() { printf 'C:%s' "$(printf '%s' "${1#"$WINEPREFIX/drive_c"}" | tr '/' '\\')"; }

mkdir -p "$LOGS"
case "${1:-play}" in
  check) check; exit $? ;;
  server)
    [ -d "$ST_FILES/SkyrimTogetherReborn" ] || fail "Skyrim Together files missing in $ST_FILES"
    cd "$ST_FILES/SkyrimTogetherReborn" || exit 1
    echo "server on UDP port 10578 — friends connect to this Mac's IP; settings in config/STServer.ini"
    exec "$WINE" SkyrimTogetherServer.exe ;;
  play)
    if [ -n "$GAMEDIR" ] && [ ! -f "$DATA/SKSE/Plugins/$ADDRLIB" ] && [ -f "$ADDRLIB_SRC" ]; then
      mkdir -p "$DATA/SKSE/Plugins" && /bin/cp "$ADDRLIB_SRC" "$DATA/SKSE/Plugins/" || fail "could not copy $ADDRLIB"
    fi
    check || fail "not ready (see MISS lines above)"
    install_mod
    enable_plugins
    # SSE Engine Fixes: its memory-manager overrides hook the same game allocator Skyrim Together replaces with mimalloc;
    # both at once would pair one allocator's blocks with the other's free. Off here, on for plain Skyrim (skyrim-play.sh).
    EF="$DATA/SKSE/Plugins/EngineFixes.toml"
    [ -f "$EF" ] && /usr/bin/sed -i '' -E 's/^(bOverrideMemoryManager|bOverrideScaleformAllocator|bOverrideHavokMemorySystem)( *)= *true/\1\2= false/' "$EF"
    # Engine Fixes' preloader (d3dx9_42.dll next to SkyrimSE.exe) only loads with a native-first override (Wine has its own)
    for d in d3dx9_42 tbb tbbmalloc; do
      [ -f "$GAMEDIR/$d.dll" ] && export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:+$WINEDLLOVERRIDES;}$d=n,b"
    done
    # Microsoft's XAudio2 and shader compiler, as SkyrimMT sets them up for SkyrimSE.exe: Wine applies those per program
    # name, and here the game runs inside SkyrimTogether.exe. Without them some sounds (hits, impacts) don't play.
    key='HKCU\Software\Wine\AppDefaults\SkyrimTogether.exe\DllOverrides'
    if ! /usr/bin/grep -q 'AppDefaults\\\\SkyrimTogether.exe\\\\DllOverrides' "$WINEPREFIX/user.reg" 2>/dev/null; then
      for n in xaudio2_7 x3daudio1_7 xapofx1_5 d3dcompiler_47; do
        [ -f "$WINEPREFIX/drive_c/windows/system32/$n.dll" ] && "$WINE" reg add "$key" /v "$n" /t REG_SZ /d native,builtin /f >/dev/null 2>&1
      done
    fi
    cd "$DATA/SkyrimTogetherReborn" || exit 1
    "$WINE" SkyrimTogether.exe --exePath "$(win_path "$GAMEDIR/SkyrimSE.exe")" > "$LOGS/skyrim-together.log" 2>&1 &
    disown
    echo "Skyrim Together started (Wine log: $LOGS/skyrim-together.log, mod logs: $DATA/SkyrimTogetherReborn/logs)" ;;
  *) echo "usage: $0 [play|server|check]"; exit 2 ;;
esac
