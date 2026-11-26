# skyrim-mac-tools

Tools for playing Skyrim Special Edition and Skyrim Together Reborn on an Apple Silicon Mac, and for building
Skyrim Together's Windows binaries on macOS. The Mac build of Skyrim Together itself is the `mac` branch of
[HAB3X/TiltedEvolution](https://github.com/HAB3X/TiltedEvolution/tree/mac).

## launch/

Launchers for the GOG version of Skyrim SE (1.6.1179) in a [SkyrimMT](https://github.com/HorrorPills/skyrimmt) Wine
prefix (`~/Games/skyrim`).

- `skyrim-play.sh` starts Skyrim fullscreen at the Mac's current screen size, `skyrim-play.sh together` starts
  Skyrim Together instead. It sets Wine's `CaptureDisplaysForFullscreen` in the prefix: without it Wine keeps the
  borderless window below the menu bar, the bottom 39 points are off screen and menu clicks land 39 points away from
  the drawn cursor (the character menu's Body and Head tabs can't be clicked).
- `skyrim-host.sh` hosts co-op in one click: starts the server in the background (or reuses it), sets a password,
  shows the internet and Wi-Fi addresses and the password, copies them to the clipboard, then starts Skyrim Together.
  `skyrim-host.sh stop` stops the server, `password` picks a new password.
- `ST_VERSION=1.8.4-plus` in front of either launcher uses the
  [Plus build](https://github.com/HAB3X/TiltedEvolution/releases/tag/v1.8.4-plus.1) (folder
  `~/Games/skyrim-together-1.8.4-plus-sse1.6.1170-mac`); the host restarts the server when it was started for the other
  build.
- `skyrim-together.sh` installs the Skyrim Together build that matches the installed game version into `Data`,
  enables its plugins and starts it. `skyrim-together.sh server` runs a server (UDP 10578), `check` reports what is
  missing.
- `collect-logs.sh` gathers what's needed to report a problem into `~/Desktop/SkyrimTogether-logs-<date>.zip` and
  prints its path: the newest Wine/DXMT logs, the mod's logs (`tp_client.log`, `cef_debug.log`, server output), Crash
  Logger's `crash-*.log` reports, crash dumps (`crash_UTC_*.dmp`, written next to `SkyrimTogether.exe`), the load
  order and game INIs, `skyrim-together.sh check` output and versions (macOS, Wine, DXMT, game, Skyrim Together build).
  Every `STServer.ini` is copied with its password values removed, and nothing from `Saves` is taken; it stops without
  writing a zip if a password or save file would get in. `COLLECT_COUNT=n` changes how many files per log folder.
- Both run Wine with msync and set DXMT's options (pipeline warming, hitch log, Metal-paced 60 fps). SSE Engine Fixes
  is set aside (`EngineFixes.dll.off`) for Skyrim Together, where it makes other players and NPCs invisible, and put
  back for plain Skyrim.

### Performance

What the logs show (M4, 16 GB, 1800×1169 borderless on a 120 Hz screen, DXMT fork da80816 with the settings in
`skyrim-together.sh`), measured 2026-11-26:

- **In focus the game holds 60 fps.** The last session's DXMT log (`SkyrimSE_d3d11.log`, 48 two-second intervals,
  5,673 frames): mean 58.9 fps, 34 intervals at 60; the 99th-percentile frame is 16.7 ms in the median interval
  and over 33 ms in 7 of 48. The GPU works about 11 ms of each 16.7 ms frame (`gpuspan` median 11.3 ms, max 15.5), so there is headroom but not a lot.
- **Shader warming works.** All 1,048 recorded pipelines were warmed (`WARM ... used=1048/1048`); 11 pipelines were
  built while playing, none failed. Compiling is not a cause of the hitches.
- **Hitches come from outside DXMT.** Of the 17 frames over 50 ms in that session (51–340 ms), 13 spent under 5 ms
  in DXMT: the time went to the game, the mod or Wine. Three were DXMT waiting for a drawable (at startup, and one
  pair of 97 and 106 ms), and one split 45 ms in DXMT (25 ms creating resources) and 96 ms outside.
- **Many sessions sat at exactly 30 fps.** Across the mod's `[Perf]` lines (`tp_client.log`, 191 ten-second intervals
  in 11 sessions since 2026-11-19), 88 intervals read exactly 30 fps and 32 read 60, with little in between. Two
  sessions (2026-11-21 09:49 and 2026-11-26 14:54 UTC, 6–7 minutes each) read exactly 30 in 23 of 38 and 28 of 34
  intervals and never dropped below it, while
  the mod's own updates took about 0.1 ms a frame. The only 30 fps cap configured is DXMT's background throttle
  (`DXMT_BG_FPS=30`, `DXMT_BG_POLICY=focus`), which also counts "no foreground window" as background, and Wine opens
  the game without making it the active app (the reason for `bring_to_front`). That fits, but it isn't proven: DXMT's
  log is overwritten on each start, so none survives from those sessions.
- **One mod cost stands out.** With about 30 actors in the 2026-11-26 15:01 session, the mod's "Game: actor updates"
  averaged 3.4 ms a frame and rose to 11–19 ms in its worst intervals, where the game fell to 27–28 fps. In the
  other sessions it averages 0.4–1.7 ms.

What changed because of it:

1. `skyrim-together.sh` now sets `DXMT_BG_FPS=60`, so the background throttle can no longer hold the game at 30 while
   it is being played; a minimized game still drops to DXMT's minimized cap. This costs some power while the game sits
   behind other windows; `DXMT_BG_FPS=30 skyrim-play.sh together` brings the old cap back. If a session still sits at
   30, it is something else: keep that session's logs (`collect-logs.sh`) before starting the game again.
2. Each start moves the last session's DXMT logs to `SkyrimSE_d3d11.previous.log` and
   `TPProcess_d3d11.previous.log`, so a slow session can still be read after the next start.

Still to do:

3. Look at the mod's actor-update hook when many players or NPCs are synced: it is the only measured cost that
   grows enough to drop frames.
4. Leave the frame cap as it is: DXMT's `preferredMaxFrameRate=60` plus SSE Display Tweaks' `FramerateLimit=60`
   with VSync gives the flat 16.7 ms pacing above.

Paths are the ones used on the original machine (`~/Games/...`); adjust the variables at the top of each script.

## mac-app/

`Skyrim Together.app`, a one-window SwiftUI launcher (macOS 14+) over the scripts in `launch/`: **Play** (runs
`skyrim-play.sh together`; the Base/Plus switch sets `ST_VERSION`), **Host a Game** (`skyrim-host-app.sh`), **Check
Setup** (`skyrim-together.sh check`, shown as rows with icons and the firewall fix ready to copy; it also runs when the
window opens and when the build changes), **Collect Logs** (`collect-logs.sh`, then shows the zip in Finder) and a
status line. It never runs `sudo`: the firewall command is copied for you to paste into Terminal. Play is refused while
`SkyrimTogether.exe` is already running.

`mac-app/build.sh` runs the tests, builds `build/Skyrim Together.app` and prints its path. The app finds the scripts
through the repo path that `build.sh` writes into its Info.plist (`STLaunchFolder`); if the repo moves it asks for the
`launch` folder. Look: system controls only, one accent (a steel blue-grey, `Color.frost`), the Play button as the one
prominent control, wording that says what each button does.

## play/

`SkyrimTogetherHost.cpp`: the `Skyrim Together Host.exe` in each release zip, a window to run a co-op server:
name, password, player limit, port, PvP, and on Plus servers host world and Friends need my mods (from Skyrim's
Plugins.txt); the addresses and join code to share, who is connected, and Kick and Ban buttons (it drives
`SkyrimTogetherServer.exe` through its stdin). On a Mac, `launch/skyrim-host-app.sh` runs it under Wine.

`PlaySkyrimTogether.cpp`: the `Play Skyrim Together.exe` in each release zip. It finds Skyrim (Steam or GOG), installs
the release folder matching the game version into `Data`, enables Skyrim Together's plugins and starts it. Holding Ctrl
while starting it (or `--collect-logs`) instead copies the same kinds of files as `collect-logs.sh` (mod logs, crash
dumps, Crash Logger reports, load order and INIs, `STServer.ini` without passwords, a system summary) into a new Desktop
folder `SkyrimTogether-logs-<date>` and opens it in Explorer. Build with `cross-build/` (clang-cl) or MSVC; the build
line is at the top of the file. From the Mac, inside `play/`:

    . ~/Developer/xwin/env.sh && mkdir -p ../build && clang-cl /nologo /std:c++20 /O2 /EHsc /W3 \
      --target=x86_64-pc-windows-msvc -fuse-ld=lld-link /winsysroot "$WINSYSROOT" /Fe../build/PlaySkyrimTogether.exe \
      PlaySkyrimTogether.cpp /link /SUBSYSTEM:WINDOWS user32.lib shell32.lib ole32.lib advapi32.lib version.lib

(the source file goes before `/link`, and paths stay relative: absolute `/Users/...` paths parse as options).

## mod-set/

A co-op mod set for Skyrim Together (both players install the same): the Keizaal Online Nexus collection without
Keizaal's own content, with the exact files, installer choices and load order. See `mod-set/README.md`.

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
