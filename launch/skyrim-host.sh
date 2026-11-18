#!/bin/bash
# One-click co-op host (~/Desktop/Host Co-op.app): starts the Skyrim Together server in the background (or reuses the
# one already running), shows the address and password to give the other player and copies them to the clipboard,
# then starts Skyrim Together.
#   skyrim-host.sh            host and play
#   skyrim-host.sh stop       stop the server
#   skyrim-host.sh password   choose a new password (applies at the next server start)
set -u
SKYRIM_HOME="$HOME/Games/skyrim"
SERVER_DIR=$(/bin/ls -d "$HOME"/Games/skyrim-together-*-mac/files/SkyrimTogetherReborn 2>/dev/null | /usr/bin/head -1)
INI="$SERVER_DIR/config/STServer.ini"
PWFILE="$SKYRIM_HOME/config/server-password"
LOG="$SKYRIM_HOME/logs/server.log"
PORT=10578
export WINEPREFIX="$SKYRIM_HOME/prefix" WINEMSYNC=1 WINEDEBUG=-all DYLD_FALLBACK_LIBRARY_PATH="$SKYRIM_HOME/wine/lib:/usr/lib"
WINE="$SKYRIM_HOME/wine/bin/wine"

notify() { /usr/bin/osascript -e "display notification \"$1\" with title \"Skyrim co-op\"" >/dev/null 2>&1; }
server_pid() { /usr/bin/pgrep -f "SkyrimTogetherServer.exe" | while read -r p; do
  /bin/ps -o command= -p "$p" | /usr/bin/grep -q '^SkyrimTogetherServer.exe' && echo "$p"; done | /usr/bin/head -1; }

new_password() {   # two words and a number, easy to read out
  local words=(amber birch cedar dawn ember frost glade hearth iron juniper kestrel lantern meadow north oak pine
               quarry raven stone thistle umber vale willow yarrow)
  echo "${words[RANDOM % ${#words[@]}]}-${words[RANDOM % ${#words[@]}]}-$((RANDOM % 90 + 10))" > "$PWFILE"
}

case "${1:-}" in
  stop) p=$(server_pid); [ -n "$p" ] && kill "$p" && echo "server stopped" || echo "no server running"; exit 0 ;;
  password) mkdir -p "$(dirname "$PWFILE")"; new_password; echo "new password: $(cat "$PWFILE") (restart the server)"; exit 0 ;;
esac

[ -f "$INI" ] || { notify "Skyrim Together isn't set up (no server files)"; exit 1; }
mkdir -p "$(dirname "$PWFILE")" "$(dirname "$LOG")"
[ -s "$PWFILE" ] || new_password
PASSWORD=$(cat "$PWFILE")
/usr/bin/sed -i '' -E "s/^sPassword=.*/sPassword=$PASSWORD/; s/^sServerName=.*/sServerName=Skyrim co-op/; s/^uPort=.*/uPort=$PORT/" "$INI"

if [ -z "$(server_pid)" ]; then
  (cd "$SERVER_DIR" && /usr/bin/nohup "$WINE" SkyrimTogetherServer.exe </dev/null > "$LOG" 2>&1 &)
  for _ in $(seq 40); do /usr/bin/grep -aq "started on port" "$LOG" 2>/dev/null && break; sleep 1; done
  /usr/bin/grep -aq "started on port $PORT" "$LOG" || { notify "The server didn't start, see $LOG"; exit 1; }
fi

LOCAL_IP=$(/usr/sbin/ipconfig getifaddr en0 2>/dev/null || /usr/sbin/ipconfig getifaddr en1 2>/dev/null)
PUBLIC_IP=$(/usr/bin/dig +short +time=3 +tries=1 myip.opendns.com @resolver1.opendns.com 2>/dev/null | /usr/bin/tail -1)
printf 'Skyrim co-op\nInternet: %s:%s\nSame Wi-Fi: %s:%s\nPassword: %s\n' "${PUBLIC_IP:-unknown}" "$PORT" "${LOCAL_IP:-unknown}" "$PORT" "$PASSWORD" \
  | /usr/bin/pbcopy
/usr/bin/osascript >/dev/null 2>&1 <<EOF &
display dialog "Server running. Give this to the other player (also copied to the clipboard):

Over the internet:  ${PUBLIC_IP:-unknown}:$PORT
On the same Wi-Fi:  ${LOCAL_IP:-unknown}:$PORT
Password:  $PASSWORD

Over the internet, UDP port $PORT must be forwarded to this Mac on your router." with title "Skyrim co-op" buttons {"OK"} default button "OK"
EOF
exec /bin/bash "$HOME/Games/skyrim-play.sh" together
