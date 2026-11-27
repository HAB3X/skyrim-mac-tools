Skyrim Together Reborn **v1.8.4** that runs on Apple Silicon Macs (Wine + DXMT), with client-side fixes from community
forks. It reports `v1.8.4`, so it plays with official v1.8.4 players and servers on Windows and Mac.

**Download:** `SkyrimTogether-1.8.4-mac.zip` – one folder for Skyrim **1.7.104** (current Steam) and one for
**1.6.1170 / 1.6.1179** (older Steam / GOG). Instructions in `INSTALL.md`.

### Mac and Wine fixes
- The launcher no longer dies at start-up under Wine (exception tables merged after the game's headers are loaded).
- No crash after creating a character with mods loaded (save buffer overrun).
- Builds on macOS with LLVM clang-cl ([skyrim-mac-tools](https://github.com/HAB3X/skyrim-mac-tools) has the toolchain and
  one-click launchers, including a co-op host).
- Release build: no console window, no diagnostic log floods.

### Fixes from community forks
134 client-side commits from 26 contributors (crash fixes, NPC and player sync, quests and parties, name tags, F2 menu on
ultrawide screens, Detect Life and poisons in PvP), plus fixes in TiltedConnect, TiltedReverse and TiltedUI. Network
protocol and server are unchanged. Full list with authors: `FORK-FIXES.md`.

### Known
- Don't use SSE Engine Fixes with Skyrim Together: other players and NPCs can turn invisible.
- On a Mac, Skyrim Together needs Microsoft's XAudio2 for `SkyrimTogether.exe` (the launchers in skyrim-mac-tools set
  it), otherwise hit and impact sounds are silent.
