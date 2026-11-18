# skyrim-mac-tools

Tools for playing Skyrim Special Edition and Skyrim Together Reborn on an Apple Silicon Mac, and for building
Skyrim Together's Windows binaries on macOS. The Mac build of Skyrim Together itself is the `mac` branch of
[HAB3X/TiltedEvolution](https://github.com/HAB3X/TiltedEvolution/tree/mac).

## launch/

Launchers for the GOG version of Skyrim SE (1.6.1179) in a [SkyrimMT](https://github.com/HorrorPills/skyrimmt) Wine
prefix (`~/Games/skyrim`).

- `skyrim-play.sh` starts Skyrim at the Mac's current screen size (borderless window), `skyrim-play.sh together`
  starts Skyrim Together instead.
- `skyrim-host.sh` hosts co-op in one click: starts the server in the background (or reuses it), sets a password,
  shows the internet and Wi-Fi addresses and the password, copies them to the clipboard, then starts Skyrim Together.
  `skyrim-host.sh stop` stops the server, `password` picks a new password.
- `skyrim-together.sh` installs the Skyrim Together build that matches the installed game version into `Data`,
  enables its plugins and starts it. `skyrim-together.sh server` runs a server (UDP 10578), `check` reports what is
  missing.
- Both run Wine with msync, switch SSE Engine Fixes' memory manager off for Skyrim Together (it replaces the game's
  allocator itself) and on for plain Skyrim, and set DXMT's options (pipeline warming, hitch log, Metal-paced 60 fps).

Paths are the ones used on the original machine (`~/Games/...`); adjust the variables at the top of each script.

## cross-build/

Cross-compiles Windows x64 code on macOS with LLVM `clang-cl`/`lld-link`, Microsoft's CRT and Windows SDK from
[xwin](https://github.com/Jake-Shadle/xwin), and xmake. `setup.sh` installs everything; then `. ~/Developer/xwin/env.sh`.

| File | Why |
|---|---|
| `bin/clang-cl` | Absolute Mac paths like `/Users/...` parse as the `/U` option: source files go after `--`. Real compiles get `-FIintrin.h` (MSVC's `windows.h` makes `__movsb` an intrinsic) and `-EHsc` for C++ (CMake's MSVC default). |
| `bin/link` | `lld-link`, or `llvm-lib` in library mode (`-lib` or an `/out:*.lib`, as CMake's archiver), with response files expanded and MSVC-only linker options dropped. `/WHOLEARCHIVE:<name>` is resolved on the library paths; `/LAST:` becomes a `/sectionlayout` that puts `.game` first (CitizenFX-style loaders). Adds `compat.lib` and `advapi32`. |
| `bin/rc` | `llvm-rc` with options in `-` form and the SDK include folders added. |
| `bin/protoc` | The Windows `protoc.exe` that xmake built with protobuf, run through Wine (same version as the library). |
| `bin/CompileShaders.cmd` | DirectXTK's shader script, compiled with `fxc/` through Wine. |
| `fxc/` | An `fxc.exe` stand-in on Microsoft's `d3dcompiler_47.dll`, writing `/Fh` headers in fxc's format. |
| `compat/` | `__udivti3`/`__umodti3` (128-bit division) and Crypto++'s `XGETBV64`/`CPUID64`. |
| `sdk-extras/winres.h` | Visual Studio ships it with ATL/MFC, which xwin doesn't fetch. |
| `xmake-patches/` | xmake's clang-cl/msvc host checks allowing macOS; Crypto++ without assembly on Mac hosts (and its clang-cl hard stop removed), cpp-httplib's host Windows-version check skipped. |

The clang-cl wrapper also marks the `.game` section of `MemoryLayout.cpp` uninitialized after compiling (clang
emits `#pragma bss_seg` sections as 1 GB of zeros).

## forks/

`combine-until-builds.sh` applies a list of fork commits onto a base branch, builds, and on a compile error skips the
fork commit that wrote the failing line, until the build succeeds.
