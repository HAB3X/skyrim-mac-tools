**Install: download `SkyrimTogether-1.8.4-mac.2.zip`, unzip it, double-click `Play Skyrim Together.exe`; to host, open `Skyrim Together Host.exe`.** Play Skyrim Together finds your Skyrim (Steam or GOG), installs the right files for your game version, turns on the plugins and starts the game. Use it every time you play.

### New in mac.2
- **Skyrim Together Host.exe:** a window to host co-op: server name, password, player limit, port and PvP, the
  addresses friends join with, **Copy invite**, who's connected and a **Kick** button. The server gained a `/kick`
  command and takes commands from a host app as well as a console window.
- Co-op mod set: dropped Simple Dual Sheath's XPMSSE rotation fix (its skeletons made some NPCs invisible).
- **One download, one click:** `Play Skyrim Together.exe` in the zip installs and starts it (details in `INSTALL.md`); the co-op mod set is in `mod-set/`.
- **Fixed: casting a spell crashed the game on a Mac.** Skyrim Together writes small hook stubs at start-up into a
  memory area that isn't marked executable; the spell projectile hook ran from there and Wine stopped it (this was in
  mac.1 and plus.1 too). The stubs are now made executable when they're created.
- **First start finds the game by itself.** Skyrim Together looks for `SkyrimSE.exe` above its own folder
  (`Data\SkyrimTogetherReborn`), then in Steam's and GOG Galaxy's install records, and starts straight away. Only if
  it can't find it does it ask, for your Skyrim folder; hold Space while starting to pick a different one.
- **Fixed: the launcher was set up for Enderal.** A fork commit made it set Steam app ID 976620 (Enderal) and write it
  to the game's `steam_appid.txt`, look up Skyrim's install under Enderal's registry key, and title errors "Enderal
  Together". It's Skyrim again.
- The server no longer crashes at start-up when `bAnnounceServer` is on: Mac-built servers have no HTTPS, so they now
  skip the public server list and say why in the log, instead of exiting.
- [skyrim-mac-tools](https://github.com/HAB3X/skyrim-mac-tools): the game now runs truly fullscreen. Wine had kept the
  window 39 points below the menu bar, so menu clicks missed the cursor (the character menu's Body and Head tabs
  couldn't be clicked). Also a co-op mod set with exact files, installer choices and load order (`mod-set/`).

Still reports `v1.8.4`: plays with official v1.8.4 players and servers.

Skyrim Together Reborn **v1.8.4** that runs on Apple Silicon Macs (Wine + DXMT), with client-side fixes from community
forks. It reports `v1.8.4`, so it plays with official v1.8.4 players and servers on Windows and Mac.

**Download:** `SkyrimTogether-1.8.4-mac.2.zip` – one folder for Skyrim **1.7.104** (current Steam) and one for
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
