# Achievements: design (draft for review, 2026-11-06)

This is the technical plan for the achievements in DesignDocument.md, built on the decisions made so far:
- No points.
- Collection is account-wide.
- Personal achievements stay local, with an "announced" flag.
- Guild-wide achievements are synced and announced only by an officer or the GM.
- Only obtainable pets count (curation `availability` yes or event).
- A tab in the Collections window opens an achievements page.

Open questions are marked **Q** and collected at the end.

## 1. Data: generated vs. hand-written

**Generated** by `tools/companions/build.py` into `Data/Companions.lua` (it replaces today's stub):

```lua
ns.Companions = {
    build = 70790,
    species = {                       -- every journal species
        [40] = { a = true, t = { "cat" } },          -- a = counts toward achievements (yes/event)
        [5176] = { a = true, t = { "farm" } },
        [5159] = { a = false },                       -- promo: in the total, not in achievements
        ...
    },
}
```

- The guild counter's total is the number of entries in `species`. Achievement totals count `a = true` entries only.
- Tags are the families. Nothing about a family is hand-coded in Lua: tagging a pet in `tags.csv` and
  regenerating adds it.
- The generator refuses to write while curation rows are unchecked, unless `--allow-unchecked` is given. With
  that flag, unchecked rows are written as `a = true` and the file says so in its header comment. Until curation
  is done, we develop against that.

**Hand-written** in `Achievements/Defs.lua`: the definitions.

```lua
{ id = "family:cat", kind = "family", tag = "cat", icon = ... },   -- texts: Achievements/Texts.lua
{ id = "count:25", kind = "count", n = 25, name = "...", desc = "25 companions" },
{ id = "loyal:30", kind = "loyal", days = 30, scope = "char", name = "Bestevenner I" },
{ id = "nick", kind = "nick", scope = "char", name = "Døpt" },
{ id = "guild:count:25", kind = "guildcount", n = 25, scope = "guild", name = "Dyreparken åpner I" },
{ id = "guild:all", kind = "guildall", scope = "guild", name = "Hele parken" },
{ id = "guild:family:cat", kind = "guildfamily", tag = "cat", distinct = true, scope = "guild", name = "Kattehuset" },
```

- **The ids are permanent.** Saved progress and sync key on them, so renaming an achievement is safe but
  changing its id is not.
- A family achievement whose tag has no pets yet doesn't exist: it's skipped, never shown, never earned.
- A count tier above the number of obtainable pets is hidden, so 100 and 250 stay hidden until Forever has
  enough companions.

## 2. Scopes and storage

| scope | examples | stored in | earned by |
|---|---|---|---|
| `account` | families, counts, sources | `DyreparkenDB.ach[id] = { at, ann }` | any character on the account |
| `char` | loyalty (same pet N days), first nickname | `DyreparkenCharDB.ach[id] = { at, ann }` | this character (adoption is per character) |
| `guild` | guild count, every pet cared for, Kattehuset | `DB:Guild().ach[id] = { at, ann }`, synced | the guild, from the registry everyone already has |

- `at` is when it was earned (server time). `ann` is when it was announced (nil = not yet).
- Once earned, an achievement is never lost: a pet let go, or a new cat added in a patch, doesn't take it back.
  The page shows the current progress next to the earned date.
- Migration 5 adds the tables. Wire: `X-Protocol` 3.

## 3. Detection (dormant)

Nothing polls. An evaluation runs:

| trigger | checks |
|---|---|
| login (after the existing 10 s settle) | everything |
| a pet learned (`NEW_PET_ADDED`, (unverified) on Forever; else the journal's list update, debounced) | account |
| the journal opens | account (cheap, and catches anything missed) |
| own record changes (`MY_RECORD`), and a daily check on login for "N days" | char |
| the registry changes (`REGISTRY`), debounced 5 s | guild |

The owned set is read once per evaluation with `GetOwnedPetIDs` (no journal filters, see FOREVER_API.md).
Evaluating is a few hundred table lookups, so it's cheap.

**Never announce on a first run or a new definition.** Each scope remembers which definition ids it has
already evaluated (`seen`).
- A definition met the first time it's evaluated (fresh install, reinstall, or a new achievement added by an
  addon update) is recorded with `ann = "quiet"`.
- After the first run, one line at most: "Dyreparken: you already have 14 achievements (see the companion
  window)". It's printed locally, not posted.

## 4. Announcing

Posting to guild chat needs a keypress or click on Forever (probed 2026-11-06, docs/FOREVER_API.md). From a
timer it's blocked; from a slash command it works. So (decision 7):

- **To addon users, automatically:**
  - **Personal:** the earner's client sends `ACH_EARNED { id, progress }` on the guild addon channel. Every
    online addon user, the earner included, prints one local line: `Dyreparken: Ola Nord fikk [Alle kattene]!`.
    Several arriving together (within 3 s) become one line.
  - **Guild-wide:**
    - everyone derives these from the same registry, so each client notices them itself;
    - the first client to record `at` broadcasts it (section 5), and everyone prints one local line when `at`
      first appears;
    - no officer rule is needed for that, since nothing is posted.
  - Not in a guild: the message is skipped, and the achievement stays on the page.
- **To guild chat, on request:**
  - the **Del** button on the page, or `/dp ach share`, posts the achievement's flavor line;
  - personal: anyone can share their own;
  - guild-wide: only an officer or the GM gets the button (`C_GuildInfo.IsGuildOfficer()`, `IsGuildLeader()`),
    and sharing one sends `ACH_SHARED { id }` so other officers' buttons go away (`ann` syncs);
  - a click is one post; there's no queue to flood.
- **Per-character option** `/dp ach notify off` (later a checkbox): don't send `ACH_EARNED` for my achievements.
  They're still recorded and shareable from the page.

## 5. Sync (guild scope only)

- `g.ach[id] = { at, ann }`. Merge: `at = min`, `ann = min` (non-nil). Monotonic, so the existing
  HELLO-digest / SYNC flow carries it unchanged:
  - the digest gets an `a` part;
  - SYNC gets an `a` field;
  - a new `ACH { a }` message carries changes as they happen.
- Trust as for the registry: shapes are validated, intent isn't. A forged `ann` could only silence an
  announcement, never post one.

## 6. Page

- A page of the Collections window, opened with our own side tab (see build step 5; first planned as a panel
  docked beside the journal).
- It's a scrollable list grouped by category (Collection, Families, Loyalty, Guild):
  - each row: icon, name, progress `9/12`, and the date when earned;
  - unearned rows are dimmed, and hidden achievements stay "???" until earned;
  - hovering a row lists the missing pets (names from `GetPetInfoBySpeciesID`), or for guild ones who has what.
- It's built the first time it opens and refreshes only while shown.

## 7. Tests

`11_achievements.lua`, multi-client like `04_sync.lua`:
- first run is quiet;
- an addon update adding a definition is quiet;
- a new pet sends exactly one `ACH_EARNED`, and every addon user prints one line;
- a batch becomes one line;
- `/reload` and alts never notify twice;
- notifications turned off;
- nothing ever posts to guild chat without a share click (the harness can block timer posts, like Forever);
- share: posts the flavor line once and marks it shared;
- guild-wide:
  - every client records it once and prints one line;
  - only officers and the GM can share, and one share hides the others' buttons;
  - partitions merge;
- data:
  - unobtainable pets are excluded;
  - an empty family is skipped;
  - count tiers are hidden.

Coverage floor as for Menagerie (95%).

## 8. Build order

1. ~~Probes~~ (done 2026-11-06): guild chat needs a click, `NEW_PET_ADDED` exists, and `IsGuildOfficer()`
   works.
2. Generator: `Data/Companions.lua` from the database (`--allow-unchecked` until curation is done).
3. ~~Core~~ (done 2026-11-06): definitions, evaluation, storage, first-run quiet, `ACH_EARNED` notices,
   `/dp ach share`. Tests in `12_achievements.lua`. The quiet rule uses `NEW_PET_ADDED`: the collection may
   grow by as many pets as were seen being learned since the last check; a bigger jump is quiet.
4. ~~Guild scope~~ (done 2026-11-06): `guild:count:10/25/50`, `guild:all`, `guild:family:cat`.
   - Every client works them out from the registry.
   - They're synced in the registry digest and SYNC, plus `ACH` for news. Merge: earliest `at` and `ann`.
   - A client that finds one prints a line, then waits 2-8 s before broadcasting, and cancels if someone
     else's `ACH` arrives first.
   - A first look that finds one already met sets `q` (nobody prints a line). It doesn't touch `ann`, so
     officers can still share it.
   - Ids from newer versions are kept and relayed, not shown, so digests agree across versions.
   - Tests in `13_guild_achievements.lua`.
5. ~~Page~~ (done 2026-11-07): `Achievements/Page.lua`. Replaced the first idea, a panel docked beside the
   journal, at the user's request: achievements are a page of the Collections window.
   - Our own side tab under Blizzard's (Forever has them down the right edge), drawn with the same atlases. It
     shows on every page of the window. Without side tabs: a "Prestasjoner" button left of Auto-summon.
   - Clicking it covers the content area below the title bar. Blizzard's pages are never hidden: the Toys page
     holds secure buttons, and addon code can't hide those in combat. While it's up, Blizzard's selected
     highlight is hidden and the title reads "Prestasjoner".
   - Any of Blizzard's tabs goes back (OnMouseDown hooked), as does any page showing or the window closing.
     Their highlight and title come back unless Blizzard already set them anew.
   - Groups: Samlingen, Familier, Lojalitet, Guilden (not shown outside a guild). Rows: icon, name and
     description; a progress bar, or the date earned. Unearned rows are dimmed. "x av y fått" top right.
   - **Del** on each row you can share (`Ach:Shareable`) posts that one line (`Ach:Share(id)`).
   - Tooltips list up to 12 missing pets (family, all), or every pet in the family and who cares for it
     (guild family), or the pets nobody cares for yet (guild all).
   - No achievement is hidden yet, so there's no "???" row.
   - (unverified) on Forever: the tab icon (`Achievement_General`) and the achievement icons.
   - Tests in `14_achievements_page.lua`.

## Decisions (2026-11-06)

1. **Names are Norwegian.**
   - Every player-visible text of an achievement lives in one place, `Achievements/Texts.lua`, keyed by id:
     name, description and flavor. Renaming is a one-line change there. Ids never change.
2. **Count tiers:** 10, 25, 50, plus "all of them" (every obtainable pet).
3. **Personal collection achievements count the pets you own.**
   - The goal is one pet you stay loyal to, perhaps swapped a few times as you discover new ones. No
     achievement rewards adopting often (no "adopted N pets", no "adopted from every family").
   - "Dyrepasser" in DesignDocument.md (a pet from every family) is dropped for that reason.
4. **"Hele parken" means every obtainable pet cared for by a guild member at the same time.** One pet per
   member, so the guild needs as many active adopters as there are obtainable pets (about 70).
5. **Each achievement has its own flavor line** for the announcement, with placeholders, e.g.
   `{player} har gitt alle kattene et hjem! [Alle kattene] ({progress})`.
   - When several are earned at once, they're posted as one plain line instead
     (`Dyreparken: {player} har fått [A], [B] og [C]!`), so a batch never floods the chat.
6. **`Data/Companions.lua` is committed** (it ships). The scrape tools and their inputs stay uncommitted.
7. **Announcing: the addon channel, plus an optional guild chat post** (because posting needs a click):
   - **Automatic, to addon users:**
     - when an achievement is earned, the earner's client sends `ACH_EARNED` on the addon channel (not blocked);
     - every guild member with the addon sees one local chat line, e.g. `Dyreparken: Ola Nord fikk [Alle
       kattene]!`;
     - the earner sees it too, with a hint that it can be shared.
   - **Optional, to everyone:**
     - the page marks unshared achievements and gives each one a **Del** button that posts its flavor line to
       guild chat (a click, so allowed);
     - `/dp ach share` posts all unshared ones;
     - for guild-wide achievements, the button is only there for officers and the GM.
   - **State per achievement:** `told` (addon channel sent) and `ann` (posted to guild chat). Both start set
     ("quiet") for achievements recorded on a first run or added by an update, so old ones are never offered
     for sharing as if they were new.
   - **Never hook unrelated keypresses** to slip a post through: it works around a restriction Blizzard added on
     purpose, and could break with any patch.
   - This replaces the batching rule in 5: there's no automatic chat post to flood. A batch arriving on the
     addon channel still becomes one local line.
