#!/bin/bash
# Collect what's needed to diagnose a Skyrim Together problem into ~/Desktop/SkyrimTogether-logs-<date>.zip and print
# its path: the newest Wine/DXMT logs, the mod's logs, Crash Logger reports, crash dumps, the setup check, versions,
# the load order and STServer.ini with its passwords removed. Never includes save games.
#   collect-logs.sh            (ST_VERSION=1.8.4-plus collect-logs.sh runs the setup check for the Plus build)
#   COLLECT_COUNT=n            how many of the newest files to take from each log folder (default 8)
set -u

COUNT=${COLLECT_COUNT:-8}
HERE=$(cd "$(dirname "$0")" && pwd)
SKYRIM_HOME="$HOME/Games/skyrim"
PREFIX="$SKYRIM_HOME/prefix"
USER_DIR="$PREFIX/drive_c/users/${USER:-$(id -un)}"
MY_GAMES="$USER_DIR/Documents/My Games/Skyrim Special Edition GOG"
LOAD_ORDER="$USER_DIR/AppData/Local/Skyrim Special Edition GOG"
GAMEDIR=$(/usr/bin/find "$PREFIX/drive_c/GOG Games" -maxdepth 2 -name SkyrimSE.exe -print -quit 2>/dev/null)
GAMEDIR=${GAMEDIR%/SkyrimSE.exe}
MOD="$GAMEDIR/Data/SkyrimTogetherReborn"

fail() { echo "FAIL $1" >&2; exit 1; }

STAGE=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/st-logs.XXXXXX") || fail "could not make a temporary folder"
trap '/bin/rm -rf "$STAGE"' EXIT
NAME="SkyrimTogether-logs-$(date +%Y-%m-%d_%H%M%S)"
OUT="$STAGE/$NAME"
ZIP="$HOME/Desktop/$NAME.zip"

# copy_newest <dest subfolder> <folder> <find -iname pattern> <count>: the newest non-empty matches, flat
copy_newest() {
  local dest="$OUT/$1" dir="$2" pattern="$3" n="$4"
  [ -d "$dir" ] || return 0
  mkdir -p "$dest"
  /usr/bin/find "$dir" -maxdepth 1 -type f -iname "$pattern" -size +0 -exec /bin/ls -t {} + 2>/dev/null \
    | /usr/bin/head -n "$n" \
    | while IFS= read -r f; do /bin/cp -p "$f" "$dest/" || echo "WARN could not copy $f" >&2; done
}

# STServer.ini with every password/token value replaced, so the zip can be shared
redacted_ini() {
  [ -f "$1" ] || return 0
  mkdir -p "$(dirname "$2")"
  /usr/bin/awk '{ k = tolower($0) } k ~ /^[ \t]*[a-z_]*(password|token)[a-z_]*[ \t]*=/ { sub(/=.*/, "=<removed>") } { print }' \
    "$1" > "$2" || fail "could not write a redacted copy of $1"
}

# Build strings baked into a Skyrim Together executable ("Build: v1.8.4-plus.3 ...", "v1.8.4-plus.3")
build_strings() {
  [ -f "$1" ] || { echo "  (missing)"; return; }
  /usr/bin/strings -n 6 "$1" | /usr/bin/grep -E '^Build: |^v[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$' | /usr/bin/sort -u | /usr/bin/sed 's/^/  /'
}

copy_newest wine-dxmt "$SKYRIM_HOME/logs" '*.log' "$COUNT"
copy_newest mod "$MOD/logs" '*.log' "$COUNT"
copy_newest skse "$MY_GAMES/SKSE" 'crash-*.log' 5
copy_newest skse "$MY_GAMES/SKSE" 'skse64.log' 1
copy_newest skse "$MY_GAMES/SKSE" 'CrashLogger.log' 1
# The mod writes crash_UTC_<time>.dmp next to SkyrimTogether.exe (Code/client/CrashHandler.cpp); Wine's own go elsewhere
for dir in "$MOD" "$GAMEDIR" "$SKYRIM_HOME/logs"; do copy_newest dumps "$dir" '*.dmp' 3; done
for f in plugins.txt loadorder.txt; do copy_newest game-settings "$LOAD_ORDER" "$f" 1; done
for f in Skyrim.ini SkyrimPrefs.ini SkyrimCustom.ini; do copy_newest game-settings "$MY_GAMES" "$f" 1; done
copy_newest game-settings "$MOD/config" 'CrashGuards.ini' 1
redacted_ini "$MOD/config/STServer.ini" "$OUT/game-settings/STServer.ini"
# Servers started from the Mac builds' own folders (skyrim-together.sh server, the host app)
for server in "$HOME"/Games/skyrim-together-*-mac/files/SkyrimTogetherReborn; do
  [ -d "$server" ] || continue
  build=$(basename "${server%/files/SkyrimTogetherReborn}")
  redacted_ini "$server/config/STServer.ini" "$OUT/servers/$build/STServer.ini"
  copy_newest "servers/$build" "$server/logs" '*.log' "$COUNT"
done

{
  echo "collected $(date)"
  echo "macOS $(/usr/bin/sw_vers -productVersion) ($(/usr/bin/sw_vers -buildVersion)), $(/usr/bin/uname -m)," \
       "$(/usr/sbin/sysctl -n machdep.cpu.brand_string), $(( $(/usr/sbin/sysctl -n hw.memsize) / 1073741824 )) GB"
  echo "Wine: $("$SKYRIM_HOME/wine/bin/wine" --version 2>/dev/null || echo missing)"
  echo "DXMT: $(/bin/cat "$HOME/Games/dxmt-builds/INSTALLED.txt" 2>/dev/null || echo unknown)"
  echo "game folder: ${GAMEDIR:-not found}"
  echo "installed Skyrim Together build: $(/bin/cat "$MOD/.installed-version" 2>/dev/null || echo none)"
  echo "SkyrimTogether.exe:"; build_strings "$MOD/SkyrimTogether.exe"
  echo "STServer.dll:"; build_strings "$MOD/STServer.dll"
  echo "running: $(/usr/bin/pgrep -fl 'SkyrimTogether.exe|SkyrimSE.exe|SkyrimTogetherServer.exe' | /usr/bin/cut -c1-120 | /usr/bin/tr '\n' ';')"
  echo
  echo "skyrim-together.sh check (ST_VERSION=${ST_VERSION:-1.8.4}):"
  /bin/bash "$HERE/skyrim-together.sh" check 2>&1
} > "$OUT/system.txt"

# Nothing from the save folder, and no password value left anywhere: stop rather than write a zip that leaks one
leak=$(/usr/bin/find "$OUT" \( -path '*/Saves/*' -o -iname '*.ess' -o -iname '*.skse' \) -print -quit)
[ -z "$leak" ] || fail "a save file got into the collection ($leak)"
/usr/bin/grep -rqiE '^[[:space:]]*s(admin)?password[[:space:]]*=[[:space:]]*[^<[:space:]]' "$OUT" \
  && fail "a password survived redaction; nothing was written"

/usr/bin/find "$OUT" -type d -empty -delete   # e.g. no crash dumps
# No ._ AppleDouble files: Windows users and forums see them as junk
/usr/bin/ditto -c -k --norsrc --noextattr --noacl --keepParent "$OUT" "$ZIP" || fail "could not write $ZIP"
echo "$ZIP"
