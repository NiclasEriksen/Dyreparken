# Research and maintenance, 2026-11-15

The user, before bed: a maintenance run for drift and faulty logic, and research into Lua practices, Forever's
API, companion data sources and similar projects. Three read-only code reviews (Core and Achievements; the
data side of Menagerie; its UI side) and two web researchers. Every finding below was checked against the code
before it was fixed or listed.

## Fixed (local commits, tests added, each seen to fail without its fix)

- **Forged update notices** (Core/Version.lua): a VER, or any message on another protocol, by whisper or party
  could print "En nyere versjon" and, remembered, silence the real notice. Only the guild channel counts now.
- **Party gathering wish stayed on through fights** (Wish.lua): InCombatLockdown is still false while
  PLAYER_REGEN_DISABLED's handlers run. It now keeps its own `fighting` flag, as Activity does. The harness
  entered combat in the wrong order, which hid it; fixed there too (no other test changed).
- **Party distance** (Init.lua ns.UnitNear): Blizzard's docs for 70938 say `UnitInRange` always returns secret
  values, so playdates' "40 yards" was in practice "the client shows them". Now `UnitDistanceSquared` (not
  secret) first, then the old checks.
- **Party gathering wish, cast secrecy**: a party member's casts are secret unless the spell is flagged never
  secret (`SecretWhenUnitSpellCastRestricted`). The party is now listened to only when
  `C_Secrets.GetSpellCastSecrecy("Mining")` (etc.) says 0, never secret; else nothing is registered and the log
  says `Mining's casts by others: secrecy N`. **Likely outcome in game: 2, and the feature stays off** (see
  decisions).
- **Parken's stage** changed pets unseen after the page closed (a click on an icon closes the park as the mouse
  leaves it); its Moves stage then followed a pet on a hidden frame. Cancelled on hide; today's pet on show.
- **The pet frame** dropped a line said while it was hidden for a fight; its tooltip keeps it now.
- **Feat lines** always said "+25", even when the bond's cap gave less. They say what was given now
  (`feat.*.full` lines for none).
- **Glint waits** rolled through `ns.random` (the seam for chances); `math.random` now.
- **Comments and docs** brought in line (Wish's cap, Sense "nothing reacts yet", Moments' rare budget,
  Reactions, Quirks "the hour", Bond's days, `/dp ach` commands, Activity, Version, ChatThrottleLib).

## For you to decide

1. **The party gathering wish** will most likely never fire (casts secret). Keep it dormant (costs nothing),
   remove it, or do it the other way: a party member's Dyreparken tells the group "I mined" (a new message
   kind, an X-Protocol bump; only friends with the addon count). Check `/dp debug` log for the secrecy value
   first.
2. **A feat can be lost** (Feats.lua): it's recorded when seen, rewarded after the fight. Die, reload or
   disconnect before the fight ends and the 25 points are gone for good (a dead player has no pet out). Options:
   reward the next time a pet is out, or record only when rewarded.
3. **Eggs after a fatal fight** (bom, motstand, trofe) still speak as you lie dead; only reactions were made to
   skip. Same rule for them?
4. **Rare eggs spend the quirks' 45 minutes** (a holiday at login, midnight), holding back the day's common
   eggs. Rare reactions spend nothing. Keep, or let rare eggs skip it too?
5. **Wire.Name lets `|` through** (a player name reaches chat). Only before the first complete roster, and only
   by a forged relay. Tightening it changes what peers accept: an X-Protocol bump. Batch it with the next one?
6. **Pet frame while mounted**: with pet B summoned by hand and pet A as "Med deg", mounting switches the frame
   to A, and back to B on landing. Keep the last pet out instead while mounted or flying?

Low, left as they are: Comm unpacks a message before its size check (the cost is spent once per sender, then
they're ignored); an activity source joining a live slot skips its `start` (harmless today); the loot-feat path
waits 30 s after login, the quest path doesn't.

## Forever's API

- **Blizzard's own interface code for Forever**: github.com/Gethe/wow-ui-source, branch `forever`, one commit
  per build (70790 to 70938, 2026-11-13). `Blizzard_APIDocumentationGenerated` lists every function and event
  with its `Secret*` flags, and four files explain the secret rules. The best reference we have; diff it per
  build. Findings from it are in docs/FOREVER_API.md (2026-11-15).
- github.com/Atraeau/WoW-Addons: a Forever addon workspace with generated API types (not checked in depth).
- No official API changelog for Forever; warcraft.wiki.gg's Patch 1.60.1 page is gameplay only.

## Companion data without wowhead

- **wago.tools has Forever** (product `wowf`, builds to 1.60.1.70938). CSV per table and build:
  `https://wago.tools/db2/BattlePetSpecies/csv?build=1.60.1.70938`, and `Creature`, `CreatureDisplayInfo`,
  `CreatureXDisplayInfo`. Names, display ids, icons, flags, per build, no scraping. Its source text is empty, so
  how a pet is got stays ours (curation.csv). 122 species at 70938 (our README says 119); the only new one,
  5163 Shen'dorei Wisp, is already in our data.
- Other Forever projects run a "DB2 watch" GitHub Action that diffs tables per build and opens a PR
  (github.com/timemir/pagle-addon issues 490/678, github.com/cjber/tweaks-forever PR 484): a model for
  tools/companions/build.py.
- Wowhead's Forever section has no pet database; Blizzard's Game Data API is retail only.

## Lua practices

Done 2026-11-15: 1 and 2 (luacheck, its globals from the stubs: tools/lint_config.lua), 3 and 4 (LuaLS headless,
`---@class` on ns and every module: tools/types.lua). Both in check.sh and CI. Left: 5.

Dyreparken already does better than common practice on the harness (many clients, lossy network,
taint/protected frames), the wire contract test, field validation, coverage floors in CI, events only while
needed, a stripped release with a test, and Locale. Cheap improvements, in order:

1. **luacheck** in check.sh and CI (1-2 h): `std = "lua51"`, globals for our SavedVariables, read_globals for
   the client API, Libs/ and tools/ left out. Catches global writes, unused locals, shadowing, capitalised
   misspellings (`GetZonetext`), which our lowercase scan can't. Start with errors only (111, 113).
2. **Its read_globals built from the harness stubs** (1 h): one list of the client API; a new API must be
   stubbed before lint accepts it.
3. **LuaLS headless** with Ketho's WoW annotations (2 h), for fields and arguments only; most useful with
4. **`---@class` on `ns` and the main modules** (2-4 h, then as we go): catches `ns.Bodn:Add` typos and wrong
   argument counts on untested branches. Retail annotations accept APIs Forever lacks: the stubs stay the truth.
5. A garbage test for hot paths (1 h): near-zero allocation per CHAT_MSG_ADDON / UNIT_AURA / COMPANION_UPDATE.

Sources: luacheck docs (luacheck.readthedocs.io), BigWigs' Capping .luacheckrc, Ketho/vscode-wow-api,
DeadlyBossMods/LuaLS-Config, TSM's wowlua-ls, LuaLS diagnosis reports, llscheck/lualscheck, WoWUnit,
Falkicon/Mechanic, warcraft.wiki.gg Secure_Execution_and_Tainting.

## Similar projects, for ideas

- **Pocket Pals** (CurseForge, Retail and Forever, 2026-11-11): one virtual pet per character with needs and
  mood, grows with play time; unlockable furniture shown locked as **silhouettes with hints**. An idea for our
  achievements and minor likes.
- **Murder Pets** (fed by your kills), Murloc Minder, OmniPet, SothPet: tamagotchi-style, retail.
- **GameSlayve Match Pets**: a "Pet Chronicle" of summons and time together, like our Story.
- **Companion Chronicle** (Retail and Forever): a journal of players you meet, in tooltips, chat and nameplates:
  a working Forever example of those hooks.
- **olympus-addon** (github.com/dnl-gentile): a live guild census on Forever; compare its comm and roster code.
- Party games: **The Gathering Stone** (trivia, social deduction; extra games in a separate pack addon, a model
  for our Games/), **House Rules** (eight modes from one command), **Guilded**. None checked on Forever.
