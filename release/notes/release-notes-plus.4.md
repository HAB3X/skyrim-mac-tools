**Install: download `SkyrimTogether-1.8.4-plus.4.zip`, unzip it, double-click `Play Skyrim Together.exe`.** To host, press **F2 → Connect → Host a game** in game, or open `Skyrim Together Host.exe`.

This is a test release: everything below passes the automated checks (506 unit-test assertions; 246 checks across 27 multi-player suites with simulated players), but it hasn't had a long real play session yet. Please report what breaks.

### Each player is their own person to the game
- **Crime stays with whoever did it.** If your friend attacks a guard, guards go after your friend, not you. Arrests, jail, bounty and marriage quests stay with the player they happen to.
- **Merchants are per player:** each player trades with their own copy of a merchant's stock and gold.
- **Factions and quests are shared**, so you can play the questlines together.

### Quests together
- **The party leader picks which kinds of quest the party shares** (main, factions, side, misc), and **anyone can share one quest** from the quest panel.
- **Catch-up:** a player joining mid-quest is brought to the party's stage.
- **Quest drift warning:** you're told when your quests differ from the leader's, with a **Repair** button that applies the leader's progress (only if you click it).
- **Quest items only go to players who share that quest.**
- **Travel together:** party members can follow the leader's fast travel.
- **Party doors:** members are asked to follow the leader through a load door.

### Party play
- **Party bar:** health, magicka, stamina, where they are and how far, with combat and downed alerts.
- **Pings:** **F3** marks a target or spot for the party, with a waypoint and a chat line.
- **Go to and summon** party members from the player list.
- **Respawn next to a party member.**
- **Immersion:** name tags, party bar, pings and every other on-screen multiplayer element can be switched off one by one, or all at once.
- **Sleep or wait together**, and the world can **pause while every player is in a menu** (host option).
- **Vote kicks and ready checks.**

### Loot and the world
- **Loot for each player** (host option, off by default): everyone gets their own copy of what's in containers.
- **Two players grabbing the same item** from a container or body at once can no longer both keep it.
- **Doors** are open or closed for players arriving later the way the others left them. **Dead NPCs stay dead** after everyone leaves.
- Far and standing NPCs send less network traffic, so busy towns stay smoother.

### Hosting and joining
- **Classic hosting:** the Host page can start a **classic** game that players on the regular Skyrim Together v1.8.4 can join.
- **Relay:** join through a relay when the host's router can't be opened (`SkyrimTogetherRelay.exe` is included for whoever runs one).
- **Host world servers keep their world** between runs.
- **Required mods** now catch a different version of the same mod, and the refusal box can search Nexus or copy the list.
- **Saves page:** your character's co-op saves, newest first, loaded from the panel.
- **Reconnect** with backoff after a lost connection, and come back to your party and place after a crash; after a crash you're offered a pre-filled bug report.
- **Performance overlay:** fps, frame time, ping, synced actors and Skyrim Together's own cost.
- Plus releases that don't match now name both versions and point to the release page.

### Fixes from community forks
Shared time when sleeping or waiting, NPCs kept dead, crashes when another player teleports away, NPCs no longer moved into interiors you aren't in, and the overlay toggle only reacting to a full key press. Full list with authors: `PLUS-FEATURES.md`.

Every player and the server need plus.4 to play Plus together. Mac launchers and the Mac app: [skyrim-mac-tools](https://github.com/HAB3X/skyrim-mac-tools).
