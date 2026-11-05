-- Bot semplicissimo, per provare il gioco quando non hai abbastanza controller.
-- Usa il random di LÖVE: non serve che sia riproducibile.

local Bot = {}

local abs = math.abs

local function sign(v) if v > 0 then return 1 elseif v < 0 then return -1 end return 0 end

local function nearest_enemy(game, p)
  local best, bd
  for _, o in ipairs(game.players) do
    if o.alive and o.id ~= p.id then
      local d = abs(o.x - p.x) + abs(o.y - p.y) * 0.5
      if not bd or d < bd then best, bd = o, d end
    end
  end
  return best, bd
end

local function nearest_item(game, p)
  local best, bd
  for _, it in ipairs(game.items) do
    local d = abs(it.x - p.x) + abs(it.y - p.y)
    if not bd or d < bd then best, bd = it, d end
  end
  return best
end

-- true se tra i due punti non c'e' un muro pieno
local function clear_line(world, x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  local steps = math.ceil(math.sqrt(dx * dx + dy * dy) / 6)
  for i = 1, steps - 1 do
    local t = i / steps
    if world:tile_at(x1 + dx * t, y1 + dy * t) == "#" then return false end
  end
  return true
end

function Bot.think(game, index)
  local p = game.players[index]
  local inp = { mx = 0, my = 0, jump_held = false, jump_pressed = false, attack_pressed = false,
                dash_pressed = false, parry_pressed = false, pickup_pressed = false }
  if not p or not p.alive or game.phase ~= "playing" then return inp end
  local r = love.math.random
  local target = nearest_enemy(game, p)
  local goal_x, goal_y

  if not p.weapon then
    local it = nearest_item(game, p)
    if it then goal_x, goal_y = it.x, it.y end
  end
  if not goal_x and target then goal_x, goal_y = target.x, target.y end
  if not goal_x then return inp end

  local def = require("src.sim.player").weapon_def(p)
  local range = (def.kind == "ranged") and (def.bot_range or 140) or (def.hit and def.hit.w + 12 or 24)
  local dx = goal_x - p.x
  if target and p.weapon and abs(dx) < range * 0.5 and def.kind == "ranged" then
    inp.mx = -sign(dx) * 0.8      -- tiene le distanze con le armi a distanza
  elseif abs(dx) > range * 0.7 then
    inp.mx = sign(dx)
  end

  -- non corre nel vuoto: se davanti non c'e' terreno si ferma o salta
  if inp.mx ~= 0 and p.grounded then
    local w = game.world
    local danger = false
    for d = 8, 40, 8 do
      local ax = p.x + sign(inp.mx) * d
      if w:tile_at(ax, p.y - 4) == "^" then danger = true end
    end
    local ax = p.x + sign(inp.mx) * 12
    local ground_ahead = w:tile_at(ax, p.y + 4) ~= "." or w:tile_at(ax, p.y + 20) ~= "."
    if danger then
      inp.jump_pressed = true          -- spuntoni davanti: salta (il salto tenuto li supera)
    elseif not ground_ahead then
      if r() < 0.5 then inp.jump_pressed = true else inp.mx = 0 end
    end
  end
  -- appena punto dagli spuntoni: salta e prosegue nella stessa direzione per uscirne
  if p.spike_cd > 0 then
    inp.jump_pressed = p.grounded or p.vy > 0
    inp.mx = (p.vx ~= 0) and sign(p.vx) or p.facing
  end
  -- in aria sopra gli spuntoni: usa il doppio salto
  if not p.grounded and p.vy > 0 and game.world:tile_at(p.x, p.y + 20) == "^" then
    inp.jump_pressed = true
  end

  -- bloccato contro un muro: salta (e nel salto prova la parete)
  if inp.mx ~= 0 and abs(p.vx) < 5 and r() < 0.25 then
    inp.jump_pressed = true
  end
  if (goal_y and goal_y < p.y - 24) and p.grounded and r() < 0.08 then
    inp.jump_pressed = true
  elseif p.grounded and r() < 0.004 then
    inp.jump_pressed = true
  end
  inp.jump_held = inp.jump_pressed or p.vy < 0 or not p.grounded

  if target then
    local tdx, tdy = target.x - p.x, target.y - p.y
    local close = abs(tdx) < range + 8 and abs(tdy) < 22
    if def.kind == "ranged" and p.weapon then
      -- mira con la "levetta destra" verso il bersaglio, con un errore casuale
      local sx, sy = p.x, p.y - 12
      local ex, ey = target.x, target.y - 10
      local dist = math.sqrt((ex - sx) ^ 2 + (ey - sy) ^ 2)
      -- compensa la caduta del proiettile mirando un po' piu' in alto
      local pj = def.proj
      if pj and pj.gravity and pj.speed > 0 then
        local t = dist / pj.speed
        ey = ey - 0.5 * pj.gravity * t * t
      end
      local ang = math.atan2(ey - sy, ex - sx) + (r() - 0.5) * 0.25
      inp.ax, inp.ay = math.cos(ang), math.sin(ang)
      if dist < (def.bot_range or 220) * 1.4 and clear_line(game.world, sx, sy, ex, ey) then
        if def.auto then
          inp.attack_held = r() < 0.7
        elseif r() < 0.07 then
          inp.attack_pressed = true
        end
      end
    elseif close and r() < 0.07 then
      inp.attack_pressed = true
    end
    local ta = target.action
    if ta and ta.type == "attack" and abs(tdx) < 50 and abs(tdy) < 24 and r() < 0.12 then
      inp.parry_pressed = true
    end
    if close and r() < 0.012 then inp.dash_pressed = true end
  end
  if p.weapon and r() < 0.002 then inp.pickup_pressed = true end
  return inp
end

return Bot
