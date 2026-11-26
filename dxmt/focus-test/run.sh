#!/bin/bash
# run.sh <seconds> [activate|drop]: present-loop.exe in a test Wine prefix and a copy of the game's Wine (APFS clone),
# never the game's own, so the game and its server are untouched. DXMT_BUILD=<folder> first copies that build
# (x86_64-windows/*.dll, x86_64-unix/winemetal.so) into the copy. The DXMT log goes to $WORK/logs.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${DXMT_TEST_DIR:-$HOME/Games/dxmt-builds/focus-test}
mkdir -p "$WORK/logs"
cd "$WORK" || exit 1
export WINEPREFIX="$WORK/prefix" DYLD_FALLBACK_LIBRARY_PATH="$WORK/wine/lib:/usr/lib" WINEDEBUG=-all WINEMSYNC=1
export WINEDLLOVERRIDES="mscoree,mshtml=" DXMT_LOG_PATH="Z:$WORK/logs"
[ -d wine ] || /bin/cp -cR "$HOME/Games/skyrim/wine" wine || exit 1
[ -d prefix ] || ./wine/bin/wine wineboot -i >/dev/null 2>&1
if [ -n "${DXMT_BUILD:-}" ]; then
  /bin/cp "$DXMT_BUILD"/x86_64-windows/*.dll wine/lib/wine/x86_64-windows/ \
    && /bin/cp "$DXMT_BUILD"/x86_64-unix/winemetal.so wine/lib/wine/x86_64-unix/ || exit 1
fi
[ present-loop.exe -nt "$HERE/present-loop.c" ] || x86_64-w64-mingw32-gcc -O2 "$HERE/present-loop.c" -o present-loop.exe \
  -ld3d11 -ldxgi -luser32 -lgdi32 -luuid || exit 1
[ activate -nt "$HERE/activate.swift" ] || swiftc -O "$HERE/activate.swift" -o activate || exit 1
rm -f logs/present-loop_d3d11.log
./wine/bin/wine present-loop.exe "$@"
