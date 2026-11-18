#!/bin/bash
# Builds compat.lib (Windows x64, static CRT-neutral C) for the Mac cross toolchain.
set -e
. "$HOME/Developer/xwin/env.sh"
cd "$(dirname "$0")"
/opt/homebrew/opt/llvm/bin/clang-cl -c --target=x86_64-pc-windows-msvc /winsysroot "$WINSYSROOT" -O2 -Zl -mxsave compat.c -Focompat.obj
/opt/homebrew/opt/llvm/bin/llvm-lib -out:compat.lib compat.obj
