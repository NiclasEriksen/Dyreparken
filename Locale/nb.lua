---@class Dyreparken
local ns = select(2, ...)
local L = ns.L

-- Every text players read, in Norwegian (bokmål). Edit freely: the code only
-- knows the keys (left), never the words. {name} is a placeholder the code
-- fills in; keep each one a text uses, in any order. Colors are WoW codes:
-- |cffRRGGBB starts one, |r ends it. Keys are permanent-ish: renaming one
-- means renaming it in the code too.
--
-- What the pets say can have many texts (ns.Lines, Core/Init.lua): a key's own text, if it has one
-- (activity.dance.flavor), and its variants, numbered without gaps (activity.dance.flavor.1, .2, ...: one past a
-- gap is never said), each as likely. The player's own are mixed in too: <key>.class.<class>.N and
-- <key>.race.<race>.N, by the client's English names in lower case (warrior, paladin, hunter, rogue, priest,
-- shaman, mage, warlock, druid; human, dwarf, nightelf, gnome, orc, scourge (undead), tauren, troll).
-- That goes for the eggs, dislikes, class reactions, liked activities, trait moments and pat answers.
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
L["home.short"] = "Hos {who} {how}"               -- the card's short form; the sentence above on hover
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
L["cmd.help.lyd"] = "lyd [på|av] - klirringen når et dyr summones (av = dempet, som standard)"
L["cmd.help.prestasjoner"] = "prestasjoner [alle|del|varsel på|av] - prestasjonene dine (alle: hele lista); del nye i guildchatten"
L["cmd.help.kunngjor"] = "kunngjør [på|av] - del adopsjoner og kallenavn i guildchatten (på som standard)"
L["cmd.help.klapp"] = "klapp - klapp dyret du har valgt som mål, eller ditt eget"
L["cmd.help.innstillinger"] = "innstillinger - åpne innstillingene"
L["cmd.help.ui"] = "Alt annet finner du i samlingen (Shift+P): kortet, Parken, Prestasjoner og ⚙."
L["cmd.help.dev"] = "Utviklerkommandoene: /dp dev"
L["cmd.unknown"] = "Ukjent kommando «{cmd}»."
L["cmd.settings.where"] = "Innstillingene finner du under ⚙ i samlingen (Shift+P), eller under Esc > Options > AddOns."

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
-- A new player's first steps (Onboarding.lua): once an account, once after the first adoption, the card's "?".
L["welcome.guild"] = "Velkommen til Dyreparken! Åpne samlingen (Shift+P) og adopter et dyr: det blir guildens, og dere bygger et bånd sammen."
L["welcome.solo"] = "Velkommen til Dyreparken! Den er for guilder, der dere adopterer dyr sammen, men båndet med dyrene dine vokser likevel: ha dem ute med deg."
L["welcome.where"] = "Parken og Prestasjoner er fanene til høyre i samlingen, og ⚙ har innstillingene."
L["welcome.adopted"] = "Ha {pet} ute med deg: {day} poeng om dagen, mer når dere gjør noe det liker (opptil {max}). Hold over ? på kortet for mer."
L["help.title"] = "Slik blir du venn med {pet}"
L["help.day"] = "Ha {pet} ute med deg: {n} båndpoeng om dagen, og opptil {max} med alt dere gjør."
L["help.likes"] = "{pet} liker {list}: mer poeng for det."
L["help.unknown"] = "Personligheten er ukjent til noen i guilden har dyret."
L["help.wish"] = "I dag: {line} (+{n})"
L["help.wish.adopt"] = "Adopter dyret, så får det et ønske hver dag."
L["help.play"] = "I gruppe med noen fra guilden som har et dyr ute, leker dyrene sammen: +{n}, én gang om dagen."
L["adopt.no_guild"] = "Du er ikke i en guild."
L["adopt.unknown"] = "Ukjent dyr."
L["adopt.not_owned"] = "Du har ikke det dyret."
L["adopt.yours"] = "Det bor allerede hos deg."
L["adopt.taken"] = "Det bor allerede hos {owner}."
L["adopt.done"] = "Du adopterte {pet}."
L["adopt.done_swap"] = "Du adopterte {pet} (og ga slipp på {old})."
L["adopt.keeps_own_name"] = " Det heter fortsatt «{nick}»."
L["adopt.confirm"] = "Adoptere {pet}?"
L["adopt.confirm.swap"] = "Du gir da slipp på {pet}. Båndet dere har bygget, blir ikke borte."
L["adopt.confirm.announce"] = "Adopsjonen blir kunngjort i guildchatten, så hele guilden får se den. (Slå av under ⚙ Innstillinger, eller med /dp kunngjør.)"
L["adopt.inherits_name"] = " Det heter «{nick}», et navn det fikk av {namer}. Ta godt vare på det!"
L["release.none"] = "Du har ikke adoptert noe dyr."
L["release.done"] = "Du ga slipp på {pet}."
L["letgo.confirm"] = "Gi slipp på {pet}?\n\nBåndet dere har bygget, blir ikke borte, men andre i guilden kan adoptere {pet}."
L["lapse.away"] = "{pet} dro tilbake til parken mens du var lenge borte. Adopter det igjen hvis det fortsatt er ledig."
L["lapse.beaten"] = "{owner} rakk å adoptere {pet} rett før deg, så det bor der nå."
-- A copy of your own record from a guildmate changed which pet lives with you (your other PC's, most likely).
L["own.relayed"] = "Ifølge {who} bor {pet} hos deg nå (endret på en annen PC?)."
L["own.relayed_none"] = "Ifølge {who} bor ikke {pet} hos deg lenger (endret på en annen PC?). Var det ikke deg, kan du adoptere det igjen."
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
L["milestone.others"] = "I dag feirer {list} en merkedag med dyret sitt!"
L["milestone.and_more"] = " og {n} til"
L["nick.unlocked_rename"] = "Nå kan du gi {pet} et nytt kallenavn hvis du vil: trykk Kallenavn på kortet, eller /dp navn."
L["nick.unlocked"] = "Nå kan du gi {pet} et kallenavn: trykk Kallenavn på kortet, eller /dp navn."
L["pat.own"] = "klapper {pet}."                       -- an emote: "Ola klapper Pepe."
L["pat.other_nick"] = "klapper {nick} ({owner} sin {species})."
L["pat.other"] = "klapper {owner} sin {species}."
L["pat.combat"] = "Ikke nå, du er i combat."
L["park.birthday"] = "Dyreparken fyller {n} år i dag! Takk for at dere tar vare på dyrene."
L["today.mine"] = "{pet} er dagens dyr i guilden! Det har fått en krone på kortet sitt."
L["pat.thanks"] = "{pet} ser fornøyd ut etter klappen fra {who}."
L["pat.nothing"] = "Summon dyret ditt, eller velg et dyr som mål."
-- The pet's answer to a pat, by family (2026-11-10; only you see it), and its variants (2026-11-17).
L["voice.cat"] = "{pet} maler: «mrrr ... mjau»."
L["voice.cat.1"] = "{pet} gnir hodet mot hånda di."
L["voice.bird"] = "{pet} kvitrer fornøyd."
L["voice.bird.1"] = "{pet} blåser seg opp og kvitrer."
L["voice.owl"] = "{pet} sier «hu-hu»."
L["voice.owl.1"] = "{pet} snur hodet nesten helt rundt og ser fornøyd på deg."
L["voice.farm"] = "{pet} sier «kakk-kakk»."
L["voice.farm.1"] = "{pet} gir deg et lite dytt med hodet."
L["voice.rabbit"] = "{pet} rister fornøyd på ørene."
L["voice.rabbit.1"] = "{pet} trommer fornøyd med bakbeinet."
L["voice.frog"] = "{pet} sier «kvekk»."
L["voice.frog.1"] = "{pet} blåser opp strupen: «kveeeeekk»."
L["voice.snake"] = "{pet} sier «sssss»."
L["voice.mechanical"] = "{pet} sier «bzzt-klikk»."
L["voice.mechanical.1"] = "{pet} piper: «KOS REGISTRERT»."
L["voice.dragon"] = "{pet} fnyser en liten røyksky."
L["voice.dragon.1"] = "{pet} legger hodet på skrå og maler som en katt. Med røyk utav nesa."
L["voice.pirate"] = "{pet} sier «arrr»."
L["voice.bug"] = "{pet} surrer fornøyd."
L["voice.rodent"] = "{pet} sier «pip»."
L["voice.rodent.1"] = "{pet} vasker potene fornøyd."
L["voice.wolf"] = "{pet} sier «auuu»."
L["voice.wolf.1"] = "{pet} logrer så hele kroppen svinger."
L["voice.plant"] = "{pet} rasler med bladene."
L["voice.festive"] = "{pet} klinger som en liten bjelle."
L["voice.demon"] = "{pet} fniser: «hehehe»."
L["voice.ooze"] = "{pet} sier «blubb»."
L["voice.spirit"] = "{pet} sier ingenting, men lyser litt sterkere."
L["voice.bear"] = "{pet} brummer fornøyd."
L["voice.bear.1"] = "{pet} ruller seg over på ryggen."
L["voice.reptile"] = "{pet} blunker sakte og fornøyd."
L["voice.murloc"] = "{pet} sier «mrglglglgl!»"
L["voice.murloc.1"] = "{pet} vifter med finnene: «mrrgl!»"
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
L["first.place.6"] = "{pet} setter et lite potetrykk i {place}. Nå har det vært her."
L["first.place.7"] = "{pet} hilser høflig på {place}."
L["first.place.bird.1"] = "{pet} tar en runde i lufta over {place}."
L["first.place.bird.2"] = "{pet} har funnet en fin utsiktspost i {place}."
L["first.place.owl.1"] = "{pet} myser vurderende på {place}. Hm-hm."
L["first.place.cat.1"] = "{pet} later som {place} ikke er noe særlig, men halen sier noe annet."
L["first.place.cat.2"] = "{pet} har allerede funnet den beste solflekken i {place}."
L["first.place.dragon.1"] = "{pet} vurderer om det er plass til en skatt i {place}."
L["first.place.wolf.1"] = "{pet} setter nesa i bakken og sporer seg gjennom {place}."
L["first.place.wolf.2"] = "{pet} uler en liten hilsen til {place}."
L["first.place.rodent.1"] = "{pet} lurer på hvor mange gjemmesteder {place} har."
L["first.place.rabbit.1"] = "{pet} hopper høyt av glede over {place}."
L["first.place.frog.1"] = "{pet} kvekker fornøyd. {place} har sikkert en dam et sted."
L["first.place.pirate.1"] = "{pet} roper «Land i sikte!» om {place}."
L["first.place.spirit.1"] = "{pet} svever stille gjennom {place}, som om det har vært her før."
L["first.place.plant.1"] = "{pet} kjenner etter om jorda i {place} er god."
L["first.place.mechanical.1"] = "{pet} skanner {place}. Kartlegging fullført."
L["first.place.mechanical.2"] = "{pet} lagrer {place} i minnet. Kart oppdatert."
L["first.place.murloc.1"] = "{pet} gurgler begeistret: «Mrgl! {place}!»"
L["first.place.bear.1"] = "{pet} rusler gjennom {place} på jakt etter noe godt å spise."
L["play.line"] = "{pet} lekte med {friend} ({owner})!"   -- a playdate: our pet met a guildmate's in the group
L["play.inseparable"] = "{pet} og {friend} leker alltid sammen i parken nå."
L["play.best"] = "Beste lekevenn: {friend} ({owner}), {n} lekedater"
-- A playdate between two families (Playdate.Line): play.<our family>.<theirs>.N, said instead of play.line.
-- {pet}: ours; {friend}: theirs with its owner, "Mjau (Kari Berg)". Pairs without lines keep play.line.
-- Katt
L["play.cat.rodent.1"] = "{pet} lekte katt og mus med {friend}. Det er ikke helt avklart hvem som var musa."
L["play.cat.rodent.2"] = "{pet} lå helt stille i gresset og fulgte {friend} med blikket. Lenge. Veldig lenge."
L["play.rodent.cat.1"] = "{pet} oppdaget {friend} og løp tre runder rundt beina dine før den turte å hilse."
L["play.rodent.cat.2"] = "{pet} stjal maten til {friend} og stakk av. Modig, eller dumt? Begge deler."
L["play.cat.bird.1"] = "{pet} følger {friend} med blikket hele tiden. Sånn helt vennlig."
L["play.cat.bird.2"] = "{pet} prøvde å klatre opp etter {friend}, men landet på rumpa. Med verdigheten i behold, nesten."
L["play.bird.cat.1"] = "{pet} satte seg rett utenfor rekkevidde for {friend} og steller fjæra."
L["play.bird.cat.2"] = "{pet} slapp en fjær ned til {friend}. Den ble jaktet på i en halvtime."
L["play.cat.wolf.1"] = "{pet} skjøt rygg og freste mot {friend}. Så la den seg ned og lot seg snuse på. Litt."
L["play.cat.wolf.2"] = "{pet} lot {friend} jage seg opp i et tre, og satt der og så overlegen ut."
L["play.wolf.cat.1"] = "{pet} ville bare leke, men {friend} sa klart nei. Med klørne."
L["play.wolf.cat.2"] = "{pet} logret så hele kroppen ristet, mens {friend} later som den ikke ser det."
L["play.cat.rabbit.1"] = "{pet} prøvde å smyge seg innpå {friend}, men ble hoppet over. Helt over."
L["play.cat.rabbit.2"] = "{pet} og {friend} hadde en stirrekonkurranse. Kaninen blunket først. Sier katten."
L["play.rabbit.cat.1"] = "{pet} hoppet i sikksakk rundt {friend} til katten ble svimmel."
L["play.rabbit.cat.2"] = "{pet} dunket med bakbeina hver gang {friend} kom nærmere. Den tok hintet."
L["play.cat.frog.1"] = "{pet} slo forsiktig etter {friend} med labben, og spratt like høyt som frosken da den hoppet unna."
L["play.cat.frog.2"] = "{pet} synes {friend} er altfor sleip til å leke med. Men fortsatte likevel."
L["play.frog.cat.1"] = "{pet} kvekket rett i ansiktet til {friend}. Katten har ikke hentet seg inn igjen."
L["play.frog.cat.2"] = "{pet} satt helt stille på en stein. {friend} har ennå ikke skjønt at den lever."
L["play.cat.owl.1"] = "{pet} og {friend} stirret på hverandre med store øyne i hele kveld."
L["play.cat.owl.2"] = "{pet} fikk oppleve at {friend} kunne snu hodet helt rundt. Katten har ikke vært den samme siden."
L["play.owl.cat.1"] = "{pet} ser ned på {friend} fra en grein. Begge mener at de er den kloke her."
L["play.owl.cat.2"] = "{pet} hoet høyt. {friend} spratt en meter rett i været."
L["play.cat.bug.1"] = "{pet} jaktet på {friend} under en stein, og gikk derfra med et veldig fornøyd tryne."
L["play.cat.bug.2"] = "{pet} slo {friend} rundt med labben. Den tålte det overraskende greit."
L["play.bug.cat.1"] = "{pet} kravlet over halen til {friend}. Katten spratt lenger enn noen gang før."
L["play.bug.cat.2"] = "{pet} gjemte seg i en sprekk og lot {friend} lete. Den leter fortsatt."
L["play.cat.snake.1"] = "{pet} sloss med {friend} i ti minutter før den skjønte at det var halen til slangen."
L["play.cat.snake.2"] = "{pet} prøvde å bli venner med {friend}, men ble litt skeptisk av all hvesingen."
L["play.snake.cat.1"] = "{pet} kveilet seg sammen i sola ved siden av {friend}. To som vet å slappe av."
L["play.snake.cat.2"] = "{pet} hveste. {friend} hveste tilbake. Det ble en lang samtale."
L["play.cat.pirate.1"] = "{pet} hørte på at {friend} skrek \"Jeg vil ha kjeks!\" i en time. Det var ikke kjeks igjen."
L["play.cat.pirate.2"] = "{pet} ble kalt for landkrabbe av {friend}. Katten vet ikke hva det betyr, men den likte det ikke."
L["play.pirate.cat.1"] = "{pet} kaller {friend} for «skipskatten» og har gitt den et oppdrag: hold rottene unna lasten."
L["play.pirate.cat.2"] = "{pet} lærte {friend} å si \"Arrr\". Det ble mer \"Mjarrr\"."
L["play.cat.mechanical.1"] = "{pet} prøvde å jage {friend}, men den lukter olje og smaker metall."
L["play.cat.mechanical.2"] = "{pet} la seg på {friend} for å varme seg. Den var varm som en ovn."
L["play.mechanical.cat.1"] = "{pet} skannet {friend}: «Pelsdyr. Lite. Høy fare for kos.»"
L["play.mechanical.cat.2"] = "{pet} fikk en tannhjul-hilsen fra {friend}, rett under nesa."
-- Ulv
L["play.wolf.rabbit.1"] = "{pet} jaget {friend} i store sirkler. Ingen tok den andre, og begge synes det var gøy."
L["play.wolf.rabbit.2"] = "{pet} stakk nesa ned i hullet som {friend} gravde. Det var ikke {friend} der nede."
L["play.rabbit.wolf.1"] = "{pet} er den eneste i parken som er raskere enn {friend}, og det vet den godt."
L["play.rabbit.wolf.2"] = "{pet} hoppet rett over hodet til {friend} og var borte før valpen rakk å snu seg."
L["play.wolf.farm.1"] = "{pet} prøvde å gjete {friend}. Det gikk ikke. Den gikk sin egen vei."
L["play.wolf.farm.2"] = "{pet} oppførte seg eksemplarisk i nærheten av {friend}."
L["play.farm.wolf.1"] = "{pet} holdt seg tett inntil deg så lenge {friend} var i nærheten. Man vet aldri."
L["play.farm.wolf.2"] = "{pet} har bestemt seg for at {friend} er en snill gjeterhund. Det stemmer ikke helt."
L["play.wolf.rodent.1"] = "{pet} gravde etter {friend} så jorda sprutet. {friend} så på fra et helt annet hull."
L["play.wolf.rodent.2"] = "{pet} tok {friend} med på en sniffetur. Den fant ingenting, men hadde det kjempegøy."
L["play.rodent.wolf.1"] = "{pet} pep og forsvant ned i et hull hver gang {friend} snudde seg. En times underholdning."
L["play.rodent.wolf.2"] = "{pet} red på ryggen til {friend} gjennom halve parken."
L["play.wolf.bear.1"] = "{pet} prøvde å bryte med {friend}. Det var ikke en rettferdig kamp, men det var en morsom en."
L["play.wolf.bear.2"] = "{pet} ulte, og {friend} brummet i takt. Det ble nesten en sang."
L["play.bear.wolf.1"] = "{pet} lot {friend} vinne en brytekamp. Det er det som er å være stor."
L["play.bear.wolf.2"] = "{pet} og {friend} delte en honningkake. {friend} spiste mest."
L["play.wolf.bird.1"] = "{pet} bjeffet etter {friend} rundt i hele parken. Fugler er visst til for å jages."
L["play.wolf.bird.2"] = "{pet} prøvde å hoppe like høyt som {friend} flyr. Den kom nesten en meter."
L["play.bird.wolf.1"] = "{pet} fløy lavt over {friend} igjen og igjen. Valpen er fortsatt svimmel."
L["play.bird.wolf.2"] = "{pet} satte seg på hodet til {friend}. Valpen har ikke lagt merke til det."
-- Slange
L["play.snake.rodent.1"] = "{pet} kveilet seg rundt {friend}. Bare en klem! Helt sant!"
L["play.snake.rodent.2"] = "{pet} så lenge på {friend} og slikket seg rundt munnen. Det ble en kort lekedate."
L["play.rodent.snake.1"] = "{pet} holdt god avstand til {friend} hele tida. Klok gnager."
L["play.rodent.snake.2"] = "{pet} bygget en mur av nøtter mellom seg selv og {friend}. Sikkerheten først."
L["play.snake.frog.1"] = "{pet} og {friend} hadde en hoppekonkurranse. Slangen tapte, av naturlige grunner."
L["play.snake.frog.2"] = "{pet} og {friend} sammenligner tunge. Ikke rart folk synes de er litt ekle."
L["play.frog.snake.1"] = "{pet} satte seg trygt på et blad i dammen og kvekket ned til {friend}. Herfra er det trygt."
L["play.frog.snake.2"] = "{pet} hoppet over {friend} igjen og igjen. Slangen synes ikke det er rettferdig."
L["play.snake.bird.1"] = "{pet} prøvde å klatre opp i treet til {friend}. Det går tregt uten bein."
L["play.snake.bird.2"] = "{pet} hveste. {friend} pep tilbake. Ingen av dem forstod hverandre, men de hadde det fint."
L["play.bird.snake.1"] = "{pet} holder seg trygt i lufta mens den skjeller ut {friend}."
L["play.bird.snake.2"] = "{pet} slapp en kvist på hodet til {friend}. Uhell. Sier den."
-- Ugle
L["play.owl.rodent.1"] = "{pet} ser på {friend} med veldig store øyne. Lekedaten ble avbrutt tidlig av gnageren."
L["play.owl.rodent.2"] = "{pet} lot {friend} vinne i gjemsel. Ugla visste hvor den var hele tida."
L["play.rodent.owl.1"] = "{pet} kikket opp og så {friend}. Så kikket den ikke mer, den bare løp."
L["play.rodent.owl.2"] = "{pet} prøver å holde seg våken like lenge som {friend}. Den sovnet før midnatt."
L["play.owl.rabbit.1"] = "{pet} sitter og vokter over {friend} fra en grein. Sånn helt vennlig."
L["play.owl.rabbit.2"] = "{pet} prøvde å forklare {friend} at natta er best. Kaninen sovnet."
L["play.rabbit.owl.1"] = "{pet} hoppet under en busk så fort {friend} kom svevende over."
L["play.rabbit.owl.2"] = "{pet} og {friend} har en avtale: ugla har natta, kaninen har dagen."
-- Frosk
L["play.frog.bug.1"] = "{pet} lot være å spise {friend}. Det var tett på, men det gikk bra."
L["play.frog.bug.2"] = "{pet} fulgte {friend} med tunga hengende ut. Ren refleks."
L["play.bug.frog.1"] = "{pet} danset rett foran nesa på {friend}. Livsfarlig, men du verden så gøy."
L["play.bug.frog.2"] = "{pet} gjemte seg under et blad og ventet til {friend} var ferdig med å kvekke."
L["play.frog.murloc.1"] = "{pet} og {friend} hadde en kvekke-og-gurgle-duett ved dammen."
L["play.frog.murloc.2"] = "{pet} mener {friend} er en stor, rar frosk. {friend} mener det samme om den."
L["play.murloc.frog.1"] = "{pet} sa \"Mrglglgl!\" til {friend}. Frosken svarte \"Kvekk\". De forstod hverandre perfekt."
L["play.murloc.frog.2"] = "{pet} lærte {friend} å svømme som en murloc. Frosken kunne det fra før."
-- Krypdyr
L["play.reptile.bird.1"] = "{pet} lå helt stille i vannkanten og lot som om den var en stokk. {friend} gikk ikke på det."
L["play.reptile.bird.2"] = "{pet} smilte bredt til {friend}. Alle tennene. Det var ment vennlig."
L["play.bird.reptile.1"] = "{pet} pirket {friend} mellom tennene. Krokodiller liker visst tannpuss."
L["play.bird.reptile.2"] = "{pet} satt på ryggen til {friend} og så på utsikten."
L["play.reptile.farm.1"] = "{pet} lå og latet seg i dammen, mens {friend} gikk nervøst rundt."
L["play.reptile.farm.2"] = "{pet} og {friend} hadde et kappløp. Ingen av dem var spesielt raske."
L["play.farm.reptile.1"] = "{pet} holder seg langt unna vannkanten så lenge {friend} er der."
L["play.farm.reptile.2"] = "{pet} kakler nervøst hver gang {friend} gjesper."
L["play.reptile.frog.1"] = "{pet} og {friend} solte seg på samme stein. Kaldblodige venner."
L["play.reptile.frog.2"] = "{pet} prøvde å lære av {friend} hvordan man hopper. Det går ikke."
L["play.frog.reptile.1"] = "{pet} satte seg på nesa til {friend}. Den modigste frosken i hele parken."
L["play.frog.reptile.2"] = "{pet} og {friend} lå i dammen med bare øynene over vann og så på verden."
-- Bjørn
L["play.bear.murloc.1"] = "{pet} prøvde å fiske {friend} ut av dammen. {friend} protesterte høylytt."
L["play.bear.murloc.2"] = "{pet} og {friend} fisket sammen. Bjørnen fikk ikke noe, murlocen fikk alt."
L["play.murloc.bear.1"] = "{pet} gurglet lenge til {friend} om hvorfor fisk er venner, ikke mat."
L["play.murloc.bear.2"] = "{pet} sprutet vann på {friend}. Bjørnen satte seg rett i dammen. Det ble en stor bølge."
L["play.bear.bug.1"] = "{pet} lurer på om {friend} vet hvor det er honning. Den vet ikke."
L["play.bear.bug.2"] = "{pet} prøvde å klappe {friend} med en stor labb. Det var en veldig forsiktig klapp."
L["play.bug.bear.1"] = "{pet} klatret helt opp i pelsen til {friend} og ble der. Det var varmt og godt."
L["play.bug.bear.2"] = "{pet} kilte {friend} i nesa til bjørnen nøs i ti minutter."
-- Drage
L["play.dragon.farm.1"] = "{pet} så sulten på {friend}. Sier at den bare var nysgjerrig."
L["play.dragon.farm.2"] = "{pet} prøvde å varme {friend} med et lite flammepust. Det lukter grillet fjær nå."
L["play.farm.dragon.1"] = "{pet} gjemte seg bak deg hele tida {friend} var der. Klok, sier vi."
L["play.farm.dragon.2"] = "{pet} er sikker på at {friend} bare er en stor, skjellbelagt høne. Den har feil."
L["play.dragon.demon.1"] = "{pet} og {friend} konkurrerte om hvem som kunne lage mest ild. Parken brant nesten."
L["play.dragon.demon.2"] = "{pet} gir {friend} et kritisk blikk. Ekte drager har ikke horn."
L["play.demon.dragon.1"] = "{pet} prøvde å skremme {friend} med et brøl. {friend} brølte større."
L["play.demon.dragon.2"] = "{pet} og {friend} har startet sin egen klubb for små, farlige vesener."
L["play.dragon.mechanical.1"] = "{pet} pustet ild på {friend}. Den ble bare litt varmere og litt blankere."
L["play.dragon.mechanical.2"] = "{pet} prøvde å ruge på {friend}. Den klikket litt, men klekket ikke."
L["play.mechanical.dragon.1"] = "{pet} målte temperaturen til {friend}: «For varm. Anbefaler avstand.»"
L["play.mechanical.dragon.2"] = "{pet} fikk et lite smeltemerke etter lekedaten med {friend}. Den bærer det med stolthet."
-- Demon og ånd
L["play.demon.spirit.1"] = "{pet} prøvde å skremme {friend}, men ånder er visst ikke redde for noe."
L["play.demon.spirit.2"] = "{pet} og {friend} hadde en lang samtale om livet etter døden. Demonen var ikke enig."
L["play.spirit.demon.1"] = "{pet} svevde gjennom {friend}. Demonen grøsset helt ned i hovene."
L["play.spirit.demon.2"] = "{pet} lyste opp så sterkt at {friend} måtte holde for øynene."
L["play.demon.festive.1"] = "{pet} prøvde å ødelegge feiringen til {friend}. Den endte opp med lue på."
L["play.demon.festive.2"] = "{pet} gav {friend} en liten flamme i gave. Det var ment hyggelig."
L["play.festive.demon.1"] = "{pet} ga {friend} en gave. Demonen vet ikke helt hva den skal gjøre med takknemlighet."
L["play.festive.demon.2"] = "{pet} sang en julesang for {friend}. Demonen nynnet med, i moll."
-- Mekanisk
L["play.mechanical.rodent.1"] = "{pet} og {friend} prøver å finne ut hvem som er det ekte ekornet."
L["play.mechanical.rodent.2"] = "{pet} prøvde å samle nøtter som {friend}. Den samlet skruer i stedet."
L["play.rodent.mechanical.1"] = "{pet} prøvde å gnage på {friend}. Det smakte ikke godt."
L["play.rodent.mechanical.2"] = "{pet} prøvde å gjemme en nøtt inni {friend}. Den sitter fast nå."
L["play.mechanical.ooze.1"] = "{pet} fikk slim i tannhjulene etter å ha lekt med {friend}. Det knirker."
L["play.mechanical.ooze.2"] = "{pet} prøvde å analysere {friend}: «Ukjent stoff. Kliss. Veldig kliss.»"
L["play.ooze.mechanical.1"] = "{pet} klistret seg fast til {friend} og ble med på en tur rundt parken."
L["play.ooze.mechanical.2"] = "{pet} smurte tannhjulene til {friend}. Den går mye stillere nå."
-- Sjørøver
L["play.pirate.murloc.1"] = "{pet} skrek \"Mann over bord!\" hver gang {friend} hoppet i dammen."
L["play.pirate.murloc.2"] = "{pet} prøvde å verve {friend} som mannskap. Murlocen vil ha sin del av byttet først."
L["play.murloc.pirate.1"] = "{pet} gurglet en sjørøversang for {friend}. Den lærte seg den på et øyeblikk."
L["play.murloc.pirate.2"] = "{pet} stjal en kjeks fra {friend}. Det er sjørøvermoral det."
-- Plante
L["play.plant.bug.1"] = "{pet} prøvde å holde {friend} unna bladene sine. Det gikk sånn passe."
L["play.plant.bug.2"] = "{pet} lot {friend} sitte på et blad og sole seg. De er en slags venner nå."
L["play.bug.plant.1"] = "{pet} tok en liten smak av {friend}. Den smakte grønt."
L["play.bug.plant.2"] = "{pet} bygget et lite hjem i røttene til {friend}."
L["play.plant.rabbit.1"] = "{pet} holdt bladene sine godt inntil seg så lenge {friend} var i nærheten."
L["play.plant.rabbit.2"] = "{pet} ble gnagd litt på av {friend}. Den tilgir, men glemmer ikke."
L["play.rabbit.plant.1"] = "{pet} så på {friend} og fikk vann i munnen."
L["play.rabbit.plant.2"] = "{pet} lekte gjemsel bak {friend}. Den var ikke god til å gjemme seg, med de ørene."
L["play.plant.rodent.1"] = "{pet} fikk et frø gravd ned i jorda ved siden av seg av {friend}. Kanskje det blir en venn."
L["play.plant.rodent.2"] = "{pet} viftet med bladene for å holde {friend} unna. Gnageren synes det var en lek."
L["play.rodent.plant.1"] = "{pet} gjemte nøtter i røttene til {friend}. Det er det tryggeste stedet den vet om."
L["play.rodent.plant.2"] = "{pet} klatret opp i {friend} og satt der hele lekedaten."
-- Slim
L["play.ooze.bug.1"] = "{pet} prøvde å bli venner med {friend}, men den satt fast i slimet."
L["play.ooze.bug.2"] = "{pet} og {friend} har funnet ut at de begge liker søppel. Det er et vennskap for livet."
L["play.bug.ooze.1"] = "{pet} kravlet rundt i {friend} og kom ut på andre siden. Helt grønn."
L["play.bug.ooze.2"] = "{pet} synes {friend} lukter fantastisk. Ingen andre er enige."
-- Fugl
L["play.bird.bug.1"] = "{pet} fulgte {friend} rundt med nebbet klart. Det var bare lek. Nesten."
L["play.bird.bug.2"] = "{pet} prøvde å lære {friend} å fly. Det ble mest kravling."
L["play.bug.bird.1"] = "{pet} gjemte seg hver gang skyggen til {friend} gikk over."
L["play.bug.bird.2"] = "{pet} satt på ryggen til {friend} og fikk sin første flytur."
-- Like møter like
L["play.cat.cat.1"] = "{pet} og {friend} snuste hverandre på nesa, og la seg så i hver sin solflekk. Perfekt lekedate."
L["play.cat.cat.2"] = "{pet} og {friend} jaget hverandre rundt i parken i ti minutter, og så sov de i to timer."
L["play.wolf.wolf.1"] = "{pet} og {friend} ulte sammen til hele parken ble stille."
L["play.wolf.wolf.2"] = "{pet} og {friend} har dannet en flokk på to. Lederen er ikke avgjort."
L["play.rodent.rodent.1"] = "{pet} og {friend} byttet nøtter. Begge mener de fikk den beste."
L["play.rodent.rodent.2"] = "{pet} og {friend} gravde en tunnel sammen. Den går under hele parken nå."
L["play.bird.bird.1"] = "{pet} og {friend} kvitret om kapp til ingen andre fikk et ord med i laget."
L["play.bird.bird.2"] = "{pet} og {friend} fløy i formasjon over parken. Nesten."
L["play.dragon.dragon.1"] = "{pet} og {friend} sammenlignet skjell. Begge mener de har de fineste."
L["play.dragon.dragon.2"] = "{pet} og {friend} kappfløy til nærmeste skatt. Det var en mynt."
L["play.frog.frog.1"] = "{pet} og {friend} hadde kvekkekor ved dammen hele kvelden."
L["play.frog.frog.2"] = "{pet} og {friend} hoppet om kapp. Det endte uavgjort, og i dammen."
L["play.snake.snake.1"] = "{pet} og {friend} floket seg sammen og trengte litt hjelp for å komme løs."
L["play.snake.snake.2"] = "{pet} og {friend} lå i sola og hveste hyggelig til hverandre."
L["play.mechanical.mechanical.1"] = "{pet} og {friend} utvekslet data. Begge er nå oppdatert."
L["play.mechanical.mechanical.2"] = "{pet} og {friend} klikket og surret i takt. Det er visst sånn de ler."
L["play.ooze.ooze.1"] = "{pet} og {friend} smeltet sammen litt. Det tok en stund å finne ut hvem som var hvem."
L["play.ooze.ooze.2"] = "{pet} og {friend} boblet om kapp. Ingen vant, alle ble klissete."
L["play.plant.plant.1"] = "{pet} og {friend} stod stille side om side i sola. En veldig rolig lekedate."
L["play.plant.plant.2"] = "{pet} og {friend} flettet bladene sammen. De er bestevenner nå."
L["play.demon.demon.1"] = "{pet} og {friend} planla verdensherredømme. De kom til punkt to: snacks."
L["play.demon.demon.2"] = "{pet} og {friend} hadde en brølekonkurranse. Naboene klager."
L["play.bug.bug.1"] = "{pet} og {friend} kravlet i ring rundt hverandre i en time. Det er visst sånn de hilser."
L["play.bug.bug.2"] = "{pet} og {friend} delte en smule. Det var nok til begge."
L["play.rabbit.rabbit.1"] = "{pet} og {friend} hoppet om kapp over hele parken."
L["play.rabbit.rabbit.2"] = "{pet} og {friend} vasket ørene til hverandre. Det var lange ører, så det tok tid."
L["play.owl.owl.1"] = "{pet} og {friend} hoet til hverandre hele natta. Ingen vet hva de snakket om."
L["play.owl.owl.2"] = "{pet} og {friend} satt på samme grein og så kloke ut sammen."
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
-- kills, quests, mining, skinning). .flavor (and .flavor.N, by class and race too:
-- 2026-11-17): the line for the first liked one of a day; without any, bond.liked
-- is used ("Pepe koste seg med herbs!"). A rep gain under Config.REP_LINE_MIN says nothing.
------------------------------------------------------------------------------
L["activity.boss"] = "boss-kills"
L["activity.boss.flavor.1"] = "{pet} så bossen daue og har allerede begynt å skryte av det."
L["activity.boss.flavor.2"] = "{pet} jubler! Den bossen kommer ikke tilbake med det første."
L["activity.boss.flavor.3"] = "{pet} snuser på det som er igjen av bossen. Godt jobba!"
L["activity.boss.flavor.class.warrior.1"] = "{pet} hørte deg brøle gjennom hele kampen. Det hjalp nok."
L["activity.boss.flavor.class.rogue.1"] = "{pet} så ikke engang hvor du ble av før bossen lå der."
L["activity.boss.flavor.class.priest.1"] = "{pet} tror ikke det hadd gått så bra uten mytji lys og mytji skygge."
L["activity.boss.flavor.class.warlock.1"] = "{pet} gir demonen din en high-five. Bra jobba!"
L["activity.quest"] = "quests"
L["activity.quest.flavor.1"] = "{pet} hjalp deg å levere questet. Ved moralsk støtte ihvertfall."
L["activity.quest.flavor.2"] = "{pet} kikker etter questrewards. Noe til meg?"
L["activity.quest.flavor.3"] = "{pet} liker å se folk bli glade når dere hjelper dem."
L["activity.taxi"] = "flyturer"
L["activity.taxi.flavor.1"] = "{pet} stakk hodet ut i vinden hele flyturen."
L["activity.taxi.flavor.2"] = "{pet} vinket til alle der nede."
L["activity.taxi.flavor.3"] = "{pet} vil fly en tur til! Med en gang!"
L["activity.pvp"] = "PvP"
L["activity.pvp.flavor.1"] = "{pet} knurrer modig mot de fiendlige spillerne."
L["activity.pvp.flavor.2"] = "{pet} holdt vakt bak deg hele slaget."
L["activity.pvp.flavor.race.orc.1"] = "{pet} roper «Lok'tar!» etter deg. Det har lært av den beste."
L["activity.pvp.flavor.race.human.1"] = "{pet} roper «For Stormwind!» så høyt det klarer."
L["activity.herb"] = "herbs"
L["activity.herb.flavor.1"] = "{pet} snuser på hver herb før du får plukket den."
L["activity.herb.flavor.2"] = "{pet} fikk et blad på nesa og nyser fornøyd."
L["activity.herb.flavor.3"] = "{pet} har funnet sin favorittblomst i dag."
L["activity.herb.flavor.class.druid.1"] = "{pet} og du stopper ved hver eneste blomst. Dere er like som to dråper moonwell-vann."
L["activity.mine"] = "mining"
L["activity.mine.flavor.1"] = "{pet} hører det klinger i hakka og blir glad."
L["activity.mine.flavor.2"] = "{pet} har funnet en liten stein det vil ha med hjem."
L["activity.mine.flavor.3"] = "{pet} er støvete fra topp til tå, og lykkelig."
L["activity.mine.flavor.race.dwarf.1"] = "{pet} nynner på en gruvesang. Den har det fra deg."
L["activity.fish"] = "fisking"
L["activity.fish.flavor.1"] = "{pet} sitter helt stille ved siden av deg og venter på napp."
L["activity.fish.flavor.2"] = "{pet} følger duppen med øynene."
L["activity.fish.flavor.3"] = "{pet} mener den første fisken er dens. Det var tross alt den som så den først."
L["activity.fish.flavor.race.troll.1"] = "{pet} har lært av deg: fisking er best i ro og mak, mon."
L["activity.skin"] = "skinning"
L["activity.skin.flavor.1"] = "{pet} passer på at ingenting går til spille."
L["activity.skin.flavor.2"] = "{pet} lurer allerede på hva du skal lage av læret."
L["activity.day"] = "dager sammen"
L["activity.dance"] = "dansing"
L["activity.dance.flavor"] = "{pet} danset med deg!"
L["activity.dance.flavor.1"] = "{pet} tråkket deg på tærne, men det gjorde ingenting."
L["activity.dance.flavor.2"] = "{pet} har aldri danset så bra. Eller så lenge."
L["activity.dance.flavor.race.nightelf.1"] = "{pet} prøver å danse som deg, men har ikke helt bevegelsene ennå."
L["activity.dance.flavor.race.tauren.1"] = "{pet} danser med, et lite stykke unna. Bakken rister når en tauren danser."
L["activity.cuddle"] = "kos"
L["activity.cuddle.flavor"] = "{pet} elsker å bli kost med!"
L["activity.cuddle.flavor.1"] = "{pet} smelter helt i hendene dine."
L["activity.cuddle.flavor.2"] = "{pet} vil ha mer. Mye mer."
L["activity.chat"] = "guildprat"
L["activity.chat.flavor"] = "{pet} lytter fornøyd til guildpraten."
L["activity.chat.flavor.1"] = "{pet} nikker som om det forsto hvert ord i guildchatten."
L["activity.chat.flavor.2"] = "{pet} har lyst til å si hei til guilden, det også."
L["activity.dive"] = "dykking"
L["activity.dive.flavor"] = "{pet} plasket rundt med deg!"
L["activity.dive.flavor.1"] = "{pet} kom opp med en glinsende stein fra bunnen."
L["activity.dive.flavor.2"] = "{pet} blåste bobler ved siden av deg hele veien ned."
L["activity.dive.flavor.race.scourge.1"] = "{pet} har lagt merke til at du nesten ikke trenger å puste. Urettferdig."
L["activity.level"] = "nye levels"
L["activity.level.flavor"] = "{pet} er så stolt av deg!"
L["activity.level.flavor.1"] = "{pet} har talt alle levelene dine. Dette var det beste så langt."
L["activity.level.flavor.2"] = "{pet} danser rundt deg. Ding!"
L["activity.revive"] = "å vente på deg"
L["activity.revive.flavor"] = "{pet} ventet tålmodig på deg."
L["activity.revive.flavor.1"] = "{pet} satt ved siden av deg hele tiden."
L["activity.nap"] = "lur i byen"
L["activity.nap.flavor"] = "{pet} tok en lur sammen med deg."
L["activity.nap.flavor.1"] = "{pet} snorker lavt ved siden av deg."
L["activity.hearth"] = "reise hjem"
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
L["activity.gold.flavor.1"] = "{pet} biter i mynten for å sjekke at den er ekte."
L["activity.gold.flavor.2"] = "{pet} har allerede planer for gullet."
L["activity.fun"] = "tull og tøys"
L["activity.fun.flavor"] = "{pet} ler så det rister!"
L["activity.fun.flavor.1"] = "{pet} hikster av latter."
L["activity.fun.flavor.2"] = "{pet} vil være med på neste tullestrek også."
L["activity.sneak"] = "snikeri"
L["activity.sneak.flavor"] = "{pet} sniker seg med deg, på tå hev."
L["activity.sneak.flavor.1"] = "{pet} holder pusten til dere er forbi."
L["activity.sneak.flavor.2"] = "{pet} er ikke helt sikker på om det er usynlig, men later som."
L["activity.sneak.flavor.class.rogue.1"] = "{pet} har lært av mesteren. Ingen så dere komme."
L["activity.sneak.flavor.class.druid.1"] = "{pet} lister seg like stille som en katt. Nesten like stille som deg."
L["activity.meet"] = "nye dyrevenner"
L["activity.meet.flavor"] = "{pet} har fått en ny venn!"
L["activity.meet.flavor.1"] = "{pet} har fått enda en venn i verden."
L["activity.meet.flavor.2"] = "{pet} snuste vennlig på den nye vennen."
L["activity.camp.flavor"] = "{pet} koste seg ved bålet med deg."
L["activity.camp.flavor.1"] = "{pet} strekker potene mot flammene."
L["activity.camp.flavor.2"] = "{pet} ser gnistene stige mot stjernene."
L["activity.rested"] = "å sove i sovepose"
L["activity.feat"] = "milepæler"
L["activity.train"] = "besøk hos treneren"
L["activity.specswap"] = "bytte av spesialisering"
L["activity.respec"] = "nye talenter"
L["activity.rested.flavor"] = "{pet} sov godt i soveposen."
L["activity.jump.flavor"] = "{pet} hopper av glede!"
L["activity.jump.flavor.1"] = "{pet} hopper høyere enn deg. Nesten."
L["activity.jump.flavor.2"] = "{pet} spretter rundt beina dine som en ball."
L["activity.explore"] = "nye steder"
L["activity.explore.flavor"] = "{pet} snuser på et nytt sted!"
L["activity.explore.flavor.1"] = "{pet} har aldri sett noe lignende!"
L["activity.explore.flavor.2"] = "{pet} vil inn i hver krok av dette nye stedet."
L["activity.skill"] = "skill-ups"
L["activity.skill.flavor.1"] = "{pet} klapper når du blir flinkere. Ett poeng nærmere mester!"
L["activity.skill.flavor.2"] = "{pet} er imponert. Du lærer så fort!"
L["activity.skill.flavor.race.gnome.1"] = "{pet} lurer på hva du skal finne opp nå. Du er tross alt en gnom."
L["activity.rep"] = "rep"
L["activity.rep.flavor.1"] = "{pet} har gjort et godt inntrykk. Alle synes det er søtt."
L["activity.rep.flavor.2"] = "{pet} logrer for de nye vennene deres."

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
-- .dayflavor. A .flavor can have variants (.flavor.N, by class and race too).
-- Ids (the middle part) never change.
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
L["trait.nattugle.flavor.1"] = "{pet} har lysende øyne i mørket og vil ikke hjem ennå."
L["trait.nattugle.flavor.race.nightelf.1"] = "{pet} og du er begge nattens barn."
L["trait.nattugle.flavor.race.scourge.1"] = "{pet} liker at du heller ikke sover om natta."
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
L["trait.flokkdyr.flavor.1"] = "{pet} har hilst på alle i gruppen. To ganger."
L["trait.einstoing.name"] = "Einstøing"
L["trait.einstoing.desc"] = "Vil helst ha deg for seg selv."
L["trait.einstoing.when"] = "uten noen gruppe"
L["trait.einstoing.flavor"] = "{pet} satte pris på å ha deg for seg selv!"
L["trait.einstoing.flavor.1"] = "{pet} nyter stillheten. Bare dere to."
L["trait.huleboer.name"] = "Huleboer"
L["trait.huleboer.desc"] = "Føler seg hjemme i mørke ganger."
L["trait.huleboer.when"] = "i dungeons og raids"
L["trait.huleboer.flavor"] = "{pet} trives i mørket!"
L["trait.huleboer.flavor.1"] = "{pet} kjenner seg hjemme mellom steinveggene."
L["trait.huleboer.flavor.race.dwarf.1"] = "{pet} og du er like glade i å være under jorda."
L["trait.friluftsdyr.name"] = "Friluftsdyr"
L["trait.friluftsdyr.desc"] = "Elsker frisk luft."
L["trait.friluftsdyr.when"] = "ute i verden (ikke i dungeons)"
L["trait.friluftsdyr.flavor"] = "{pet} nøt den friske luften!"
L["trait.friluftsdyr.flavor.1"] = "{pet} trekker inn den friske lufta og blir helt glad."
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
L["trait.ordensdyr.flavor.1"] = "{pet} hilser høflig på vaktene."
L["trait.venneflokk.name"] = "Venneflokk"
L["trait.venneflokk.desc"] = "Alle dyr skal være venner."
L["trait.vinterpels.name"] = "Vinterpels"
L["trait.vinterpels.desc"] = "Trives i snø og kulde."
L["trait.vinterpels.when"] = "der det er kaldt"
L["trait.vinterpels.flavor"] = "{pet} koser seg i kulda!"
L["trait.vinterpels.flavor.1"] = "{pet} ruller seg i snøen."
L["trait.vinterpels.flavor.race.dwarf.1"] = "{pet} trives i kulda, akkurat som en ekte dverg fra Dun Morogh."
L["trait.solelsker.name"] = "Charterdyr"
L["trait.solelsker.desc"] = "Elsker sol og varme, som finingene på Charterfeber."
L["trait.solelsker.when"] = "der det er varmt"
L["trait.solelsker.flavor"] = "{pet} soler seg i varmen!"
L["trait.solelsker.flavor.1"] = "{pet} har funnet en solflekk og legger seg rett i den."
L["trait.solelsker.flavor.race.troll.1"] = "{pet} og du nyter varmen. Det er nesten som hjemme på øyene."
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
L["trait.skybaren.flavor.1"] = "{pet} ser ned på skyene og smiler."
L["trait.skybaren.flavor.race.tauren.1"] = "{pet} forstår godt hvorfor taurenene bygde byen sin på toppen av klippene."
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
L["personality.line"] = "{traits} · {likes}"                   -- {likes}: "liker mining · liker ikke flyturer"

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
L["dislike.dive.4"] = "{pet} venter på land og ser bort når du kommer opp."
L["dislike.pvp.1"] = "{pet} gjemte seg under kappen din til slåsskampen var over."
L["dislike.pvp.2"] = "{pet} synes slåssing er tull."
L["dislike.pvp.3"] = "{pet} skjønner ikke hvorfor dere ikke bare kan være venner med det andre laget."
L["dislike.chat.1"] = "{pet} legger potene over ørene. Så mye prat!"
L["dislike.chat.2"] = "{pet} sukker tungt over guildpraten."
L["dislike.chat.3"] = "{pet} har gitt opp å følge med i guildchatten."
L["dislike.taxi.1"] = "{pet} holdt øynene igjen hele flyturen."
L["dislike.taxi.2"] = "{pet} er grønn i fjeset etter flyturen."
L["dislike.taxi.3"] = "{pet} kysser bakken etter landing."
L["dislike.boss.1"] = "{pet} gjemte seg bak beina dine til bossen daua."
L["dislike.boss.2"] = "{pet} skjelver fortsatt litt etter den bossen."
L["dislike.boss.3"] = "{pet} synes bossen var altfor stor og altfor sint."
L["dislike.jump.1"] = "{pet} blir svimmel av all hoppingen."
L["dislike.jump.2"] = "{pet} ser på deg som om du har gått fra vettet der du spretter rundt."
L["dislike.jump.3"] = "{pet} har satt seg ned og nekter å hoppe mer."
L["dislike.jump.race.gnome.1"] = "{pet} skjønner ikke hvor en så liten gnom får all den energien fra."
L["dislike.hearth.1"] = "{pet} ble kvalm av hearthstonen."
L["dislike.hearth.2"] = "{pet} var ikke ferdig der dere var!"
L["dislike.hearth.3"] = "{pet} hater at verden blir borte i et blått blink."
L["dislike.nap.1"] = "{pet} tripper utålmodig. Skal dere ikke gjøre noe annet enn å bare ligge her?"
L["dislike.nap.2"] = "{pet} har talt alle plankene i gulvet. To ganger."
L["dislike.cuddle.1"] = "{pet} tåler kos, men bare så vidt."
L["dislike.cuddle.2"] = "{pet} later som ingenting skjedde."
L["dislike.cuddle.3"] = "{pet} retter på pelsen etterpå, med verdighet."
-- (2026-11-12: minor dislikes in Data/Unlocks.lua had none of these, so they could never be found; drafts)
L["dislike.camp.1"] = "{pet} holder seg et godt stykke unna bålet."
L["dislike.camp.2"] = "{pet} hoster av røyken og ser dømmende på deg."
L["dislike.camp.3"] = "{pet} lukter røyk og er ikke fornøyd med det."
L["dislike.dance.1"] = "{pet} ser flau ut over dansingen din."
L["dislike.dance.2"] = "{pet} later som det ikke kjenner deg mens du danser."
L["dislike.dance.3"] = "{pet} vender ryggen til til du er ferdig."
L["dislike.dance.race.nightelf.1"] = "{pet} har sett den nightelfdansen før. Altfor mange ganger."
L["dislike.fish.1"] = "{pet} rynker på nesen av fiskelukta."
L["dislike.fish.2"] = "{pet} synes fisking er det kjedeligste som finnes."
L["dislike.fish.3"] = "{pet} gjesper så kjeven knaker. Fortsatt ikke napp?"
L["dislike.mine.1"] = "{pet} hoster av steinstøvet."
L["dislike.mine.2"] = "{pet} holder for ørene mens du hakker løs på fjellet."
L["dislike.mine.3"] = "{pet} har fått grus mellom tærne og er sur."
L["dislike.skin.1"] = "{pet} snur seg bort mens du flår."
L["dislike.skin.2"] = "{pet} synes flåing er ekkelt."
L["dislike.skin.3"] = "{pet} later som det ikke ser noe som helst av skinningen."
L["dislike.fun.1"] = "{pet} himler med øynene av tullet ditt."
L["dislike.fun.2"] = "{pet} synes ikke du er så morsom som du tror."
L["dislike.fun.3"] = "{pet} ser på deg uten å si noe, lenge."

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
L["egg.midsummer.2"] = "{pet} danser rundt bålet med deg. God midtsommer!"
L["egg.harvest.1"] = "{pet} har funnet en kurv med epler. God Harvest Festival!"
L["egg.harvest.2"] = "{pet} sitter stille et øyeblikk og minnes heltene."
L["egg.hallowsend.1"] = "{pet} har fått en gresskarbøtte og vil gå på knask eller knep."
L["egg.hallowsend.2"] = "{pet} skvatt av en flaggermus. Det er Hallow's End!"
L["egg.winterveil.1"] = "{pet} rister på en pakke fra Greatfather Winter. Hva kan det være?"
L["egg.winterveil.2"] = "{pet} har fått en liten nisselue. God Winter Veil!"
L["egg.fredag13.1"] = "{pet} går i en stor bue rundt alle svarte katter i dag."
L["egg.dager.1"] = "{pet} og du har bodd sammen i {n} dager!"
L["egg.midnatt.1"] = "{pet} gjesper. Det er midnatt, vet du. Skal du opp tidlig i morgen?"
L["egg.midnatt.2"] = "{pet} lurer på om du aldri skal legge deg."
L["egg.midnatt.3"] = "{pet} har sovnet på tastaturet ditt. Hint, hint."
L["egg.midnatt.race.scourge.1"] = "{pet} vet at du ikke trenger søvn, men det gjør det."
L["egg.speil.1"] = "{pet} stirrer på {owner} sitt dyr. Er det et speil?"
L["egg.speil.2"] = "{pet} har møtt en av sitt eget slag, hos {owner}!"
L["egg.speil.3"] = "{pet} og {owner} sitt dyr gjør nøyaktig det samme, samtidig."
L["egg.paske.1"] = "{pet} har gjemt et påskeegg i bagen din. Kvikk Lunsj?"
L["egg.paske.2"] = "God påske! {pet} har lett etter påskeegg hele morgenen."
L["egg.klokka.1"] = "Klokka ble stilt i natt, og {pet} skjønner ikke når det er middag."
L["egg.mandag.1"] = "{pet} er sur. Det er mandag, og helgen er fem dager unna."
L["egg.morgen.1"] = "{pet} gnir søvnen ut av øynene. Så tidlig?"
L["egg.morgen.nattugle.1"] = "{pet} har ikke lagt seg ennå."
L["egg.morgen.2"] = "{pet} er ikke et morgendyr. Ikke snakk til det ennå."
-- Jumps (2026-11-19): a hundred in a day now and then, no number; a thousand in a day; ten thousand with your pet
L["egg.hopp.1"] = "{pet} puster tungt. All denne hoppingen tar på."
L["egg.hopp.2"] = "{pet} lurer på hvorfor du aldri kan gå som folk."
L["egg.hopp.hoppetass.1"] = "{pet} hopper i takt med deg. Dere er et lag!"
L["egg.tusenhopp.1"] = "Tusen hopp i dag! {pet} har lagt seg flat og nekter å reise seg."
L["egg.tusenhopp.2"] = "{pet} har talt med: tusen hopp i dag. Beina dens skjelver."
L["egg.tusenhopp.hoppetass.1"] = "Tusen hopp i dag, og {pet} er bare så vidt varm i trøya!"
L["egg.titusenhopp.1"] = "Ti tusen hopp sammen! {pet} ser på deg med noe som ligner på beundring."
L["egg.titusenhopp.2"] = "{pet} har fulgt deg gjennom ti tusen hopp. Det har aldri vært så spenstig."
L["egg.lur.1"] = "{pet} lurer på om dere har tenkt å bli her for godt."
L["egg.lur.2"] = "{pet} har flyttet inn i innet. Det har til og med fått eget teppe."
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
L["egg.kjenner.3"] = "{pet} logrer for {owner}. De har en historie, de to."
L["egg.fetter.1"] = "{pet} og {owner} sitt dyr snuser forsiktig på hverandre."
L["egg.fetter.2"] = "{pet} har truffet en fetter hos {owner}. Det er tydelig at de er i slekt."
L["egg.fetter.3"] = "{pet} og {owner} sitt dyr sammenligner ører. Helt likt, nesten."
L["egg.ener.1"] = "{pet} så terningen lande på 1 og prøver tappert å holde maska."
L["egg.ener.2"] = "{pet} ler så den hikster. En av hundre!"
L["egg.ener.3"] = "{pet} har aldri sett noen rulle så dårlig. Imponerende, egentlig."
L["egg.ener.4"] = "{pet} klapper deg trøstende. 1 er også et tall."
L["egg.ener.5"] = "{pet} legger terningen pent tilbake i esken. Den får hvile nå."
L["egg.fiskeflaks.1"] = "{pet} ser på deg, så på vannet, så på deg igjen."
L["egg.fiskeflaks.2"] = "{pet} lurer på om du har hørt om agn."
L["egg.fiskeflaks.3"] = "{pet} fniser. Fisken lo nok også."
L["egg.fiskeflaks.4"] = "{pet} tilbyr seg å hoppe uti og hente den neste selv."
L["egg.fiskeflaks.5"] = "{pet} lurer på om du og fisken har en avtale."
L["egg.hundre.1"] = "{pet} måper. Hundre av hundre!"
L["egg.hundre.2"] = "{pet} lurer på om terningen din er jukset med."
L["egg.hundre.3"] = "{pet} hopper av glede. Den visste du hadde flaks i deg!"
L["egg.hundre.4"] = "{pet} vil gjerne at du ruller for dem neste gang."
L["egg.hundre.5"] = "{pet} vil ha terningen din i gave. Den er heldig!"
L["egg.lilla.1"] = "{pet} stirrer på den lilla teksten med store øyne."
L["egg.lilla.2"] = "{pet} vil gjerne holde det episke itemet. Bare litt."
L["egg.lilla.3"] = "{pet} snuser på byttet. Det lukter episk."
L["egg.lilla.4"] = "{pet} har aldri sett noe så lilla før. Gratulerer!"
L["egg.lilla.5"] = "{pet} holder lilla-itemet mens du ser på stats. Forsiktig, forsiktig."
L["egg.lilla.class.paladin.1"] = "{pet} vet allerede at du kommer til å si at det er en oppgradering."
L["egg.lilla.class.hunter.1"] = "{pet} ser på det episke itemet og lurer på om det er til deg. Uansett hva det er."
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
L["egg.baalnaer.3"] = "{pet} drar deg mot bålet. Bare fem minutter?"
L["egg.baalvarm.1"] = "{pet} krøller seg sammen ved bålet og varmer potene."
L["egg.baalvarm.2"] = "{pet} har funnet den beste plassen ved bålet."
L["egg.baalvarm.eventyr.1"] = "{pet} tripper rundt bålet. Skal vi sitte her lenge?"
L["egg.baalvarm.eventyr.2"] = "{pet} ser seg over skulderen. Eventyret venter ikke!"
L["egg.baal.1"] = "{pet} er helt rolig. Bålkos er det beste den vet."
L["egg.baal.2"] = "{pet} har sovnet halvveis i bålvarmen."
L["egg.baal.eventyr.1"] = "{pet} har sittet stille lenge nok. Kom igjen, eventyret venter!"
L["egg.baal.eventyr.2"] = "{pet} kjeder seg. Ingen bosser i nærheten av et leirbål."
L["egg.baal.3"] = "{pet} forteller en spøkelseshistorie ved bålet. Den er ikke skummel i det hele tatt."
L["egg.sovepose.1"] = "{pet} sov som en stein i soveposen."
L["egg.sovepose.2"] = "{pet} vil ikke ut av soveposen ennå. Fem minutter til!"
L["egg.sovepose.eventyr.1"] = "{pet} var oppe før soloppgang og vil videre."
L["egg.sovepose.eventyr.2"] = "{pet} pakket ned soveposen før du våknet."
L["egg.sovepose.3"] = "{pet} har stjålet hele soveposen i løpet av natta."
L["egg.skravle.1"] = "{pet} lurer på om du har tenkt å puste snart. Så mye prat!"
L["egg.skravle.2"] = "{pet} har sovnet. Guildpraten din ble visst litt lang."
L["egg.skravle.3"] = "{pet} prøver å få et ord med i laget, men du snakker for fort."
L["egg.skravle.4"] = "{pet} har begynt å skrive ned alt du sier. Det er allerede tre bøker."
L["egg.kattefisk.1"] = "{pet} har allerede spist halve fangsten."
L["egg.kattefisk.2"] = "{pet} slikker seg rundt munnen. Hvilken fisk?"
L["egg.kattefisk.3"] = "{pet} har bestemt at denne fisken er middag. Dens middag."
L["egg.vinger.1"] = "{pet} mener den kunne fløyet dit raskere selv."
L["egg.vinger.2"] = "{pet} flakser ved siden av flightpathen og ser fornærmet ut."
L["egg.vinger.3"] = "{pet} skjønner ikke hvorfor dere må leie vinger."
L["egg.trofe.1"] = "{pet} tok med seg en liten bit av {boss} som minne."
L["egg.trofe.2"] = "{pet} har tatt med seg en knapp fra {boss}. Til samlingen."
L["egg.trofe.3"] = "{pet} poserer stolt ved siden av {boss}."
L["egg.dodsfall.1"] = "{pet} lurer på om det er trygt å bo hos deg."
L["egg.dodsfall.2"] = "{pet} har begynt å bære med seg et lite plaster, for sikkerhets skyld."
L["egg.dodsfall.3"] = "{pet} kjenner veien fra kirkegården bedre enn veien hjem nå."
L["egg.dodsfall.class.priest.1"] = "{pet} lurer på hvem som skal heale healeren."
L["egg.dodsfall.class.paladin.1"] = "{pet} lurer på hvorfor du ikke brukte bobla."
L["egg.dodsfall.class.hunter.1"] = "{pet} trodde du spilte død. Du gjorde visst ikke det."
L["egg.dodsfall.class.warlock.1"] = "{pet} synes demonen din kunne passet bedre på deg."
-- The damage meter after a boss kill in a group (Menagerie/Meter.lua)
L["egg.toppen.1"] = "{pet} jubler: Du gjorde mest skade! Bossen hadde ingen sjanse."
L["egg.toppen.2"] = "{pet} har sett på måleren. Du var best. Selvfølgelig."
L["egg.toppen.3"] = "{pet} sparrer i lufta for å vise hvordan du gjorde så mye skade."
L["egg.toppen.4"] = "{pet} forteller alle i nærheten hvem som gjorde mest skade."
L["egg.helter.1"] = "{pet} er stolt: Ingen healte mer enn deg!"
L["egg.helter.2"] = "{pet} holdt pusten hele kampen, men du holdt alle i live."
L["egg.helter.3"] = "{pet} har bestemt at du er raidets beste healer. Ingen protester."
L["egg.sparket.1"] = "{pet} nikker anerkjennende. Ingen fikk caste noe i fred i dag."
L["egg.sparket.2"] = "{pet} prøver å interrupte deg også. For moro skyld."
L["egg.sparket.3"] = "{pet} applauderer. Hver gang fienden castet, sa du nei."
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
L["egg.seilas.murloc.1"] = "{pet} lengter gurglende til havet. Mrgl..."
L["egg.seilas.reptile.1"] = "{pet} soler seg på dekk og ser etter krokodiller i vannet."
L["egg.seilas.bird.1"] = "{pet} sitter på masta og holder utkikk."
L["activity.zeppelin"] = "zeppelinerturer"
L["activity.boat"] = "båtturer"
L["activity.guildgroup"] = "selskap fra guilden" -- (2026-11-14: wishes for social pets, Wish.SOCIAL)
L["activity.guildpet"] = "dyrevenner fra guilden"
L["activity.playmate"] = "en lekeavtale"
L["activity.misses"] = "bom på rad" -- (eggs only: Quirks' bom and motstand)
L["activity.resisted"] = "trolldom som prellet av"
L["activity.wipe"] = "wipes" -- (eggs only: Quirks' wipe)
L["activity.routed"] = "tap i battlegrounds" -- (eggs only: Quirks' rumpejuling)
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
L["egg.ridning.2"] = "{pet} ser skeptisk på den nye mounten ditt."
L["egg.ridning.3"] = "{pet} har allerede bestemt seg: det skal løpe om kapp med mounten."
L["egg.maks.1"] = "{pet} har laget en liten krone til deg. Level 60!"
L["egg.maks.2"] = "{pet} danser rundt deg. Det visste hele tiden at du skulle klare det."
L["egg.trener.1"] = "{pet} prøver å lære seg det samme som deg. Det går ikke så bra."
L["egg.trener.2"] = "{pet} hilser høflig på treneren din."
L["egg.trener.3"] = "{pet} gjesper mens treneren forklarer. Igjen."
L["egg.trener.4"] = "{pet} prøver å se like klok ut som treneren."
L["egg.trener.class.hunter.1"] = "{pet} lurer på om treneren din lærer bort skills til dyr også."
L["egg.trener.class.warlock.1"] = "{pet} holder seg bak deg. Treneren din har rare venner."
L["egg.trener.class.mage.1"] = "{pet} prøver å snappe en av bøkene til treneren."
L["egg.talentbytte.1"] = "{pet} myser på deg. Er du den samme som i stad?"
L["egg.talentbytte.2"] = "{pet} merker at noe ved deg forandret seg."
L["egg.glemsel.1"] = "{pet} ser forvirret på deg. Kjenner det deg fortsatt igjen?"
L["egg.glemsel.2"] = "{pet} snuser grundig på deg, som for å sjekke at du fortsatt er deg."
L["egg.glemsel.3"] = "{pet} lurer på hvorfor du betalte for å glemme alt du kunne."
L["egg.oppdrag.1"] = "{pet} har hjulpet deg med {n} quests. Det fortjener en godbit!"
L["egg.oppdrag.2"] = "{pet} har vært med på {n} quests. Det vurderer å starte sitt eget questkontor."
-- A wipe: your whole group of five or more died (Activity "wipe"), said once you're up again; the boss by name
-- half the time when one was up (egg.wipe.boss, {boss}), else by nature. (2026-11-17: drafts, for the user to edit)
L["egg.wipe.1"] = "{pet} ser på hele gruppen som ligger strødd utover. Det der gikk ikke helt etter planen."
L["egg.wipe.2"] = "{pet} foreslår at dere prøver en gang til. Med en ny plan, kanskje?"
L["egg.wipe.3"] = "{pet} trodde Dyreparken var recovery-eksperter?"
L["egg.wipe.4"] = "{pet} går rundt og snuser på alle for å sjekke at de er like hele."
L["egg.wipe.5"] = "{pet} har skrevet en liten lapp: «Neste gang: ikke stå i ilden.»"
L["egg.wipe.6"] = "{pet} lurer på om dere gikk på en Brink."
L["egg.wipe.boss.1"] = "{pet} knurrer i retning {boss}. Neste gang!"
L["egg.wipe.boss.2"] = "{pet} har lært seg alt om {boss} nå. Det vet nøyaktig hvor dere skal stå."
L["egg.wipe.boss.3"] = "{pet} synes {boss} var frekk som tok hele gruppen på den måten."
L["egg.wipe.boss.4"] = "{pet} tror {boss} ler av dere nå. Skal nok få gliset sitt tørka av snart."
L["egg.wipe.trofast.1"] = "{pet} ble hos deg hele tiden, mens alle andre lå på bakken."
L["egg.wipe.skoyer.1"] = "{pet} gir gruppen en 10/10 for synkronisert død."
L["egg.wipe.latsabb.1"] = "{pet} synes dere like godt kan ta en pause nå, når dere først ligger der på bakken."
L["egg.wipe.eventyrlysten.1"] = "{pet} er allerede klar for neste forsøk. Kom igjen, opp med dere!"
L["egg.wipe.kjaelen.1"] = "{pet} gir alle i gruppen en klem, én etter én."
L["egg.wipe.ordensdyr.1"] = "{pet} vil gjerne snakke om hvem som sto hvor. Det har laget et kart."
L["egg.wipe.class.priest.1"] = "{pet} sier ingenting om healingen. Ingenting i det hele tatt."
L["egg.wipe.class.shaman.1"] = "{pet} ser forventningsfullt på deg. Var det ikke noe med en ankh?"
L["egg.wipe.class.shaman.2"] = "{pet} ankher dommen. Ankhlager du meg for noe? Jeg bankher deg!"
L["egg.wipe.class.warlock.1"] = "{pet} lurer på om du har en soulstone oppe. Bare lurer."
L["egg.wipe.class.paladin.1"] = "{pet} så bobla di. Den holdt ikke helt hele veien, nei."
L["egg.wipe.class.hunter.1"] = "{pet} lurer på om du spilte død litt for godt denne gangen."
-- Your battleground team routed: you died with more than three in four of it dead. (2026-11-17: drafts)
L["egg.rumpejuling.1"] = "{pet} har telt: nesten hele laget ligger på graveyarden. Dere får skikkelig juling."
L["egg.rumpejuling.2"] = "{pet} lurer på om det andre laget har tatt med seg hele byen sin."
L["egg.rumpejuling.3"] = "{pet} ser på resten av laget ved graveyarden. Ingen sier noe."
L["egg.rumpejuling.4"] = "{pet} foreslår å vente ved graveyarden til det er over. Bare en tanke."
L["egg.rumpejuling.5"] = "{pet} holder for øynene. Dette er ikke pent å se på."
L["egg.rumpejuling.skoyer.1"] = "{pet} har begynt å heie på det andre laget. Bare for å ha noen å heie på."
L["egg.rumpejuling.trofast.1"] = "{pet} står ved din side, selv nå. Særlig nå."
L["egg.rumpejuling.eventyrlysten.1"] = "{pet} nekter å gi seg. Ut og slåss igjen, alle sammen!"
L["egg.rumpejuling.latsabb.1"] = "{pet} har lagt seg ned ved graveyarden. Her er det rolig, ihvertfall."
-- ======== UTKAST 2026-11-17: magefamiliærer, for brukeren å redigere ========
-- A mage's familiar (Data/Familiars.lua: rat, frog, cat), from a scroll, out for its buff's hour. {pet}: its name.
-- No traits: lines by familiar (egg.<id>.<rat|frog|cat>.N) and for all of them (egg.<id>.N).
-- Arrival: the scroll read, the familiar appears (egg "tryllet").
L["egg.tryllet.1"] = "{pet} dukker opp i et lite blått glimt og ser seg forvirret rundt."
L["egg.tryllet.2"] = "{pet} er tryllet fram, og har tydeligvis ikke fått beskjed om hvorfor."
L["egg.tryllet.3"] = "{pet} kjenner etter i potene. Jo, alt er der. Ganske bra trylling."
L["egg.tryllet.4"] = "{pet} er på oppdrag i en time. Så er det tilbake til papiret."
L["egg.tryllet.rat.1"] = "{pet} snuser nysgjerrig på ryggsekken din. Har du ost oppi der?"
L["egg.tryllet.rat.2"] = "{pet} stikker snuten i været og klatrer opp på skulderen din for å se seg om."
L["egg.tryllet.frog.1"] = "{pet} lander med et lite plask, selv om det ikke er vann i nærheten."
L["egg.tryllet.frog.2"] = "{pet} kvekker en gang, høytidelig. Det er tydeligvis sånn man hilser."
L["egg.tryllet.cat.1"] = "{pet} strekker seg, gjesper, og later som den har vært her hele tiden."
L["egg.tryllet.cat.2"] = "{pet} ser på deg som om det var du som ble tryllet fram."
-- The buff's end: it fades, your own pet comes back (egg "poff").
L["egg.poff.1"] = "{pet} vinker farvel og forsvinner i et lite blått poff."
L["egg.poff.2"] = "{pet} blir mer og mer gjennomsiktig. Det var en fin time!"
L["egg.poff.3"] = "{pet} er ferdig for i dag. Trylleriet tar slutt, men minnene blir."
L["egg.poff.4"] = "{pet} bukker dypt før den blir til glitter."
L["egg.poff.rat.1"] = "{pet} rekker å knaske en siste smule før den blir borte."
L["egg.poff.frog.1"] = "{pet} tar et siste hopp og lander ingen steder."
L["egg.poff.cat.1"] = "{pet} går uten å se seg tilbake. Typisk katt."
L["egg.poff.cat.2"] = "{pet} forsvinner, og gjør et poeng ut av å vise at den ikke bryr seg."
-- The pet kept out (Med deg) waits its turn while the familiar is out ({friend}: its name; egg "vikar").
L["egg.vikar.1"] = "{pet} lover å passe godt på deg til {friend} kommer tilbake."
L["egg.vikar.2"] = "{pet} er bare vikar. {friend} har nok ikke glemt deg."
L["egg.vikar.3"] = "{pet} har fått en lang liste med beskjeder fra {friend}. Den første: ikke glem kosen."
L["egg.vikar.rat.1"] = "{pet} har funnet {friend} sin matskål. Den er tom nå."
L["egg.vikar.frog.1"] = "{pet} prøver å sitte på plassen til {friend}. Den er litt for tørr."
L["egg.vikar.cat.1"] = "{pet} har allerede tatt over senga til {friend}."
-- ======== slutt på utkast ========
-- Five swings missed in a row, three spells resisted in a row (2026-11-14; edited by the user)
L["egg.bom.1"] = "{pet} teller: fem bom på rad. Kanskje du trenger briller?"
L["egg.bom.2"] = "{pet} lurer på om du sikter på lufta med vilje."
L["egg.bom.3"] = "{pet} ser på våpenet ditt, så på deg. Holder du det riktig?"
L["egg.bom.skoyer.1"] = "{pet} ler så den nesten faller om. Fem bom! Fem!"
L["egg.bom.rampete.1"] = "{pet} viser deg hvordan man gjør det: rett i leggen."
L["egg.bom.kjaelen.1"] = "{pet} klapper deg på beinet. Det går bedre neste gang."
L["egg.bom.eventyrlysten.1"] = "{pet} er utålmodig. Treff noe, da!"
L["egg.bom.latsabb.1"] = "{pet} gjesper. Si fra når du treffer noe."
L["egg.bom.class.warrior.1"] = "{pet} foreslår at du prøver den skarpe enden."
L["egg.bom.class.rogue.1"] = "{pet} lurer på om du sikter på skyggene i stedet for fienden."
L["egg.motstand.1"] = "{pet} ser spellsene din prelle av, tre ganger på rad. Den fienden var sta!"
L["egg.motstand.2"] = "{pet} lurer på om fienden ikke tror på magi."
L["egg.motstand.skoyer.1"] = "{pet} fniser. Tre ganger sa fienden nei takk!"
L["egg.motstand.oppdager.1"] = "{pet} vil vite hvordan fienden blåser av seg spellsene sånn."
L["egg.motstand.kjaelen.1"] = "{pet} trøster deg. Spellsene var fine, selv om den ikke funket så bra."
L["egg.motstand.ordensdyr.1"] = "{pet} synes det er urettferdig. Man kan ikke bare motstå magi!"
L["egg.motstand.class.mage.1"] = "{pet} foreslår å prøve en annen magiskole. Ild, kanskje?"
L["egg.motstand.class.warlock.1"] = "{pet} lurer på om fienden har en sterkere pakt enn deg."
-- Class reactions (Menagerie/Reactions.lua, 2026-11-14): your pet reacts to what your class does. react.<id>.N,
-- and by nature react.<id>.<trait|family>.N. Drafts, edited by the user 2026-11-14.
-- Warrior
L["react.krigsrop.1"] = "{pet} hopper høyt da du brøler Battle Shout. Så skummel du er!"
L["react.krigsrop.2"] = "{pet} holder seg for ørene. Må du rope så høyt?"
L["react.krigsrop.3"] = "{pet} retter seg opp og ser modig ut, akkurat som deg."
L["react.krigsrop.latsabb.1"] = "{pet} våkner med et rykk av ropet ditt og ser fornærmet på deg."
L["react.krigsrop.pratsom.1"] = "{pet} svarer med et lite krigsrop av sitt eget. Pip!"
L["react.krigsrop.kjaelen.1"] = "{pet} gjemmer seg bak beinet ditt til ekkoet har lagt seg."
L["react.krigsrop.4"] = "{pet} prøver å rope det samme. Det blir et lite pip."
L["react.krigsrop.race.orc.1"] = "{pet} kjenner orkeblodet i ropet ditt. Lok'tar!"
L["react.krigsrop.race.dwarf.1"] = "{pet} hører ekkoet rulle som i en gruvegang."
L["react.stansdans.1"] = "{pet} prøver å følge med på alle stancene dine og blir helt svimmel."
L["react.stansdans.2"] = "{pet} lurer på om dette er en ny dans."
L["react.stansdans.hoppetass.1"] = "{pet} hopper fra side til side i takt med stancebyttene dine. For en dans!"
L["react.stansdans.latsabb.1"] = "{pet} legger seg ned. Si fra når du har bestemt deg for stance."
L["react.stansdans.3"] = "{pet} har gitt opp å følge med på hvilken stance du står i."
L["react.blodraseri.1"] = "{pet} ser bekymret på deg. Gjorde det vondt?"
L["react.blodraseri.2"] = "{pet} skjønner ikke hvorfor du blir sint helt uten grunn."
L["react.blodraseri.kjaelen.1"] = "{pet} kryper inntil deg for å trøste. Ikke gjør deg selv vondt!"
L["react.blodraseri.trofast.1"] = "{pet} stiller seg foran deg, klar til å forsvare deg mot deg selv."
-- Rogue
L["react.lommetyv.1"] = "{pet} later som den ikke så noe som helst."
L["react.lommetyv.2"] = "{pet} kikker nysgjerrig på hva du fant i lomma der."
L["react.lommetyv.roverdyr.1"] = "{pet} gnir labbene. Hva fikk vi? Hva fikk vi?"
L["react.lommetyv.ordensdyr.1"] = "{pet} ser forferdet på deg. Det der er ikke lov!"
L["react.lommetyv.sjorover.1"] = "{pet} vil ha sin del av byttet. Det er piratloven!"
L["react.lommetyv.3"] = "{pet} holder vakt mens du tømmer lommene."
L["react.lasedirk.1"] = "{pet} holder pusten mens du dirker. Hva er inni?"
L["react.lasedirk.2"] = "{pet} hører det klikker i låsen og blir helt spent."
L["react.lasedirk.sjorover.1"] = "{pet} lukter skatt. En kiste er en kiste!"
L["react.lasedirk.oppdager.1"] = "{pet} må bare se hva som skjuler seg der inne."
L["react.spurt.1"] = "{pet} spurter etter deg så fort beina bærer."
L["react.spurt.2"] = "{pet} roper etter deg: vent på meg!"
L["react.spurt.hoppetass.1"] = "{pet} tar utfordringen og løper om kapp med deg!"
L["react.spurt.latsabb.1"] = "{pet} nekter å løpe. Den kommer etter, i sitt eget tempo."
L["react.spurt.3"] = "{pet} kommer pesende etter. Hvor skulle du så fort?"
-- Hunter
L["react.spilldod.1"] = "{pet} legger seg ned og spiller død, akkurat som deg."
L["react.spilldod.2"] = "{pet} dytter forsiktig borti deg. Lever du?"
L["react.spilldod.trofast.1"] = "{pet} ble livredd da du falt om. Ikke gjør det der igjen!"
L["react.spilldod.skoyer.1"] = "{pet} synes du spiller død så bra at den vil lære det."
L["react.spilldod.3"] = "{pet} ser seg rundt. Gikk fienden på den?"
L["react.mating.1"] = "{pet} ser misunnelig på kjæledyret ditt som får mat."
L["react.mating.2"] = "{pet} lurer på om det blir noe til den også."
L["react.mating.glupsk.1"] = "{pet} tigger med store øyne. Det store dyret fikk jo mat!"
L["react.mating.3"] = "{pet} synes kjæledyret ditt får altfor mange godbiter."
L["react.sjalusi.1"] = "{pet} ser på deg mens du temmer et nytt dyr. Skal du bytte den ut?"
L["react.sjalusi.2"] = "{pet} er ikke sikker på om den liker det nye dyret ditt."
L["react.sjalusi.trofast.1"] = "{pet} snur seg bort, såret. Er ikke den god nok lenger?"
L["react.sjalusi.kjaelen.1"] = "{pet} trenger ekstra kos etter dette. Du lovet at den var favoritten!"
L["react.sjalusi.einstoing.1"] = "{pet} sukker. Enda en til i flokken."
L["react.gepard.1"] = "{pet} prøver å holde følge nå som du løper som en gepard."
L["react.gepard.2"] = "{pet} kjenner farten i potene."
L["react.gepard.hoppetass.1"] = "{pet} elsker farten! Fortere, fortere!"
L["react.gepard.latsabb.1"] = "{pet} vil heller bli båret."
L["react.gepard.3"] = "{pet} har vind i pelsen og et stort smil."
-- Warlock
L["react.demonen.imp.1"] = "{pet} holder seg for ørene. Den impen slutter aldri å prate."
L["react.demonen.imp.2"] = "{pet} og impen ser stygt på hverandre."
L["react.demonen.voidwalker.1"] = "{pet} gjemmer seg bak den store, mørke skyggen din."
L["react.demonen.voidwalker.2"] = "{pet} lurer på om voidwalkeren vil være venner."
L["react.demonen.succubus.1"] = "{pet} er sjalu. Hvem er hun?"
L["react.demonen.succubus.2"] = "{pet} synes ikke noe om den nye følgesvennen din."
L["react.demonen.felhunter.1"] = "{pet} vil leke med felhunteren, men er litt redd for tentaklene."
L["react.demonen.felhunter.2"] = "{pet} snuser forsiktig på felhunteren. Den snuser tilbake."
L["react.demonen.demon.1"] = "{pet} føler seg hjemme. Endelig noen fra familien!"
L["react.demonen.demon.2"] = "{pet} hilser på demonen din som en gammel venn."
L["react.helsestein.1"] = "{pet} ser på den grønne steinen og lurer på om den kan spises."
L["react.helsestein.2"] = "{pet} prøver å smake på healthstonen din."
L["react.helsestein.glupsk.1"] = "{pet} prøver å spise helsesteinen. Den smaker stein."
L["react.helsestein.3"] = "{pet} lurer på hvorfor steinen er grønn. Er den ikke sunn?"
L["react.inferno.1"] = "{pet} skjelver av skrekk når infernalen krasjer ned."
L["react.inferno.2"] = "{pet} gjemmer seg så langt unna flammene den kommer."
L["react.inferno.balkos.1"] = "{pet} kommer nærmere for å varme seg. For et bål den infernalen er!"
-- Mage
L["react.trylleskaffet.1"] = "{pet} snapper etter smulene fra maten du trylla fram."
L["react.trylleskaffet.2"] = "{pet} er imponert. Mat fra løse lufta!"
L["react.trylleskaffet.glupsk.1"] = "{pet} tigger om den første biten. Du kan jo bare trylle mer!"
L["react.trylleskaffet.3"] = "{pet} lurer på om du kan trylle frem godbiter også."
L["react.trylleskaffet.race.gnome.1"] = "{pet} ser at du trylla fram mat på størrelse med deg selv."
L["react.sau.1"] = "{pet} ser på sauen og lurer på hvor fienden ble av."
L["react.sau.2"] = "{pet} prøver å leke med sauen."
L["react.sau.farm.1"] = "{pet} hilser på sin nye fetter. Bæ!"
L["react.sau.reptile.1"] = "{pet} er sikker på at den skilpadden er i slekt med den."
L["react.sau.rabbit.1"] = "{pet} gjemmer seg. Hva om du gjør den om til en sau også?"
L["react.sau.3"] = "{pet} teller sauer. Én. Og så er fienden tilbake."
L["react.portal.1"] = "{pet} kikker inn i portalen. Hvor skal vi?"
L["react.portal.2"] = "{pet} holder seg tett inntil deg gjennom den magiske portalen."
L["react.portal.hjemlengsel.1"] = "{pet} elsker portaler. Rett hjem!"
L["react.portal.reiseglad.1"] = "{pet} hopper av glede. Et nytt sted!"
L["react.portal.3"] = "{pet} hopper gjennom først, for å sjekke at det er trygt."
L["react.fallskjerm.1"] = "{pet} svever ned ved siden av deg som en fjær."
L["react.fallskjerm.2"] = "{pet} synes det kiler i magen å falle så sakte."
L["react.fallskjerm.skybaren.1"] = "{pet} er stolt. Endelig flyr du litt, du også!"
L["react.fallskjerm.bird.1"] = "{pet} viser deg hvordan man egentlig gjør det. Med vinger!"
L["react.fallskjerm.owl.1"] = "{pet} glir stille ved siden av deg. Ikke dårlig, for en uten fjær."
L["react.fallskjerm.3"] = "{pet} ser ned. Så langt det er!"
-- Priest
L["react.svev.1"] = "{pet} ser forbløffet på at du svever."
L["react.svev.2"] = "{pet} prøver å sveve, men blir på bakken."
L["react.svev.skybaren.1"] = "{pet} svever med deg. Er det ikke herlig her oppe?"
L["react.svev.hjemlengsel.1"] = "{pet} vil ned igjen. Bakken er tryggest."
L["react.svev.3"] = "{pet} lurer på om det kan gå på vann også, nå."
L["react.skyggeform.1"] = "{pet} ser på deg og lurer på hvor fargene dine ble av."
L["react.skyggeform.2"] = "{pet} synes du ser litt skummel ut nå."
L["react.skyggeform.ordensdyr.1"] = "{pet} rynker på nesen. Er det der virkelig lov for en prest?"
L["react.skyggeform.kjaelen.1"] = "{pet} kryper bort. Den vil ha deg tilbake slik du var."
L["react.skyggeform.spirit.1"] = "{pet} føler seg hjemme i skyggene dine."
L["react.indreild.1"] = "{pet} ser på lyset rundt deg med store øyne."
L["react.indreild.2"] = "{pet} kjenner varmen fra den indre ilden din."
L["react.indreild.balkos.1"] = "{pet} kryper inntil deg for å varme seg ved gløden din."
L["react.indreild.vinterpels.1"] = "{pet} holder seg litt unna. Det blir for varmt!"
L["react.indreild.3"] = "{pet} varmer potene i gløden din."
-- Paladin
L["react.boblehjem.1"] = "{pet} kan ikke tro det. Bubble HS? Klassisk!"
L["react.boblehjem.2"] = "{pet} ser seg tilbake mot fiendene du lot stå igjen."
L["react.boblehjem.skoyer.1"] = "{pet} applauderer. Det eldste paladintrikset i boka!"
L["react.boblehjem.ordensdyr.1"] = "{pet} skammer seg på dine vegne. En paladin flykter ikke!"
L["react.stridshest.1"] = "{pet} ser opp på den store hesten din med ærefrykt."
L["react.stridshest.2"] = "{pet} holder god avstand til de store hovene."
L["react.stridshest.farm.1"] = "{pet} prøver å hilse på hesten, men den er altfor fin for gården."
L["react.stridshest.3"] = "{pet} vil gjerne sitte på. Bare en liten tur."
L["react.stridshest.race.dwarf.1"] = "{pet} lurer på hvordan du kommer deg opp på den hesten."
L["react.velsignet.1"] = "{pet} kjenner velsignelsen og står litt rakere."
L["react.velsignet.2"] = "{pet} synes du skinner litt nå."
L["react.velsignet.ordensdyr.1"] = "{pet} retter seg opp. Nå er vi velsignet og ordentlige!"
L["react.velsignet.3"] = "{pet} blunker mot det fine lyset."
-- Druid
L["react.kattedyr.1"] = "{pet} ser på deg i katteform. Er det fortsatt deg?"
L["react.kattedyr.2"] = "{pet} prøver å kose med den nye pelsen din."
L["react.kattedyr.cat.1"] = "{pet} maler og gnir seg mot deg. Endelig en ordentlig katt!"
L["react.kattedyr.rodent.1"] = "{pet} blir nervøs. Du ser plutselig veldig sulten ut."
L["react.kattedyr.bird.1"] = "{pet} flakser opp på trygg avstand. Katter og fugler, du vet."
L["react.kattedyr.frog.1"] = "{pet} hopper unna. Den vet hva katter gjør med frosker."
L["react.kattedyr.3"] = "{pet} ser at du har fått værhår. Kler deg."
L["react.bjornemor.1"] = "{pet} ser opp på den store bjørnen. Wow."
L["react.bjornemor.2"] = "{pet} gjemmer seg under den varme pelsen din."
L["react.bjornemor.bear.1"] = "{pet} løper bort til deg. Mamma?"
L["react.bjornemor.3"] = "{pet} prøver å klatre opp på ryggen din."
L["react.bjornemor.race.tauren.1"] = "{pet} er ikke sikker på hva som var størst: tauren eller bjørn."
L["react.kjempeugle.1"] = "{pet} vet ikke hva den skal tro om den store, rare fuglen."
L["react.kjempeugle.2"] = "{pet} myser på deg. Er du en ugle nå?"
L["react.kjempeugle.nattugle.1"] = "{pet} hoer begeistret mot deg. Nattens største ugle!"
L["react.kjempeugle.owl.1"] = "{pet} er full av ærefrykt. En ugle på størrelse med et hus!"
L["react.moonglade.1"] = "{pet} kjenner roen i Moonglade straks dere er framme."
L["react.moonglade.2"] = "{pet} ser seg om i den stille lysningen."
L["react.moonglade.owl.1"] = "{pet} er hjemme! Uglene i Moonglade hoer velkommen."
L["react.moonglade.spirit.1"] = "{pet} svever av glede. Det er så fredelig her."
-- Shaman
L["react.spokelsesulv.1"] = "{pet} løper ved siden av ghostwolfen din."
L["react.spokelsesulv.2"] = "{pet} synes du ser litt skummel ut som ulv."
L["react.spokelsesulv.wolf.1"] = "{pet} uler med deg. Flokken løper sammen!"
L["react.spokelsesulv.rabbit.1"] = "{pet} skvetter. En ulv! Å, det er bare deg."
L["react.spokelsesulv.farm.1"] = "{pet} holder seg nær deg, men ikke for nær. Ulver er ulver."
L["react.spokelsesulv.3"] = "{pet} løper om kapp med deg, og taper."
L["react.spokelsesulv.race.tauren.1"] = "{pet} tenker at en tauren-ulv må være den største ulven i verden."
L["react.totemer.1"] = "{pet} snuser på totemet ditt."
L["react.totemer.2"] = "{pet} lurer på hva den rare pinnen i bakken gjør."
L["react.totemer.handverker.1"] = "{pet} studerer totemet nøye. Fint håndverk!"
L["react.totemer.cat.1"] = "{pet} setter seg på toppen av totemet ditt. Det er dens plass nå."
L["react.totemer.3"] = "{pet} plasserer en pinne ved siden av totemet ditt. Nå har det et også."
L["react.totemhage.1"] = "{pet} ser på alle totemene dine. En hel hage!"
L["react.totemhage.2"] = "{pet} løper rundt mellom totemene og leker gjemsel."
L["react.astral.1"] = "{pet} blir med deg hjem i et glimt av stjernelys."
L["react.astral.2"] = "{pet} gnir øynene etter turen hjem gjennom stjernene."
L["react.astral.hjemlengsel.1"] = "{pet} hopper av glede. Tar stjerneveien hjem igjen!"
L["react.forfedre.1"] = "{pet} ser med store øyne på mens du drar noen tilbake fra dødsriket."
L["react.forfedre.2"] = "{pet} er veldig glad for at det ikke var den som lå der."
L["react.forfedre.trofast.1"] = "{pet} vet at du ville gjort det samme for den. Alltid."
L["react.forfedre.spirit.1"] = "{pet} vinker farvel til ånden som fikk dra tilbake til kroppen sin."
L["react.renselse.1"] = "{pet} så buffene fly av fienden. Borte vekk!"
L["react.renselse.2"] = "{pet} synes det var litt frekt å ta fra noen buffene deres."
L["react.renselse.skoyer.1"] = "{pet} fniser. Du blåste buffen rett av dem!"
L["react.renselse.rampete.1"] = "{pet} vil også lære det trikset der."
L["react.krigsstamp.1"] = "{pet} kjente bakken riste under labbene."
L["react.krigsstamp.2"] = "{pet} rister støvet av seg etter stampet ditt."
L["react.krigsstamp.hoppetass.1"] = "{pet} hoppet rett opp i lufta. Igjen! Gjør det igjen!"
L["react.krigsstamp.rabbit.1"] = "{pet} skvatt så den nesten løp sin vei. For et stamp!"
L["react.krigsstamp.rodent.1"] = "{pet} trodde det var jordskjelv og gjemte seg."

------------------------------------------------------------------------------
-- The pet journal: list tooltips and the world tooltip
------------------------------------------------------------------------------
L["tip.free"] = "Dyreparken: trenger et hjem"
L["list.nick"] = "«{nick}»"                               -- after the species' name in the list
L["tip.nick"] = "Kallenavn: «{nick}»"
L["tip.named_by"] = "Navngitt av {who}, {date}"           -- {who}: a name, or home.you
L["tip.yours"] = "Ditt bånd: {label}"                      -- your own, with a pet someone else holds (or nobody)
L["tip.bond"] = "Bånd: {label}"                           -- {label}: bond.label
L["tip.world"] = "Dyreparken: {home} · {level}"           -- {home} starts with a small letter here

------------------------------------------------------------------------------
-- The pet card
------------------------------------------------------------------------------
L["card.free"] = "Trenger et hjem"
L["card.no_guild"] = "Ingen guild"
L["card.guild.none"] = "Du er ikke i en guild. Dyreparken er guildens: der adopterer dere dyr, og alle ser hvem de bor hos."
L["card.likes"] = "Liker {list}"
L["card.likes.tip"] = "Liker: {list}"
L["card.adopt"] = "Adopter"
L["card.letgo"] = "Gi slipp"
L["card.adopt.no_guild"] = "Adopsjon skjer i en guild: dyret blir guildens, og alle ser hvem det bor hos. Bli med i en guild, så kan du adoptere. Båndet med dyrene dine vokser likevel."
-- The settings page (Menagerie/Settings.lua: a cog in the journal's title bar)
L["settings.title"] = "Innstillinger"
L["settings.char"] = "Gjelder bare denne karakteren."
L["settings.char.head"] = "(denne karakteren)"
L["settings.back"] = "Tilbake"
L["settings.options.title"] = "Dyreparken"        -- its name in Blizzard's options (Esc > Options > AddOns)
L["settings.head.pet"] = "Dyret ditt"
L["settings.head.guild"] = "Guilden"
L["settings.head.chat"] = "Chatten og verden"
L["settings.head.card"] = "Dyrekortet"
L["settings.autosummon"] = "Ta med dyret ut automatisk"
L["settings.autosummon.tip"] = "Summoner dyret du har valgt med «Med deg» når du er klar: etter loading screens, combat og når du går av mounten ditt."
L["settings.mute"] = "Demp lyden av summons"
L["settings.mute.tip"] = "Lydeffekten når et dyr kommer ut, også når spillet summoner det tilbake selv."
L["settings.announce"] = "Fortell guilden når du adopterer eller gir navn"
L["settings.announce.tip"] = "En linje i guildchatten når du adopterer et dyr eller gir det kallenavn, og når du gratulerer fra en kake."
L["settings.achnotify"] = "Fortell andre med Dyreparken om prestasjonene dine"
L["settings.achnotify.tip"] = "Guildmedlemmer med Dyreparken får en linje når du får en prestasjon. Ingenting i guildchatten."
L["settings.achothers"] = "Vis andres prestasjoner"
L["settings.achothers.tip"] = "En linje i chatten når noen i guilden med Dyreparken får en prestasjon."
L["settings.chatframe"] = "Chatvinduet Dyreparken skriver i:"
L["settings.chatframe.tip"] = "Hvilket av chatvinduene dine linjene fra Dyreparken kommer i. Finnes ikke vinduet lenger, kommer de i hovedvinduet."
L["settings.chatframe.n"] = "Vindu {n}"
L["settings.chatter"] = "Småting i chatten"
L["settings.chatter.tip"] = "Hvor mye dyret ditt sier: påskeegg, ting det ikke liker, ting det elsker og første ganger sammen. Ingenting: de skjer og teller like fullt, bare uten linje. Litt: sjeldnere, så du finner færre påskeegg. Mye: oftere, men påskeeggene er like sjeldne. Dette vises alltid: nye levels, når dagen er full for dyret du har adoptert, prestasjoner (andres kan slås av under Guilden) og merkedager."
L["settings.chatter.none"] = "Ingenting"
L["settings.chatter.few"] = "Litt"
L["settings.chatter.normal"] = "Vanlig"
L["settings.chatter.many"] = "Mye"
L["settings.hearts"] = "Hjerter og gnister"
L["settings.hearts.tip"] = "Hjerter når du holder musen over et kjæledyr i verden, og gnister ved chatten."
L["settings.head.park"] = "Parken"
L["settings.hideunknown"] = "Skjul ukjente dyr"
L["settings.hideunknown.tip"] = "Dyr ingen i guilden har ennå, vises som et spørsmålstegn i Parken."
L["settings.particles"] = "Partikler på kortet:"
L["settings.particles.tip"] = "Blader, bobler, stjerner og alt det andre som svever rundt dyret."
L["settings.particles.all"] = "Alle"
L["settings.particles.few"] = "Færre"
L["settings.particles.none"] = "Ingen"
L["settings.moves"] = "Animasjoner"
L["settings.moves.tip"] = "Det sover om natten, setter seg, hopper når du klikker, går og løper med deg."
L["settings.celebrate"] = "Feiring på kortet ved nytt level"
L["settings.petsounds"] = "Lyder fra dyrene"
L["settings.petsounds.tip"] = "Dyret lager en lyd når du klikker på det på kortet."
L["settings.head.frame"] = "Dyret på skjermen"
L["settings.petframe"] = "Vis dyret ditt på skjermen"
L["settings.petframe.tip"] = "Dyret du har ute, eller det du har med deg, også når du rir eller flyr, med navnet og båndet deres, på skjermen. Det beveger seg som på kortet. Flytt det og endre størrelsen i Edit Mode; et klikk åpner dyrekortet."
L["settings.petframeart"] = "Bakgrunn og ramme rundt dyret"
L["settings.petframecombat"] = "Skjul dyret i combat"
L["settings.petframecombat.tip"] = "Dyret forsvinner fra skjermen når du går i combat, og kommer tilbake etterpå."
L["settings.petframefade"] = "Ton ned dyret når ingenting skjer"
L["settings.petframefade.tip"] = "Dyret er svakt på skjermen, og blir helt synlig når du holder musen over det, når båndet ditt vokser eller når det får et nytt level."
L["settings.petframealpha"] = "Synlighet når det er tonet ned"
L["settings.petframealpha.tip"] = "Hvor synlig dyret er når ingenting skjer."
L["settings.petframeart.tip"] = "Steinbakgrunn og ramme som på vinduene i spillet. Av: kun dyret og navnet på skjermen."
L["petframe.tip"] = "Klikk for å se dyret."
L["petframe.today"] = "I dag: {n} av {max} båndpoeng"
-- (2026-11-13: a draft, for the user to edit) A click on the pet frame with the Pets page closed.
L["petframe.open_hint"] = "Åpne pet-samlingen, så viser jeg {pet}."
-- (2026-11-13: drafts) The window opened (or was open) on another page; a click in combat.
L["petframe.tab_hint"] = "Bytt til Pets-fanen, så viser jeg kortet til {pet}."
L["petframe.combat_hint"] = "Kortet til {pet} kommer når combat er over."
L["petframe.name"] = "Dyreparken: dyret ditt"
L["petframe.edit"] = "Dyreparken: dyret ditt\nDra for å flytte, scroll for størrelse ({pct}%)"
L["settings.celebrate.tip"] = "Lys, gnister og en lyd når båndet ditt med dyret når et nytt level."
L["card.nick"] = "Kallenavn"
L["card.nick.locked"] = "Du kan gi det et kallenavn når båndet deres er {level} (level {n})."
L["card.nick.clearable"] = "Navnet det har nå, kan du fjerne allerede: la feltet stå tomt."
L["personality.unknown"] = "Ukjent personlighet"            -- nobody in the guild has it (Owners), you neither
L["personality.unknown.tip"] = "Personligheten er en overraskelse. Den blir kjent når du eller noen i guilden har dyret."
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
L["card.out.frame_hint"] = "Vil du ha dyret på skjermen? Slå det på under ⚙ Innstillinger («Vis dyret ditt på skjermen»)."
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
L["bond.tip.yours"] = "Ditt bånd med dyret: {level} (level {n}), {p} poeng."
L["bond.tip.how"] = "Vokser for hver dag dyret er ute med deg, og raskere når dere gjør noe det liker."
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
-- (a chip's count from 1000 on, Stats.Short: "1,1k"; the tooltip says it in full)
L["stats.short.k"] = "{n}k"
L["stats.short.M"] = "{n}M"
L["stats.decimal"] = ","
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
-- Today's wish on the card, its own words (2026-11-14, the user: "a little more flavor"): one of these all day
-- (Wish.Line), else wish.line. Edited by the user the same day.
L["wish.say.boss.1"] = "{pet} vil se en boss daue i dag"
L["wish.say.boss.2"] = "{pet} drømmer om en skikkelig boss-fight"
L["wish.say.boss.3"] = "{pet} er klar for en sterk boss i dag"
L["wish.say.quest.1"] = "{pet} vil hjelpe noen med et quest i dag"
L["wish.say.quest.2"] = "{pet} lurer på hva questgiverne trenger i dag"
L["wish.say.quest.3"] = "{pet} vil fullføre et quest med deg i dag"
L["wish.say.taxi.1"] = "{pet} vil fly over skyene i dag"
L["wish.say.taxi.2"] = "{pet} drømmer om en flytur"
L["wish.say.taxi.3"] = "{pet} vil se verden ovenfra i dag"
L["wish.say.pvp.1"] = "{pet} vil kjempe mot den andre siden i dag"
L["wish.say.pvp.2"] = "{pet} er i slossehumør: PvP i dag!"
L["wish.say.pvp.3"] = "{pet} vil vise motstanderne hvem dere er"
L["wish.say.herb.1"] = "{pet} vil snuse på blomster i dag"
L["wish.say.herb.2"] = "{pet} drømmer om ferske urter"
L["wish.say.herb.3"] = "{pet} vil plukke herbs med deg i dag"
L["wish.say.mine.1"] = "{pet} vil grave etter malm i dag"
L["wish.say.mine.2"] = "{pet} drømmer om noe som glitrer i fjellet"
L["wish.say.mine.3"] = "{pet} vil høre hakka klinge i dag"
L["wish.say.fish.1"] = "{pet} drømmer om fersk fisk i dag"
L["wish.say.fish.2"] = "{pet} vil sitte ved vannet og fiske"
L["wish.say.fish.3"] = "{pet} har på følelsen av at vi får napp i dag"
L["wish.say.skin.1"] = "{pet} vil være med på skinning i dag"
L["wish.say.skin.2"] = "{pet} vil se deg flå noe i dag"
L["wish.say.skin.3"] = "{pet} drømmer om et fint stykke lær"
L["wish.say.explore.1"] = "{pet} vil se et nytt sted i dag"
L["wish.say.explore.2"] = "{pet} lengter etter noe den ikke har sett"
L["wish.say.explore.3"] = "{pet} vil på oppdagelsesferd i dag"
L["wish.say.skill.1"] = "{pet} vil se deg bli flinkere til noe i dag"
L["wish.say.skill.2"] = "{pet} vil at du skal øve på et håndverk"
L["wish.say.skill.3"] = "{pet} heier på en skill-up i dag"
L["wish.say.rep.1"] = "{pet} vil gjøre et godt inntrykk i dag (rep)"
L["wish.say.rep.2"] = "{pet} vil at dere skal bli bedre likt et sted"
L["wish.say.rep.3"] = "{pet} vil samle rep med deg i dag"
L["wish.say.dance.1"] = "{pet} vil danse med deg i dag"
L["wish.say.dance.2"] = "{pet} har lyst til å svinge seg"
L["wish.say.dance.3"] = "{pet} tripper etter en dans"
L["wish.say.cuddle.1"] = "{pet} vil bli kost med i dag"
L["wish.say.cuddle.2"] = "{pet} trenger en klem i dag"
L["wish.say.cuddle.3"] = "{pet} ser på deg med store øyne: kos?"
L["wish.say.chat.1"] = "{pet} vil høre deg prate i guilden i dag"
L["wish.say.chat.2"] = "{pet} vil at du skal si hei til guilden"
L["wish.say.chat.3"] = "{pet} er nysgjerrig på guildpraten i dag"
L["wish.say.dive.1"] = "{pet} vil dykke i dag"
L["wish.say.dive.2"] = "{pet} drømmer om dypt vann"
L["wish.say.dive.3"] = "{pet} vil holde pusten under vann med deg i dag"
L["wish.say.nap.1"] = "{pet} vil ta en liten nap i byen i dag"
L["wish.say.nap.2"] = "{pet} gjesper: en kvil i byen?"
L["wish.say.nap.3"] = "{pet} drømmer om en chill stund i byen"
L["wish.say.hearth.1"] = "{pet} vil dra hjem i dag"
L["wish.say.hearth.2"] = "{pet} savner inn-et"
L["wish.say.hearth.3"] = "{pet} vil sove i sin egen seng i natt"
L["wish.say.jump.1"] = "{pet} vil hoppe i dag"
L["wish.say.jump.2"] = "{pet} har sprett i beina i dag"
L["wish.say.jump.3"] = "{pet} vil hoppe og sprette med deg"
L["wish.say.camp.1"] = "{pet} vil sitte ved et leirbål i dag"
L["wish.say.camp.2"] = "{pet} drømmer om et knitrende bål"
L["wish.say.camp.3"] = "{pet} vil varme seg ved bålet i dag"
L["wish.say.rested.1"] = "{pet} vil sove i sovepose i dag"
L["wish.say.rested.2"] = "{pet} drømmer om en natt under stjernene"
L["wish.say.rested.3"] = "{pet} vil krype ned i soveposen i dag"
L["wish.say.gold.1"] = "{pet} vil finne gull i dag"
L["wish.say.gold.2"] = "{pet} drømmer om mynter"
L["wish.say.gold.3"] = "{pet} vil loote gull med deg i dag"
L["wish.say.fun.1"] = "{pet} vil tulle og tøyse i dag"
L["wish.say.fun.2"] = "{pet} vil se deg gjøre noe fleibede"
L["wish.say.fun.3"] = "{pet} er i fleibehumør i dag"
L["wish.say.meet.1"] = "{pet} vil hilse på et annet dyr i dag"
L["wish.say.meet.2"] = "{pet} vil få en ny dyrevenn i dag"
L["wish.say.meet.3"] = "{pet} lurer på hvem den kan møte i dag"
L["wish.say.guildgroup.1"] = "{pet} vil være i gruppe med noen fra guilden"
L["wish.say.guildgroup.2"] = "{pet} savner guildvennene sine i dag"
L["wish.say.guildgroup.3"] = "{pet} vil ut på eventyr med guilden"
L["wish.say.playmate.1"] = "{pet} vil leke med et dyr fra guilden i dag"
L["wish.say.playmate.2"] = "{pet} drømmer om en lekeavtale"
L["wish.say.playmate.3"] = "{pet} vil ha en lekekamerat i dag"
L["wish.say.guildpet.1"] = "{pet} vil hilse på et dyr fra guilden"
L["wish.say.guildpet.2"] = "{pet} vil møte guildens andre dyr i dag"
L["wish.say.guildpet.3"] = "{pet} lurer på hvordan guildens dyr har det"
L["wish.say.zone.1"] = "{pet} vil til {zone} i dag"
L["wish.say.zone.2"] = "{pet} drømmer om {zone}"
L["wish.say.zone.3"] = "{pet} lengter til {zone} i dag"
-- A companion not in Data/Companions.lua (Menagerie/Unlisted.lua), once per species
L["unlisted.seen"] = "Dyreparken kjenner ikke {name} (art {id}) ennå. Si fra til {who}, så kommer den med!"
L["unlisted.learned"] = "Du har {name} (art {id}), som Dyreparken ikke kjenner ennå. Si fra til {who}, så kommer den med!"
L["unlisted.noname"] = "et ukjent dyr"
L["wish.zone.noun"] = "en tur til {zone}" -- (a trip wish, in "fikk ønsket sitt oppfylt: ...")
L["bond.contest"] = "{pet} jubler over at du fisket i fiskekonkurransen! (+{n} båndpoeng)"
L["bond.contest.full"] = "{pet} jubler over at du fisket i fiskekonkurransen!" -- (a full day: no points left to give)
-- Feats (Menagerie/Feats.lua): the line and the story's word, by how the feat reads
L["feat.spell"] = "{pet} var med da du lærte {what}! (+{n} båndpoeng)"
L["feat.quest"] = "{pet} var med da du fullførte «{what}»! (+{n} båndpoeng)"
L["feat.totem"] = "{pet} var med da du fikk {totem}! (+{n} båndpoeng)"
L["feat.riding"] = "{pet} var med da du lærte å ri! (+{n} båndpoeng)"
L["feat.level60"] = "Level 60! {pet} har vært med deg helt til toppen. (+{n} båndpoeng)"
-- (the same with no points left to give: the bond at its cap)
L["feat.spell.full"] = "{pet} var med da du lærte {what}!"
L["feat.quest.full"] = "{pet} var med da du fullførte «{what}»!"
L["feat.totem.full"] = "{pet} var med da du fikk {totem}!"
L["feat.riding.full"] = "{pet} var med da du lærte å ri!"
L["feat.level60.full"] = "Level 60! {pet} har vært med deg helt til toppen."
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
-- A party member's gathering nearby (Wish.GATHER): {who} is their name.
L["wish.granted.friend"] = "{pet} fikk se {who} gjøre det, og ønsket ble oppfylt: {activity}! (+{n} båndpoeng)"
L["wish.granted.friend.full"] = "{pet} fikk se {who} gjøre det, og ønsket ble oppfylt: {activity}!"
-- (2026-11-13: drafts, for the user to edit) A wish come true by itself (Wish:Auto): everything explored and
-- seen together, or every profession at its cap.
L["wish.auto.explore"] = "{pet} har sett hver krok av verden sammen med deg, og ønsker seg bare å være med deg i dag. Ønsket er oppfylt! (+{n} båndpoeng)"
L["wish.auto.explore.full"] = "{pet} har sett hver krok av verden sammen med deg, og ønsker seg bare å være med deg i dag. Ønsket er oppfylt!"
L["wish.auto.skill"] = "Du har lært alt trenerne kan lære deg, og {pet} er stolt av deg. Ønsket er oppfylt! (+{n} båndpoeng)"
L["wish.auto.skill.full"] = "Du har lært alt trenerne kan lære deg, og {pet} er stolt av deg. Ønsket er oppfylt!"

------------------------------------------------------------------------------
-- The park (the map page)
------------------------------------------------------------------------------
L["park.title"] = "Parken"
L["park.counter"] = "Har et hjem"
L["park.empty"] = "Ingen har adoptert et dyr ennå. Bli den første!"
L["park.no_guild"] = "Parken er guildens. Bli med i en guild for å se den."
L["park.oldest"] = "|cffffd100Lengste vennskap:|r {pet} hos {owner}, {time}"
L["park.family"] = "|cffffd100Mest populære familie:|r {family} ({n} har et hjem)"
L["park.newest"] = "|cffffd100Nyeste beboer:|r {pet}, {home}"           -- {home}: "flyttet inn hos Kari Berg i går"
-- (2026-11-16, drafts) The same records, short, on the stage's side; the lines above in their tooltips.
L["park.rec.oldest"] = "Lengste vennskap"
L["park.rec.family"] = "Mest populære familie"
L["park.rec.newest"] = "Nyeste beboer"
L["park.rec.empty"] = "Ingen har adoptert ennå"
L["park.rec.who"] = "{pet} hos {owner}"
L["park.rec.families"] = "{family} ({n})"
L["park.free"] = "Trenger et hjem"
L["park.also_yours"] = "Du har også dette dyret."
L["park.can_adopt"] = "Du har dette dyret, og kan adoptere det."
L["park.click"] = "Klikk for å se dyret."
L["park.click.pets"] = "Åpne Pets-fanen, så kan du klikke her for å se dyret."
-- (2026-11-13: a draft) A click on an icon in combat.
L["park.combat_hint"] = "{pet} vises når combat er over."
L["park.legend"] = "I farger: har et hjem.  Grå: trenger et hjem.  {icon} Du kan adoptere det."
L["park.spot.today"] = "Dagens dyr"
L["park.spot.hint"] = "Hold over et dyr for å se det."
L["park.unknown"] = "???"
L["park.unknown.tip"] = "Ingen i guilden har funnet dette dyret ennå."
L["park.legend.unknown"] = "?: ingen har det ennå."
-- (2026-11-16, a draft) The legend, short, under the records; the one above in its tooltip.
L["park.legend.short"] = "{home} Har et hjem    {free} Trenger et hjem\n{icon} Kan adopteres"
L["park.legend.short.unknown"] = "?  Ingen har det"
-- Who else in the guild has a pet, under the card's home line (Owners:Line). "also": its holder or you have it too.
L["owners.one"] = "{a} har dette dyret."
L["owners.two"] = "{a} og {b} har dette dyret."
L["owners.many"] = "{n} i guilden har dette dyret."
L["owners.also.one"] = "{a} har også dette dyret."
L["owners.also.two"] = "{a} og {b} har også dette dyret."
L["owners.also.many"] = "{n} andre i guilden har også dette dyret."
-- The search and the filters (2026-11-14): what doesn't match is dimmed in place.
L["park.search"] = "Søk"
L["park.search.tip"] = "Søk etter navn, kallenavn, hvem det bor hos eller familie."
L["park.matches"] = "{n} treff"
L["park.family.default"] = "andre dyr"
L["park.sign.homes"] = "{homes} av {n} har et hjem"
L["park.sign.show"] = "Klikk for å vise bare denne familien."
L["park.sign.all"] = "Klikk igjen for å vise alle."
L["park.filter.free"] = "Trenger hjem"
L["park.filter.free.tip"] = "Bare dyr ingen i guilden har adoptert."
L["park.filter.adopt"] = "Kan adopteres"
L["park.filter.adopt.tip"] = "Bare dyr du har selv og ingen har adoptert: dem kan du adoptere nå."
-- Where a pet comes from (Data/Companions.lua: s, w), in its tooltip. {where}: names from the game (NPC, quest,
-- item, zone), in English like the client's.
L["source.line"] = "Kilde: {how}"
L["source.line.where"] = "Kilde: {how} – {where}"
L["source.vendor"] = "Vendor"
L["source.quest"] = "Quest"
L["source.drop"] = "Drop"
L["source.crafted"] = "Crafting"
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
L["source.where.5163"] = "Blizzard-butikken eller en kampanje"
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
        share_hint = "Del det i guildchatten med Del på Prestasjoner-siden, eller med /dp prestasjoner del.",
        already = "Du har allerede {n} prestasjoner fra før. Se dem med /dp prestasjoner.",
        none_to_share = "Ingen nye prestasjoner å dele.",
        share_more = "{n} til venter. Del dem med /dp prestasjoner del en gang til.",
        not_in_guild = "Du er ikke i en guild.",
        notify_on = "Andre med Dyreparken får beskjed når du får en prestasjon.",
        notify_off = "Andre med Dyreparken får ikke lenger beskjed om prestasjonene dine.",
        list_header = "Prestasjoner ({n} av {total}):",
        list_unshared = "* ikke delt ennå: /dp prestasjoner del. Alle står under Prestasjoner i samlingen (Shift+P).",
        list_page = "Alle står under Prestasjoner i samlingen (Shift+P), eller /dp prestasjoner alle.",
        points = "{have}/{need} poeng",
        guild_earned = "{guild} fikk {list}!",                  -- Dyreparken fikk [Kattehuset]!
        guild_hint = "Som offiser kan du dele det i guildchatten med /dp prestasjoner del.",

        -- Families in the plural, for "Mest populære familie" (Menagerie/ParkPage.lua).
        families = { cat = "katter", farm = "gårdsdyr", owl = "ugler", rabbit = "kaniner", snake = "slanger",
            frog = "frosker og padder", mechanical = "mekaniske dyr", dragon = "drager", bird = "fugler",
            pirate = "piratdyr", bug = "insekter", rodent = "gnagere", wolf = "ulver", plant = "planter",
            festive = "høytidsdyr", demon = "demoner", ooze = "slimdyr", spirit = "ånder", bear = "bjørner",
            reptile = "krypdyr", murloc = "murlocs" },

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
    ["count:10"] = { name = "Ti på taket", desc = "Ha 10 dyr.",
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
    -- (secret: listed once earned)
    ["jump:10000"] = { name = "Sprett i beina", desc = "Hopp 10 000 ganger med dyret ditt ute.",
        flavor = "{player} og {pet} har hoppet 10 000 ganger sammen! {name}", plain = "{player} og dyret sitt har hoppet 10 000 ganger sammen! {name}" },
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
    ["dislikes"] = { name = "Kjenner dyret ut og inn", desc = "Finn ut alt dyret ditt liker og ikke liker, også det du lærer når båndet blir sterkere.",
        flavor = "{player} vet nå alt om hva {pet} liker og ikke liker! {name}",
        plain = "{player} kjenner dyret sitt ut og inn! {name}" },

    -- Guild: the companions the guild cares for, all at once (one per member).
    ["guild:count:10"] = { name = "Dyreparken åpner", desc = "Guilden tar vare på 10 dyr samtidig.",
        flavor = "Portene er åpne: {guild} tar vare på ti dyr! {name}" },
    ["guild:count:25"] = { name = "Full drift", desc = "Guilden tar vare på 25 dyr samtidig.",
        flavor = "{guild} tar vare på 25 dyr! Dyreparken er i full drift. {name}" },
    ["guild:count:50"] = { name = "Nordens største dyrepark", desc = "Guilden tar vare på 50 dyr samtidig.",
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
