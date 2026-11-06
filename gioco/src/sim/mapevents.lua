-- Eventi di mappa: la mappa attacca i giocatori, sempre con un preavviso visibile.
-- Ogni mappa ha due tipi di evento; durante il round gli eventi diventano piu' frequenti
-- e piu' fitti, e dopo meta' round possono arrivare due eventi insieme (ondata).
-- Deterministici: usano solo il generatore del gioco.
--
--   colonne (si colpisce una colonna verticale): fulmine, pressa, geyser di fuoco
--   cadute (oggetti che cadono dal soffitto):    massi, barili esplosivi
--   vento: spinge tutti da un lato per qualche secondo

local data = require("src.sim.data")
local Combat = require("src.sim.combat")

local E = {}
local T = data.tile

local KINDS = {
  Arena = { "rocks", "geyser" },
  Fabbrica = { "barrels", "press" },
  Tetti = { "lightning", "wind" },
  Miniera = { "rocks", "barrels" },
  Ghiacciaio = { "rocks", "wind" },        -- stalattiti che cadono, bufera
  Vulcano = { "geyser", "rocks" },         -- colonne di fuoco, lapilli
  Tempio = { "rocks", "lightning" },
  Galeone = { "barrels", "wind" },         -- barili rotolati giu', raffiche di mare
  Laboratorio = { "press", "lightning" },
}

local COLUMN = { lightning = true, press = true, geyser = true }

function E.kinds(world) return KINDS[world.name] end
function E.kind(world) local k = KINDS[world.name]; return k and k[1] end

function E.reset(game)
  local ev = data.map_events
  game.hazards = {}
  game.wind = nil
  game.event_timer = game.rng:int(ev.first_min, ev.first_max)
  game.event_wave = 0
end

-- primo punto libero dall'alto in una colonna (sotto il soffitto)
local function top_free(world, x)
  for r = 1, world.rows_n do
    if world:tile_at(x, (r - 1) * T + 1) ~= "#" then return (r - 1) * T end
  end
  return 0
end

-- primo pavimento sotto y (solido, piattaforma o spuntoni)
local function floor_below(world, x, y)
  local yy = y
  while yy < world.height do
    local t = world:tile_at(x, yy)
    if t == "#" or t == "=" or t == "^" then return math.floor(yy / T) * T end
    yy = yy + 4
  end
  return world.height
end
E.floor_below = floor_below

-- intensita' del round: 0 all'inizio, 1 dopo data.map_events.ramp frame
local function intensity(game)
  return math.min(1, (game.round_frame or 0) / data.map_events.ramp)
end
E.intensity = intensity

local function start_event(game, kind)
  local ev = data.map_events
  local spec = ev[kind]
  local w = game.world
  local k = intensity(game)
  game.event_wave = game.event_wave + 1
  if kind == "wind" then
    local dir = game.rng:int(0, 1) == 0 and -1 or 1
    game.wind = { dir = dir, warn = ev.warn, t = spec.frames + math.floor(spec.frames_extra * k) }
    game:emit("map_event", 0, 0, { kind = kind, dir = dir })
    return
  end
  local alive = {}
  for _, p in ipairs(game.players) do if p.alive then alive[#alive + 1] = p end end
  local count = spec.count + math.floor((spec.extra or 0) * k + 0.5)
  local width = spec.width or spec.size or 12
  local used = {}
  for n = 1, count do
    local x
    if n <= 2 and #alive > 0 then
      -- i primi colpi puntano i giocatori: l'evento conta sempre
      local p = alive[((n - 1 + game.event_wave) % #alive) + 1]
      x = p.x + game.rng:range(-30, 30)
    else
      x = game.rng:range(2 * T, w.width - 2 * T)
    end
    x = math.max(2 * T, math.min(w.width - 2 * T, x))
    for _ = 1, 4 do
      local clash = false
      for _, u in ipairs(used) do if math.abs(u - x) < width + 10 then clash = true end end
      if not clash then break end
      x = 2 * T + ((x - 2 * T + width + 24) % (w.width - 4 * T))
    end
    used[#used + 1] = x
    local y0 = top_free(w, x)
    local y2 = floor_below(w, x, y0 + 2)
    if kind == "geyser" then
      -- il fuoco sale dal pavimento: la colonna parte dal basso
      y0 = math.max(y0, y2 - spec.height)
    end
    game.hazards[#game.hazards + 1] = { kind = kind, phase = "warn", x = x, y = y0, y0 = y0, y2 = y2,
                                        t = ev.warn + (n - 1) * spec.stagger, vy = 0, width = width }
  end
  game:emit("map_event", 0, 0, { kind = kind })
end

local function hits_player(game, x, y, hw, hh)
  for _, p in ipairs(game.players) do
    if p.alive and p.invuln <= 0 and math.abs(p.x - x) < p.w / 2 + hw and y + hh > p.y - p.h and y - hh < p.y then
      return p
    end
  end
end

-- colpo di una colonna: chi sta dentro prende danno (e brucia, se e' un geyser)
local function strike(game, h, spec)
  h.width = h.width or spec.width or 16
  h.y2 = h.y2 or floor_below(game.world, h.x, h.y0 + 2)
  local x1, x2 = h.x - h.width / 2, h.x + h.width / 2
  for _, p in ipairs(game.players) do
    if p.alive and p.x + p.w / 2 > x1 and p.x - p.w / 2 < x2 and p.y > h.y0 and p.y - p.h < h.y2 then
      Combat.hazard_hit(game, p, spec.dmg, h.kind)
      if p.alive and spec.burn then
        if p.burn <= 0 then game:emit("ignite", p.x, p.y - 10, { id = p.id }) end
        p.burn, p.burn_by = data.player.burn_frames, nil
      end
      if p.alive and spec.push then
        p.vy = -spec.push
        p.vx = (p.x < h.x and -1 or 1) * spec.push * 0.6
      end
    end
  end
  if spec.breaks then
    Combat.blocks_broken(game, game.world:break_blocks(h.x, (h.y0 + h.y2) / 2, math.max(h.width, (h.y2 - h.y0) / 2)), h.x, h.y2)
  end
  game:emit(h.kind, h.x, h.y2, { y1 = h.y0, width = h.width })
end

local function update_wind(game)
  local wd = game.wind
  if not wd then return end
  if wd.warn > 0 then
    wd.warn = wd.warn - 1
    if wd.warn == 0 then game:emit("wind_start", 0, 0, { dir = wd.dir }) end
    return
  end
  local spec = data.map_events.wind
  local push = wd.dir * (spec.speed + spec.speed_extra * intensity(game)) * data.dt
  for _, p in ipairs(game.players) do
    if p.alive and not p.grapple then
      -- in aria si vola di piu'
      game.world:move_x(p, push * (p.grounded and 1 or spec.air_mul))
    end
  end
  for _, pr in ipairs(game.projectiles) do
    if not pr.stuck then pr.vx = pr.vx + wd.dir * spec.speed * 2 * data.dt end
  end
  wd.t = wd.t - 1
  if wd.t <= 0 then game.wind = nil; game:emit("wind_end", 0, 0, {}) end
end

function E.update(game)
  local ev = data.map_events
  local kinds = E.kinds(game.world)
  if not kinds then return end
  local k = intensity(game)
  game.event_timer = game.event_timer - 1
  if game.event_timer <= 0 then
    local kind = game.rng:pick(kinds)
    if kind == "wind" and game.wind then kind = kinds[1] end
    start_event(game, kind)
    -- ondata: dopo meta' round a volte arriva anche l'altro evento
    if k >= 0.5 and game.rng:float() < ev.wave_chance * k then
      local other = (kind == kinds[1]) and kinds[2] or kinds[1]
      if not (other == "wind" and game.wind) then start_event(game, other) end
    end
    local lo = ev.every_min + (ev.late_min - ev.every_min) * k
    local hi = ev.every_max + (ev.late_max - ev.every_max) * k
    game.event_timer = game.rng:int(math.floor(lo), math.floor(hi))
  end
  update_wind(game)
  local list = game.hazards
  for i = #list, 1, -1 do
    local h = list[i]
    local spec = ev[h.kind]
    local remove = false
    if h.phase == "warn" then
      h.t = h.t - 1
      if h.t <= 0 then
        if COLUMN[h.kind] then
          strike(game, h, spec)
          remove = true
        else
          h.phase = "fall"
        end
      end
    else
      h.vy = math.min(h.vy + spec.gravity * data.dt, spec.max_speed)
      h.y = h.y + h.vy * data.dt
      local victim = hits_player(game, h.x, h.y, spec.size / 2, spec.size / 2)
      local t = game.world:tile_at(h.x, h.y + spec.size / 2)
      local landed = t == "#" or t == "=" or h.y > game.world.height + 20
      if victim or landed then
        if h.kind == "rocks" then
          if victim then Combat.hazard_hit(game, victim, spec.dmg, "masso") end
          Combat.blocks_broken(game, game.world:break_blocks(h.x, h.y + spec.size / 2, 10), h.x, h.y)
          game:emit("rock", h.x, h.y, {})
        else
          Combat.explode(game, h.x, h.y, spec.blast, nil, "barile")
        end
        remove = true
      end
    end
    if remove then table.remove(list, i) end
  end
end

return E
