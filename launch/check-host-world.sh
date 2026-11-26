#!/bin/zsh
# Checks multiplayer with fake players, without the game:
#   check-host-world.sh <Plus server folder> <folder with FakePlayers.exe> [official v1.8.4 server folder]
# 1. A Plus server (SkyrimTogetherServer.exe, STServer.dll) with host world on and UPnP off: host world mode and local
#    network discovery (FakePlayers host / join).
# 2. The host kicking a player from the player list (FakePlayers kicker / kicked).
# 3. The same server requiring the host's mods (ModPolicy:bRequireMods): refuses a player without them and names the
#    missing one, lets one with them in (FakePlayers mods).
#    Also: another version of a required mod refused (modversions), only the host's chosen kinds of quest shared
#    (questleader / questmember), the leader's fast travel offered to the party (travelleader / travelmember), quest
#    progress drifting from the leader's reported (desyncleader / desyncmember).
#    Also: a player whose game crashed put back in their party and place when they come back (lostleader / lostmember
#    / lostreturn).
# 5. A Plus server with the router closed and SkyrimTogetherRelay (from the FakePlayers folder) as its way in: host world
#    with both players joining through the relay.
# 6. A player with another Plus release refused, and the host told both versions (FakePlayers oldversion).
# 7. A required mod listed with its checksum: same size, other contents refused (FakePlayers modchecksums).
# 8. A vote kick and a ready check among three players, two of them at this computer's network address so they
#    aren't the host (FakePlayers votehost / votetarget / votevoter).
# 9. A host world server keeping its world (Gameplay:bKeepWorld): a chest's contents survive the server being killed
#    and started again in the same folder (FakePlayers worldstore / worldload).
# 10. A party member with a bounty gets the guards of that hold near them, the leader can't claim them back meanwhile, and
#     paying the bounty returns them to the leader (FakePlayers crimeleader / crimemember).
# 11. A downed party member revived by the other, a revive of someone who is up refused, and both told when the whole
#     party is down (FakePlayers reviveleader / revivemember).
# With SOAK_SECONDS set, also two players connected and chatting for that long (FakePlayers soak).
# 4. With a v1.8.4 server folder (official, or our mac release's): this build joining it in its protocol and chatting
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
# Every process this script starts writes its PID to a *.pid file in $WORK; only those are ever stopped (other runs and
# a game's own server share the machine)
stop_started() {
    local pidfile
    for pidfile in "$WORK"/**/*.pid(N); do
        kill -9 "$(<"$pidfile")" 2>/dev/null
        rm -f "$pidfile"
    done
    sleep 1
}
trap 'stop_started; rm -rf "$WORK"' EXIT
FAILED=0
# A server left running would take the port: say so rather than stop someone else's
if lsof -nP -iUDP:10578 > /dev/null 2>&1; then
    echo "FAIL UDP port 10578 is in use by another process (lsof -iUDP:10578)" >&2
    exit 1
fi

# start_player <folder for its log and pid> <name> <role> [endpoint]: FakePlayers in the background
start_player() {
    (cd "$PLAYERS_DIR" && exec "$WINE" FakePlayers.exe "$3" "${4:-127.0.0.1:10578}" > "$1/$2.raw" 2>/dev/null) &
    print -r -- $! > "$1/$2.pid"
}

# run_player <folder> <name> <role> [endpoint]: FakePlayers in the foreground, its log in <folder>/<name>.log
run_player() {
    (cd "$PLAYERS_DIR" && "$WINE" FakePlayers.exe "$3" "${4:-127.0.0.1:10578}" 2>/dev/null) | tr -d '\r' > "$1/$2.log"
}

# wait_player <folder> <name>: waits up to 30 s for a background player to exit, then makes its log
wait_player() {
    local pid=$(<"$1/$2.pid")
    for _ in {1..30}; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
    kill -9 "$pid" 2>/dev/null
    rm -f "$1/$2.pid"
    tr -d '\r' < "$1/$2.raw" > "$1/$2.log"
}

# start_server <server folder> <ini text> <name> [required mods]: a server from a copy of the folder; prints its folder
start_server() {
    local dir="$WORK/server-$3"
    mkdir -p "$dir/config"
    cp "$1"/SkyrimTogetherServer.exe "$1"/STServer.dll "$dir"/ || exit 1
    print -r -- "$2" > "$dir/config/STServer.ini"
    [[ -n "${4:-}" ]] && print -r -- "$4" > "$dir/config/required-mods.txt" && print -r -- $'NiceToHave.esp\nSomeMod.esp' > "$dir/config/recommended-mods.txt"

    (cd "$dir" && exec "$WINE" SkyrimTogetherServer.exe < /dev/null > "$dir/server.log" 2>&1) &
    print -r -- $! > "$dir/server.pid"
    for _ in {1..30}; do grep -aq "started on port" "$dir/server.log" && break; sleep 1; done
    grep -aq "started on port" "$dir/server.log" || { echo "FAIL the server in $1 didn't start" >&2; return 1; }
    print -r -- "$dir"
}

# report <log>...: prints the checks, and records a failure
report() {
    grep -h "PASS\|FAIL" "$@"
    grep -qh "FAIL" "$@" && FAILED=1
    grep -q "ALL CHECKS PASSED" "${@[-1]}" || FAILED=1
    stop_started
}

# run_pair <server folder> <ini text> <first role> <second role>: the first role in the background, then the second
run_pair() {
    local dir
    dir=$(start_server "$1" "$2" "$3") || { FAILED=1; return; }

    start_player "$dir" first "$3"
    sleep 5
    run_player "$dir" second "$4"
    wait_player "$dir" first
    report "$dir/first.log" "$dir/second.log"
}

echo "== Plus server: host world and local network discovery"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\n[Gameplay]\nbHostWorld=true' host join

echo "== Plus server: the host kicks a player from the player list"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' kicker kicked

echo "== Plus server: the host's mods required"
if dir=$(start_server "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[ModPolicy]\nbRequireMods=true' mods $'SomeMod.esp\nccBGSSSE001-Fish.esm'); then
    run_player "$dir" mods mods
    report "$dir/mods.log"
else
    FAILED=1
fi

echo "== Plus server: another version of a required mod"
if dir=$(start_server "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[ModPolicy]\nbRequireMods=true' modversions $'Sized.esp|12345\nPlain.esp\nccBGSSSE001-Fish.esm'); then
    (cd "$PLAYERS_DIR" && "$WINE" FakePlayers.exe modversions 127.0.0.1:10578 2>/dev/null | tr -d '\r' > "$dir/modversions.log")
    report "$dir/modversions.log"
else
    FAILED=1
fi

echo "== Plus server: only the host's chosen kinds of quest are shared"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[Gameplay]\nsSharedQuestTypes=Main,Misc' questleader questmember

echo "== Plus server: party members follow the leader's fast travel"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' travelleader travelmember

echo "== Plus server: quest progress drifting from the leader's is reported"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' desyncleader desyncmember

echo "== Plus server: a player whose game crashed comes back to their party and place"
if dir=$(start_server "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[Gameplay]\nbAutoPartyJoin=false' lost); then
    start_player "$dir" leader lostleader
    sleep 3
    start_player "$dir" member lostmember
    wait_player "$dir" leader
    # The server times the "crashed" leader out after 10 s
    sleep 15
    run_player "$dir" return lostreturn
    wait_player "$dir" member
    report "$dir/leader.log" "$dir/member.log" "$dir/return.log"
else
    FAILED=1
fi

echo "== Plus server whose router can't be opened: host world through the relay (SkyrimTogetherRelay)"
mkdir -p "$WORK/relay"
(cd "$PLAYERS_DIR" && exec "$WINE" SkyrimTogetherRelay.exe > "$WORK/relay/relay.log" 2>&1) &
print -r -- $! > "$WORK/relay/relay.pid"
sleep 2
if dir=$(start_server "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nsRelay=127.0.0.1:10600\n[Gameplay]\nbHostWorld=true' relay); then
    # The relay's first port goes to the only host
    start_player "$dir" first host 127.0.0.1:10601
    sleep 5
    run_player "$dir" second join 127.0.0.1:10601
    wait_player "$dir" first
    grep -aq "Public address: 127.0.0.1:10601 (through the relay)" "$dir/server.log" && echo "PASS the server's invite address is the relay's port" ||
        { echo "FAIL the server didn't get a port from the relay"; FAILED=1; }
    report "$dir/first.log" "$dir/second.log"
else
    FAILED=1
fi

echo "== Plus server: a player with another Plus release"
if dir=$(start_server "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' version); then
    run_player "$dir" version oldversion
    grep -aq "\[Host\] FakeOldBuild couldn't join: they have Skyrim Together v1.8.4-plus.0" "$dir/server.log" &&
        echo "PASS the host is told which version the player had" || { echo "FAIL the host isn't told the player's version"; FAILED=1; }
    report "$dir/version.log"
else
    FAILED=1
fi

echo "== Plus server: a required mod with the same size and other contents"
if dir=$(start_server "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[ModPolicy]\nbRequireMods=true' checksums $'Exact.esp|100|0000abcd\nccBGSSSE001-Fish.esm'); then
    run_player "$dir" checksums modchecksums
    report "$dir/checksums.log"
else
    FAILED=1
fi

echo "== Plus server: the party bar's magicka, stamina, combat and downed"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' barleader barmember

echo "== Plus server: pings reach the party"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' pingleader pingmember

echo "== Plus server: the party is asked to follow the leader through a load door"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' doorleader doorfollower

echo "== Plus server: any member's load door, when the host allows it"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[Gameplay]\nbPartyDoorsAnyMember=true' doorleaderany doorfollower

echo "== Plus server: go to and summon party members, with a cooldown"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[Gameplay]\nuPartyTeleportCooldown=5' moveleader movemember

echo "== Plus server: respawning next to a party member"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' respawnleader respawnmember

echo "== Plus server: a vote kick and a ready check"
# Players at this computer's network address aren't the host, who plays at 127.0.0.1
LAN_ADDRESS=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
if [[ -z "$LAN_ADDRESS" ]]; then
    echo "FAIL no network address for the players who aren't the host"
    FAILED=1
elif dir=$(start_server "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' votes); then
    start_player "$dir" host votehost
    sleep 3
    start_player "$dir" target votetarget "$LAN_ADDRESS:10578"
    sleep 3
    run_player "$dir" voter votevoter "$LAN_ADDRESS:10578"
    wait_player "$dir" target
    wait_player "$dir" host
    report "$dir/host.log" "$dir/target.log" "$dir/voter.log"
else
    FAILED=1
fi

echo "== Plus host world server: the world it keeps survives a restart"
WORLD_INI=$'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[Gameplay]\nbHostWorld=true\nuKeepWorldSeconds=2\nsKeepWorldName=FakeParty'
if dir=$(start_server "$PLUS_SERVER" "$WORLD_INI" world); then
    run_player "$dir" store worldstore
    # Stopped the hard way: the periodic save has to be enough
    stop_started
    if [[ -f "$dir/world/FakeParty.dat" ]] && start_server "$PLUS_SERVER" "$WORLD_INI" world > /dev/null; then
        run_player "$dir" load worldload
        report "$dir/store.log" "$dir/load.log"
    else
        echo "FAIL no world/FakeParty.dat after the first run, or the server didn't start again"
        FAILED=1
    fi
else
    FAILED=1
fi

echo "== Plus server: far NPCs' movement relayed less often"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' crowdowner crowdwatcher

echo "== Plus server: a player entering a cell sees doors as the others left them"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' doorfirst doorlater

echo "== Plus server: two players taking the same container item, the later gives it back"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' lootfirst lootsecond

echo "== Plus server: the party leader's quest sharing, and a quest offered to the party"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[Gameplay]\nsSharedQuestTypes=Main' shareleader sharemember

echo "== Plus server: a player joining mid-quest is offered the leader's progress"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' catchupleader catchupmember

echo "== Plus server: two players looting the same body at once"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' corpseowner corpselooter

echo "== Plus server: each player loots their own copy of a container"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false\n[Gameplay]\nbPerPlayerLoot=true' ownlootfirst ownlootsecond

echo "== Plus server: a guard deals with the player whose bounty it is, from that player's game"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' crimeleader crimemember

echo "== Plus server: a downed party member is revived by a partner, and dies once the whole party is down"
run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' reviveleader revivemember

# With SOAK_SECONDS set: two players stay connected and chat for that long (FakePlayers soak)
if [[ -n "${SOAK_SECONDS:-}" ]]; then
    echo "== Plus server: soak for $SOAK_SECONDS seconds"
    export WINEDEBUG SOAK_SECONDS
    run_pair "$PLUS_SERVER" $'[GameServer]\nsPassword=\nbUPnP=false\nbLanDiscovery=false' soak soak
fi

if [[ -n "$OFFICIAL_SERVER" ]]; then
    echo "== Official v1.8.4 server: joining in its protocol"
    run_pair "$OFFICIAL_SERVER" $'[GameServer]\nsPassword=' listen184 talk184
fi

exit $FAILED
