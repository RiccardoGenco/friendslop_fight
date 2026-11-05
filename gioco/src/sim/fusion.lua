-- Fusione delle armi. Nessuna dipendenza da LÖVE.
--
-- L'arma in mano e' il CORPO (decide come si attacca); quella raccolta dona il suo TRATTO,
-- una proprieta' che si aggiunge. Due armi uguali danno la versione doppia.
-- Le ricette speciali (Fusion.RECIPES, vedi recipes.lua) hanno la precedenza sui tratti.
--
-- Un'arma fusa e' un'istanza normale ({ id = <corpo>, ammo/uses, ... }) con in piu':
--   def    = la definizione generata (copia di quella del corpo con il tratto applicato)
--   fused  = { body = <id>, donor = <id>, trait = <id> | nil, recipe = <id> | nil }
-- Player.weapon_def legge w.def quando c'e', quindi il resto del gioco non cambia.

local data = require("src.sim.data")

local Fusion = {}

local floor, max, min = math.floor, math.max, math.min

-- ---------------------------------------------------------------------------
-- Tratti donati da ogni arma

Fusion.DONOR = {
  sword = "affilata", hammer = "pesante", spear = "portata", whip = "uncino",
  katana = "scatto", shield = "guardia", pistol = "calibro",
  shotgun = "rosa", autoshotgun = "rosa", boomerang = "ritorno",
  smg = "raffica", assault = "raffica", sniper = "perforante", hook = "aggancio",
  bubble = "bolla", gust = "folata", flamer = "fuoco",
  grenade = "esplosivo", bazooka = "esplosivo", mines = "trappola",
}

-- aggettivo del tratto per il nome generato: { maschile, femminile, femminile plurale }
Fusion.ADJ = {
  affilata = { "affilato", "affilata", "affilate" },
  pesante = { "pesante", "pesante", "pesanti" },
  portata = { "a lunga gittata", "a lunga gittata", "a lunga gittata" },
  uncino = { "uncinato", "uncinata", "uncinate" },
  scatto = { "fulmineo", "fulminea", "fulminee" },
  guardia = { "corazzato", "corazzata", "corazzate" },
  calibro = { "potenziato", "potenziata", "potenziate" },
  rosa = { "a rosa", "a rosa", "a rosa" },
  ritorno = { "di ritorno", "di ritorno", "di ritorno" },
  raffica = { "a raffica", "a raffica", "a raffica" },
  perforante = { "perforante", "perforante", "perforanti" },
  aggancio = { "con rampino", "con rampino", "con rampino" },
  bolla = { "a bolle", "a bolle", "a bolle" },
  folata = { "a vento", "a vento", "a vento" },
  fuoco = { "infuocato", "infuocata", "infuocate" },
  esplosivo = { "esplosivo", "esplosiva", "esplosive" },
  trappola = { "minato", "minata", "minate" },
}
local DOUBLE = { "Doppio", "Doppia", "Doppie" }

-- genere grammaticale del nome dell'arma: 1 maschile, 2 femminile, 3 femminile plurale
local GENDER = {
  sword = 2, hammer = 1, spear = 2, whip = 2, katana = 2, shield = 1, pistol = 2,
  shotgun = 1, autoshotgun = 1, boomerang = 1, smg = 2, assault = 1, sniper = 1,
  hook = 1, bubble = 2, gust = 1, flamer = 1, grenade = 1, bazooka = 1, mines = 3,
}

-- proiettili donati da armi da mischia quando il corpo e' da mischia
local SHOTS = {
  calibro = { speed = 520, life = 60, count = 1, spread = 0, w = 4, h = 3, gravity = 260,
              bounces = 1, bounce_keep = 0.85, dmg = 16, kb = 90 },
  rosa = { speed = 460, life = 30, count = 5, spread = 0.3, w = 3, h = 3, gravity = 380,
           drag = 0.975, bounces = 0, dmg = 7, kb = 70 },
  aggancio = { speed = 760, life = 40, count = 1, spread = 0, w = 6, h = 6, gravity = 120,
               bounces = 0, kind = "hook", on_impact = "grapple", effect = "hookpull", dmg = 4, kb = 0 },
  trappola = { speed = 120, life = 1500, count = 1, spread = 0, w = 16, h = 10, gravity = 700,
               bounces = 0, kind = "mine", on_impact = "stick", on_touch = "mine", arm = 45,
               blast = { radius = 46, dmg = 55, kb = 360, self_mul = 1.0 }, dmg = 0, kb = 0, dir = "down" },
}

-- ---------------------------------------------------------------------------
-- Utilita'

local function copy(t)
  if type(t) ~= "table" then return t end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v) end
  return o
end
Fusion.copy = copy

local function add_effect(t, eff)
  t.effects = t.effects or {}
  for _, e in ipairs(t.effects) do if e == eff then return end end
  t.effects[#t.effects + 1] = eff
end

local function base_def(w)
  return (w and w.def) or (w and data.weapons[w.id]) or nil
end

-- L'arma puo' fare da ingrediente? (fuse, mitiche e pugni no)
function Fusion.fusable(w)
  if not w or w.fused then return false end
  local def = data.weapons[w.id]
  if not def or def.mythic or (def.tier or 1) >= 4 or w.id == "fists" then return false end
  return Fusion.DONOR[w.id] ~= nil
end

function Fusion.can_fuse(held, ground)
  return Fusion.fusable(held) and Fusion.fusable(ground)
end

-- chiave della ricetta speciale, indipendente dall'ordine
function Fusion.recipe_key(a, b)
  if a < b then return a .. "+" .. b end
  return b .. "+" .. a
end

-- ---------------------------------------------------------------------------
-- Applicazione dei tratti

local T = {}     -- T[trait](def, donor_def, strength) modifica def (copia del corpo)

T.affilata = function(d)
  d.damage = d.damage * 1.3
  if d.proj and d.proj.blast then d.proj.blast.dmg = d.proj.blast.dmg * 1.3 end
end

T.pesante = function(d)
  d.knockback = max(d.knockback * 1.6, 160)
  d.guardbreak = true
  if d.proj and d.proj.blast then d.proj.blast.kb = d.proj.blast.kb * 1.4 end
end

T.portata = function(d)
  if d.kind == "melee" then
    d.hit.w = floor(d.hit.w * 1.6)
  else
    d.proj.speed = d.proj.speed * 1.35
    d.proj.gravity = (d.proj.gravity or 0) * 0.5
    d.proj.life = floor(d.proj.life * 1.2)
  end
end

T.uncino = function(d)
  if d.kind == "melee" then d.pull = true else add_effect(d.proj, "hookpull") end
end

T.scatto = function(d)
  if d.kind == "melee" then
    d.lunge = max(d.lunge or 0, 380)
    d.lunge_invuln, d.keep_momentum = true, true
    d.active = max(d.active, 6)
  else
    d.fire_dash = 300          -- ogni colpo ti spinge in avanti, con una breve invulnerabilita'
  end
end

T.guardia = function(d) d.guard = true end

T.calibro = function(d)
  if d.kind == "melee" then
    d.melee_shot = copy(SHOTS.calibro)
  else
    d.damage = d.damage * 1.3
    d.proj.bounces = (d.proj.bounces or 0) + 1
  end
end

T.rosa = function(d, donor, k)
  if d.kind == "melee" then
    d.melee_shot = copy(SHOTS.rosa)
    d.melee_shot.count = 4 + k
  else
    local pj = d.proj
    if (pj.count or 1) <= 1 then
      pj.count, pj.spread = 2 + k, 0.16
      d.damage = d.damage * 0.55
      if pj.blast then pj.blast.dmg = pj.blast.dmg * 0.5 end
    else
      pj.count = pj.count + 1 + k
      pj.spread = pj.spread * 1.15
    end
  end
end

T.ritorno = function(d, donor)
  local pj = donor.proj
  if d.kind == "melee" then
    -- l'arma si lancia ruotando e torna in mano: diventa un'arma a distanza con i colpi come lanci
    d.kind, d.returns = "ranged", true
    d.ammo, d.uses = d.uses, nil
    d.startup, d.active, d.recovery = 4, 1, 10
    d.thrown_melee = true
    d.proj = { speed = pj.speed, life = pj.life, count = 1, spread = 0, w = 12, h = 12,
               gravity = pj.gravity, bounces = pj.bounces, bounce_keep = 1.0, pierce = 9,
               kind = "boomerang", return_after = pj.return_after, homing = pj.homing,
               max_speed = pj.max_speed, spin_of = d.id }
  else
    local p = d.proj
    p.return_after, p.homing = 20, 1600
    p.max_speed = max(p.speed, 420)
    p.pierce = (p.pierce or 0) + 1
    p.life = max(p.life, 110)
  end
end

T.raffica = function(d, donor, k)
  d.auto = true
  d.recovery = max(2, floor(d.recovery * (0.65 - 0.1 * k)))
  if d.kind == "melee" then d.startup = max(2, floor(d.startup * 0.7)) end
end

T.perforante = function(d)
  if d.kind == "melee" then
    d.hit.w = floor(d.hit.w * 1.5)
    d.hit.h = max(6, floor(d.hit.h * 0.75))
  else
    local p = d.proj
    p.speed = min(1500, p.speed * 1.8)
    p.pierce = (p.pierce or 0) + 1
    p.gravity = (p.gravity or 0) * 0.3
  end
end

T.aggancio = function(d)
  if d.kind == "melee" then
    d.melee_shot = copy(SHOTS.aggancio)
  else
    d.proj.on_impact = d.proj.on_impact or "grapple"
  end
end

T.bolla = function(d)
  if d.kind == "melee" then add_effect(d, "bubble") else add_effect(d.proj, "bubble") end
end

T.folata = function(d)
  d.knockback = d.knockback + 320
  if d.proj and d.proj.blast then d.proj.blast.kb = d.proj.blast.kb + 200 end
end

T.fuoco = function(d)
  if d.kind == "melee" then add_effect(d, "burn") else add_effect(d.proj, "burn") end
end

T.esplosivo = function(d, donor, k)
  local blast = { radius = 30 + 6 * k, dmg = 26 + 8 * k, kb = 260, self_mul = 0.5 }
  if d.kind == "melee" then
    d.on_hit_blast = blast
  else
    local p = d.proj
    if not p.blast then
      p.blast = blast
      p.on_impact = (p.on_impact == nil or p.on_impact == "grapple") and "explode" or p.on_impact
      p.on_touch = p.on_touch or "explode"
      p.on_expire = p.on_expire or "explode"
    else
      p.blast.radius = p.blast.radius * 1.3
      p.blast.dmg = p.blast.dmg * 1.2
    end
  end
end

T.trappola = function(d)
  if d.kind == "melee" then
    d.melee_shot = copy(SHOTS.trappola)
  else
    local p = d.proj
    p.on_impact, p.on_touch, p.arm = "stick", "mine", 45
    p.life = max(p.life, 900)
    p.bounces = 0
    p.blast = p.blast or { radius = 34, dmg = max(24, d.damage * 1.4), kb = 300, self_mul = 1.0 }
    p.gravity = max(p.gravity or 0, 200)
  end
end

local function double(d)
  if d.kind == "melee" then
    d.recovery = max(2, floor(d.recovery * 0.5))
    d.startup = max(2, floor(d.startup * 0.75))
  else
    local p = d.proj
    p.count = (p.count or 1) * 2
    p.spread = max(p.spread or 0, 0.07)
  end
end

-- ---------------------------------------------------------------------------
-- Fusione

-- tier e forza del tratto del donatore: la versione di livello piu' alto dona il tratto piu' forte
local function strength(donor_id)
  local t = data.weapons[donor_id].tier or 1
  return max(0, t - 1)
end

-- Definizione generata per corpo + donatore (senza ricette speciali)
function Fusion.make_def(body_id, donor_id)
  local d = copy(data.weapons[body_id])
  local donor = data.weapons[donor_id]
  d.tier = max(d.tier or 1, donor.tier or 1)
  if body_id == donor_id then
    double(d)
    return d, nil
  end
  local trait = Fusion.DONOR[donor_id]
  T[trait](d, donor, strength(donor_id))
  return d, trait
end

-- Crea l'arma fusa. `held` e' il corpo, `ground` il donatore. Riparte con le munizioni al massimo.
function Fusion.fuse(held, ground)
  local body, donor = held.id, ground.id
  local recipe = Fusion.RECIPES and Fusion.RECIPES[Fusion.recipe_key(body, donor)]
  local def, trait
  if recipe then
    def = recipe.build(body, donor)
    def.tier = max(data.weapons[body].tier or 1, data.weapons[donor].tier or 1)
  else
    def, trait = Fusion.make_def(body, donor)
  end
  local w = { id = def.id, tier = def.tier, dmg_mul = 1, def = def,
              fused = { body = body, donor = donor, trait = trait, recipe = recipe and recipe.id } }
  if def.ammo then w.ammo = def.ammo end
  if def.uses then w.uses = def.uses end
  return w
end

-- Nome dell'arma (normale o fusa)
function Fusion.name(w)
  if not w then return "" end
  local base = data.weapons[w.id] and data.weapons[w.id].name or w.id
  local f = w.fused
  if not f then return base end
  if f.recipe then return Fusion.RECIPES[Fusion.recipe_key(f.body, f.donor)].name end
  local body_name = data.weapons[f.body].name
  local g = GENDER[f.body] or 1
  if f.body == f.donor then
    return DOUBLE[g] .. " " .. body_name:sub(1, 1):lower() .. body_name:sub(2)
  end
  return body_name .. " " .. Fusion.ADJ[f.trait][g]
end

-- Nome dell'anteprima: per le ricette speciali non ancora scoperte e' "???"
function Fusion.preview(held, ground, discovered)
  if not Fusion.can_fuse(held, ground) then return nil end
  local key = Fusion.recipe_key(held.id, ground.id)
  local recipe = Fusion.RECIPES and Fusion.RECIPES[key]
  if recipe then
    if discovered and discovered[recipe.id] then return recipe.name, true end
    return "???", true
  end
  local f = { fused = { body = held.id, donor = ground.id, trait = Fusion.DONOR[ground.id] }, id = held.id }
  return Fusion.name(f), false
end

-- elenco di tutte le coppie normali (per il ricettario)
function Fusion.all_pairs()
  local ids, out = {}, {}
  for _, id in ipairs(data.weapon_order) do
    if Fusion.fusable({ id = id }) then ids[#ids + 1] = id end
  end
  for _, b in ipairs(ids) do
    for _, d in ipairs(ids) do
      if not (Fusion.RECIPES and Fusion.RECIPES[Fusion.recipe_key(b, d)]) then
        out[#out + 1] = { body = b, donor = d }
      end
    end
  end
  return out, ids
end

Fusion.RECIPES = {}

return Fusion
