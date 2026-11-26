# skyrim-mac-tools

Tools for playing Skyrim Special Edition and Skyrim Together Reborn on an Apple Silicon Mac, and for building
Skyrim Together's Windows binaries on macOS. The Mac build of Skyrim Together itself is the `mac` branch of
[HAB3X/TiltedEvolution](https://github.com/HAB3X/TiltedEvolution/tree/mac).

## launch/

Launchers for Skyrim SE in a [SkyrimMT](https://github.com/HorrorPills/skyrimmt) Wine prefix (`~/Games/skyrim`): the
GOG copy (1.6.1179, under `C:\GOG Games`) or a Steam copy (1.6.1170 or 1.7.104) in the prefix's Steam libraries
(`libraryfolders.vdf`) or Steam for Mac's library. When both are there GOG is used, `ST_STORE=steam` picks Steam. The
Steam copy starts through Steam, so `check` warns when no `steam.exe` runs in the prefix. `skyrim-together.sh paths`
prints where the game and its settings folders are (`Skyrim Special Edition GOG` or `Skyrim Special Edition`); the
other scripts read it from there. Only the GOG copy has been run here: the Steam detection is tested on a made-up
prefix.

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
  missing, `fix-input` gives a running game its mouse and keyboard back (below).
- Mouse and keyboard: Skyrim reads them through DirectInput, which only works while the game's window is Wine's
  foreground window, and Wine's foreground isn't macOS's. After a Cmd-Tab Wine can be left with no foreground window
  while the game is the active Mac app, and the game then ignored the mouse and keyboard until it was restarted.
  `launch/fix-input.c` (built to `~/Games/skyrim/tools/fix-input.exe`, the build line is in the file) makes the game's
  window Wine's foreground window again. While the game runs, the launcher runs it each time the game becomes the active
  Mac app again, and keeps `fix-input.exe --watch` running in Wine, which does it within half a second whenever Wine has
  no foreground window at all (it never makes the game the active Mac app by itself). `skyrim-together.sh fix-input` (the
  app's **Fix Mouse & Keyboard**) brings the game to the front, releases Wine's cursor clip and gives the game Wine's
  focus again, without restarting it. What they did is in `~/Games/skyrim/logs/fix-input.log`. Tested on a test window
  that loses Wine's foreground (`dxmt/focus-test`), not yet in the game; input lost while the mod's overlay is open is the
  mod's (its DirectInput hook) and isn't covered.
- Keeping the Mac awake: while the game runs, the launcher holds `caffeinate -dis -w <game pid>` (no display sleep,
  idle sleep or, on power, system sleep; it ends with the game). `check` and Play warn when Low Power Mode is on
  (`pmset -g` shows `lowpowermode 1`), which keeps the game from holding 60 fps.
- After a crash: when the game exits, the launcher looks for this session's crash reports (the mod's
  `crash_UTC_*.dmp` next to `SkyrimTogether.exe`, Crash Logger's `crash-*.log`, or Wine's "Unhandled exception/page
  fault" in `skyrim-together.log`). If there is one it runs `collect-logs.sh` and shows a dialog with the zip's path and
  **Relaunch** (`skyrim-play.sh together` with the same build). skyrim-play.sh passes its folder (`ST_LAUNCH_DIR`) so
  the copy in `~/Games` finds `collect-logs.sh`. What it found and did is in `~/Games/skyrim/logs/crash-recovery.log`.
- Controllers: `check` lists each game controller connected to the Mac (`ioreg`, HID joystick/gamepad) and whether
  Wine has made it an XInput controller, the only kind Skyrim reads (winebus's `Enum\HID\VID_…&PID_…&XI_…` entries in
  the prefix's `system.reg`), with a hint when it hasn't (start the game with it connected; reconnect it while the game
  runs). The registry records what Wine has seen, not what a running game sees right now.
- Plus updates: `ST_VERSION=1.8.4-plus skyrim-together.sh update check` reads the releases of HAB3X/TiltedEvolution
  from GitHub's public API (no sign-in) and prints `UPDATE <tag> <bytes> <installed>` when a `v1.8.4-plus.N` newer than
  the installed build (the version in its `SkyrimTogether.exe`) is out. `update install` downloads that release's zip,
  checks its size and the SHA-256 GitHub lists, unpacks the folder for the installed game (`SkyrimTogether-1.6.1170`
  for 1.6.1170/1.6.1179, else `SkyrimTogether-1.7.104`) with `Skyrim Together Host.exe` into the build folder Play uses,
  keeps the server's `config/` (STServer.ini) and moves the replaced build to `<folder>.previous`; Play then installs it
  into `Data` (the stamp now includes the build's `VERSION`). `update rollback` swaps the two back. Both refuse while
  the game or its server runs. The app shows **Update to plus.N** when a check finds one. `ST_BUILDS` moves where the
  build folders are (default `~/Games`).
- Ready-made shader cache: DXMT records what each pipeline was built from (`recipes_1.db`) and keeps the shaders it
  translated (`shaders_<n>.db`) in `$(getconf DARWIN_USER_CACHE_DIR)dxmt/SkyrimSE.exe/` (`DXMT_CACHE_DIR` moves the
  base); pipeline warming (`DXMT_WARM=all`, the `WARM` lines) builds from them at start, so only a fresh install
  stutters while it compiles. `skyrim-together.sh shader-cache export [zip]` writes both (consistent sqlite copies,
  about 7 MB zipped for 11,047 recipes) with a `MANIFEST.txt` (date, DXMT build, chip, macOS, recipe count) to
  `~/Desktop/SkyrimTogether-shader-cache-<date>.zip`; `shader-cache import <zip>` checks the files and puts them in
  place, keeping a cache that was there as `SkyrimSE.exe.before-import-<time>`. Both refuse while the game runs.
  Tested: a cache exported here and imported into an empty cache folder warmed all 1,048 used pipelines (804 functions,
  0 failed) in a fresh DXMT process.
  Packaging it for a release (the lead): on the DXMT build the release uses, play a long session through the main
  areas (and the mod's UI), quit, run `shader-cache export`, and attach the zip to the GitHub release; players run
  `shader-cache import` once before their first start. Recipes are keyed by Metal target, so on another chip family
  some may not apply (the `WARM` line counts them as `othertarget`); a cache from another DXMT build's shader
  translator (another `shaders_<n>.db` number) isn't read. The recipes hold the DXBC of every shader the game ran,
  including mods' shaders: check that sharing that is all right before publishing one.
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
  (`DXMT_BG_FPS=30`, `DXMT_BG_POLICY=focus`), which counts "no foreground window" (or another process's) as
  background, going by Wine's foreground window only. Wine's foreground isn't macOS's: in a test window (`dxmt/focus-test`)
  that loses Wine's foreground window while it is the active Mac app, DXMT da80816 held it at exactly 30 fps until
  another app was activated and the window activated again. DXMT's log of the slow game sessions was overwritten, so
  that this is what happened in them is likely, not proven.
- **One mod cost stands out.** With about 30 actors in the 2026-11-26 15:01 session, the mod's "Game: actor updates"
  averaged 3.4 ms a frame and rose to 11–19 ms in its worst intervals, where the game fell to 27–28 fps. In the
  other sessions it averages 0.4–1.7 ms.

What changed because of it:

1. The cause, fixed in DXMT (`dxmt/0001-background-throttle-frontmost.patch`, installed as
   `v0.80-578-gf068fc2e3`): the focus policy also counts the game as foreground while it is the active app on macOS
   with its window on screen, whatever Wine reports. A hidden, minimized or Cmd-Tabbed-away game still throttles. In
   the test window the patched build presents at the display's rate where da80816 sat at 30, and logs
   `Present: the window is in front on macOS while Wine reports no foreground window ...: counted as foreground` each
   time it overrides Wine. Not yet seen in a game session: look for that line in `SkyrimSE_d3d11.log`.
2. Containment until a game session confirms it: `skyrim-together.sh` still sets `DXMT_BG_FPS=60`, so even an
   unforeseen case can't hold the game at 30 (a minimized game still drops to DXMT's minimized cap). Once a session
   shows the line above and no 30 fps stretch, drop that line to get the power saving back. If a session still sits
   at 30, keep its logs (`collect-logs.sh`) before starting the game again.
3. Each start moves the last session's DXMT logs to `SkyrimSE_d3d11.previous.log` and
   `TPProcess_d3d11.previous.log`, so a slow session can still be read after the next start.

Still to do:

4. Look at the mod's actor-update hook when many players or NPCs are synced: it is the only measured cost that
   grows enough to drop frames.
5. Leave the frame cap as it is: DXMT's `preferredMaxFrameRate=60` plus SSE Display Tweaks' `FramerateLimit=60`
   with VSync gives the flat 16.7 ms pacing above.

### Audio

How the game's sound reaches the Mac (read from a `WINEDEBUG=+mmdevapi,+coreaudio` trace and an audio tap,
2026-11-27):

- Skyrim loads Microsoft's XAudio2 2.7 (`xaudio2_7`, `x3daudio1_7`, `xapofx1_5` from the DirectX June 2010
  redistributable, placed in the prefix's `system32` by SkyrimMT). Wine's own FAudio-based one gets Skyrim's sound
  distances wrong (SkyrimMT `scripts/_env.sh`). The override is per program: SkyrimMT sets it for `SkyrimSE.exe`,
  `skyrim-together.sh` for `SkyrimTogether.exe` (without it hit and impact sounds were silent).
- XAudio2 opens one 48 kHz stereo float stream (asks for a 120 ms buffer, writes 10 ms per wake-up) through Wine's
  `winecoreaudio`, which hands macOS 512 frames per callback. The logo video (Bink, through Wine's DirectSound) uses a
  second stream at Wine's mix rate (96 kHz, SkyrimMT's `coreaudio_rate.sh`); the game's own stream ignores that rate.
- It only plays without dropouts on SkyrimMT's patched Wine audio: 30 ms device period (`coreaudio_period.sh`) and 90 ms
  minimum buffer (`mmdevapi_buffer.sh`). SkyrimMT re-applies them when plain Skyrim starts; `skyrim-together.sh`
  checks and applies the same two before a Skyrim Together session (a `WARN audio:` line says when it can't).
  Revert: `~/Documents/Mac-Wine-References/SkyrimMT-source/tools/wine-patches/<name>.sh revert`.
- Measured with these patches, plain Skyrim at the main menu, 60 s idle then 60 s with all 10 cores busy: 0 dropouts
  in 11,269 callbacks of the game's stream. The logo video's stream had 3 short dropouts in its first seconds.
- Skyrim Together Plus voice chat uses its own streams (miniaudio, 48 kHz): playback on the Windows default device,
  and the microphone only once one is picked in Settings (`sInputDevice` in `config/STServer.ini`; empty = none).

Finding a dropout: `ST_AUDIO_DIAG=1 ~/Games/skyrim-together.sh` injects `launch/audiotap.c` (build line at its top,
installed as `~/Games/skyrim/tools/audiotap.dylib`) and rewrites per-stream totals every 2 s in
`~/Games/skyrim/logs/audio-tap.<pid>`: `dropouts` counts buffers Wine had to finish with silence because the game had
not queued enough sound (a click or crackle), `silent_calls` all-silent buffers. Note the time when you hear a problem
and compare. Skyrim Together only: plain Skyrim starts through SkyrimMT's script, and macOS drops the variable on the
way (`/bin/bash` is a protected binary).

What only the Mac's owner can change:

- AirPods (or any Bluetooth headset) with voice chat: when a program opens the AirPods microphone, macOS switches them
  to the headset profile (mono, low sample rate) and all game sound turns dull while the microphone is open. Voice
  chat keeps the picked microphone open the whole session (for the level meter, even while not talking). Pick
  "MacBook Pro Microphone" as the voice chat input in Settings, or set System Settings → Sound → Input to the MacBook
  Pro Microphone, and the AirPods keep full quality.
- Bluetooth adds its own delay (typically 0.1-0.3 s) on top of the game's ~0.1 s buffer, so hits can sound late;
  wired headphones and the built-in speakers don't add it.
- Switching the output device while the game runs (connecting AirPods, unplugging headphones): the game's stream was
  opened on the device that was the default at start and is expected to stay there (not tested here). Pick the output
  before starting the game.
- Audio MIDI Setup: the built-in speakers run at 48 kHz, the rate the game mixes at, so nothing to change. An external
  interface at 44.1 kHz also works (macOS converts); 48 kHz skips that conversion.

Paths are the ones used on the original machine (`~/Games/...`); adjust the variables at the top of each script.

## dxmt/

Our patches to the DXMT build the game uses (jdrly's gw2-on-mac fork at da80816), and how to build and install it.

- `0001-background-throttle-frontmost.patch`: the 30 fps fix above.
- `build.sh <checkout> <output folder>` builds a checkout of the fork with the patch applied (`git am`): it sets up,
  once, the toolchains the fork's CI uses in `~/Games/dxmt-builds/toolchains` (LLVM 15 for x86_64, built here in about
  15 minutes; 3Shain's Wine 8.16 build; meson), and needs mingw-w64 and Xcode's Metal Toolchain
  (`xcodebuild -downloadComponent MetalToolchain`). The checkout used is `~/Documents/Mac-Wine-References/dxmt-jdrly`,
  branch `skyrim-focus`.
- `install.sh <build folder> "<description>"` puts a build into the game's Wine (refused while the game runs) and
  records it in `~/Games/dxmt-builds/INSTALLED.txt`. Back up what it replaces first (`~/Games/skyrim/backups/`, named by
  commit); going back is `install.sh` with the backup's folder, the command is in `INSTALLED.txt`.
- `focus-test/`: a D3D11 window that presents for a while in a copy of the game's Wine and a test prefix (never the
  game's own). `scenario.sh` makes it lose Wine's foreground window while it is the active app and switches apps
  around it, then prints DXMT's throttle lines and fps; `DXMT_BUILD=<folder>` tests that build. It takes the keyboard
  from the frontmost app for 12 of its 26 seconds.

## mac-app/

`Skyrim Together.app`, a one-window SwiftUI launcher (macOS 14+) over the scripts in `launch/`: **Play** (runs
`skyrim-play.sh together`; the Base/Plus switch sets `ST_VERSION`), **Host a Game** (`skyrim-host-app.sh`), **Check
Setup** (`skyrim-together.sh check`, shown as rows with icons; it also runs when the window opens and when the build
changes, and for Plus it also runs `update check` and offers **Update to plus.N**), **Fix Mouse & Keyboard**
(`skyrim-together.sh fix-input`), **Collect Logs** (`collect-logs.sh`, then shows the zip in Finder) and a status line.
Play is refused while `SkyrimTogether.exe` is already running.

The firewall fix: the check's row has the Terminal command to copy, and **Allow Wine…**, which runs the same
`socketfilterfw` commands through `osascript -e 'do shell script "…" with administrator privileges'`, so macOS asks for
your own password in its dialog; then the check runs again. Only `socketfilterfw` commands are accepted
(`FirewallFix` in `LauncherCore`, unit-tested, including an `osacompile` check of the AppleScript). Started with
`ST_DRY_RUN=1` in its environment, the app shows and prints the `osascript` command instead of running it.

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
