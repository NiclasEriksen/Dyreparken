# Pet life: bond, temperament and growth (plan, 2026-11-08)

Status: **planned**; the open questions were settled 2026-11-08 (Decisions, at the end). Nothing here is built yet.

## The idea in one paragraph

Every companion in the park gets a life of its own. It arrives **wild**, and every carer it lives with tames it a
little more, until it's a settled, beloved park animal. That's the pet's **temperament**, guild-wide, and it never
resets. Between a member and the pet they care for there's a **bond**: a score that grows every day the pet is out
with you, and faster when you do things it likes. Cats like hunting critters and fishing, birds like flying,
bugs like herbs, frogs like water. The bond has levels and a progress bar on the pet card, and it replaces today's
time-only loyalty. Each pet keeps a short **story**: when it came to the park, its first home, its carers, its big
moments.

## 1. Two scores

| | Bond (*bånd*) | Temperament (*tamhet*) |
|---|---|---|
| Between | one member and the pet they care for | the pet and the whole guild |
| Grows from | days together, liked activities | the sum of every bond the pet has had |
| Resets | when you let go (it's your bond) | never |
| Shown as | level + progress bar on the pet card | a stage word: "vill", "tam", ... |

### Bond levels (names are suggestions)

A curve to 2250 for the top, with at most 75 points a day (changed 2026-11-09; before: 6000, 1150, 1750, and 100
a day), so the very fastest bond takes 30 days. Each step is longer than the last:

| Level | Name | Points (total) | Step | Days at 10 a day | At ~45 a day | At 75 a day |
|---|---|---|---|---|---|---|
| 1 | Bekjent | 0 | | | | |
| 2 | Kamerat | 100 | 100 | 10 | 3 | 2 |
| 3 | Venn | 270 | 170 | 27 | 6 | 4 |
| 4 | God venn | 530 | 260 | 53 | 12 | 8 |
| 5 | Bestevenn | 900 | 370 | 90 | 20 | 12 |
| 6 | Uatskillelig | 1440 | 540 | 144 | 32 | 20 |
| 7 | Sjelevenn | 2250 | 810 | 225 | 50 | 30 |

Venn also unlocks naming the pet (Config.NICKNAME_LEVEL; it was 7 days of care). The protocol went to 7.
10 a day is the pet out and nothing else; ~35 is a liked activity most days. The loyalty achievements are levels
(Bestevenner at Venn, Uatskillelige at God venn, Venner for livet at Uatskillelig), so they follow the curve.
`Bond.LEVELS` in Menagerie/Bond.lua. The sync digest holds levels, so the change bumped the protocol to 6.

### Temperament stages

The pet's lifetime points across all its carers: **Vill** (never adopted) → **Sky** → **Nysgjerrig** → **Tam** →
**Kosete** → **Parklegende**. A pet that has had many loving homes becomes a legend. A new arrival is wild, a little
unruly, and that's part of the fun.

## 2. Earning bond points

Rules that keep it fair and cheap:

- **Only while the pet is out.** Points count when your adopted companion is summoned, checked at the moment of the
  event (`C_PetJournal.GetSummonedPetGUID`, out of combat; see the kills probe).
- **Daily caps per activity**, so nobody grinds herbs for a bond. The daily presence points come once a day.
- **Never negative.** A bond pauses while you're away; it doesn't decay.
- **Dormant.** Activity events are registered only while you have an adopted pet. Handlers are a table lookup,
  with no `OnUpdate`, no polling and no combat log.

### Activities (each needs a probe on Forever; Midnight restrictions apply)

| Activity | How we'd notice it (cheap) | Liked by (tags) |
|---|---|---|
| A day together | first login of the day with the pet out (no event) | everyone |
| Quests | `QUEST_TURNED_IN` (confirmed 2026-11-08) | farm, rabbit, everyone a little |
| Flight paths | `hooksecurefunc("TakeTaxiNode")`, or the taxi end at `PLAYER_CONTROL_GAINED` | bird, owl, dragon |
| Herbs | `UNIT_SPELLCAST_SUCCEEDED` (player only) with the Herb Gathering spell, out of combat | bug, rabbit, farm |
| Mining | the same, Mining | mechanical |
| Fishing | the same, or `LOOT_OPENED` + `IsFishingLoot()` | cat, pirate, frog |
| Diving | `MIRROR_TIMER_START` "BREATH" (fires when you go under) | frog, snake, pirate |
| ~~Critter hunting~~ | ~~`PARTY_KILL`~~: its GUIDs are secret on Forever (2026-11-08). Not possible. | |
| Boss kills | `ENCOUNTER_END` with success (confirmed 2026-11-08; `BOSS_KILL` doesn't fire) | dragon, everyone |
| PvP | `PLAYER_PVP_KILLS_CHANGED` (honorable kills) | pirate, dragon |
| New zones | `ZONE_CHANGED_NEW_AREA`: a zone this pet hasn't visited | bird, owl |
| Night owl | any activity between 22 and 04 server time | owl |
| Petted | a guildmate's `/dp klapp` on your pet (a small addon message) | everyone |
| Skill-ups | `CHAT_MSG_SKILL` matched with `SKILL_RANK_UP` (verified 2026-11-09) | mechanical, farm |
| Reputation | `CHAT_MSG_COMBAT_FACTION_CHANGE` matched with `FACTION_STANDING_INCREASED` (unverified) | festive, spirit, dragon |

Liked activities give full points; anything else gives a little.

### The activity engine (shared by bond, achievements and the kills probe)

One module, `Core/Activity.lua`, turns game events into **activities**, and everything else listens to it. Bond
points, achievement counters ("50 boss kills with your pet out"), pet stories and probes all reuse the same
listener. Nobody registers game events of their own.

- **Sources.** Each activity is declared once: its game events, a small filter, and the activity it yields.
  For example, `{ id = "herb", events = { "UNIT_SPELLCAST_SUCCEEDED" }, unit = "player", spells = HERB_IDS }`.
  The engine does the shared work in one place: the combat check, secret-value guards, and the "pet out?" check.
  It then fires one Bus event, `ACTIVITY(id, petKey, extra)`.
- **On demand.** A game event is registered only while some consumer wants an activity that uses it. That means
  `Activity:Want(id, owner)` / `Activity:Drop(id, owner)`, built on `ns.Events:On/Off`. With no adopted pet, the
  bond consumer wants nothing, and the engine sits idle.
- **Degrades, never breaks.** An event the client lacks is skipped at registration (`Events:On` already pcalls it),
  and that activity is marked unavailable. The page then hides what can't be earned. A source that throws is logged
  once and switched off for the session, so one bad event can't spam errors.
- **Cheap per event.** A source handler is a table lookup and a couple of API calls. No combat log, no
  `OnUpdate`. Per-unit events are registered for the player only (`RegisterUnitEvent`).
- **Counters, batched.** Per-character counters (`char.activity[id] = { total, day, today }`) hold the daily caps
  and the lifetime totals. They live in memory and SavedVariables write them at logout; nothing is sent per
  event. The bond's points are published by its own rule (section 5).
- **Achievements reuse it.** A new `Eval` kind `activity` reads the counters (`{ kind = "activity", act = "boss",
  n = 50, pet = true }`). Achievements re-check on `ACTIVITY` through the existing debounced `Ach:Check`. The
  kills probe becomes the engine's debug mode: `/dp debug on` logs every activity with its payload.
- **Tested like the rest:** the harness fires the game events, and specs check the activities, the caps, the
  on-demand registration (no listeners without consumers), a missing event, and a throwing source.

### Personality

- **Likes** come from the pet's family tags (`Data/Companions.lua`): two or three per pet, from a table per tag.
- **A quirk** per species, chosen from the species id so every client agrees. For example "redd for vann",
  "elsker å fly", "nattmenneske" or "glupsk". It shapes the flavor text, and one quirk can bend a like (a cat
  that's "redd for vann" doesn't like diving).
- **Flavor lines**, used sparingly. On a level-up: "Pepe er blitt din bestevenn!" When something liked happens for
  the first time: "Mjau elsket fisketuren!" At most one such line per day, so it stays charming.

## 3. The story (timeline)

What we can record for each pet, from data the addon already has or will sync:

- **Kom til parken** (arrived): when the first member had it. This needs **collection sync**: each member shares a
  tiny list of the species they own. That's a wire change, but it also unlocks "nobody in the guild has it" on the
  park map, which we had to drop. Decided: the last stage (6).
- **Første hjem**: the first adoption ever, and by whom.
- **Carers**: each carer with how long they kept it.
- **Milestones**: temperament stages reached, bond levels, its first boss kill, its first new zone.

Shown as a short timeline in the park map tooltip and on the pet card's tooltip.

## 4. Where it shows

- **Pet card (journal):** under the big nickname, "Tam · Bestevenn (nivå 5)" and a **progress bar** to the next bond
  level. Hovering shows the likes and the quirk, and this bond's numbers: "12 boss-drap, 340 urter, 31 dager".
- **Card decorations** (built 2026-11-08, Menagerie/Decor.lua): the holder's bond level dresses the card, one
  thing per level: 2 a border and a wash of the family color, 3 silver border and corners, 4 a strong glow under
  the pet, 5 everything gold and sparks flying, 6 a ribbon with the level's name and slowly turning light rays, 7
  hearts, brighter and faster rays and a glowing gold edge. (Reworked the same evening: the first version's levels
  looked too alike, and the crown was clumsy.) Traits add particles (Dykker bubbles,
  Nattugle stars at night, Festglad confetti on holidays...), and every pet gets snow in December. The bond's
  tooltip says what the next level adds. The card's light follows the clock.
- **The card's story** (built 2026-11-08): chips at the top with what you've done together (days out, boss-kills,
  herbs...: Stats.lua); today's wish under them (one of the pet's likes a day, +10 when done: Wish.lua); a click on
  the pet answers quietly (a ripple, a few hearts, a glow; no text), and once a day it's a cuddle (Cuddle.lua). In the list: an adopted pet's bond
  level in a gold ring, and its nickname under the name.
- **World tooltip:** under the species line, the temperament: "Pepe / Panda Cub / tam og kosete".
- **Park map:** the icon border is colored by temperament stage, and the tooltip carries the story.
- **Achievements:** the loyalty ones move to bond levels. "Bestevenner" means reaching "Venn", and so on. Ones
  already earned stay earned.
- **Guild chat** (respects `/dp kunngjør`): only the big moments, e.g. "Pepe er blitt en parklegende!"

## 5. Data and sync

- **Bond:** two new fields in the owner's adoption record, points `b` and a points timestamp. Only the owner writes,
  as today. To keep traffic low, the owner publishes at most every 30 minutes, at a level-up, and at logout.
- **Lifetime per pet:** `g.life[petKey][carer] = { p = points, f = firstAdopted, l = lastSeen }`, written only by
  that carer and merged by the highest `p`. It's the same pattern as nicknames. Temperament is the sum of `p`
  over carers. First home is the lowest `f`.
- **Sanity bounds** on the wire: points can't exceed what's possible since `f` (a daily maximum times days), and
  the usual time bounds apply. A forged huge score is refused.
- **Migration:** existing adoptions are seeded with 10 points per day already together, so nobody starts over.
  Only adoptions from before bonds shipped (Config.BONDS_SHIPPED, 0.1.0-alpha4), and only their days until then
  (2026-11-10: seeding any adoption with no entry yet gave points nobody earned, on a new PC before the SYNC's
  bonds arrived, or for a pet never out).
  Protocol bump.
- **Collection sync** (if chosen): `g.owned[member] = { ts, list }`, a compact species list sent in SYNC and
  updated on `NEW_PET_ADDED`.

## 6. Stages (each committed, tested, verified in game)

0. **Probe** the activity events above, like the kills probe: which fire, with what, and whether they're secret in
   or out of combat. Partly done (kills). Build only on what works.
1. **Activity engine:** sources, on-demand registration, counters and caps, the `activity` achievement kind, the
   kills probe folded in. First sources: the daily presence and whatever passed the probe.
   *Built 2026-11-08* (`Core/Activity.lua`): sources day, boss, quest, pvp, taxi (all but day unverified in game);
   no achievements use it yet. The kills probe stays separate until its dungeon log is read.
2. **Bond core:** daily points, levels, the card bar, the migration seed, loyalty achievements moved to levels.
   *Built 2026-11-08* (Menagerie/Bond.lua, protocol 5): the bond lives in `g.life` (not in the adoption record),
   which is what lets a re-adopted pet bring its bond back. The digest holds levels, not points.
3. **Activities and likes:** more sources as probes confirm them, likes per tag, quirks, flavor lines.
   *Built 2026-11-08* (Menagerie/Personality.lua): likes from families plus species of their own (Panda Cub:
   herbs), eight quirks picked by species id (one adds a like; "Kosete" doubles the days). Liked activities 5 points
   (25 a day each), others 1 (5 a day; since 2026-11-10: 3 a day each and 10 in all). Gathering (herb, mine, fish, skin) from your own casts, registered for the
   player only; unverified in game. Shown on the card's third line and in tooltips.
   *Two traits per pet, 2026-11-08:* traits of three kinds: a liked activity (the first eight), a moment when
   anything done counts as liked (Nattugle 22-04, Flokkdyr with a guildmate in the group, Einstøing alone,
   Huleboer in dungeons and raids, Friluftsdyr outside them; one 25-point cap per trait, 10 since 2026-11-10), and a day multiplier
   (Kosete x2, Helgedyr x2 on weekends, Festglad x3 on Norwegian holidays). Contradicting pairs never meet.
   *The probed traits, same day:* Dansefot (dance), Kjælen (cuddle: /pet, /hug... naming the companion), Oppdager
   (explore: a place this companion hasn't been, `char.places`), Trofast (revive: up again after PLAYER_DEAD),
   Hoppetass (jump, per 10), Dykker (dive), Hjemlengsel (hearth: the Hearthstone, Astral Recall, Teleport: Moonglade), Ambisiøs (level), Latsabb (nap: AFK while
   resting), Pratsom (chat: our own guild lines). The bond watches these only for a pet that likes them.
   **Pinned** the same day: every species' two traits are in `Data/Traits.lua` for good (Panda Cub: Kosete and
   Grønnfinger, by hand; the rest balanced, 6-7 species per trait). New species: `luajit tools/pin_traits.lua`.
   *Bonds with every pet, 2026-11-09:* any pet of yours that's out bonds (one you haven't adopted at half rate,
   its own day of 37), and "Hold ute" picks the one auto-summon keeps out. New ways to earn, all at the pet's rate:
   **firsts together** (10: a boss this pet hasn't seen fall, `char.firsts`; a place it hasn't been; at most 3 lines
   a pet a day), **playdates** (15, once a day per pet: in a group with a guildmate whose pet is out; a PLAY
   message on PARTY/RAID, sent on group changes and summons at most every 10 minutes, answered at most once a
   minute; Menagerie/Playdate.lua), and **skill-ups and reputation** (activities `skill` and `rep`).
4. **Lifetime and temperament:** `g.life` sync, temperament stages, park map borders, world tooltip word.
5. **Story:** the timeline, milestone lines, big moments in guild chat.
6. **(Optional) Collection sync:** "kom til parken", "vill" for pets nobody has, the wish list on the park map.

## Decisions (2026-11-08)

1. **No decay.** A bond only pauses while you're away; it never goes down.
2. **Daily points** need one login that day with the adopted pet summoned. Activities need it out at that moment.
3. **Re-adopting** a pet you let go brings your old bond back: `g.life` keeps each carer's points per pet, and the
   new adoption resumes from them.
4. **Collection sync: yes, as the last stage** (stage 6). Until then the story starts at "Første hjem", and pets
   never adopted show as "Vill".
5. **Names** as suggested: bond levels Bekjent, Kamerat, Venn, God venn, Bestevenn, Uatskillelig, Sjelevenn;
   temperament Vill, Sky, Nysgjerrig, Tam, Kosete, Parklegende.
6. **Everyone sees bond levels** (tooltips, park map), not only the carer.
