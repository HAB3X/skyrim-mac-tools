#!/bin/bash
# scenario.sh: present-loop.exe for 26 s with "drop" (Wine loses its foreground window at 8 s). The test window is
# made the frontmost app at 5 s and 17 s (System Events, as the launcher's bring_to_front), the app that was
# frontmost gets it back at 13 s and 23 s. Prints DXMT's throttle transitions and its 2-second fps.
# Takes the keyboard away from the frontmost app for 12 of the 26 seconds. DXMT_BUILD: as in run.sh.
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${DXMT_TEST_DIR:-$HOME/Games/dxmt-builds/focus-test}
"$HERE/run.sh" 1 > /dev/null 2>&1   # sets up the copy, the prefix and the helpers (and installs DXMT_BUILD)
cd "$WORK" || exit 1
prev=$(./activate front)
DXMT_BUILD= "$HERE/run.sh" 26 drop > /dev/null 2>&1 &
t0=$(date +%s)
front() { /usr/bin/osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $1) to true"; }
# retried: a just-started Wine process takes a moment to appear in System Events
step() { sleep $(( $1 - ($(date +%s) - t0) )); for _ in 1 2 3 4; do front "$2" 2>/dev/null && break; sleep 0.4; done
         echo "t=$1 frontmost $(./activate front)"; }
sleep 3; pid=$(pgrep -f 'present-loop.exe' | head -1)
step 5 "$pid"; step 13 "$prev"; step 17 "$pid"; step 23 "$prev"
wait
grep -E 'Present: (.*throttl|.*normally|the window)' logs/present-loop_d3d11.log | cut -c8-200
grep -o 'STATS fps=[0-9]*' logs/present-loop_d3d11.log | cut -d= -f2 | tr '\n' ' '; echo
