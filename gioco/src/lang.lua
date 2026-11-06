-- Lingua dei testi a schermo. Il gioco e' scritto in italiano; con l'inglese ogni testo passa da qui
-- (Render.text chiama Lang.t). Prima si cerca la frase intera, poi si sostituiscono i pezzi noti:
-- cosi' funzionano anche i testi composti ("Obiettivo: " .. nome, "VINCE " .. eroe, ...).

local Lang = { code = "it" }

local EN = {
  -- menu principale
  ["GIOCA"] = "PLAY", ["PERSONAGGI"] = "HEROES", ["RICETTARIO"] = "RECIPES", ["OBIETTIVI"] = "ACHIEVEMENTS",
  ["IMPOSTAZIONI"] = "SETTINGS", ["ESCI"] = "QUIT",
  ["2-6 giocatori, ultimo in piedi vince"] = "2-6 players, last one standing wins",
  ["eroi, skin e negozio"] = "heroes, skins and shop",
  ["fusioni e ricette scoperte"] = "fusions and recipes found",
  ["sfide e ricompense"] = "challenges and rewards",
  ["audio e video"] = "audio, video and language",
  ["a presto"] = "see you soon",
  ["Frecce / WASD / croce: muovi    Invio / A / click: scegli    Esc / B: indietro"] =
    "Arrows / WASD / d-pad: move    Enter / A / click: select    Esc / B: back",
  -- impostazioni
  ["AUDIO"] = "AUDIO", ["VIDEO"] = "VIDEO",
  ["Volume generale"] = "Master volume", ["Musica"] = "Music", ["Effetti sonori"] = "Sound effects",
  ["Schermo intero"] = "Fullscreen", ["Risoluzione finestra"] = "Window resolution",
  ["Sincronia verticale (vsync)"] = "Vertical sync (vsync)", ["Scala pixel perfetta"] = "Pixel-perfect scaling",
  ["Scosse dello schermo"] = "Screen shake", ["Lampi a schermo"] = "Screen flashes",
  ["Vibrazione controller"] = "Controller vibration", ["Ripristina predefinite"] = "Restore defaults",
  ["Lingua"] = "Language", ["(schermo intero)"] = "(fullscreen)",
  ["SI"] = "YES", ["NO"] = "NO", ["Invio"] = "Enter",
  ["Su/giu: scegli    Sinistra/destra o click: cambia    Esc/B: salva e torna"] =
    "Up/down: select    Left/right or click: change    Esc/B: save and go back",
  -- eroi
  ["SCEGLI IL COMBATTENTE"] = "CHOOSE YOUR FIGHTER", ["SCEGLI"] = "SELECT", ["PREFERITO"] = "FAVORITE",
  ["BLOCCATA"] = "LOCKED", ["SBLOCCATA"] = "UNLOCKED", ["COMPRA EROE "] = "BUY HERO ", ["COMPRA SKIN "] = "BUY SKIN ",
  ["Sinistra/destra: eroe    Su/giu o rotella: skin    Invio/A: scegli o compra    Esc/B: indietro"] =
    "Left/right: hero    Up/down or wheel: skin    Enter/A: select or buy    Esc/B: back",
  ["<> eroe   su/giu skin"] = "<> hero   up/down skin",
  ["Micio Kage"] = "Kage the Cat", ["Gatto ninja"] = "Ninja cat",
  ["Ranocchio Taro"] = "Taro the Frog", ["Rana samurai"] = "Samurai frog",
  ["Orso Barbanera"] = "Blackbeard Bear", ["Orso pirata"] = "Pirate bear",
  ["Volpe Dakota"] = "Dakota Fox", ["Volpe cowboy"] = "Cowboy fox",
  ["Coniglio Ragnar"] = "Ragnar Rabbit", ["Coniglio vichingo"] = "Viking rabbit",
  ["Procione Lesto"] = "Swift Raccoon", ["Procione ladro"] = "Thief raccoon",
  ["Tigrato"] = "Tabby", ["Siamese"] = "Siamese", ["Ombra"] = "Shadow", ["Alchimista"] = "Alchemist",
  ["Stagno"] = "Pond", ["Velenosa"] = "Poison", ["Oro"] = "Gold",
  ["Bruno"] = "Brown", ["Polare"] = "Polar", ["Fantasma"] = "Ghost",
  ["Prateria"] = "Prairie", ["Artica"] = "Arctic", ["Fuoco"] = "Fire",
  ["Fiordo"] = "Fjord", ["Neve"] = "Snow", ["Runico"] = "Runic",
  ["Bidone"] = "Trash can", ["Albino"] = "Albino", ["Notturno"] = "Night",
  ["Rosso"] = "Red", ["Blu"] = "Blue", ["Verde"] = "Green", ["Giallo"] = "Yellow", ["Viola"] = "Purple",
  ["Arancio"] = "Orange",
  -- ricettario
  ["FUSIONI NORMALI"] = "NORMAL FUSIONS", ["RICETTE SPECIALI"] = "SPECIAL RECIPES",
  ["Passa col mouse su una casella"] = "Hover a cell with the mouse",
  ["??? (ricetta speciale)"] = "??? (special recipe)", [": da scoprire"] = ": not found yet",
  [" fusioni normali scoperte   (oro: ricetta speciale)"] = " normal fusions found   (gold: special recipe)",
  ["Sinistra/destra: pagina    Mouse: nome della fusione    Esc/B: indietro"] =
    "Left/right: page    Mouse: fusion name    Esc/B: back",
  ["Sinistra/destra: pagina    Su/giu o rotella: scorri    Esc/B: indietro"] =
    "Left/right: page    Up/down or wheel: scroll    Esc/B: back",
  ["Su/giu o rotella: scorri    Esc/B: indietro"] = "Up/down or wheel: scroll    Esc/B: back",
  ["SCOPERTA"] = "FOUND", ["NUOVA RICETTA!"] = "NEW RECIPE!", ["Indizio: contiene "] = "Hint: contains ",
  ["Nuova ricetta: "] = "New recipe: ",
  -- obiettivi
  ["Primo sangue"] = "First blood", ["Elimina un avversario"] = "Knock out an opponent",
  ["Cacciatore"] = "Hunter", ["Elimina 50 avversari"] = "Knock out 50 opponents",
  ["Campione"] = "Champion", ["Vinci una partita"] = "Win a match",
  ["Ultimo in piedi"] = "Last one standing", ["Vinci 10 round"] = "Win 10 rounds",
  ["Veterano"] = "Veteran", ["Gioca 20 partite"] = "Play 20 matches",
  ["Ninja dei muri"] = "Wall ninja", ["Fai 100 salti dal muro"] = "Do 100 wall jumps",
  ["Mano ferma"] = "Steady hand", ["Fai 10 parry perfetti"] = "Land 10 perfect parries",
  ["Leggenda"] = "Legend", ["Elimina qualcuno con un'arma mitica"] = "Knock someone out with a mythic weapon",
  ["Demolitore"] = "Demolisher", ["Elimina 15 avversari con le esplosioni"] = "Knock out 15 opponents with explosions",
  ["Collezionista"] = "Collector", ["Raccogli 100 armi"] = "Pick up 100 weapons",
  ["Domatore di bot"] = "Bot tamer", ["Vinci una partita contro bot difficili"] = "Win a match against hard bots",
  ["Sfida gli elementi"] = "Weather the storm", ["Resta in vita durante 25 eventi di mappa"] = "Survive 25 map events",
  ["Intoccabile"] = "Untouchable", ["Vinci un round senza subire danni"] = "Win a round without taking damage",
  ["Scintilla"] = "Spark", ["Fondi due armi"] = "Fuse two weapons",
  ["Fabbro"] = "Blacksmith", ["Scopri 25 fusioni normali diverse"] = "Find 25 different normal fusions",
  ["Apprendista alchimista"] = "Apprentice alchemist", ["Scopri 5 ricette speciali"] = "Find 5 special recipes",
  ["Scopri tutte le ricette speciali"] = "Find every special recipe",
  ["Forgiato in battaglia"] = "Battle-forged", ["Vinci un round con un'arma fusa in mano"] = "Win a round holding a fused weapon",
  ["Obiettivi: "] = "Achievements: ", ["Obiettivo: "] = "Achievement: ", [" completati"] = " completed",
  ["Nuova skin: "] = "New skin: ", ["Sbloccato "] = "Unlocked ", ["Skin "] = "Skin ", [" sbloccata!"] = " unlocked!",
  [" monete"] = " coins", [" monete   (totale "] = " coins   (total ", ["FATTO"] = "DONE",
  -- lobby
  ["START (o Invio) per iniziare"] = "START (or Enter) to begin",
  ["START (o Invio): parti da solo contro 2 bot"] = "START (or Enter): play alone against 2 bots",
  ["Invio: tastiera + 2 bot   oppure premi un tasto del controller"] = "Enter: keyboard + 2 bots   or press a controller button",
  ["Tastiera 1"] = "Keyboard 1", ["Tastiera 2"] = "Keyboard 2", ["Controller "] = "Controller ",
  ["Bot: "] = "Bots: ", ["Bot "] = "Bot ", ["Facile"] = "Easy", ["Normale"] = "Normal", ["Difficile"] = "Hard",
  ["   (Tab o Select per cambiare)"] = "   (Tab or Select to change)",
  ["F1/F2 tastiera   F10 bot   Backspace togli   Esc menu   Tastiera 1: A D W S   Tastiera 2: frecce"] =
    "F1/F2 keyboard   F10 bot   Backspace remove   Esc menu   Keyboard 1: A D W S   Keyboard 2: arrows",
  ["Frecce muovi e salta, Z attacco, X scatto, C parry, V scambia (tieni: fondi), B lancia"] =
    "Arrows move and jump, Z attack, X dash, C parry, V swap (hold: fuse), B throw",
  ["WASD muovi, Spazio salta, mouse mira, click attacca, click destro o Q parry, Shift scatto, E scambia (tieni: fondi), G lancia"] =
    "WASD move, Space jump, mouse aim, click attack, right click or Q parry, Shift dash, E swap (hold: fuse), G throw",
  ["CONTROLLER SCOLLEGATO"] = "CONTROLLER DISCONNECTED", ["Ricollegalo per continuare"] = "Reconnect it to continue",
  ["Controller non riconosciuto come gamepad standard (SDL)"] = "Controller not recognized as a standard gamepad (SDL)",
  ["libero"] = "empty",
  ["In gioco: F3 hitbox  F4 slow  F5 pausa  F6 frame  F7 ricarica dati  F8 taratura"] =
    "In game: F3 hitboxes  F4 slow motion  F5 pause  F6 frame step  F7 reload data  F8 tuning",
  ["TARATURA (F8 chiude, F9 salva)"] = "TUNING (F8 closes, F9 saves)",
  -- partita
  ["PAUSA"] = "PAUSED", ["Riprendi"] = "Resume", ["Torna alla lobby"] = "Back to lobby", ["Menu principale"] = "Main menu",
  ["Volume"] = "Volume",
  ["Su/giu scegli   sinistra/destra volume   Invio/A conferma   Esc/B riprendi"] =
    "Up/down select   left/right volume   Enter/A confirm   Esc/B resume",
  ["ROUND "] = "ROUND ", ["VIA!"] = "GO!", ["PAREGGIO"] = "DRAW", ["PUNTO A"] = "POINT TO", ["VINCE "] = "WINNER: ",
  ["MORTE IMPROVVISA"] = "SUDDEN DEATH", ["ATTENZIONE!"] = "WARNING!",
  ["A / Invio: rivincita      B / Esc: lobby"] = "A / Enter: rematch      B / Esc: lobby",
  [" round   "] = " rounds   ", [" round "] = " rounds ", [" elim."] = " KOs",
  ["a mani nude"] = "bare hands", ["in mano  v"] = "held  v", ["raccolta  >"] = "pick up  >", ["solo scambio"] = "swap only",
  ["FRANA!"] = "ROCKSLIDE!", ["BARILI IN ARRIVO!"] = "BARRELS INCOMING!", ["GEYSER DI FUOCO!"] = "FIRE GEYSERS!",
  ["LAVA IN ARRIVO!"] = "LAVA INCOMING!", ["TEMPESTA!"] = "STORM!", ["PRESSE!"] = "PRESSES!", ["ONDATA!  "] = "WAVE!  ",
  ["VENTO  >>>"] = "WIND  >>>", ["<<<  VENTO"] = "<<<  WIND",
  -- mappe
  ["Arena"] = "Arena", ["Fabbrica"] = "Factory", ["Tetti"] = "Rooftops", ["Miniera"] = "Mine",
  ["Ghiacciaio"] = "Glacier", ["Vulcano"] = "Volcano", ["Tempio"] = "Temple", ["Galeone"] = "Galleon",
  ["Laboratorio"] = "Laboratory",
  -- rarita'
  ["Base"] = "Basic", ["Avanzata"] = "Advanced", ["Potente"] = "Powerful", ["Mitica"] = "Mythic",
  -- armi
  ["Pugni"] = "Fists", ["Spada"] = "Sword", ["Martello"] = "Hammer", ["Lancia"] = "Spear", ["Pistola"] = "Pistol",
  ["Fucile a pompa"] = "Shotgun", ["Pompa"] = "Shotgun", ["Mitraglietta"] = "SMG", ["Mitra"] = "SMG",
  ["Fucile cecchino"] = "Sniper rifle", ["Cecchino"] = "Sniper", ["Lanciagranate"] = "Grenade launcher",
  ["Granate"] = "Grenades", ["Frusta"] = "Whip", ["Katana"] = "Katana", ["Scudo"] = "Shield",
  ["Boomerang"] = "Boomerang", ["Boomer."] = "Boomer.", ["Lanciafiamme"] = "Flamethrower", ["Fiamme"] = "Flamer",
  ["Mine"] = "Mines", ["Rampino"] = "Grappling hook", ["Lanciarazzi"] = "Rocket launcher", ["Razzi"] = "Rockets",
  ["Soffiatore"] = "Leaf blower", ["Soffio"] = "Blower", ["Pistola a bolle"] = "Bubble gun", ["Bolle"] = "Bubbles",
  ["Pompa automatico"] = "Auto shotgun", ["Pompa A."] = "Auto SG", ["Fucile d'assalto"] = "Assault rifle",
  ["Assalto"] = "Assault", ["Spara buchi neri"] = "Black hole gun", ["B. nero"] = "B. hole",
  ["Fucile fantasma"] = "Ghost rifle", ["Lanciasciame"] = "Swarm launcher", ["Sciame"] = "Swarm",
  -- ricette speciali
  ["Tornado di fuoco"] = "Fire tornado", ["Tornado"] = "Tornado",
  ["un vortice che avanza lento, spinge via e incendia"] = "a slow whirlwind that pushes away and sets on fire",
  ["Bolle bomba"] = "Bubble bombs", ["B. bomba"] = "B. bombs",
  ["bolle che vagano per la mappa ed esplodono al contatto"] = "bubbles that roam the map and explode on contact",
  ["Bolla razzo"] = "Rocket bubble", ["B. razzo"] = "R. bubble",
  ["imprigiona l'avversario e la bolla parte come un razzo"] = "traps the opponent and the bubble takes off like a rocket",
  ["Arpione"] = "Harpoon",
  ["lanci la lancia legata a una corda e trascini chi colpisci"] = "throw the spear on a rope and drag whoever you hit",
  ["Catena falciante"] = "Reaper chain", ["Catena"] = "Chain",
  ["ti agganci al bersaglio e arrivi con un fendente"] = "hook onto the target and arrive with a slash",
  ["Martello a reazione"] = "Jet hammer", ["Reazione"] = "Jet",
  ["il colpo ti spara in avanti come un razzo e chiude con un'esplosione"] = "the swing launches you forward like a rocket and ends in an explosion",
  ["Scudo volante"] = "Flying shield", ["Scudo vol."] = "Fly shield",
  ["lo lanci, rimbalza sui muri, colpisce e torna: in volo non ti protegge"] = "throw it, it bounces off walls, hits and comes back: it won't protect you while flying",
  ["Granata boomerang"] = "Boomerang grenade", ["Gran. boom."] = "Boom. gren.",
  ["torna verso di te: prendila al volo prima che esploda e la rilanci"] = "it comes back to you: catch it before it explodes to throw it again",
  ["Frusta di fuoco"] = "Fire whip", ["Frusta f."] = "Fire whip",
  ["tira verso di te, incendia e lascia fiamme a terra"] = "pulls toward you, sets on fire and leaves flames on the ground",
  ["Sciame d'api"] = "Bee swarm", ["Api"] = "Bees",
  ["raffica di api che inseguono il bersaglio e lo rallentano"] = "a burst of bees that chase the target and slow it down",
  ["Pompa a bolle"] = "Bubble shotgun", ["Pompa b."] = "Bubble SG", ["sei bolle a ventaglio"] = "six bubbles in a fan",
  ["Cannone a vento"] = "Wind cannon", ["Cannone v."] = "Wind cannon",
  ["un colpo d'aria che attraversa la mappa e spinge chiunque sulla linea"] = "an air blast that crosses the map and pushes anyone in its path",
  ["Pioggia di mine"] = "Mine shower", ["Pioggia"] = "Shower", ["cinque mine sparse a ventaglio"] = "five mines spread in a fan",
  ["Spada di ritorno"] = "Returning sword", ["Spada rit."] = "Ret. sword",
  ["la spada si lancia ruotando e torna in mano, colpendo all'andata e al ritorno"] = "the sword spins out and comes back, hitting both ways",
}

-- aggettivi delle fusioni normali (inglese: prima del nome)
Lang.ADJ = {
  affilata = "Sharp", pesante = "Heavy", portata = "Long-range", uncino = "Hooked", scatto = "Swift",
  guardia = "Armored", calibro = "Boosted", rosa = "Spread", ritorno = "Returning", raffica = "Burst",
  perforante = "Piercing", aggancio = "Grappling", bolla = "Bubble", folata = "Wind", fuoco = "Flaming",
  esplosivo = "Explosive", trappola = "Mined",
}

-- maiuscole: "VINCE MICIO KAGE!" -> "WINNER: KAGE THE CAT!"
local upper = {}
for k, v in pairs(EN) do
  local K = k:upper()
  if K ~= k and not EN[K] then upper[K] = v:upper() end
end
for k, v in pairs(upper) do EN[k] = v end

-- pezzi per i testi composti, dal piu' lungo al piu' corto
local PIECES = {}
for k, v in pairs(EN) do
  if #k >= 3 and k ~= v then PIECES[#PIECES + 1] = { k, v } end
end
table.sort(PIECES, function(a, b) if #a[1] ~= #b[1] then return #a[1] > #b[1] end return a[1] < b[1] end)

local function plain(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
for _, p in ipairs(PIECES) do
  -- se il pezzo comincia o finisce con una lettera, deve essere una parola intera
  local pat = plain(p[1])
  if p[1]:find("^[%w]") then pat = "%f[%w]" .. pat end
  if p[1]:find("[%w]$") then pat = pat .. "%f[%W]" end
  p.pat = pat
  p.rep = p[2]:gsub("%%", "%%%%")
end

local cache, cached = {}, 0

function Lang.t(s)
  if Lang.code ~= "en" or type(s) ~= "string" or s == "" then return s end
  local c = cache[s]
  if c then return c end
  local out = EN[s]
  if not out then
    out = s
    for _, p in ipairs(PIECES) do
      if out:find(p.pat) then out = out:gsub(p.pat, p.rep) end
    end
  end
  cached = cached + 1
  if cached > 4000 then cache, cached = {}, 0 end
  cache[s] = out
  return out
end

-- nomi delle armi fuse in inglese: "Doppia spada" -> "Double Sword", "Pistola a raffica" -> "Burst Pistol"
function Lang.fusion_name(body_name, trait, double)
  local n = EN[body_name] or body_name
  if double then return "Double " .. n end
  return (Lang.ADJ[trait] or trait) .. " " .. n
end

function Lang.set(code)
  Lang.code = code == "en" and "en" or "it"
  cache, cached = {}, 0
end

return Lang
