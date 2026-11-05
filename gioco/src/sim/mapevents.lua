-- Eventi di mappa: ogni 12-18 secondi la mappa fa qualcosa ai giocatori.
-- Sempre annunciati in anticipo (colonna di avviso), deterministici (usano il generatore del gioco).
--   Arena:    massi che cadono dal soffitto
--   Fabbrica: barili che cadono ed esplodono all'impatto
--   Tetti:    fulmini che colpiscono una colonna intera

local data = require("src.sim.data")
local Combat = require("src.sim.combat")

local E = {}
local T = data.tile

local KIND = { Arena = "rocks", Fabbrica = "barrels", Tetti = "lightning" }

function E.kind(world) return KIND[world.name] end

function E.reset(game)
  local ev = data.map_events
  game.hazards = {}       -- avvisi e oggetti in caduta
  game.event_timer = game.rng:int(ev.first_min, ev.first_max)
end

-- primo punto libero dall'alto in una colonna (sotto il soffitto)
local function top_free(world, x)
  for r = 1, world.rows_n do
    local t = world:tile_at(x, (r - 1) * T + 1)
    if t ~= "#" then return (r - 1) * T end
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

local function start_event(game)
  local ev = data.map_events
  local kind = E.kind(game.world)
  if not kind then return end
  local spec = ev[kind]
  local w = game.world
  -- una colonna vicino a un giocatore vivo a caso, cosi' l'evento conta; le altre a caso
  local alive = {}
  for _, p in ipairs(game.players) do if p.alive then alive[#alive + 1] = p end end
  local used = {}
  for k = 1, spec.count do
    local x
    if k == 1 and #alive > 0 then
      local p = game.rng:pick(alive)
      x = p.x + game.rng:range(-40, 40)
    else
      x = game.rng:range(2 * T, w.width - 2 * T)
    end
    x = math.max(2 * T, math.min(w.width - 2 * T, x))
    for _, u in ipairs(used) do if math.abs(u - x) < 28 then x = x + 32 end end
    used[#used + 1] = x
    local y0 = top_free(w, x)
    game.hazards[#game.hazards + 1] = { kind = kind, phase = "warn", x = x, y = y0, y0 = y0,
                                        y2 = floor_below(w, x, y0 + 2), t = ev.warn + (k - 1) * 12, vy = 0 }
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

function E.update(game)
  local ev = data.map_events
  if not E.kind(game.world) then return end
  game.event_timer = game.event_timer - 1
  if game.event_timer <= 0 then
    start_event(game)
    game.event_timer = game.rng:int(ev.every_min, ev.every_max)
  end
  local list = game.hazards
  for i = #list, 1, -1 do
    local h = list[i]
    local spec = ev[h.kind]
    local remove = false
    if h.phase == "warn" then
      h.t = h.t - 1
      if h.t <= 0 then
        if h.kind == "lightning" then
          local y2 = floor_below(game.world, h.x, h.y0 + 2)
          for _, p in ipairs(game.players) do
            if p.alive and math.abs(p.x - h.x) < spec.width / 2 + p.w / 2 and p.y > h.y0 and p.y - p.h < y2 then
              Combat.hazard_hit(game, p, spec.dmg, "fulmine")
            end
          end
          game:emit("lightning", h.x, y2, { y1 = h.y0 })
          remove = true
        else
          h.phase = "fall"
        end
      end
    else
      -- massi e barili cadono
      h.vy = math.min(h.vy + spec.gravity * data.dt, spec.max_speed)
      h.y = h.y + h.vy * data.dt
      local victim = hits_player(game, h.x, h.y, spec.size / 2, spec.size / 2)
      local t = game.world:tile_at(h.x, h.y + spec.size / 2)
      local landed = t == "#" or t == "=" or h.y > game.world.height + 20
      if victim or landed then
        if h.kind == "rocks" then
          if victim then Combat.hazard_hit(game, victim, spec.dmg, "masso") end
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
