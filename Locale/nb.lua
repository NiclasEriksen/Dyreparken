local _, ns = ...
local L = ns.L

-- Every text players read, in Norwegian (bokmål). Edit freely: the code only
-- knows the keys (left), never the words. {name} is a placeholder the code
-- fills in; keep each one a text uses, in any order. Colors are WoW codes:
-- |cffRRGGBB starts one, |r ends it. Keys are permanent-ish: renaming one
-- means renaming it in the code too.
--
-- Achievements have their own table at the end (ns.AchTexts).

------------------------------------------------------------------------------
-- Time and home ("Bor hos Kari Berg i 3 dager")
------------------------------------------------------------------------------
L["time.today"] = "siden i dag"
L["time.yesterday"] = "siden i går"
L["time.days"] = "i {n} dager"
L["time.months"] = "i {n} måneder"
L["time.years"] = "i {n} år"
L["home.today"] = "Flyttet inn hos {who} i dag"
L["home.yesterday"] = "Flyttet inn hos {who} i går"
L["home.since"] = "Bor hos {who} {how}"          -- {how}: one of the time.* texts
L["home.you"] = "deg"                            -- {who} when it's your own pet

------------------------------------------------------------------------------
-- Slash commands (/dp)
------------------------------------------------------------------------------
L["cmd.adopt.nomatch"] = "Du har ikke noe dyr som passer «{text}»."
L["cmd.adopt.nothing"] = "Summon dyret du vil adoptere, eller skriv navnet."
L["cmd.list.head"] = "Guilden har hjem til {n} av {total} dyr ({pct}%):"
L["cmd.list.row"] = "  {pet} - {owner}"
L["cmd.list.row_nick"] = "  {pet} - {owner} («{nick}»)"
L["cmd.sound.deferred"] = "AutoCompanion er lastet: bruk innstillingen «Mute summoning sounds» der."
L["cmd.sound.on"] = "Summonlyden er på."
L["cmd.sound.off"] = "Summonlyden er dempet."
L["cmd.help.head"] = "{version} - kommandoer:"
L["cmd.help.adopter"] = "adopter [navn] - adopter dyret du har ute, eller et ved navn"
L["cmd.help.gislipp"] = "gislipp - gi slipp på dyret ditt"
L["cmd.help.navn"] = "navn [kallenavn] - gi dyret ditt et kallenavn (tomt fjerner det)"
L["cmd.help.liste"] = "liste - hvilke dyr som har et hjem i guilden"
L["cmd.help.lyd"] = "lyd [på|av] - klirringen når et dyr summones (dempet som standard)"
L["cmd.help.prestasjoner"] = "prestasjoner [del|varsel på|av] - prestasjonene dine; del nye i guild-chatten"
L["cmd.help.kunngjor"] = "kunngjør [på|av] - del adopsjoner og kallenavn i guild-chatten (på som standard)"
L["cmd.help.klapp"] = "klapp - klapp dyret du har valgt som mål, eller ditt eget"

------------------------------------------------------------------------------
-- Versions
------------------------------------------------------------------------------
L["version.newer"] = "En nyere versjon ({theirs}) er ute; du har {mine}."

------------------------------------------------------------------------------
-- Adopting, letting go, nicknames (Registry)
------------------------------------------------------------------------------
L["nick.empty"] = "Du har ikke skrevet noe kallenavn."
L["nick.too_long"] = "Kallenavn kan ha maks {n} tegn."
L["nick.bad_chars"] = "Kallenavn kan ikke inneholde | eller linjeskift."
L["nick.no_pet"] = "Du har ikke adoptert noe dyr."
L["nick.locked"] = "Du kan gi det et kallenavn når båndet deres er {level} (nivå {n})."
L["nick.same"] = "Det heter allerede «{nick}»."
L["nick.none"] = "Det har ikke noe kallenavn."
L["nick.set"] = "Kallenavnet er nå «{nick}»."
L["nick.cleared"] = "Kallenavnet er fjernet."
L["adopt.no_guild"] = "Du er ikke i en guild."
L["adopt.unknown"] = "Ukjent dyr."
L["adopt.not_owned"] = "Du har ikke det dyret."
L["adopt.yours"] = "Det bor allerede hos deg."
L["adopt.taken"] = "Det bor allerede hos {owner}."
L["adopt.done"] = "Du adopterte {pet}."
L["adopt.done_swap"] = "Du adopterte {pet} (og ga slipp på {old})."
L["adopt.keeps_own_name"] = " Det heter fortsatt «{nick}»."
L["adopt.confirm"] = "Adoptere {pet}?"
L["adopt.confirm.swap"] = "Du gir da slipp på {pet}."
L["adopt.confirm.announce"] = "Adopsjonen blir kunngjort i guild-chatten, så hele guilden får se den. (Slå av med /dp kunngjør.)"
L["adopt.inherits_name"] = " Det heter «{nick}», et navn det fikk av {namer}. Ta godt vare på det!"
L["release.none"] = "Du har ikke adoptert noe dyr."
L["release.done"] = "Du ga slipp på {pet}."
L["lapse.away"] = "{pet} dro tilbake til parken mens du var lenge borte. Adopter det igjen hvis det fortsatt er ledig."
L["lapse.beaten"] = "{owner} rakk å adoptere {pet} rett før deg, så det bor der nå."
L["lapse.unknown_owner"] = "?"

------------------------------------------------------------------------------
-- /dp rapport (who forgot their companion; posted to group chat)
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Milestones, dagens dyr, /dp klapp, guild announcements (Bonds)
------------------------------------------------------------------------------
L["milestone.month"] = "1 måned"
L["milestone.days100"] = "100 dager"
L["milestone.years"] = "{n} år"
L["milestone.mine"] = "I dag har {pet} bodd hos deg i {time}!"
L["milestone.other"] = "{owner} og {pet} feirer {time} sammen i dag!"
L["milestone.more"] = "... og {n} til."
L["nick.unlocked_rename"] = "Nå kan du gi {pet} et nytt kallenavn hvis du vil: /dp navn"
L["nick.unlocked"] = "Nå kan du gi {pet} et kallenavn: /dp navn"
L["pat.own"] = "klapper {pet}."                       -- an emote: "Ola klapper Pepe."
L["pat.other_nick"] = "klapper {nick} ({owner} sin {species})."
L["pat.other"] = "klapper {owner} sin {species}."
L["pat.combat"] = "Ikke nå, du er i kamp."
L["pat.nothing"] = "Summon dyret ditt, eller velg et dyr som mål."
L["announce.adopt_nick"] = "Dyreparken: {player} adopterte {species} («{nick}»)!"
L["announce.adopt"] = "Dyreparken: {player} adopterte {species}!"
L["announce.name"] = "Dyreparken: {player} ga {species} kallenavnet «{nick}»!"
L["announce.on"] = "Adopsjoner og kallenavn kunngjøres i guild-chatten."
L["announce.off"] = "Adopsjoner og kallenavn kunngjøres ikke lenger i guild-chatten."

------------------------------------------------------------------------------
-- The bond (Bond, BondTrack)
------------------------------------------------------------------------------
L["bond.level.1"] = "Bekjent"
L["bond.level.2"] = "Kamerat"
L["bond.level.3"] = "Venn"
L["bond.level.4"] = "God venn"
L["bond.level.5"] = "Bestevenn"
L["bond.level.6"] = "Uatskillelig"
L["bond.level.7"] = "Sjelevenn"
L["bond.label"] = "{level} (nivå {n})"                -- "Venn (nivå 3)"
L["bond.levelup"] = "|cffffd100Båndet ditt med {pet} er nå på nivå {n}: {level}!|r"
L["first.boss"] = "{pet} var med da {boss} falt!"          -- the first time this pet sees that boss fall
L["first.place"] = "{pet} så {place} for første gang!"     -- the first time this pet is in that place
L["play.line"] = "{pet} lekte med {friend} ({owner})!"   -- a playdate: our pet met a guildmate's in the group
L["bond.liked"] = "{pet} koste seg med {activity}!"   -- the first liked thing of the day
L["bond.full"] = "|cffffd100Båndet med {pet} er fullt for i dag. Fortsett i morgen!|r"

------------------------------------------------------------------------------
-- Auto-summon
------------------------------------------------------------------------------
L["summon.deferred"] = "AutoCompanion er lastet, så Dyreparken tilkaller ikke automatisk. Guilden ser fortsatt hvilket dyr som bor hos deg."

------------------------------------------------------------------------------
-- Lists ("herbs, quests og flyturer")
------------------------------------------------------------------------------
L["list.sep"] = ", "
L["list.and"] = " og "

------------------------------------------------------------------------------
-- Activities: what pets like doing with you (the guild's own words: herbs,
-- kills, quests, mining, skinning). .flavor: the line for the first liked one
-- of a day; without one, bond.liked is used ("Pepe koste seg med herbs!").
------------------------------------------------------------------------------
L["activity.boss"] = "boss-kills"
L["activity.quest"] = "quests"
L["activity.taxi"] = "flyturer"
L["activity.pvp"] = "PvP"
L["activity.herb"] = "herbs"
L["activity.mine"] = "mining"
L["activity.fish"] = "fisking"
L["activity.skin"] = "skinning"
L["activity.day"] = "dager sammen"
L["activity.dance"] = "dansing"
L["activity.dance.flavor"] = "{pet} danset med deg!"
L["activity.cuddle"] = "kos"
L["activity.cuddle.flavor"] = "{pet} elsker å bli kost med!"
L["activity.chat"] = "guildprat"
L["activity.chat.flavor"] = "{pet} lytter fornøyd til guildpraten."
L["activity.dive"] = "dykking"
L["activity.dive.flavor"] = "{pet} plasket rundt med deg!"
L["activity.level"] = "nye levels"
L["activity.level.flavor"] = "{pet} er så stolt av deg!"
L["activity.revive"] = "å vente på deg"
L["activity.revive.flavor"] = "{pet} ventet tålmodig på deg."
L["activity.nap"] = "lur i byen"
L["activity.nap.flavor"] = "{pet} tok en lur sammen med deg."
L["activity.hearth"] = "å dra hjem"
L["activity.hearth.flavor"] = "{pet} er glad for å være hjemme!"
L["activity.jump"] = "hopping"
L["activity.jump.flavor"] = "{pet} hopper av glede!"
L["activity.explore"] = "nye steder"
L["activity.explore.flavor"] = "{pet} snuser på et nytt sted!"
L["activity.skill"] = "skill-ups"
L["activity.rep"] = "omdømme"

------------------------------------------------------------------------------
-- Holidays (the Festglad trait)
------------------------------------------------------------------------------
L["holiday.0101"] = "1. nyttårsdag"
L["holiday.0517"] = "17. mai"
L["holiday.0623"] = "St. Hans"
L["holiday.1224"] = "julaften"
L["holiday.1225"] = "1. juledag"
L["holiday.1231"] = "nyttårsaften"

------------------------------------------------------------------------------
-- Traits: two per pet. .name and .desc for all; .when (a moment: anything done
-- then counts as liked) with its .flavor; .day (a day worth more) with its
-- .dayflavor. Ids (the middle part) never change.
------------------------------------------------------------------------------
L["trait.glupsk.name"] = "Glupsk"
L["trait.glupsk.desc"] = "Spiser alt, og elsker belønningen etter en quest."
L["trait.eventyrlysten.name"] = "Eventyrlysten"
L["trait.eventyrlysten.desc"] = "Vil alltid være med på boss-kills."
L["trait.reiseglad.name"] = "Reiseglad"
L["trait.reiseglad.desc"] = "Elsker å fly."
L["trait.rampete.name"] = "Fleibede"
L["trait.rampete.desc"] = "Liker litt bråk."
L["trait.gronnfinger.name"] = "Grønnfinger"
L["trait.gronnfinger.desc"] = "Snuser på hver eneste herb."
L["trait.vannhund.name"] = "Vannhund"
L["trait.vannhund.desc"] = "Elsker vann og fisk."
L["trait.steinhard.name"] = "Steintøff"
L["trait.steinhard.desc"] = "Graver gjerne etter malm."
L["trait.dansefot.name"] = "Dansefot"
L["trait.dansefot.desc"] = "Kan ikke sitte stille når du danser."
L["trait.kjaelen.name"] = "Kosete"
L["trait.kjaelen.desc"] = "Elsker /pet, /hug og /cuddle."
L["trait.oppdager.name"] = "Oppdager"
L["trait.oppdager.desc"] = "Vil se hele verden, ett sted om gangen."
L["trait.trofast.name"] = "Trofast"
L["trait.trofast.desc"] = "Venter på deg, uansett hva som skjer."
L["trait.hoppetass.name"] = "Hoppetass"
L["trait.hoppetass.desc"] = "Hopper når du hopper."
L["trait.dykker.name"] = "Dykker"
L["trait.dykker.desc"] = "Holder pusten lenger enn deg."
L["trait.hjemlengsel.name"] = "Hjemlengsel"
L["trait.hjemlengsel.desc"] = "Borte bra, men hjemme best."
L["trait.ambisios.name"] = "Ambisiøs"
L["trait.ambisios.desc"] = "Vil se deg bli sterkere."
L["trait.latsabb.name"] = "Latsabb"
L["trait.latsabb.desc"] = "En lur i byen er det beste som finnes."
L["trait.pratsom.name"] = "Pratsom"
L["trait.pratsom.desc"] = "Elsker når du prater med guilden."
L["trait.kosete.name"] = "Klengete"
L["trait.kosete.desc"] = "Det er nok å være sammen."
L["trait.kosete.day"] = "Hver dag sammen"
L["trait.nattugle.name"] = "Nattugle"
L["trait.nattugle.desc"] = "Våkner til liv når det blir mørkt."
L["trait.nattugle.when"] = "mellom kl. 22 og 04"
L["trait.nattugle.flavor"] = "{pet} elsker nattlige eventyr!"
L["trait.festglad.name"] = "Festløve"
L["trait.festglad.desc"] = "Elsker 17. mai, St. Hans, jul og nyttår."
L["trait.festglad.day"] = "En høytidsdag sammen (17. mai, St. Hans, julaften, 1. juledag, nyttårsaften, 1. nyttårsdag)"
L["trait.festglad.dayflavor"] = "{pet} feirer {holiday} med deg!"
L["trait.helgedyr.name"] = "Helgetroll"
L["trait.helgedyr.desc"] = "Lever for helgene."
L["trait.helgedyr.day"] = "En lørdag eller søndag sammen"
L["trait.helgedyr.dayflavor"] = "{pet} elsker helg!"
L["trait.flokkdyr.name"] = "Flokkdyr"
L["trait.flokkdyr.desc"] = "Trives best i flokk."
L["trait.flokkdyr.when"] = "med en fra guilden i gruppen"
L["trait.flokkdyr.flavor"] = "{pet} koste seg i flokken!"
L["trait.einstoing.name"] = "Einstøing"
L["trait.einstoing.desc"] = "Vil helst ha deg for seg selv."
L["trait.einstoing.when"] = "uten noen gruppe"
L["trait.einstoing.flavor"] = "{pet} nøt å ha deg for seg selv!"
L["trait.huleboer.name"] = "Huleboer"
L["trait.huleboer.desc"] = "Føler seg hjemme i mørke ganger."
L["trait.huleboer.when"] = "i dungeons og raids"
L["trait.huleboer.flavor"] = "{pet} trives i mørket!"
L["trait.friluftsdyr.name"] = "Friluftsdyr"
L["trait.friluftsdyr.desc"] = "Elsker frisk luft."
L["trait.friluftsdyr.when"] = "ute i verden (ikke i dungeons)"
L["trait.friluftsdyr.flavor"] = "{pet} nøt den friske luften!"

------------------------------------------------------------------------------
-- What a trait does, in numbers (the numbers come from the code)
------------------------------------------------------------------------------
L["effect.day"] = "{when} gir {times} så mange bånd-poeng ({n} i stedet for {base})."
L["effect.times.2"] = "dobbelt"
L["effect.times.3"] = "tre ganger"
L["effect.when"] = "Alt dere gjør sammen {when}"
L["effect.activity"] = "{activity} med dyret ute"   -- {activity}: activity.*, capitalized
L["effect.liked"] = "{what} gir {n} bånd-poeng (opptil {cap} om dagen), mot {other} ellers."
L["effect.activity.dance"] = "/dance med dyret ute"
L["effect.activity.cuddle"] = "/pet, /hug eller /cuddle på dyret"
L["effect.activity.chat"] = "Hver linje du skriver i guildchatten"
L["effect.activity.dive"] = "Hver gang du dykker under vann med dyret ute"
L["effect.activity.level"] = "Hver gang du dinger med dyret ute"
L["effect.activity.revive"] = "Hver gang du står opp igjen etter å ha dødd"
L["effect.activity.nap"] = "/afk i en by eller et vertshus med dyret ute"
L["effect.activity.hearth"] = "Hearthstone, Astral Recall eller Teleport: Moonglade med dyret ute"
L["effect.activity.jump"] = "Hvert tiende hopp med dyret ute"
L["effect.activity.explore"] = "Hvert nytt sted dyret ser sammen med deg"
L["personality.line"] = "{traits} · liker {likes}"

------------------------------------------------------------------------------
-- Quirks (Menagerie/Quirks.lua): no effect, only flavor, at most one line an
-- hour. dislike.<activity>.N: something it doesn't like happened (one of the
-- numbered lines is picked; add more freely, numbered without gaps).
-- egg.<id>.N: the easter eggs. {pet}: its nickname, else its species.
------------------------------------------------------------------------------
L["dislike.found"] = "Nå vet du det: {pet} liker ikke {what}."
L["dislike.dive.1"] = "{pet} rister vannet av seg og ser fornærmet på deg."
L["dislike.dive.2"] = "{pet} nekter å se på deg etter den dukkerten."
L["dislike.dive.3"] = "{pet} er klissvåt og ikke det minste fornøyd."
L["dislike.pvp.1"] = "{pet} gjemte seg under kappen din til slåsskampen var over."
L["dislike.pvp.2"] = "{pet} synes slåssing er tull."
L["dislike.chat.1"] = "{pet} legger potene over ørene. Så mye prat!"
L["dislike.chat.2"] = "{pet} sukker tungt over guildpraten."
L["dislike.taxi.1"] = "{pet} holdt øynene igjen hele flyturen."
L["dislike.taxi.2"] = "{pet} er grønn i fjeset etter flyturen."
L["dislike.boss.1"] = "{pet} gjemte seg bak beina dine til bossen falt."
L["dislike.boss.2"] = "{pet} skjelver fortsatt litt etter den bossen."
L["dislike.jump.1"] = "{pet} blir svimmel av alt hoppingen."
L["dislike.jump.2"] = "{pet} ser på deg som om du har gått fra vettet."
L["dislike.hearth.1"] = "{pet} ble kvalm av hearthstonen."
L["dislike.hearth.2"] = "{pet} var ikke ferdig der dere var!"
L["dislike.nap.1"] = "{pet} tripper utålmodig. Skal dere ikke gjøre noe?"
L["dislike.cuddle.1"] = "{pet} tåler kos, men bare så vidt."
L["dislike.cuddle.2"] = "{pet} later som ingenting skjedde."

L["egg.mai17.1"] = "{pet} har fått sløyfe i rødt, hvitt og blått. Hipp hurra!"
L["egg.jul.1"] = "{pet} snuser nysgjerrig på gavene. God jul!"
L["egg.nyttar.1"] = "{pet} gjemmer seg allerede for rakettene."
L["egg.april.1"] = "{pet} later som den er et helt annet dyr i dag."
L["egg.halloween.1"] = "{pet} har kledd seg ut som et spøkelse. Bø!"
L["egg.fredag13.1"] = "{pet} går i en stor bue rundt alle svarte katter i dag."
L["egg.dager.1"] = "{pet} og du har bodd sammen i {n} dager!"
L["egg.midnatt.1"] = "{pet} gjesper. Det er midnatt, vet du."
L["egg.midnatt.2"] = "{pet} lurer på om du aldri skal legge deg."
L["egg.speil.1"] = "{pet} stirrer på {owner} sitt dyr. Er det et speil?"
L["egg.speil.2"] = "{pet} har møtt en av sitt eget slag, hos {owner}!"
L["egg.kattefisk.1"] = "{pet} har allerede spist halve fangsten."
L["egg.vinger.1"] = "{pet} mener den kunne fløyet dit raskere selv."
L["egg.trofe.1"] = "{pet} tok med seg en liten bit av {boss} som minne."
L["egg.dodsfall.1"] = "{pet} lurer på om det er trygt å bo hos deg."
L["egg.kake.1"] = "{pet} har bakt kake til nivå {level}!"
L["egg.oppdrag.1"] = "{pet} har hjulpet deg med {n} quests. Det fortjener en godbit!"

------------------------------------------------------------------------------
-- The pet journal: list tooltips and the world tooltip
------------------------------------------------------------------------------
L["tip.free"] = "Dyreparken: trenger et hjem"
L["list.nick"] = "«{nick}»"                               -- after the species' name in the list
L["tip.nick"] = "Kallenavn: «{nick}»"
L["tip.named_by"] = "Navngitt av {who}, {date}"           -- {who}: a name, or home.you
L["tip.bond"] = "Bånd: {label}"                           -- {label}: bond.label
L["tip.world"] = "Dyreparken: {home} · {level}"           -- {home} starts with a small letter here

------------------------------------------------------------------------------
-- The pet card
------------------------------------------------------------------------------
L["card.free"] = "Trenger et hjem"
L["card.likes"] = "Liker {list}"
L["card.likes.tip"] = "Liker: {list}"
L["card.adopt"] = "Adopter"
L["card.letgo"] = "Gi slipp"
L["card.nick"] = "Kallenavn"
L["card.nick.locked"] = "Du kan gi det et kallenavn når båndet deres er {level} (nivå {n})."
L["personality.unknown"] = "Ukjent personlighet"            -- not collected, and nobody in the guild has adopted it
L["personality.unknown.tip"] = "Personligheten er en overraskelse. Den blir kjent når du samler dyret, eller når noen i guilden adopterer det."
L["card.dislikes"] = "liker ikke {list}"                 -- after card.likes, or alone; only those seen happen
L["card.dislikes.tip"] = "Liker ikke: {list}"
L["card.personality.hint"] = "Gjør det den liker mens den er ute med deg, så vokser båndet raskere."
L["card.guild"] = "Guilden"
L["card.guild.value"] = "{n} av {total} ({pct}%)"
L["card.guild.tip"] = "Guilden: {n} av {total} dyr har et hjem ({pct}%)."
L["card.today"] = "Dagens dyr"
L["card.today.tip"] = "Dagens dyr: {pet}, som bor hos {owner}."
L["card.today.click"] = "Klikk for å se det."
L["card.today.none"] = "Dagens dyr: ingen har adoptert et dyr ennå."
L["card.out.on"] = "Med deg"                                 -- the badge on the card: this pet is the one kept out
L["card.out.off"] = "Ta med ut"                             -- ... and when it isn't
L["card.out.on.title"] = "{pet} er med deg"
L["card.out.off.title"] = "Ta med {pet} ut"
L["card.out.on.click"] = "Klikk for å slutte å summone automatisk."
L["card.out.off.click"] = "Klikk for å ta {pet} med ut."
L["card.auto.tip"] = "Summoner {pet} når det er fraværende og du ikke er opptatt. Kun ett dyr kan holdes ute om gangen; det du adopterer blir automatisk valgt."
L["card.auto.now"] = "Nå holdes {pet} ute."
L["card.auto.deferred"] = "AutoCompanion er lastet og tar seg av summoning."
L["card.nick.popup"] = "Kallenavn på dyret ditt (maks {n} tegn, tomt fjerner det):"

------------------------------------------------------------------------------
-- The bond on the card: tooltips, the stars, the celebration (BondTrack)
------------------------------------------------------------------------------
L["bond.tip.title"] = "Bånd: {level} (nivå {n})"
L["bond.tip.to_next"] = "{n} poeng til {level}."
L["bond.tip.next_decor"] = "På nivå {n} får kortet {decor}."
L["bond.tip.top"] = "Det høyeste nivået."
L["bond.tip.whose"] = "{owner} sitt bånd med dyret."
L["bond.tip.others"] = "Også glad i det: {list}"
L["bond.tip.how_other"] = "Ditt bånd med et dyr du ikke har adoptert vokser halvparten så fort. Adopter det for å gi det full oppmerksomhet."
L["bond.theirs"] = "{owner} sitt bånd"
L["bond.tip.how"] = "Vokser for hver dag dyret er ute med deg, og raskere når dere gjør noe det liker. Båndet svekkes aldri."
L["bond.star.title"] = "Nivå {n}: {level}"
L["bond.star.first"] = "Der alle starter."
L["bond.star.from"] = "Fra {n} poeng."
L["bond.star.decor"] = "Kortet får {decor}."
L["bond.star.reached"] = "Nådd!"
L["bond.star.nick"] = "Du kan gi dyret ditt et kallenavn."
L["bond.next"] = "{n} poeng til {level}"
L["bond.bar"] = "{have} / {need}"
L["bond.bar.today"] = "{have} / {need}  (+{today})"   -- your own pet: today's points too
L["bond.bar.top"] = "{have}"
L["bond.bar.top_today"] = "{have}  (+{today})"
L["bond.full.line"] = "{icon} Fullt for i dag"
L["bond.tip.today"] = "I dag: +{n} av {max} mulige poeng."
L["bond.tip.today_full"] = "I dag: fullt ({max} av {max}). Kom tilbake i morgen!"
L["bond.top"] = "Det høyeste nivået"
L["bond.celebrate.title"] = "{level}!"
L["bond.celebrate.text"] = "{pet} og du er nå på nivå {n}."
L["bond.celebrate.decor"] = "Ny pynt: {decor}."
-- What the card gets at each level (also in the tooltips above).
L["decor.level.2"] = "en kant og et hint av familiens farge"
L["decor.level.3"] = "sølvkant og sølvhjørner"
L["decor.level.4"] = "en glød under dyret"
L["decor.level.5"] = "gull overalt, og gnister som flyr"
L["decor.level.6"] = "et bånd med navnet på nivået, og lysstråler"
L["decor.level.7"] = "hjerter, og alt gull skinner"

------------------------------------------------------------------------------
-- What you've done together (the chips at the top of the card)
------------------------------------------------------------------------------
L["stats.days"] = "{n} dager ute sammen med {pet}"
L["stats.tip"] = "{n} {what} sammen med {pet}"

------------------------------------------------------------------------------
-- Today's wish (your own pet)
------------------------------------------------------------------------------
L["wish.line"] = "{pet} ønsker seg {activity} i dag"
L["wish.done"] = "Ønsket er oppfylt!"
L["wish.title"] = "Dagens ønske"
L["wish.tip"] = "Gjør det med {pet} ute i dag, så får dere {n} ekstra bånd-poeng."
L["wish.tip.done"] = "Oppfylt! {pet} er fornøyd. Et nytt ønske kommer i morgen."
L["wish.granted"] = "{pet} fikk ønsket sitt oppfylt: {activity}! (+{n} bånd-poeng)"

------------------------------------------------------------------------------
-- The park (the map page)
------------------------------------------------------------------------------
L["park.title"] = "Parken"
L["park.counter"] = "Har et hjem"
L["park.empty"] = "Ingen har adoptert et dyr ennå. Bli den første!"
L["park.oldest"] = "|cffffd100Lengste vennskap:|r {pet} og {owner} ({time})"
L["park.family"] = "|cffffd100Mest populære familie:|r {family} ({n} har et hjem)"
L["park.newest"] = "|cffffd100Nyeste beboer:|r {pet} hos {owner} ({time})"
L["park.free"] = "Trenger et hjem"
L["park.also_yours"] = "Du har også dette dyret."
L["park.can_adopt"] = "Du har dette dyret, og kan adoptere det."
L["park.click"] = "Klikk for å se kortet."
L["park.click.pets"] = "Åpne Pets-fanen, så kan du klikke her for å se kortet."
L["park.legend"] = "I farger: har et hjem.  Grå: trenger et hjem.  {icon} Du kan adoptere det."

------------------------------------------------------------------------------
-- Achievements (moved here from Achievements/Texts.lua, 2026-11-08)
------------------------------------------------------------------------------
-- Every text players see for achievements, in one place so they're easy to
-- rename (decided 2026-11-06: Norwegian). Keyed by achievement id
-- (Defs.lua). Ids never change; everything here may.
--
--   name    shown in brackets: [Alle kattene]
--   desc    what it takes, shown on the page
--   flavor  the guild chat line when shared. Placeholders:
--             {player}    the earner ("Ola Nord")
--             {name}      the name in brackets ("[Alle kattene]")
--             {progress}  "12/12"
--             {guild}     the guild's name (guild achievements)
--             {pet}       your companion: its nickname, else its species ("Pepe")
--             {species}   your companion's species ("Panda Cub")
--             {nick}      its nickname ("Pepe")
--           A line whose placeholder has no value (no companion, no nickname)
--           falls back to `plain`, then to the generic "share" line below.
--
-- The generic lines use placeholders too ({player}, {n}...), as the comments show.
ns.AchTexts = {
    generic = {
        earned_one = "{player} fikk {name}!",                    -- Ola Nord fikk [Alle kattene]!
        earned_many = "{player} fikk {list} og {last}!",             -- Ola Nord fikk [A], [B] og [C]!
        share = "{player} fikk {name}!",               -- guild chat, when an achievement has no flavor
        share_hint = "Del det i guild-chatten med /dp prestasjoner del.",
        already = "Du har allerede {n} prestasjoner fra før. Se dem med /dp prestasjoner.",
        none_to_share = "Ingen nye prestasjoner å dele.",
        not_in_guild = "Du er ikke i en guild.",
        notify_on = "Andre med Dyreparken får beskjed når du får en prestasjon.",
        notify_off = "Andre med Dyreparken får ikke lenger beskjed om prestasjonene dine.",
        list_header = "Prestasjoner ({n} av {total}):",
        points = "{have}/{need} poeng",
        guild_earned = "{guild} fikk {list}!",                  -- Dyreparken fikk [Kattehuset]!
        guild_hint = "Som offiser kan du dele det i guild-chatten med /dp prestasjoner del.",

        -- Families in the plural, for "Mest populære familie" (Menagerie/ParkPage.lua).
        families = { cat = "katter", farm = "gårdsdyr", owl = "ugler", rabbit = "kaniner", snake = "slanger",
            frog = "frosker og padder", mechanical = "mekaniske dyr", dragon = "drager", bird = "fugler",
            pirate = "piratdyr", bug = "insekter", rodent = "gnagere", wolf = "ulver", plant = "planter",
            festive = "høytidsdyr", demon = "demoner", ooze = "slimdyr", spirit = "ånder" },

        -- The page in the Collections window (Page.lua)
        page_title = "Prestasjoner",
        page_count = "Fullført",
        cat_collection = "Samlingen",
        cat_family = "Familier",
        cat_loyalty = "Lojalitet",
        cat_guild = "Guilden",
        share_button = "Del",
        share_button_tip = "Del det i guild-chatten.",
        tip_earned = "Fått {date}",
        tip_shared = "Delt i guild-chatten.",
        tip_missing = "Mangler:",
        tip_no_home = "trenger et hjem",
        tip_no_home_title = "Trenger et hjem:",
        tip_more = "... og {n} til",
    },

    -- Collection: pets you own that can be got in game (Data/Companions.lua).
    ["count:10"] = { name = "Ti små indianere", desc = "Ha 10 dyr.",
        flavor = "{player} har samlet ti dyr! {name}" },
    ["count:25"] = { name = "Dyrevenn", desc = "Ha 25 dyr.",
        flavor = "{player} har samlet 25 dyr! {name}" },
    ["count:50"] = { name = "Dyrepasser", desc = "Ha 50 dyr.",
        flavor = "{player} har samlet 50 dyr og trenger et større hus! {name}" },
    ["count:all"] = { name = "Noahs ark", desc = "Ha alle dyrene som finnes.",
        flavor = "{player} har samlet ALLE dyrene! To av hver? Nei, én av hver holder. {name}" },

    -- Families (our tags; see tools/companions/tags.csv).
    ["family:cat"] = { name = "Kattevræl", desc = "Ha alle kattene.",
        flavor = "{player} har gitt alle kattene et hjem! {name}" },
    ["family:farm"] = { name = "Kutoppen", desc = "Ha alle gårdsdyrene.",
        flavor = "{player} har fylt opp hele kutoppen! {name}" },
    ["family:owl"] = { name = "Ugleredet", desc = "Ha alle uglene.",
        flavor = "Hu-hu! {player} har samlet alle uglene. {name}" },
    ["family:rabbit"] = { name = "Kaninhagen", desc = "Ha alle kaninene.",
        flavor = "{player} har alle kaninene. De formerer seg nok snart. {name}" },
    ["family:snake"] = { name = "Slangegropa", desc = "Ha alle slangene.",
        flavor = "Ssss! {player} har samlet alle slangene. {name}" },
    ["family:frog"] = { name = "Froskedammen", desc = "Ha alle froskene og paddene.",
        flavor = "{player} har samlet alle froskene. Ingen prinser ennå. {name}" },
    ["family:mechanical"] = { name = "Tannhjul og skruer", desc = "Ha alle de mekaniske dyrene.",
        flavor = "{player} har samlet alle de mekaniske dyrene! {name}" },
    ["family:dragon"] = { name = "Dragehulen", desc = "Ha alle dragene.",
        flavor = "{player} har samlet alle dragene. Pass på gardinene! {name}" },
    ["family:bird"] = { name = "Fuglekassa", desc = "Ha alle fuglene.",
        flavor = "{player} har samlet alle fuglene! Ti på taket er bedre. {name}" },
    ["family:pirate"] = { name = "Kaptein Sabeltann", desc = "Ha alle piratdyrene.",
        flavor = "Det var en meget gledelig overraskelse, {player}, med alle piratdyrene om bord! {name}" },

    -- Loyalty: the companion you care for (per character).
    ["loyal:30"] = { name = "Bestevenner", desc = "Nå Venn med dyret ditt.",
        flavor = "{player} og {pet} er blitt ordentlige venner! {name}",
        plain = "{player} og dyret sitt er blitt ordentlige venner! {name}" },
    ["loyal:100"] = { name = "Uatskillelige", desc = "Nå God venn med dyret ditt.",
        flavor = "{player} og {pet} er nå gode venner! {name}",
        plain = "{player} og dyret sitt er nå gode venner! {name}" },
    ["loyal:365"] = { name = "Venner for livet", desc = "Nå Uatskillelig med dyret ditt.",
        flavor = "{player} og {pet} er uatskillelige! {name}",
        plain = "{player} og dyret sitt er uatskillelige! {name}" },
    ["nick"] = { name = "Døpt", desc = "Gi dyret ditt et kallenavn.",
        flavor = "{player} har døpt {species} til «{nick}»! {name}",
        plain = "{player} har gitt dyret sitt et navn! {name}" },

    -- Guild: the companions the guild cares for, all at once (one per member).
    ["guild:count:10"] = { name = "Dyreparken åpner", desc = "Guilden tar vare på 10 dyr samtidig.",
        flavor = "Portene er åpne: {guild} tar vare på ti dyr! {name}" },
    ["guild:count:25"] = { name = "Full drift", desc = "Guilden tar vare på 25 dyr samtidig.",
        flavor = "{guild} tar vare på 25 dyr! Dyreparken er i full drift. {name}" },
    ["guild:count:50"] = { name = "Nordens største dyrepark", desc = "Guilden tar vare på 50 dyr samtidig.",
        flavor = "{guild} tar vare på 50 dyr! {name}" },
    ["guild:all"] = { name = "Hele parken", desc = "Guilden tar vare på alle dyrene som finnes, samtidig.",
        flavor = "Hvert eneste dyr har et hjem i {guild}! {name}" },
    ["guild:family:cat"] = { name = "Kattehuset", desc = "Hver katt har sin egen eier i guilden.",
        flavor = "Hver eneste katt har fått sitt eget hjem i {guild}! {name}" },
}
