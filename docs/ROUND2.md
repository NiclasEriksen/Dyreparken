# Dev tools and refactor, round 2 (2026-11-14, after 0.6.2)

The user: "our dev tools / logic / structure could need some improvements. We both need better tools to log /
test in game, and I'm sure there are areas in the code that would get improved performance / maintainability /
flexibility". Two read-only reviews (performance, maintainability) plus a look at the log. The user chose all
of it; the performance fix goes in now, released later with the rest (not a 0.6.3 of its own).
No wire or saved-data change is planned (no X-Protocol bump; migrations only if a step turns out to need one).

## 1. Performance (done: 93fb61f)

- Sense registered UNIT_SPELLCAST_SUCCEEDED (every class, through the reactions) and UNIT_AURA (paladins) for
  every unit since 0.6.2: hundreds of calls a second in a raid. `ns.Events:On(event, owner, fn, unit)` now has
  a hub per unit (RegisterUnitEvent); Activity's own unit frame went. `H.Invariants` fails a test that leaves a
  UNIT_ event registered for every unit.
- Activity sources' `when`: "fight" (solo, in a fight: the bad-luck eggs' UNIT_COMBAT on the target) and
  "peace" (the fall's UNIT_HEALTH).
- Spell names kept once read, a loot line's roll read once, ADDON_LOADED off after ours, Sense's log line not
  built while the log is off, Feats' Known without a table per call.
- Left: a guildmate's bond update runs a guild achievement check with a full Context() and a Story scan of every
  pet (item 3.4); COMPANION_SEEN and the glance build tables before their "seen recently" checks.

## 2. Dev tools (dev-only: Dev/ or behind ns.DEV, never packaged)

1. **Log reader** `tools/log.lua`: the ring in order (`DyreparkenDebugDB.lines.head`), sessions split by a
   header logged at each login (version, character, class, level, zone, build), filters by module, text,
   session, time; a summary of the busiest lines. **Noise**: repeated lines collapsed in the ring
   ("... x40"), `/dp debug mute <Module>`.
2. **Errors into the log**: our own Lua errors with their stack (an error handler chained in front of the one
   there, BugSack's included), so they're read with the rest.
3. **`/dp state`** (pacing, today's eggs and reactions, the wish, today's bond, registered events) and
   **`/dp try egg|react|wish <id>`** (a line and its move now, to check text and visuals in game).
4. **`/dp probe perf`**: calls and time per event handler and Bus listener for a session (debugprofilestop).

## 3. Refactors (by payoff)

1. **One moment engine** for Quirks' eggs and Reactions: nature lines (ByNature), once a day, cooldown budgets
   (45 min, 20 min, rare `always`), said after the fight, one "line on its way" slot for both (today an egg and a
   reaction can speak seconds apart), `*_FOUND`. Before CLASS_INTERACTIONS part 2.
2. **One event layer**: Sense's sensors and Activity's sources over the same Want/Drop; Fight through ns.Events
   (it has a frame of its own). One shared `ns.AutoAttacking()`.
3. **Secrets and zones in one place**: `ns.IsSecret`/`ns.Plain` know secret tables, `ns.Read(fn, ...)` (Sense's,
   Wish.Call, Fight.Number), `Data/Zones.lua` for the six zone lists (Personality climates, Quirks.HOME_ZONES,
   Wish.ZONES, Sense.CAPITALS/NEUTRAL, Bond's Stranglethorn).
4. **Smaller pieces**: Moves' play-once flags as one queue (it reads char.eggs.dodsfall, char.wish, char.sulk
   today); Fight asks PetFrame through methods; Activity's ~35 sources out of the engine file; Moves.NewStage
   (374 lines) split; a bond-only registry change doesn't rescan the guild (1, Left).

## Decided along the way

- 3.2: Sense's sensors stay a registry of their own beside Activity's sources. Both sit on ns.Events' unit
  hubs now, and the rest of their Want/Drop is a dozen lines each; merging them would mix counted activities
  (bond points, achievements) with uncounted subjects for no gain in cost.

## Status

- 1 done (93fb61f).
- 2.1 and 2.2 done (d358512): tools/log.lua, Session lines, repeats counted, /dp debug mute, Dev/Errors.lua.
- 2.3 done: /dp state (f7d175a), /dp try (Dev/Try.lua).
- 2.4 done (f6cee16): /dp probe perf (Dev/Perf.lua).
- 3.1 done: Menagerie/Moments.lua. The user, the same day: a rare reaction skips the one-at-a-time slot only
  some of the time (Reactions.RARE_SKIP 0.5), and the totem garden is common now ("not rare, I've gotten it
  twice in a short period").
- 3.2 done: Fight through ns.Events (the last frame of its own), ns.AutoAttacking, PetFrame:ShownPet/Act
  (Fight no longer reads its fields), Activity's sources apart by event and unit.
- 3.3 done: ns.IsSecret/Plain know secret tables (3d30722: a secret aura list had switched four aura sources
  off), ns.Read shared; Data/Zones.lua (Bond's Stranglethorn stays: it's the contest's own place).
- 3.4: bond-only registry changes no longer rescan the guild (461ada4); Core/Sources.lua (f4c16a7); the owed
  moves (char.owed, char migration 3).
