**Install: download `SkyrimTogether-1.8.4-plus.3.zip`, unzip it, double-click `Play Skyrim Together.exe`.** To host, press **F2 → Connect → Host a game** in game, or open `Skyrim Together Host.exe`.

### New in plus.3
- **Host from inside the game.** F2 → Connect → **Host a game**: set a password, tick what you want, click Host. The game starts the server in the background and joins it; the server stops by itself when you quit the game.
- **Host world.** With *Friends join my world* on, everyone who joins takes over the host's world: the host's quests (running ones at the host's stage, finished ones finished), cleared dungeons and which named NPCs are dead or alive, and starts next to the host. Before that, the joiner's own world is saved as `BeforeHostWorld_<character>`, so going back to it is one load away, and chat says what changed.
- **Require your mods.** With *Friends need my mods* on, a friend missing one of your mods is refused and told exactly which to install. Bethesda's and Creation Club plugins never count; extra mods are fine.
- **Games on your network.** The Connect screen lists Skyrim Together games on your Wi-Fi with their players and whether they need a password; click Join.
- **No more router setup, mostly.** The server opens its port on your router (UPnP) while it runs and closes it again; the host gets an **Invite** button with a short join code like `6BVJN-FJAAJ` that friends type into Connect.
- **Tells you what's wrong.** At start the server checks players on your network can reach it, and says so in chat if a VPN (like NordVPN) or a firewall is blocking them.
- **Join official servers.** Plus can now join official Skyrim Together v1.8.4 servers (and the base mac release's): it speaks their protocol, with Plus's own features off there.
- **Kick and ban from the F2 player list** when you host; bans are remembered (`config/bans.txt`). The Host app has a Ban button and the mods box too.
- **Reconnect and rejoin.** After a lost connection the game reconnects by itself; after a crash the menu offers **Rejoin** (or **Host again**).
- The new text is translated into all 15 languages; the launcher's refusal messages are English Skyrim text (they were German Fallout text from another fork).

Every player and the server need plus.3 to play Plus together (plus.1 and plus.2 can't join a plus.3 server). Mac launchers and the Host app: [skyrim-mac-tools](https://github.com/HAB3X/skyrim-mac-tools).
