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

- Missing: `GetSpellInfo` (use `C_Spell.GetSpellInfo`, which returns a table), `GetItemInfo` (`C_Item.GetItemInfo`),
  `UnitAura` (`C_UnitAuras`), `GetMerchantItemInfo`, Classic craft/tradeskill APIs, `GetSpecialization`.
- Registering an unknown event **throws** and aborts the file: `ns.Events:On` pcalls registration.
- `GetMouseFoci()` returns a table (top region first).
- `ReloadUI()` is protected (no Reload buttons); users type /reload.
- Settings: `Settings.RegisterCanvasLayoutCategory` / `Settings.RegisterAddOnCategory` exist.
- The Addon Compartment TOC fields exist (`AddonCompartmentFunc` …); whether the button shows is unconfirmed.
- Unverified, relied on since 2026-11-10 (each degrades to nothing when missing): `PLAYER_STARTED_MOVING`,
  `PLAYER_STOPPED_MOVING` and `GetUnitSpeed("player")` (the card's pet walking with you, Moves.lua);
  `ModelSceneActor:GetYaw/SetYaw` (the pet turning its back after a dislike); `GetBindLocation()` (the hearth
  line names your inn); the enUS zone names in `Quirks.HOME_ZONES`.

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
  a weapon skill-up ("Two-Handed Axes") with the pet out logged `skill +1` and its bond point. Reputation: not
  seen yet. If Forever lacks the events or the strings, the activities are just unavailable.
- Events that exist (`C_EventUtils.IsEventValid`, 2026-11-06): `NEW_PET_ADDED`, `COMPANION_LEARNED`,
  `PET_JOURNAL_LIST_UPDATE`, `CHAT_MSG_GUILD`.
- Officers: `C_GuildInfo.IsGuildOfficer()` works (true for rank 1). `GetGuildInfo("player")` returns
  `name, rankName, rankIndex, realm`, e.g. `Dyreparken, Dyrepasser, 1, CAMWOWEU4Realm5PvE`. `IsGuildLeader()`
  exists.

## SavedVariables

- Written on /reload and logout (not on a crash, and not on Alt+F4 / "Exit Now"?).
- (beta) Early builds didn't load SavedVariables at launch; reportedly fixed in 70009. Verify on live.
- Create default tables at `ADDON_LOADED`, never at file scope.

## Combat lockdown

- Protected frames can't be shown, hidden or moved in combat (`InCombatLockdown()`); queue for
  `PLAYER_REGEN_ENABLED` (`ns.Events:OutOfCombat`). "Interface action failed because of an AddOn" can occur
  without a Lua error.
- Hook Blizzard UI (`hooksecurefunc`, `HookScript`), never replace it, to avoid taint.

## Sources

- AutoCompanion (local, `../AutoCompanion`): Forever-specific comments in Core.lua, Pool.lua, Init.lua, UI_Popup.lua.
- https://wowforeverguides.com/addons/developers and /addons/patterns
- https://github.com/Thunderz96/forever-addon-kit (findings from beta builds 69893 to 70338)
- https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage
