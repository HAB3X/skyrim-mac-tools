# Skyrim Together Plus – install

Plus is Skyrim Together Reborn's newer `dev` code with co-op features and fixes from community forks, including
built-in proximity voice chat. It changes the network protocol, so to play Plus together **every player and the server
must run Plus plus.5**. Plus can also join official Skyrim Together v1.8.4 servers (it speaks their protocol, with
Plus's own features off there); official clients can't join a Plus server. It runs on Windows and, under Wine, on a
Mac.

## 1. Install and play

1. Unzip this whole folder anywhere (Downloads is fine).
2. Double-click **`Play Skyrim Together.exe`**.

It finds your Skyrim Special Edition (Steam or GOG), picks the files for your game version (Steam 1.7.x, Steam 1.6.1170
or GOG 1.6.1179), installs them into the game's `Data` folder, turns on `SkyrimTogether.esp` and
`SkyrimTogetherQuestPatches.esp` (last in the load order) and starts Skyrim Together. Use it every time you play: it
only copies files again when you've unzipped a newer release. If it can't find the game it asks for your Skyrim folder
once; hold **Shift** while starting it to pick a different folder.

The one thing it can't install for you is the **Address Library for SKSE Plugins** (Nexus Mods, "All in one"); if it's
missing, Play Skyrim Together says so and opens its download page.

**On a Mac**, use the Mac download from the same release page instead
(`SkyrimTogether-1.8.4-plus.5-Mac.zip`, <https://github.com/HAB3X/TiltedEvolution/releases/latest>): an app that
installs this release for you and starts it. Its `MAC-INSTALL.md` has the steps.

Installing by hand instead: copy everything inside `SkyrimTogether-1.7.104` (Steam 1.7.x) or
`SkyrimTogether-1.6.1170` (Steam 1.6.1170, GOG 1.6.1179) into the game's `Data` folder, enable the two plugins and
start `Data/SkyrimTogetherReborn/SkyrimTogether.exe`.

Optional co-op mod set (both players install the same): `mod-set/README.md`.

## 2. Hosting

**From the game:** press **F2 → Connect → Host a game**, type a password (or leave it empty) and click **Host**. The
game starts the server in the background, joins it, and stops it when you quit the game.

- **Friends join my world:** whoever joins takes over your world — your quests (running ones at your stage, finished
  ones finished), cleared dungeons and which named NPCs are dead or alive — and starts next to you. Their own world is
  saved first as `BeforeHostWorld_<character>`; loading that takes them back to it.
- **Friends need my mods:** a friend missing any of your mods is refused and told which to install. Bethesda's and
  Creation Club plugins don't count; extra mods are fine.
- The server opens UDP port 10578 on your router by itself (UPnP) and closes it again. Then **F2 → Invite** shows a
  join code like `6BVJN-FJAAJ`, which friends type into Connect instead of an address. If your router doesn't do
  UPnP, chat says so: forward UDP port 10578 to your computer by hand.
- Chat also says when a VPN or firewall keeps friends on your network out.
- In **F2 → Player Manager** you can **Kick** or **Ban** a player; bans are kept in `config/bans.txt`.
- **Classic** instead of **Plus** on the Host page starts a game players on the regular Skyrim Together v1.8.4 can
  join (Plus's own features are off in it). The server for it is in `SkyrimTogetherReborn/classic`.
- **Loot for each player** gives everyone their own copy of what's in containers and on bodies; off by default.
- **Revive instead of reload** (on by default): in a party, a player who would die goes down until a partner
  activates them to revive them.
- **Relay:** if your router can't be opened, enter a relay's address under the relay settings and friends join through
  it. Running a relay yourself: `relay/README.md`.

Friends on your Wi-Fi don't need an address at all: **Connect** lists **Games on your network**; click **Join**.

**With the Host app:** double-click **`Skyrim Together Host.exe`** (in this folder). Set the server name, password, player limit and port, then
**Start server**. It shows the addresses friends join with (same Wi-Fi, and internet once UDP port 10578 is forwarded on
your router), **Copy invite** puts the address and password on the clipboard, the player list shows who's connected and
**Kick** and **Ban** disconnect the selected player. It has the same *Friends join my world* and *Friends need my
mods* boxes (the mods come from Skyrim's `Plugins.txt`), and shows the join code once the router has opened the
port. Closing it stops the server. Players join with **F2** in game. On a Mac, the Mac app's **Host a Game** button
opens it.

## 3. Voice chat

Voice chat goes through the game connection, so no extra program or port is needed. It's on for the server in this
pack (`bVoip=true` under `[Voice]`). Each player picks a microphone in their own `STServer.ini`, under `[Voice]`:

```ini
bVoip=true               ; connect to voice chat
sInputDevice=default     ; empty = microphone off (the default), "default" = Windows' default microphone
sVoipChannel=everyone    ; whom you hear: everyone, party or strangers
fVoipFadeStart=2500      ; distance where voices start to fade out
fMicVolume=1.0
fNoiseGate=0.1
```

You can hear people who are near you in the game world; they get quieter with distance and sound from their side.

## 4. Chat commands

`/wave` waves, `/settime HH MM` sets the time (if the server allows it), `/help` lists the commands.

Full list of the fork changes with their authors: `PLUS-FEATURES.md`.
