#!/bin/bash
# Builds fxc.exe (Windows x64) with the Mac cross toolchain; d3dcompiler_47.dll (Microsoft redistributable, the copy
# Skyrim Together ships) sits next to it so Wine loads Microsoft's compiler, not Wine's own.
set -e
. "$HOME/Developer/xwin/env.sh"
cd "$(dirname "$0")"
clang-cl -c --target=x86_64-pc-windows-msvc /winsysroot "$WINSYSROOT" -O2 -MT -W3 fxc.c -Fofxc.obj
lld-link /winsysroot:"$WINSYSROOT" /machine:x64 /subsystem:console /out:fxc.exe fxc.obj d3dcompiler.lib
cp -n "$HOME/Games/skyrim-together-1.8.4/files/SkyrimTogetherReborn/d3dcompiler_47.dll" . 2>/dev/null || true
