# Refactoring review and plan (2026-11-12, at 6cdbbd4)

Four parallel reviews (content pipeline, card UI, core/sync, tests), with the main claims checked by hand.
Nothing was changed. Sizes: S (an hour or less), M (a session), L (several sessions).

## The short version

The addon is in good shape. Coverage is 99.5%, the suite runs in about 4 s, and the comments explain why the code
does what it does. The debt comes from how fast it grew: **every feature added its own copy of a pattern**, and
**every piece of content is spread across hand-kept lists that nothing cross-checks**. Three themes:

1. **Adding content touches 5–14 places, and a typo in most of them silently does nothing.** One new trait means
   up to 14 edits: Personality, Locale, Decor, and the lists in Fight, Wish, Quirks (×4) and Bond, plus
   `HasTrait` literals. Only the first two are tested. A new family touches about 13 tables in 7 files.
2. **The tests repeat their setup and depend on the machine.** 28 specs each write their own `Setup`. Traits are
   forced three different ways, the dice four ways, and the suite **fails in 10 places under
   `TZ=America/Anchorage`** (checked).
3. **Rules live in memory, not in code.** "Bump X-Protocol when a limit changes", "every widget must pause under a
   side page", "every token-guarded timer must check its token" and "an egg's activity must be in WATCH" are all
   unenforced. Each has already gone wrong at least once.

The plan below puts **the test helpers first**: once they exist, every later refactor is cheaper to make and
cheaper to verify.

---

## Latent bugs found along the way (fix first, all S)

| # | Where | Bug |
|---|---|---|
| B1 | Core/DB.lua:225-229 | A missing migration step **wipes the whole account DB** (every guild's registry, achievements, settings). That breaks the "compatible from 0.1.0" rule. Make it log, refuse, and keep the data; add a test that the migration list has no gaps. |
| B2 | Core/Init.lua:136 | `RunPhase` has no pcall. One module's start-up error (a new client build lacking an API, say) stops every module after it in that phase, Sync and Achievements included. |
| B3 | tools/test (harness.lua:116, 1243) | The tests use the host's timezone. They pass in CET and UTC by luck: 10 fail in Anchorage, 4 in Auckland. |
| B4 | Core/Activity.lua:145 | `Emit` doesn't check the id is declared. An undeclared id crashes `Bond.lua:397` (`KIND[id].always`). |
| B5 | Menagerie/CardActions.lua:48 | The Kallenavn button's OnLeave calls `GameTooltip:Hide()` unconditionally. Everything else uses `ns.HideTip`. |
| B6 | Menagerie/Decor.lua:746, 828 | `Specs()` runs twice per Apply, each time with its own `Now()`. At a boundary (midnight, a trait's moment) the signature and the particles disagree, and stale particles stay. It's also double work. |
| B7 | Menagerie/Moves.lua:925 | `Moves.SULK = 3` is set inside `NewStage`, so every new stage resets it. |
| B8 | Menagerie/Bond.lua:478 | `PlaceLine` uses `math.random`, not `Bond.random`, so tests can't pin it. |
| B9 | tools/pin_unlocks.lua:21,24,28 | The `parrot`, `chicken` and `whelp` rows never run, because Scenes.ALIAS maps those tags to bird, farm and dragon first. A new parrot gets the generic bird lists. |
| B10 | Menagerie/Registry.lua:246 | One client's odd roster read (say a name format with a realm suffix) lapses every claim it can't match, permanently and guild-wide. Guard: skip if I'm not in the roster myself, or if more than N would lapse at once. |
| B11 | Sync (Registry.lua:200-231, Sync.lua:182) | **Flood:** `TooBig` caps entries per message, and per-member caps count by author name, which a relay can make up. A few forged SYNCs can push the stored total past `SYNC_MAX_ENTRIES`, and from then on everyone refuses every honest SYNC part. Needs a decision (Q4). |
| B12 | Achievements.lua:410 | A forged ACH with 128 junk ids fills GUILD_MAX for good; there is no eviction. |
| B13 | tools/test/harness.lua:1402 | `UnitStandState` is stubbed, but Forever doesn't have it (FOREVER_API.md:319). 05_summon tests a sitting check that never runs in game. |
| B14 | JournalUI.lua:508-516 | Opening a side page stops Decor, BondTrack and the others, but not the bond celebration or Cuddle's bursts. |
| B15 | Meter.lua:326 | `Meter.last` is one shared slot. If combat restarts within READ_AFTER, all three deferred Emits read the last `Top`. |
| — | docs | Feats.lua:7 says "within the day's 75" (it's past it). The fall comment sits on the boat line (Activity.lua:84). CLAUDE.md says the debug ring holds 2000 lines (it's 8000). run.lua:14 still says `c.errors = {}`. |

---

## Phase 0: the safety net (S, one session)

- **The bugs:** B1–B8, B13, B14 and the stale docs.
- **Pin the timezone** once: `check.sh` exports it, and `run.lua` re-executes itself with TZ set if it's missing (Q2).
- **Bytecode cache in the harness** (`Load`, ~10 lines): a one-process run goes from 26.5 s to 12.5 s with
  identical coverage. Prototyped and verified by the test review.
- **Runner-wide checks after every test** (each finds 0 problems today, so they're free to add):
  - no stray globals (today only one scenario in 01_core checks this)
  - no printed line with an unfilled `{placeholder}` or a raw locale key
  - the env lacks every API in a `H.MISSING` list that mirrors FOREVER_API.md's "Missing"
- **A coverage ratchet**: a committed per-file baseline instead of 95/95/90 floors, since actual coverage is 99.5% (Q-list).
- `run.lua --slow=N` to show slow tests.

## Phase 1: test helpers and one source of randomness (M)

This makes everything after it cheaper.

- **One fixture world.**
  - Signature: `H.Setup{ ola={5159}, adopt="panda", traits={"kosete","latsabb"}, dice=true, at={2027,3,2,14}, companions=H.COMPANIONS }`.
  - `H.COMPANIONS` replaces the six copies of `Fixture()`, whose tags have already drifted apart.
  - Fixtures are re-applied on `c:Reload()` through an `opts.fixture(ns, c)` hook. Today 20_card re-applies them by hand.
- **`c:Traits(ids, sid)`** sets `Personality.PINNED[sid]` per species. It replaces 31 `P.Traits = function` overrides,
  which give every pet the same traits and can hide two-pet bugs.
- **One random seam**: `ns.Roll()` and `ns.Pick(list)` in Init.lua, with a per-client RNG in the harness.
  - Today Quirks, Bond, Moves and Fight each have their own `.random` with different signatures.
  - Sync's jitter shares the global RNG with cosmetic code like Fx, so adding one particle shifts sync timing in
    unrelated tests.
  - `c:Dice{roll=0, pick=1}` then pins every source, sets **every** `Quirks.DELAY` key to zero (read from the real
    table), and clears `quirkAt`. That removes the test-only workaround at Quirks.lua:84.
- **Small helpers**:
  - `c:Adopt(sid)` (adopts and settles; the `/dp adopter` form appears 102 times)
  - `c:Said(text)`, `c:Points(key, who)`
  - `H.same(a, b)` (replaces 46 `eq(table.concat…)`)
  - `w:SetDate(y, m, d, h)` (replaces 40 `w:Skip(os.time{…} - …)`)
  - `c:TipOf(frame)` (hover and return the lines; about 90 hand-written hovers)
- **Migrate the specs gradually**: the new helpers first, then the egg specs (29, 33, 34, 39, 41–47).

## Phase 2: content as declared, checked data (L)

This is the payoff for "easier to add pets, traits and eggs".

- **Trait tags in `Personality.TRAITS`.**
  - Each row declares its tags: `tags = {"cozy","sleeper","fighter","timid","watcher","adventurous"}`, `fall = 3`
    (a priority), `place = 1.3`, `ride = {zeppelin=…, boat=…}`, `particles = {…}` (moved from Decor.TRAITS),
    `day = {x=3, on="holiday"}` (data instead of a function plus a hand-matched `dayX`).
  - `Personality:Has(key, id)` and `Personality:Tagged(key, tag)` replace the three copies of `HasTrait` and
    Fight.Nature, and settle the inconsistent `Known` checks.
  - Fight.FIGHTERS/TIMID/WATCHERS, Wish.SLEEPERS, Quirks.COZY/ADVENTUROUS/FALL_TRAITS/ZEPPELIN_TRAITS/BOAT_TRAITS
    and Bond.PLACE_TRAITS disappear.
  - **A new trait is one row plus its Locale lines.**
- **`Data/Families.lua`**, one row per family:
  - Scenes ORDER/TINT/ALIAS/BY_FAMILY
  - Decor.FAMILY and FAMILY_ART
  - Personality BY_FAMILY, DISLIKE_BY_FAMILY, FAMILY_PICK and NO_DISLIKE
  - Bond.PLACE_CHANCE and Quirks.HOME_ZONES
  - the ride lists
  - pin_unlocks' FAMILY (the tool reads the same file, which also fixes B9)

  Zone names are collected the same way (Personality COLD/WARM/HIGH/CITIES, HOME_ZONES, Voyage.ROUTES and
  "Stranglethorn Vale"), so "Forever's names are unverified" has one place to fix.
- **Eggs, validated.**
  - `Quirks.WATCH` is derived from `EGGS[].on`.
  - A check at load (or in a test) that `on` is a real activity, moment or `*`.
  - Variants become one generic mechanism: `egg.<id>.<trait>.N` / `egg.<id>.<family>.N` are found from the Locale
    keys, like `ByNature`, and replace the hand-written `_key` choices in seven eggs (Q5).
  - The header documents that egg ids are permanent (char.eggs, the story, the `eggs:N` achievements).
- **One consistency spec that walks all the data**:
  - every trait, activity, family and egg id referenced anywhere exists
  - every one has its Locale keys
  - every `egg.X.N` / `dislike.X.N` renders with its egg's variables and leaves nothing unfilled (today only variant 1 is ever rendered)

  **New content then needs no hand-written test unless it brings new logic.**
- **Smaller pieces**:
  - `ns.PetSays(key, text, kind, opts)`: one path for the purple line plus PET_SAID, with consistent `chatLines` handling (Q6)
  - `ns.PickLine(prefix, vars)`: one variant picker with a cache
  - `Activity:WantOnly(owner, set)`: Bond, Quirks and Feats have the same diffing code
  - Voyage gets its own source instead of riding on Quirks' interest in `zeppelin`
- **Personality resolved once** (Q3). Today one activity leads to 6–8 `Personality:Of()` calls that each build
  tables. Cheapest fix: memoize per species, with the minor part separate. Or bigger: see Q3.
- **Game data into Data/**: Feats.LIST, Activity's GATHER_IDS/HOME_IDS/AURAS and Voyage.ROUTES.

## Phase 3: wire, sync and saved data (L, protocol-sensitive)

- **`Core/Wire.lua`**: every limit peers enforce, in one table:
  - ValidKey's 64, SaneName's 48, Version.Sane's 32
  - GUILD_MAX and the ach id pattern
  - MAX_PARTS and MAX_RAW, LifeCap

  Plus one nickname validator (today ValidName and ValidNickname are two). `Comm:Register(kind,
  {from=…, fields={pet=Wire.Key,…}}, fn)` drops malformed messages before the handler runs.
- **A protocol fingerprint test**: a snapshot of the registered kinds and their fields, the LIMITS,
  BOND_DAILY_MAX, LEVELS, SYNC_MAX_ENTRIES, CLOCK_SLACK and BOND_EPOCH, keyed by X-Protocol. If one changes
  without a bump, the test fails, and the CLAUDE.md rule becomes a test.
- **`Sync.TABLES`**: one row per synced store (wire key, SYNC part, validator, merge, digest, cap). Digest,
  SendFull, TooBig, MergeAll and a generic "revalidate" migration all loop over it. Today each store is listed in
  about 7 places, and guild achievements needed hooks of their own. Keeps the wire layout, so no protocol bump.
- **`Registry:WriteOwn(store, key, entry)`**: one place for "stamp grows, run the peers' validator on it, trim,
  fire MY_*". Bond:Add writes `g.life` directly and skips Trim.
- **Flood resistance (B11, B12)**: depends on Q4.
- **Saved data with an owner**:
  - `char.wish` and `char.bondToday` are missing from CHAR_DEFAULTS.
  - `announce`, `eggs`, `sulk`, `dislikes` and `firsts` are written by 2–5 modules each; non-owners should go
    through the owner's accessor.
  - Export `DB.SCHEMA`: tests hardcode 11 in three places.
  - Add a test that every `DB.char.X` read is in the defaults.
- **Declared Bus events**: `ns.Bus.EVENTS = {NAME = "args"}`, checked in the harness. There are about 28 events
  as bare strings; FEAT fires and nobody listens.
- **Small items**:
  - `JournalUI:Card()` instead of `_card` (9 sites)
  - Summon fires PET_OUT instead of calling `Activity:NewDay()`
  - the remaining tunables into Config (Sync's SYNC_GAP/HOLD/ASK_GAP, Comm's REPLY_GAP/BURST, Guild's timeouts)

## Phase 4: card UI (L)

- **A card widget registry**:
  - `ns.Card.Register{ id, build, update, pause, stop }`, run in order. JournalUI loops over it for build, update,
    side page and one OnHide.
  - Today a widget appears in up to four places (Build, WIDGETS, the SIDEPAGE list, its own OnHide), and they have
    drifted (B14). Pause is spelled Stop, Pause or Update(nil).
  - Field names (`card.bond…`) are kept, so the tests survive.
- **`ns.Timers()`**: `t:After`, `t:Every`, `t:Cancel` with a generation counter. It replaces about 15 hand-written
  token guards in Moves, PetFrame and BondTrack, and two bugs of that kind have already been found. The harness
  can then count pending timers.
- **A BondBar component** shared by the card and the pet frame. PetFrame builds a fake card to call BondTrack and
  reads its private `growTo`.
- **Tooltips as data**: `XxxLines(key) → {{text,r,g,b,wrap}}` plus `ns.ShowTip(owner, anchor, lines)`. About 16
  hand-written OnEnter blocks; ParkPage duplicates JournalList's tooltip.
- **A UI kit in Core**:
  - `ns.MEDIA` / `ns.Icon` (the particle path is written out 9 times)
  - `Edges`, `Gradient` (4 copies each)
  - `RoundBadge` (OutBadge, Story, the Settings cog)
  - Decor's Loop/Timeline/Swing moved into Core/Anim
- **One particle burst engine**: Fx:Burst with a parent and a frame level. Fx, Cuddle, BondTrack, OutBadge and the
  PetFrame bubble each have their own pool (Q8).
- **One table of bond-level rewards and palette**. Decor.NEED exists, but Apply hardcodes 2..7, and BondTrack,
  Scenes.Tier and Fx have their own thresholds.
- **`ns.Events:OffAll(owner)`** and one convention for Bus wiring (at load, in Start, or in Attach: today it's all
  three).
- **Refresh only what changed**: every guildmate's BOND redraws the whole list, the card and ParkPage.
- **Moves: a pure planner** (`Plan.Rest/Pose/Jump/Cuddle/Cheer` return step lists) and a stage that only plays
  them. Sleep is built in four places and the jump in two. 32_moves (979 lines) could then test the plans without
  timers. Medium risk: lots of in-game tuning to protect.

## Phase 5: dev code out of the release (M; could also go first, see Q1)

- **What loads for players today**: about 2,500 lines that only a git checkout uses: ApiProbe 1168, MovesEditor
  304, SceneGallery 250, DecorCandidates 242, Kills 238, LiftEditor 170, Pets' probes ~170, Moves' probes ~300, and
  bits of Decor, Scenes, BondTrack and Page.
- **Move them** to `Dev/` and wrap them in `#@do-not-package@` in the TOC. The harness reads the raw TOC, so the
  tests keep them.
- **The editors** set one override hook (`Moves.override`) instead of flags that Moves, Decor, Scenes and BondTrack
  read on every call. LiftEditor and MovesEditor merge into one.

## Phase 6: when everything else is done (M)

- Split harness.lua (BuildEnv is 547 lines) into `harness/{frames,world,client,env/*}.lua`.
- Less reading of private state in specs: `c:Visible(text)` and `c:Page(name)` instead of `_rows`, `_page`, `_tab`
  (~83 reads) and `DB.char` (112).

## How I'd carry it out

- **Order**: Phase 0 → 1 → 2 and 5 (they don't share files) → 3 → 4 → 6.
- **One commit per item**, each with `tools/check.sh` green and with `Tidy-up:` or `Tests:` subjects (except
  fixes players notice, like B1).
- **Within a phase**, subagents in their own worktree for slices that touch different files. I review and merge
  each one.
- **Before each phase**, a short summary of what changes for you. No protocol bumps or migrations are planned,
  except where Q4 might need one.

---

## Decisions (2026-11-12, the user)

- **Q1 dev code**: yes, left out of the release zip.
- **Q2 test timezone**: Europe/Oslo (done: run.lua sets TZ for itself and its shards).
- **Q3 personality**: left to me. Memoize at runtime (keeps today's rules, no one-way door); the pinned
  file stays an option if the rules ever need freezing.
- **Q4 sync**: only guild members' data matters; the client shouldn't care about anything else. So: relayed
  entries (claims, lapses, names, bonds, guild achievements) whose owner/author isn't a member are refused when
  the roster is known and pruned on a complete roster; with no roster yet they're accepted and pruned later
  (a new member mustn't be lost to a cached roster). That also bounds the stores, which fixes B11/B12.

- **Q5** (2026-11-12): eggs ride on disliked activities too ("why not?"). Done.
- **Q6**: chatLines is about the random lines; the unlock lines, the pat thanks and /dp klapp print anyway (as they did).
- **Q9**: left for a discussion at the end.

## Status

- **Phase 0, done**: B1, B2, B3, B4, B5, B6, B7, the stale docs, the bytecode cache (suite
  4 s → 2 s), H.Invariants after every test (stray globals, unfilled placeholders), the migration-gap test.
  Left for later: B8 (Phase 1's random seam), B13 (Q11), B14 (Phase 4's widget registry), the coverage ratchet
  (Q10), `--slow`.
- **Phase 1, done**: `ns.random`, the one seam for every chance (Quirks/Bond/Moves/Fight had their own; fixes
  B8; Sync's jitter and Fx's scatter stay on math.random), `c:Dice`, `c:QuirksNow` (removed the test-only
  DELAY fallback in Quirks:Say), `c:Traits` / `c:Companions` / `c:Fixture` (survive reloads; replaced 30+
  hand overrides of Personality.Traits, PINNED and ns.Companions; both checked load-bearing), `H.COMPANIONS`,
  `w:SetDate`, `c:Said` / `c:CountPrinted` / `c:Points`. Skipped as low value: `c:Adopt`, `H.same`, a
  per-client RNG. `c:TipOf` waits for Phase 4's tooltips-as-data. Left on purpose: 19_bond's made-up trait,
  23_decor's trait-cycling override, 13's own companions fixture (its tags differ).
- **Phase 2, done**: trait tags on the rows (`is`, `place`) and `Personality:Has/Tagged` replace nine lists
  in Fight, Wish, Quirks, Bond and three copies of HasTrait; eggs carry their own `traits`/`families`
  (ByNature reads the egg), `on` is checked at load, `Quirks.WATCH` is built from the eggs; `ns.PetSays`,
  `ns.Variants`/`ns.PickLine`, `Activity:WantOnly`; Voyage wants its own cast filter. 49_content.lua walks
  traits, eggs, lines, activities, dislikes and families. **Found by it**: six minor dislikes (camp, dance,
  fish, fun, mine, skin; 36 species) had no lines, so they could never be found, nor "Kjenner deg ut og
  inn" completed for those pets; lines drafted (for the user to review), and 25_locale now counts minor
  dislikes. Decided against, with reasons: Data/Families.lua (the content spec catches a missing family row
  instead, with less churn); memoizing Personality (it runs per activity and per card refresh, not per
  frame; a cache would go stale under tests that edit the tables); moving Feats.LIST, GATHER_IDS and the
  zone lists into Data/ (no bug it prevents). Q5, Q6, Q9 still open: behavior kept (PetSays' `always`
  marks Q6's lines).
- **Phase 3, done except Q4** (two halves, merged): every saved key declared under its owner (50_saved),
  ns.Bus.EVENTS checked by the harness, JournalUI:Card(), PET_OUT, the story panel on SidePage's host;
  B10 (a roster that doesn't list you, or would free more than a third of the adopted pets, frees none),
  B12 (unknown guild achievement ids capped at 64, lowest kept; migration 12), Sync.TABLES (wire pinned
  first in 51_wire), Registry:WriteOwn (bonds now keep LIFE_PER_MEMBER), Core/Wire.lua with every limit and
  check, Comm:Register field specs, the protocol fingerprint (52_protocol), tunables in Config.
  **Q4 not done**: dropping non-members' data can't be done without old and new clients' digests
  disagreeing (a SYNC round per login in a mixed guild) unless X-Protocol is bumped; B11 stays open.
  **Decided (the user): D, at the next X-Protocol bump ("probably very soon. Don't forget").** 52_protocol's
  message for a missing snapshot says so, so the bump itself brings it up.
  B10 follow-up (the user: "hell yeah"): a batch held back as too big goes once a roster on a later day
  still misses the same owners (g.rosterHeld). New message kinds alone need no bump (the user: OK);
  52_protocol lets them through.
- **Phase 5, done**: Dev/ in a `#@do-not-package@` block (ApiProbe, the editors, galleries, Kills, and the
  probe parts of Pets, Moves, Decor, Scenes, BondTrack, JournalUI and Page); shipped Lua 18,324 → 15,136
  lines. Editor/preview flags became one `override` per module that only Dev code sets. A release client
  in the harness (`{ release = true }`, 48_release.lua) tours the addon with no Dev files and ns.DEV off.
  Not done: merging LiftEditor into MovesEditor (little left in common). Unverified: the packager's
  stripping of the block, until the next real zip.

## Questions still open

1. **Dev code in the release** (answered above): may probes, galleries, editors, ApiProbe and DecorCandidates be left out of the
   zip (`#@do-not-package@`)? (Recommended.)
2. **Test timezone**: Europe/Oslo (where the players are) or UTC?
3. **Personality**: memoize at runtime (keeps today's rules), or a fully resolved, pinned
   `Data/Personalities.lua` like Traits and Unlocks? The second makes "pinned forever" literal and removes the
   exceptions for adopted pets, but future changes to families' or traits' likes would then only reach new
   species.
4. **Sync flood (B11/B12)**: should relayed data be limited to guild members (prune non-members on a complete
   roster), or should there be a total cap with deterministic eviction? Should an owner's client re-assert its own
   record when a relayed copy overwrites it (a forged release)?
5. **Eggs on disliked activities**: today a dislike stops every egg on that activity (a wolf never gets `lur`, a
   Latsabb never `hopp`). On purpose? And should trait or family variants of egg lines be generic (just add the
   Locale key), or stay opt-in per egg?
6. **chatLines**: Bonds:TellUnlocks, the pat thanks and `/dp klapp` print even with chatLines off. On purpose?
7. **Cuddle**: the header says "your adopted pet", but the code gives the daily cuddle to any of your pets that's
   out. Which is right?
8. **Card bursts**: if they move to Fx's pool, should they stay at the card's frame level (under the side page) or
   go on top like Fx (HIGH strata)?
9. **`whelp`/`parrot`/`chicken`**: real personality sub-families, or delete their rows in pin_unlocks?
10. **Coverage**: a ratchet (no file may drop), or a fixed 98%?
11. **The `UnitStandState` stub and its sitting tests**: remove them, or keep them for "a later client" behind a
    `patch`?
12. **Pre-push**: all 8 random sync seeds, or 3 locally and 8 in CI?
13. **Games/Framework.lua** (103 lines, no handlers yet): keep it in the TOC until it's used?
