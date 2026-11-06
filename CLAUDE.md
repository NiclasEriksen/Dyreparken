# Dyreparken

A guild addon for **World of Warcraft: Forever** (interface 16001, client 1.60.1, Mainline engine,
**Lua 5.1**). It has two parts: a companion pet registry (reserve, sync, auto-summon, nicknames) and a party
games framework. The spec is `DesignDocument.md`, which is a living document owned by the user. It's kept out
of git on purpose (`.gitignore`); read it, but never commit it.

**Before writing WoW API code, read `docs/FOREVER_API.md`**: secret values, missing APIs, comm limits, pet journal
quirks. When you learn something new about the client, add it there with the date and build.

## Working rules

- **Ask before guessing.** The user wants questions about anything vague, open to interpretation, or that would
  need an ugly hack. Settle open questions with them; don't silently pick.
- **Performance comes first.** The addon is dormant day-to-day: no OnUpdate or polling, and events are registered
  only while needed (`ns.Events:On/Off`). Build data on demand.
- Never call protected functions in combat. Hook Blizzard UI, don't replace it.
- Treat every addon message as untrusted input.
- Keep backwards compatibility from 0.1.0 on. Until then, breaking changes are fine. Saved data changes go
  through `MIGRATIONS` in `Core/DB.lua`. Wire changes bump `X-Protocol` in the TOC.
- Comments explain *why* (game quirks, decisions), not what.

## Verify

- `tools/check.sh` runs the TOC↔file check, a Lua 5.1 syntax check (luajit), a scan for 5.2+ syntax, and
  the test suite with coverage floors (~25 s). `tools/check.sh --quick` skips coverage (~2 s).
- The game can't run from here. For in-game checks, ask the user to `/reload` and run `/dp debug on`, then
  `/dp probe` or the feature. Then read the log at
  `../../../WTF/Account/*/SavedVariables/Dyreparken.lua` (account folder: `NIKKERN`) (`DyreparkenDebugDB.lines`, tab-separated
  `serverTime  GetTime  module  message`, ring buffer of 2000; `head` is the newest index).
  Lua errors appear in-game (BugSack, if installed) or in `../../../Logs/`.

## Testing

**Run the tests whenever you implement something new or change something existing**, and add or update tests
in the same change. Run `luajit tools/test/run.lua <filter>` while working, and `tools/check.sh` before
committing. A change isn't done while a test fails or a coverage floor is missed.

- `tools/test/harness.lua` simulates a world: several clients (`w:AddClient("Ola Nord", opts)`), each running
  its own copy of the addon in its own global environment, with a shared clock (`w:Run(s)`, `w:SkipDays(n)`),
  guild roster, group, and an addon-message network. The network can lose messages (`w.drop`), take forged
  input (`w:InjectMessage`), and records every decoded message in `w.wire` (`w:Sent(kind)`). Clients log in
  and out with their SavedVariables kept (`c:Reload()`). There are helpers for the journal, tooltips, popups
  and player state. Read its header first.
- Specs: `tools/test/spec/NN_area.lua`, each `return function(test, H) ... end`. The runner fails a test if any
  client hit a Lua error, a failed comm handler, or a tooltip error. Tests that cause errors on purpose take
  them with `c:TakeErrors()`.
- `--coverage` reports line coverage per file and `--missed=File` lists the uncovered lines. `tools/check.sh`
  enforces **Menagerie ≥ 95%** and **Core ≥ 90%**. Keep the sync and registry tests multi-client: races,
  partitions, lost messages, lapses, and the randomized convergence runs in `04_sync.lua`.
- Stubs must behave like the real client (docs/FOREVER_API.md). Unknown frame methods and unknown events throw
  on purpose, and reads of globals the stubs lack are reported (`01_core.lua`). When the addon starts using
  a new API, stub it realistically in `Client:BuildEnv`.
- Before relying on a new test, make sure it can fail: break the code it covers once and watch it go red.
- **Games (`Games/`) are the exception, for now.** That part is meant to stay dynamic and change shape quickly,
  so it has no coverage floor and only light tests (`10_games.lua`). They pin what must never break: UI changes
  are always undone, including after a reload. Don't let tests get in the way of reshaping game code. Tighten
  this once the games protocol settles.

## Releasing

- Push a tag `vX.Y.Z` (release), `vX.Y.Z-betaN` or `vX.Y.Z-alphaN`. `.github/workflows/release.yml` runs the checks,
  then BigWigsMods/packager@v2, which uploads to CurseForge (WoW Forever, 1.60.1) and makes a GitHub release.
- The TOC has `## Version: @project-version@`, which the packager replaces with the tag. A git checkout reports `dev`
  (`ns.DEV`) and never shows "outdated" warnings.
- The CurseForge project ID is the `CF_PROJECT_ID` repository secret, passed as `-p`, so it isn't in the TOC.
- The changelog is generated from commit messages, so write them for players.
- `.pkgmeta` lists the dev files left out of the zip: tools, docs, CLAUDE.md, README.md, .claude, .luarc.json, .github.
- Any wire format change bumps `X-Protocol`. Any saved data change adds a migration (see Working rules).

## Layout

```
Dyreparken.toc     load order (each file only uses files above it)
Libs/              LibStub, ChatThrottleLib (global), LibSerialize, LibDeflate. Don't edit.
Core/Init.lua      ns, Config tunables, Bus (internal events), helpers (Now = GetServerTime)
Core/Debug.lua     ns.Log(module, fmt, ...) → SavedVariables ring buffer; no-op when off
Core/Events.lua    single event frame, On/Off, OutOfCombat queue
Core/DB.lua        SavedVariables, defaults, schema migrations, DB:Guild() registry
Core/Comm.lua      serialize→compress→encode→chunk, CTL send, Register(kind, fn)
Core/Version.lua   HELLO on login, one-time outdated notice, /dp version
Core/Guild.lua     guild roster snapshot on demand (membership, days offline)
Core/Commands.lua  /dp slash commands (claim, release, nick, list, version, report, probe, debug)
Menagerie/         Pets (journal access, pet keys, probes), Registry (reservation data model,
                   merge + holder rules: read its header first), Sync (HELLO digest, SYNC/UPD/LAPSE),
                   Summon (auto-summon, defers to AutoCompanion), Report (/dp report), JournalUI,
                   Tooltip (reservation lines on companion units; owner parsed from tooltip text)
Games/Framework.lua game definitions, lifecycle, UI stash/restore, history
Main.lua           bootstrap (ADDON_LOADED → init, PLAYER_LOGIN → summon + hello)
tools/check.sh     all offline checks (see Verify)
tools/test/        harness.lua (simulated clients + network), run.lua (runner, coverage), spec/*.lua
```

## Decisions (2026-11-06)

- Libraries: minimal (no Ace3).
- A reservation is **one species per character**, guild-wide, first come first served by `GetServerTime()`.
- Released when the owner leaves the guild, or after 30 days unseen. Nicknames unlock after 7 days, max 20
  characters (`ns.Config`).
- Auto-summon turns itself off if AutoCompanion is loaded.
- `/dp report` checks addon users only. It calls out those without a companion in group chat and lists non-users
  locally as unknown.
- Auto-summon only when idle: not in combat, mounted, on a taxi, flying, dead, stealthed, sitting, eating/drinking,
  casting/channeling, or in a battleground/arena. At most 3 tries per trigger. Toggled by the per-character
  "Auto-summon" checkbox in the journal (default on). It never replaces a pet you summoned yourself. It doesn't watch
  `COMPANION_UPDATE` (that fires for every nearby companion), so a pet you dismiss comes back only at the next
  trigger: loading screen, leaving combat, dismounting, or claiming.
- Counter: "x reserved of y known", where known = species this client has come across (owned, reserved, hovered).
- No officer force-release for now: release only happens by the owner, by leaving the guild, or after inactivity.
  Build it later if it turns out to be needed.
- Anyone can run a version check. Only the group leader or an assist can start games.
- The debug log goes to `DyreparkenDebugDB` (account-wide SavedVariables).
- Players are keyed as `"First Surname"` and guilds by name: **no realms**, because Forever moves players between
  realms invisibly. See docs/FOREVER_API.md.
- The pet key is `s:<speciesID>`. Forever returns real species IDs (see docs/FOREVER_API.md).

## Open questions (ask the user before deciding)

- Whisper targets with surnames ("First Surname") are unverified, so all replies go on the group/guild channel for now.
- `UnitStandState` existence on Forever is unverified (sitting detection is skipped if it's missing).

## Future additions

- A full list of Forever companions compiled from wowhead data. It would replace "known" (species this client has
  seen) as the denominator in "x reserved of y known", and enable a "companions the guild is missing" list.
