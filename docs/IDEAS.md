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
- **Tease the dislikes.** While one is still secret, the card tooltip says "Det er noe {pet} ikke liker…".
  Finding it becomes a small goal (Personality:Dislikes vs char.dislikes).
- **An egg collection.** Eggs are counted per character already (char.eggs). An achievement ("Påskeegghøne: fant 10
  forskjellige") and maybe a list of the ones found.
- **Share a funny line.** Quirk lines are only for you. A clickable `[Del]` after one could post it to guild
  chat (a click is a hardware event, which Forever needs for guild chat).
- **Traits in the world tooltip.** Hovering a guildmate's pet shows "Dyreparken: bor hos…"; add its two traits
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

## Known limits (from the code review)

- Records and lapses still have no cap on what's stored: SYNC relays them for any owner name, so a member could
  flood made-up owners until honest SYNC parts are over SYNC_MAX_ENTRIES. Names and bonds got per-member caps
  (Registry: Trim); owners can't be capped the same way (one record each). A fix would need a rule every client
  applies alike, e.g. dropping released records of owners not seen for a long time.
