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
-- Time and home ("Har bodd hos Kari Berg i 3 dager")
------------------------------------------------------------------------------
L["time.today"] = "siden i dag"
L["time.yesterday"] = "siden i går"
L["time.days"] = "i {n} dager"
L["time.months"] = "i {n} måneder"
L["time.years"] = "i {n} år"
L["home.today"] = "Flyttet inn hos {who} i dag"
L["home.yesterday"] = "Flyttet inn hos {who} i går"
L["home.since"] = "Har bodd hos {who} {how}"          -- {how}: one of the time.* texts
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
L["cmd.help.prestasjoner"] = "prestasjoner [del|varsel på|av] - prestasjonene dine; del nye i guildchatten"
L["cmd.help.kunngjor"] = "kunngjør [på|av] - del adopsjoner og kallenavn i guildchatten (på som standard)"
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
L["nick.locked"] = "Du kan gi det et kallenavn når båndet deres er {level} (level {n})."
L["nick.same"] = "Det heter allerede «{nick}»."
L["nick.tomorrow"] = "{pet} har allerede fått nytt navn i dag. Du kan endre det igjen i morgen."
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
L["adopt.confirm.announce"] = "Adopsjonen blir kunngjort i guildchatten, så hele guilden får se den. (Slå av med /dp kunngjør.)"
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
L["card.cake.title"] = "Merkedag!"                 -- the cake on a pet's card on its milestone day

-- The pet's story (Menagerie/Story.lua): a book button on the card, a panel beside the window
L["story.title"] = "Historien om {pet}"
L["story.tip"] = "Det dette dyret har opplevd i guilden. {n} hendelser."
L["story.none"] = "Historien har ikke begynt ennå."
L["story.first"] = "Første hjem: flyttet inn hos {who}"
L["story.adopt"] = "Flyttet inn hos {who}"
L["story.letgo"] = "Flyttet fra {who} etter {days}"
L["story.days.0"] = "under en dag"
L["story.days.1"] = "én dag"
L["story.days"] = "{n} dager"
L["story.name"] = "Fikk navnet «{name}» av {who}"
L["story.unname"] = "Heter ikke «{name}» lenger"
L["story.level"] = "Ble {level} med {who} (level {n})"
L["story.milestone"] = "{time} hos {who}"
L["story.day"] = "Dagens dyr i guilden"
L["story.first.boss"] = "Første boss sammen med {who}: {what}"
L["story.first.place"] = "Første nye sted sammen med {who}: {what}"
L["story.first.play"] = "Første lekedate: med {owner} sin {friend}"
L["story.ach"] = "Var med da du fikk {name}"
L["story.egg"] = "«{line}»"
L["story.feat"] = "Milepæl sammen med {who}: {what}"
L["card.cake.click"] = "Klikk for å gratulere i guildchatten."
L["cake.congrats"] = "Gratulerer med {time} sammen, {owner} og {pet}!"
L["milestone.more"] = "... og {n} til."
L["nick.unlocked_rename"] = "Nå kan du gi {pet} et nytt kallenavn hvis du vil: /dp navn"
L["nick.unlocked"] = "Nå kan du gi {pet} et kallenavn: /dp navn"
L["pat.own"] = "klapper {pet}."                       -- an emote: "Ola klapper Pepe."
L["pat.other_nick"] = "klapper {nick} ({owner} sin {species})."
L["pat.other"] = "klapper {owner} sin {species}."
L["pat.combat"] = "Ikke nå, du er i kamp."
L["park.birthday"] = "Dyreparken fyller {n} år i dag! Takk for at dere tar vare på dyrene."
L["today.mine"] = "{pet} er dagens dyr i guilden! Det har fått en krone på kortet sitt."
L["pat.thanks"] = "{pet} ser fornøyd ut etter klappen fra {who}."
L["pat.nothing"] = "Summon dyret ditt, eller velg et dyr som mål."
-- The pet's answer to a pat, by family (2026-11-10; only you see it).
L["voice.cat"] = "{pet} maler: «mrrr ... mjau»."
L["voice.bird"] = "{pet} kvitrer fornøyd."
L["voice.owl"] = "{pet} sier «hu-hu»."
L["voice.farm"] = "{pet} sier «kakk-kakk»."
L["voice.rabbit"] = "{pet} rister fornøyd på ørene."
L["voice.frog"] = "{pet} sier «kvekk»."
L["voice.snake"] = "{pet} sier «sssss»."
L["voice.mechanical"] = "{pet} sier «bzzt-klikk»."
L["voice.dragon"] = "{pet} fnyser en liten røyksky."
L["voice.pirate"] = "{pet} sier «arrr»."
L["voice.bug"] = "{pet} surrer fornøyd."
L["voice.rodent"] = "{pet} sier «pip»."
L["voice.wolf"] = "{pet} sier «auuu»."
L["voice.plant"] = "{pet} rasler med bladene."
L["voice.festive"] = "{pet} klinger som en liten bjelle."
L["voice.demon"] = "{pet} fniser: «hehehe»."
L["voice.ooze"] = "{pet} sier «blubb»."
L["voice.spirit"] = "{pet} sier ingenting, men lyser litt sterkere."
L["voice.bear"] = "{pet} brummer fornøyd."
L["voice.reptile"] = "{pet} blunker sakte og fornøyd."
L["voice.murloc"] = "{pet} sier «mrglglglgl!»"
L["announce.adopt_nick"] = "Dyreparken: {player} adopterte {species} («{nick}»)!"
L["announce.adopt"] = "Dyreparken: {player} adopterte {species}!"
L["announce.name"] = "Dyreparken: {player} ga {species} kallenavnet «{nick}»!"
L["announce.on"] = "Adopsjoner og kallenavn kunngjøres i guildchatten."
L["announce.off"] = "Adopsjoner og kallenavn kunngjøres ikke lenger i guildchatten."

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
L["bond.label"] = "{level} (level {n})"                -- "Venn (level 3)"
L["bond.levelup"] = "|cffffd100Båndet ditt med {pet} er nå på level {n}: {level}!|r"
L["first.boss"] = "{pet} var med da {boss} falt!"          -- the first time this pet sees that boss fall
-- A place new to this pet, now and then (Bond:PlaceChance): one of these, or its family's own (first.place.<family>.N)
L["first.place.1"] = "{pet} snuser nysgjerrig rundt i {place}."
L["first.place.2"] = "{pet} har aldri vært i {place} før. Alt må utforskes!"
L["first.place.3"] = "{pet} ser seg storøyd rundt i {place}."
L["first.place.4"] = "{pet} merker seg {place}. Hit vil det gjerne komme tilbake til."
L["first.place.5"] = "{pet} stikker nesen i været. {place} lukter nytt!"
L["first.place.bird.1"] = "{pet} tar en runde i lufta over {place}."
L["first.place.bird.2"] = "{pet} har funnet en fin utsiktspost i {place}."
L["first.place.owl.1"] = "{pet} myser vurderende på {place}. Hm-hm."
L["first.place.cat.1"] = "{pet} later som {place} ikke er noe særlig, men halen sier noe annet."
L["first.place.dragon.1"] = "{pet} vurderer om det er plass til en skatt i {place}."
L["first.place.wolf.1"] = "{pet} setter nesa i bakken og sporer seg gjennom {place}."
L["first.place.rodent.1"] = "{pet} lurer på hvor mange gjemmesteder {place} har."
L["first.place.rabbit.1"] = "{pet} hopper høyt av glede over {place}."
L["first.place.frog.1"] = "{pet} kvekker fornøyd. {place} har sikkert en dam et sted."
L["first.place.pirate.1"] = "{pet} roper «Land i sikte!» om {place}."
L["first.place.spirit.1"] = "{pet} svever stille gjennom {place}, som om det har vært her før."
L["first.place.plant.1"] = "{pet} kjenner etter om jorda i {place} er god."
L["first.place.mechanical.1"] = "{pet} skanner {place}. Kartlegging fullført."
L["first.place.murloc.1"] = "{pet} gurgler begeistret: «Mrgl! {place}!»"
L["first.place.bear.1"] = "{pet} rusler gjennom {place} på jakt etter noe godt å spise."
L["play.line"] = "{pet} lekte med {friend} ({owner})!"   -- a playdate: our pet met a guildmate's in the group
L["play.inseparable"] = "{pet} og {friend} leker alltid sammen i parken nå."
L["play.best"] = "Beste lekevenn: {friend} ({owner}), {n} lekedater"
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
L["activity.hearth.flavor_home"] = "{pet} er glad for å være hjemme i {home}!"
L["activity.jump"] = "hopping"
L["activity.roll"] = "terningkast"
L["activity.fishfail"] = "fisker som slapp unna"
L["activity.hundred"] = "hundrere"
L["activity.epic"] = "episke funn"
L["activity.duelwon"] = "dueller vunnet"
L["activity.duellost"] = "dueller tapt"
L["activity.newpath"] = "nye flightpaths"
L["activity.campnear"] = "leirbål i nærheten"
L["activity.campwarm"] = "en plass ved bålet"
L["activity.camp"] = "bålkos"
L["activity.dmgtop"] = "mest skade på en boss"
L["activity.healtop"] = "mest healing på en raidboss"
L["activity.kicktop"] = "flest interrupts"
L["activity.gold"] = "ganger loota gull"
L["activity.gold.flavor"] = "{pet} teller gullet ditt. To ganger."
L["activity.fun"] = "tull og tøys"
L["activity.fun.flavor"] = "{pet} ler så det rister!"
L["activity.sneak"] = "snikeri"
L["activity.sneak.flavor"] = "{pet} sniker seg med deg, på tå hev."
L["activity.meet"] = "nye dyrevenner"
L["activity.meet.flavor"] = "{pet} har fått en ny venn!"
L["activity.camp.flavor"] = "{pet} koste seg ved bålet med deg."
L["activity.rested"] = "å sove i sovepose"
L["activity.feat"] = "milepæler"
L["activity.train"] = "besøk hos treneren"
L["activity.specswap"] = "bytte av spesialisering"
L["activity.respec"] = "nye talenter"
L["activity.rested.flavor"] = "{pet} sov godt i soveposen."
L["activity.jump.flavor"] = "{pet} hopper av glede!"
L["activity.explore"] = "nye steder"
L["activity.explore.flavor"] = "{pet} snuser på et nytt sted!"
L["activity.skill"] = "skill-ups"
L["activity.rep"] = "rep"

------------------------------------------------------------------------------
-- Holidays (the Festglad trait)
------------------------------------------------------------------------------
L["holiday.0101"] = "1. nyttårsdag"
L["holiday.0517"] = "17. mai"
L["holiday.0623"] = "St. Hans"
L["holiday.1224"] = "julaften"
L["holiday.1225"] = "1. juledag"
L["holiday.1231"] = "nyttårsaften"
-- The game's (Menagerie/Holidays.lua): by the names players know them by
L["holiday.game.lunar"] = "Lunar Festival"
L["holiday.game.love"] = "Love is in the Air"
L["holiday.game.noblegarden"] = "Noblegarden"
L["holiday.game.midsummer"] = "Midsummer Fire Festival"
L["holiday.game.harvest"] = "Harvest Festival"
L["holiday.game.hallowsend"] = "Hallow's End"
L["holiday.game.winterveil"] = "Feast of Winter Veil"

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
L["trait.nattugle.flavor"] = "{pet} elsker eventyr på nattestid!"
L["trait.festglad.name"] = "Festløve"
L["trait.festglad.desc"] = "Elsker 17. mai, St. Hans, jul og nyttår, og alle høytidene i Azeroth."
L["trait.festglad.day"] = "En høytidsdag sammen (17. mai, St. Hans, julaften, 1. juledag, nyttårsaften, 1. nyttårsdag, og spillets høytider: Lunar Festival, Love is in the Air, Noblegarden, Midsummer, Harvest Festival, Hallow's End, Winter Veil)"
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
L["trait.einstoing.flavor"] = "{pet} satte pris på å ha deg for seg selv!"
L["trait.huleboer.name"] = "Huleboer"
L["trait.huleboer.desc"] = "Føler seg hjemme i mørke ganger."
L["trait.huleboer.when"] = "i dungeons og raids"
L["trait.huleboer.flavor"] = "{pet} trives i mørket!"
L["trait.friluftsdyr.name"] = "Friluftsdyr"
L["trait.friluftsdyr.desc"] = "Elsker frisk luft."
L["trait.friluftsdyr.when"] = "ute i verden (ikke i dungeons)"
L["trait.friluftsdyr.flavor"] = "{pet} nøt den friske luften!"
-- 2026-11-12: from Dyreparken (Kaptein Sabeltann, Julius, Kardemomme by, Hakkebakkeskogen), Forever, and the gaps
L["trait.sjorover.name"] = "Sjørøver"
L["trait.sjorover.desc"] = "Drømmer om gull og skatter, som Kaptein Sabeltann."
L["trait.skoyer.name"] = "Skøyer"
L["trait.skoyer.desc"] = "Elsker tull og tøys, som Julius."
L["trait.roverdyr.name"] = "Røverdyr"
L["trait.roverdyr.desc"] = "Sniker seg rundt, som Kasper, Jesper og Jonatan."
L["trait.ordensdyr.name"] = "Ordensdyr"
L["trait.ordensdyr.desc"] = "Liker ro og orden, som Politimester Bastian."
L["trait.ordensdyr.when"] = "i en storby"
L["trait.ordensdyr.flavor"] = "{pet} liker at alt er i orden i byen!"
L["trait.venneflokk.name"] = "Venneflokk"
L["trait.venneflokk.desc"] = "Alle dyr skal være venner."
L["trait.vinterpels.name"] = "Vinterpels"
L["trait.vinterpels.desc"] = "Trives i snø og kulde."
L["trait.vinterpels.when"] = "der det er kaldt"
L["trait.vinterpels.flavor"] = "{pet} koser seg i kulda!"
L["trait.solelsker.name"] = "Charterdyr"
L["trait.solelsker.desc"] = "Elsker sol og varme, som finingene på Charterfeber."
L["trait.solelsker.when"] = "der det er varmt"
L["trait.solelsker.flavor"] = "{pet} soler seg i varmen!"
L["trait.tivolidyr.name"] = "Tivolidyr"
L["trait.tivolidyr.desc"] = "Elsker karuseller, lys og sukkerspinn."
L["trait.tivolidyr.day"] = "En dag med Darkmoon Faire"
L["trait.tivolidyr.dayflavor"] = "{pet} gleder seg til tivoli!"
L["trait.balkos.name"] = "Monsen"
L["trait.balkos.desc"] = "Ingenting slår en kveld ved bålet."
L["trait.skybaren.name"] = "Skybåren"
L["trait.skybaren.desc"] = "Hjemme høyt over bakken, blant skyene."
L["trait.skybaren.when"] = "høyt oppe (Zephras Isle, Hyjal, Thunder Bluff, Teldrassil)"
L["trait.skybaren.flavor"] = "{pet} nyter utsikten der oppe!"
L["trait.jeger.name"] = "Jeger"
L["trait.jeger.desc"] = "Har jaktinstinktet i blodet."
L["trait.handverker.name"] = "Håndverker"
L["trait.handverker.desc"] = "Elsker å se deg lære noe nytt."
L["trait.diplomat.name"] = "Diplomat"
L["trait.diplomat.desc"] = "Vil gjerne være venner med alle."

------------------------------------------------------------------------------
-- What a trait does, in numbers (the numbers come from the code)
------------------------------------------------------------------------------
L["effect.day"] = "{when} gir {times} så mange båndpoeng ({n} i stedet for {base})."
L["effect.times.2"] = "dobbelt"
L["effect.times.3"] = "tre ganger"
L["effect.when"] = "Alt dere gjør sammen {when}"
L["effect.activity"] = "{activity} med dyret ute"   -- {activity}: activity.*, capitalized
L["effect.liked"] = "{what} gir {n} båndpoeng (opptil {cap} om dagen), mot {other} ellers."
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
-- Minor likes and dislikes (Personality.lua: your bond unlocks them at levels 4 and 6; dimmed on the card)
L["unlock.like"] = "{pet} har åpnet seg mer for deg: det liker {what} også, litt."
L["unlock.dislike"] = "Det er noe nytt {pet} ikke liker. Hva kan det være?"
L["card.likes.minor_tip"] = "Liker også litt: {list}"
L["card.dislikes.minor_tip"] = "Liker heller ikke: {list}"
L["card.unlock.like"] = "Når båndet ditt blir {level}, lærer du mer om hva {pet} liker."
L["card.unlock.dislike"] = "Når båndet ditt blir {level}, lærer du mer om {pet}."
L["dislike.dive.1"] = "{pet} rister vannet av seg og ser fornærmet på deg."
L["dislike.dive.2"] = "{pet} nekter å se på deg etter den dukkerten."
L["dislike.dive.3"] = "{pet} er klissvåt og ikke det minste fornøyd."
L["dislike.pvp.1"] = "{pet} gjemte seg under kappen din til slåsskampen var over."
L["dislike.pvp.2"] = "{pet} synes slåssing er tull."
L["dislike.chat.1"] = "{pet} legger potene over ørene. Så mye prat!"
L["dislike.chat.2"] = "{pet} sukker tungt over guildpraten."
L["dislike.taxi.1"] = "{pet} holdt øynene igjen hele flyturen."
L["dislike.taxi.2"] = "{pet} er grønn i fjeset etter flyturen."
L["dislike.boss.1"] = "{pet} gjemte seg bak beina dine til bossen daua."
L["dislike.boss.2"] = "{pet} skjelver fortsatt litt etter den bossen."
L["dislike.jump.1"] = "{pet} blir svimmel av all hoppingen."
L["dislike.jump.2"] = "{pet} ser på deg som om du har gått fra vettet der du spretter rundt."
L["dislike.hearth.1"] = "{pet} ble kvalm av hearthstonen."
L["dislike.hearth.2"] = "{pet} var ikke ferdig der dere var!"
L["dislike.nap.1"] = "{pet} tripper utålmodig. Skal dere ikke gjøre noe annet enn å bare ligge her?"
L["dislike.cuddle.1"] = "{pet} tåler kos, men bare så vidt."
L["dislike.cuddle.2"] = "{pet} later som ingenting skjedde."
-- (2026-11-12: minor dislikes in Data/Unlocks.lua had none of these, so they could never be found; drafts)
L["dislike.camp.1"] = "{pet} holder seg et godt stykke unna bålet."
L["dislike.camp.2"] = "{pet} hoster av røyken og ser dømmende på deg."
L["dislike.dance.1"] = "{pet} ser flau ut over dansingen din."
L["dislike.dance.2"] = "{pet} later som det ikke kjenner deg mens du danser."
L["dislike.fish.1"] = "{pet} rynker på nesen av fiskelukta."
L["dislike.fish.2"] = "{pet} synes fisking er det kjedeligste som finnes."
L["dislike.mine.1"] = "{pet} hoster av steinstøvet."
L["dislike.mine.2"] = "{pet} holder for ørene mens du hakker løs på fjellet."
L["dislike.skin.1"] = "{pet} snur seg bort mens du flår."
L["dislike.skin.2"] = "{pet} synes flåing er ekkelt."
L["dislike.fun.1"] = "{pet} himler med øynene av tullet ditt."
L["dislike.fun.2"] = "{pet} synes ikke du er så morsom som du tror."

L["egg.mai17.1"] = "{pet} har fått sløyfe i rødt, hvitt og blått. Hipp hurra!"
L["egg.jul.1"] = "{pet} snuser nysgjerrig på gavene. God jul!"
L["egg.nyttar.1"] = "{pet} gjemmer seg allerede for rakettene."
L["egg.april.1"] = "{pet} later som den er et helt annet dyr i dag."
L["egg.halloween.1"] = "{pet} har kledd seg ut som et spøkelse. Bø!"
L["egg.lunar.1"] = "{pet} har tent en lykt for forfedrene. God Lunar Festival!"
L["egg.lunar.2"] = "{pet} ser opp på fyrverkeriet med store øyne."
L["egg.love.1"] = "{pet} har fått et rosa kort med hjerter på. Hvem kan det være fra?"
L["egg.love.2"] = "{pet} lukter mistenkelig mye parfyme i dag."
L["egg.noblegarden.1"] = "{pet} leter etter fargede egg i gresset."
L["egg.noblegarden.2"] = "{pet} har fått kaninører. Den er ikke sikker på om den liker det."
L["egg.midsummer.1"] = "{pet} holder seg på trygg avstand fra midtsommerbålet."
L["egg.midsummer.2"] = "{pet} danser rundt bålet med deg. Godt midtsommer!"
L["egg.harvest.1"] = "{pet} har funnet en kurv med epler. God Harvest Festival!"
L["egg.harvest.2"] = "{pet} sitter stille et øyeblikk og minnes heltene."
L["egg.hallowsend.1"] = "{pet} har fått en gresskarbøtte og vil gå på knask eller knep."
L["egg.hallowsend.2"] = "{pet} skvatt av en flaggermus. Det er Hallow's End!"
L["egg.winterveil.1"] = "{pet} rister i en pakke fra Greatfather Winter. Hva kan det være?"
L["egg.winterveil.2"] = "{pet} har fått en liten nisselue. God Winter Veil!"
L["egg.fredag13.1"] = "{pet} går i en stor bue rundt alle svarte katter i dag."
L["egg.dager.1"] = "{pet} og du har bodd sammen i {n} dager!"
L["egg.midnatt.1"] = "{pet} gjesper. Det er midnatt, vet du."
L["egg.midnatt.2"] = "{pet} lurer på om du aldri skal legge deg."
L["egg.speil.1"] = "{pet} stirrer på {owner} sitt dyr. Er det et speil?"
L["egg.speil.2"] = "{pet} har møtt en av sitt eget slag, hos {owner}!"
L["egg.paske.1"] = "{pet} har gjemt et påskeegg i bagen din. Kvikk Lunsj?"
L["egg.paske.2"] = "God påske! {pet} har lett etter påskeegg hele morgenen."
L["egg.klokka.1"] = "Klokka ble stilt i natt, og {pet} skjønner ikke når det er middag."
L["egg.mandag.1"] = "{pet} er sur. Det er mandag, og helgen er fem dager unna."
L["egg.morgen.1"] = "{pet} gnir søvnen ut av øynene. Så tidlig?"
L["egg.morgen.nattugle.1"] = "{pet} har ikke lagt seg ennå."
L["egg.hopp.1"] = "{pet} har hoppet hundre ganger med deg i dag og må hvile litt."
L["egg.hopp.hoppetass.1"] = "{pet} har hoppet hundre ganger med deg i dag, og vil ha mer!"
L["egg.lur.1"] = "{pet} lurer på om dere har tenkt å bli her for godt."
L["egg.midnattsdans.1"] = "Midnattsdans! {pet} visste ikke at du hadde det i deg."
L["egg.fredagstaco.1"] = "{pet} lukter taco. Det er fredag!"
L["egg.fredagstaco.2"] = "{pet} har allerede funnet frem lomper og rømme. Fredagstaco!"
L["egg.lordagsgodt.1"] = "{pet} har funnet lørdagsgodteriet ditt."
L["egg.lordagsgodt.2"] = "{pet} deler gjerne lørdagsgodtet. Eller, nesten."
L["egg.leet.1"] = "{pet} synes klokka er ekstremt kul akkurat nå. 13:37!"
L["egg.navnebror.1"] = "{pet} heter det samme som deg. Det blir rot ved middagsbordet."
L["egg.tvilling.1"] = "Nå finnes det to «{nick}» i parken!"
L["egg.fullfest.1"] = "Full fest: {n} dyr fra parken samlet!"
L["egg.fullfest.flokkdyr.1"] = "Full fest: {n} dyr fra parken samlet! {pet} er i sitt ess i flokken."
L["egg.hjemme.1"] = "{pet} føler seg hjemme i {zone}!"
L["egg.hjemme.pirate.1"] = "{pet} føler seg hjemme blant piratene i {zone}!"
L["egg.hjemme.frog.1"] = "{pet} kvekker fornøyd: {zone} er som hjemme."
L["egg.hjemme.owl.1"] = "{pet} tuter fornøyd. {zone} er et skikkelig uglested."
L["egg.hjemme.mechanical.1"] = "{pet} surrer begeistret. {zone} lukter olje og tannhjul."
L["egg.hjemme.dragon.1"] = "{pet} kjenner seg igjen i {zone}. Her har det bodd drager."
L["egg.kjenner.1"] = "{pet} kjenner igjen {owner}!"
L["egg.kjenner.2"] = "{pet} hilser ivrig på {owner}. Gamle venner glemmer ikke."
L["egg.fetter.1"] = "{pet} og {owner} sitt dyr snuser forsiktig på hverandre."
L["egg.fetter.2"] = "{pet} har truffet en fetter hos {owner}. Det er tydelig at de er i slekt."
L["egg.ener.1"] = "{pet} så terningen lande på 1 og prøver tappert å holde maska."
L["egg.ener.2"] = "{pet} ler så den hikster. En av hundre!"
L["egg.ener.3"] = "{pet} har aldri sett noen rulle så dårlig. Imponerende, egentlig."
L["egg.ener.4"] = "{pet} klapper deg trøstende. 1 er også et tall."
L["egg.fiskeflaks.1"] = "{pet} ser på deg, så på vannet, så på deg igjen."
L["egg.fiskeflaks.2"] = "{pet} lurer på om du har hørt om agn."
L["egg.fiskeflaks.3"] = "{pet} fniser. Fisken lo nok også."
L["egg.fiskeflaks.4"] = "{pet} tilbyr seg å hoppe uti og hente den neste selv."
L["egg.hundre.1"] = "{pet} måper. Hundre av hundre!"
L["egg.hundre.2"] = "{pet} lurer på om terningen din er jukset med."
L["egg.hundre.3"] = "{pet} hopper av glede. Den visste du hadde flaks i deg!"
L["egg.hundre.4"] = "{pet} vil gjerne at du ruller for dem neste gang."
L["egg.lilla.1"] = "{pet} stirrer på den lilla teksten med store øyne."
L["egg.lilla.2"] = "{pet} vil gjerne holde det episke itemet. Bare litt."
L["egg.lilla.3"] = "{pet} snuser på byttet. Det lukter episk."
L["egg.lilla.4"] = "{pet} har aldri sett noe så lilla før. Gratulerer!"
L["egg.duellvinner.1"] = "{pet} jubler! Du vant duellen mot {who}."
L["egg.duellvinner.2"] = "{pet} visste hele tiden at du ville slå {who}."
L["egg.duelltaper.1"] = "{pet} slikker sårene dine etter duellen mot {who}."
L["egg.duelltaper.2"] = "{pet} synes {who} jukset. Helt sikkert."
L["egg.nyrute.1"] = "{pet} er i ekstase: en ny flightpath! Når drar vi?"
L["egg.nyrute.2"] = "{pet} studerer det nye flykartet. Hvor skal dere først?"
L["egg.nyrute.redd.1"] = "{pet} skjelver ved tanken på enda en flightpath."
L["egg.nyrute.redd.2"] = "{pet} håper du ikke har tenkt å bruke den nye flightpathen med det første."
L["egg.fiskedag.1"] = "{pet} har hørt om fiskekonkurransen i Stranglethorn i dag og vil være med!"
L["egg.fiskedag.2"] = "{pet} drømmer om den største fisken i Stranglethorn. Det er konkurranse i dag!"
L["egg.baalnaer.1"] = "{pet} kikker lengselsfullt mot leirbålet. Skal vi ikke sette oss litt?"
L["egg.baalnaer.2"] = "{pet} lukter bålrøyk og blir helt myk i sjela."
L["egg.baalvarm.1"] = "{pet} krøller seg sammen ved bålet og varmer potene."
L["egg.baalvarm.2"] = "{pet} har funnet den beste plassen ved bålet."
L["egg.baalvarm.eventyr.1"] = "{pet} tripper rundt bålet. Skal vi sitte her lenge?"
L["egg.baalvarm.eventyr.2"] = "{pet} ser seg over skulderen. Eventyret venter ikke!"
L["egg.baal.1"] = "{pet} er helt rolig. Bålkos er det beste den vet."
L["egg.baal.2"] = "{pet} har sovnet halvveis i bålvarmen."
L["egg.baal.eventyr.1"] = "{pet} har sittet stille lenge nok. Kom igjen, eventyret venter!"
L["egg.baal.eventyr.2"] = "{pet} kjeder seg. Ingen bosser i nærheten av et leirbål."
L["egg.sovepose.1"] = "{pet} sov som en stein i soveposen."
L["egg.sovepose.2"] = "{pet} vil ikke ut av soveposen ennå. Fem minutter til!"
L["egg.sovepose.eventyr.1"] = "{pet} var oppe før soloppgang og vil videre."
L["egg.sovepose.eventyr.2"] = "{pet} pakket ned soveposen før du våknet."
L["egg.skravle.1"] = "{pet} lurer på om du har tenkt å puste snart. Så mye prat!"
L["egg.skravle.2"] = "{pet} har sovnet. Guildpraten din ble visst litt lang."
L["egg.skravle.3"] = "{pet} prøver å få et ord inn, men du snakker for fort."
L["egg.kattefisk.1"] = "{pet} har allerede spist halve fangsten."
L["egg.vinger.1"] = "{pet} mener den kunne fløyet dit raskere selv."
L["egg.trofe.1"] = "{pet} tok med seg en liten bit av {boss} som minne."
L["egg.dodsfall.1"] = "{pet} lurer på om det er trygt å bo hos deg."
-- The damage meter after a boss kill in a group (Menagerie/Meter.lua)
L["egg.toppen.1"] = "{pet} jubler: Du gjorde mest skade! Bossen hadde ingen sjanse."
L["egg.toppen.2"] = "{pet} har sett på måleren. Du var best. Selvfølgelig."
L["egg.toppen.3"] = "{pet} sparrer i lufta for å vise hvordan du gjorde så mye skade."
L["egg.toppen.4"] = "{pet} forteller alle i nærheten hvem som gjorde mest skade."
L["egg.helter.1"] = "{pet} er stolt: Ingen helte mer enn deg!"
L["egg.helter.2"] = "{pet} holdt pusten hele kampen, men du holdt alle i live."
L["egg.helter.3"] = "{pet} har bestemt at du er raidets beste healer. Ingen protester."
L["egg.sparket.1"] = "{pet} nikker anerkjennende. Ingen fikk caste noe i fred i dag."
L["egg.sparket.2"] = "{pet} prøver å interrupte deg også. For moro skyld."
-- A big fall (Activity "fall": most of your health at once, out of combat); by trait, else worried
L["egg.stup.1"] = "{pet} kommer løpende. Gikk det bra? Det så vondt ut."
L["egg.stup.2"] = "{pet} holder for øynene. Var det virkelig nødvendig å hoppe derfra?"
L["egg.stup.3"] = "{pet} snuser bekymret på deg etter fallet."
L["egg.stup.dod.1"] = "{pet} sitter ved siden av deg og venter. Det var visst litt for høyt."
L["egg.stup.hoppetass.1"] = "{pet} er imponert. Det hoppet skal det prøve selv en dag!"
L["egg.stup.skybaren.1"] = "{pet} rister på hodet. Du burde virkelig skaffe deg vinger."
L["egg.stup.rampete.1"] = "{pet} ler så det triller rundt. Det smalt godt!"
L["egg.stup.skoyer.1"] = "{pet} gir deg en ti-er for landingen. Fem for stilen."
L["egg.stup.eventyrlysten.1"] = "{pet} vil gjerne gjøre det en gang til!"
L["egg.stup.latsabb.1"] = "{pet} har alltid sagt at det er tryggest å holde seg på bakken."
L["egg.stup.hjemlengsel.1"] = "{pet} synes det er på tide å dra hjem nå."
L["egg.stup.kjaelen.1"] = "{pet} klemmer deg forsiktig der det gjør vondt."
L["egg.stup.kosete.1"] = "{pet} legger seg tett inntil deg til det slutter å gjøre vondt."
L["egg.stup.trofast.1"] = "{pet} forlater deg ikke et sekund etter det fallet."
L["activity.fall"] = "store fall"
-- (2026-11-13: drafts, for the user to edit) Back from AFK: the pet frame's pet wakes (egg "vaken").
L["activity.wake"] = "å våkne når du kommer tilbake"
L["egg.vaken.1"] = "{pet} gnir søvnen ut av øynene. Var du borte?"
L["egg.vaken.2"] = "{pet} gjesper og strekker seg. Så godt det var med en lur mens du var borte."
L["egg.vaken.trofast.1"] = "{pet} har ventet ved døra hele tiden. Endelig er du tilbake!"
L["egg.vaken.einstoing.1"] = "{pet} merket ikke engang at du var borte."
L["egg.vaken.latsabb.1"] = "{pet} synes du kom tilbake litt for tidlig. Det var akkurat blitt behagelig."
L["egg.vaken.hjemlengsel.1"] = "{pet} drømte om hjemme, og våkner glad for å se deg igjen."
-- Zeppelins and boats (Menagerie/Voyage.lua): by trait, then family, else plain
L["egg.luftskip.1"] = "{pet} kikker ut over rekkverket. Så smått alt ser ut herfra!"
L["egg.luftskip.2"] = "{pet} lurer på om zeppelinen har plass til en til i førerhuset."
L["egg.luftskip.redd.1"] = "{pet} har lukket øynene og klamrer seg til deg hele turen."
L["egg.luftskip.skybaren.1"] = "{pet} er endelig hjemme i lufta. Det vil aldri ned igjen."
L["egg.luftskip.reiseglad.1"] = "{pet} stråler. En luftskipstur er den beste måten å reise på!"
L["egg.luftskip.eventyrlysten.1"] = "{pet} speider etter nye eventyr fra baugen."
L["egg.luftskip.hjemlengsel.1"] = "{pet} ser seg tilbake mot havna. Når skal vi hjem?"
L["egg.luftskip.latsabb.1"] = "{pet} har funnet en solflekk på dekk og sovnet."
L["egg.luftskip.bird.1"] = "{pet} flyr ved siden av zeppelinen et stykke, bare for å vise at det kan."
L["egg.luftskip.owl.1"] = "{pet} myser skeptisk på ballongen. Den ser ikke ut som en ugle."
L["egg.luftskip.dragon.1"] = "{pet} synes zeppelinen er treg. Veldig treg."
L["egg.luftskip.mechanical.1"] = "{pet} lytter interessert til motoren. Brrrm."
L["egg.seilas.1"] = "{pet} kjenner saltvannet i nesa og ser på bølgene."
L["egg.seilas.2"] = "{pet} står i baugen og later som det styrer skuta."
L["egg.seilas.sjorover.1"] = "{pet} synger en sjørøversang for hele mannskapet. Yo-ho!"
L["egg.seilas.vannhund.1"] = "{pet} speider etter fisk over rekkverket."
L["egg.seilas.dykker.1"] = "{pet} vil hoppe i vannet og svømme resten av veien."
L["egg.seilas.hjemlengsel.1"] = "{pet} ser lengselsfullt mot land som forsvinner bak dere."
L["egg.seilas.eventyrlysten.1"] = "{pet} stirrer mot horisonten. Hvem vet hva som venter der?"
L["egg.seilas.pirate.1"] = "{pet} er endelig til sjøs igjen. Land i sikte? Hvem bryr seg!"
L["egg.seilas.cat.1"] = "{pet} er grønn i fjeset og vil helst være på land."
L["egg.seilas.frog.1"] = "{pet} vurderer å hoppe over bord. Vannet ser så deilig ut."
L["egg.seilas.murloc.1"] = "{pet} gurgler hjemlengselsfullt til havet. Mrgl..."
L["egg.seilas.reptile.1"] = "{pet} soler seg på dekk og ser etter krokodiller i vannet."
L["egg.seilas.bird.1"] = "{pet} sitter på masta og holder utkikk."
L["activity.zeppelin"] = "zeppelinerturer"
L["activity.boat"] = "båtturer"
-- Drafts of 2026-11-13, for the user to edit: Hakkebakkeloven (a playdate between a hunter and its
-- prey), Bastians runde (22:00 on the clock), Gjensynsglede (back after days apart).
L["egg.hakkebakke.1"] = "{pet} ser lenge på {friend}, men husker Hakkebakkeloven og holder litt igjen."
L["egg.hakkebakke.2"] = "{pet} lover {friend} at det bare er lek. Helt ærlig."
L["egg.hakkebakke.bytte.1"] = "{pet} holder et øye med {friend}, men alle dyrene i skogen skal jo være venner."
L["egg.hakkebakke.bytte.2"] = "{pet} leker med {friend}, men med litt avstand. Sånn for sikkerhets skyld."
L["egg.hakkebakke.venneflokk.1"] = "{pet} stråler mot {friend}: Alle dyrene i skogen skal være venner!"
L["egg.hakkebakke.roverdyr.1"] = "{pet} slikker seg rundt munnen når {friend} kommer. Bare en gammel vane, sier det."
L["egg.bastian.1"] = "{pet} går en runde rundt deg og melder: Klokken er ti, og alt er vel i Kardemomme by!"
L["egg.bastian.2"] = "{pet} retter på luen. Klokken er ti, og alt er vel. Nesten alt, i alle fall."
L["egg.bastian.roverdyr.1"] = "{pet} kikker seg over skulderen. Klokken er ti: nå er Kasper, Jesper og Jonatan ute og går!"
L["egg.bastian.roverdyr.2"] = "{pet} lister seg på tå. Klokken er ti, og politimesteren har gått sin runde."
L["egg.gjensyn.1"] = "{pet} kommer løpende! {n} dager er lenge å være borte."
L["egg.gjensyn.2"] = "{pet} snuser grundig på deg. Hvor har du vært i {n} dager?"
L["egg.gjensyn.hjemlengsel.1"] = "{pet} er så glad for å se deg igjen at det ikke vet hvor det skal gjøre av seg!"
L["egg.gjensyn.trofast.1"] = "{pet} har ventet på deg hver eneste dag. Det visste at du ville komme tilbake."
L["egg.gjensyn.kjaelen.1"] = "{pet} vil ha kos. Masse kos. Det har mye å ta igjen."
L["egg.gjensyn.latsabb.1"] = "{pet} åpner det ene øyet. Å, var du borte?"
L["egg.kake.1"] = "{pet} har bakt kake til level {level}!"
L["egg.kake.2"] = "{pet} hopper rundt deg. Level {level}!"
L["egg.kake.3"] = "{pet} har pyntet seg til level {level}."
-- Feats (Menagerie/Feats.lua): riding, level 60; a trainer visit, a dual-spec switch, a talent reset
L["egg.ridning.1"] = "{pet} lurer på om det får sitte foran på salen."
L["egg.ridning.2"] = "{pet} ser skeptisk på det nye ridedyret ditt."
L["egg.ridning.3"] = "{pet} har allerede bestemt seg: det skal løpe om kapp med ridedyret."
L["egg.maks.1"] = "{pet} har laget en liten krone til deg. Level 60!"
L["egg.maks.2"] = "{pet} danser rundt deg. Det visste hele tiden at du skulle klare det."
L["egg.trener.1"] = "{pet} prøver å lære seg det samme som deg. Det går ikke så bra."
L["egg.trener.2"] = "{pet} hilser høflig på treneren din."
L["egg.trener.3"] = "{pet} gjesper mens treneren forklarer. Igjen."
L["egg.talentbytte.1"] = "{pet} myser på deg. Er du den samme som i stad?"
L["egg.talentbytte.2"] = "{pet} merker at noe ved deg forandret seg."
L["egg.glemsel.1"] = "{pet} ser forvirret på deg. Kjenner det deg fortsatt igjen?"
L["egg.glemsel.2"] = "{pet} snuser grundig på deg, som for å sjekke at du fortsatt er deg."
L["egg.glemsel.3"] = "{pet} lurer på hvorfor du betalte for å glemme alt du kunne."
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
-- The settings page (Menagerie/Settings.lua: a cog in the journal's title bar)
L["settings.title"] = "Innstillinger"
L["settings.char"] = "Gjelder bare denne karakteren."
L["settings.char.head"] = "(denne karakteren)"
L["settings.back"] = "Tilbake"
L["settings.head.pet"] = "Dyret ditt"
L["settings.head.guild"] = "Guilden"
L["settings.head.chat"] = "Chatten og verden"
L["settings.head.card"] = "Dyrekortet"
L["settings.autosummon"] = "Ta med dyret ut automatisk"
L["settings.autosummon.tip"] = "Summoner dyret du har valgt med «Med deg» når du er klar: etter lasteskjermer, kamp og når du går av fjellet ditt."
L["settings.mute"] = "Demp lyden når et dyr summones"
L["settings.mute.tip"] = "Lydeffekten når et dyr kommer ut, også når spillet summoner det tilbake selv."
L["settings.announce"] = "Fortell guilden når du adopterer eller gir navn"
L["settings.announce.tip"] = "En linje i guildchatten når du adopterer et dyr eller gir det kallenavn, og når du gratulerer fra en kake."
L["settings.achnotify"] = "Fortell andre med Dyreparken om prestasjonene dine"
L["settings.achnotify.tip"] = "Guildmedlemmer med Dyreparken får en linje når du får en prestasjon. Ingenting i guildchatten."
L["settings.chatlines"] = "Småting i chatten"
L["settings.chatlines.tip"] = "Linjene om påskeegg, ting dyret ikke liker, ting det elsker og første ganger sammen. Av: de skjer og teller like fullt, bare uten linje. Nye levels vises alltid."
L["settings.hearts"] = "Hjerter og gnister"
L["settings.hearts.tip"] = "Hjerter når du holder musen over et kjæledyr i verden, og gnister ved chatten."
L["settings.particles"] = "Partikler på kortet:"
L["settings.particles.tip"] = "Blader, bobler, stjerner og alt det andre som svever rundt dyret."
L["settings.particles.all"] = "Alle"
L["settings.particles.few"] = "Færre"
L["settings.particles.none"] = "Ingen"
L["settings.moves"] = "Dyret beveger seg på kortet"
L["settings.moves.tip"] = "Det sover om natten, setter seg, hopper når du klikker, går og løper med deg."
L["settings.celebrate"] = "Feiring på kortet ved nytt level"
L["settings.head.frame"] = "Dyret på skjermen"
L["settings.petframe"] = "Vis dyret ditt på skjermen"
L["settings.petframe.tip"] = "Dyret du har ute, med navnet og båndet deres, på skjermen. Det beveger seg som på kortet. Flytt det og endre størrelsen i Edit Mode; et klikk åpner dyrekortet."
L["settings.petframeart"] = "Bakgrunn og ramme rundt dyret"
L["settings.petframecombat"] = "Skjul dyret i kamp"
L["settings.petframecombat.tip"] = "Dyret forsvinner fra skjermen når du går i kamp, og kommer tilbake etterpå."
L["settings.petframefade"] = "Ton ned dyret når ingenting skjer"
L["settings.petframefade.tip"] = "Dyret er svakt på skjermen, og blir helt synlig når du holder musen over det, når båndet ditt vokser eller når det får et nytt level."
L["settings.petframealpha"] = "Synlighet når det er tonet ned"
L["settings.petframealpha.tip"] = "Hvor synlig dyret er når ingenting skjer."
L["settings.petframeart.tip"] = "Steinbakgrunn og ramme som på vinduene i spillet. Av: dyret svever fritt på skjermen."
L["petframe.tip"] = "Klikk for å åpne dyrekortet."
-- (2026-11-13: a draft, for the user to edit) A click on the pet frame with the Pets page closed.
L["petframe.open_hint"] = "Åpne kjæledyrsamlingen, så viser jeg kortet til {pet}."
-- (2026-11-13: drafts) The window opened (or was open) on another page; a click in combat.
L["petframe.tab_hint"] = "Bytt til Pets-fanen, så viser jeg kortet til {pet}."
L["petframe.combat_hint"] = "Kortet til {pet} kommer når kampen er over."
L["petframe.name"] = "Dyreparken: dyret ditt"
L["petframe.edit"] = "Dyreparken: dyret ditt\nDra for å flytte, rull for størrelse ({pct}%)"
L["settings.celebrate.tip"] = "Lys, gnister og en lyd når båndet ditt med dyret når et nytt level."
L["card.nick"] = "Kallenavn"
L["card.nick.locked"] = "Du kan gi det et kallenavn når båndet deres er {level} (level {n})."
L["card.nick.clearable"] = "Navnet det har nå, kan du fjerne allerede: la feltet stå tomt."
L["personality.unknown"] = "Ukjent personlighet"            -- not collected, and nobody in the guild has adopted it
L["personality.unknown.tip"] = "Personligheten er en overraskelse. Den blir kjent når du samler dyret, eller når noen i guilden adopterer det."
L["card.dislikes"] = "liker ikke {list}"                 -- after card.likes, or alone; only those seen happen
L["card.dislikes.tip"] = "Liker ikke: {list}"
L["card.dislikes.secret_one"] = "Det er noe {pet} ikke liker. Hva kan det være?"
L["card.dislikes.secret"] = "Det er {n} ting {pet} ikke liker. Hva kan det være?"
L["card.personality.hint"] = "Gjør det den liker mens den er ute med deg, så vokser båndet raskere."
L["card.guild"] = "Guilden"
L["card.guild.value"] = "{n} av {total} ({pct}%)"
L["card.guild.tip"] = "Guilden: {n} av {total} dyr har et hjem ({pct}%)."
L["card.today"] = "Dagens dyr"
L["card.today.tip"] = "Dagens dyr: {pet}, som bor hos {owner}."
L["card.today.click"] = "Klikk for å se det."
L["card.today.none"] = "Dagens dyr: ingen har adoptert et dyr ennå."
L["card.crown.tip"] = "{pet} er dagens dyr i guilden."
L["card.notowned"] = "Ikke samlet"                   -- the paw badge's place, for a pet you don't own
L["card.notowned.tip"] = "Du har ikke {pet} i samlingen din. Det du ser her er dyret og hjemmet det har i guilden."
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
L["bond.tip.title"] = "Bånd: {level} (level {n})"
L["bond.tip.to_next"] = "{n} poeng til {level}."
L["bond.tip.next_decor"] = "På level {n} får kortet {decor}."
L["bond.tip.top"] = "Høyeste level."
L["bond.tip.whose"] = "{owner} sitt bånd med dyret."
L["bond.tip.others"] = "Også glad i det: {list}"
L["bond.tip.how_other"] = "Ditt bånd med et dyr du ikke har adoptert vokser halvparten så fort. Adopter det for å gi det full oppmerksomhet."
L["bond.theirs"] = "{owner} sitt bånd"
L["bond.yours"] = "{icon} Ditt: {level} ({n})"           -- under bond.theirs: your own bond with someone else's pet
L["bond.tip.yours"] = "Ditt eget bånd med dyret: {level} (level {n}), {p} poeng."
L["bond.tip.how"] = "Vokser for hver dag dyret er ute med deg, og raskere når dere gjør noe det liker. Båndet svekkes aldri."
L["bond.star.title"] = "Level {n}: {level}"
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
L["bond.full.line"] = "{icon} {goal}"                   -- the day full: the goal stays, with a check
L["bond.tip.today"] = "I dag: +{n} av {max} mulige poeng."
L["bond.tip.today_full"] = "I dag: fullt ({max} av {max}). Kom tilbake i morgen!"
L["bond.top"] = "Høyeste level"
L["bond.celebrate.title"] = "{level}!"
L["bond.celebrate.text"] = "{pet} og du er nå på level {n}."
L["bond.celebrate.decor"] = "Ny pynt: {decor}."
-- What the card gets at each level (also in the tooltips above).
L["decor.level.2"] = "en kant og et hint av farge"
L["decor.level.3"] = "sølvkant og sølvhjørner"
L["decor.level.4"] = "en glød under dyret"
L["decor.level.5"] = "gull overalt, og gnister som flyr"
L["decor.level.6"] = "et bånd med navnet på levelet, og lysstråler"
L["decor.level.7"] = "hjerter, og alt gull skinner"

------------------------------------------------------------------------------
-- What you've done together (the chips at the top of the card)
------------------------------------------------------------------------------
L["stats.days"] = "{n} dager ute sammen med {pet}"
L["stats.days_one"] = "1 dag ute sammen med {pet}"
L["stats.tip"] = "{n} {what} sammen med {pet}"
L["stats.last_place"] = "Sist oppdaget sammen: {place}"
L["stats.round"] = "Rundt tall i dag: {m}!"

------------------------------------------------------------------------------
-- Today's wish (your own pet)
------------------------------------------------------------------------------
L["wish.line"] = "{pet} ønsker seg {activity} i dag"
L["wish.done"] = "Ønsket er oppfylt!"
L["wish.title"] = "Dagens ønske"
L["wish.tip"] = "Gjør det med {pet} ute i dag, så får dere {n} ekstra båndpoeng."
L["wish.tip.done"] = "Oppfylt! {pet} er fornøyd. Et nytt ønske kommer i morgen."
L["wish.done.streak"] = "Ønsket er oppfylt! {n} dager på rad"
L["wish.streak.tip"] = "{n} oppfylte ønsker på rad."
L["wish.streak.keep"] = "Oppfyll det i dag, så blir det {n} dager på rad."
L["bond.contest"] = "{pet} jubler over at du fisket i fiskekonkurransen! (+{n} båndpoeng)"
L["bond.contest.full"] = "{pet} jubler over at du fisket i fiskekonkurransen!" -- (a full day: no points left to give)
-- Feats (Menagerie/Feats.lua): the line and the story's word, by how the feat reads
L["feat.spell"] = "{pet} var med da du lærte {what}! (+{n} båndpoeng)"
L["feat.quest"] = "{pet} var med da du fullførte «{what}»! (+{n} båndpoeng)"
L["feat.totem"] = "{pet} var med da du fikk {totem}! (+{n} båndpoeng)"
L["feat.riding"] = "{pet} var med da du lærte å ri! (+{n} båndpoeng)"
L["feat.level60"] = "Level 60! {pet} har vært med deg helt til toppen. (+{n} båndpoeng)"
L["feat.story.spell"] = "{what}"
L["feat.story.quest"] = "«{what}»"
L["feat.story.totem"] = "{totem}"
L["feat.story.riding"] = "lærte å ri"
L["feat.story.level60"] = "level 60"
L["feat.totem.earth"] = "jordtotemet"
L["feat.totem.fire"] = "ildtotemet"
L["feat.totem.water"] = "vanntotemet"
L["feat.totem.air"] = "lufttotemet"
L["wish.granted"] = "{pet} fikk ønsket sitt oppfylt: {activity}! (+{n} båndpoeng)"
L["wish.granted.full"] = "{pet} fikk ønsket sitt oppfylt: {activity}!" -- (a full day: no points left to give)
-- (2026-11-13: drafts, for the user to edit) A wish come true by itself (Wish:Auto): everything explored and
-- seen together, or every profession at its cap.
L["wish.auto.explore"] = "{pet} har sett hver krok av verden sammen med deg, og ønsker seg bare å være med deg i dag. Ønsket er oppfylt! (+{n} båndpoeng)"
L["wish.auto.explore.full"] = "{pet} har sett hver krok av verden sammen med deg, og ønsker seg bare å være med deg i dag. Ønsket er oppfylt!"
L["wish.auto.skill"] = "Du har lært alt trenerne kan lære deg nå, og {pet} er stolt av deg. Ønsket er oppfylt! (+{n} båndpoeng)"
L["wish.auto.skill.full"] = "Du har lært alt trenerne kan lære deg nå, og {pet} er stolt av deg. Ønsket er oppfylt!"

------------------------------------------------------------------------------
-- The park (the map page)
------------------------------------------------------------------------------
L["park.title"] = "Parken"
L["park.counter"] = "Har et hjem"
L["park.empty"] = "Ingen har adoptert et dyr ennå. Bli den første!"
L["park.oldest"] = "|cffffd100Lengste vennskap:|r {pet} hos {owner}, {time}"
L["park.family"] = "|cffffd100Mest populære familie:|r {family} ({n} har et hjem)"
L["park.newest"] = "|cffffd100Nyeste beboer:|r {pet}, {home}"           -- {home}: "flyttet inn hos Kari Berg i går"
L["park.free"] = "Trenger et hjem"
L["park.also_yours"] = "Du har også dette dyret."
L["park.can_adopt"] = "Du har dette dyret, og kan adoptere det."
L["park.click"] = "Klikk for å se kortet."
L["park.click.pets"] = "Åpne Pets-fanen, så kan du klikke her for å se kortet."
-- (2026-11-13: a draft) A click on an icon in combat.
L["park.combat_hint"] = "Kortet til {pet} kommer når kampen er over."
L["park.legend"] = "I farger: har et hjem.  Grå: trenger et hjem.  {icon} Du kan adoptere det."
-- The search and the filters (2026-11-14): what doesn't match is dimmed in place.
L["park.search"] = "Søk"
L["park.search.tip"] = "Søk etter navn, kallenavn, hvem det bor hos, familie eller hvor det fås."
L["park.matches"] = "{n} treff"
L["park.filter.free"] = "Trenger et hjem"
L["park.filter.free.tip"] = "Bare dyr ingen i guilden har adoptert."
L["park.filter.adopt"] = "Kan adopteres"
L["park.filter.adopt.tip"] = "Bare dyr du har selv og ingen har adoptert: dem kan du adoptere nå."
-- Where a pet comes from (Data/Companions.lua: s, w), in its tooltip. {where}: names from the game (NPC, quest,
-- item, zone), in English like the client's.
L["source.line"] = "Kilde: {how}"
L["source.line.where"] = "Kilde: {how} – {where}"
L["source.vendor"] = "Selger"
L["source.quest"] = "Oppdrag"
L["source.drop"] = "Drop"
L["source.crafted"] = "Håndverk"
L["source.event"] = "Høytid"
L["source.promo"] = "Kampanje"
L["source.other"] = "Annet"
L["source.unknown"] = "Ukjent"
-- Where, for the sources the data has only in English prose (by species id).
L["source.where.5005"] = "Zephras Isle: /sing til en frosk, og snakk med frosken som dukker opp"
L["source.where.5122"] = "Legacy Track: 25 Legacy Points"
L["source.where.5138"] = "Blizzard-butikken: Skyborne Epic Pack eller Warcraft Forever Collection"
L["source.where.5159"] = "Blizzard-butikken: Skyborne Epic Pack eller Warcraft Forever Collection"
L["source.where.5160"] = "Blizzard-butikken: Skyborne Epic Pack eller Warcraft Forever Collection"
L["source.where.5161"] = "Blizzard-butikken: Skyborne Epic Pack eller Warcraft Forever Collection"
L["source.where.5179"] = "belønning for 12 måneders abonnement"

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
        share_hint = "Del det i guildchatten med /dp prestasjoner del.",
        already = "Du har allerede {n} prestasjoner fra før. Se dem med /dp prestasjoner.",
        none_to_share = "Ingen nye prestasjoner å dele.",
        not_in_guild = "Du er ikke i en guild.",
        notify_on = "Andre med Dyreparken får beskjed når du får en prestasjon.",
        notify_off = "Andre med Dyreparken får ikke lenger beskjed om prestasjonene dine.",
        list_header = "Prestasjoner ({n} av {total}):",
        points = "{have}/{need} poeng",
        guild_earned = "{guild} fikk {list}!",                  -- Dyreparken fikk [Kattehuset]!
        guild_hint = "Som offiser kan du dele det i guildchatten med /dp prestasjoner del.",

        -- Families in the plural, for "Mest populære familie" (Menagerie/ParkPage.lua).
        families = { cat = "katter", farm = "gårdsdyr", owl = "ugler", rabbit = "kaniner", snake = "slanger",
            frog = "frosker og padder", mechanical = "mekaniske dyr", dragon = "drager", bird = "fugler",
            pirate = "piratdyr", bug = "insekter", rodent = "gnagere", wolf = "ulver", plant = "planter",
            festive = "høytidsdyr", demon = "demoner", ooze = "slimdyr", spirit = "ånder", bear = "bjørner",
            reptile = "krypdyr", murloc = "murloker" },

        -- The page in the Collections window (Page.lua)
        page_title = "Prestasjoner",
        page_count = "Fullført",
        cat_collection = "Samlingen",
        cat_family = "Familier",
        cat_loyalty = "Lojalitet",
        cat_together = "Sammen på eventyr",
        cat_guild = "Guilden",
        share_button = "Del",
        share_button_tip = "Del det i guildchatten.",
        tip_earned = "Fått {date}",
        tip_shared = "Delt i guildchatten.",
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
    ["loyal:30"] = { name = "Venner i parken", desc = "Nå Venn med dyret ditt.",
        flavor = "{player} og {pet} er blitt ordentlige venner! {name}",
        plain = "{player} og dyret sitt er blitt ordentlige venner! {name}" },
    ["loyal:100"] = { name = "Gode kamerater", desc = "Nå God venn med dyret ditt.",
        flavor = "{player} og {pet} er nå gode venner! {name}",
        plain = "{player} og dyret sitt er nå gode venner! {name}" },
    ["loyal:365"] = { name = "Venner for livet", desc = "Nå Uatskillelig med dyret ditt.",
        flavor = "{player} og {pet} er uatskillelige! {name}",
        plain = "{player} og dyret sitt er uatskillelige! {name}" },
    ["nick"] = { name = "Døpt", desc = "Gi dyret ditt et kallenavn.",
        flavor = "{player} har døpt {species} til «{nick}»! {name}",
        plain = "{player} har gitt dyret sitt et navn! {name}" },
    -- Together: what you've done with your adopted pet out (2026-11-10, numbers and names from the user).
    ["boss:50"] = { name = "Bosskamerat", desc = "Drep 50 bosser med dyret ditt ute.",
        flavor = "{player} og {pet} har felt 50 bosser sammen! {name}", plain = "{player} og dyret sitt har felt 50 bosser sammen! {name}" },
    ["boss:250"] = { name = "Skrekk for bossene", desc = "Drep 250 bosser med dyret ditt ute.",
        flavor = "{player} og {pet} har felt 250 bosser sammen! {name}", plain = "{player} og dyret sitt har felt 250 bosser sammen! {name}" },
    ["boss:1000"] = { name = "Bossjeger", desc = "Drep 1000 bosser med dyret ditt ute.",
        flavor = "{player} og {pet} har felt 1000 bosser sammen! {name}", plain = "{player} og dyret sitt har felt 1000 bosser sammen! {name}" },
    ["pvp:50"] = { name = "Kampklar", desc = "Få 50 honorable kills med dyret ditt ute.",
        flavor = "{player} og {pet} har tatt 50 honorable kills sammen! {name}", plain = "{player} og dyret sitt har tatt 50 honorable kills sammen! {name}" },
    ["pvp:250"] = { name = "Slagmarkens skrekk", desc = "Få 250 honorable kills med dyret ditt ute.",
        flavor = "{player} og {pet} har tatt 250 honorable kills sammen! {name}", plain = "{player} og dyret sitt har tatt 250 honorable kills sammen! {name}" },
    ["pvp:1000"] = { name = "Krigsherre", desc = "Få 1000 honorable kills med dyret ditt ute.",
        flavor = "{player} og {pet} har tatt 1000 honorable kills sammen! {name}", plain = "{player} og dyret sitt har tatt 1000 honorable kills sammen! {name}" },
    ["quest:100"] = { name = "Hjelpsomme sjeler", desc = "Fullfør 100 quests med dyret ditt ute.",
        flavor = "{player} og {pet} har fullført 100 quests sammen! {name}", plain = "{player} og dyret sitt har fullført 100 quests sammen! {name}" },
    ["quest:500"] = { name = "Alltid til tjeneste", desc = "Fullfør 500 quests med dyret ditt ute.",
        flavor = "{player} og {pet} har fullført 500 quests sammen! {name}", plain = "{player} og dyret sitt har fullført 500 quests sammen! {name}" },
    ["quest:1000"] = { name = "Hele Azeroths hjelpere", desc = "Fullfør 1000 quests med dyret ditt ute.",
        flavor = "{player} og {pet} har fullført 1000 quests sammen! {name}", plain = "{player} og dyret sitt har fullført 1000 quests sammen! {name}" },
    ["eggs:10"] = { name = "Påskeegghøne", desc = "Trigge 10 hemmelige interaksjoner med dyrene dine.",
        flavor = "{player} har funnet 10 forskjellige hemmelige interaksjoner med dyrene sine! {name}" },
    ["eggs:25"] = { name = "Eggspert", desc = "Finn 25 forskjellige hemmelige interaksjoner med dyrene dine.",
        flavor = "{player} har funnet 25 forskjellige interaksjoner! Ingen hemmelighet er trygg. {name}" },
    -- Wishes come true (2026-11-11): days in a row, and in all.
    ["wish:7"] = { name = "Ønskeuke", desc = "Oppfyll dagens ønske 7 dager på rad.",
        flavor = "{player} har oppfylt dyrets ønske 7 dager på rad! {name}" },
    ["wish:30"] = { name = "Ønskemåned", desc = "Oppfyll dagens ønske 30 dager på rad.",
        flavor = "{player} har oppfylt dyrets ønske 30 dager på rad! {name}" },
    ["wish:100"] = { name = "Ønskebrønnen", desc = "Oppfyll 100 ønsker.",
        flavor = "{player} har oppfylt 100 ønsker! {name}" },
    ["dislikes"] = { name = "Kjenner deg ut og inn", desc = "Finn ut alt dyret ditt liker og ikke liker, også det du lærer når båndet blir sterkere.",
        flavor = "{player} vet nå alt om hva {pet} liker og ikke liker! {name}",
        plain = "{player} kjenner dyret sitt ut og inn! {name}" },

    -- Guild: the companions the guild cares for, all at once (one per member).
    ["guild:count:10"] = { name = "Dyreparken åpner", desc = "Guilden tar vare på 10 dyr samtidig (av dem som kan skaffes i spillet).",
        flavor = "Portene er åpne: {guild} tar vare på ti dyr! {name}" },
    ["guild:count:25"] = { name = "Full drift", desc = "Guilden tar vare på 25 dyr samtidig (av dem som kan skaffes i spillet).",
        flavor = "{guild} tar vare på 25 dyr! Dyreparken er i full drift. {name}" },
    ["guild:count:50"] = { name = "Nordens største dyrepark", desc = "Guilden tar vare på 50 dyr samtidig (av dem som kan skaffes i spillet).",
        flavor = "{guild} tar vare på 50 dyr! {name}" },
    ["guild:all"] = { name = "Hele parken", desc = "Guilden tar vare på alle dyrene som kan skaffes i spillet, samtidig.",
        flavor = "Hvert eneste dyr har et hjem i {guild}! {name}" },
    ["guild:family:cat"] = { name = "Kattehuset", desc = "Hver katt blir tatt vare på i guilden.",
        flavor = "Hver eneste katt har fått sitt eget hjem i {guild}! {name}" },
    ["guild:family:farm"] = { name = "KuToppen", desc = "Hvert gårdsdyr blir tatt vare på i guilden.",
        flavor = "Hvert eneste gårdsdyr har fått sitt eget hjem i {guild}! Kua er fornøyd. {name}" },
    ["guild:family:owl"] = { name = "Ugleparlamentet", desc = "Hver ugle blir tatt vare på i guilden.",
        flavor = "Hver eneste ugle har fått sitt eget hjem i {guild}! Parlamentet er satt. {name}" },
    ["guild:family:rabbit"] = { name = "Kaninøya", desc = "Hver kanin blir tatt vare på i guilden.",
        flavor = "Hver eneste kanin har fått sitt eget hjem i {guild}! (Tell dem igjen i morgen.) {name}" },
    ["guild:family:snake"] = { name = "Terrariet", desc = "Hver slange blir tatt vare på i guilden.",
        flavor = "Hver eneste slange har fått sitt eget hjem i {guild}! Sssss. {name}" },
    ["guild:family:frog"] = { name = "Kvekkekoret", desc = "Hver frosk og padde blir tatt vare på i guilden.",
        flavor = "Hver eneste frosk og padde har fått sitt eget hjem i {guild}! Koret er komplett. {name}" },
    ["guild:family:mechanical"] = { name = "Verkstedet", desc = "Hvert mekaniske dyr blir tatt vare på i guilden.",
        flavor = "Hvert eneste mekaniske dyr har fått sitt eget hjem i {guild}! Bzzt-klikk. {name}" },
    ["guild:family:dragon"] = { name = "Dragegrotta", desc = "Hver drage blir tatt vare på i guilden.",
        flavor = "Hver eneste drage har fått sitt eget hjem i {guild}! Ha brannslukkeren klar. {name}" },
    ["guild:family:bird"] = { name = "Fuglefjellet", desc = "Hver fugl blir tatt vare på i guilden.",
        flavor = "Hver eneste fugl har fått sitt eget hjem i {guild}! {name}" },
    ["guild:family:pirate"] = { name = "Den Sorte Dame", desc = "Hvert piratdyr blir tatt vare på i guilden.",
        flavor = "Hvert eneste piratdyr har fått sitt eget hjem i {guild}! Hiv og hoi! {name}" },
}
