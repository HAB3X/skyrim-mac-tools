# Cross-compiling Windows x64 code on this Mac: LLVM clang-cl/lld-link + Microsoft's CRT/SDK (xwin, VS layout),
# driven by xmake from a copy of its scripts that allows a macOS host (toolchains/{clang-cl,msvc}/check.lua).
export PATH="$HOME/Developer/xwin/bin:/opt/homebrew/opt/llvm/bin:/opt/homebrew/opt/lld/bin:$PATH"
export XMAKE_PROGRAM_DIR="$HOME/Developer/xmake-mac-cross"
export WINSYSROOT="$HOME/Developer/xwin/winsysroot"
