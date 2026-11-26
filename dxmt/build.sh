#!/bin/bash
# Build jdrly's DXMT fork (gw2-on-mac) with our patches on this Mac:
#   dxmt/build.sh <dxmt source checkout> <output folder>
# The checkout is jdrly/dxmt at da80816 with 0001-*.patch applied (git am) and submodules checked out. The output
# folder gets x86_64-windows/*.dll and x86_64-unix/winemetal.so, ready for dxmt/install.sh. Toolchains, as the
# fork's CI uses them, go to ~/Games/dxmt-builds/toolchains once (about 1 GB kept; LLVM's 2 GB of sources and build
# tree are deleted after it installs): LLVM 15.0.7 static libraries for x86_64, 3Shain's Wine 8.16 build (winebuild
# and import libraries), meson 1.10.0. Also needed: mingw-w64 (brew) and Xcode's Metal Toolchain
# (xcodebuild -downloadComponent MetalToolchain).
set -eu
SRC=$(cd "${1:?usage: build.sh <dxmt checkout> <output folder>}" && pwd)
OUT=${2:?usage: build.sh <dxmt checkout> <output folder>}
T="$HOME/Games/dxmt-builds/toolchains"
mkdir -p "$T"
command -v x86_64-w64-mingw32-gcc >/dev/null || { echo "FAIL no mingw-w64 (brew install mingw-w64)"; exit 1; }
xcrun metal --version >/dev/null 2>&1 || { echo "FAIL no Metal Toolchain (xcodebuild -downloadComponent MetalToolchain)"; exit 1; }

if [ ! -f "$T/llvm-darwin/lib/libLLVMCore.a" ]; then
  echo "building LLVM 15.0.7 for x86_64 (about 15 minutes; log: $T/llvm-build.log)"
  [ -d "$T/llvm-project" ] || git clone -q --depth 1 --branch llvmorg-15.0.7 https://github.com/llvm/llvm-project.git "$T/llvm-project"
  { cmake -B "$T/llvm-darwin-build" -S "$T/llvm-project/llvm" -DCMAKE_INSTALL_PREFIX="$T/llvm-darwin" \
      -DCMAKE_OSX_ARCHITECTURES=x86_64 -DLLVM_HOST_TRIPLE=x86_64-apple-darwin -DLLVM_ENABLE_ASSERTIONS=On \
      -DLLVM_ENABLE_ZSTD=Off -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-D_LIBCPP_KEEP_TRANSITIVE_INCLUDES_LLVM23" \
      -DLLVM_TARGETS_TO_BUILD="" -DLLVM_BUILD_TOOLS=Off -DLLVM_INCLUDE_BENCHMARKS=Off -DLLVM_INCLUDE_TESTS=Off \
      -DLLVM_INCLUDE_EXAMPLES=Off -DLLVM_VERSION_PRINTER_SHOW_HOST_TARGET_INFO=Off -G Ninja \
    && cmake --build "$T/llvm-darwin-build" && cmake --install "$T/llvm-darwin-build"; } > "$T/llvm-build.log" 2>&1 \
    || { echo "FAIL LLVM build (see $T/llvm-build.log)"; exit 1; }
  rm -rf "$T/llvm-project" "$T/llvm-darwin-build"
fi
if [ ! -x "$T/wine/bin/winebuild" ]; then
  mkdir -p "$T/wine"
  curl -sSLf https://github.com/3Shain/wine/releases/download/v8.16-3shain/wine.tar.gz | tar -xz -C "$T/wine"
fi
[ -x "$T/meson-venv/bin/meson" ] || { python3 -m venv "$T/meson-venv" && "$T/meson-venv/bin/pip" -q install meson==1.10.0; }

export PATH="$T/meson-venv/bin:$PATH"
cd "$SRC"
[ -d build ] || meson setup --cross-file build-win64.txt -Dnative_llvm_path="$T/llvm-darwin" -Dwine_install_path="$T/wine" \
  build --buildtype release --prefix "$SRC/install" --strip > "$T/meson-setup.log" 2>&1 \
  || { echo "FAIL meson setup (see $T/meson-setup.log)"; exit 1; }
{ meson compile -C build && meson install -C build; } > "$T/meson-build.log" 2>&1 \
  || { echo "FAIL build (see $T/meson-build.log)"; exit 1; }
mkdir -p "$OUT/x86_64-windows" "$OUT/x86_64-unix"
cp install/x86_64-windows/*.dll "$OUT/x86_64-windows/" && cp install/x86_64-unix/winemetal.so "$OUT/x86_64-unix/"
echo "built $(/usr/bin/grep -a -o -m1 'v0\.[0-9]*-[0-9]*-g[0-9a-f]*' "$OUT/x86_64-windows/d3d11.dll" | /usr/bin/head -1) into $OUT"
