#!/bin/zsh
# Checks multiplayer with fake players, without the game:
#   check-host-world.sh <Plus server folder> <folder with FakePlayers.exe> [official v1.8.4 server folder]
# 1. A Plus server (SkyrimTogetherServer.exe, STServer.dll) with host world on and UPnP off: host world mode and local
#    network discovery (FakePlayers host / join).
# 2. With a v1.8.4 server folder (official, or our mac release's): this build joining it in its protocol and chatting
#    (FakePlayers listen184 / talk184).
# Prints one line per check; exits 0 when all pass.
set -u
PLUS_SERVER=${1:?Plus server folder}
PLAYERS_DIR=${2:?folder with FakePlayers.exe}
OFFICIAL_SERVER=${3:-}
SKYRIM_HOME=${SKYRIM_HOME:-$HOME/Games/skyrim}

export WINEPREFIX="$SKYRIM_HOME/prefix" WINEMSYNC=1 WINEDEBUG=-all
# Wine's encryption (bcrypt, which the network handshake needs) comes from the libraries next to it
export DYLD_FALLBACK_LIBRARY_PATH="$SKYRIM_HOME/wine/lib:/usr/lib"
WINE="$SKYRIM_HOME/wine/bin/wine"
WORK=$(mktemp -d)
trap 'pkill -9 -f "SkyrimTogetherServer.exe|FakePlayers.exe"; rm -rf "$WORK"' EXIT
FAILED=0
# A server left running would take the port
pkill -9 -f "SkyrimTogetherServer.exe|FakePlayers.exe"; sleep 1

# run_pair <server folder> <ini text> <first role> <second role>: a server from a copy of the folder, the first role in
# the background, then the second
run_pair() {
    local dir="$WORK/server-$3"
    mkdir -p "$dir/config"
    cp "$1"/SkyrimTogetherServer.exe "$1"/STServer.dll "$dir"/ || exit 1
    print -r -- "$2" > "$dir/config/STServer.ini"

    (cd "$dir" && tail -f /dev/null | "$WINE" SkyrimTogetherServer.exe > "$dir/server.log" 2>&1 &)
    for _ in {1..30}; do grep -aq "started on port" "$dir/server.log" && break; sleep 1; done
    grep -aq "started on port" "$dir/server.log" || { echo "FAIL the server in $1 didn't start"; FAILED=1; return; }

    (cd "$PLAYERS_DIR" && "$WINE" FakePlayers.exe "$3" 127.0.0.1:10578 2>/dev/null | tr -d '\r' > "$dir/first.log" &)
    sleep 5
    (cd "$PLAYERS_DIR" && "$WINE" FakePlayers.exe "$4" 127.0.0.1:10578 2>/dev/null | tr -d '\r' > "$dir/second.log")
    for _ in {1..30}; do pgrep -f "FakePlayers.exe $3" > /dev/null || break; sleep 1; done
    grep -h "PASS\|FAIL" "$dir/first.log" "$dir/second.log"
    grep -qh "FAIL" "$dir/first.log" "$dir/second.log" && FAILED=1
    grep -q "ALL CHECKS PASSED" "$dir/second.log" || FAILED=1
    pkill -9 -f "SkyrimTogetherServer.exe"; sleep 1
}

echo "== Plus server: host world and local network discovery"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\n[Gameplay]\nbHostWorld=true' host join

if [[ -n "$OFFICIAL_SERVER" ]]; then
    echo "== Official v1.8.4 server: joining in its protocol"
    run_pair "$OFFICIAL_SERVER" $'[GameServer]\nsPassword=' listen184 talk184
fi

exit $FAILED
