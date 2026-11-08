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
- Never change the pet journal's filters or search (`C_PetJournal.Set*Filter*`, `SetSearchFilter`). Forever's journal
  has no Filter button, and a filter left wrong empties the list for good (see docs/FOREVER_API.md). Read species
  with `GetPetInfoBySpeciesID` / `GetOwnedPetIDs` instead. The test harness throws if the addon calls a setter.
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
A `pre-push` hook (`.githooks/`, enabled per clone with `git config core.hooksPath .githooks`) runs the full
`tools/check.sh` on each pushed commit in a temporary worktree and refuses the push if it fails.

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
  enforces **Menagerie ≥ 95%**, **Achievements ≥ 95%** and **Core ≥ 90%**. Keep the sync and registry tests multi-client: races,
  partitions, lost messages, lapses, and the randomized convergence runs in `04_sync.lua`.
- Frames in the harness record anchors (`f.points`, `f.size`) and have geometry only if a test sets `f.geo`.
  `c:OpenJournal({ sideTabs = n })` builds Forever's Collections window (side tab strip, Mounts/Pets pages,
  `CollectionsJournal_SetTab`); `c:ClickTab(n)` presses a tab.
  Show/Hide cascade OnShow/OnHide to shown children, like the client.
- The harness enforces the server's addon message throttle (10 per prefix, +1/s; drops go in `w.throttled`), so a
  test sending more than that at once fails unless `Comm` paces it. `GameTooltip` has per-line font strings
  (`GameTooltipTextLeftN`), and `c:Hover` returns the whole tooltip as its third value.
- The harness blocks guild chat posts that don't come from `c:Slash` or a `Click` (Forever does; the test then
  fails with `ADDON_ACTION_BLOCKED`). Post to guild chat only from a keypress or click.
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
Core/Activity.lua  the activity engine: game events -> activities ("boss", "quest", "pvp", "taxi", "herb", "mine",
                   "fish", "skin", "day"), counted per
                   character after combat, Bus "ACTIVITY". Events registered only while a consumer wants them
                   (Want/Drop). Bond, achievements (`activity` kind) and stories build on it. Read its header.
Core/SidePage.lua  our pages of the Collections window: a side tab each under Blizzard's, the page covers theirs
                   (no taint: never their SetTab or tab list), title/portrait swapped and put back. Read its header.
Core/Commands.lua  /dp slash commands (adopter, gislipp, navn, liste, lyd, prestasjoner [ikoner], versjon, klapp, kunngjør, rapport;
                   English aliases; probe [more|tabs|kills|bg|ach], debug)
Data/Companions.lua GENERATED (tools/companions/build.py --lua; the tools stay out of git): every journal species, whether
                   it counts toward achievements (a), and its tags/families (t). Don't edit by hand.
Menagerie/         Pets (journal access, pet keys, probes), Registry (reservation data model,
                   merge + holder rules: read its header first), Sync (HELLO digest, SYNC/UPD/NICK/BOND/LAPSE, guild channel only;
                   the digest and SYNC also carry guild achievements),
                   Summon (auto-summon, defers to AutoCompanion), Report (/dp rapport), JournalUI,
                   Tooltip (reservation lines on companion units; owner parsed from tooltip text)
                   Personality (likes and a quirk per species, from families, a few species and a hash; liked
                   activities give more bond points), Scenes (backgrounds behind the pet on the card, by family; candidates until probed), SceneGallery (/dp probe bg: thumbnails of every
                   background that exists; pick one per family, saved in DyreparkenDB.scenePicks),
                   ParkPage ("Parken", the park map SidePage: records, every journal companion as an icon;
                   loads after Achievements/Page.lua so its tab comes second),
                   Bond (the bond score between a carer and their pet: levels, daily points, seeding; data in
                   g.life, see Registry.lua; docs/PET_LIFE.md),
                   Bonds (milestone lines after login, the nickname unlock note, dagens dyr, /dp klapp,
                   guild announcements)
Achievements/      Texts (every player-visible achievement text, Norwegian: rename here), Defs (ids, kinds;
                   ids are permanent), Achievements (evaluation, quiet first runs, ACH_EARNED notices,
                   /dp ach share; guild ones synced with the registry, ACH), Kills (research probe for boss/PvP kills, only while
                   debug is on), Page (the achievements SidePage;
                   Del per shareable one).
                   Plan and decisions:
                   docs/ACHIEVEMENTS.md (read it first). Planned next: bond, temperament and the activity engine,
                   docs/PET_LIFE.md.
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
- **Bonds** (2026-11-08, docs/PET_LIFE.md): a score per carer and pet that grows (10 points a day with your adopted
  pet out, more from activities later), never decays, and comes back if you adopt the pet again. Seven levels;
  everyone sees everyone's. The loyalty achievements (ids `loyal:*`) are bond levels now. The sync digest holds bond
  levels, not points: points go out lazily (a level-up at once, else within 30 minutes).
- **Nicknames belong to the pet** (2026-11-08): only its current holder can name, rename or clear it, after caring
  for it 7 days. The name stays when they let go, and the next carer inherits it until they change it. A name set by
  anyone else during a holder's care doesn't count (`Registry:Nickname`). It replaces the title line of the world
  tooltip, with the species moved below it, and shows big on the journal's pet card.
- Auto-summon turns itself off if AutoCompanion is loaded.
- `/dp rapport` checks addon users only and lists non-users locally as unknown. The result (who forgot their
  companion, by nickname; or praise when everyone has one out) shows in a dialog, and its button posts it to group
  chat (2026-11-08): posting needs a click, and the player sees the call-out first.
- Adopting and naming are announced in guild chat from the click or command that did it (`Bonds:Announce`), per
  character, default on, `/dp kunngjør`. Letting go and clearing a name aren't announced. The same line isn't
  repeated within an hour.
- Auto-summon only when idle: not in combat, mounted, on a taxi, flying, dead, stealthed, sitting, eating/drinking,
  casting/channeling, or in a battleground/arena. At most 3 tries per trigger. Toggled by the per-character
  "Auto-summon" checkbox in the journal (default on). It never replaces a pet you summoned yourself. It doesn't watch
  `COMPANION_UPDATE` (that fires for every nearby companion), so a pet you dismiss comes back only at the next
  trigger: loading screen, leaving combat, dismounting, or claiming.
- The summon clank (sound files 567569, 568424) is muted for 2.5 s after any `SummonPetByGUID` call, per character,
  default on, toggled with `/dp lyd`. Off when AutoCompanion is loaded (it has its own option).
- **Everything players read is Norwegian** (2026-11-08); developer output (`/dp probe`, `/dp debug`, the log) stays
  English. Companions are *adoptert* and *bor hos* someone, never "reservert". "Bor hos Kari Berg i 3 dager" /
  "siden i dag" / "siden i går" (`ns.CaredFor`), "Trenger et hjem", buttons Adopter / Gi slipp / Kallenavn, nicknames in
  «», dates as 08.11.2026. Commands: `/dp adopter, gislipp, navn, liste, lyd, prestasjoner, versjon, rapport`; the
  English ones (adopt, letgo, nick, list, sound, ach, version, report, and the oldest claim/release) still work,
  unlisted. Code and the wire keep English names (claim, Registry, `claims`).
- Counter: "Guilden: x av y har et hjem (z%)", y = every companion in Forever's journal (`Pets:Total`,
  `Data/Companions.lua`). The old "known" list is gone (migration 4).
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

- A "companions the guild is missing" list, from `Data/Companions.lua`.
- Mute the summon clank after loading screens and landing too. The game brings the pet back on its own there, with
  no `SummonPetByGUID` call to hook, so it still clanks. AutoCompanion mutes for a window after
  `PLAYER_ENTERING_WORLD` and dismounting (`AutoCompanion/Sound.lua`, `QuietSummon`).
- A settings UI. The summon sound mute is `/dp lyd` for now; it gets a checkbox there.
