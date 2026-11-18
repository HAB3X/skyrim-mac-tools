#!/bin/bash
# Sets up the Windows x64 cross-build toolchain on macOS (Apple Silicon) used to build Skyrim Together Reborn:
# LLVM clang-cl/lld-link + Microsoft's CRT and Windows SDK (xwin, Visual Studio folder layout) + xmake with its
# host checks widened to macOS. Installs into ~/Developer/xwin and ~/Developer/xmake-mac-cross.
#
# xwin downloads Microsoft's CRT and SDK; running this means accepting Microsoft's licence for them (--accept-license).
# protoc and CompileShaders.cmd run Windows tools through Wine: set WINE_ROOT to a Wine 10 runtime (default: SkyrimMT's).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
X="$HOME/Developer/xwin"
mkdir -p "$X/bin"

brew install xmake llvm lld xwin pnpm

# Microsoft CRT + SDK in Visual Studio layout; xmake looks for x64 folders, xwin names them x86_64
if [ ! -d "$X/winsysroot/VC" ]; then
  xwin --accept-license --arch x86_64 --cache-dir "$X/cache" splat --use-winsysroot-style --include-debug-libs --output "$X/winsysroot"
  rm -rf "$X/cache"
fi
for d in "$X/winsysroot/VC/Tools/MSVC/"*/lib "$X/winsysroot/Windows Kits/10/Lib/"*/ucrt "$X/winsysroot/Windows Kits/10/Lib/"*/um; do
  ln -sfn x86_64 "$d/x64"
done
cp "$HERE/sdk-extras/winres.h" "$(ls -d "$X/winsysroot/Windows Kits/10/Include/"*/um | tail -1)/winres.h"

# wrappers, under the names xmake, CMake and the projects call
cp "$HERE/env.sh" "$X/env.sh"
for f in clang-cl link rc protoc CompileShaders.cmd; do cp "$HERE/bin/$f" "$X/bin/$f"; chmod +x "$X/bin/$f"; done
for n in clang-cl.exe cl cl.exe; do ln -sf clang-cl "$X/bin/$n"; done
for n in link.exe lib lib.exe; do ln -sf link "$X/bin/$n"; done
for n in rc.exe llvm-rc; do ln -sf rc "$X/bin/$n"; done
L=/opt/homebrew/opt/llvm/bin
for p in llvm-lib llvm-mt llvm-ml llvm-ar llvm-nm llvm-objcopy llvm-dlltool; do ln -sf "$L/$p" "$X/bin/$p.exe"; done
ln -sf "$L/llvm-mt" "$X/bin/mt"; ln -sf "$L/llvm-mt" "$X/bin/mt.exe"; ln -sf "$L/llvm-ml" "$X/bin/ml64"; ln -sf "$L/llvm-ml" "$X/bin/ml64.exe"
ln -sf /opt/homebrew/opt/lld/bin/lld-link "$X/bin/lld-link.exe"

# fxc stand-in and the small runtime library the link wrapper adds
mkdir -p "$X/fxc" "$X/compat"
cp "$HERE/fxc/fxc.c" "$HERE/fxc/build.sh" "$X/fxc/"; cp "$HERE/compat/compat.c" "$HERE/compat/build.sh" "$X/compat/"
bash "$X/compat/build.sh"
echo "fxc: put Microsoft's d3dcompiler_47.dll (redistributable; Skyrim Together ships it) in $X/fxc, then run $X/fxc/build.sh"

# xmake: a copy of its scripts with the clang-cl/msvc host checks allowing macOS
XM="$HOME/Developer/xmake-mac-cross"
rm -rf "$XM"; cp -R "$(brew --prefix xmake)/share/xmake" "$XM"
(cd "$XM" && patch -p1 < "$HERE/xmake-patches/xmake-host-check.patch")
echo "xmake-repo recipes: after the first 'xmake f', apply xmake-patches/xmake-repo-packages.patch in ~/.xmake/repositories/xmake-repo"
echo "done: . $X/env.sh"
