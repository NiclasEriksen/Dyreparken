# World of Warcraft: Forever, addon API notes

What we know about the client this addon targets. **Verify on the live client** before relying on
anything marked (beta) or (unverified). Add findings here as you make them, with date and build.

## Client

- Product `wowf`, folder `_forever_`, **client 1.60.1, build 70790** (from `.build.info`, 2026-11-06).
  Live since 2026-11-04 (patch 1.60.1).
- TOC `## Interface: 16001`.
- It's the **modern Mainline engine** (12.x / Midnight-era API) with Classic-like content, not the Classic
  Era API. Retail-style addon code mostly works; Classic globals mostly don't.
- Detection: `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18 seen on build 70338; it was 1 on early beta),
  so compare the named constant, not the number. `select(4, GetBuildInfo())` returns 16001, so Retail
  checks like `>= 100000` fail. Prefer probing for the API you need.

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

## Companions (C_PetJournal)

From AutoCompanion (written for Forever, in this AddOns folder):
- Available: `C_PetJournal.GetOwnedPetIDs`, `GetPetInfoByPetID`, `GetPetInfoByIndex`, `GetNumPets`,
  `GetSummonedPetGUID`, `SummonPetByGUID`, `PetIsFavorite`, `PetIsRevoked`.
- **No pet battles, caging, releasing or trading** → one copy per companion, no `GetPetStats`.
- AutoCompanion keys companions on Forever by **English species name**, not speciesID.
  (unverified) Is speciesID returned and stable on Forever? Run `/dp probe` with a pet out.
- `SummonPetByGUID` **toggles**: on the pet that's out, it dismisses it.
- Summoning is blocked in combat. There's a short companion-only cooldown (~1.1 s, up to 2.5 s) that starts
  when the pet appears; acting inside it gives "Ability is not ready yet".
- Summon sound file IDs on Forever: 567569, 568424 (AutoCompanion mutes them).
- Journal: `Blizzard_Collections` is load-on-demand; `CollectionsJournal` exists. (unverified) `PetJournal` frame
  names and ScrollBox layout: check with `/dp probe` and `/fstack`.
- Whether `C_PetJournal.SetCustomName` exists on Forever: (unverified); we use our own nicknames anyway.

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
- `SendChatMessage` restrictions on Forever: (unverified). Posting to RAID/PARTY from a slash command should be
  fine; test before relying on it from timers or events.

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
