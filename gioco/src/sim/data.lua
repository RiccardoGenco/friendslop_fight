-- Tutti i numeri di bilanciamento del gioco vivono qui.
-- Le durate sono in frame (la simulazione gira a 60 frame al secondo).
-- Le velocita' sono in pixel al secondo; le mappe sono 1024x576 (64x36 tile da 16).
-- Premendo F7 in gioco questo file viene riletto senza riavviare.

local M = {}

M.fps = 60
M.dt = 1 / 60
M.tile = 16

M.player = {
  w = 10, h = 20, hp = 100,
  run_speed = 130,
  accel_ground = 1500, decel_ground = 1700,
  accel_air = 1300, decel_air = 900,
  gravity = 900, jump_vel = 330, jump_cut = 0.5, max_fall = 420,
  -- arco del salto: si cade piu' in fretta di come si sale e in cima si "galleggia" un attimo
  fall_gravity_mul = 1.25, apex_speed = 45, apex_gravity_mul = 0.55,
  coyote = 5, buffer = 6, drop_frames = 10,
  -- mira con la levetta destra: sotto questa inclinazione si usa la mira classica
  aim_deadzone = 0.35,
  -- doppio salto e parete (stile Hollow Knight)
  air_jumps = 1, double_jump_vel = 290,
  -- parete: ci si aggancia da soli cadendo, si frena e si scivola; tenendo la direzione
  -- opposta per qualche frame ci si stacca
  wall_slide_speed = 70, wall_brake = 2400, wall_grab_frames = 8, wall_release = 5, wall_coyote = 6,
  -- salto dalla parete: neutro o verso il muro = piu' verticale (si risale lo stesso muro),
  -- via dal muro = piu' lungo. Il controllo torna gradualmente durante wall_lock
  wall_jump_vx = 160, wall_jump_vx_away = 230, wall_jump_vy = 320,
  wall_lock = 8, wall_lock_away = 12,
  -- scatto
  dash_frames = 14, dash_invuln = 8, dash_speed = 300,
  dash_cooldown = 40, dash_cancel_cooldown = 60,
  -- parry (Deflect)
  parry_startup = 2, parry_active = 8, parry_whiff_recovery = 24,
  parry_stun = 30, parry_proj_speed = 1.25,
  perfect_parry = 4,   -- i primi frame attivi del parry sono "perfetti": parano anche il martello
  -- stati provocati dalle armi nuove
  burn_frames = 150, burn_every = 20, burn_dmg = 3,          -- fuoco: 3 danni ogni 1/3 di secondo
  bubble_frames = 110, bubble_rise = 38, bubble_mash = 7,    -- bolla: galleggia verso l'alto; premere tasti libera prima
  bubble_pop_bonus = 12,                                     -- colpire chi e' in una bolla la fa scoppiare con danno extra
  grapple_speed = 520, grapple_frames = 45,                  -- rampino: velocita' e durata massima del traino
  hook_pull_speed = 420, hook_stun = 22,                     -- rampino su un avversario: lo tira verso di te
  shield_block_push = 120, shield_attacker_stun = 14,        -- scudo: rinculo e stordimento di chi colpisce
  -- clash
  clash_window = 12, clash_knockback = 160, counter_mul = 1.5, counter_lunge = 220, clash_tolerance = 1,
  -- colpi subiti
  hitstun_base = 4, hitstun_per_dmg = 0.25,
  hitstop_base = 3, hitstop_max = 6,
  knockback_up = 0.35,
  -- trappole
  spike_damage = 30, spike_cooldown = 30,
  fall_death_margin = 32,
  throw_speed = 340, throw_damage = 20, throw_gravity = 600,
}

-- Elementi delle mappe (src/sim/gadgets.lua, src/sim/movers.lua)
M.gadgets = { spring_vel = 560, belt_speed = 75, portal_cd = 40 }

-- Eventi di mappa (src/sim/mapevents.lua). Tempi in frame (60 = 1 secondo).
M.map_events = {
  first_min = 360, first_max = 540,                      -- primo evento dopo 6-9 s
  every_min = 600, every_max = 840,                      -- poi ogni 10-14 s a inizio round...
  late_min = 300, late_max = 420,                        -- ...che scendono a 5-7 s a fine rampa
  ramp = 2400,                                           -- intensita' piena dopo 40 s
  wave_chance = 0.6,                                     -- probabilita' di ondata doppia a intensita' piena
  warn = 75,                                             -- preavviso prima del colpo
  rocks = { count = 3, extra = 4, stagger = 8, dmg = 25, size = 12, gravity = 900, max_speed = 520 },
  barrels = { count = 2, extra = 3, stagger = 14, size = 12, gravity = 800, max_speed = 480,
              blast = { radius = 46, dmg = 45, kb = 330, self_mul = 1 } },
  lightning = { count = 2, extra = 3, stagger = 10, dmg = 40, width = 16 },
  press = { count = 1, extra = 2, stagger = 30, dmg = 55, width = 44, push = 260, breaks = true },
  geyser = { count = 2, extra = 3, stagger = 12, dmg = 15, width = 14, height = 150, burn = true, push = 380 },
  wind = { frames = 180, frames_extra = 120, speed = 60, speed_extra = 40, air_mul = 1.25 },
}

M.momentum = {
  max = 100, tier1 = 33, tier2 = 66,
  gain_hit = 10, gain_parry = 25, gain_kill = 20, loss_hit = 30,
  decay_delay = 180, decay_rate = 5,        -- dopo 3 s senza colpire, -5 al secondo
  speed_bonus = 0.10, dmg_bonus = 0.15, knock_bonus = 0.15,
}

M.round = {
  countdown = 180, end_delay = 100,
  wins = 5, wins_duel = 3,
  sudden_death_warning = 2400, sudden_death = 2700, lava_speed = 0.5,
  simultaneous_window = 10,
  spawn_min = 240, spawn_max = 360, max_items = 6,   -- max_items conta solo le armi comparse, non quelle lasciate
  telegraph = 60, item_life = 1200,                    -- un'arma a terra dura 20 s
  max_ground = 12,                                     -- oltre, sparisce l'arma a terra piu' vecchia
  tap_frames = 12,                                     -- tasto raccogli rilasciato entro 1/5 di s = scambio
  fuse_frames = 30,                                    -- tenuto premuto mezzo secondo = fusione
  crate_min = 1200, crate_max = 1800,
  start_items_less = 1,   -- armi iniziali = giocatori - questo numero (almeno 1): qualcuno resta senza
  map_repeat_block = 2,
}

-- Proiettili: i rimbalzi massimi stanno in ogni arma (proj.bounces).
M.projectiles = {
  self_hit_after_bounce = true,   -- un proiettile che ha rimbalzato colpisce anche chi l'ha sparato
}

M.weapons = {
  -- Tutti i proiettili seguono una traiettoria balistica: proj.gravity e' la caduta
  -- (pixel/s^2), proj.drag il rallentamento per frame. Per colpire lontano si mira piu' in alto.
  -- kind: "melee" (colpo davanti al personaggio) o "ranged" (spara proiettili)
  -- startup/active/recovery in frame; uses = colpi prima di rompersi; ammo = munizioni
  -- weight = probabilita' di comparire; proj.bounces = rimbalzi massimi sui muri
  fists = {
    id = "fists", name = "Pugni", short = "Pugni", kind = "melee",
    startup = 4, active = 3, recovery = 14,
    damage = 4, knockback = 0,
    hit = { ox = 0, oy = -15, w = 9, h = 8 },
    move_mult = 0.6,
  },
  sword = {
    -- veloce e affidabile, ma con un caricamento visibile: si puo' leggere e parare
    id = "sword", name = "Spada", short = "Spada", kind = "melee",
    startup = 6, active = 4, recovery = 10,
    damage = 28, knockback = 170,
    hit = { ox = 0, oy = -17, w = 22, h = 12 },
    uses = 22, move_mult = 0.7, weight = 20,
    color = { 0.85, 0.9, 1.0 },
  },
  hammer = {
    -- lento e devastante; rompe la parata, tranne quella perfetta
    id = "hammer", name = "Martello", short = "Martello", kind = "melee",
    startup = 16, active = 4, recovery = 22,
    damage = 55, knockback = 330,
    hit = { ox = 0, oy = -24, w = 24, h = 22 },
    guardbreak = true,
    uses = 10, move_mult = 0.35, weight = 12,
    color = { 0.75, 0.55, 0.35 },
  },
  spear = {
    -- portata lunghissima ma stretta: punisce chi si avvicina in linea retta
    id = "spear", name = "Lancia", short = "Lancia", kind = "melee",
    startup = 9, active = 4, recovery = 16,
    damage = 24, knockback = 230,
    hit = { ox = 2, oy = -14, w = 36, h = 6 },
    lunge = 120,
    uses = 20, move_mult = 0.55, weight = 16,
    color = { 0.75, 0.8, 0.85 },
  },
  pistol = {
    id = "pistol", name = "Pistola", short = "Pistola", kind = "ranged",
    startup = 3, active = 1, recovery = 10,
    damage = 25, knockback = 120,
    ammo = 14, move_mult = 0.9, weight = 22, bot_range = 360,
    proj = { speed = 560, life = 150, count = 1, spread = 0, w = 4, h = 3,
             gravity = 260, bounces = 2, bounce_keep = 0.85 },
    color = { 1.0, 0.85, 0.3 },
  },
  shotgun = {
    id = "shotgun", name = "Fucile a pompa", short = "Pompa", kind = "ranged",
    startup = 6, active = 1, recovery = 26,
    damage = 12, knockback = 90,
    ammo = 6, move_mult = 0.8, weight = 14, bot_range = 150,
    recoil = 160,
    proj = { speed = 470, life = 45, count = 6, spread = 0.2, w = 3, h = 3,
             gravity = 380, drag = 0.975, bounces = 1, bounce_keep = 0.6 },
    color = { 1.0, 0.55, 0.3 },
  },
  smg = {
    -- automatica: si tiene premuto il grilletto. Poco danno a colpo, tanta pressione
    id = "smg", name = "Mitraglietta", short = "Mitra", kind = "ranged", auto = true,
    startup = 1, active = 1, recovery = 4,
    damage = 8, knockback = 45,
    ammo = 50, move_mult = 0.85, weight = 14, bot_range = 280,
    jitter = 0.09,
    proj = { speed = 540, life = 120, count = 1, spread = 0, w = 3, h = 2,
             gravity = 330, bounces = 1, bounce_keep = 0.7 },
    color = { 0.6, 0.85, 0.65 },
  },
  sniper = {
    -- lento da caricare (la canna brilla mentre carica), attraversa il primo bersaglio
    -- e rimbalza senza perdere velocita': premia i colpi di sponda
    id = "sniper", name = "Fucile cecchino", short = "Cecchino", kind = "ranged",
    startup = 20, active = 1, recovery = 40,
    damage = 85, knockback = 300,
    ammo = 5, move_mult = 0.4, weight = 8, bot_range = 600,
    recoil = 220,
    proj = { speed = 1500, life = 90, count = 1, spread = 0, w = 5, h = 2,
             gravity = 160, bounces = 3, bounce_keep = 1.0, pierce = 1, kind = "sniper" },
    color = { 0.55, 0.75, 1.0 },
  },
  grenade = {
    -- granate che rimbalzano ed esplodono dopo un secondo e mezzo, o subito se toccano
    -- un avversario. L'esplosione ferisce anche chi l'ha lanciata.
    id = "grenade", name = "Lanciagranate", short = "Granate", kind = "ranged",
    startup = 6, active = 1, recovery = 32,
    damage = 0, knockback = 0,
    ammo = 5, move_mult = 0.6, weight = 8, bot_range = 200,
    recoil = 90,
    proj = { speed = 400, life = 90, count = 1, spread = 0, w = 5, h = 5,
             gravity = 650, bounces = 8, bounce_keep = 0.55, kind = "grenade",
             on_expire = "explode", on_touch = "explode", on_impact = "explode",
             blast = { radius = 50, dmg = 70, kb = 380, self_mul = 0.6 } },
    color = { 0.45, 0.6, 0.35 },
  },
}

-- ---------------------------------------------------------------------------
-- Armi della v0.3: ognuna introduce una meccanica che le altre non hanno.
-- short_range = arma volutamente corta (non deve attraversare la mappa).

M.weapons.whip = {
  -- frusta: portata lunga e tira l'avversario verso di te invece di respingerlo
  id = "whip", name = "Frusta", short = "Frusta", kind = "melee",
  startup = 10, active = 3, recovery = 16,
  damage = 14, knockback = 240, pull = true,
  hit = { ox = 0, oy = -16, w = 46, h = 8 },
  uses = 18, move_mult = 0.6, weight = 12,
  color = { 0.6, 0.4, 0.25 },
}
M.weapons.katana = {
  -- katana: il fendente e' uno scatto in avanti, invulnerabile, che colpisce tutto sul percorso
  id = "katana", name = "Katana", short = "Katana", kind = "melee",
  startup = 7, active = 8, recovery = 20,
  damage = 32, knockback = 200,
  hit = { ox = -6, oy = -19, w = 26, h = 16 },
  lunge = 430, lunge_invuln = true, keep_momentum = true,
  uses = 14, move_mult = 1.0, weight = 11,
  color = { 0.9, 0.95, 1.0 },
}
M.weapons.shield = {
  -- scudo: para da solo i colpi frontali finche' non attacchi; l'attacco e' una spinta che stordisce.
  -- uses = parate prima di rompersi (il martello ne toglie 3)
  id = "shield", name = "Scudo", short = "Scudo", kind = "melee",
  startup = 5, active = 3, recovery = 14,
  damage = 8, knockback = 280, stun = 26, no_wear = true,
  hit = { ox = 0, oy = -20, w = 12, h = 20 },
  uses = 12, move_mult = 0.8, weight = 10,
  color = { 0.55, 0.6, 0.7 },
}
M.weapons.boomerang = {
  -- boomerang: va, rimbalza sui muri e torna da te; colpisce sia all'andata sia al ritorno.
  -- Finche' e' in volo non puoi lanciarlo di nuovo. ammo = lanci
  id = "boomerang", name = "Boomerang", short = "Boomer.", kind = "ranged", returns = true,
  startup = 4, active = 1, recovery = 10,
  damage = 18, knockback = 150,
  ammo = 14, move_mult = 0.9, weight = 12, bot_range = 260,
  proj = { speed = 430, life = 200, count = 1, spread = 0, w = 10, h = 10,
           gravity = 40, bounces = 2, bounce_keep = 1.0, pierce = 9, kind = "boomerang",
           return_after = 22, homing = 1500, max_speed = 460 },
  color = { 0.85, 0.6, 0.3 },
}
M.weapons.flamer = {
  -- lanciafiamme: automatico e corto, le fiamme salgono e danno fuoco a chi toccano.
  -- I colpi delle fiamme non stordiscono: bruciano.
  id = "flamer", name = "Lanciafiamme", short = "Fiamme", kind = "ranged", auto = true,
  short_range = true,
  startup = 1, active = 1, recovery = 2,
  damage = 2, knockback = 0, jitter = 0.16,
  ammo = 120, move_mult = 0.75, weight = 9, bot_range = 70,
  proj = { speed = 330, life = 32, count = 1, spread = 0, w = 7, h = 7,
           gravity = -140, drag = 0.95, bounces = 0, pierce = 9, kind = "flame",
           effect = "burn", nostun = true },
  color = { 1.0, 0.45, 0.15 },
}
M.weapons.mines = {
  -- mine: lanciate a breve distanza, si attaccano dove cadono, si armano dopo un secondo
  -- ed esplodono quando qualcuno ci passa sopra (anche tu)
  id = "mines", name = "Mine", short = "Mine", kind = "ranged", short_range = true,
  startup = 4, active = 1, recovery = 20,
  damage = 0, knockback = 0,
  ammo = 5, move_mult = 0.8, weight = 9, bot_range = 60,
  proj = { speed = 180, life = 1800, count = 1, spread = 0, w = 16, h = 10,
           gravity = 700, bounces = 0, kind = "mine", on_impact = "stick", on_touch = "mine",
           arm = 60, blast = { radius = 56, dmg = 80, kb = 400, self_mul = 1.0 } },
  color = { 0.5, 0.5, 0.45 },
}
M.weapons.hook = {
  -- rampino: sul muro ti tira fino al punto colpito (si annulla col salto);
  -- su un avversario lo trascina verso di te
  id = "hook", name = "Rampino", short = "Rampino", kind = "ranged", returns = true,
  startup = 3, active = 1, recovery = 12,
  damage = 5, knockback = 0,
  ammo = 10, move_mult = 0.9, weight = 10, bot_range = 300,
  proj = { speed = 760, life = 40, count = 1, spread = 0, w = 6, h = 6,
           gravity = 120, bounces = 0, kind = "hook", on_impact = "grapple", effect = "hookpull" },
  color = { 0.7, 0.7, 0.75 },
}
M.weapons.bazooka = {
  -- lanciarazzi: il razzo parte lento e accelera, esplode all'impatto.
  -- Sparando ai propri piedi si fa il salto col razzo (costa un po' di salute)
  id = "bazooka", name = "Lanciarazzi", short = "Razzi", kind = "ranged",
  startup = 8, active = 1, recovery = 40,
  damage = 0, knockback = 0,
  ammo = 4, move_mult = 0.5, weight = 7, bot_range = 420,
  recoil = 120,
  proj = { speed = 180, life = 140, count = 1, spread = 0, w = 6, h = 4,
           gravity = 30, accel = 1400, max_speed = 760, bounces = 0, kind = "rocket",
           on_impact = "explode", on_touch = "explode", on_expire = "explode",
           blast = { radius = 62, dmg = 75, kb = 470, self_mul = 0.3 } },
  color = { 0.45, 0.5, 0.35 },
}
M.weapons.gust = {
  -- soffiatore: nessun danno, una folata enorme che spinge via chiunque.
  -- Serve a buttare gli altri negli spuntoni, nel vuoto o nella lava
  id = "gust", name = "Soffiatore", short = "Soffio", kind = "ranged", short_range = true,
  startup = 5, active = 1, recovery = 22,
  damage = 0, knockback = 440,
  ammo = 10, move_mult = 0.8, weight = 10, bot_range = 110,
  recoil = 60,
  proj = { speed = 430, life = 26, count = 1, spread = 0, w = 16, h = 22,
           gravity = 0, drag = 0.96, bounces = 0, pierce = 9, kind = "gust" },
  color = { 0.75, 0.9, 1.0 },
}
M.weapons.bubble = {
  -- pistola a bolle: chi viene preso resta chiuso in una bolla che sale e non puo' fare niente
  -- (premendo tasti si libera prima). Un colpo la fa scoppiare con danno extra
  id = "bubble", name = "Pistola a bolle", short = "Bolle", kind = "ranged",
  startup = 4, active = 1, recovery = 22,
  damage = 0, knockback = 0,
  ammo = 8, move_mult = 0.9, weight = 10, bot_range = 260,
  proj = { speed = 300, life = 170, count = 1, spread = 0, w = 9, h = 9,
           gravity = -50, drag = 0.988, bounces = 2, bounce_keep = 0.8, kind = "bubble",
           effect = "bubble" },
  color = { 0.6, 0.85, 1.0 },
}

M.weapons.autoshotgun = {
  -- pompa automatico: la versione migliorata del fucile a pompa, si tiene premuto
  id = "autoshotgun", name = "Pompa automatico", short = "Pompa A.", kind = "ranged", auto = true,
  startup = 3, active = 1, recovery = 13,
  damage = 12, knockback = 110,
  ammo = 12, move_mult = 0.8, weight = 10, bot_range = 170,
  recoil = 120,
  proj = { speed = 500, life = 50, count = 6, spread = 0.2, w = 3, h = 3,
           gravity = 360, drag = 0.98, bounces = 1, bounce_keep = 0.6 },
  color = { 1.0, 0.65, 0.35 },
}
M.weapons.assault = {
  -- fucile d'assalto: automatico, preciso, tanto danno e gittata lunga
  id = "assault", name = "Fucile d'assalto", short = "Assalto", kind = "ranged", auto = true,
  startup = 1, active = 1, recovery = 6,
  damage = 15, knockback = 80, jitter = 0.03,
  ammo = 40, move_mult = 0.75, weight = 12, bot_range = 380,
  proj = { speed = 660, life = 110, count = 1, spread = 0, w = 4, h = 2,
           gravity = 200, bounces = 1, bounce_keep = 0.8 },
  color = { 0.45, 0.55, 0.4 },
}

-- --- Armi mitiche -----------------------------------------------------------

M.weapons.blackhole = {
  -- spara buchi neri: una sfera lenta che, toccato un muro o dopo un po', diventa un buco nero.
  -- Per 3 secondi risucchia giocatori, proiettili e armi a terra; al centro fa danno.
  -- Attira anche chi l'ha sparato (un po' meno)
  id = "blackhole", name = "Spara buchi neri", short = "B. nero", kind = "ranged", mythic = true,
  short_range = true,
  startup = 12, active = 1, recovery = 40,
  damage = 0, knockback = 0,
  ammo = 2, move_mult = 0.6, weight = 10, bot_range = 300,
  proj = { speed = 230, life = 70, count = 1, spread = 0, w = 10, h = 10,
           gravity = 0, bounces = 0, kind = "singularity",
           on_impact = "blackhole", on_expire = "blackhole", on_touch = "blackhole" },
  field = { frames = 180, radius = 170, force = 2400, core = 18, core_dmg = 8, core_every = 12,
            owner_mul = 0.5, end_blast = { radius = 45, dmg = 25, kb = 380 } },
  color = { 0.55, 0.3, 0.85 },
}
M.weapons.ghost = {
  -- fucile fantasma: i proiettili attraversano i muri e il primo bersaglio, senza cadere
  id = "ghost", name = "Fucile fantasma", short = "Fantasma", kind = "ranged", mythic = true,
  startup = 6, active = 1, recovery = 16,
  damage = 40, knockback = 200,
  ammo = 8, move_mult = 0.8, weight = 10, bot_range = 500,
  proj = { speed = 560, life = 130, count = 1, spread = 0, w = 6, h = 4,
           gravity = 0, bounces = 0, pierce = 1, phase_walls = true, kind = "ghost" },
  color = { 0.75, 0.6, 1.0 },
}
M.weapons.swarm = {
  -- lanciasciame: 5 missili piccoli che inseguono l'avversario piu' vicino
  id = "swarm", name = "Lanciasciame", short = "Sciame", kind = "ranged", mythic = true,
  startup = 8, active = 1, recovery = 45,
  damage = 0, knockback = 0,
  ammo = 4, move_mult = 0.7, weight = 10, bot_range = 400,
  proj = { speed = 260, life = 150, count = 5, spread = 0.9, w = 4, h = 4,
           gravity = 0, bounces = 0, kind = "missile", seek = 1700, max_speed = 420,
           seek_delay = 12, on_impact = "explode", on_touch = "explode", on_expire = "explode",
           blast = { radius = 26, dmg = 18, kb = 220, self_mul = 0.5 } },
  color = { 0.9, 0.4, 0.5 },
}

-- ---------------------------------------------------------------------------
-- Livelli delle armi. Ogni arma che compare sceglie prima il livello, poi l'arma
-- dentro il livello (secondo il suo weight). Le probabilita' dei livelli cambiano
-- durante il round: da weight_start all'inizio a weight_end dopo ramp_frames,
-- quindi piu' il round dura, piu' escono armi forti.
M.tiers = {
  { name = "Base",     color = { 0.85, 0.85, 0.85 }, weight_start = 70, weight_end = 30,
    weapons = { "sword", "hammer", "spear", "whip", "shield", "pistol", "shotgun", "boomerang" } },
  { name = "Avanzata", color = { 0.35, 0.75, 1.0 },  weight_start = 25, weight_end = 38,
    weapons = { "smg", "sniper", "autoshotgun", "katana", "hook", "bubble", "gust" } },
  { name = "Potente",  color = { 0.8, 0.4, 1.0 },    weight_start = 5,  weight_end = 24,
    weapons = { "flamer", "grenade", "assault", "bazooka", "mines" } },
  { name = "Mitica",   color = { 1.0, 0.75, 0.2 },   weight_start = 0,  weight_end = 8,
    weapons = { "blackhole", "ghost", "swarm" } },
}
M.tier_ramp_frames = 2400        -- 40 secondi
M.start_tier = 1                 -- armi di inizio round: solo livello Base
-- la cassa centrale: livello Potente o Mitico
M.crate_tiers = { { tier = 3, weight = 75 }, { tier = 4, weight = 25 } }

-- elenco completo, ricavato dai livelli; ogni arma conosce il suo livello
M.weapon_order = {}
for t, tier in ipairs(M.tiers) do
  for _, id in ipairs(tier.weapons) do
    M.weapons[id].tier = t
    M.weapon_order[#M.weapon_order + 1] = id
  end
end
M.weapons.fists.tier = 1


M.colors = {
  { 0.95, 0.35, 0.35 }, { 0.35, 0.65, 0.95 }, { 0.40, 0.85, 0.45 },
  { 0.95, 0.85, 0.30 }, { 0.80, 0.45, 0.95 }, { 0.95, 0.60, 0.25 },
}
M.color_names = { "Rosso", "Blu", "Verde", "Giallo", "Viola", "Arancio" }

-- Ricarica il file in place, mantenendo i riferimenti gia' presi dal resto del codice.
function M.reload()
  local chunk = loadfile and loadfile("src/sim/data.lua")
  if not chunk then return false end
  local ok, fresh = pcall(chunk)
  if not ok or type(fresh) ~= "table" then return false end
  local function merge(dst, src)
    for k, v in pairs(src) do
      if type(v) == "table" and type(dst[k]) == "table" then merge(dst[k], v) else dst[k] = v end
    end
  end
  merge(M, fresh)
  return true
end

return M
