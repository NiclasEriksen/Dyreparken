# Ideas for later (creative review, 2026-11-09)

A review of the pet card and the pet life features for fun details, barriers to fun, and UI fixes, from a
screenshot of the journal (Pepe the Panda Cub, bond level 1) and the code. Nothing here is decided: pick, change or
drop. Each idea notes what it builds on.

## UI fixes (from the screenshot)

Done 2026-11-09: Dagens dyr (a gold star instead of the label, and a click shows the pet in the journal through
`PetJournal_SelectSpecies`, unverified on Forever), the quest chip (the quest giver's "!", a book as fallback), the
list's "free" mark (a little house), and the likes line (light text). Still open: the empty space, the level shown
three times.

- **"Dagens dyr" is cut off** ("Br…"). The box only gets the room left of the card's right edge
  (JournalUI: `todayBox`). Show the nickname or a short name with the rest on hover, and **make the box clickable**:
  it jumps to that pet in the list. Useful, and a reason to look at it every day.
- **The quest chip shows a "?"** (the gossip icon is missing on Forever; Activity.KINDS `quest`). A question mark
  reads as "unknown". A scroll or book icon would read better.
- **Two kinds of rings side by side in the list.** The gold ring holds the bond level and the green ring means
  "free to adopt" (JournalList markers). They look alike, and Pachimari shows only the green one. A different
  "free" mark (a small house or door: "trenger et hjem") would tell them apart.
- **"Liker herbs" is small grey text** (GameFontDisableSmall) under brighter lines and hard to read. Discovered
  dislikes now land on the same line ("· liker ikke dykking").
- **Empty space** between the stat chips and the model: room for a mood or wish line (below).
- The bond level shows three times (the medallion "1", the first star, "Bekjent"). Fine, but if the panel gets
  crowded the star track can carry it alone.

## Fun details

- **Today's mood.** A small word on the card ("Søvnig", "Leken", "Sulten"...), the same on every client (from the
  species and the date, like Dagens dyr; no messages). Now and then it hints at the wish of the day.
- ~~**Tease the dislikes.**~~ Done 2026-11-10 (the personality tooltip). While one is still secret, the card tooltip says "Det er noe {pet} ikke liker…".
  Finding it becomes a small goal (Personality:Dislikes vs char.dislikes).
- ~~**An egg collection.**~~ Done 2026-11-10: Påskeegghøne (10) and Eggspert (25). Eggs are counted per character already (char.eggs). An achievement ("Påskeegghøne: fant 10
  forskjellige") and maybe a list of the ones found.
- **Share a funny line.** Quirk lines are only for you. A clickable `[Del]` after one could post it to guild
  chat (a click is a hardware event, which Forever needs for guild chat).
- ~~**Traits in the world tooltip.**~~ Done 2026-11-10. Hovering a guildmate's pet shows "Dyreparken: bor hos…"; add its two traits
  (only for a known personality). It rewards hovering, which the new cursor puff (Fx.lua) already invites.
- **Name suggestions** in the nickname popup, from the species and traits (a Latsabb gets "Slappe"?). One small
  list in Locale.
- **The model reacts**: its own section below.
- ~~**The anniversary as a "birthday".**~~ Done 2026-11-09: a cake with flickering candles on an adopted pet's card on
  its milestone days (Menagerie/Cake.lua).

## Animating the pet on demand (the user's "gamechanger", 2026-11-09)

If the pet on the card (and maybe elsewhere) can play an animation when we ask, a lot opens up. Untested: the
servers were down when this came up. **First step: a probe**, built 2026-11-10 (`/dp probe anim [list|all|stop|<id|name>]`,
Menagerie/Moves.lua, ids from wowdev.wiki/M2/AnimationList, pet battle ones 742-772 too): find the card's model actor
(`PetJournalPetCard`'s model scene, `GetActorByTag` or its first actor), call `SetAnimation(id)` with a list of
animation ids from the client's animation table (stand, bow, wave, cheer, dance, laugh, sleep, sit, jump, roar...;
the ids need looking up, not guessing), and log which the client accepts and whether the pet
moves. Then ask the user what they saw. Read docs/FOREVER_API.md (secret values, the model scene notes) first.

Built 2026-11-10 (Menagerie/Moves.lua): asleep at night, the Latsabb sitting, the happy hop on a click, the level-up
spell, playing dead. Still open below: the rest.

What it could open, once we know which animations a companion has:
- **Reactions on the card**: a cuddle click (Cuddle.lua) makes it bow or jump; a bond level-up (BondTrack's
  celebration) makes it cheer or dance; opening the card in the evening finds it asleep.
- **Mood and traits shown, not told**: a Latsabb pet sits down after a while, a Dansefot one dances when you dance
  (CHAT_MSG_TEXT_EMOTE), a Nattugle one perks up at night.
- **Dislikes and eggs with a gesture**: a disliked activity's line comes with a shake or a turned back the next time
  you open the card; an easter egg day (17 May, Christmas) with its own little act.
- **The Parken page**: a hovered icon could show a small live model playing an idle animation instead of a flat icon.
- Keep the performance rule: animations only while the card is shown, no OnUpdate, one-shot where possible.

## Barriers to fun

- **Hard to discover.** A new player sees rings, chips and a bond bar, but nothing says what feeds them. A small
  "?" on the card with three lines (likes, wishes, playdates).
- **Playdates happen invisibly.** Nobody knows they exist until one happens. A hint in the tooltip when a guildmate
  in your group has a pet out.
- **A slow start.** The first level takes about a week of casual play. A bonus the first day you adopt a pet
  ("første dag sammen") would make the start feel good. A balance call.

## Known limits (from the code reviews)

- (2026-11-10) Bond points lost in a crash come back only if a whole level was lost: the digest compares levels,
  and only a carer sends their own bond. Getting the guild's higher copy back needs a new message and a protocol
  bump; the user chose not to bump for it.
- (2026-11-10) A forged bond can claim any level once enough days have passed since BOND_EPOCH: LifeCap counts from
  a start date the sender picks. No cheap rule is forgery-proof; a bond only gives cosmetics and nickname rights.

- Records and lapses still have no cap on what's stored: SYNC relays them for any owner name, so a member could
  flood made-up owners until honest SYNC parts are over SYNC_MAX_ENTRIES. Names and bonds got per-member caps
  (Registry: Trim); owners can't be capped the same way (one record each). A fix would need a rule every client
  applies alike, e.g. dropping released records of owners not seen for a long time.

# Small additions (creative review, 2026-11-10)

Small touches that build on what's there. Nothing here is decided. Sizes: **tiny** (a table row or a few Locale
lines), **small** (under ~60 lines and a test), **medium** (several modules). ★ = the review's favourites. Every
idea keeps the rules: no bond points from flavor, no polling, events only while needed, Norwegian text.

Built 2026-11-10: everything below except the December calendar, April Fools and Fastelavn (the user said no to
those). Changed while building: the seasons are one faint particle, the last to go (the user: "veeery sparingly");
the early bird is 05:00-07:00; the midnight dance only for a pet whose like already watches dancing (every emote
nearby would wake it); the park's birthday counts claims only. To check in game: walking (the moving events), the
turned back (SetYaw), the inn's name (GetBindLocation), the zone names, and a guildmate's /dp klapp arriving.

## The card

- ★ **Zzz over a sleeping pet.** When Moves puts the pet to sleep at night, a few `zee` particles rise from it
  (Decor.KINDS, the Latsabb kind). A click to wake it stops them. Only while the card shows. *Tiny.*
- ★ **A cuddle answers in the pet's own particles.** One or two of Cuddle's four hearts become the first trait's
  particle (`Decor.TRAITS[id].kind`): bubbles for a Dykker, a note for a Dansefot, a crumb for a Glupsk, a bolt for
  a Fleibede. No trait particle: the family's (`Decor.FAMILY`). *Tiny.*
- **Trait particles that remember today.** If a trait's activity happened today (`Activity:Count`), the trait shows
  double its particles until midnight: chevrons on the day you dinged, Pratsom's speech bubbles after guild chat.
  A multiplier in `Decor:Specs`. *Tiny.*
- **"Fornøyd for i dag."** After BOND_FULL your pet on the card sits (the `sit` anim) instead of standing. *Tiny.*
- **A happy hop when a wish comes true.** The first time you open the card after the wish is done, it plays its
  happy move once (`Moves:Cuddle`, a `char.wish.shown` flag). *Tiny.*
- **Round numbers on the chips.** A stat chip reaching 10, 50, 100 or 500 gets the `ring` texture as a gold rim
  for the day; tooltip "100 quests sammen med {pet}!" (Stats:Update). *Small.*
- **The last place you saw together.** The explore chip's tooltip: "Sist oppdaget sammen: Westfall"
  (`Activity:CheckPlace` has the name; a `char.lastPlace[key]`). *Tiny.*
- **A sulky back after a dislike** (builds on "turned back" above): the first card open on a dislike day, the pet
  turns away for three seconds with a `cloud` puff. Needs `ModelSceneActor:SetYaw`, unverified on Forever. *Small.*
- **The pet walks with you** (the user's idea, 2026-11-10). Only the active pet (char.activePet, auto-summon on):
  it walks (anim 4) while you move on foot and runs (5) while you're mounted and moving; on a taxi it stands. It
  **never overrides another animation**: cuddle, cheer, playing dead, asleep at night and the Latsabb's sit all
  win; motion replaces only the plain stand. Both ids are in Moves.ANIMS (they play on companions); add
  `walk = 4, run = 5` to `PetMoves.default`, with `false` per species where it looks wrong (wisps, oozes).
  Events only while the card shows: `PLAYER_STARTED_MOVING`/`PLAYER_STOPPED_MOVING` (**unverified on Forever**),
  `PLAYER_MOUNT_DISPLAY_CHANGED` + `IsMounted()` and `UnitOnTaxi` (both in use in Summon). Debounce the stop ~0.3 s
  so key taps don't twitch it. Opening the card mid-run starts at rest unless `GetUnitSpeed`/`IsPlayerMoving` exist
  (unverified). Open: mounted but standing still (suggested: stand). *Small to medium.*

## The world and chat

- ★ **Family voices for `/dp klapp`.** After the pat, a line only you see: "{pet} sier «mjau»." Cat «mjau», owl
  «hu-hu», frog «kvekk», mechanical «bzzt-klikk», dragon a «fnys», snake «sssss», rodent «pip», wolf «auuu», ooze
  «blubb», demon «hehehe». One Locale table `voice.<family>`. *Tiny.*
- ★ **Hearing a guildmate's pat.** A nearby guildmate's `/dp klapp` emote reaches you as CHAT_MSG_EMOTE with your
  pet's name: hearts at the chat window (Fx) and "{pet} logrer fornøyd etter klappen fra {who}." No new wire
  message. Register only while your adopted pet is out; sender must be in the roster; `Plain()` the text.
  Unprobed: whether custom emotes arrive that way. *Small.*
- **Hearts in the holder's colors.** The cursor hearts on a companion (Fx) tinted by its holder's bond tier
  (`Scenes.Tier`): pink, silver from 3, gold from 5. *Tiny.*
- ★ **It remembers an old carer.** Hovering a companion whose owner has a `g.life` entry with your current pet:
  an egg "{pet} kjenner igjen {owner}! De bodde sammen en gang." *Small.*
- **Cousins meet.** COMPANION_SEEN with the same family, another species, chance 0.25: "{pet} og {owner} sitt dyr
  snuser forsiktig på hverandre." Two owls: "To ugler, null søvn." *Tiny.*
- **Home by name.** The hearth line names the inn: "{pet} er glad for å være hjemme i {home}!" Needs
  `GetBindLocation`, unverified. *Tiny.*
- **At home in a zone.** Family → zone: a pirate pet in Booty Bay, a frog in the Wailing Caverns, an owl in
  Moonglade, a mechanical pet in Gnomeregan. "{pet} føler seg hjemme blant piratene i Booty Bay!" Zone names need a
  look in game. *Small.*

## The guild together

- ★ **Congratulate from the cake.** A click on another member's milestone cake (Cake.lua) posts "Gratulerer med
  {time}, {owner} og {pet}!" to guild chat (the click is the hardware event). Once per pet a day; respects
  `/dp kunngjør`. *Small.*
- **A best friend in the park.** Count playdates per pet pair (`char.playmates`); the bond tooltip: "Bestevenn i
  parken: Mjau (Kari Berg), 6 lekedater." The fifth brings a line. *Small.*
- **Full house.** PLAY from three or more guildmates within ten minutes: once a day, "Full fest: {n} dyr fra parken
  på samme sted!" No new traffic. *Small.*
- **Your pet is Dagens dyr.** A line after login, "{pet} er dagens dyr i guilden i dag!", and the `halo` over it on
  the card that day (pairs with the crown in CLAUDE.md's Future additions). *Tiny.*
- **The park's birthday.** The guild's first adoption is the day Dyreparken opened there (a guild fact, not a
  player's birthday): confetti on every card and "Dyreparken fyller {n} år i dag!" *Small.*

## Easter eggs (rows in Quirks.EGGS, lines egg.<id>.N)

- ★ **Fredagstaco.** Fridays after 17:00 with a Glupsk pet or a cat: "{pet} lukter taco. Det er fredag!" Saturdays,
  for a Helgetroll: "{pet} har funnet lørdagsgodteriet ditt." *Tiny.*
- **Monday blues** for a Helgetroll: "{pet} er sur. Det er mandag, og helgen er fem dager unna." *Tiny.*
- **13:37**: "{pet} synes klokka er ekstremt kul akkurat nå." *Tiny.*
- **A midnight dance** (dance 00:00–00:30): "Midnattsdans! {pet} visste ikke at du hadde det i deg." *Tiny.*
- **A hundred jumps** in a day: "{pet} har hoppet 100 ganger med deg i dag og må hvile litt." A Hoppetass: "...og
  vil ha mer!" *Tiny.*
- **A long nap** (nap ×5): "{pet} lurer på om dere har flyttet inn i vertshuset." *Tiny.*
- **Early bird** (the day's visit before 07:00): "{pet} gnir søvnen ut av øynene. Så tidlig?" A Nattugle: "{pet}
  har ikke lagt seg ennå." *Tiny.*
- **A namesake** nickname (your own first name): "{pet} heter det samme som deg. Det blir rot ved middagsbordet."
  Same as another guild pet: "Nå finnes det to «{nick}» i parken!" *Tiny.*
- **April Fools for real.** On 1 April a Fleibede's card shows another species' name, picked from the date, with an
  "Aprilsnarr!" tooltip. *Small.*

## Seasons and time (date math, read when the card draws)

- ★ **A December calendar.** 1–24 December, the first card open each day "opens a door": a gold star burst and
  one of 24 lines ("Luke 7: {pet} fant en pepperkake bak sofaen." "Luke 24: {pet} har pakket inn en gave til deg.
  Den er formet som en pinne."). A missed day stays shut. *Small, mostly writing.*
- **Seasons on the card.** Autumn leaves in October–November on outdoor pets, clover in April–May, butterflies in
  June–August (existing kinds, a `when = Month(...)` in `Decor:Specs`). *Tiny.*
- **National days for everyone.** 17 May: confetti in red, white and blue on every card. Sankthans: embers from
  below. New Year's Eve 23:50–00:10: sparks. *Tiny.*
- **Easter and Fastelavn** (Easter Sunday by the Gauss formula): "{pet} har gjemt et påskeegg i bagen din. Kvikk
  Lunsj?" Fastelavn: feathers and "{pet} har pyntet seg med fjær." *Small.*
- **The clocks change** (`date("*t").isdst` differs from yesterday): "Klokka ble stilt i natt, og {pet} skjønner
  ikke når det er middag." *Tiny.*

## An achievement

- **"Kjenner deg ut og inn"**: you've found every dislike of your adopted pet (char.dislikes against
  `Personality:Dislikes`). A new Defs kind. *Small.*

# Waiting for later (noted 2026-11-10, the user: "most of these should wait")

- **Temperament** (docs/PET_LIFE.md stage 4): a pet's total bond across all carers as stages (Vill → Sky →
  Nysgjerrig → Tam → ... → Parklegende; "Kosete" clashes with the trait's name), a word in the world tooltip and a
  colored border on the Parken map. Needs thresholds.
- ~~**The pet's story** (stage 5)~~ Built 2026-11-10, local only (Menagerie/Story.lua): homes, moves, names, levels,
  milestones, pet of the day, and your firsts, achievements and eggs with it. Still to come: syncing it, the Parken
  tooltip, and big moments in guild chat.
- **Collection sync** (stage 6, a protocol bump): what each member owns, so "the guild is missing these",
  "arrived in the park" and "wild" pets nobody has.
- **Trofast's halo** hangs at a fixed height like the old pet-of-the-day halo (the client can't say where a head
  is): keep it, make it a glow under the pet, or drop it.
- The leftover ideas above: today's mood word, a "Del" link for a funny quirk line, name suggestions, a "?" help,
  the playdate hint, a first-day bonus, a live model on Parken.
- **Whispers:** replies (bond answers) as whispers instead of guild-wide, once whispering "First Surname" is
  probed on Forever.

# Known bugs (to fix later)

- **Playdates work at any distance** (the user, 2026-11-11): a guildmate's pet anywhere in the group counts, even
  far away. Only one in range should (Menagerie/Playdate.lua). Candidates to probe on Forever: `UnitInRange`,
  `CheckInteractDistance`, `UnitIsVisible`, or the companion seen nearby (Quirks' COMPANION_SEEN, Tooltip).

# The pet frame's settings (noted 2026-11-11, the user)

Two more options for the pet frame (Menagerie/PetFrame.lua, the "Dyret på skjermen" column in Settings):

- **Hide in combat.** Hidden on PLAYER_REGEN_DISABLED, back on PLAYER_REGEN_ENABLED (registered only while the
  frame and the option are on). The frame has no protected parts, so Hide/Show in combat is allowed.
- **Fade when inactive.** Decided (the user, 2026-11-11): the frame is faded at all times, except while the
  mouse is over it and briefly when something happens to the pet (a new level, bond points rising, a cheer and the
  like), then it fades back. Faded opacity 25% by default, with a slider in Settings to change it. The click layer
  already takes the mouse (OnEnter/OnLeave), so no polling.
