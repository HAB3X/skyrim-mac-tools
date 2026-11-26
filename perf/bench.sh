#!/bin/bash
# Repeatable frame-time benchmark: start the game, load the newest save ("Continue"), play a fixed route of input
# (stand, turn on the spot, run forward while turning), stop the game, and print frametimes.sh's summary of each part.
#   bench.sh [together|plain] [label]     extra DXMT_/WINE env set by the caller passes through to the game
# Waits for /tmp/skyrim-game.lock (one game run at a time) and for no game to be running, then holds the lock. Saves are never
# written: the INIs are backed up, autosaves are turned off for the run, and both are put back afterwards; the Saves
# folder is compared before and after. Output: one summary line per part, and the run's logs in $BENCH_OUT.
set -u
mode=${1:-together}; label=${2:-run}
HERE=$(cd "$(dirname "$0")" && pwd)
SKYRIM_HOME="$HOME/Games/skyrim"; LOGS="$SKYRIM_HOME/logs"; DXLOG="$LOGS/SkyrimSE_d3d11.log"
BENCH_OUT=${BENCH_OUT:-$HOME/Games/skyrim/logs/bench}/$(date +%Y%m%d-%H%M%S)-$mode-$label
eval "$(/bin/bash "$HOME/Games/skyrim-together.sh" paths)"
SKSELOG="$MY_GAMES/SKSE/skse64.log"
export WINEPREFIX="$SKYRIM_HOME/prefix" DYLD_FALLBACK_LIBRARY_PATH="$SKYRIM_HOME/wine/lib:/usr/lib" WINEDEBUG=-all WINEMSYNC=1
WINE="$SKYRIM_HOME/wine/bin/wine"
INPUT="$SKYRIM_HOME/tools/game-input.exe"; FIX_INPUT="$SKYRIM_HOME/tools/fix-input.exe"
fail() { echo "FAIL $*"; exit 1; }
# The game's own process: Wine sets its argv to the Windows command line (SkyrimSE.exe, or SkyrimTogether.exe --exePath ...)
GAME_PROC='^([A-Z]:.*\\SkyrimSE\.exe|SkyrimTogether\.exe --exePath)'
game_running() { /usr/bin/pgrep -f "$GAME_PROC" >/dev/null; }
game_gone() { ! game_running; }
[ -f "$INPUT" ] || fail "$INPUT missing: x86_64-w64-mingw32-gcc -O2 -s perf/game-input.c -o $INPUT -luser32"
# One game run at a time; a game running without the lock is the owner playing: wait for both
for ((;;)); do
  until mkdir /tmp/skyrim-game.lock 2>/dev/null; do sleep 10; done
  game_running || break
  rmdir /tmp/skyrim-game.lock; sleep 30
done
mkdir -p "$BENCH_OUT"

saves_state() { /bin/ls -lT "$MY_GAMES/Saves"; }
restore() {
  if [ -n "${launched:-}" ] && game_running; then /usr/bin/pkill -f "$GAME_PROC"; sleep 5; fi   # our run only
  for f in SkyrimPrefs.ini Skyrim.INI; do [ -f "$BENCH_OUT/$f.orig" ] && /bin/cp -p "$BENCH_OUT/$f.orig" "$MY_GAMES/$f"; done
  saves_state > "$BENCH_OUT/saves.after"
  /usr/bin/cmp -s "$BENCH_OUT/saves.before" "$BENCH_OUT/saves.after" || echo "WARN the Saves folder changed during the run (see $BENCH_OUT/saves.*)"
  rmdir /tmp/skyrim-game.lock
}
trap restore EXIT
saves_state > "$BENCH_OUT/saves.before"
for f in SkyrimPrefs.ini Skyrim.INI; do /bin/cp -p "$MY_GAMES/$f" "$BENCH_OUT/$f.orig" || fail "backup $f"; done
# No autosaves during the run (the launcher keeps every other setting as the owner has it)
P="$MY_GAMES/SkyrimPrefs.ini"
for k in bSaveOnTravel bSaveOnWait bSaveOnRest bSaveOnCharacterMenu; do
  if /usr/bin/grep -q "^$k=" "$P"; then /usr/bin/sed -i '' "s/^$k=.*/$k=0/" "$P"
  else /usr/bin/sed -i '' "s/^\[MAIN\]/[MAIN]\\
$k=0/" "$P"; fi
done
/usr/bin/sed -i '' 's/^fAutosaveEveryXMins=.*/fAutosaveEveryXMins=9999.0000/' "$P"

export DXMT_HITCH_MS=${DXMT_HITCH_MS:-20}   # every frame that missed a 120 Hz vblank (late at 60 fps) gets a HITCH line
skse_mark() { /usr/bin/grep -q "dispatch message ($1)" "$SKSELOG" 2>/dev/null; }   # 8: main menu ready, 3: save loaded
wait_for() {   # wait_for <seconds> <command...>: poll once a second until the command succeeds
  local t=$1; shift
  for ((i = 0; i < t; i++)); do "$@" && return 0; sleep 1; done; return 1
}
fresh_log() { [ "$DXLOG" -nt "$BENCH_OUT/saves.before" ] && [ "$SKSELOG" -nt "$BENCH_OUT/saves.before" ]; }
loaded() { fresh_log && skse_mark 3; }
menu() { fresh_log && skse_mark 8; }
# The game takes input only while it is the active Mac app and its window is Wine's foreground window
input() {
  /usr/bin/osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $(/usr/bin/pgrep -f "$GAME_PROC" | /usr/bin/head -1)) to true" >/dev/null 2>&1
  "$WINE" "$FIX_INPUT" >/dev/null 2>&1; "$WINE" "$INPUT" "$@"
}
# shot <name>: the game window only, into $BENCH_OUT (with perf/build/winid: swiftc -O perf/winid.swift -o perf/build/winid)
shot() {
  local id; id=$("$HERE/build/winid" "$(/usr/bin/pgrep -f "$GAME_PROC" | /usr/bin/head -1)" 2>/dev/null) || return 0
  /usr/sbin/screencapture -x -o -l "$id" "$BENCH_OUT/$1.png"
}

launched=1
case $mode in
  together) /bin/bash "$HOME/Games/skyrim-play.sh" together > "$BENCH_OUT/launch.log" 2>&1 ;;
  plain)    /bin/bash "$HOME/Games/skyrim-play.sh" > "$BENCH_OUT/launch.log" 2>&1 & ;;
  *) fail "mode is together or plain" ;;
esac
wait_for 240 menu || fail "no main menu in 4 minutes (launch log: $BENCH_OUT/launch.log)"
# Continue = the newest save (unless something already loads it): the main menu opens with Continue highlighted, so
# Enter alone; an arrow key first would move to New
for try in 1 2 3; do
  wait_for 15 loaded && break
  shot "menu-$try"
  input tap:0x1C
  sleep 1; shot "menu-$try-after"
done
wait_for 60 loaded || { shot no-load; fail "the save did not load"; }
sleep 15   # the load screen's fade and the first streaming
part() {   # part <name> <input steps...>: run the steps and summarise the frames they covered
  local name=$1 from; shift
  from=$(( $(/usr/bin/wc -l < "$DXLOG") + 1 )); first=${first:-$from}
  input "$@"
  sleep 2   # one more STATS interval
  echo "$name $(/bin/bash "$HERE/frametimes.sh" "$DXLOG" "$from") load=$(/usr/sbin/sysctl -n vm.loadavg | /usr/bin/cut -d' ' -f2)" | tee -a "$BENCH_OUT/summary.txt"
}
part stand wait:30000
part turn turn:8000:15000 turn:-8000:15000
part run down:0x11 turn:2000:20000 turn:-4000:20000 turn:2000:20000 wait:30000 up:0x11
echo "all $(/bin/bash "$HERE/frametimes.sh" "$DXLOG" "$first")" | tee -a "$BENCH_OUT/summary.txt"
# Quit: stop the game (nothing is saved; the console's qqq didn't reach the console through SendInput)
/usr/bin/pkill -f "$GAME_PROC"; wait_for 30 game_gone || echo "WARN the game did not stop"
/bin/cp "$DXLOG" "$BENCH_OUT/"
echo "logs: $BENCH_OUT"
