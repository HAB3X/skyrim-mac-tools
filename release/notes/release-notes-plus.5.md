## Download

| You play on | Download | Then |
|---|---|---|
| **Windows** | `SkyrimTogether-1.8.4-plus.5-Windows.zip` | Unzip it and double-click **`Play Skyrim Together.exe`**. |
| **Mac** (Apple Silicon, macOS 14+) | `SkyrimTogether-1.8.4-plus.5-Mac.zip` | Set up Skyrim with [SkyrimMT](https://github.com/HorrorPills/skyrimmt/releases) once, then open the **Skyrim Together** app, click **Install plus.5**, then **Play**. Steps in its `MAC-INSTALL.md`. |

Both are below under **Assets**. Windows and Mac players play together. To host, press **F2 → Connect → Host a game** in game, or open `Skyrim Together Host.exe` (Windows) or click **Host a Game** (Mac app).

A test release: everything below passes the automated checks (546 unit-test assertions; 292 checks across 33 multi-player suites with simulated players), but none of it has been played in a real session yet. Please report what breaks.

### New in plus.5
- **Guards go after whoever committed the crime.** When you have a bounty, the guards of that hold near you are run by your game, so they arrest or attack you in everyone's game, and never your friend. Paying, jail or death hands them back.
- **Revive instead of reload.** In a party, a player who would die goes down instead; a partner revives them by activating them, and they get up with half health. If the whole party is down, or nobody comes within 2 minutes, it's a normal death. Host option *Revive instead of reload*, on by default.
- **Trade.** **Trade** on a party member in the player list opens a window for both of you: pick what to give, both confirm, and the server swaps the items so nothing is duplicated. Changing an offer unconfirms both sides. Worn and quest items can't be traded.
- **Your followers and horse stay yours.** They're run by your game and follow you, and others see them do it; nobody else can take them over.
- **Gates and levers** are open or closed for players arriving later the way the others left them.
- **Loot for each player now covers bodies too:** with the host option on, everyone loots their own copy of a body, and the game's own death items go to everyone.

Werewolf and vampire lord transformations and shouts already show for other players; they weren't changed.

Every player and the server need plus.5 to play Plus together (plus.4 can't join a plus.5 server). The Mac app's source: [skyrim-mac-tools](https://github.com/HAB3X/skyrim-mac-tools).
