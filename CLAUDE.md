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
  `tools/smoke.lua` (headless load with stubbed APIs plus a comm round trip). Run it after every change.
  When the addon uses a new WoW API, add a realistic stub to `tools/smoke.lua`.
- The game can't run from here. For in-game checks, ask the user to `/reload` and run `/dp debug on`, then
  `/dp probe` or the feature. Then read the log at
  `../../../WTF/Account/*/SavedVariables/Dyreparken.lua` (account folder: `NIKKERN`) (`DyreparkenDebugDB.lines`, tab-separated
  `serverTime  GetTime  module  message`, ring buffer of 2000; `head` is the newest index).
  Lua errors appear in-game (BugSack, if installed) or in `../../../Logs/`.

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
                   Summon (auto-summon, defers to AutoCompanion), Report (stub), JournalUI,
                   Tooltip (reservation lines on companion units; owner parsed from tooltip text)
Games/Framework.lua game definitions, lifecycle, UI stash/restore, history
Main.lua           bootstrap (ADDON_LOADED → init, PLAYER_LOGIN → summon + hello)
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
  "Auto-summon" checkbox in the journal (default on).
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
