# World of Warcraft: Forever, addon API notes

What we know about the client this addon targets. **Verify on the live client** before relying on
anything marked (beta) or (unverified). Add findings here as you make them, with date and build.

## Client

- Product `wowf`, folder `_forever_`, **client 1.60.1, build 70790** (from `.build.info`; `GetBuildInfo()` says built "Nov  3 2026").
  Live since 2026-11-04 (patch 1.60.1).
- TOC `## Interface: 16001`.
- It's the **modern Mainline engine** (12.x / Midnight-era API) with Classic-like content, not the Classic
  Era API. Retail-style addon code mostly works; Classic globals mostly don't.
- Detection: `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18 on live 70790; it was 1 on early beta),
  so compare the named constant, not the number. `select(4, GetBuildInfo())` returns 16001, so Retail
  checks like `>= 100000` fail. Prefer probing for the API you need.

## Player identity (probed 2026-11-06, build 70790)

- Characters have **surnames**. `UnitName("player")` and `UnitFullName("player")` both return `"Hjelp", "Plask"`:
  the second value is the **surname, not the realm** (unlike Retail).
- `CHAT_MSG_ADDON` sender: `"Hjelp Plask"` for the same realm (first + space + surname, no realm suffix).
  Other realms presumably `"First Surname-Realm"` (unverified).
- `GetRealmName()` = `"CAMWOW EU4 Realm 1 PvE"`, `GetNormalizedRealmName()` = `"CAMWOWEU4Realm1PvE"`.
- `GetGuildInfo("player")` returns the guild's **home realm** as the 4th value (`CAMWOWEU4Realm5PvE`), which can
  differ from the player's realm. The guild spans connected realms.
- `GetAutoCompleteRealms()` returns a table (connected realms, normalized).
- `UnitGUID("player")` looks like `Player-6841-001BD719`. `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT == 18`.
- **Realms are ignored** (decided 2026-11-06). On Forever they're an under-the-hood detail: players move between them
  without noticing, and only the ruleset is visible. A key with a realm in it can change silently. Player key =
  `"First Surname"` (`ns.PlayerKey`). Guild key = guild name. `ns.NormalizeName` strips a sender's `-Realm` suffix.
  A suffix counts as a realm if it's a known/connected realm or matches the `CAMWOW…<digit>…` pattern, so
  hyphenated surnames survive.
- **Full names ("First Surname") are unique across all rulesets** (per the user, 2026-11-06), because characters can
  transfer between rulesets fairly freely. So the key is safe.
- **Guilds don't span rulesets.** A guild name is only unique within its ruleset, so two guilds on different rulesets
  could share a name and, with it, the same `DyreparkenDB.guilds` entry. That only matters for one account with alts in
  same-named guilds on two rulesets. We accept that for now.

## Companion journal frames (probed 2026-11-06)

- Retail-style: `CollectionsJournal`, `PetJournal`, `PetJournal.ScrollBox`, `PetJournalPetCard`,
  `PetJournalSummonButton` all exist once `Blizzard_Collections` loads.
- Full `C_PetJournal` set, including `GetPetInfoBySpeciesID`, `GetNumCollectedInfo` (returns `1, 1` for a pet you own),
  `PetIsSummonable`, `GetPetSummonInfo`, `FindPetIDByName`, `SetCustomName`.
- (probed 2026-11-07) The Collections tabs (Pets, Mounts, Toys, ...) are icon tabs down the window's
  **right** edge, not at the bottom as on Retail. They sit in an unnamed strip frame, a direct child of
  `CollectionsJournal` (window 703x606, title bar about 21 px), as tall as the window and 55 px wide.
  - Tabs are **Frames** (not Buttons) named `CollectionsJournalTab1`, `2`, `3`, `5` (4 is hidden): Mounts, Pets,
    Toys, ... 55x55, 2 px apart, no children.
  - Regions: BACKGROUND atlas `common-sidetab`; ARTWORK the icon (50x50) masked by `common-sidetab-mask`;
    two OVERLAY `common-sidetab-selected` (shown on the selected tab); HIGHLIGHT `common-sidetab-hover`.
    The atlases are 55x60.
  - `/dp probe tabs` logs all of this. `Achievements/Page.lua` finds them by position (no names needed).
- (seen 2026-11-07) `BasicFrameTemplateWithInset` and `UIPanelScrollFrameTemplate` work (mouse wheel too), but
  look older than the journal.

- (probed 2026-11-08, `/dp probe card`) `PetJournalPetCard`'s title row is a Button `PetInfo`
  (`PetJournalPetCardPetInfo`, at TOPLEFT 6,-6, 208 wide) holding `icon` (38), `name`, `subName` (hidden), `favorite`,
  `isDead`, `new` and `newGlow`. The card's own frame art is `ShadowOverlay` (TopLeft/TopRight/... corners,
  `PetJournalPetCardTop` and so on), and `PetBackground` is its background texture. The model is `modelScene`
  with `RotateLeftButton`/`RotateRightButton`. We hide `PetInfo` (JournalUI).

## Lua

- **Lua 5.1** (WoW-modified): no `goto`, no `//`, no bitwise operators (`bit.band`, `bit.bor`, …), no `_ENV`,
  no `require`/`dofile`/`loadfile`, no `io`/`os` (except `date`, `time`, `difftime`, `clock`). The TOC is the module loader.
- Each file gets `local addonName, ns = ...`.
- WoW extras: `strtrim`, `strsplit`, `wipe`, `CopyTable`, `tinsert`, `format`, `C_Timer`, etc.
- 200-locals-per-function limit (applies to file main chunks too): keep modules on `ns`.
- After 100 Lua errors in a session the client stops reporting them until /reload.

## Secret values (Midnight restrictions, active on Forever)

- Some values are "secret": `type()` reports number/string/boolean, but arithmetic, comparison, boolean tests,
  indexing and table keys **throw**. Printing a secret throws. Storing, passing and concatenating are allowed.
- Known secret: `UnitHealth`/percent/missing (player and target), target `UnitHealthMax`, possibly unit names,
  `UnitCanAttack`/`UnitExists` (contextual). Auras are inaccessible while `C_Secrets.ShouldAurasBeSecret()` is true
  (includes your own buffs; `UNIT_AURA` payload tables can be secret). AutoCompanion notes this happens in combat.
- Guard with `issecretvalue(v)` / `canaccessvalue(v)` before branching on unit data. We avoid unit queries in
  combat entirely.
- `COMBAT_LOG_EVENT_UNFILTERED` / `CombatLogGetCurrentEventInfo` are unavailable.

## Missing or renamed APIs

(The test harness's `H.MISSING`, tools/test/harness/base.lua, lists what's missing here and below; 01_core
checks the stub client lacks it. Add new finds there too.)

- Missing: `GetSpellInfo` (use `C_Spell.GetSpellInfo`, which returns a table), `GetItemInfo` (`C_Item.GetItemInfo`),
  `UnitAura` (`C_UnitAuras`), `GetMerchantItemInfo`, Classic craft/tradeskill APIs, `GetSpecialization`.
- Registering an unknown event **throws** and aborts the file: `ns.Events:On` pcalls registration.
- `GetMouseFoci()` returns a table (top region first).
- `ReloadUI()` is protected (no Reload buttons); users type /reload.
- Settings: `Settings.RegisterCanvasLayoutCategory` / `Settings.RegisterAddOnCategory` exist.
- The Addon Compartment TOC fields exist (`AddonCompartmentFunc` …); whether the button shows is unconfirmed.
- The card's model scene (probed 2026-11-10, `/dp probe pos`): the actor has `GetPosition`/`SetPosition` (works:
  the pet visibly moves), `GetScale`, `GetActiveBoundingBox`, `GetMaxBoundingBox`, `SetYaw`; the scene has
  `Project3DPointTo2D` (answers in pixels: the scene's size × its effective scale, x matched) and `GetViewInsets`
  (0, 0, 300, -50). Blizzard puts each model at its own height and camera (Brown Prairie Dog z 0.5, zoom 24;
  Zergling z 2.5, zoom 20). The projected box did NOT match where the pet shows (y off by 60-200 px, differently
  per pet), so neither its feet nor its head can be found from it: per-species `lift` by eye instead.
- The pet's height on the card belongs to its **model scene** (`modelScene:GetModelSceneID()`, works; 1271 for the
  Brown Prairie Dog), not to the pet (2026-11-10, the user paging between pets): Blizzard sets the actor's position
  only when the card changes scene, so between two pets of one scene the actor stays where an addon put it. Heights
  per scene come in round values (0.5, 1, 1.5, 2.5). Moves reads each scene's height as it arrives.
- Verified 2026-11-10 (the user, in game): the card's pet walks and runs with you, and stops after a flight path
  (`PLAYER_STARTED_MOVING`, `PLAYER_STOPPED_MOVING`, `PLAYER_CONTROL_GAINED`, `GetUnitSpeed`).
- The card scales a model to its size as it loads (2026-11-10): an animation playing at that moment changes the
  size it measures. A pet shown mid-walk came out at scale 13.4 instead of 19.5 (Brown Prairie Dog), and stayed so
  until loaded again. So nothing but standing plays during `Moves.SETTLE` after a new model.
- A pose frozen with `SetAnimation(id, 0, 0, offset)` (speed 0) doesn't hold (2026-11-10, the user): the pet lay
  still for about a second, then stood up to its idle. Asleep now pauses the actor (`ModelSceneActor:SetPaused`,
  retail's) when it has it; unverified on Forever (`/dp probe anim sleep` says which way it holds).
- (2026-11-10, the roll and fishing eggs; a loot roll of 1 verified 2026-11-11: `roll +1` logged in Gnomeregan)
  `RANDOM_ROLL_RESULT` in CHAT_MSG_SYSTEM ("Hjelp Plask rolls 1
  (1-100)", the user), `LOOT_ROLL_ROLLED_NEED/GREED/DE` in CHAT_MSG_LOOT ("Need Roll - 1 for [item] by Name"), and
  `ERR_FISH_ESCAPED` / `ERR_FISH_NOT_HOOKED` as UI_ERROR_MESSAGE (type, text), a catch as LOOT_OPENED.
- Relied on since 2026-11-10 (each degrades to nothing when missing). **Verified 2026-11-11** (the pet walks, runs
  and jumps with you on the card and the pet frame, the user): `PLAYER_STARTED_MOVING`, `PLAYER_STOPPED_MOVING`,
  `GetUnitSpeed("player")`, a `hooksecurefunc("JumpOrAscendStart")` firing on every jump, and `GetBindLocation()`.
  Still unverified: `PLAYER_CONTROL_GAINED` (2026-11-10: after landing from a flight path no stop came, so landing
  re-reads the speed);
  `ModelSceneActor:GetYaw/SetYaw` (the pet turning its back after a dislike); the enUS zone names in `Quirks.HOME_ZONES`; custom emotes (`SendChatMessage(..., "EMOTE")`)
  reaching nearby players as `CHAT_MSG_EMOTE` with a "First Surname" sender (a guildmate's /dp klapp, Bonds.lua).

## Companions (C_PetJournal)

From AutoCompanion (written for Forever, in this AddOns folder):
- Available: `C_PetJournal.GetOwnedPetIDs`, `GetPetInfoByPetID`, `GetPetInfoByIndex`, `GetNumPets`,
  `GetSummonedPetGUID`, `SummonPetByGUID`, `PetIsFavorite`, `PetIsRevoked`.
- **No pet battles, caging, releasing or trading** → one copy per companion, no `GetPetStats`.
- **speciesID works** (probed 2026-11-06, build 70790). `GetPetInfoByPetID` returns the Retail field order:
  `speciesID, customName, level, xp, maxXp, displayID, isFavorite, name, icon, petType, creatureID, sourceText, ...`
  e.g. Panda Cub = `5159, nil, 1, 0, 1, 146955, false, "Panda Cub", 7831521, 5, 272330, ""`.
  The IDs are Forever's own numbering (not Retail's), shared by every Forever client. We key pets as `s:<speciesID>`.
  AutoCompanion keys by English name, probably because its external zone data is name-based.
- Pet GUIDs look like `BattlePet-0-00000008B2A2`.
- `SummonPetByGUID` **toggles**: on the pet that's out, it dismisses it.
- Summoning is blocked in combat. There's a short companion-only cooldown (~1.1 s, up to 2.5 s) that starts
  when the pet appears; acting inside it gives "Ability is not ready yet".
- Summon sound file IDs on Forever: 567569, 568424 (AutoCompanion mutes them).
- Journal: `Blizzard_Collections` is load-on-demand. Frame names are above. The ScrollBox button layout is still
  unverified: check with `/fstack`.
- `C_PetJournal.SetCustomName` exists. We still use our own synced nicknames.

## Journal list, roster and companion units (probed 2026-11-06, build 70790)

- `PetJournal_InitPetButton(button, elementData)` and `PetJournal_UpdatePetCard` exist (hookable). List buttons
  carry `.petID`, `.speciesID`, `.owned`, `.index`.
- **The Summon/Dismiss button (`PetJournalSummonButton`) sits at the bottom left of the journal**, under the list
  (unlike Retail). Our buttons are anchored to its right.
- Guild roster: `GetGuildRosterInfo(i)` names are `"First Surname"` (no realm). `GetNumGuildMembers()` = 41 total,
  6 online, and the full read was 41/41. `GetGuildRosterLastOnline(i)` returns nils for online members and
  `years, months, days, hours` for offline ones (e.g. `0, 0, 0, 10` = 10 hours ago). Under an hour gives `0, 0, 0, 0`.
- `PetJournal_InitPetButton` / `PetJournal_UpdatePetCard` only exist after `Blizzard_Collections` loads.
- Another player's companion as `target`: `UnitIsBattlePetCompanion` = true, `UnitBattlePetSpeciesID` = 46
  (White Kitten), `UnitCreator` = nil, GUID `Creature-0-6864-1-2-7386-…` (npcID 7386). Tooltip lines:
  `"White Kitten"`, `"Gnikke Guri's Companion"`, `"Pet Level 1 Critter"`. The owner comes from line 2, matched with
  `UNITNAME_TITLE_COMPANION`.
- **Rewriting a unit tooltip's lines** (2026-11-08, build 70862): change the font strings (`GameTooltipTextLeftN`)
  *and* the post-call's `data.lines` (text and `lineIndex`). Tooltip addons that draw their own panel read the data:
  PrettyTooltip takes the title from `data.lines[1]` and appends any native line whose `lineIndex` the data doesn't
  list, so changing only the font strings left the old title and showed a moved line twice. With both changed, the
  nickname shows as the title in PrettyTooltip as well.
- A companion the client has no creature name for (2026-11-09: Azurky, species 5179, hidden from the journal) shows
  "Unknown" (`UNKNOWNOBJECT`) on its nameplate and as its tooltip title. Its `UnitBattlePetSpeciesID` still works,
  so Tooltip.lua puts the species' name (`GetPetInfoBySpeciesID`) in the title; whether that returns a name for a
  hidden species on Forever is unverified. The nameplate stays the game's.
- **Unit and journal species IDs match**: your own Panda Cub as a unit reports `UnitBattlePetSpeciesID` = 5159, the
  same as the journal. Its GUID is `Creature-0-6845-1-1-272330-…`, and npcID 272330 equals the journal's creatureID.

- **Showing a species' card** (2026-11-09, build 70862): `PetJournal_SelectSpecies(PetJournal, speciesID)` works for a
  pet you own (scrolls the list, shows the card). For one you don't own, which isn't in Forever's list, it left the
  card on the last pet viewed, unlike retail (where it ends in `PetJournal_ShowPetCardBySpeciesID`). JournalUI then
  calls `PetJournal_ShowPetCardBySpeciesID` itself and logs the card's species after each call; whether that works
  on Forever is unverified.
- **Animating the pet on the card** (2026-11-10, `/dp probe anim`): the actor is
  `PetJournalPetCard.modelScene:GetActorByTag("unwrapped")`. It has `SetAnimation` and `GetAnimation`, but **no
  `HasAnimation`**, and `SetAnimation` takes any id without an error, so code can't tell what a model has from the call
  alone. By eye (one pet, 2026-11-10), what visibly plays: 1 Death, 4 Walk, 5 Run, 37-39 the jump, 96-98 sitting
  down / sitting / getting up, 99-101 lying down / sleeping / getting up, and the pet battle 744 Death, 746 Run,
  748 Wound, 750 Attack, 752 ReadySpell, 754 SpellCast, 756-762 Custom0-3, 770 Dead. Nothing: every emote (60-186:
  talk, bow, wave, cheer, dance, laugh, roar...), and 742 PetBattleStand, 764 Victory, 766 Loss, 768 Stun,
  772 Freeze (0 Stand is the rest pose). Ids from wowdev.wiki/M2/AnimationList. Other species may differ; whether
  `GetAnimation` only echoes the id set (both pets, every id), so it can't tell either. One-off animations (99 lying
  down) end by standing the pet up again, and Sleep (100) didn't hold: a pet "asleep" lies as PetBattleDead (770),
  which holds on every pet tried. (The Panda Cub's PetBattleCustom0 is a joyful hop; Mini Diablo's a roar.)
  Correction, same night: 770 lies the Panda Cub down, but Mini Diablo and the Zergling only sink small below their
  floor shadow, and the prairie dog gets up after a second or two. **Dead (6)** lies most pets down and holds; Mini
  Diablo vanishes with it. **Death (1)** plays each model's own fall (Mini Diablo bursts into flames). The
  Zergling's PetBattleCustom0 is an attack. Per-species choices live in Data/PetMoves.lua.
  **Holding a pose** (2026-11-10, 1.60.1, prairie dog, Zergling, Panda Cub): Dead (6) doesn't hold after all: played
  normally the pet goes flat, then the animation ends and it stands up (~0.6 s). The actor takes
  `SetAnimation(id, variation, speed, offsetSeconds)` and `SetAnimationBlendOperation(op)` (retail's
  Enum.ModelBlendOperation: 0 None, 1 Anim); both return without an error. Speed 0 alone froze the pet standing,
  only a slight jitter: the blend from standing froze too. With blend 0 (None), `SetAnimation(6, 0, 0, 1.2)` holds
  it lying still: before 1.2 s it's caught mid-fall. Blend 0 is set only for such a held pose, 1 otherwise.
- **Companions get no nameplate** (2026-11-09, `/dp probe world`, outdoors): with a guildmate's Brown Prairie Dog
  right there, `C_NamePlate.GetNamePlates()` returned 0 plates and `GetNamePlateForUnit("mouseover")` nil, while
  hostile mobs nearby got plates (`NAME_PLATE_UNIT_ADDED`, not forbidden). `nameplateShowAll` and
  `nameplateShowFriendlyNPCs` were 1; `nameplateShowFriends`, `nameplateShowFriendlyPets`, `...Minions`,
  `...Guardians` and `nameplateShowOnlyNames` don't exist (nil). `UnitNameFriendlyPetName` = 1, so the "nameplate"
  showing a companion's name above it is the floating unit name, which addons can't reach. So there's no frame over a
  companion to draw on. **The mouse is**: `UPDATE_MOUSEOVER_UNIT` fires over a companion with plain values
  (`UnitIsBattlePetCompanion` true, species 70, the owner from the tooltip, `GetCursorPosition()`).

## All species (full export, 2026-11-06, build 70790, enUS)

- Every journal filter API exists: `SetFilterChecked`/`IsFilterChecked` (`LE_PET_JOURNAL_FILTER_COLLECTED` /
  `_NOT_COLLECTED`), `SetAllPetTypesChecked`, `SetAllPetSourcesChecked`, `GetNumPetTypes`, `GetNumPetSources`,
  `IsPetTypeChecked`, `IsPetSourceChecked`, `SetPetTypeFilter`, `SetPetSourceChecked`, `ClearSearchFilter`. With
  all of them on, `GetNumPets()` counts uncollected pets too, and right away (no wait for an update event).
- **The journal lists 83 companions**: that's the "y" for "x of y". Sweeping `GetPetInfoBySpeciesID` over 1..20000
  finds 119 species. The 36 extra are hidden, e.g. an older Panda Cub (92, while the obtainable one is 5159), Murky,
  Zergling 94, the Ent/Furbolg pets and the Tiny dragons. Species IDs run from 39 to 5203.
- **Source and description text are empty strings for every species** (`tooltipSource`, `tooltipDescription`),
  so the client can't tell where a pet comes from. Use outside data (wowhead) for that.
- Pet types are almost all Critter (110 of 119), so they're useless for grouping. Use our own tags.
- **The journal has no Filter button** (seen 2026-11-06, build 70790), so players are always on the default
  filters and can't fix a wrong one in the UI. The filter API works (`SetFilterChecked`, `SetAllPetTypesChecked`,
  `SetAllPetSourcesChecked`, `SetSearchFilter`, `SetDefaultFilters`, `IsUsingDefaultFilters`) and its state is
  saved across sessions.
- **Changing filters and putting them back one by one is not safe.** On 2026-11-06 a dev tool opened every
  filter, then restored collected / not collected / each type / each source from what it had read. The list was
  then empty (`GetNumPets()` = `0, 4`), even after switching all of those on again, and the three filter CVars
  showed their defaults. Some filter outside those was left changed. Only `C_PetJournal.SetDefaultFilters()`
  brought the list back.
  Rule: don't touch journal filters in the addon. Read species with `GetPetInfoBySpeciesID` / `GetOwnedPetIDs`
  instead. If filters must be changed (dev tools only), end with `SetDefaultFilters()` and check `GetNumPets()`.
  Recovery for a player: `/run C_PetJournal.SetDefaultFilters()`.

## Addon messages

- `C_ChatInfo.RegisterAddonMessagePrefix(prefix)`: max 16 chars. Messages max **255 bytes**, any byte except `\0`.
- `C_ChatInfo.SendAddonMessage(prefix, msg, chatType, target)` returns `Enum.SendAddonMessageResult`:
  0 Success (only means queued), 3 AddonMessageThrottle, 5 NotInGroup, 8 ChannelThrottle, 10 NotInGuild,
  11 AddOnMessageLockdown (when it applies is undocumented; log it if seen), 12 TargetOffline.
- Throttle: **per prefix, 10 messages, +1 per second**, all chat types. The server may change these. Too much data
  across prefixes can disconnect. Always send through ChatThrottleLib (we do, via `ns.Comm`).
- Chat types: PARTY, RAID, INSTANCE_CHAT, GUILD, OFFICER, WHISPER. No CHANNEL broadcast assumed.
- **Trial and Veteran accounts can't send addon messages** on Forever (patch 1.60.1). They can still receive.
- Messages are untrusted: anyone can send anything on our prefix. Validate types before use.
- **`SendChatMessage(..., "GUILD")` from a timer is blocked** (probed 2026-11-06, build 70790, `/dp probe ach
  post`). It raises `ADDON_ACTION_BLOCKED` ("tried to call the protected function 'UNKNOWN()'"), `pcall` doesn't
  see an error, and nothing reaches chat. So posting needs a hardware event (a keypress or click), like
  SAY/YELL on Retail. **GUILD straight from a slash command works** (`/dp probe ach now`, same day): no error,
  and the line reached guild chat. PARTY/RAID are unprobed (`/dp probe ach group|groupnow`). `/dp rapport`
  no longer posts from a timer: its result dialog's button posts it (2026-11-08).
- `C_ChatInfo.SendChatMessage` exists alongside the global `SendChatMessage`.
- Kill events (2026-11-08, build 70862, `/dp probe kills`): `ENCOUNTER_START`, `ENCOUNTER_END`, `BOSS_KILL`,
  `PLAYER_PVP_KILLS_CHANGED` and `PARTY_KILL` are all valid events. `GetPVPSessionStats()` returns `0, 0` and
  `GetPVPLifetimeStats()` `0, 0` on a character without PvP.
- **What fires** (2026-11-08, build 70862, a 5-player dungeon, kills probe):
  - `ENCOUNTER_START (id, name, difficulty, size)` and `ENCOUNTER_END (id, name, difficulty, size, success, table)`
    fire for dungeon bosses with plain values (e.g. `3482, "Relic Guardian", 1, 5, 1`). A wipe has `success = 0`
    (and, dead, no companion out). The 6th value is a table (unexplored).
  - `BOSS_KILL` never fired: use `ENCOUNTER_END`.
  - `PARTY_KILL` fires for every kill in the group, but **both GUIDs are secret**: who killed what can't be read.
  - `QUEST_TURNED_IN (questID, xp, money)`, plain values.
  - `C_PetJournal.GetSummonedPetGUID()` is **readable in combat** (not secret).
  - Herb gathering is seen through `UNIT_SPELLCAST_SUCCEEDED` registered for the player (`RegisterUnitEvent`), out of
    combat: the activity engine counted it, with the companion out (2026-11-08).
  - Background art: 57 of 66 guessed `Interface\EncounterJournal\UI-EJ-BACKGROUND-*` / `UI-EJ-LOREBG-*` paths for
    classic dungeons and raids exist. The pet battle weathers exist but are small overlays (blurry when stretched);
    the loading screens that exist are the generic splash. `/dp probe bg` shows them in a gallery.
    The art fills only part of each `UI-EJ-BACKGROUND-*` file: Blizzard's journal crops it with TexCoords 0-0.7695
    across, 0-0.8301 down (`dungeonBG`). Shown whole, the art sits in the top left.
  - **Animation groups** (2026-11-08, inferred from what showed, not yet confirmed by the fix): an Alpha animation
    waiting out its `SetStartDelay` seems to apply its
    start value, so a fade-out (from 1) delayed inside a group showed the particle fully opaque and still until it
    began. Build timelines in steps (`SetOrder`) instead of delays within one step.
    Two groups playing on one region and touching the same thing (a Scale in each, a Translation in each) don't add
    up: hearts flickered to full size and swaying leaves jumped sideways or blinked. Give each motion its own region
    (a holder frame for the path, an inner frame for the sway, the texture for spin or throb). Same evening; the
    layered version is still to be seen in game.
    After layering, hearts (Scale), notes and leaves (Rotation, Translation) still blinked, all on `BOUNCE` loops,
    while `REPEAT` spins were smooth: `BOUNCE` seems to blink where it turns. Back-and-forth now is a `REPEAT` loop
    of relative steps that add up to nothing (out, back past the middle, home). To be confirmed in game.
  - **The atlas library is the modern one** (2026-11-08, `/dp probe decor`): 40 of 45 guessed retail atlas names
    exist (`C_Texture.GetAtlasInfo`), e.g. `AftLevelup-*`, `bags-glow-*`, `ArtifactsFX-*`,
    `UI-Frame-DiamondMetal-CornerTopLeft`, `PetJournal-FavoritesIcon`.
- **Traits probe** (2026-11-08, `/dp probe life`): `PLAYER_DEAD`, `PLAYER_ALIVE`, `PLAYER_UNGHOST`,
  `ZONE_CHANGED_NEW_AREA`, `MIRROR_TIMER_START`, `PLAYER_LEVEL_UP`, `CHAT_MSG_GUILD`, `CHAT_MSG_TEXT_EMOTE`,
  `GROUP_ROSTER_UPDATE`, `PLAYER_FLAGS_CHANGED` and `UNIT_SPELLCAST_SUCCEEDED` are valid events. `GetZoneText`,
  `IsResting`, `UnitIsAFK`, `UnitLevel`, `DoEmote` and `JumpOrAscendStart` exist. Out of combat they return plain
  values: zone "Wetlands", `C_Map.GetBestMapForUnit("player")` 1437, `IsInInstance()` `false, "none"`, level 27.
  What fires (same evening, a dungeon run and Orgrimmar):
  - Typed emotes **don't go through `DoEmote`** (the hook never fired). `CHAT_MSG_TEXT_EMOTE` does, with our own
    GUID (12th value) and plain English text: "You burst into dance.", "You dance with Panda Cub.", "You pet Panda
    Cub.", "You hug Panda Cub.", and "/pet" without a target: "You need to be petted."
  - `MIRROR_TIMER_START ("BREATH", 60000, 60000, -1, 0, "Breath")` going under; the same with scale 10 while it
    refills. Fires inside dungeons too.
  - `PLAYER_LEVEL_UP (28, ...)`: the new level. `UnitLevel` still says 27 at that moment.
  - `PLAYER_ALIVE` fires at **every loading screen** (entering an instance, the hearthstone), not just after dying.
    Running back as a ghost gave `PLAYER_ALIVE` + `PLAYER_UNGHOST` on entering the instance.
  - `C_Map.GetBestMapForUnit("player")` is **nil inside instances**; `GetZoneText()` works there ("Excavation Site:
    Wetlands"). Outdoors: Wetlands 1437, Orgrimmar 1454, the excavation site's outside 1414.
  - Hearthstone: `UNIT_SPELLCAST_SUCCEEDED` 8690 "Hearthstone". `CHAT_MSG_GUILD` gives the sender as plain
    "First Surname". `JumpOrAscendStart` hooks fine. The companion is readable at all of these, except right after a
    loading screen (back a moment later).
  - `/afk` in Thunder Bluff: `PLAYER_FLAGS_CHANGED ("player")` with `UnitIsAFK("player")` true and `IsResting()`
    true, the companion readable; again with false on coming back. Our own guild line: `CHAT_MSG_GUILD` with our
    GUID (sender "First Surname"). The `TakeTaxiNode` hook counted a flight path ("taxi").
  - Not seen yet: `PLAYER_DEAD` itself.
- **Skill-ups and reputation** (2026-11-09): read from `CHAT_MSG_SKILL` and
  `CHAT_MSG_COMBAT_FACTION_CHANGE`, matched against the client's own `SKILL_RANK_UP` ("Your skill in %s has
  increased to %d.") and `FACTION_STANDING_INCREASED`, which on Forever reads "Reputation with %s increased by
  %d." (not Retail's wording; `/dp probe life`, 2026-11-09). Both events exist. **Skill-ups verified** the same day:
  a weapon skill-up ("Two-Handed Axes") with the pet out logged `skill +1` and its bond point. **Reputation
  verified** 2026-11-11 (build 1.60.1): `rep +1` logged six times in a session. If Forever lacks the events or the strings, the activities are just unavailable.
- Events that exist (`C_EventUtils.IsEventValid`, 2026-11-06): `NEW_PET_ADDED`, `COMPANION_LEARNED`,
  `PET_JOURNAL_LIST_UPDATE`, `CHAT_MSG_GUILD`.
- Officers: `C_GuildInfo.IsGuildOfficer()` works (true for rank 1). `GetGuildInfo("player")` returns
  `name, rankName, rankIndex, realm`, e.g. `Dyreparken, Dyrepasser, 1, CAMWOWEU4Realm5PvE`. `IsGuildLeader()`
  exists.

## What the client has (`/dp probe api`, 2026-11-11, build 1.60.1 70888, enUS, EU)

The full dump is `DyreparkenDebugDB.api` after a run (`/dp probe api`, then `/reload`). A Tauren shaman,
level 34, in Grom'gol, with their own Brown Prairie Dog out and targeted.

- **Size**: 6195 global functions, 272 `C_*` namespaces (retail's, Housing and Delves included), `Enum`.
- **Missing** (classic or old retail globals): `UnitStandState` (so Summon's sitting check never runs; there is no
  stand state to read), `GetSpellInfo` (use `C_Spell`), `GetItemCount`, `GetContainerNumSlots` (use
  `C_Container`), `GetNumFactions`, `GetWatchedFactionInfo` (`C_Reputation.GetWatchedFactionData` exists),
  `GetNumSkillLines`, `GetSkillLineInfo` (`GetProfessions` works: `5, 7, nil, 8, 6`), `GetZonePVPInfo`, `GetNumAddOns`
  (use `C_AddOns`), `C_Calendar.GetDate` (use `C_DateAndTime.GetCurrentCalendarTime`). The old companion API is
  there but empty: `GetNumCompanions("CRITTER")` is 0; the pet journal is the only way.
- **Works**: `GetBindLocation()` ("Grom'gol Base Camp"), `GetShapeshiftFormID()` (nil outside a form),
  `GetUnitSpeed` (`0, 7, 7, 4.72`), `IsFlying/IsSwimming/IsSubmerged/IsFalling/IsIndoors/IsOutdoors/IsResting`,
  `GetZoneText`/`GetRealZoneText` ("Stranglethorn Vale"), `GetSubZoneText`, `GetMinimapZoneText`,
  `C_Map.GetBestMapForUnit("player")` (1434), `GetGuildRosterMOTD`, `C_DateAndTime` (`GetCurrentCalendarTime`,
  `IsDayTime`, `GetSecondsUntilDailyReset`), `GetStatistic(60)` ("21": deaths), `GetNumCompletedAchievements()` (111):
  Blizzard's achievements exist, `GetTotalAchievementPoints()` is 0.
- **Names**: `UnitName("player")` and `UnitFullName("player")` return first name and **surname** as two values
  ("Hjelp", "Plask"), where retail returns name and realm; `UnitPVPName` is "Hjelp Plask". The roster has
  "First Surname" in one string.
- **Companions as units**: a targeted companion (your own) is `UnitIsBattlePet` and `UnitIsBattlePetCompanion` true,
  `UnitBattlePetSpeciesID` the species (70), `UnitBattlePetLevel` 1, `UnitBattlePetType` 5, `UnitCreatureType`
  "Non-combat Pet", its GUID a `Creature-...`, `UnitName` the species name, and `UnitIsOtherPlayersBattlePet` false
  for your own (not seen yet for someone else's). The owner isn't in any of these: still the tooltip.
  `C_TooltipInfo.GetUnit` exists (structured tooltip lines, untried).
- **Secret values**: `issecretvalue`, `issecrettable`, `hasanysecretvalues`, `canaccesssecrets`, `scrubsecretvalues`,
  `secretwrap`, and `C_Secrets` (`ShouldUnitIdentityBeSecret`, ...) exist.
- **Events**: of about 130 tried, the client refuses only `LEARNED_SPELL_IN_TAB`. That says they exist, not that
  they fire (`UPDATE_SHAPESHIFT_FORM`, `CALENDAR_UPDATE_EVENT_LIST`, `CHAT_MSG_PET_INFO`, `PET_BATTLE_OPENING_START`,
  `HEARTHSTONE_BOUND`, `START_LOOT_ROLL` all accepted).
- **Templates**: all tried exist but `CharacterFrameTabButtonTemplate` and `ItemButtonTemplate`
  (`ButtonFrameTemplate`, `WowStyle1DropdownTemplate`, `MinimalSliderWithSteppersTemplate`, `WowScrollBoxList` do).
- **Global strings** for chat parsing: all present, in retail wording, e.g. `LOOT_ROLL_ROLLED_NEED`
  "|HlootHistory:%d|h[Loot]|h: Need Roll - %d for %s by %s", `LOOT_ROLL_ROLLED_DE` "Disenchant Roll - %d for %s by %s",
  `RANDOM_ROLL_RESULT` "%s rolls %d (%d-%d)", `ERR_FISH_ESCAPED` "Your fish got away!", `ERR_FISH_NOT_HOOKED`
  "No fish are hooked.", `ERR_ZONE_EXPLORED` "Discovered: %s", `ERR_NEWTAXIPATH`, `ERR_DEATHBIND_SUCCESS_S`
  "%s is now your home.", `ACHIEVEMENT_BROADCAST`, `DUEL_WINNER_KNOCKOUT`.
- **The card's actor** (`ModelSceneActor`): no `HasScript` (no script handlers at all, so no `OnAnimFinished`), but
  `SetOnModelLoadedCallback`/`GetOnModelLoadedCallback`, `IsLoaded` (true), `GetPaused` (exists, with `SetPaused`),
  `GetAnimationVariation`, `PlayAnimationKit`/`StopAnimationKit`, `SetSpellVisualKit`, `GetActiveBoundingBox`/
  `GetMaxBoundingBox`, `GetModelFileID` (125434 for the prairie dog), `SetModelByCreatureDisplayID`. Position was
  `0, 0, 0.3`, scale 19.48. The scene is a `ModelScene` (id 1271), camera fov 0.94.
- **PlayerModel** (an invisible one, `SetDisplayInfo` with the journal's display id, 1072 for the prairie dog) has
  `OnAnimFinished`, `OnAnimStarted`, `OnModelLoaded`, `HasAnimation`, `SetAnimation`, `FreezeAnimation`,
  `SetSequenceTime`, `GetPaused/SetPaused`, `PlayAnimKit`. **Animation lengths by OnAnimFinished** (prairie dog):
  PetBattleCustom0 (756) 1.13 s, PetBattleSpellCast (754) 1.13 s, PetBattleWound (748) 1.00 s, Death (1) 1.37 s,
  Stand (0) 2.00 s. Sit down (96) 2.01 s and get up (98) 2.67 s: the prairie dog can't sit, so those are probably
  the fallback stand. `HasAnimation` listed only `0 1 4 5 9 16`, though 756 and 748 played with lengths of their
  own: not to be trusted for the pet battle ids (or it was read too early).
- **Calendar**: `C_Calendar` has `OpenCalendar`, `GetNumDayEvents(offsetMonths, monthDay)`, `GetDayEvent`,
  `GetHolidayInfo`. **Works** (2026-11-11, `/dp probe api calendar`, 3 s after `OpenCalendar`): `GetNumDayEvents(0, 11)`
  was 2, `GetDayEvent` gave tables (`eventID` 263 and 1842, `eventType` 4 = holiday, `sequenceType` "ONGOING",
  `numSequenceDays` 8, `startTime`/`endTime`, `iconTexture`), and `GetHolidayInfo(0, day, i)` their name and
  description: "Darkmoon Faire" ("...this time in idyllic Elwynn Forest") and "Call to Arms: Warsong Gulch". So the
  game's own holidays can come from the calendar; the names are English (the client's locale). Unverified
  (2026-11-13): whether the calendar's clock (`GetCurrentCalendarTime`, the realm's) and the player's (`date()`) differ
  on Forever; Holidays.lua reads the player's date in the calendar so the two can't disagree near midnight.
- **Loot roll lines** start with a loot history link on Forever (need and greed, not disenchant):
  "|HlootHistory:%d|h[Loot]|h: Need Roll - %d for %s by %s". Read the roll as the third capture from the end
  (Activity.Rolled); before 2026-11-11 the history id was read as the roll. Loot you pick up: `LOOT_ITEM_SELF`
  "You receive loot: %s"; items given to you: `LOOT_ITEM_PUSHED_SELF` "You receive item: %s". Unverified: how a
  link's color code looks in these lines on Forever (an epic is read by `|cffa335ee`).
- **A model scene of our own** (2026-11-11, `/dp probe api petframe`, the Brown Prairie Dog): `CreateFrame("ModelScene",
  nil, parent, "ModelSceneMixinTemplate")`, then `C_PetJournal.GetPetModelSceneInfoBySpeciesID(sid)` (1271, 7: the
  scene id, and a second value), `scene:TransitionToModelSceneID(1271, ...)`, `scene:GetActorByTag("unwrapped")`
  (found) and `actor:SetModelByCreatureDisplayID(display)` show the pet, as on the card. In a 180x180 frame only its
  bottom half showed: the scene's camera is set for the card's shape. The scene takes the mouse itself (the pet could
  be rotated by dragging), so a click on the frame under it never arrived.
  Second run: the card's model scene is 399x386; in a frame that size the pet had the card's scale (19.48) but
  stood at 0.5 (the card: 0.3, its lift), and was still cut off at the same place: not by the frame's edge. With
  the scene's mouse off and a Button above it, clicks and drags work.
  Third run: the cut-off is the frame's top edge after all: both scenes have the same camera (scene 1271: target
  0, 0, 1.5, zoom 24, yaw 2.62, pitch 0.35, fov 0.94, near clip 0.2), but the card sets **view insets 0, 0, 300,
  -50** (left, right, top, bottom) on its 386 px: the model's view is its bottom part, 50 px below the edge to 86
  above, so the pet stands low with room above. Ours had none: the pet sat at the top, half out of the frame.
- **Edit Mode**: `EventRegistry:RegisterCallback("EditMode.Enter"/"EditMode.Exit", fn, owner)` fire for an addon
  (the same test).
- **Feats, talents, trainers** (2026-11-12, 1.60.1, `/dp probe api feats` on a level 36 shaman):
  - Classic spell IDs are real here: 71 Defensive Stance, 2458 Berserker Stance, 7328 Redemption, 23214 Summon
    Charger, 1515 Tame Beast, 2842 Poisons, 697/712/691 the warlock demons, 1122 Inferno, 18540 Ritual of Doom, 23161
    Summon Dreadsteed, 5487 Bear Form, 1066 Aquatic Form, 768 Cat Form. Riding both ways: 33388 Apprentice and 33391
    Journeyman Riding, and Classic's 824-828, 10861, 10906, 10907, 18995; not 34090, 34091, 90265.
    `ERR_NO_RIDING_SKILL`: "You can learn riding and obtain a mount from your riding trainer at level 10".
  - Quest flags: Call of Earth's race copies (1518, 1521, 94375) all read completed for one character. Titles of
    quests the client hasn't seen are nil until asked for (`C_QuestLog.RequestLoadQuestByID`). Every step of a
    class chain has the chain's name, and each race has its own steps: a level 36 shaman's completed quests hold 30
    "Call of Earth/Fire/Water/Air" besides our finals (Classic's 63, 96, 100, 1516-1536, 2983-2986, and Forever's
    92466-92468, 94373-94374, 96136, 97243). So never match a class quest by its title. The level 60 quests (7647,
    7636, 7622, 7583, 7631) had no title even after asking: not in the client yet (raids open 9 December).
  - Events known: `LEARNED_SPELL_IN_SKILL_LINE`, `CHARACTER_POINTS_CHANGED`, `PLAYER_TALENT_UPDATE`,
    `TRAIT_CONFIG_UPDATED`, `TRAIT_CONFIG_LIST_UPDATED`, `CONFIRM_TALENT_WIPE`, `TALENTS_INVOLUNTARILY_RESET`,
    `ACTIVE_COMBAT_CONFIG_CHANGED`, `SPEC_INVOLUNTARILY_CHANGED`, `TRAINER_SHOW/CLOSED/UPDATE`; not `LEARNED_SPELL_IN_TAB`.
  - Talents are retail's system with Classic trees: `C_ClassTalents.GetActiveConfigID()` 672432, one specialization
    (`GetNumSpecializations` 1, spec group 1), the strings "Reset All Talents", "Left Tree / Right Tree", "You must
    be in a rest area to change talents", and "You must spend all available talent points to apply changes"
    (`ERR_TALENT_FAILED_UNSPENT_TALENT_POINTS`). `GetNumUnspentTalents()` 0 with every point spent.
    Dual spec strings: "Primary/Secondary Talents - Active".
  - `Enum.PlayerInteractionType.Trainer` is 7; `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` fires with the window's type.
- **UNIT_AURA's updateInfo can be secret** (2026-11-12, 1.60.1, in a dungeon): "attempt to perform boolean test on field
  'isFullUpdate' (a secret boolean)". Check `issecretvalue` on the table and its fields before testing them.
- **The meter in a real fight** (2026-11-12): Meter.lua's read after a boss kill gave "damage: place 5, 1027 against
  6513" (Arcanist Doan, a five-man): the right session, plain, our place.
- **A zeppelin ride** (2026-11-12, 1.60.1, `/dp probe api transport`, Grom'gol to Durotar): no transport API, but
  stepping aboard fired `NEW_WMO_CHUNK`; aboard, the position moved with `GetUnitSpeed` 0; halfway
  `LOADING_SCREEN_ENABLED` (known; the zone and map still ours), `PLAYER_LEAVING_WORLD` (map already gone),
  `PLAYER_ENTERING_WORLD (false, false)` with the map on the other continent (1415 Eastern Kingdoms to 1414
  Kalimdor; `GetMapInfo` parents, mapType 2) but `GetZoneText` still the old zone, then `LOADING_SCREEN_DISABLED` and
  `ZONE_CHANGED_NEW_AREA` with the new zone ("Durotar", subzone "Bladefist Bay"). Grom'gol's tower subzone is
  "Grom'gol Base Camp". Menagerie/Voyage.lua is built on this.
- **A boat ride** (2026-11-12, Forever's new route, Steamwheedle Port in Tanaris to Powderfuse Port in Riverglades):
  the same as the zeppelin (loading screen at sea, `PLAYER_ENTERING_WORLD` with the map already in Eastern
  Kingdoms and the zone still "Tanaris", then `ZONE_CHANGED_NEW_AREA` "Riverglades", map 2548, "Eastwind Shore").
  Forever's 14 routes (wowforever.be, from the 1.60.1 game files): new are Steamwheedle Port to Powderfuse Port,
  Stormwind Harbor to Auberdine, Menethil to Southshore to Auberdine, and Zephras Isle's zeppelins (Valanaar to
  Dalaran and to Skywatcher Plateau); their zone names other than Riverglades are unverified.
- **A ride's zones are the sea's, not the docks'** (2026-11-14, 1.60.1, the user): the boat from Ratchet to Booty Bay
  was taken for Grom'gol's zeppelin on a friend's client, so halfway out from Ratchet `GetZoneText` must have read
  "Durotar" (the zeppelin's pair: Durotar and Stranglethorn Vale). Voyage tells them apart by the position on
  Stranglethorn's map (`C_Map.GetPlayerMapPosition`, north: Grom'gol; south: Booty Bay); the line at y 0.55 is a guess
  until a ride's log ("Voyage ... at x,y") shows where the loading screens come.
- **A melee fight without a combat log** (2026-11-12, 1.60.1, `/dp probe api combat`, a shaman, solo, one mob):
  `PLAYER_ENTER_COMBAT` fires when auto-attack starts (here 5 s before `PLAYER_REGEN_DISABLED`: walking up to the
  mob) and `PLAYER_LEAVE_COMBAT` when it stops (just before `PLAYER_REGEN_ENABLED`). `UNIT_COMBAT` registered for
  "player" and "target" fires each hit: unit, action (`WOUND`, `MISS`, `DODGE`), flag text (`CRITICAL`, `GLANCING`,
  `BLOCK_REDUCED`, or ""), amount **secret**, school mask **plain** (1 physical; 4 fire, 8 nature, 16 frost: the
  shaman's shocks and weapon procs). It doesn't say who hit: on "target" solo, the physical hits come every 2.4-2.9 s,
  your swings (`UnitAttackSpeed("player")` 2.4, read out of combat); in a group anyone's would. `UNIT_SPELLCAST_SUCCEEDED`
  in combat gave plain spell ids (8053 Flame Shock, 8058, 10412, 408510). `C_Spell.IsCurrentSpell(6603)` (Attack) is
  true while auto-attack is on; the globals `IsCurrentSpell` and `IsAutoRepeatSpell` don't exist.
  `UnitRangedDamage("player")` answers (0 speed without a ranged weapon). `START/STOP_AUTOREPEAT_SPELL` register fine
  (unseen: no ranged weapon); `PLAYER_TARGET_SET_ATTACKING` doesn't exist.
  Since 2026-11-14 the misses and resists eggs (Activity "misses", "resisted") read `MISS`, `DODGE`, `PARRY` and
  `RESIST` from it; `MISS` and `DODGE` were seen, **`PARRY` and `RESIST` (a fully resisted spell) are unverified**.
- **The layout cache** (2026-11-12, 1.60.1, from Logs/AccountData.log): a named frame moved with `StartMoving` is
  user-placed, and the client saves its spot itself ("Frame: DyreparkenPetFrame", anchor, x, y), to restore it
  before our code runs. A frame that keeps its own spot calls `SetUserPlaced(false)` after a drag. `EditModeManagerFrame` and Blizzard's EditMode*Mixin tables exist.
- **The year's holidays** (`/dp probe api holidays`, 2026-11-11, Nov 2026 to Oct 2027; event ids, `eventType` 4):
  324 Hallow's End, 141 Feast of Winter Veil (Dec 15 to Jan 2), 327 Lunar Festival (Feb 2-16), 335 Love is in the
  Air (Feb 11-16), 181 Noblegarden (Mar 29-30), 341 Midsummer Fire Festival (Jun 21 to Jul 5), 321 Harvest Festival
  (Sep 11-18); 263 and 264 Darkmoon Faire (every month, in turn), 301 Stranglethorn Fishing Extravaganza (weekly),
  1840-1842 Call to Arms (battlegrounds). No Children's Week, Brewfest or Pilgrim's Bounty. Used by Menagerie/Holidays.lua.
- **The card's model never says it has loaded**: a hook on the actor's `OnModelLoaded` (the mixin's method) logged
  nothing over a whole session of cards, so SETTLE and SLEEP_AFTER stay guesses (2026-11-11).
- **The built-in damage meter, `C_DamageMeter`** (2026-11-12, build 1.60.1, `/dp probe api meter`, solo fights):
  - Readable **out of combat** in plain numbers: a second after PLAYER_REGEN_ENABLED every session read fine
    (names, totalAmount, amountPerSecond, maxAmount, durationSeconds). **In combat** the amounts, names and the
    duration are secret; `classFilename` and `isLocalPlayer` stay readable (Retail's NeverSecret), so which row is
    ours is known even then.
  - Sessions: type 1 (Current) is the last fight, kept after it ends until the next starts; 0 (Overall) adds them
    up; 2 (Expired) was empty. Each fight gets a new session id (5, 6, ...); `GetAvailableCombatSessions()` lists
    them with a name (the mob's: "Wildplains Huntress") and a duration. `GetSessionDurationSeconds` takes a
    session TYPE, not an id.
  - Events: `DAMAGE_METER_CURRENT_SESSION_UPDATED` (no payload) as a fight starts; then
    `DAMAGE_METER_COMBAT_SESSION_UPDATED` (meter type, session id) about every 2 s in a fight (0 damage, 7 damage
    taken...). Arithmetic or comparisons on the secret values would taint; read after combat instead.
  - **In a group** (2026-11-12, a five-man Scarlet Monastery run, two bosses: Interrogator Vishas, Bloodmage
    Thalnos): a second after combat every member is a source with their plain name ("First Surname"), class and
    amounts, and the list is **sorted, highest first**, so our place is our row's index. Only those who did any
    of a kind are listed (healing: the healer, plus a paladin's 1 point). No separate rows for hunters' pets;
    whether a pet's damage is in its owner's total is unknown. Interrupts (type 5) counted our one kick.
  - Session 1 (Current) after a boss kill is that boss fight alone (29 s and 40 s, matching the pulls), so a
    boss's result is session 1 read after combat. Our boss activity (ENCOUNTER_END, counted after combat) and
    PLAYER_REGEN_ENABLED logged in the same frame; the read a second later had the boss fight in it.
  - `DAMAGE_METER_RESET` fired on entering the dungeon, and session ids started again from 1: Overall is per
    instance there, not per login.
- **A new flight path is seen** (2026-11-11, build 1.60.1): `ERR_NEWTAXIPATH` matched on UI_INFO_MESSAGE or
  CHAT_MSG_SYSTEM (Activity "newpath"); the user's pet said its line as the flight path was learned.
- **Range to a group member** (2026-11-11, playdates): `UnitInRange(unit)` (in range, checked) and `UnitIsVisible`
  exist; what they answer on Forever is unverified (logged: "playdate range: ..."). Playdate.lua uses UnitInRange,
  and UnitIsVisible where it couldn't check.
- **A new model stands itself up once it has loaded, unseen** (2026-11-11, build 1.60.1, pet card swaps at night):
  a sleep loop set the moment Blizzard swapped the card's model was lost a moment later, with no Lua call on the actor
  (no SetAnimation hook fired) and `GetAnimation` still answering the loop. `actor:IsLoaded()` said true right after
  `SetModelByCreatureDisplayID`, so it can't tell either. And setting the same loop again doesn't refresh it: the
  client played it as a one-off, and the pet got up when it ended. So wait (SLEEP_AFTER) before posing a new model.
- **Animation lengths** for every species: Data/AnimLengths.lua (`/dp probe api lengths`, 2026-11-11). Stand
  plays 2-4 s depending on the model, and a move a model lacks plays as Stand (same length).
- **Ghost Wolf** counts as a riding form (`Moves.RIDING_FORMS`, form id 16): the pet ran on its card in it (the user,
  2026-11-11). Travel Form (3) not tried.

## Units under the mouse, forms and your casts (`/dp probe api glance`, 2026-11-14, build 1.60.1, Horde shaman)

- **A unit in combat has a secret identity, even when you aren't in combat**: `C_Secrets.ShouldUnitIdentityBeSecret`
  true, and then `UnitGUID` is nil, and `UnitName`, `UnitClass`, `UnitCreatureType`, `UnitIsPVP` and the tooltip's
  second line are secret. Still readable then: `UnitFactionGroup`, `UnitReaction`, `UnitIsEnemy`, `UnitCanAttack`,
  `UnitClassification`, `UnitLevel`, `UnitPlayerControlled`. 62 of 103 glances were secret (46 with us in combat,
  16 of elites or players fighting nearby). Out of combat everything reads plain.
- **The other faction reads plain** out of combat: a Horde player saw an Alliance gnome mage's class, race and
  faction (reaction 2, `UnitIsPVP` false). The tooltip's line 2 is the guild, else "Level N Race (Player)".
  Skyborne race: "Windshaper Skyborne", file name "Skyborne", id 96.
- Creatures: `UnitClass` gives a class (a mob's own: "WARRIOR", "MAGE"), `UnitCreatureFamily` names beasts and
  demons ("Crocolisk", "Bat", "Imp"), `UnitCreatureType` gives "Beast", "Elemental", "Demon". A warlock's demon has a
  `Pet-` GUID (npc id 416 for an Imp), line 2 "<Owner>'s Minion". A companion: `UnitBattlePetSpeciesID` works (70),
  line 2 "<Owner>'s Companion". No hunter pet or totem was moused over.
- Second run (the same day): **hunter pets** have a `Pet-` GUID with npc id **165189 for every one** (a Cat and a
  Tallstrider alike: tell them apart by `UnitCreatureFamily`), line 2 "<Owner>'s Pet". A Voidwalker: family
  "Voidwalker", "<Owner>'s Minion". A **totem**: a `Creature-` GUID, `UnitCreatureType` "Totem" (11), controlled,
  its name with its rank ("Healing Stream Totem III"). Players' `UnitCreatureType` isn't their race: Tauren,
  Trolls in a form, Skyborne and Night Elf druids read "Beast". Alliance Skyborne: "High Order Skyborne", id 95.
  Varimathras: classification "worldboss", line 2 "Level ?? (Boss)".
- **`GetZonePVPInfo` is missing**, so a zone's faction context must come from a list of our own. Zone names
  as `GetZoneText` gives them include Forever's own "Riverglades" and "Dalaran" (its own zone, entered from
  Alterac Mountains); `GetSubZoneText` works ("Thandol Span", "Lordamere Lake").
- **`GetPetHappiness` is missing.** `UNIT_HAPPINESS` (registered for every unit) fired 543 times in ~30 minutes
  with no pet of ours out: register it for "pet" only, if at all.
- Shaman: `GetShapeshiftFormID()` 16 in Ghost Wolf, `GetShapeshiftForm()` 1, but `GetNumShapeshiftForms()` 0.
  `UPDATE_SHAPESHIFT_FORM` also fires with no form (nil) when casting (fishing).
- Forever's own spell ids (`UNIT_SPELLCAST_SUCCEEDED`): Ghost Wolf 1238640, Water Shield 408510, Totemic Call
  437009, Call of the Elements 66842, Unroll Bag 429961, Nutritious Food 1249507; the classic ids for the rest (Flame
  Shock 10447, Searing Totem 6365, Fishing 7732...). Buffs seen: Plainsrunning 1299038 (Tauren, often), Boosted Rest
  1229451, Well Fed 1249520, Windfury Totem 8515, Stoneskin 10403, Healing Stream 6372.

## Professions and the exploration achievements (`/dp probe api legacy`, 2026-11-13, build 1.60.1)

- **Professions**: `GetProfessions()` gives the slots' indexes (primary, primary, archaeology, fishing, cooking;
  nil for an empty slot), and `GetProfessionInfo(i)` gives name, icon, rank, maxRank, ..., skillLine (Herbalism
  224/225, Enchanting 186/225, Fishing 193/225, Cooking 197/225). maxRank is the trainer's current cap, not 300.
  Weapon skills can't be read: `GetSkillLineInfo` and `GetNumSkillLines` are missing. Wish.Capped reads these.
- **Achievements**: Blizzard's API works (`GetCategoryList`, `GetCategoryInfo`, `GetCategoryNumAchievements`,
  `GetAchievementInfo(cat, i)`, `GetAchievementNumCriteria`, `GetAchievementCriteriaInfo(id, j)` -> name, type,
  done, have, need). Category 15607 "Explorer" holds "Explore Azeroth" (62053, criteria Eastern Kingdoms and
  Kalimdor), "Explore Eastern Kingdoms" (62353, 23 zone criteria, Forever's Riverglades among them) and "Explore
  Kalimdor" (62355, 20 zones). **A zone's criterion is done only when the zone is fully explored**: the tester had
  0/23 and 1/20 after visiting many zones. The probe read them by (category, index); whether
  `GetAchievementInfo(id)` with the id alone answers is unverified, so Wish.AchievementDone tries it and falls
  back to finding the id in the category once.
- `ERR_ZONE_EXPLORED` is "Discovered: %s"; whether the line comes as UI_INFO_MESSAGE or in system chat is
  unverified, so the explore wish reads both (like ERR_NEWTAXIPATH), and `ERR_ZONE_EXPLORED_XP` too.

## SavedVariables

- Written on /reload and logout (not on a crash, and not on Alt+F4 / "Exit Now"?).
- (beta) Early builds didn't load SavedVariables at launch; reportedly fixed in 70009. Verify on live.
- Create default tables at `ADDON_LOADED`, never at file scope.

## Combat lockdown

- Protected frames can't be shown, hidden or moved in combat (`InCombatLockdown()`); queue for
  `PLAYER_REGEN_ENABLED` (`ns.Events:OutOfCombat`). "Interface action failed because of an AddOn" can occur
  without a Lua error.
- Hook Blizzard UI (`hooksecurefunc`, `HookScript`), never replace it, to avoid taint.
- (seen 2026-11-13, 1.60.1) **Never open or switch the Collections window from addon code.**
  `ToggleCollectionsJournal(tab)` (or `CollectionsJournal_SetTab`) called from an insecure click writes
  `CollectionsJournal`'s selected tab tainted. Later, opening the window with its key binding **in combat** fails:
  `ADDON_ACTION_BLOCKED ... MountJournal:SetShown()` via `CollectionsJournal_UpdateSelectedTab`. The pet frame's
  click now shows a card only on a Pets page that's already open, and otherwise waits for the player to open it
  (PetFrame:OpenCard, JournalUI:ShowWhenOpen). Selecting a species on the open page (`PetJournal_SelectSpecies`)
  hasn't shown this.
- (2026-11-13, 1.60.1; **assumed, to check in game**) The pet frame opens the window through a secure button
  instead (Menagerie/PetFrame.lua, its click section): our own `SecureActionButtonTemplate` button, attributes
  `type` = "click", `clickbutton` = `CollectionsMicroButton`, so the micro button's own OnClick
  (`ToggleCollectionsJournal()` with no tab: the last page) runs untainted. Verified: the template, its mixin and
  `CollectionsMicroButton` exist (the client's API dump). Assumed from retail and WoW's secure system, not seen on
  Forever yet:
  - each handler the client calls (PreClick, OnClick, PostClick) starts secure, so our PreClick and PostClick don't
    taint the template's OnClick between them; attributes set by our code out of combat don't taint the action;
  - the template acts on the down or the up of a click as the `ActionButtonUseKeyDown` cvar says (retail 10.x), so
    the button registers only that one (else our Pre/PostClick ran twice, or nothing happened);
  - the micro button opens the window on its last page, and the window's OnShow picks that page before our
    PostClick runs (the hint for "opened on another page" reads it then);
  - a protected frame's parent, and any frame a protected frame is anchored to, becomes protected too: so the
    button is on UIParent, matched to the pet frame's anchor, scale and size out of combat, never its child or
    anchored to it;
  - `RegisterStateDriver(button, "visibility", "[combat] hide; show")` hides it in combat (petFrameCombat);
    a protected frame can't be shown, hidden, moved, sized, or have its attributes or mouse changed in combat by
    addon code, and isn't made in combat by us (deferred to PLAYER_REGEN_ENABLED).
  In combat the click toggles the window as the micro button would (Blizzard's code: allowed); the card waits for
  the end of the fight (JournalUI:AfterCombat, PLAYER_REGEN_ENABLED only while a card waits).

## Sources

- AutoCompanion (local, `../AutoCompanion`): Forever-specific comments in Core.lua, Pool.lua, Init.lua, UI_Popup.lua.
- https://wowforeverguides.com/addons/developers and /addons/patterns
- https://github.com/Thunderz96/forever-addon-kit (findings from beta builds 69893 to 70338)
- https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage
