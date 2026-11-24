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
  through `MIGRATIONS` in `Core/DB.lua`. Wire changes bump `X-Protocol` in the TOC (`52_protocol.lua` fails until they do). Since X-Protocol 11 a
  bump keeps older clients syncing down to `X-Protocol-Floor` (10): a new kind goes in `Wire.SINCE`, a changed one gets
  a new name; only raising the floor splits the guild.
- **Balance is wire.** Lowering an earning is free; raising `BOND_DAILY_MAX` or a `beyond` + `once` reward (the wish's
  10), or adding one, widens `Wire.DayRoom`/`LifeCap`: an X-Protocol bump, and in practice the floor raised too, since
  clients at the floor would refuse a fast player's bond (Bond.REWARDS' comment).
- Comments explain *why* (game quirks, decisions), not what.

## Verify

- `tools/check.sh` runs the TOC↔file check, a Lua 5.1 syntax check (luajit), a scan for 5.2+ syntax,
  luacheck (reads of unknown globals too: a misspelt or undeclared local; its config from the harness's stubs, `tools/lint_config.lua`: a client API must be stubbed before lint takes
  it; one read only behind an existence check goes in its OPTIONAL list; `-- luacheck: ignore NNN (why)` for a meant one),
  the Lua language server headless (fields and arguments: `ns.Bodn`, `ns.Wish:Grnat()`, an argument too many; value
  types are off in .luarc.json; it runs alongside the rest), and the test suite with coverage floors (~40 s).
  `tools/check.sh --quick` skips coverage (~8 s). The runner uses every core (`--jobs=N`; one process for `-v` or a
  filter matching under 20 tests), dealing tests longest first by their last times (`tools/test/.timings*`, untracked);
  `--slow[=N]` lists the slowest, `--shuffle[=seed]` runs in a random order. A filter matching nothing, or an unknown
  option, fails. The harness shares one memoized LibDeflate among its clients: a test that compresses a lot of
  unique data is slow under coverage (27_hardening's big message was 31 s of it).
- The game can't run from here. For in-game checks, ask the user to `/reload` and run `/dp debug on`, then
  `/dp probe` or the feature. Then read the log at
  `../../../WTF/Account/*/SavedVariables/Dyreparken.lua` (account folder: `NIKKERN`) (`DyreparkenDebugDB.lines`, tab-separated
  `serverTime  GetTime  module  message`, ring buffer of `Config.DEBUG_RING_SIZE` (8000); `head` is the newest index).
  **Read it with `luajit tools/log.lua`** (`-h`: the newest session by default, `--sessions`, `-m/-x` modules, `-g`
  text, `--summary`, `--errors`, `--dump api.glance`, `--db settings`, `--at 22:08` the lines around a time, `--rate`). Each login writes a `Session start` line first of all, and a
  `Session settled` one (zone, guild, pets) 10 s on; a line repeated right after itself becomes " (xN)";
  `/dp debug mute <Module>` silences a noisy one. `Moves.step` (every animation played) and `Sense.cast` (every cast
  seen) are quiet until `/dp debug unmute` (`Debug.QUIET`; `/dp probe sense` hears casts). Everything printed is
  logged as `Chat`, with the line's key when `ns.PickLine` chose it (`-m Chat`: what the player was told).
- `luajit tools/lines.lua egg.stup --pet 70` (or `--traits a,b`, `--class`, `--race`, `--all`): every text a pet can
  say for a line, by its nature, through the real ns.Lines and Moments.ByNature; for editing Locale/nb.lua.
- `luajit tools/chatter.lua --pet 70 --class shaman --days 28 --profile casual|regular|grinder|max [--chatter few]
  [--set boss=1,quest=2]`: days of scripted play (activities at guessed rates, fights with the class's casts) in a
  harness client: the bond's pace (days to each level), every line group with how often it came and on what share of
  days, and the groups heard first each week. The first three profiles are a levelling triple gatherer; `max` is a
  level 60 with no gathering (2026-11-24), the pace most players see; `--set` overrides an hour's rates. Run it after
  changing a chance, a cooldown or a REWARDS row. Our own Lua errors go into the log
  with their stack (Dev/Errors.lua, through BugGrabber), and `--errors` also reads BugGrabber's saved ones.
- The saved data itself: **`luajit tools/sv.lua`** (read-only; `summary`: claims, bonds, names, owners, each table's
  size; `check`: a harness client logs in with it, then lists what a peer's merge would refuse; `picks`: the editors'
  picks as Lua to paste, each marked if the data has it already; `--file`, `--char`, `-h`).

**Types** (2026-11-15): every file starts `---@class Dyreparken` / `local ns = select(2, ...)` (one class in parts), and
a module's table has its class: `---@class Dyreparken.Wish` above `local Wish = {}` (`ns.Wish = Wish`), and above
`local X = ns.X` in a file that adds to it (Core/Sources.lua, Dev/). `luajit tools/types.lua` writes the namespace's
fields to tools/types/ns.lua (check.sh does). Fields set elsewhere or at run time: `---@field` under the class line
(Moves' card methods, the dev hooks). `---@diagnostic disable-next-line: <code> (why)` for a meant exception.

## Testing

**Run the tests whenever you implement something new or change something existing**, and add or update tests
in the same change. Run `luajit tools/test/run.lua <filter>` while working, and `tools/check.sh` before
committing. A change isn't done while a test fails or a coverage floor is missed.
A `pre-push` hook (`.githooks/`, enabled per clone with `git config core.hooksPath .githooks`) runs
`tools/check.sh --quick` on the newest commit of each pushed branch, and the full check for a tag (once per push, not
per commit), in a temporary worktree, and refuses the push if it fails. CI runs the full check on every push.

- `tools/test/harness.lua` simulates a world: several clients (`w:AddClient("Ola Nord", opts)`), each running
  its own copy of the addon in its own global environment, with a shared clock (`w:Run(s)`, `w:SkipDays(n)`),
  guild roster, group, and an addon-message network. The network can lose messages (`w.drop`), take forged
  input (`w:InjectMessage`), and records every decoded message in `w.wire` (`w:Sent(kind)`). Clients log in
  and out with their SavedVariables kept (`c:Reload()`). There are helpers for the journal, tooltips, popups
  and player state. Read its header first: it's the entry point, and its parts live in `tools/test/harness/`
  (base, frames, world, client, ui, assert; the stub client API in `env/*.lua`, one file per area).
- The usual world is one line: `local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }` (Ola Nord, Kari Berg
  if given, logged in and settled; `each`, `settle`, `journal`). Wait for the login by name, not by a number:
  `w:Settle("hello" | "bond" | "day")` (12, 20, 40 s: past the HELLO round, Bond's seed, the first day's visit).
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
  (`GameTooltipTextLeftN`), and `c:Hover` returns the whole tooltip as its third value. `c:TipOf(frame)` hovers
  one of our frames and returns its tooltip's lines (`.text`: joined with " / "). Tooltips are data: a module's
  pure `XxxLines(...)` builds `{ { text, r, g, b, wrap }, ... }` and `ns.SetTip` / `ns.ShowTip` show them.
- Secure code and protected frames (`tools/test/harness/frames.lua`, its header): Blizzard's code runs secure
  (`c:OpenJournal`, `c:ClickTab`, `c:ToggleCollections` (the key binding), the secure template's click); the addon's
  handlers, hooks, events and timers never do. A Secure* template's frame is protected, and so are its parents and
  the frames it's anchored to (`f:IsProtected()`); insecure Show/Hide/SetPoint/SetSize/SetScale/EnableMouse/
  SetAttribute on one in combat fails the test with ADDON_ACTION_BLOCKED. `c:Press(button)` is a real mouse click
  (down and up, as the button registered: the secure template acts on the down while ActionButtonUseKeyDown is 1).
  An insecure ToggleCollectionsJournal or CollectionsJournal_SetTab taints the window (`c.insecureCJ`), and its key
  binding is then blocked in combat, as seen in game. State drivers (`RegisterStateDriver`, `c.drivers`) apply on
  `c:EnterCombat()`/`c:LeaveCombat()`.
- The harness blocks guild chat posts that don't come from `c:Slash` or a `Click` (Forever does; the test then
  fails with `ADDON_ACTION_BLOCKED`). Post to guild chat only from a keypress or click.
- Stubs must behave like the real client (docs/FOREVER_API.md). Unknown frame methods and unknown events throw
  on purpose, and reads of globals the stubs lack are reported (`01_core.lua`). When the addon starts using
  a new API, stub it realistically in the right `tools/test/harness/env/*.lua` (Client:BuildEnv runs them).
- Pin a test's world with the harness, never by replacing addon functions: `c:Traits{...}`, `c:Companions(...)`,
  `c:Fixture(fn)` (all survive `c:Reload()`), `c:Dice(roll, pick)` for every chance (the addon rolls only through
  `ns.random`), `c:QuirksNow()`, `c:SetBond(key, points)`, `w:SetDate(y, m, d, h)`, `w:SetHour(h, min)`. Tests run on
  Europe/Oslo time whatever the host's (run.lua), and the stubs' `date()`/`time()` without a time read the world's
  clock. Read state with `c:Points(key)`, `c:Listening(event)`, `c:CountPrinted(text)`.
- Read the UI as a player does, not through a module's private fields: `c:Visible(text)` (shown text, its parents
  shown too), `c:Labeled(text)` (the check box or button a label names), `c:Frames(pred, root)`, and
  `c:Page(title)` for our side pages (`.tab`, `.button`, `.frame`, `:Open()`, `:Row(name)`, `:Text(t)`).
- After every test the runner also fails it for a stray global or a printed `{placeholder}` (`H.Invariants`).
- Before relying on a new test, make sure it can fail: break the code it covers once and watch it go red.
- **Games (`Games/`) are the exception, for now.** That part is meant to stay dynamic and change shape quickly,
  so it has no coverage floor and only light tests (`10_games.lua`). They pin what must never break: UI changes
  are always undone, including after a reload. Don't let tests get in the way of reshaping game code. Tighten
  this once the games protocol settles.

## Adding content

`tools/test/spec/49_content.lua` walks all of it, so new content needs no test of its own unless it brings new logic.
- **A trait**: a row in `Personality.TRAITS` (what other modules ask of it goes on the row: `is = { tags }`,
  `place`), its `trait.<id>.*` lines, its particles in `Decor.TRAITS` (`icon` there too when the kind's texture is a dot
  or a sparkle: its badge on the card, AboutPet.lua; 49_content checks). Never a list of trait ids in another
  module: ask `Personality:Has(key, id)` / `:Tagged(key, tag)`.
- **An egg**: a row in `Quirks.EGGS` and its `egg.<id>.N` lines. Lines by nature: `traits` / `families` on the egg
  and `egg.<id>.<trait|family>.N`. Its activity is watched for it (Quirks.WATCH is built from the eggs). Ids are permanent.
- **An activity**: a row in `Activity.KINDS`, a source, `activity.<id>`; `dislike.<id>.N` if anything can dislike it;
  `icons` (a chip) or a `mark` (one of our textures) if a pet can like or dislike it (its badge on the card).
- **A family**: in `Scenes.ORDER` and a row in each table the content spec names.
- **A companion**: tools/companions/README.md, "Adding a companion" (its data, traits, moves' lengths, where it
  stands, its sound row). Parken's map grows by itself (rows by the count; the garden Park.GARDEN_CELLS, near the middle).
- Lines: `ns.PickLine(prefix, vars)`; a pet's own line: `ns.PetSays(text, key, kind)`.

## Releasing

- **Commit subjects and COMMIT.md** (2026-11-22, the user): every commit's subject is one line a player could read
  (what changed for them, not how), or starts with `Tests:`, `Tidy-up:`, `Notes:`, `Docs:` or `Developer probe` for
  what players don't see. For a release, `tools/changelog.sh --draft vX.Y.Z` writes `COMMIT.md` from the subjects
  since the last tag; the user edits it (reword, merge, reorder, drop), and running it again later adds only the
  commits since (their edits stay; `--force` writes it anew). Commit it before tagging: for that tag, release.yml
  uses it word for word (its `<!-- -->` lines left out) instead of the subjects. Keep it up to date as work lands.
- Before tagging, `tools/changelog.sh` prints what players will read (since the newest tag) and warns on stderr when a
  subject names an egg id, a hidden achievement or says egg/hidden/secret (a warning only). release.yml writes the
  changelog with the same script, and refuses a tag that isn't on main or isn't newer than the last.
- Push a tag `vX.Y.Z` (release), `vX.Y.Z-betaN` or `vX.Y.Z-alphaN`. `.github/workflows/release.yml` runs the checks,
  then BigWigsMods/packager@v2, which uploads to CurseForge (WoW Forever, 1.60.1) and makes a GitHub release.
- The TOC's Version is `dev` in a `#@debug@` block, and `# ## Version: @project-version@` in a `#@non-debug@` one: every
  packaged build is non-debug, so the packager deletes the first and uncomments the second, with the tag (2026-11-19:
  the bare token showed in the addon list for a checkout; 01_core checks the TOC). A git checkout reports `dev`
  (`ns.DEV`) and never shows "outdated" warnings.
- The CurseForge project ID is the `CF_PROJECT_ID` repository secret, passed as `-p`, so it isn't in the TOC.
- The changelog is written by the release workflow from commit **subjects** since the previous tag (bodies and
  Co-Authored-By lines left out; the Claude credit is one line at the top), skipping subjects that start with
  `Tests:`, `Tidy-up:`, `Notes:`, `Docs:` or `Developer probe`. So write subjects for players, and start developer-only
  ones with one of those words. `.pkgmeta` has `manual-changelog: CHANGELOG.md`.
- **Keep secrets out of the changelog** (2026-11-19, the user): easter eggs, hidden achievements and other surprises
  are never named in a subject. Wrap the giveaway in `{{...}}` (it shows as `*****`), e.g. "and {{ten thousand jumps}}
  earns something". A subject already pushed that gives one away gets a line in `.github/changelog-fix.txt`
  (`<full hash> <subject>`) before the tag.
- `.pkgmeta` lists the dev files left out of the zip: tools, docs, CLAUDE.md, README.md, .claude, .luarc.json, .github,
  .githooks, Dev (whose TOC lines sit in a `#@do-not-package@` block).
- Any wire format change bumps `X-Protocol` (the floor stays, see Working rules). Any saved data change adds a migration (see Working rules).

## Layout

```
Dyreparken.toc     load order (each file only uses files above it)
Libs/              LibStub, LibSerialize, LibDeflate. Don't edit. (ChatThrottleLib went 2026-11-12: unused since
                   Comm paces its own outbox, and it hooked every addon's sends.)
Core/Init.lua      ns, Config tunables, Bus (internal events, each declared in Bus.EVENTS: the harness checks), helpers (Now = GetServerTime, Plain/IsSecret, Today/Date,
                   Join, Capital/LowerFirst (a first letter, æøå too), Gold/PrintGold, SpellName, GroupChannel, Debounce, SetTip/ShowTip/HideTip (tooltips as
                   data: lines from a pure XxxLines builder), Call (a method that may not exist), PlayFirstSound), the start-up
                   phases (ns.Start, ns.RunPhase): use these,
                   don't write them again
                   ns.L / ns.T / ns.Fill: the strings (below)
Core/Wire.lua      what peers accept, in one place: Wire.LIMITS (key, name, version and id lengths, MAX_PARTS, MAX_RAW,
                   the bond cap, the lapses' cap, unknown guild achievement ids) and the primitive checks (Time, Since,
                   Name, Key, Version, Nick, AchId, Owned, DayRoom, LifeCap, and CHECKS for Comm's field specs), the protocol
                   window (SINCE: the kinds newer than the floor; Stamp: a kind's protocol on the wire; Compatible: what
                   we read, floor to ours). A change here (or to a Config value that feeds
                   validation) bumps X-Protocol; tools/test/spec/52_protocol.lua fails until it does
Locale/nb.lua      EVERY text players read, Norwegian, keyed ("card.home.today" = "Flyttet inn hos {who} i dag"),
                   grouped by area; named {placeholders}; the achievement texts (ns.AchTexts) at its end. Loads right
                   after Init and Wire. Code never holds player text: add a key here and use ns.L[key] / ns.T(key, vars).
                   Developer output (/dp probe, /dp debug, the log) stays English in the code.
Core/Debug.lua     ns.Log(module, fmt, ...) → SavedVariables ring buffer; no-op when off; repeats counted, muted
                   modules, a Session line at each login (tools/log.lua reads it)
Core/Events.lua    one event frame, and one per unit: On(event, owner, fn, unit) registers a UNIT_ event for that unit
                   only (the tests fail on one left registered for every unit); Off/Has/OffAll(owner), Registered,
                   OutOfCombat queue
Core/DB.lua        SavedVariables, defaults, schema migrations, DB:Guild() registry
Core/Comm.lua      serialize→compress→encode→chunk, our own paced outbox (not ChatThrottleLib), Register(kind, fn, from, fields)
                   ("GUILD"/"GROUP": other channels never reach fn; fields: { name = Wire.CHECKS name }, a malformed
                   message is dropped before fn), MayReply (requests anyone can send: once per channel every 5 s)
Core/Version.lua   HELLO on login, one-time outdated notice (0.2.x clients' VER_REQ went unanswered from 0.6.0, under the
                   floor; the code went at X-Protocol 12, 2026-11-17)
Core/Guild.lua     guild roster snapshot on demand (membership, days offline; Guild.known: the last complete one, which
                   judges whose data the sync keeps; Guild:Soon, a read no sooner than ROSTER_INTERVAL)
Core/Activity.lua  the activity engine: game events -> activities, every one declared once in Activity.KINDS (always
                   watched or not, wishable, chip icons; its words in Locale by id), counted per
                   character after combat, Bus "ACTIVITY". Events registered only while a consumer wants them
                   (Want/Drop). Bond, achievements (`activity` kind) and stories build on it. Read its header.
Core/Sources.lua   the activity engine's sources, by area (what in the game counts as each activity)
Core/UI.lua        the UI kit: MEDIA/Icon(name) (our particle textures), Edges, Gradient, RoundBadge (disc, ring, icon)
Core/Anim.lua      shared animation pieces for the card (Pulse, OneShot, Fade, Scale; Decor's Loop,
                   Timeline, Swing/SetSwing): no BOUNCE loops, one group per region
Core/Timers.lua    ns.Timers(): a group of cancellable timers (After, Every, Cancel bumps a generation): use it instead of
                   a hand-written token guard around C_Timer.After
Core/SidePage.lua  our pages of the Collections window: a side tab each under Blizzard's, the page covers theirs
                   (no taint: never their SetTab or tab list), title/portrait swapped and put back. Read its header.
Core/Commands.lua  /dp slash commands (adopter, gislipp, navn, liste, lyd, prestasjoner [alle], kunngjør (kunngjor too, not
                   listed), klapp (also /klapp on its own, 2026-11-19; c:Chat("/klapp") in the tests), innstillinger; Norwegian only; an unknown word says so); ns.Commands.Add for Dev/Commands.lua,
                   whose help is under /dp dev. A release never logs (Debug:Init turns a saved log off)
Data/Companions.lua GENERATED (tools/companions/build.py --lua; per build, tools/companions/wago.py first: Forever's
                   tables from wago.tools, no game needed; the tools stay out of git; a new companion:
                   tools/companions/add.py, see "Adding a companion" in tools/companions/README.md): every journal species, whether
                   it counts toward achievements (a), and its tags/families (t). Don't edit by hand.
Data/PetMoves.lua  which animation each pet uses for each reaction on the card (sleep, sit, happy, cheer, dead): a
                   default and per-species overrides, EDITED BY HAND by the user (found by eye, /dp probe anim)
Data/AnimLengths.lua GENERATED (luajit tools/anim_lengths.lua, from a /dp probe api lengths run): how long each
                   species' one-off moves play, so the card moves on when one ends (Moves:Length); else Moves.T. Don't edit
Data/PetBoxes.lua  GENERATED (luajit tools/pet_boxes.lua, from a /dp probe api boxes run): every species' standing box
                   and model scene. Don't edit
Data/PetScenes.lua where pets stand and how tall (Moves.FRAMING: placed by their feet, 2026-11-16): ns.PetScenes per
                   model scene, ns.PetModels per model (pets sharing one share their box in Data/PetBoxes.lua,
                   Moves.ModelOf; a model's row goes first), per stage (park and frame fall back to the card's),
                   EDITED BY HAND from /dp probe place (a model at a time)
Data/PetSounds.lua the pets' own sounds when clicked on the card (Cuddle; setting petSounds): sets of sound files,
                   and a row per species (a set or false: quiet; every species needs one, 34_touches), EDITED BY HAND
                   by ear (/dp probe sound); a new companion's row: tools/companions/README.md
Data/Familiars.lua a mage's familiars from scrolls (rat, frog, cat; 2026-11-17): their bond keys ("n:<name>",
                   permanent), item, buff spell, npc, model and family, from the client's tables (wago.tools)
Data/Zones.lua     zones, one row each (level, faction, capital, climate, high, neutral, home families), EDITED BY
                   HAND: Personality's climates and cities, Quirks.HOME_ZONES, Wish.ZONES, Sense's capitals are views
Data/Unlocks.lua   every species' minor like and minor dislike (your bond unlocks them at levels 4 and 6), PINNED
                   for good like the traits (2026-11-12): luajit tools/pin_unlocks.lua adds new species (from
                   fitting lists per family and species, never a major like or dislike) and never changes a line
Data/WeatherPins.lua every species' weather likes and dislikes (rain, snow, sand: Personality.WEATHER, only where it had
                   room), PINNED like the unlocks (2026-11-22): luajit tools/pin_weather.lua adds new species, never changes a line
Data/Traits.lua    every species' two personality traits, PINNED for good (decided 2026-11-08): never reshuffle.
                   After regenerating Data/Companions.lua, run `luajit tools/pin_traits.lua`: it adds new species
                   (least-used traits) and never changes an existing line. Change a species by hand only.
Menagerie/         Pets (journal access, pet keys, OutKey: the pet out now, probes), Registry (reservation data model, members only,
                   merge + holder rules: read its header first; Status: mine/taken/free; NameOf/NameFor: what a pet is called), Sync (HELLO digest, SYNC/UPD/NICK/BOND/LAPSE, guild channel only;
                   the digest and SYNC also carry guild achievements),
                   Owners (2026-11-15, X-Protocol 11: who in the guild owns which pets, g.owns[member] = { at, s = "40,5159" },
                   written by each member, only growing; its own digest in HELLO's `o` and a lazy paged OWN_SYNC, OWN when
                   ours changes; not in the registry's digest, so 0.7 clients sync as before; Of/Any/Others/Line also count
                   holders and bond carers; Personality:Known and Parken's question marks read it; read its header),
                   Familiar (2026-11-17: which mage's familiar is out, read from its buff by id and name and
                   remembered until its end, through secret or failed reads, a /reload, and a "gone" until a second read
                   3 s later agrees (flight paths, mounts); Bus FAMILIAR; a mage watches the scrolls' casts; read its header),
                   Summon (auto-summon, defers to AutoCompanion; never replaces a familiar), OutBadge (the "Med deg" badge: which pet is kept out;
                   "Bytt inn" when the pet out is full and this one has room; Turnus' small toggle beside it), Turnus (2026-11-22:
                   2 to 5 pets take turns as the "Med deg" pet, a new one each day and the next with room when one's day
                   fills, Summon:Rotate; listed at the top of the story panel's Flokk tab, AboutPet),
                   JournalList (the journal's list: markers, bond rings, nicknames, tooltips), CardActions (the card's
                   Adopter / Gi slipp and Kallenavn buttons and popups), JournalUI (the card and the wiring),
                   Card (the card's widgets: one ns.Card.Register{ id, build, update, pause, stop } each, run in
                   Card.ORDER for build, update, our pages' pause and the card's one OnHide; a widget with nothing
                   to stop says still = true),
                   AboutPet (2026-11-19, the user: room for more traits, moods, temperaments: a pet's personality on its card as a row of
                   round badges between the home line and the bond strip (the "badges" widget): its traits, likes (green ring, a minor one dimmed), dislikes
                   found out (red) and a "?" for the secret ones, each with its tooltip; a click opens the panel on "Personlighet", every
                   trait, like and dislike in words; "Bånd" there lists everyone's bond with the pet, strongest first. A mood or
                   temperament is meant to go at the row's end, the two next to each other (the user; undecided yet);
                   c:About(key, tab) reads a tab in the tests),
                   Tooltip (reservation lines on companion units; owner parsed from tooltip text)
                   Sense (2026-11-14, docs/CLASS_INTERACTIONS.md part 1: sensors for the class, race and faction
                   reactions (the class ones read them: Reactions.lua; race and faction ones don't exist yet): glance (a unit under the mouse), cast, form, buff, pet, group,
                   flag, zone, emote; each fires Bus "SENSE" (kind, subject), registered only while wanted
                   (Sense:Want/Drop), nothing from secret units; Sense.Match for rows; Data/Creatures.lua maps
                   creature family ids to our families, edited by hand, and a beast's or critter's name words when it
                   has none (Forever's own creatures, 2026-11-15); /dp probe sense logs them all)
                   Unlisted (2026-11-14: a companion not in Data/Companions.lua, seen under the mouse, learned
                   or owned at login, is told once per account in chat, with its species id and who to tell,
                   Config.REPORT_TO; DyreparkenDB.unlisted keeps them, the developer's list to add),
                   Reactions (2026-11-14: your pet reacts to what your class does, read from the sensors: rows in
                   Reactions.ROWS by class (or race: a Tauren's War Stomp; UnitRace's file name, undead "Scourge") and spell name (Forever's spell ids differ), lines by nature
                   (react.<id>.<trait|family>.N), once a day each, common ones at most one every 20 minutes
                   (char.reactAt, beside Quirks' 45), rare ones always (with another line on its way, half the
                   time: RARE_SKIP), a fight's after it; counted in char.reacts
                   for achievements of their own once enough rows exist; plan: docs/CLASS_INTERACTIONS.md)
                   Moments (2026-11-14: what Quirks' lines and the reactions share: lines by nature
                   (Moments.ByNature), the cooldown budgets (quirk 45 min, react 20), ONE line on its way at a
                   time for both (one held back by it waits its turn: Moments:Later, a minute at most), the waits
                   (Moments.DELAY = Quirks.DELAY), counting once a day (SaidToday, Count), the day's roll (Moments.Rolled,
                   char.rolls, 2026-11-19: a line's chance is rolled once a day at its first moment, so it's the
                   share of days; rolled at every moment, a 40% landed on nearly every day; an egg's chance as a
                   function stays this moment's own: a new boss, a level)),
                   Holidays (the game's holidays from the calendar, today's, by event id: Lunar Festival, Love is in the Air,
                   Noblegarden, Midsummer, Harvest Festival, Hallow's End, Winter Veil; not the Darkmoon Faire, too often),
                   Personality (likes, and two traits per species from Data/Traits.lua;
                   liked activities, and anything done at a trait's moment, give more bond points), Scenes (backgrounds behind the pet on the card, by family, and the light of the hour; the
                   card's tier colors: Tier, Bright; Scenes.LEVELS: what each bond level brings, read by Decor, the
                   bond's words and stars, the medallion and Fx's hearts), BondTrack (the bond on the card: a medallion with the level, a track of seven stars,
                   a tinted bar with a spark; a celebration once per new level of your own pet, char.bondSeen), BondBar (the bar the card and the pet frame share:
                   ns.BondBar.New, :Set(points, from, top, tier), :Gains(last, list) grows it and floats the "+N", :Stop), Stats (what you've done with a pet: chips at the top of its card, from the activity counters),
                   Playdate (in a group with a guildmate whose pet is out: both pets play, once a day each;
                   PLAY on PARTY/RAID), Quirks (flavor with no effect: dislikes and easter eggs, at most one line
                   every 45 minutes; read its header), Fx (the one particle burst engine, a pool per parent: the card's bursts on the card; outside the journal: hearts at the cursor over a
                   companion in the world, since companions have no nameplate to draw on; at the chat window for bond
                   lines and level-ups), Voyage (zeppelins and boats: a loading screen between two zones a route joins,
                   ROUTES, not after a hearthstone or portal; a zeppelin counts as flying too; eggs luftskip, seilas
                   by trait and family), Fight (the pet frame's pet joins your fights now and then, by its traits: an
                   attack move, a timid one cowers, a Latsabb watches; no combat log, so a "swing" is a physical hit on
                   your target (UNIT_COMBAT) while your auto-attack is on, one per weapon swing, plus your casts; only in
                   a fight and only while the pet frame shows a pet), Meter (0.5: after a boss kill in a group of three or more, with a pet out, the
                   meter's Current session read once, a second after the boss activity: first in damage, first in healing
                   in a raid, the most interrupts are eggs-only activities (dmgtop, healtop, kicktop); their eggs
                   (toppen, helter, sparket) a gold bubble and a cheer, likelier in a raid and far ahead), Feats (a character's big moments, 0.5: a class quest's reward, riding, level 60
                   give the pet that's out 25 points once per character, by the spell taught (SPELLS_CHANGED) or the
                   quest's id; what was had at the first look isn't new; a trainer visit, a dual-spec switch, a talent
                   reset and the tenth levels are eggs only; read its header), Wish (today's wish: one of your pet's likes a day, +10 when done, a line on the card; a gathering wish also
                   by a party member's gathering within ~40 yards, the wish only (their Dyreparken's GATHER on PARTY, a new
                   kind without a protocol bump: their casts are secret to us; in a party, out of combat), or by hovering a node that
                   says so in its tooltip (Wish.NODE_WORDS, 2026-11-19: a herb, a vein, a skinnable corpse; unverified words,
                   logged while such a wish waits); wishes in a row, char.wishes, with achievements at 7 and 30 in a row and 100 in all), Moves (the pet on the card moves: asleep at night, a Latsabb sits, a click is a happy move, a level-up a
                   cheer, a jump with you (every pet: canJump), playing dead the day of the three-deaths egg; a move a moment earns the pet is owed once,
                   Moves:Owe(key, "dead"|"joy"|"sulk"), char.owed (an egg's `move`); which animation per species: Data/PetMoves.lua; every step list comes from the pure planner Moves.Plan, the stages only play plans), Cake (a cake with flickering candles on an adopted pet's card on its milestone day; a click on a guildmate's
                   congratulates them), Crown (the pet of the day's gold crown on its card, beside the cake), Story (a pet's story: a local
                   timeline of its life in the guild, g.story, found by comparing the registry with what it last saw,
                   plus your moments with it; a book button on every pet's card (an arrow: it opens out to the side) opens a panel right of the window, newest first, with tabs
                   (Story:AddTab; the one last chosen opens next): Historie, and AboutPet's; flavor (eggs,
                   pet-of-the-day days) older than Story.FLAVOR_DAYS folds into grey "N interaksjoner" lines, 2026-11-19), Onboarding
                   (2026-11-19: a new player's welcome once an account, the line after a character's first adoption, the
                   card's "?" with how this pet's bond grows; an old install skips the first two: account migration 15, char
                   4; /dp fresh [solo|reset] replays them), Cuddle (a click on the pet:
                   a ripple, hearts, a glow; once a day a cuddle), Decor (pet card decorations: one more per bond level of the holder
                   (border and color wash: family, silver, gold; corners; glow; sparks; ribbon and turning rays; hearts),
                   particles from traits (every trait has some; those with a moment show only then) and the date, and
                   each family's ambience, always (Decor.FAMILY: feathers, embers, gears, lily pads...; the same row gives its
                   mark on Parken's sign, Decor.Mark); each kind with its
                   own motion (sway, spin, tilt, throb, flap) and path (rise, fall, burst, twinkle, steps, drift, wind);
                   the everyday ones scaled by bond level (Decor.DENSITY, a curve: 45% at 1 to 130% at 7, tuned by eye);
                   a border per family (Decor.FAMILY_ART, picked with /dp probe frames), corners the same for all (wood, filigree
                   from 5); gallery picks show on the card only while a gallery is open, so write them into the code; animation
                   groups only, timelines in steps (never Alpha delays inside a step), one playing group per region
                   (holder frame: path; inner frame: sway; texture: spin/tilt/throb), no BOUNCE loops (REPEAT steps that
                   come home instead), stopped when hidden),
                   ParkPage ("Parken", the park map SidePage: every journal companion as a round portrait (or a question
                   mark for one nobody in the guild has: Owners, Park.Unknown; a click wiggles it) (Pets:Portrait, also
                   the list's icons) in a ring of its holder's bond level, grouped by family into tinted enclosures on a grained ground (Media turf, one tile over four cells) with wooden fences (one on each line between two), a sign on
                   each (its family's mark; hover: name and homes; click: only that family), the pointer's family lit (and its sign), the
                   a fenced garden of Park.GARDEN_CELLS cells in among them (a run of the path between two families, nearest the map's middle: Park.Layout; its pieces nearest its own middle; lawn, tree, pond, flowers in grass, a bench under a lamp lit at night, signpost, feed trough, stump (2026-11-16: a zoo walk); a click on a piece: a hop and a few particles, one in eight a surprise of its own, Park.GARDEN, nothing saved or told; every piece clicked within 15 s: the whole garden at once; by the clock and calendar, Park.Weather: the season's lawn, darker with fireflies at night, snow in December, autumn's orange leaves; /dp probe garden <hour> [month] to look)
                   along one path through the grid (Park.Path: each family one piece; a sign clicked swings on its post, the chosen one bigger and gilded; your own pet's cell sends out paw prints now and then; today's pet wears a small gold crown on its corner, 2026-11-21), a click opens its card on the Pets page (also pets you
                   don't own); under the map a stage with today's pet, or the one hovered, as a live model (Pets:LoadModel), the bond's glow at half strength and half the card's particles behind it (Decor:BuildStage, Decor.STAGE, 2026-11-19), fenced as the pens are (Park.StageFence), and at its right the guild's records and the legend, short, in full on hover (Park:Side);
                   loads after Achievements/Page.lua so its tab comes second),
                   PetFrame (the pet that's out on screen; mounted or on a flight path the last one out, else the one kept out (Med deg), none while
                   you're dead, optional and off by default: its own ModelScene with the card's view
                   insets, a stage of Moves so it moves 1:1 as on the card (and asleep while you're AFK, a rare line as it
                   wakes: Quirks' egg vaken; after a dislike its back turned with a cloud, kept through every move until its card's sulk has played or the day ends: Plan.Away, opts.sulks, 2026-11-19), name and a slim bond bar with the rising numbers;
                   a click opens its card through a secure button of its own over it (SecureActionButtonTemplate, type
                   "click" on CollectionsMicroButton: Blizzard opens the window untainted, on its last page; never our
                   ToggleCollectionsJournal or SetTab; on UIParent, matched to the frame out of combat, never its child or
                   anchored to it, so the frame stays unprotected; a state driver hides it in combat with petFrameCombat;
                   hidden in Edit Mode; in combat a click toggles the window and the card waits for the fight's end:
                   JournalUI:ShowWhenOpen/AfterCombat; read the header of its click section); placed and sized (mouse
                   wheel) in Blizzard's Edit Mode, char.petFrame),
                   Settings (the settings page: a SidePage with no tab, opened by a cog in the Collections window's title
                   bar, shown on the pets, Parken, Prestasjoner and itself, "Tilbake" back to the page it came from
                   (2026-11-15); five sections on faint panels in two even columns within the page (Settings.SECTIONS,
                   Settings.PAGE; this character's settings marked *, 2026-11-21); the same two columns in Blizzard's options too (Esc > Options > AddOns >
                   Dyreparken: Settings.Canvas, a canvas category; c:OpenOptions in the tests); the four older per-character settings plus the account's DyreparkenDB.settings: chatter ("Småting i chatten", a slider of four steps, 2026-11-15: none hides the lines only; few doubles
                   the waits and halves every chance; many a third of the waits (an egg's stays) and half again the lines' chances,
                   not the eggs': Settings.CHATTER, Moments:Every; account migration 14 from chatLines),
                   worldHearts, cardParticles all/few/none, cardMoves, celebrate, hideUnknown ("Ukjente dyr som spørsmålstegn", on by default: Parken's
                   question marks), and the pet frame's (petFrame, petFrameArt,
                   petFrameCombat, petFrameFade, petFrameAlpha); modules ask Settings:On(key)),
                   Bond (the bond score between a carer and their pet: levels, daily points, seeding; data in
                   g.life, see Registry.lua; docs/PET_LIFE.md. Data only, it prints nothing: BOND_LEVEL, BOND_FULL,
                   BOND_LINE on the Bus. Rewards beyond activities (wish, first, playdate) are rows in Bond.REWARDS,
                   given with Bond:Reward),
                   Bonds (what players read about bonds: levels, full days, reward lines; milestone lines after login, the nickname unlock note, dagens dyr, /dp klapp,
                   guild announcements)
Achievements/      Defs (ids, kinds;
                   ids are permanent), Achievements (evaluation, quiet first runs, ACH_EARNED notices,
                   /dp prestasjoner del; guild ones synced with the registry, ACH), Page (the achievements SidePage;
                   Del per shareable one).
                   Plan and decisions:
                   docs/ACHIEVEMENTS.md (read it first). Planned next: bond, temperament and the activity engine,
                   docs/PET_LIFE.md.
Media/Particles/   our own particle textures (heart, sparkle, star, dot, bubble, confetti, note, paw, leaf, moon, snowflake, ring, rays,
                   and since 2026-11-09 feather, ember, gear, wisp, coin, grain, seed, clover, zee, speech, crumb, cloud,
                   pebble, chevron, bolt, halo, sword, drop, butterfly, mist; house, the list's mark for a pet that needs a home; cake, Cake.lua;
                   since 2026-11-12 the pet frame's bubbles speechblank, thought, shout and rain, the families' yarn
                   (cats), petal (plants), shell (murlocs), and the traits' banana, mask, sun, badge; 2026-11-15 Parken's
                   fences, plank and post, its sign, tree, pond, flowers and stump (and since 2026-11-16 signpost, bench, trough; the bush went 2026-11-19), in color, not white, and the pens' ground, turf (a seamless grain, near white, tinted); the signs'
                   marks snake, cheese, horseshoe, lilypad, egg):
                   white with soft alpha, 64x64 32-bit TGA, to tint and animate. Drawn by tools/draw_particles.py;
                   edit the script and rerun it rather than editing the files.
Games/Framework.lua game definitions, lifecycle, UI stash/restore, history
Dev/               DEVELOPMENT ONLY (2026-11-12, refactor phase 5): what only a git checkout uses. Listed in the TOC
                   between #@do-not-package@ and #@end-do-not-package@ (the packager strips the block; .pkgmeta
                   leaves Dev/ out), after every module, so each file can extend the one it probes. Shipped code never
                   calls into Dev/: a dev tool changes the card through an override hook a release leaves nil
                   (Moves.override, Decor.override, Scenes.override, BondTrack.override). The tests load it all; a
                   client made with { release = true } loads the release's files only (spec/48_release.lua), and one
                   made with { from = "v0.7.1" } runs that release's own code from git (an older client: spec/65_owners.lua;
                   CI's checkout fetches the tags for it).
                   Commands (/dp probe [more|tabs|kills|life|world|card|bg|decor|frames|level|celebrate|anim|ach|pos|
                   place|lift|moves|gains|api|sense|perf|garden|sound|verify|watch], /dp debug and /dp fresh, only when ns.DEV; place: the
                   per-scene floor and size editor, PlaceEditor.lua, picks in DyreparkenDB.placePicks); Errors (our Lua errors into the log); Verify (2026-11-20, /dp probe verify: one checklist of everything unconfirmed in game, 236 items by area: activity, api, react, egg, zone, route, look (ticked by hand: ok <id>), new (events that might become interactions); each ticks itself the first time it happens, from a debug log line (Debug.tap, a release leaves it nil), an event of its own, or an answer read now; kept account-wide in DyreparkenDebugDB.verify, on at each login until off; add an item there when something new is unverified); Watch (2026-11-24, /dp probe watch [sit craft group scene pet spot jump|range|status|off]: the in-game questions of
                   docs/review-2026-11-24 as session watches to the log, "Watch <watch> ...": sitting and refused summons, crafting
                   queues, ready checks and the range APIs, cutscenes and vehicles, when the game takes and brings back the pet,
                   subzones (DyreparkenDebugDB.watch.subzones) and swimming, a jump's landing; an hour, listening only); State (/dp state: cooldowns, today's lines, the wish, events); Try (/dp try egg|react|dislike|line|wish:
                   a line now, by nature, nothing counted); Perf (/dp probe perf: calls and time per
                   handler, through ns.profile, the one hook Events, Bus and Activity check; a release leaves it nil); PetsProbe (/dp probe, more, ach);
                   MovesProbe (/dp probe anim and pos, the editors' Moves.override); DecorProbe (/dp probe decor,
                   frames, level: Decor.show/preview, Decor.override, BondTrack.override); ScenesProbe (/dp probe bg);
                   BondTrackProbe (celebrate, gains); JournalProbe (card, tabs); SceneGallery (the galleries of bg,
                   decor and frames: thumbnails of every candidate that exists; picks in DyreparkenDB.scenePicks,
                   decorPicks); LiftEditor and MovesEditor (/dp probe lift, moves: picks in DyreparkenDB.liftPicks,
                   movePicks, to write into Data/PetMoves.lua); DecorCandidates (GENERATED from the retail atlas
                   list); SceneArt (GENERATED by python3 tools/scene_art.py, 2026-11-21: every large picture the build
                   has, from its tables on wago.tools: loading screens (Forever's own too), the dungeon journal's, scenic
                   atlases, each with its art's crop and shape, and suggestions per family; /dp probe bg shows them per
                   family and group, cut to the card's shape, hover previews on the card; a pick is a file id or
                   "atlas:<name>", and a file's crop goes in Scenes.ART: sv.lua picks prints both; its download cache
                   tools/.scene_art/ is gitignored, with a preview page there); Kills (research probes: honorable kills while debug is on; /dp probe kills, life and
                   world: companions' nameplates); ApiProbe (/dp probe api [section|clear]: what the client really has (globals, C_* namespaces, Enum, events,
                   widget types and their methods/handlers, templates, global strings, getters' values, the card's
                   actor, the calendar, a pet model's animations and lengths), read-only, in DyreparkenDebugDB.api; by name only:
                   holidays (the calendar a year ahead), lengths (every species' moves, DyreparkenDebugDB.animLengths)
                   and feats (Feats' spell and quest ids as the client has them, Forever's copies among your completed
                   quests, talent/spec getters; then logs the candidate talent, spec and trainer events this session);
                   transport (zone, map and world changes, casts and a sample every 5 s, this session: zeppelins and boats); legacy (professions and their caps, exploration and legacy achievements, Legacy globals: for wishes a level 60 can no longer do);
                   combat (auto-attack, auto shot, casts, UNIT_COMBAT on you and your target, swing speeds, this session))
Main.lua           bootstrap: runs the start-up phases (loaded, login, settled, hello). Each module declares its own
                   start at the end of its file, ns.Start(phase, fn) (Core/Init.lua); within a phase, TOC order
tools/check.sh     all offline checks (see Verify)
tools/test/        harness.lua (the entry point: simulated clients + network; its parts in harness/: base, frames,
                   world, client, ui, assert, and env/*.lua, the stub client API by area), run.lua (runner,
                   coverage), spec/*.lua
```

## Decisions (2026-11-06)

- Libraries: minimal (no Ace3).
- A reservation is **one species per character**, guild-wide, first come first served by `GetServerTime()`.
- Released when the owner leaves the guild, or after 30 days unseen. Nicknames unlock at bond level Venn (3), max 20
  characters (`ns.Config`).
- **Bonds** (2026-11-08, docs/PET_LIFE.md): a score per carer and pet that grows (10 points a day with your adopted
  pet out, more from activities), never decays, and comes back if you adopt the pet again. Seven levels on a curve
  to 2250 points (100, 270, 530, 900, 1440, 2250, decided 2026-11-09: 30 days at the very least, seven months of
  days alone, about seven weeks for a casual player); at most 75 points a calendar day (Config.BOND_DAILY_MAX: the day and every activity together; the bar shows
  today's share and "Fullt for i dag");
  everyone sees everyone's. The loyalty achievements (ids `loyal:*`) are bond levels now. The sync digest holds bond
  levels, not points: points go out lazily (a level-up at once, else within 30 minutes).
- **Bonds with every pet** (2026-11-09): any pet you own that's out earns bond points, each with its own day; one
  you haven't adopted at half rate (Config.BOND_OTHER_RATE, its day 37). The card shows an adopted pet's holder's bond (2026-11-09, reversed from "yours first" the same day), with your own bond with it as a small line under it (Bond:Yours), and a dim "Ikke samlet" in the paw badge's place for a pet you don't own; a pet without a home shows yours; the list's ring is your level in gold, else the holder's in grey. Only adopted bonds
  (each pet's holder's) ride the full SYNC and the digest (Registry:AdoptedLife): with ~100 members and several pets
  each, all bonds would outgrow a SYNC. Other bonds go out as their owner's BOND messages, and a card asks the guild
  once per pet a session (BONDS_REQ since 2026-11-19: one client answers with every bond it knows, BONDS, the others
  hold back; older clients' BOND_REQ is still answered with one's own BOND); they may be a little behind, by design. Wish and nicknames stay adoption-only.
- **More ways to bond** (2026-11-09): firsts together (a boss this pet hasn't seen fall, a place it hasn't been: 10
  points), playdates (15, once a day per pet, with a guildmate's pet out in the group; Menagerie/Playdate.lua), and
  skill-ups (verified 2026-11-09) and reputation (verified 2026-11-11) as activities. All at the pet's rate, within
  its day.
- **Balance pass** (2026-11-10, the user: "many max out after 15 mins of normal activity"; one dungeon of firsts
  filled the day): firsts 5 points (was 10), at most 15 a day; everyday (not liked) activities 1 each, at most 3
  per kind (was 5) and 10 in all; a trait's moment at most 10 a day (was 25). Unchanged: the day 10, likes 5 each
  (25 a day), wish 10, playdate 15, and the 75 a day (BOND_DAILY_MAX feeds validation). Likes are what fill a day.
- **Data pass** (2026-11-10, with the user): every journal pet tagged and its source checked (tools/companions:
  tags.csv, curation.csv; 78 of 88 count toward achievements since 2026-11-15, when the Shen'dorei Wisp joined the store pets (the user); four species hidden from the journal added by hand: Spectral Bear Cub (Legacy Track, counts), White Tiger Cub (the Black Market, counts; 2026-11-12), Bronze Whelpling and Mini Uber Diablo (source unknown)). Two new families, `bear` (Panda Cub) and
  `reptile` (Baby Crocolisk, Speedy). The Zergling is a demon. Limited pets count (2026-11-12, the user: "as
  long as it was never impossible to get"; until then they didn't): the store pack pets (Panda Cub, Mini Diablo,
  Zergling, Pachimari: Skyborne Epic Pack or Warcraft Forever Collection) and Azurky; the Musical Gustjumper is
  open world (/sing to a frog on Zephras Isle). Pets nobody knows how to get yet don't (Galestrider Chick,
  Minfernal, Spawn of Grubthor, the four Lashlings), nor removed ones, nor the Wild Chicken, whose card shows no model on Forever. Event pets also get a body family.
  Forever is the classic world (Quirks.HOME_ZONES uses classic zone names).
  Any pet can be adopted, whatever its availability; only achievements depend on it. The guild total counts every
  pet in Data/Companions.lua, limited ones too: Azurky (5179, a 12-month subscription reward the journal hides)
  was added by hand with a curation row, and has a family of its own, `murloc`.
- **Campfires** (2026-11-11, the user; new on Forever): four buffs as activities (Activity.AURAS, by spell name
  on UNIT_AURA, out of combat): campnear 1283391 (a fire nearby, constantly), campwarm 1229739 (Welcoming Campfire, the
  minute's countdown), camp 1229741 (after the minute), rested 429959
  (Well-Rested, a sleeping bag). Any pet wishes for camp one day in Wish.CAMP_EVERY; Latsabb, Kosete,
  Hjemlengsel and Friluftsdyr also for rested. Eggs: cozy traits (Quirks.COZY) enjoy it, adventurous ones
  (Quirks.ADVENTUROUS) get restless, the rest say nothing.
- **The fishing contest bonus** (2026-11-11, the user): a pet that likes fishing, out while you fish in Stranglethorn
  on the day the calendar has the Stranglethorn Fishing Extravaganza: 10 points once that day (Bond:Contest,
  Config.BOND_CONTEST_POINTS, within the day's 75; no protocol change). A new flight path matters only to a pet
  that likes or dislikes flying.
- **Feats** (2026-11-12, the user, for 0.5; Menagerie/Feats.lua): a class quest's reward, learning to ride and level
  60 give the pet that's out 25 points (Config.BOND_FEAT_POINTS), once per character, only with a pet out, and
  **past the day's 75, not counted in it** (the user: "major feats should not count towards the daily limit, they're
  supposed to be huge bonuses"). They stay within the wire's cap (Registry.LifeCap keeps spare days, three since
  X-Protocol 10 so a feat on a full day always fits). A trainer visit, a dual-spec switch, a talent reset and the tenth levels 10-50 are eggs only, no points.
- **Wishes go past the cap** (2026-11-13, the user: "Yes, definitely past the cap. Ensure this doesn't mess with
  antitampering"): today's wish come true gives its 10 points past the day's 75, not counted in it, like a feat
  (Bond.REWARDS `beyond`). Our own entry still stays within Wire.LifeCap (Bond:Add clamps; the line says what was
  really given), so peers keep accepting it. Since X-Protocol 10 the cap's room a day is the day's 75 and the wish's
  10 (Wire.DayRoom, from the REWARDS rows that are `beyond` and `once`), so full days with every wish done are never
  clamped (26_story runs 20 of them).
- **New traits and a one-time rework** (2026-11-12, the user, for 0.5): 13 traits (Sjørøver, Skøyer, Røverdyr
  against Ordensdyr, Venneflokk, Vinterpels against Solelsker, Tivolidyr, Bålkos, Skybåren, Jeger, Håndverker,
  Diplomat; 38 in all) and four activities for them (gold, fun, sneak, meet). Every species nobody in the guild
  had adopted was re-pinned by hand in Data/Traits.lua that day; the eight adopted then (Black Tabby, Senegal,
  Cockroach, Brown Prairie Dog, Excitable Slime, Panda Cub, Zergling, Mini Diablo) kept theirs, and so did the
  Mechanical Squirrel, adopted on 0.4.4 later that day (checked before 0.5.0's release), and so did the
  family and species like lists (their majors come from those too). From now on the pins hold again. The zone
  traits read GetZoneText (Personality.COLD/WARM/HIGH/CITIES); Forever's names there are unverified.
- **One like from the families** (2026-11-12, the user: "a bit crazy that it has 6 while the prairie dog only has
  2"): a species gets one of its families' likes, the one that fits it best, picked by hand in
  `Personality.FAMILY_PICK` (a test asks for a pick wherever the families give more than one), plus its story's
  (BY_SPECIES) and its traits'. The adopted pets kept all theirs (Senegal, Mechanical Squirrel, Panda Cub: a list
  there; `false`: none). A family dislike a species is spared: `Personality.NO_DISLIKE`; one of its own:
  `DISLIKE_BY_SPECIES`. (The 4-6 likes and dislikes together of that day: replaced 2026-11-19, below.)
- **More likes, and a third trait** (2026-11-19, the user, once the card's badges made room): **every species has
  4 to 6 likes and 2 to 3 dislikes at level 7** (the minor ones and the third trait unlocked), never more before
  (43_new_traits holds it). Every trait has a like now (those with only a moment or a day had none: Klengete kos,
  Nattugle nye steder, Festglad dansing, Helgetroll sovepose, Flokkdyr selskap fra guilden, Einstøing fisking,
  Huleboer dungeons, Friluftsdyr bål, Ordensdyr ærend, Vinterpels and Solelsker et måltid, Tivolidyr tøys, Skybåren
  zeppeliner). New activities: errand (the bank, a mailbox, the auction house), eat (the Food or Drink buff), dungeon
  (going in), duel (won or lost); boat and zeppelin (Voyage) became likes too: the pirates' parrots and Azurky like
  boats, cats dislike them (not the Siamese, a ship's cat: it minds flying instead), the Rampete and Eventyrlysten species like duels. **A third trait** opens up at your bond's
  level 7 (Config.THIRD_TRAIT_LEVEL), pinned per species as Data/Unlocks.lua's third value by tools/pin_unlocks.lua
  (its like new to the pet, within the limits, from the family's fitting traits; the Senegal's by hand), told once at
  the level-up (unlock.trait) and hinted on the panel before. Two minor likes the new trait likes made major were
  re-pinned by hand (Jubling, Sinister Squashling). Guild company as a like is wished for only with guildmates about
  (Wish.Company). No wire change: points and caps are as they were (chatter: the same pace).
- **Minor likes and dislikes** (2026-11-12, the user): your own bond with a pet unlocks one more like at
  level 4 (Config.MINOR_LIKE_LEVEL) and one more dislike at 6, per species (Data/Unlocks.lua). Lesser than the
  major ones: a minor like gives 2 points, at most 10 a day (BOND_MINOR_POINTS/CAP), its line at 30% of its first
  times a day; the minor dislike is a secret until it happens (a hint at the level-up), then speaks 15%/5%; both
  dimmed in the card's likes line, no new row. "Kjenner deg ut og inn" counts them (char migration 2 took it
  back from those who had it).
- **Dislikes and easter eggs** (2026-11-09, Menagerie/Quirks.lua): pure flavor, no effect on the bond (an activity
  watched only for a dislike gives no points). Dislikes come from families and a few traits, never override a like,
  and stay secret until one happens (then "liker ikke ..." on the card, char.dislikes). Lines come by chance, at most
  one quirk line every 45 minutes (an hour until 2026-11-11) for the common ones; rare ones (`always`: holidays, milestones,
  a roll, a duel, the clock's eggs) and a dislike's first time aren't held back (three tiers, 2026-11-12, from the log); easter eggs (holidays, adoption anniversaries, meeting its own kind, midnight...) at most
  once a day each, counted in char.eggs. Lines: Locale dislike.<activity>.N and egg.<id>.N. No player birthdays
  (we don't know them).
- **A personality is a surprise** (2026-11-09): traits, likes and trait particles show only for a pet you've
  collected or that someone in the guild has (adopted until 2026-11-15, owned since: Owners) (`Personality:Known`); otherwise "Ukjent personlighet".
- **Sync hardening** (code review 2026-11-09): SYNC goes in three parts (records, names, bonds), peers hold back
  theirs when one starts arriving; a part with more than Config.SYNC_MAX_ENTRIES is refused whole; pet keys must be
  "s:<id>" or "n:<name>"; bonds can't start before Config.BOND_EPOCH and hold at most Registry.LifeCap (Wire.DayRoom,
  85, a day plus three spare days since X-Protocol 10; 75 and one spare until then). Anything that feeds validation or the digest (LEVELS, BOND_DAILY_MAX, LifeCap, GUILD_MAX) needs an
  X-Protocol bump and, for stored data, a migration that brings old entries within it (see migration 8).
  Exception (decided 2026-11-09): the per-member caps on stored names and bonds (Config.NAMES_PER_MEMBER,
  LIFE_PER_MEMBER, migration 9) came without a bump: they only bite under a flood, so mixed versions still agree in
  a normal guild. Incoming messages that unpack past Wire.LIMITS.MAX_RAW are dropped and their sender ignored for the session.
  Likewise without a bump (code review 2026-11-10, migration 10): claims, lapses and names must be on or after
  Config.BOND_EPOCH, a claim no later than its record's write, and no wire time more than Config.CLOCK_SLACK (5 min)
  ahead; only forgeries fail these.
- **Members-only sync, X-Protocol 10** (2026-11-13, the user, Q4 in docs/REFACTOR.md; fixes B11): relayed data about
  someone who isn't a guild member doesn't matter. Claims, names (by namer) and bonds (by carer) whose author isn't on
  the last complete roster (Guild.known, one that lists us) aren't stored: they wait in memory (Registry `held`, at
  most Config.HELD_MAX) for the next roster (Guild:Soon), which lets the members among them in and drops the rest, so
  a roster read before someone joined never loses them. An author's own message on the guild channel is let in at
  once (only members can send there). Every complete roster prunes the same way (Registry:Prune, after
  CheckRoster's lapses), so clients with the same members keep the same data and digests agree; a SYNC that leaves
  two clients apart asks for a roster read (one may be older). No complete roster yet: kept, pruned at the first.
  Our own entries always stay; a claim that still holds a pet stays until a lapse frees it (CheckRoster's guards);
  lapses aren't pruned (a returning member's own client still has its old claim: only the lapse stops it), they have
  a cap instead (Wire.LIMITS.LAPSES_MAX 1000, the oldest going; a LAPSE message is held to SYNC_MAX_ENTRIES). A
  name a member who left gave a pet stays while it names the pet (the user, the same day: Registry Tidy), for
  journal species only, so one such entry per species at most; a newer name by the next carer replaces it, and the
  old one goes then. Guild achievement records carry no author: unchanged. Same bump:
  LIFE_SPARE_DAYS 3, LifeCap's room a day 85 (the wish), whole-number wire times (Wire.Time), and a claim's and a
  name's digest line carry what they hold (a copy with the same stamp but another pet or name is told apart: the
  greater line wins). Migration 13 drops stored entries peers refuse now (times off a whole second, lapses past the
  cap); members only needs none (each roster prunes).
- **Nicknames belong to the pet** (2026-11-08): only its current holder can name, rename or clear it,
  once their bond reaches Venn (level 3; it was 7 days of care until 2026-11-09). The name stays when they let go
  (and when they leave the guild, 2026-11-13), and the next carer inherits it until they change it. A name set by
  anyone else during a holder's care doesn't count (`Registry:Nickname`). Clearing needs no bond level (2026-11-10):
  a holder can drop the name the pet came with (or a forged one) at once. One new name a day per pet, with 10 minutes after the
  day's first for typo fixes (Config.NICKNAME_FIX); at most three name lines in guild chat a day (Config.NAME_LINES). It replaces the title line of the world
  tooltip, with the species moved below it, and shows big on the journal's pet card.
- Auto-summon turns itself off if AutoCompanion is loaded.
- **Fewer commands** (2026-11-09, the addon spread beyond the guild): `/dp rapport` (calling out group members
  without a pet), `/dp versjon`, `/dp prestasjoner ikoner` and the English aliases are gone. The developer commands
  (probe, debug) exist only in a git checkout, so the probes and the debug log are for the developer. The answers to
  0.2.x clients' PET_REQ and VER_REQ went at X-Protocol 12 (2026-11-17): their protocol, 9, had been under the
  floor since 0.6.0, so none of it reached us.
- Adopting and naming are announced in guild chat from the click or command that did it (`Bonds:Announce`), per
  character, default on, `/dp kunngjør`. Letting go and clearing a name aren't announced. The same line isn't
  repeated within an hour.
- **The active pet** (2026-11-09): auto-summon keeps out one pet of yours, adopted or not, picked with the "Med deg" paw badge on
  its card (char.activePet; adopting a pet makes it the active one, turns auto-summon on and swaps it in; clicking the badge again turns auto-summon off).
- Auto-summon only when idle: not in combat, mounted, on a taxi, flying, dead, stealthed, sitting, eating/drinking,
  casting/channeling, in a battleground/arena, or while a mage's familiar from a scroll is out (its buff on you, 2026-11-15: not a journal pet, and replacing it took the buff). At most 3 tries per trigger. Toggled by the "Med deg" badge on the card (Menagerie/OutBadge.lua; the list shows a gold paw on the active pet). It never replaces a pet you summoned yourself, except right after you pick a pet on its card: that swaps it in. It doesn't watch
  `COMPANION_UPDATE` (that fires for every nearby companion), so a pet you dismiss comes back only at the next
  trigger: loading screen, leaving combat, dismounting, or claiming.
- The summon clank (sound files 567569, 568424) is muted for 2.5 s after any `SummonPetByGUID` call, per character,
  default on, toggled with `/dp lyd`. Off when AutoCompanion is loaded (it has its own option).
- **Strings live in Locale/nb.lua** (2026-11-08): one Lua file per language (English later: Locale/en.lua, falling
  back to Norwegian), named placeholders ({pet}, {n}), keys grouped by area. Prepared for a full text pass.
- **Everything players read is Norwegian** (2026-11-08); developer output (`/dp probe`, `/dp debug`, the log) stays
  English. Companions are *adoptert* and *bor hos* someone, never "reservert". "Har bodd hos Kari Berg i 3 dager" (2026-11-10) /
  "siden i dag" / "siden i går" (`ns.CaredFor`), "Trenger et hjem", buttons Adopter / Gi slipp / Kallenavn, nicknames in
  «», dates as 08.11.2026. Commands: `/dp adopter, gislipp, navn, liste, lyd, prestasjoner, kunngjør, klapp` (the
  English aliases went 2026-11-09). Code and the wire keep English names (claim, Registry, `claims`).
- Counter: "Guilden: x av y har et hjem (z%)", y = every companion in Forever's journal (`Pets:Total`,
  `Data/Companions.lua`). The old "known" list is gone (migration 4).
- No officer force-release for now: release only happens by the owner, by leaving the guild, or after inactivity.
  Build it later if it turns out to be needed.
- Anyone can run a version check. Only the group leader or an assist can start games.
- The debug log goes to `DyreparkenDebugDB` (account-wide SavedVariables).
- Players are keyed as `"First Surname"` and guilds by name: **no realms**, because Forever moves players between
  realms invisibly. See docs/FOREVER_API.md.
- The pet key is `s:<speciesID>`. Forever returns real species IDs (see docs/FOREVER_API.md).

- **Pats from the guild** (2026-11-19, the user): a guildmate's /klapp (or /dp klapp) on any pet of yours that's out,
  adopted or not, gives it Config.BOND_PAT_POINTS (1; Bond.REWARDS.pat, within the day's 75, at the pet's rate), with
  its thank-you line and hearts, once every Bonds.PAT_AGAIN (5 minutes) from each guildmate (a session's memory).
  It's the activity `patted`: one day in Wish.PAT_EVERY (10) any pet wishes for it, only with guildmates about lately
  (Wish.Company). No wire change: the pat is the patter's emote, read on our side (Bonds:Patted, CHAT_MSG_EMOTE heard
  always). A guildmate can type the emote by hand: a point every 5 minutes at most, within the day.

- **Loyalty points** (lojalitetspoeng, 2026-11-19, the user): from your bond's top level (Sjelevenn) on, everything a pet
  earns with you counts on with no day's limit (the per-activity caps stay), continuing from the bond's points, at
  the pet's rate (adopted or not): Bond:Loyalty / AddLoyalty / LoyaltyTotal (a character's sum: a leaderboard later).
  The bond's own `p` goes on as before, within the day's 75 and Wire.LifeCap, so nothing changes on the wire: the
  points are kept on this client only (g.loyal[carer][pet]), not sent yet (the user: "not yet"; sending them later
  is a protocol bump with a sanity cap a day). On the card (your own bond) and the pet frame a counter ("3 484
  lojalitetspoeng") takes the bar's place, the "+N" still rising; the level's number becomes a gold star at the top,
  "level 7/7" in the tooltip (a guildmate's pet at the top: the star, its bar).

- **Who owns what, X-Protocol 11** (2026-11-15, the user: "essential for many of the features I have planned"; Menagerie/
  Owners.lua): each member's owned species go to the guild, lazily, and pets are assumed kept for good (a list only
  grows). Older clients keep syncing (the user): the protocol is per kind now (X-Protocol-Floor 10; Wire.SINCE, Stamp,
  Compatible), so a 0.7 client reads every kind it knows and drops OWN and OWN_SYNC. Parken shows a pet nobody in the
  guild has as a small question mark (no ring, no name in its tooltip, a wiggle on a click, not on the stage, not found
  by a search; "Ukjente dyr som spørsmålstegn", on by default, turns it off). The card's home line tooltip names the others who
  have it (not you or the holder): two by name, from three a count. A pet someone in the guild owns has a known
  personality (Personality:Known). A non-member's list is dropped, not held (the next OWN_SYNC brings it again).

- **Forgeries by a member** (2026-11-21, review part A, the user): a claim written more than Config.CLAIM_RACE (an
  hour) after its date, new to us, can't take a pet from its holder (Registry Backdated; judged against what we hold,
  only forgeries fail, no bump; known limit, kept: a client that hasn't the holder's record yet when the forgery
  comes keeps it until that pet's adoption changes, a SYNC round a login, 73_forgeries pins it). A lapse of ours stamped since our login is made up: we adopt the pet again at once
  if it's free (its date starts over: lapses can't be refused). Trim evicts made-up keys (not journal species or
  familiars, Registry.Real) first, and a name naming a pet last. Our own bond's copy stamped since login is refused
  on our client. A pre-login copy that changes our pet asks on the pet journal's page whether to keep it
  (char.ownChange, CardActions:AskOwnChange; keeping writes the old record again, date kept).

## Open questions (ask the user before deciding)

- Whisper targets with surnames ("First Surname") are unverified, so all replies go on the group/guild channel for now.

## Future additions

- **docs/IDEAS.md**: the creative review of 2026-11-09 (UI fixes, fun details, barriers to fun) and known limits.


- A "companions the guild is missing" list, from `Data/Companions.lua`.
