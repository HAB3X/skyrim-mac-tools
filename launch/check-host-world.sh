#!/bin/zsh
# Checks a Plus server's host world mode and local network discovery with two fake players, without the game.
#   check-host-world.sh <folder with SkyrimTogetherServer.exe> <folder with FakePlayers.exe>
# Runs a server with Gameplay:bHostWorld on, UPnP off and an empty password from a copy of the folder's config, then
# FakePlayers.exe as host and as joiner. Prints one line per check; exits 0 when all pass.
set -u
SERVER_DIR=${1:?folder with SkyrimTogetherServer.exe}
PLAYERS_DIR=${2:?folder with FakePlayers.exe}
SKYRIM_HOME=${SKYRIM_HOME:-$HOME/Games/skyrim}

export WINEPREFIX="$SKYRIM_HOME/prefix" WINEMSYNC=1 WINEDEBUG=-all
# Wine's encryption (bcrypt, which the network handshake needs) comes from the libraries next to it
export DYLD_FALLBACK_LIBRARY_PATH="$SKYRIM_HOME/wine/lib:/usr/lib"
WINE="$SKYRIM_HOME/wine/bin/wine"
WORK=$(mktemp -d)
trap 'pkill -9 -f "SkyrimTogetherServer.exe|FakePlayers.exe"; rm -rf "$WORK"' EXIT

# The server reads config\STServer.ini next to it: run a copy with the settings the check needs
cp "$SERVER_DIR"/SkyrimTogetherServer.exe "$SERVER_DIR"/STServer.dll "$WORK"/ || exit 1
mkdir -p "$WORK/config"
cat > "$WORK/config/STServer.ini" <<'INI'
[GameServer]
sPassword=
bUPnP=false
[Gameplay]
bHostWorld=true
INI

cd "$WORK" && (tail -f /dev/null | "$WINE" SkyrimTogetherServer.exe > "$WORK/server.log" 2>&1 &)
for _ in {1..30}; do grep -aq "started on port" "$WORK/server.log" && break; sleep 1; done
grep -aq "started on port" "$WORK/server.log" || { echo "FAIL the server didn't start"; tail -5 "$WORK/server.log"; exit 1; }

cd "$PLAYERS_DIR"
("$WINE" FakePlayers.exe host 127.0.0.1:10578 2>/dev/null | tr -d '\r' > "$WORK/host.log" &)
sleep 5
"$WINE" FakePlayers.exe join 127.0.0.1:10578 2>/dev/null | tr -d '\r' > "$WORK/join.log"
for _ in {1..25}; do pgrep -f "FakePlayers.exe host" > /dev/null || break; sleep 1; done
grep -h "PASS\|FAIL" "$WORK/host.log" "$WORK/join.log"
! grep -qh "FAIL" "$WORK/host.log" "$WORK/join.log" && grep -q "ALL CHECKS PASSED" "$WORK/join.log"
