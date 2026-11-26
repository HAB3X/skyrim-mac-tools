#!/bin/bash
# Skyrim Together Reborn on this Mac: the GOG Skyrim in SkyrimMT's Wine prefix (~/Games/skyrim), no Steam.
#   skyrim-together.sh            install/update the mod into the game if needed, then start Skyrim Together
#   skyrim-together.sh server     run a Skyrim Together server here (port 10578, UDP) for friends to join
#   skyrim-together.sh check      report what is ready and what is missing; changes nothing
#   skyrim-together.sh fix-input  give the running game its mouse and keyboard back (no restart)
#   skyrim-together.sh update [check|install|rollback]   Plus build updates from GitHub (ST_VERSION=1.8.4-plus)
set -u

ST_VERSION=${ST_VERSION:-1.8.4}   # "1.8.4-plus" picks the Plus build (Desktop: Skyrim Together Plus.app)
ST_BUILDS=${ST_BUILDS:-$HOME/Games}   # where the builds are: skyrim-together-<ST_VERSION>[-sse1.6.1170][-mac]/files

SKYRIM_HOME="$HOME/Games/skyrim"
export WINEPREFIX="$SKYRIM_HOME/prefix"
export DYLD_FALLBACK_LIBRARY_PATH="$SKYRIM_HOME/wine/lib:/usr/lib"
export WINEDEBUG="${WINEDEBUG:--all}"
# msync: Wine synchronisation through Mach ports instead of wineserver round trips (much less stutter). Every Wine
# process of this prefix must agree (game, server, Chromium UI, SkyrimMT launches via skyrim-play.sh), so both scripts set it.
export WINEMSYNC=1
# DXMT (Metal renderer) = jdrly's gw2-on-mac fork with dxmt/ patches (~/Games/dxmt-builds/INSTALLED.txt): pre-build the pipelines
# recorded on earlier runs, log hitches/stats to ~/Games/skyrim/logs, and let Metal pace 60 fps (VSync is broken on
# ProMotion screens, DXMT issue #26). Earlier builds: ~/Games/skyrim/backups.
# Rosetta reports AVX/AVX2 to the game and SKSE plugins (macOS 15+), as CrossOver does by default
export ROSETTA_ADVERTISE_AVX=1
export DXMT_WARM="${DXMT_WARM:-all}"
export DXMT_LOG_PATH="${DXMT_LOG_PATH:-Z:$HOME/Games/skyrim/logs}"
# DXMT caps an unfocused game at 30 fps, and da80816 treated the game as unfocused whenever Wine reported no
# foreground window: 88 of 191 logged [Perf] intervals sat at exactly 30 fps in play. The installed build (dxmt/)
# counts the active app's on-screen window as foreground; containment until a game session confirms that: keep 60
# unless it's minimized (DXMT_BG_FPS_MINIMIZED keeps its own default for that).
export DXMT_BG_FPS="${DXMT_BG_FPS:-60}"
export DXMT_CONFIG="${DXMT_CONFIG:-d3d11.preferredMaxFrameRate=60;}"
# Rendering itself as upstream DXMT: the fork's draw/state/resource shortcuts were tuned on Guild Wars 2, and with them
# Skyrim lost actors and items (invisible). Pacing, warming and the stats above stay. Remove a line to retest that one.
export DXMT_GETDATA_SKIP_FLUSH=0 DXMT_SKIP_SAME_STATE=0 DXMT_SKIP_EMPTY_SLOTS=0 DXMT_SKIP_REBIND=0
export DXMT_PSO_MRU=0 DXMT_PSO_TOPOLOGY_KEEP=0 DXMT_DEPTH_PFV=1 DXMT_STENCIL_PFV=1
export DXMT_MAP_FAST=0 DXMT_UNRETAINED=0 DXMT_RELEASE_POOL=0 DXMT_RESIDENCY_SET=0 DXMT_VIEW_KEY_ARRAY_BIT=0 DXMT_METAL4=0
# Apple's Metal HUD (fps, frame times) while ~/Games/skyrim/config/metal-hud exists: touch it to show, delete it to hide.
[ -f "$SKYRIM_HOME/config/metal-hud" ] && export MTL_HUD_ENABLED=1
WINE="$SKYRIM_HOME/wine/bin/wine"

game_pid() { /usr/bin/pgrep -f "SkyrimTogether.exe --exePath" | /usr/bin/tail -1; }
make_frontmost() {   # $1: pid of a Mac app
  /usr/bin/osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $1) to true" >/dev/null 2>&1 \
    || { echo "Couldn't make the game the active app (allow this app to control System Events in Privacy & Security, Automation)" >&2; return 1; }
}
front_pid() { /usr/bin/lsappinfo info -only pid "$(/usr/bin/lsappinfo front)" | /usr/bin/sed -n 's/.*"pid"=\([0-9]*\).*/\1/p'; }

# Skyrim reads the mouse and keyboard through DirectInput, which only works while the game's window is Wine's
# foreground window, and Wine's foreground isn't macOS's: after a Cmd-Tab Wine can be left with none while the game is
# the active Mac app, and the game then gets no input until it restarts. fix-input.exe (launch/fix-input.c) makes the
# game's window Wine's foreground window again; --reset also releases the cursor clip and re-activates the window.
FIX_INPUT="$SKYRIM_HOME/tools/fix-input.exe"
fix_input() {
  [ -f "$FIX_INPUT" ] || { echo "FAIL $FIX_INPUT is missing: x86_64-w64-mingw32-gcc -O2 -s launch/fix-input.c -o $FIX_INPUT -luser32 -lpsapi"; return 1; }
  "$WINE" "$FIX_INPUT" "$@"
}

# Wine opens the game's window without making it the active app: macOS keeps the keyboard and mouse with whatever
# started it (Terminal, another app). Once the window is there, make the game the active app; then, for as long as the
# game runs, give Wine's foreground back to the game each time it becomes the active Mac app again (Cmd-Tab, Dock),
# and whenever Wine has no foreground window at all (fix-input.exe --watch).
bring_to_front() {
  local pid="" front last=""
  for _ in {1..120}; do
    sleep 1
    pid=$(game_pid)
    [ -n "$pid" ] || continue
    windows=$(/usr/bin/osascript -e "tell application \"System Events\" to count windows of (first process whose unix id is $pid)" 2>/dev/null)
    [ "${windows:-0}" -gt 0 ] && break
    pid=""
  done
  [ -n "$pid" ] || return
  make_frontmost "$pid"
  fix_input --watch >> "$LOGS/fix-input.log" 2>&1 &   # inside Wine: no foreground window at all -> the game's
  while /bin/kill -0 "$pid" 2>/dev/null; do
    front=$(front_pid)
    [ "$front" = "$pid" ] && [ "$last" != "$pid" ] && fix_input >> "$LOGS/fix-input.log" 2>&1
    last=$front
    sleep 1
  done
}
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
  1.6.1170.0|1.6.1179.0) ST_FILES="$ST_BUILDS/skyrim-together-$ST_VERSION-sse1.6.1170/files"; GAME_VERSION=$INSTALLED_VERSION ;;
  *)                     ST_FILES="$ST_BUILDS/skyrim-together-$ST_VERSION/files"; GAME_VERSION=1.7.104.0 ;;
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

network_check() {   # things on this Mac that keep friends out; prints one WARN line each, never stops the game
  local fw=/usr/libexec/ApplicationFirewall/socketfilterfw vpn
  vpn=$(/usr/sbin/scutil --nc list 2>/dev/null | /usr/bin/sed -n 's/.*(Connected).*"\(.*\)".*/\1/p' | /usr/bin/head -1)
  [ -n "$vpn" ] && echo "WARN the VPN \"$vpn\" is connected: friends on your network can't reach a game you host. Disconnect it, or allow local network traffic in it."
  # --getappblocked says "permitted" for programs it has no rule for: the rule list is what counts
  if "$fw" --getglobalstate 2>/dev/null | /usr/bin/grep -q enabled \
     && ! "$fw" --listapps 2>/dev/null | /usr/bin/grep -A1 -F "$WINE " | /usr/bin/grep -q "Allow incoming"; then
    echo "WARN the Mac firewall blocks Wine: friends can't join a game you host. In Terminal:"
    echo "       sudo $fw --add $WINE && sudo $fw --unblockapp $WINE"
  fi
  return 0
}

# Copy the release into Data (APFS clones: instant, no extra space). Only files that differ are replaced.
install_mod() {
  local stamp="$DATA/SkyrimTogetherReborn/.installed-version" want
  want=$(basename "${ST_FILES%/files}")   # which build: release + game runtime (+ -mac), and its version when known
  [ -f "${ST_FILES%/files}/VERSION" ] && want="$want $(cat "${ST_FILES%/files}/VERSION")"
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

# Plus updates. Releases of HAB3X/TiltedEvolution are tagged v1.8.4-plus.N; each has one zip with a
# SkyrimTogether-1.6.1170 and a SkyrimTogether-1.7.104 folder (what goes into Data for that game runtime).
RELEASES_API="https://api.github.com/repos/HAB3X/TiltedEvolution/releases?per_page=30"

# The newest Plus release, from GitHub's public API: "<tag> <zip url> <size> <sha256 or ->"
latest_plus_release() {
  /usr/bin/curl -sSf --max-time 30 "$RELEASES_API" | python3 -I -c 'import json, re, sys
best = None
for r in json.load(sys.stdin):
    m = re.fullmatch(r"v1\.8\.4-plus\.(\d+)", r["tag_name"])
    zips = [a for a in r["assets"] if a["name"].endswith(".zip")]
    if m and zips and not r["draft"] and not r["prerelease"] and (best is None or int(m[1]) > best[0]):
        best = (int(m[1]), r["tag_name"], zips[0])
if best is None:
    sys.exit("no v1.8.4-plus.N release with a zip")
a = best[2]
print(best[1], a["browser_download_url"], a["size"], (a.get("digest") or "sha256:-").split(":", 1)[1])'
}

# The version baked into a build's SkyrimTogether.exe ("v1.8.4-plus.3"), empty when it has none
build_version() {
  [ -f "$1/files/SkyrimTogetherReborn/SkyrimTogether.exe" ] || return 0
  /usr/bin/strings -n 8 "$1/files/SkyrimTogetherReborn/SkyrimTogether.exe" | /usr/bin/grep -m1 -E '^v1\.8\.4-plus\.[0-9]+$'
}

# "UPDATE <tag> <bytes> <installed>" when a newer Plus release is out, else an OK line
update_check() {
  local release tag size have
  release=$(latest_plus_release) || { echo "FAIL could not read the Skyrim Together releases from GitHub"; return 1; }
  read -r tag _ size _ <<< "$release"
  have=$(build_version "${ST_FILES%/files}")
  if [ -n "$have" ] && [ "${have##*.}" -ge "${tag##*.}" ]; then
    echo "OK   Skyrim Together Plus $have is the newest release"
  else
    echo "UPDATE $tag $size ${have:-none}"
  fi
}

# Download the newest Plus release, check it, and make it the build for this game's runtime. The build it replaces
# stays next to it as <folder>.previous (update rollback swaps them); its config/ (STServer.ini) carries over.
update_install() {
  local release tag url size sha target top runtime got
  /usr/bin/pgrep -f 'SkyrimTogether.exe --exePath|SkyrimTogetherServer.exe' >/dev/null \
    && fail "Skyrim Together or its server is running: quit them first"
  release=$(latest_plus_release) || fail "could not read the Skyrim Together releases from GitHub"
  read -r tag url size sha <<< "$release"
  [ "$GAME_VERSION" = 1.7.104.0 ] && runtime=SkyrimTogether-1.7.104 || runtime=SkyrimTogether-1.6.1170
  target="${ST_FILES%/files}"
  # global, not local: the EXIT trap runs after this function has returned
  mkdir -p "$ST_BUILDS" && UPDATE_TMP=$(/usr/bin/mktemp -d "$ST_BUILDS/.st-update.XXXXXX") || fail "could not make a folder in $ST_BUILDS"
  trap '/bin/rm -rf "$UPDATE_TMP"' EXIT
  local tmp=$UPDATE_TMP
  echo "downloading $tag ($((size / 1048576)) MB)"
  /usr/bin/curl -sSfL --retry 2 -o "$tmp/release.zip" "$url" || fail "could not download $url"
  got=$(/usr/bin/stat -f %z "$tmp/release.zip")
  [ "$got" = "$size" ] || fail "the download is $got bytes, GitHub lists $size: not installed"
  if [ "$sha" = - ]; then
    echo "WARN GitHub lists no SHA-256 for $tag: only its size was checked"
  else
    [ "$(/usr/bin/shasum -a 256 "$tmp/release.zip" | /usr/bin/cut -d' ' -f1)" = "$sha" ] \
      || fail "the download's SHA-256 isn't the one GitHub lists: not installed"
  fi
  top=$(/usr/bin/unzip -Z1 "$tmp/release.zip" | /usr/bin/head -1); top=${top%%/*}
  /usr/bin/unzip -q "$tmp/release.zip" "$top/$runtime/*" "$top/Skyrim Together Host.exe" "$top/PLUS-FEATURES.md" -d "$tmp/x" \
    && [ -f "$tmp/x/$top/$runtime/SkyrimTogetherReborn/SkyrimTogether.exe" ] || fail "$tag's zip has no $runtime build"
  mkdir -p "$tmp/new" && /bin/mv "$tmp/x/$top/$runtime" "$tmp/new/files" \
    && /bin/mv "$tmp/x/$top/Skyrim Together Host.exe" "$tmp/new/files/SkyrimTogetherReborn/" \
    && /bin/mv "$tmp/x/$top/PLUS-FEATURES.md" "$tmp/new/" && echo "$tag" > "$tmp/new/VERSION" || fail "could not unpack $tag"
  if [ -d "$target" ]; then
    [ -d "$target/files/SkyrimTogetherReborn/config" ] \
      && { /bin/cp -R "$target/files/SkyrimTogetherReborn/config/" "$tmp/new/files/SkyrimTogetherReborn/config/" || fail "could not keep the server settings"; }
    [ -f "$target/VERSION" ] || build_version "$target" > "$target/VERSION"
    /bin/rm -rf "$target.previous" && /bin/mv "$target" "$target.previous" || fail "could not set $target aside"
  fi
  /bin/mv "$tmp/new" "$target" || fail "could not put $tag in $target"
  echo "OK   installed $tag in $target; the game gets it at the next Play (the previous build is $target.previous)"
}

update_rollback() {
  local target="${ST_FILES%/files}"
  [ -d "$target.previous" ] || fail "there is no previous build ($target.previous)"
  /usr/bin/pgrep -f 'SkyrimTogether.exe --exePath|SkyrimTogetherServer.exe' >/dev/null \
    && fail "Skyrim Together or its server is running: quit them first"
  /bin/mv "$target" "$target.rollback" && /bin/mv "$target.previous" "$target" && /bin/mv "$target.rollback" "$target.previous" \
    || fail "could not swap $target and $target.previous"
  echo "OK   $(cat "$target/VERSION" 2>/dev/null || echo "the previous build") is back in $target; the game gets it at the next Play"
}

win_path() { printf 'C:%s' "$(printf '%s' "${1#"$WINEPREFIX/drive_c"}" | tr '/' '\\')"; }

mkdir -p "$LOGS"
case "${1:-play}" in
  check) check; status=$?; network_check; exit $status ;;
  update)
    [ "$ST_VERSION" = 1.8.4-plus ] || fail "updates are for the Plus build: ST_VERSION=1.8.4-plus"
    case "${2:-check}" in
      check) update_check ;;
      install) update_install ;;
      rollback) update_rollback ;;
      *) echo "usage: $0 update [check|install|rollback]"; exit 2 ;;
    esac ;;
  fix-input)
    pid=$(game_pid)
    [ -n "$pid" ] || fail "Skyrim Together isn't running"
    make_frontmost "$pid"
    fix_input --reset ;;
  server)
    [ -d "$ST_FILES/SkyrimTogetherReborn" ] || fail "Skyrim Together files missing in $ST_FILES"
    cd "$ST_FILES/SkyrimTogetherReborn" || exit 1
    echo "server on UDP port 10578 — friends connect to this Mac's IP; settings in config/STServer.ini"
    exec "$WINE" SkyrimTogetherServer.exe ;;
  play)
    # Hosting needs the network open; the game's own check says the same in chat once a server runs
    warnings=$(network_check)
    if [ -n "$warnings" ]; then
      echo "$warnings"
      /usr/bin/osascript -e "display notification \"$(printf '%s' "$warnings" | /usr/bin/head -1 | /usr/bin/cut -c6- | /usr/bin/tr -d '\"')\" with title \"Skyrim Together\"" >/dev/null 2>&1
    fi
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
    # DXMT rewrites its log on every start; keep the previous session's, to see why a session ran slow
    for log in "$LOGS"/{SkyrimSE,TPProcess}_d3d11.log; do
      [ -f "$log" ] && mv -f "$log" "${log%.log}.previous.log"
    done
    cd "$DATA/SkyrimTogetherReborn" || exit 1
    "$WINE" SkyrimTogether.exe --exePath "$(win_path "$GAMEDIR/SkyrimSE.exe")" > "$LOGS/skyrim-together.log" 2>&1 &
    disown
    bring_to_front &
    disown
    echo "Skyrim Together started (Wine log: $LOGS/skyrim-together.log, mod logs: $DATA/SkyrimTogetherReborn/logs)" ;;
  *) echo "usage: $0 [play|server|check|fix-input|update]"; exit 2 ;;
esac
