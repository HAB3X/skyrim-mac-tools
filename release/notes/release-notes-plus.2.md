**Install: download `SkyrimTogether-1.8.4-plus.2.zip`, unzip it, double-click `Play Skyrim Together.exe`; to host, open `Skyrim Together Host.exe`.** Play Skyrim Together finds your Skyrim (Steam or GOG), installs the right files for your game version, turns on the plugins and starts the game. Use it every time you play.

### New in plus.2
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
- Smoother when playing alone: while no other player is near, the game culls unseen actors again (Skyrim's own
  pre-culling), as it does in single player.
- A frame-rate report in the client log every 10 seconds (fps, 1% low, hitches, and what each Skyrim Together system
  costs per frame). `[Debug] bFrameProfiler=false` in `STServer.ini` turns it off.
- The skyrim-mac-tools fullscreen fix and co-op mod set from
  [v1.8.4-mac.2](https://github.com/HAB3X/TiltedEvolution/releases/tag/v1.8.4-mac.2) apply here too.

Client-only changes: still reports `v1.8.4-plus.1`, so it plays with plus.1 players and servers.

**Optional, for co-op groups who all switch together.** Skyrim Together Reborn's newer `dev` code plus 169 commits
from community forks, including ones that change the network protocol and the server. Every player and the server
must run Plus (`v1.8.4-plus.1`); it doesn't mix with official v1.8.4. If you want to stay compatible with everyone
else, use [v1.8.4-mac.2](https://github.com/HAB3X/TiltedEvolution/releases/tag/v1.8.4-mac.2) instead.

**Download:** `SkyrimTogether-1.8.4-plus.2.zip`, with one folder for Skyrim **1.7.104** and one for **1.6.1170 /
1.6.1179** (GOG), the server, and `INSTALL.md`. It runs on Windows and on Apple Silicon Macs (Wine + DXMT,
[skyrim-mac-tools](https://github.com/HAB3X/skyrim-mac-tools) has `Host Co-op Plus` and `Skyrim Together Plus`
launchers).

### What's in it
- **Proximity voice chat** built in: it runs over the game connection, voices fade with distance and are panned left
  and right, and you can listen to everyone, party only or strangers. Set it up in `STServer.ini` (`[Voice]`).
- **Party play:** saving together with the party, the party leader owns world-encounter spawns, quest-item pickups
  shared with the party, stricter quest-stage and quest-stop sync, party invites that expire, safer kicks and leaves.
- **Items and the world:** server support for opt-in player-to-player item transfers, container contents kept on the server, locks synced
  across nearby cells, synced mod animation events and a `/wave` chat command.
- **Sync and crash fixes:** many movement, cell-change and actor-visibility fixes, horses no longer slide without
  moving their legs, damage subtracted correctly on the server, and crash fixes for teleports into unloaded cells,
  deleted activated objects, missing projectiles and saves referencing freed cells.
- Everything from the Mac release: the Wine start-up fix, the save buffer fix, release build without console or log
  floods.
- Servers built without HTTPS (like this one) no longer crash at start-up trying to reach the public server list.
  The fix is also on the `mac` branch.

Full list with authors: `PLUS-FEATURES.md` (also on the `plus` branch). Source: branch
[`plus`](https://github.com/HAB3X/TiltedEvolution/tree/plus).

### Known
- Not compatible with official Skyrim Together v1.8.4 clients or servers.
- Fork code is less tested than official releases; keep backups of your saves.
- Don't use SSE Engine Fixes with Skyrim Together (other players and NPCs can turn invisible).
- Left out because they didn't build here: a voice relay for a separate voice program (the built-in voice chat is in),
  an unfinished party async-save system, one quest-stage change, a dropped-item grid-shift change and debug logging.
