#!/bin/bash
# Mac stand-in for DirectXTK's Src/Shaders/CompileShaders.cmd (CMake runs it by name from Src/Shaders): reads the
# shader list from the real .cmd next to it and compiles each entry with ~/Developer/xwin/fxc/fxc.exe in Wine, with
# the same profiles and options. Output: <newest build dir>/Shaders/Compiled (CMake's COMPILED_SHADERS; the
# "set CompileShadersOutput=..." before this command does not reach us through /bin/sh).
set -u
export PATH="$PATH:/usr/bin:/bin"   # xmake sub-builds can run tools with a PATH lacking the system folders
[ -f CompileShaders.cmd ] || { echo "CompileShaders.cmd: not in DirectXTK's Src/Shaders" >&2; exit 1; }
build=$(/bin/ls -td ../../build_*/ 2>/dev/null | head -1)
[ -n "$build" ] || { echo "CompileShaders.cmd: no CMake build folder next to Src" >&2; exit 1; }
out="${build}Shaders/Compiled"
mkdir -p "$out" || exit 1
export WINEPREFIX="$HOME/Developer/xwin/wineprefix" WINEDEBUG=-all DYLD_FALLBACK_LIBRARY_PATH="$HOME/Games/skyrim/wine/lib:/usr/lib"
WINE="$HOME/Games/skyrim/wine/bin/wine"; FXC="$HOME/Developer/xwin/fxc/fxc.exe"
OPTS=(/nologo /WX /Ges /Zi /Zpc /Qstrip_reflect /Qstrip_debug)

# "call :CompileShader<kind>%1 <file> <type> <entry>" → "<kind or -> <file> <type> <entry>"
list=$(tr -d '\r' < CompileShaders.cmd | awk '/^call :CompileShader(SM4|HLSL)?%1 /{
  k = $2; sub(/^:CompileShader/, "", k); sub(/%1$/, "", k); if (k == "") k = "-"; print k, $3, $4, $5 }')

fail=0; n=0
while read -r kind file type entry; do
  case "$kind" in
    SM4)  src="$file.fx";   prof="${type}_4_0" ;;
    HLSL) src="$file.hlsl"; prof="${type}_4_0_level_9_1" ;;
    *)    src="$file.fx";   prof="${type}_4_0_level_9_1" ;;
  esac
  "$WINE" "$FXC" "$src" "${OPTS[@]}" "/T$prof" "/E$entry" "/Fh$out/${file}_$entry.inc" "/Vn${file}_$entry" \
    </dev/null >/dev/null || { echo "fxc failed: $src $entry ($prof)" >&2; fail=1; }
  n=$((n + 1))
done <<< "$list"

if [ "$fail" = 0 ]; then echo "Shaders compiled ok ($n in $out)"; else echo "There were shader compilation errors!"; exit 1; fi
