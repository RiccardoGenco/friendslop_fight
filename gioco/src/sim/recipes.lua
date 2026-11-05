-- Ricette speciali della fusione: combinazioni scritte a mano, con un nome e un comportamento
-- che i tratti da soli non darebbero. Valgono in entrambi gli ordini.
-- Ogni ricetta: id, name, a, b (ingredienti), hint (testo del ricettario), build() -> definizione.
-- Nessuna dipendenza da LÖVE.

local data = require("src.sim.data")
local Fusion = require("src.sim.fusion")

local copy = Fusion.copy

local function from(id, patch)
  local d = copy(data.weapons[id])
  for k, v in pairs(patch or {}) do d[k] = v end
  return d
end

local LIST = {
  {
    id = "tornado", name = "Tornado di fuoco", a = "flamer", b = "gust",
    hint = "un vortice che avanza lento, spinge via e incendia",
    build = function()
      return from("gust", {
        name = "Tornado di fuoco", short = "Tornado", startup = 8, recovery = 34,
        damage = 6, knockback = 300, ammo = 6, color = { 1.0, 0.5, 0.15 },
        proj = { speed = 130, life = 170, count = 1, spread = 0, w = 20, h = 34, gravity = 0,
                 bounces = 2, bounce_keep = 1.0, pierce = 99, kind = "tornado", effects = { "burn" } },
      })
    end,
  },
  {
    id = "bubblebomb", name = "Bolle bomba", a = "bubble", b = "mines",
    hint = "bolle che vagano per la mappa ed esplodono al contatto",
    build = function()
      return from("bubble", {
        name = "Bolle bomba", short = "B. bomba", startup = 5, recovery = 24, ammo = 6,
        color = { 0.7, 0.75, 1.0 },
        proj = { speed = 140, life = 420, count = 1, spread = 0, w = 10, h = 10, gravity = -25,
                 drag = 0.996, bounces = 8, bounce_keep = 0.95, kind = "bubblebomb",
                 on_touch = "explode", on_expire = "explode",
                 blast = { radius = 42, dmg = 45, kb = 340, self_mul = 0.6 } },
      })
    end,
  },
  {
    id = "bubblerocket", name = "Bolla razzo", a = "bubble", b = "bazooka",
    hint = "imprigiona l'avversario e la bolla parte come un razzo",
    build = function()
      return from("bubble", {
        name = "Bolla razzo", short = "B. razzo", startup = 6, recovery = 30, ammo = 5,
        color = { 1.0, 0.6, 0.4 },
        proj = { speed = 340, life = 160, count = 1, spread = 0, w = 10, h = 10, gravity = -30,
                 drag = 0.99, bounces = 1, bounce_keep = 0.8, kind = "bubble", effect = "bubblerocket" },
      })
    end,
  },
  {
    id = "harpoon", name = "Arpione", a = "spear", b = "hook",
    hint = "lanci la lancia legata a una corda e trascini chi colpisci",
    build = function()
      return from("spear", {
        name = "Arpione", short = "Arpione", kind = "ranged", returns = true, uses = nil,
        startup = 6, active = 1, recovery = 18, damage = 22, knockback = 0, ammo = 12,
        proj = { speed = 720, life = 45, count = 1, spread = 0, w = 10, h = 4, gravity = 160,
                 bounces = 0, kind = "harpoon", effect = "hookpull", on_impact = "grapple" },
      })
    end,
  },
  {
    id = "chainblade", name = "Catena falciante", a = "katana", b = "hook",
    hint = "ti agganci al bersaglio e arrivi con un fendente",
    build = function()
      return from("katana", {
        name = "Catena falciante", short = "Catena", kind = "ranged", returns = true, uses = nil,
        startup = 4, active = 1, recovery = 16, damage = 30, knockback = 160, ammo = 12,
        proj = { speed = 780, life = 38, count = 1, spread = 0, w = 6, h = 6, gravity = 100,
                 bounces = 0, kind = "hook", effect = "pullself", on_impact = "grapple" },
      })
    end,
  },
  {
    id = "jethammer", name = "Martello a reazione", a = "hammer", b = "bazooka",
    hint = "il colpo ti spara in avanti come un razzo e chiude con un'esplosione",
    build = function()
      return from("hammer", {
        name = "Martello a reazione", short = "Reazione", startup = 12, active = 8, recovery = 22,
        damage = 45, knockback = 360, lunge = 520, lunge_invuln = true, keep_momentum = true,
        uses = 10, move_mult = 0.5, jet = true, color = { 1.0, 0.55, 0.25 },
        on_hit_blast = { radius = 44, dmg = 30, kb = 420, self_mul = 0.3 },
      })
    end,
  },
  {
    id = "flyshield", name = "Scudo volante", a = "shield", b = "boomerang",
    hint = "lo lanci, rimbalza sui muri, colpisce e torna: in volo non ti protegge",
    build = function()
      local pj = data.weapons.boomerang.proj
      return from("shield", {
        name = "Scudo volante", short = "Scudo vol.", kind = "ranged", returns = true, guard = true,
        uses = nil, ammo = 12, startup = 5, active = 1, recovery = 12, damage = 26, knockback = 260,
        proj = { speed = 460, life = 220, count = 1, spread = 0, w = 12, h = 14, gravity = 0,
                 bounces = 4, bounce_keep = 1.0, pierce = 9, kind = "boomerang", spin_of = "shield",
                 return_after = 26, homing = pj.homing, max_speed = 480 },
      })
    end,
  },
  {
    id = "boomgrenade", name = "Granata boomerang", a = "grenade", b = "boomerang",
    hint = "torna verso di te: prendila al volo prima che esploda e la rilanci",
    build = function()
      local g = data.weapons.grenade.proj
      return from("grenade", {
        name = "Granata boomerang", short = "Gran. boom.", returns = true, ammo = 5, recovery = 24,
        proj = { speed = 380, life = 110, count = 1, spread = 0, w = 6, h = 6, gravity = 120,
                 bounces = 3, bounce_keep = 0.8, kind = "grenade", return_after = 28, homing = 1300,
                 max_speed = 380, refund = true, on_touch = "explode", on_expire = "explode",
                 blast = copy(g.blast) },
      })
    end,
  },
  {
    id = "firewhip", name = "Frusta di fuoco", a = "whip", b = "flamer",
    hint = "tira verso di te, incendia e lascia fiamme a terra",
    build = function()
      return from("whip", {
        name = "Frusta di fuoco", short = "Frusta f.", effects = { "burn" }, damage = 16,
        color = { 1.0, 0.5, 0.2 },
        melee_shot = { speed = 140, life = 70, count = 4, spread = 0.6, w = 6, h = 6, gravity = 420,
                       drag = 0.97, bounces = 0, kind = "flame", effects = { "burn" }, nostun = true,
                       dmg = 2, kb = 0 },
      })
    end,
  },
  {
    id = "bees", name = "Sciame d'api", a = "smg", b = "bubble",
    hint = "raffica di api che inseguono il bersaglio e lo rallentano",
    build = function()
      return from("smg", {
        name = "Sciame d'api", short = "Api", damage = 5, knockback = 20, ammo = 60, jitter = 0.35,
        color = { 1.0, 0.85, 0.2 },
        proj = { speed = 300, life = 100, count = 1, spread = 0, w = 4, h = 4, gravity = 0,
                 bounces = 0, kind = "bee", seek = 3200, max_speed = 320, seek_delay = 6,
                 effect = "slow" },
      })
    end,
  },
  {
    id = "bubbleshot", name = "Pompa a bolle", a = "shotgun", b = "bubble",
    hint = "sei bolle a ventaglio",
    build = function()
      return from("shotgun", {
        name = "Pompa a bolle", short = "Pompa b.", damage = 0, knockback = 0, ammo = 6, recoil = 80,
        color = { 0.6, 0.85, 1.0 },
        proj = { speed = 320, life = 110, count = 6, spread = 0.38, w = 8, h = 8, gravity = -40,
                 drag = 0.985, bounces = 1, bounce_keep = 0.8, kind = "bubble", effect = "bubble" },
      })
    end,
  },
  {
    id = "windcannon", name = "Cannone a vento", a = "gust", b = "sniper",
    hint = "un colpo d'aria che attraversa la mappa e spinge chiunque sulla linea",
    build = function()
      return from("gust", {
        name = "Cannone a vento", short = "Cannone v.", startup = 16, recovery = 40,
        damage = 6, knockback = 620, ammo = 5, recoil = 200, short_range = false,
        proj = { speed = 900, life = 80, count = 1, spread = 0, w = 18, h = 26, gravity = 0,
                 bounces = 0, pierce = 99, kind = "gust" },
      })
    end,
  },
  {
    id = "minerain", name = "Pioggia di mine", a = "mines", b = "shotgun",
    hint = "cinque mine sparse a ventaglio",
    build = function()
      local m = copy(data.weapons.mines.proj)
      m.count, m.spread, m.speed = 5, 0.5, 260
      return from("mines", { name = "Pioggia di mine", short = "Pioggia", ammo = 4, recovery = 30, proj = m })
    end,
  },
  {
    id = "returnblade", name = "Spada di ritorno", a = "sword", b = "boomerang",
    hint = "la spada si lancia ruotando e torna in mano, colpendo all'andata e al ritorno",
    build = function()
      local pj = data.weapons.boomerang.proj
      return from("sword", {
        name = "Spada di ritorno", short = "Spada rit.", kind = "ranged", returns = true, uses = nil,
        ammo = 22, startup = 4, active = 1, recovery = 10, damage = 30, knockback = 180,
        proj = { speed = 500, life = 220, count = 1, spread = 0, w = 14, h = 12, gravity = 30,
                 bounces = 3, bounce_keep = 1.0, pierce = 9, kind = "boomerang", spin_of = "sword",
                 return_after = 24, homing = pj.homing, max_speed = 520 },
      })
    end,
  },
}

local R = {}
for _, r in ipairs(LIST) do
  local build = r.build
  r.build = function()
    local d = build()
    -- la sagoma resta quella del corpo, cosi' l'arma si riconosce
    d.id = d.id
    return d
  end
  R[Fusion.recipe_key(r.a, r.b)] = r
end

Fusion.RECIPES = R
Fusion.RECIPE_LIST = LIST

return LIST
