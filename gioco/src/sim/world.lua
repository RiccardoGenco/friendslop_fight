-- Mappa a tile e collisioni. Nessuna dipendenza da LÖVE.
-- Simboli: # solido, = piattaforma attraversabile dal basso, ^ spuntoni,
--          S spawn giocatore, W spawner armi, C cassa centrale.
local data = require("src.sim.data")

local World = {}
World.__index = World

local floor = math.floor

function World.new(map)
  local T = data.tile
  local w = setmetatable({}, World)
  w.name = map.name
  w.rows_n = #map.rows
  w.cols = #map.rows[1]
  w.grid = {}
  w.spawns, w.weapon_spawns = {}, {}
  w.crate = nil
  for r = 1, w.rows_n do
    local line = map.rows[r]
    assert(#line == w.cols, "riga " .. r .. " della mappa " .. tostring(map.name) .. " ha lunghezza diversa")
    w.grid[r] = {}
    for c = 1, w.cols do
      local ch = line:sub(c, c)
      local tile = "."
      if ch == "#" or ch == "=" or ch == "^" then
        tile = ch
      elseif ch == "S" then
        w.spawns[#w.spawns + 1] = { x = (c - 0.5) * T, y = r * T }
      elseif ch == "W" then
        w.weapon_spawns[#w.weapon_spawns + 1] = { x = (c - 0.5) * T, y = r * T }
      elseif ch == "C" then
        w.crate = { x = (c - 0.5) * T, y = r * T }
      end
      w.grid[r][c] = tile
    end
  end
  w.width = w.cols * T
  w.height = w.rows_n * T
  for _, s in ipairs(w.spawns) do s.facing = (s.x < w.width / 2) and 1 or -1 end
  if not w.crate then w.crate = { x = w.width / 2, y = 4 * T } end
  return w
end

-- c, r sono indici 1-based. Fuori dai lati: muro. Sopra e sotto: vuoto.
function World:tile(c, r)
  if c < 1 or c > self.cols then return "#" end
  if r < 1 or r > self.rows_n then return "." end
  return self.grid[r][c]
end

function World:tile_at(x, y)
  local T = data.tile
  return self:tile(floor(x / T) + 1, floor(y / T) + 1)
end

-- Sposta il corpo b (x centro, y piedi, w, h) in orizzontale. Ritorna true se urta un muro.
function World:move_x(b, dx)
  local T = data.tile
  b.x = b.x + dx
  if dx == 0 then return false end
  local top, bottom = b.y - b.h, b.y
  local r0 = floor(top / T) + 1
  local r1 = floor((bottom - 0.001) / T) + 1
  if dx > 0 then
    local c = floor((b.x + b.w / 2 - 0.0001) / T) + 1
    for r = r0, r1 do
      if self:tile(c, r) == "#" then
        b.x = (c - 1) * T - b.w / 2
        return true
      end
    end
  else
    local c = floor((b.x - b.w / 2) / T) + 1
    for r = r0, r1 do
      if self:tile(c, r) == "#" then
        b.x = c * T + b.w / 2
        return true
      end
    end
  end
  return false
end

-- Sposta il corpo in verticale. Ritorna landed, bumped.
-- drop = true ignora le piattaforme attraversabili (discesa volontaria).
function World:move_y(b, dy, drop)
  local T = data.tile
  local prev = b.y
  b.y = b.y + dy
  local left = b.x - b.w / 2 + 0.001
  local right = b.x + b.w / 2 - 0.001
  local c0 = floor(left / T) + 1
  local c1 = floor(right / T) + 1
  if dy > 0 then
    local rp = floor(prev / T) + 1
    local rb = floor(b.y / T) + 1
    for r = rp, rb do
      local surface = (r - 1) * T
      if surface >= prev - 0.01 then
        for c = c0, c1 do
          local t = self:tile(c, r)
          if t == "#" or (t == "=" and not drop) then
            b.y = surface
            return true, false
          end
        end
      end
    end
  elseif dy < 0 then
    local r = floor((b.y - b.h) / T) + 1
    for c = c0, c1 do
      if self:tile(c, r) == "#" then
        b.y = r * T + b.h
        return false, true
      end
    end
  end
  return false, false
end

-- true se il corpo poggia su una piattaforma attraversabile (non su un solido)
function World:standing_on_oneway(b)
  local T = data.tile
  local r = floor((b.y + 1) / T) + 1
  local c0 = floor((b.x - b.w / 2 + 0.001) / T) + 1
  local c1 = floor((b.x + b.w / 2 - 0.001) / T) + 1
  local oneway = false
  for c = c0, c1 do
    local t = self:tile(c, r)
    if t == "#" then return false end
    if t == "=" then oneway = true end
  end
  return oneway
end

-- true se il rettangolo tocca almeno un tile del tipo dato
function World:rect_touches(x1, y1, x2, y2, ch)
  local T = data.tile
  local c0, c1 = floor(x1 / T) + 1, floor((x2 - 0.001) / T) + 1
  local r0, r1 = floor(y1 / T) + 1, floor((y2 - 0.001) / T) + 1
  for r = r0, r1 do
    for c = c0, c1 do
      if self:tile(c, r) == ch then return true end
    end
  end
  return false
end

return World
