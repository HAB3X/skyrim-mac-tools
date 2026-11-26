#!/bin/bash
# Install a DXMT build into the game's Wine: install.sh <build folder> "<description>"
# The folder holds x86_64-windows/{d3d10core,d3d11,dxgi,winemetal}.dll and x86_64-unix/winemetal.so (and optionally
# i386-windows/*.dll). The DLLs it replaces must already be backed up (see ~/Games/dxmt-builds/INSTALLED.txt):
# to go back, run it again with the backup's folder. Refuses while the game runs.
set -u
SRC=${1:?usage: install.sh <build folder> "<description>"}
DESC=${2:?usage: install.sh <build folder> "<description>"}
WINELIB="$HOME/Games/skyrim/wine/lib/wine"
RECORD="$HOME/Games/dxmt-builds/INSTALLED.txt"

/usr/bin/pgrep -f 'SkyrimSE.exe|SkyrimTogether.exe --exePath' >/dev/null && { echo "FAIL the game is running: quit it first"; exit 1; }
[ -f "$SRC/x86_64-windows/d3d11.dll" ] && [ -f "$SRC/x86_64-unix/winemetal.so" ] \
  || { echo "FAIL $SRC has no x86_64-windows/d3d11.dll or x86_64-unix/winemetal.so"; exit 1; }
for f in "$SRC"/x86_64-windows/*.dll "$SRC"/x86_64-unix/winemetal.so "$SRC"/i386-windows/*.dll; do
  [ -f "$f" ] || continue
  dest="$WINELIB/$(basename "$(dirname "$f")")/$(basename "$f")"
  [ -f "$dest" ] || { echo "FAIL $dest isn't there: not a DXMT Wine?"; exit 1; }
  # a new file renamed over the old one: a Wine process still running (the server) keeps the file it mapped
  /bin/cp "$f" "$dest.new" && /bin/mv -f "$dest.new" "$dest" || { echo "FAIL could not install $dest"; exit 1; }
done
echo "$DESC" > "$RECORD"
echo "installed $SRC ($DESC)"
