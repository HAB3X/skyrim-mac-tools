# Plus: features and fixes from community forks

The Plus build is Skyrim Together Reborn's `dev` branch (newer than v1.8.4) with 183 commits from community forks applied in date order, with their original authors, including ones that change the network protocol and the server. Each commit keeps a `(cherry picked from commit ...)` line pointing at the original. Because the protocol changed, every player and the server must run Plus (version `v1.8.4-plus.5` since this release).


## Added in plus.5 (this release's own work)

- Guard crime authority: a player with a bounty gets that hold's nearby guards in their own game, so guards act on the offender only, in every game.
- Revive instead of reload in a party (host option `Gameplay:bReviveInParty`, on by default).
- Trading between party members, both confirming, checked by the server.
- A player's followers and last ridden horse run in that player's game and stay theirs.
- Gates and levers with open/close animations keep their state for players arriving later.
- Loot for each player also covers bodies; the host world save moved to version 3 (version 2 still loads).
- `v1.8.4-plus.5` replaces `v1.8.4-plus.4` as the version every player and the server need.

## Added in plus.4 (this release's own work)

- Each player is their own person to the game: crime, arrest, jail, bounty and marriage stay with the player they happen to; guards and enemies act on that player only; merchants keep a stock and gold per player. Factions stay shared.
- Party quests: the leader picks which kinds of quest the party shares, anyone can share one quest, catch-up for players joining mid-quest, a drift warning with a Repair button, quest items only for shared quests.
- Travel together, party doors, go to and summon, respawn next to a party member.
- Party bar, F3 pings, a performance overlay; every on-screen multiplayer element can be switched off.
- Loot for each player in containers (host option); two players can't both keep the same item from a container or body.
- Door state for players arriving later; far and standing NPCs send less traffic.
- Classic hosting for regular Skyrim Together players; a relay for hosts whose router can't be opened; host world servers keep their world.
- Required mods catch other versions of a mod; Saves page; reconnect with backoff; a crash report offer; vote kicks and ready checks.
- `v1.8.4-plus.4` replaces `v1.8.4-plus.3` as the version every player and the server need.

## Added in plus.3 (this release's own work)

- Host a game from F2 → Connect; the server stops with the game.
- Host world: joiners take over the host's quests, cleared locations and unique NPC deaths, after saving their own world.
- Required mods: the server refuses players missing the host's mods and names them.
- Games on your network (UDP 10579 discovery), UPnP port opening, join codes and an Invite button, a network check.
- Joining official v1.8.4 servers in their protocol.
- Kick and ban from the player list; reconnect after a lost connection; Rejoin after a crash.
- `v1.8.4-plus.3` replaces `v1.8.4-plus.1` as the version every player and the server need.

## Fork commits

| Date | Author | Change |
|---|---|---|
| 2026-09-01 | Colin | fix: align Papyrus VM vtable for Skyrim VR |
| 2026-09-03 | Sanford Leach | build: pin xmake to 2.9.8 in the server Dockerfile |
| 2026-09-04 | MrMartexX | Cover process request lifecycle quiescence |
| 2026-09-03 | Sanford Leach | build(deps): force every tiltedcore require to v0.2.9 |
| 2026-09-06 | MrMartexX | Add edge-triggered runtime bootstrap signal |
| 2026-09-06 | MrMartexX | Test signal-driven runtime bootstrap ordering |
| 2026-09-06 | MrMartexX | Prove bootstrap bind fencing and allocation fail-closed |
| 2026-09-08 | Colin | fix: interleave VR VM slots using binary comparison |
| 2026-09-10 | MrMartexX | Define reviewed quest transition admission |
| 2026-09-14 | MrMartexX | Fix naked NPC inventory recreation safety |
| 2026-09-14 | Colin | fix: restore Games/TES.h include in MagicService |
| 2026-09-14 | Colin | fix: keep VR message boxes visible without pausing the game |
| 2026-09-20 | MrMartexX | Accumulate pending quest lifecycle boundaries |
| 2026-09-21 | MrMartexX | Fence pre-load admission callbacks |
| 2026-09-22 | MrMartexX | Track exact pre-load admission attempts |
| 2026-09-21 | MrMartexX | add ordered lifecycle queue primitive |
| 2026-09-22 | MrMartexX | Keep lifecycle queue identity fixed |
| 2026-09-22 | MrMartexX | add native load request correlation contract |
| 2026-09-22 | MrMartexX | add native load bridge ABI policy |
| 2026-09-22 | MrMartexX | require target-return load completion capability |
| 2026-09-22 | MrMartexX | Document load identity tail semantics |
| 2026-09-15 | Sergio Rayo | Include <cstring> for std::strlen in SubtitleManager (#854 merge follow-up) |
| 2026-09-22 | Sergio Rayo | Add sit and sleep state helpers to ActorState |
| 2026-09-22 | Sergio Rayo | Reset the stale seated pose of remote actors on replay |
| 2026-09-22 | MrMartexX | add bounded native load identity capture |
| 2026-09-23 | MrMartexX | define native load export ABI contract |
| 2026-09-23 | MrMartexX | Add native load bridge adapter core |
| 2026-09-23 | MrMartexX | add native load bridge owner state reducer |
| 2026-09-23 | MrMartexX | formalize native load drain capability |
| 2026-09-23 | MrMartexX | bind native load reserve capability to identity |
| 2026-09-23 | MrMartexX | bind native load effects to exact plan sequence |
| 2026-09-23 | MrMartexX | test native load adapter owner contract |
| 2026-09-23 | MrMartexX | correlate native load foreign outcomes to plan |
| 2026-09-24 | MrMartexX | Regress corrupted load call capability padding |
| 2026-09-24 | MrMartexX | derive native load runtime fingerprint from executable identity |
| 2026-09-24 | MrMartexX | Make inventory header self contained for standalone tests |
| 2026-09-30 | MostExcellent | RE: add IPostAnimationChannelUpdateFunctor::DoPostAnimationChannelUpdate, rename Actor::unk78 (correctly) to postAnimationChannelUpdateFunctor |
| 2026-09-30 | MostExcellent | remove unused SAVE_STUFF and related code, Actor::Save_Reversed would not compile anyway. |
| 2026-09-30 | MostExcellent | remove unused externs from DebugService.cpp |
| 2026-09-30 | MostExcellent | Remove commented SetLeveledCreature hook lines, unused RealSetLeveledCreature and the now unused TU scope TSetLeveledCreature typedef |
| 2026-09-30 | MostExcellent | Remove no-op FindTargets and GetPerkRank hooks from MagicTarget.cpp |
| 2026-10-01 | MostExcellent | ActionEvent: remove undefined Load/Save declarations + rule of 0 |
| 2026-09-29 | MostExcellent | Remove dead code relating to old animation RE investigations. RE documentation TODO if desired. |
| 2026-09-29 | David Glover | Undo unintentional hkEventContext changes |
| 2026-09-30 | MostExcellent | fix: GamePtr move ctor initialization before swap, make operators able to be used for const T ptr or ref, make bool operator explicit, move assign noexcept |
| 2026-10-03 | Wookie1411 | M2 step 1: log load-door activations by the local player (untested) |
| 2026-10-03 | Wookie1411 | M2 step 2: hold load doors while in a party with a partner (untested) |
| 2026-10-03 | Wookie1411 | Fast travel step 1: log answers to the fast-travel prompt (untested) |
| 2026-10-03 | MostExcellent | fix DesiredTarget not initialized in MagicService::OnSpellCastEvent, preventing unnecessary logging and incorrect targets being sent if the uninitialized value does happen to match a valid ID |
| 2026-10-03 | Daniil Zakharov | Move to header |
| 2026-10-04 | TheSporkBard | Target Enderal Special Edition in launcher |
| 2026-10-04 | TheSporkBard | Allow Enderal plugin layout during smoke testing |
| 2026-10-05 | GhostWriter42 | Sync persistent quest-item pickups to party members |
| 2026-01-02 | liangchen | prevent teammates from syncing QuestStop events for incomplete quests |
| 2026-01-02 | liangchen | remove redundant check |
| 2026-10-05 | GhostWriter42 | Add TESQuest::IsCompleted() and restore the completed-quest check |
| 2026-10-05 | GhostWriter42 | fix(party): block cross-party actor ownership claims |
| 2026-10-05 | GhostWriter42 | fix(party): clear stale remote OwnerPlayerId on leave |
| 2026-10-05 | GhostWriter42 | fix(party): null-check WorldEncountersEnabled global on party info |
| 2026-10-05 | GhostWriter42 | fix(party): make server party invites actually expire; drop leaver's invites |
| 2026-10-05 | GhostWriter42 | fix(party): server PartyService stale-party and cross-party kick guards |
| 2026-10-05 | GhostWriter42 | fix(ownership): purge disconnected player from InvalidOwners |
| 2026-10-05 | GhostWriter42 | fix(beastform): guard OnBeastFormChange against missing player entity |
| 2026-10-05 | GhostWriter42 | fix(party): use hopscotch iterator value() for mutable Party access |
| 2026-10-05 | GhostWriter42 | fix(party): server consume party invite on accept |
| 2026-10-05 | GhostWriter42 | fix(party): client PartyService init leader id, clear player list on disconnect |
| 2026-10-05 | GhostWriter42 | fix(party): server reject expired invite on accept |
| 2026-10-05 | GhostWriter42 | fix(party): client drop consumed invite on party join |
| 2026-10-11 | mailamea10 | launcher: pre-bind System32 dwmapi.dll to avoid shadowing by extra DLL directories |
| 2026-10-14 | Mariagrazia Grasso | fix(sync): remove remote actors outside view |
| 2026-10-14 | Mariagrazia Grasso | fix(sync): preserve factions while NPCs load |
| 2026-10-14 | Mariagrazia Grasso | fix(sync): reject stale owner animation events |
| 2026-10-14 | gherman7755 | Keep container contents on the server and merge shared storage |
| 2026-10-14 | Mariagrazia Grasso | fix(sync): skip unavailable actors in weapon state polling |
| 2026-10-14 | Mariagrazia Grasso | fix(sync): cache only accepted NPC actions |
| 2026-10-14 | Mariagrazia Grasso | fix(sync): validate spell casting sources |
| 2026-10-14 | Mariagrazia Grasso | fix(sync): clear queued effects after disconnect |
| 2026-10-14 | Mariagrazia Grasso | fix(sync): activate quests on remote stage updates |
| 2026-10-14 | Mariagrazia Grasso | fix(sync): clear animation queues on disconnect |
| 2026-10-14 | Mariagrazia Grasso | fix(client): avoid null iteration for empty game arrays |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): guard custom enchantment array resize |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): reject unresolved enchantment effects |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): restore lazy summon command target |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): reject stale actor movement snapshots |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): guard unavailable cells during grid shifts |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): guard the initial player cell lookup |
| 2026-10-15 | Mariagrazia Grasso | fix(quest): guard empty player objective entries |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): guard actor discovery before player load |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): skip player updates before player load |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): defer auth until player is ready |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): update actor cell before visibility event |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): update actor cell on grid shifts |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): notify peers on player grid shifts |
| 2026-10-15 | Mariagrazia Grasso | fix(sync): use effective actor cell in movement snapshots |
| 2026-10-15 | Mariagrazia Grasso | fix(inventory): suppress duplicate NPC pickup events |
| 2026-10-16 | Daniil Zakharov | Fix scene type redefinition after rebase onto dev |
| 2026-10-20 | absol89 | feat: player name tags (port of v1.8.1 NameTagService onto dev) |
| 2026-10-21 | absol89 | Adapt PR 932 to the playtest's dropped-item sync |
| 2026-10-24 | gherman7755 | Keep the owner's actor values when conforming a leveled NPC |
| 2026-10-30 | Fallout Together Reborn Contributors | Client: add TP_NO_OVERLAY_RENDER diagnostic switch |
| 2026-10-30 | Fallout Together Reborn Contributors | Quests: start stopped quests before applying a remote stage |
| 2026-10-30 | Fallout Together Reborn Contributors | Memory: hook realloc as well |
| 2026-10-30 | Fallout Together Reborn Contributors | Memory: send foreign blocks back to the CRT |
| 2026-10-30 | Fallout Together Reborn Contributors | Check the package build on connect and explain refusals |
| 2026-10-30 | Fallout Together Reborn Contributors | Ignore the package output |
| 2026-10-30 | barneym | Let the party leader own world encounter spawns |
| 2026-10-30 | barneym | Continue past thread naming exceptions in the launcher |
| 2026-10-31 | barneym | Save together with the party |
| 2026-10-31 | HAB3X | Let side-by-side test clients use separate gamepads and F4 |
| 2026-10-31 | HAB3X | Find the game's XInput import instead of assuming xinput1_3 |
| 2026-10-31 | barneym | Repaint a remote player's face after its head is rebuilt |
| 2026-10-31 | HAB3X | Add a follow-the-leader mode for solo testing |
| 2026-10-31 | SupperCraft5000 | Track the package sources |
| 2026-10-31 | SupperCraft5000 | Starter: connect over the Steam network |
| 2026-10-31 | SupperCraft5000 | Starter: make room for the Steam option |
| 2026-10-31 | HAB3X | Log follow mode's distance from the leader |
| 2026-10-31 | HAB3X | Find Papyrus natives whatever case the engine stored their names in |
| 2026-10-31 | HAB3X | Keep NPCs animating for others when their owner looks away |
| 2026-10-31 | HAB3X | Turn the follower toward the leader |
| 2026-10-31 | HAB3X | Log when a client joins a party |
| 2026-10-31 | HAB3X | Stop turning the follower toward the leader |
| 2026-10-31 | HAB3X | Stop actors that can't sheathe flooding other clients |
| 2026-10-19 | absol89 | Fix crash when a launched projectile can't be found |
| 2026-10-18 | absol89 | Don't equip unresolved spells or shouts on spawned actors |
| 2026-10-28 | absol89 | Fix a crash when an activated object is deleted before its activation is handled |
| 2026-10-21 | absol89 | Fix crash when a remote actor is teleported into an unloaded exterior cell |
| 2026-09-15 | Sergio Rayo | Restore the weapon state when a forced draw or sheathe is refused (#810) |
| 2026-10-27 | Ryan McGee | Allow server settings to be overridden with environment variables |
| 2026-11-02 | DJLegends | Sync mod animation events and add a /wave chat command |
| 2026-10-03 | absol89 | fix: restore torso-less remote player bodies in validation build |
| 2026-10-05 | GhostWriter42 | Fire BeastFormChangeEvent on beast-form leave after the race reverts |
| 2026-10-17 | absol89 | Don't party-sync the Riften North Gate guard scene quest |
| 2026-11-02 | absol89 | The console follows SkyrimTogetherTweaks.ini |
| 2026-11-02 | HAB3X | Ship the Opus licence notice with the client |
| 2026-11-02 | absol89 | Stop sending truncated client messages |
| 2026-11-02 | absol89 | Sync exterior locks across nearby cells |
| 2026-11-03 | Apocryn | Fix remote horses sliding without moving their legs |
| 2026-11-04 | HAB3X | Don't hand out a remote actor the game failed to place |
| 2026-11-04 | HAB3X | Don't block in the crash handler |
| 2026-11-04 | HAB3X | Don't spawn dead actors that are disabled locally |
| 2026-11-04 | HAB3X | Don't restart completed run once quests from party updates |
| 2026-11-05 | HAB3X | Don't teleport remote actors into a worldspace the player isn't in |
| 2026-11-04 | absol89 | Make poisons apply to other players in PvP |
| 2026-11-05 | jotagalindo | Make the F2 UI usable on ultrawide screens |
| 2026-11-05 | jotagalindo | Point TiltedUI at the ultrawide overlay fix for testing |
| 2026-11-05 | absol89 | Declare the world position of NiAVObject |
| 2026-11-07 | Maddie | Enable server diagnostics before configuration is loaded |
| 2026-11-07 | Maddie | Keep distinct enchantment payloads separate in inventory state |
| 2026-11-07 | Maddie | Preserve transfer quantities after reading item metadata |
| 2026-11-07 | the3venthoriz0n | server: add opt-in player-to-player inventory transfers |
| 2026-11-08 | NutyoPR | Respawn the puppet for any non-playable (beast) race, not just vanilla werewolf/vampire lord |
| 2026-11-11 | the3venthoriz0n | server: expose CalendarService AdvanceHours and HoursUntil to Lua |
| 2026-11-11 | the3venthoriz0n | server: add DateTime::AdvanceHours and HoursUntil with tests |
| 2026-11-14 | HAB3X | Subtract damage from the server's stored health instead of adding it |
| 2026-11-14 | HAB3X | Add a build_version option so a branch build can report a release version |
| 2026-11-14 | the3venthoriz0n | Skip destroyed magic items in combat scoring instead of crashing |
| 2026-11-14 | the3venthoriz0n | CombatMagicItemGuard: also reject destroyed forms |
| 2026-11-14 | the3venthoriz0n | Skip combat magic items for remotely owned actors; shared crash guard config |
| 2026-11-15 | HAB3X | Run the game's actor update for dead remote NPCs |
| 2026-11-09 | Zenderal | fix(client): give bow aim controllers a fresh weapon bone |
| 2026-11-09 | friendlycocktails-lgtm | fix(client): don't hook ID 37448, it is GetSubmergedLevel, not attribute regen |
| 2026-11-09 | Zenderal | fix(client): don't keep the caster in the queued SpellCastEvent |
| 2026-11-09 | Zenderal | fix(client): don't sync actions that have no actor or no BGSAction |
| 2026-11-10 | friendlycocktails-lgtm | fix(client,server): remove a deleted temporary actor for every player |
| 2026-11-16 | HAB3X | Let non-host players loot corpses of remotely killed NPCs |
| 2026-11-16 | HAB3X | Log why a remote actor could not be spawned |
| 2026-11-17 | Zeus Hernández | Fix a crash on loading a save with a reference left in a freed cell |
| 2026-11-02 | HAB3X | Relay proximity voice chat through the game server |
| 2026-11-02 | HAB3X | Add built-in proximity voice chat to the client |
| 2026-10-05 | Vincent Hengel | Overlay: toggle only on a release that follows a press |
| 2026-11-22 | absol89 | Stop moving NPCs into an interior the player isn't in |
| 2026-11-22 | absol89 | Only skip the interior move for actors this client found itself |
| 2026-11-24 | Zeus Hernández | Fix crashes when another player teleports away |
| 2026-11-26 | Vincent Hengel | Stop relaying activations of temporary objects |
| 2026-11-25 | Apocryn | Keep NPCs dead after every player leaves their cell |
| 2026-09-15 | Sergio Rayo | Advance the shared time when a player sleeps or waits (#467) |
| 2026-10-31 | Constructor | Skip time together once every player sleeps or waits |
| 2026-10-31 | Constructor | Declare SleepWaitMenu as a struct, RTTI.h already names it |
| 2026-11-21 | Constructor | Use the shared GFxValue and FxDelegateArgs types in the sleep/wait hook |
| 2026-11-21 | Constructor | Skip time on public servers once most players sleep or wait |
| 2026-11-21 | absol89 | Let players on 1.6.1170 vote to sleep or wait together |
| 2026-11-22 | Constructor | Start a shared sleep from the menu's update instead of a job thread |
| 2026-11-21 | Constructor | Pause the world while every player is in a pausing menu |
