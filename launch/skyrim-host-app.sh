#!/bin/zsh
# Skyrim Together Host on the Mac: the host window (password, player list, kick) from the release, run under Wine from
# the Skyrim Together build's server folder. ST_VERSION=1.8.4-plus hosts with the Plus build.
# (skyrim-host.sh is the one-click terminal version: starts the server and the game.)
export ST_VERSION="${ST_VERSION:-1.8.4}"
SKYRIM_HOME="$HOME/Games/skyrim"
SERVER_DIR=$(/bin/ls -d "$HOME/Games/skyrim-together-$ST_VERSION"{-sse1.6.1170,}{-mac,}/files/SkyrimTogetherReborn 2>/dev/null | /usr/bin/head -1)
HOST="$SERVER_DIR/Skyrim Together Host.exe"
[ -f "$HOST" ] || { /usr/bin/osascript -e "display notification \"Skyrim Together Host.exe isn't in $SERVER_DIR\" with title \"Skyrim Together Host\""; exit 1; }
export WINEPREFIX="$SKYRIM_HOME/prefix" WINEMSYNC=1 WINEDEBUG=-all DYLD_FALLBACK_LIBRARY_PATH="$SKYRIM_HOME/wine/lib:/usr/lib"
cd "$SERVER_DIR" && exec "$SKYRIM_HOME/wine/bin/wine" "Skyrim Together Host.exe" > "$SKYRIM_HOME/logs/host-app.log" 2>&1
