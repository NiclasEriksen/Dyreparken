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
  the test suite with coverage floors (~50 s). `tools/check.sh --quick` skips coverage (~5 s). The runner
  uses every core (`--jobs=N`; one process for a filter or `-v`): coverage alone made a run ~9x slower.
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
`tools/check.sh` on the newest commit of each pushed branch (once per push, not per commit) in a temporary worktree
and refuses the push if it fails.

- `tools/test/harness.lua` simulates a world: several clients (`w:AddClient("Ola Nord", opts)`), each running
  its own copy of the addon in its own global environment, with a shared clock (`w:Run(s)`, `w:SkipDays(n)`),
  guild roster, group, and an addon-message network. The network can lose messages (`w.drop`), take forged
  input (`w:InjectMessage`), and records every decoded message in `w.wire` (`w:Sent(kind)`). Clients log in
  and out with their SavedVariables kept (`c:Reload()`). There are helpers for the journal, tooltips, popups
  and player state. Read its header first.
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
- The changelog is written by the release workflow from commit **subjects** since the previous tag (bodies and
  Co-Authored-By lines left out; the Claude credit is one line at the top), skipping subjects that start with
  `Tests:`, `Tidy-up:`, `Notes:`, `Docs:` or `Developer probe`. So write subjects for players, and start developer-only
  ones with one of those words. `.pkgmeta` has `manual-changelog: CHANGELOG.md`.
- `.pkgmeta` lists the dev files left out of the zip: tools, docs, CLAUDE.md, README.md, .claude, .luarc.json, .github.
- Any wire format change bumps `X-Protocol`. Any saved data change adds a migration (see Working rules).

## Layout

```
Dyreparken.toc     load order (each file only uses files above it)
Libs/              LibStub, LibSerialize, LibDeflate. Don't edit. (ChatThrottleLib went 2026-11-12: unused since
                   Comm paces its own outbox, and it hooked every addon's sends.)
Core/Init.lua      ns, Config tunables, Bus (internal events), helpers (Now = GetServerTime, Plain/IsSecret, Today/Date,
                   Join, Gold/PrintGold, SpellName, GroupChannel, Debounce, SetTip/HideTip, PlayFirstSound), the start-up
                   phases (ns.Start, ns.RunPhase): use these,
                   don't write them again
                   ns.L / ns.T / ns.Fill: the strings (below)
Locale/nb.lua      EVERY text players read, Norwegian, keyed ("card.home.today" = "Flyttet inn hos {who} i dag"),
                   grouped by area; named {placeholders}; the achievement texts (ns.AchTexts) at its end. Loads right
                   after Init. Code never holds player text: add a key here and use ns.L[key] / ns.T(key, vars).
                   Developer output (/dp probe, /dp debug, the log) stays English in the code.
Core/Debug.lua     ns.Log(module, fmt, ...) → SavedVariables ring buffer; no-op when off
Core/Events.lua    single event frame, On/Off, OutOfCombat queue
Core/DB.lua        SavedVariables, defaults, schema migrations, DB:Guild() registry
Core/Comm.lua      serialize→compress→encode→chunk, our own paced outbox (not ChatThrottleLib), Register(kind, fn, from)
                   ("GUILD"/"GROUP": other channels never reach fn), MayReply (requests anyone can send: once per channel every 5 s)
Core/Version.lua   HELLO on login, one-time outdated notice; still answers VER_REQ from 0.2.x clients
Core/Guild.lua     guild roster snapshot on demand (membership, days offline)
Core/Activity.lua  the activity engine: game events -> activities, every one declared once in Activity.KINDS (always
                   watched or not, wishable, chip icons; its words in Locale by id), counted per
                   character after combat, Bus "ACTIVITY". Events registered only while a consumer wants them
                   (Want/Drop). Bond, achievements (`activity` kind) and stories build on it. Read its header.
Core/Anim.lua      shared animation pieces for the card (Pulse, OneShot, Fade, Scale): no BOUNCE loops, one group per region
Core/SidePage.lua  our pages of the Collections window: a side tab each under Blizzard's, the page covers theirs
                   (no taint: never their SetTab or tab list), title/portrait swapped and put back. Read its header.
Core/Commands.lua  /dp slash commands (adopter, gislipp, navn, liste, lyd, prestasjoner, kunngjør, klapp; Norwegian
                   only). Only in a git checkout (ns.DEV): probe [more|tabs|kills|life|world|card|bg|decor|frames|level|
                   celebrate|anim|ach|pos|lift|moves|gains|api] and debug; a release never logs (Debug:Init turns a saved log off)
Core/ApiProbe.lua  /dp probe api [section|clear]: what the client really has (globals, C_* namespaces, Enum, events,
                   widget types and their methods/handlers, templates, global strings, getters' values, the card's
                   actor, the calendar, a pet model's animations and lengths), read-only, in DyreparkenDebugDB.api; by name only:
                   holidays (the calendar a year ahead), lengths (every species' moves, DyreparkenDebugDB.animLengths)
                   and feats (Feats' spell and quest ids as the client has them, Forever's copies among your completed
                   quests, talent/spec getters; then logs the candidate talent, spec and trainer events this session)
Data/Companions.lua GENERATED (tools/companions/build.py --lua; the tools stay out of git; a new companion:
                   tools/companions/add.py, see "Adding a companion" in tools/companions/README.md): every journal species, whether
                   it counts toward achievements (a), and its tags/families (t). Don't edit by hand.
Data/PetMoves.lua  which animation each pet uses for each reaction on the card (sleep, sit, happy, cheer, dead): a
                   default and per-species overrides, EDITED BY HAND by the user (found by eye, /dp probe anim)
Data/AnimLengths.lua GENERATED (luajit tools/anim_lengths.lua, from a /dp probe api lengths run): how long each
                   species' one-off moves play, so the card moves on when one ends (Moves:Length); else Moves.T. Don't edit
Data/Unlocks.lua   every species' minor like and minor dislike (your bond unlocks them at levels 4 and 6), PINNED
                   for good like the traits (2026-11-12): luajit tools/pin_unlocks.lua adds new species (from
                   fitting lists per family and species, never a major like or dislike) and never changes a line
Data/Traits.lua    every species' two personality traits, PINNED for good (decided 2026-11-08): never reshuffle.
                   After regenerating Data/Companions.lua, run `luajit tools/pin_traits.lua`: it adds new species
                   (least-used traits) and never changes an existing line. Change a species by hand only.
Menagerie/         Pets (journal access, pet keys, OutKey: the pet out now, probes), Registry (reservation data model,
                   merge + holder rules: read its header first; Status: mine/taken/free; NameOf/NameFor: what a pet is called), Sync (HELLO digest, SYNC/UPD/NICK/BOND/LAPSE, guild channel only;
                   the digest and SYNC also carry guild achievements),
                   Summon (auto-summon, defers to AutoCompanion), OutBadge (the "Med deg" badge: which pet is kept out), Report (only answers 0.2.x clients' PET_REQ; /dp rapport is gone),
                   JournalList (the journal's list: markers, bond rings, nicknames, tooltips), CardActions (the card's
                   Adopter / Gi slipp and Kallenavn buttons and popups), JournalUI (the card and the wiring; the card's
                   widgets are one ordered list, WIDGETS: Build + a line there),
                   Tooltip (reservation lines on companion units; owner parsed from tooltip text)
                   Holidays (the game's holidays from the calendar, today's, by event id: Lunar Festival, Love is in the Air,
                   Noblegarden, Midsummer, Harvest Festival, Hallow's End, Winter Veil; not the Darkmoon Faire, too often),
                   Personality (likes, and two traits per species from Data/Traits.lua;
                   liked activities, and anything done at a trait's moment, give more bond points), Scenes (backgrounds behind the pet on the card, by family, and the light of the hour; the
                   card's tier colors: Tier, Bright), SceneGallery (/dp probe bg and decor: thumbnails of every
                   background that exists; pick one per family, saved in DyreparkenDB.scenePicks), BondTrack (the bond on the card: a medallion with the level, a track of seven stars,
                   a tinted bar with a spark; a celebration once per new level of your own pet, char.bondSeen), Stats (what you've done with a pet: chips at the top of its card, from the activity counters),
                   Playdate (in a group with a guildmate whose pet is out: both pets play, once a day each;
                   PLAY on PARTY/RAID), Quirks (flavor with no effect: dislikes and easter eggs, at most one line
                   every 45 minutes; read its header), Fx (one-shot particle bursts outside the journal: hearts at the cursor over a
                   companion in the world, since companions have no nameplate to draw on; at the chat window for bond
                   lines and level-ups), Feats (a character's big moments, 0.5: a class quest's reward, riding, level 60
                   give the pet that's out 25 points once per character, by the spell taught (SPELLS_CHANGED) or the
                   quest's id; what was had at the first look isn't new; a trainer visit, a dual-spec switch, a talent
                   reset and the tenth levels are eggs only; read its header), Wish (today's wish: one of your pet's likes a day, +10 when done, a line on the card; wishes in a row, char.wishes, with achievements at 7 and 30 in a row and 100 in all), Moves (the pet on the card moves: asleep at night, a Latsabb sits, a click is a happy move, a level-up a
                   cheer, a jump with you (every pet: canJump), playing dead the day of the three-deaths egg; which animation per species: Data/PetMoves.lua; and the /dp probe anim research probe), Cake (a cake with flickering candles on an adopted pet's card on its milestone day; a click on a guildmate's
                   congratulates them), Crown (the pet of the day's gold crown on its card, beside the cake), Story (a pet's story: a local
                   timeline of its life in the guild, g.story, found by comparing the registry with what it last saw,
                   plus your moments with it; a book button on the card opens a panel right of the window, newest first), Cuddle (a click on the pet:
                   a ripple, hearts, a glow; once a day a cuddle), Decor (pet card decorations: one more per bond level of the holder
                   (border and color wash: family, silver, gold; corners; glow; sparks; ribbon and turning rays; hearts),
                   particles from traits (every trait has some; those with a moment show only then) and the date, and
                   each family's ambience, always (Decor.FAMILY: feathers, embers, gears, fireflies...); each kind with its
                   own motion (sway, spin, tilt, throb, flap) and path (rise, fall, burst, twinkle, steps, drift, wind);
                   the everyday ones thinned by bond level (Decor.Density: 70% at 1, all at 7);
                   a border per family (Decor.FAMILY_ART, picked with /dp probe frames), corners the same for all (wood, filigree
                   from 5); gallery picks show on the card only while a gallery is open, so write them into the code; animation
                   groups only, timelines in steps (never Alpha delays inside a step), one playing group per region
                   (holder frame: path; inner frame: sway; texture: spin/tilt/throb), no BOUNCE loops (REPEAT steps that
                   come home instead), stopped when hidden. Also
                   the art probe /dp probe decor; DecorCandidates.lua is GENERATED from the retail atlas list, dev only),
                   ParkPage ("Parken", the park map SidePage: records, every journal companion as an icon, a click opens its card on the Pets page (also pets you don't own);
                   loads after Achievements/Page.lua so its tab comes second),
                   PetFrame (the pet that's out on screen, optional and off by default: its own ModelScene with the card's view
                   insets, a stage of Moves so it moves 1:1 as on the card, name and a slim bond bar with the rising numbers;
                   a click opens its card; placed and sized (mouse wheel) in Blizzard's Edit Mode, char.petFrame),
                   Settings (the settings page: a SidePage with no tab, opened by a cog in the pet journal's title
                   bar; the four older per-character settings plus the account's DyreparkenDB.settings: chatLines (hides the lines only),
                   worldHearts, cardParticles all/few/none, cardMoves, celebrate, and the pet frame's (petFrame, petFrameArt,
                   petFrameCombat, petFrameFade, petFrameAlpha); modules ask Settings:On(key)),
                   Bond (the bond score between a carer and their pet: levels, daily points, seeding; data in
                   g.life, see Registry.lua; docs/PET_LIFE.md. Data only, it prints nothing: BOND_LEVEL, BOND_FULL,
                   BOND_LINE on the Bus. Rewards beyond activities (wish, first, playdate) are rows in Bond.REWARDS,
                   given with Bond:Reward),
                   Bonds (what players read about bonds: levels, full days, reward lines; milestone lines after login, the nickname unlock note, dagens dyr, /dp klapp,
                   guild announcements)
Achievements/      Defs (ids, kinds;
                   ids are permanent), Achievements (evaluation, quiet first runs, ACH_EARNED notices,
                   /dp ach share; guild ones synced with the registry, ACH), Kills (research probes: honorable kills while debug
                   is on; /dp probe kills, life and world: companions' nameplates), Page (the achievements SidePage;
                   Del per shareable one).
                   Plan and decisions:
                   docs/ACHIEVEMENTS.md (read it first). Planned next: bond, temperament and the activity engine,
                   docs/PET_LIFE.md.
Media/Particles/   our own particle textures (heart, sparkle, star, dot, bubble, confetti, note, paw, leaf, moon, snowflake, ring, rays,
                   and since 2026-11-09 feather, ember, gear, wisp, coin, grain, seed, clover, zee, speech, crumb, cloud,
                   pebble, chevron, bolt, halo, sword, drop, butterfly, mist; house, the list's mark for a pet that needs a home; cake, Cake.lua;
                   since 2026-11-12 the pet frame's bubbles speechblank, thought, shout and rain, the families' yarn
                   (cats), petal (plants), shell (murlocs), and the traits' banana, mask, sun, badge):
                   white with soft alpha, 64x64 32-bit TGA, to tint and animate. Drawn by tools/draw_particles.py;
                   edit the script and rerun it rather than editing the files.
Games/Framework.lua game definitions, lifecycle, UI stash/restore, history
Main.lua           bootstrap: runs the start-up phases (loaded, login, settled, hello). Each module declares its own
                   start at the end of its file, ns.Start(phase, fn) (Core/Init.lua); within a phase, TOC order
tools/check.sh     all offline checks (see Verify)
tools/test/        harness.lua (simulated clients + network), run.lua (runner, coverage), spec/*.lua
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
  once per pet a session (BOND_REQ); they may be a little behind, by design. Wish and nicknames stay adoption-only.
- **More ways to bond** (2026-11-09): firsts together (a boss this pet hasn't seen fall, a place it hasn't been: 10
  points), playdates (15, once a day per pet, with a guildmate's pet out in the group; Menagerie/Playdate.lua), and
  skill-ups (verified 2026-11-09) and reputation (verified 2026-11-11) as activities. All at the pet's rate, within
  its day.
- **Balance pass** (2026-11-10, the user: "many max out after 15 mins of normal activity"; one dungeon of firsts
  filled the day): firsts 5 points (was 10), at most 15 a day; everyday (not liked) activities 1 each, at most 3
  per kind (was 5) and 10 in all; a trait's moment at most 10 a day (was 25). Unchanged: the day 10, likes 5 each
  (25 a day), wish 10, playdate 15, and the 75 a day (BOND_DAILY_MAX feeds validation). Likes are what fill a day.
- **Data pass** (2026-11-10, with the user): every journal pet tagged and its source checked (tools/companions:
  tags.csv, curation.csv; 77 of 88 count toward achievements since 2026-11-12; four species hidden from the journal added by hand: Spectral Bear Cub (Legacy Track, counts), White Tiger Cub (the Black Market, counts; 2026-11-12), Bronze Whelpling and Mini Uber Diablo (source unknown)). Two new families, `bear` (Panda Cub) and
  `reptile` (Baby Crocolisk, Speedy). The Zergling is a demon. Limited pets count (2026-11-12, the user: "as
  long as it was never impossible to get"; until then they didn't): the store pack pets (Panda Cub, Mini Diablo,
  Zergling, Pachimari: Skyborne Epic Pack or Warcraft Forever Collection) and Azurky; the Musical Gustjumper is
  open world (/sing to a frog on Zephras Isle). Pets nobody knows how to get yet don't (Galestrider Chick,
  Shen'dorei Wisp, Minfernal, Spawn of Grubthor, the four Lashlings), nor removed ones, nor the Wild Chicken, whose card shows no model on Forever. Event pets also get a body family.
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
  supposed to be huge bonuses"). They stay within the wire's cap (Registry.LifeCap keeps a spare day): no protocol
  change. A trainer visit, a dual-spec switch, a talent reset and the tenth levels 10-50 are eggs only, no points.
- **New traits and a one-time rework** (2026-11-12, the user, for 0.5): 13 traits (Sjørøver, Skøyer, Røverdyr
  against Ordensdyr, Venneflokk, Vinterpels against Solelsker, Tivolidyr, Bålkos, Skybåren, Jeger, Håndverker,
  Diplomat; 38 in all) and four activities for them (gold, fun, sneak, meet). Every species nobody in the guild
  had adopted was re-pinned by hand in Data/Traits.lua that day; the eight adopted then (Black Tabby, Senegal,
  Cockroach, Brown Prairie Dog, Excitable Slime, Panda Cub, Zergling, Mini Diablo) kept theirs, and so did the
  family and species like lists (their majors come from those too). From now on the pins hold again. The zone
  traits read GetZoneText (Personality.COLD/WARM/HIGH/CITIES); Forever's names there are unverified.
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
  collected or that someone in the guild has adopted (`Personality:Known`); otherwise "Ukjent personlighet".
- **Sync hardening** (code review 2026-11-09): SYNC goes in three parts (records, names, bonds), peers hold back
  theirs when one starts arriving; a part with more than Config.SYNC_MAX_ENTRIES is refused whole; pet keys must be
  "s:<id>" or "n:<name>"; bonds can't start before Config.BOND_EPOCH and hold at most Registry.LifeCap (75 a day plus
  a spare day). Anything that feeds validation or the digest (LEVELS, BOND_DAILY_MAX, LifeCap, GUILD_MAX) needs an
  X-Protocol bump and, for stored data, a migration that brings old entries within it (see migration 8).
  Exception (decided 2026-11-09): the per-member caps on stored names and bonds (Config.NAMES_PER_MEMBER,
  LIFE_PER_MEMBER, migration 9) came without a bump: they only bite under a flood, so mixed versions still agree in
  a normal guild. Incoming messages that unpack past Comm.MAX_RAW are dropped and their sender ignored for the session.
  Likewise without a bump (code review 2026-11-10, migration 10): claims, lapses and names must be on or after
  Config.BOND_EPOCH, a claim no later than its record's write, and no wire time more than Config.CLOCK_SLACK (5 min)
  ahead; only forgeries fail these.
- **Nicknames belong to the pet** (2026-11-08): only its current holder can name, rename or clear it,
  once their bond reaches Venn (level 3; it was 7 days of care until 2026-11-09). The name stays when they let go,
  and the next carer inherits it until they change it. A name set by
  anyone else during a holder's care doesn't count (`Registry:Nickname`). Clearing needs no bond level (2026-11-10):
  a holder can drop the name the pet came with (or a forged one) at once. One new name a day per pet, with 10 minutes after the
  day's first for typo fixes (Config.NICKNAME_FIX); at most three name lines in guild chat a day (Config.NAME_LINES). It replaces the title line of the world
  tooltip, with the species moved below it, and shows big on the journal's pet card.
- Auto-summon turns itself off if AutoCompanion is loaded.
- **Fewer commands** (2026-11-09, the addon spread beyond the guild): `/dp rapport` (calling out group members
  without a pet), `/dp versjon`, `/dp prestasjoner ikoner` and the English aliases are gone. The developer commands
  (probe, debug) exist only in a git checkout, so the probes and the debug log are for the developer. We still answer
  0.2.x clients' PET_REQ and VER_REQ.
- Adopting and naming are announced in guild chat from the click or command that did it (`Bonds:Announce`), per
  character, default on, `/dp kunngjør`. Letting go and clearing a name aren't announced. The same line isn't
  repeated within an hour.
- **The active pet** (2026-11-09): auto-summon keeps out one pet of yours, adopted or not, picked with the "Med deg" paw badge on
  its card (char.activePet; adopting a pet makes it the active one, turns auto-summon on and swaps it in; clicking the badge again turns auto-summon off).
- Auto-summon only when idle: not in combat, mounted, on a taxi, flying, dead, stealthed, sitting, eating/drinking,
  casting/channeling, or in a battleground/arena. At most 3 tries per trigger. Toggled by the "Med deg" badge on the card (Menagerie/OutBadge.lua; the list shows a gold paw on the active pet). It never replaces a pet you summoned yourself, except right after you pick a pet on its card: that swaps it in. It doesn't watch
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

## Open questions (ask the user before deciding)

- Whisper targets with surnames ("First Surname") are unverified, so all replies go on the group/guild channel for now.

## Future additions

- **docs/IDEAS.md**: the creative review of 2026-11-09 (UI fixes, fun details, barriers to fun) and known limits.


- A "companions the guild is missing" list, from `Data/Companions.lua`.
