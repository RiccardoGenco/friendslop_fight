-- Aspetto delle mappe e dei personaggi, tutto disegnato via codice (niente immagini).
-- Le parti fisse (tile, decorazioni, sfondi) si disegnano una volta in una canvas
-- per mappa; ogni frame si disegnano solo le cose animate.

local data = require("src.sim.data")
local lg = love.graphics
local floor, sin, cos, min, max, abs = math.floor, math.sin, math.cos, math.min, math.max, math.abs

local Look = {}
local T = data.tile
local PAD = 260          -- margine dei livelli di sfondo (servono piu' larghi della mappa)

local function hash(a, b)
  local v = sin(a * 127.1 + b * 311.7) * 43758.5453
  return v - floor(v)
end
local function col(c, k, a)
  k = k or 1
  lg.setColor(min(1, c[1] * k), min(1, c[2] * k), min(1, c[3] * k), a or 1)
end
local function rect(x, y, w, h) lg.rectangle("fill", x, y, w, h) end

-- ---------------------------------------------------------------------------
-- Temi per mappa

local THEMES = {
  Arena = {
    sky = { { 0.10, 0.06, 0.18 }, { 0.62, 0.30, 0.22 } }, moon = { 1, 0.88, 0.65 },
    far = "ruins", farc = { 0.22, 0.12, 0.20 }, nearc = { 0.13, 0.07, 0.13 },
    stone = { 0.58, 0.46, 0.34 }, top = { 0.42, 0.64, 0.28 }, pattern = "brick",
    plat = { 0.64, 0.43, 0.24 }, spike = { 0.70, 0.66, 0.62 }, deco = "arena", ambient = "embers",
  },
  Fabbrica = {
    sky = { { 0.04, 0.07, 0.08 }, { 0.20, 0.22, 0.17 } },
    far = "factory", farc = { 0.10, 0.14, 0.14 }, nearc = { 0.06, 0.09, 0.09 },
    stone = { 0.30, 0.36, 0.39 }, top = { 0.92, 0.70, 0.12 }, pattern = "panel",
    plat = { 0.48, 0.53, 0.55 }, spike = { 0.62, 0.66, 0.70 }, deco = "factory", ambient = "sparks",
  },
  Tetti = {
    sky = { { 0.03, 0.04, 0.12 }, { 0.20, 0.22, 0.40 } }, moon = { 0.88, 0.94, 1 }, stars = true,
    far = "city", farc = { 0.11, 0.12, 0.24 }, nearc = { 0.06, 0.06, 0.15 },
    stone = { 0.52, 0.29, 0.25 }, top = { 0.30, 0.29, 0.36 }, pattern = "roof",
    plat = { 0.52, 0.37, 0.24 }, spike = { 0.66, 0.66, 0.72 }, deco = "roofs", ambient = "rain",
  },
}
THEMES.Miniera = {
  sky = { { 0.03, 0.02, 0.02 }, { 0.12, 0.07, 0.05 } },
  far = "cave", farc = { 0.10, 0.06, 0.05 }, nearc = { 0.06, 0.035, 0.03 },
  stone = { 0.42, 0.30, 0.22 }, top = { 0.50, 0.38, 0.26 }, pattern = "rock",
  plat = { 0.62, 0.42, 0.22 }, spike = { 0.55, 0.45, 0.38 }, deco = "mine", ambient = "dust",
}

local DEFAULT = {
  sky = { { 0.05, 0.06, 0.11 }, { 0.13, 0.15, 0.24 } }, stars = true,
  far = "grid", farc = { 0.12, 0.14, 0.22 }, nearc = { 0.08, 0.09, 0.15 },
  stone = { 0.23, 0.26, 0.38 }, top = { 0.40, 0.78, 0.92 }, pattern = "lab",
  plat = { 0.72, 0.62, 0.40 }, spike = { 0.68, 0.68, 0.74 }, ambient = "dust",
}
function Look.theme(world) return THEMES[world.name] or DEFAULT end

-- ---------------------------------------------------------------------------
-- Tile

local function draw_solid(w, th, c, r, x, y, anims)
  local function open(dc, dr) return w:tile(c + dc, r + dr) ~= "#" end
  local up, dn, lf, rt = open(0, -1), open(0, 1), open(-1, 0), open(1, 0)
  local near = up or dn or lf or rt or open(-1, -1) or open(1, -1) or open(-1, 1) or open(1, 1)
  local deep = not near and not (open(0, -2) or open(0, 2) or open(-2, 0) or open(2, 0))
  local k = deep and 0.55 or (near and 0.9 or 0.72)
  local s = th.stone
  col(s, k * (0.95 + 0.1 * hash(c, r)))
  rect(x, y, T, T)
  local p = th.pattern
  if p == "brick" then
    col(s, k * 0.68)
    rect(x, y + 7, T, 1); rect(x, y + 15, T, 1)
    local o = (r % 2 == 0) and 0 or 8
    rect(x + (3 + o) % 16, y, 1, 7); rect(x + (11 + o) % 16, y + 8, 1, 7)
    if hash(c * 2, r) > 0.6 then col(s, k * 1.12); rect(x + 1, y + 1, 5, 1) end
  elseif p == "panel" then
    col(s, k * 0.65)
    lg.rectangle("line", x + 0.5, y + 0.5, T - 1, T - 1)
    col(s, k * 1.35)
    rect(x + 2, y + 2, 1, 1); rect(x + 13, y + 2, 1, 1); rect(x + 2, y + 13, 1, 1); rect(x + 13, y + 13, 1, 1)
    if hash(c, r * 3) > 0.7 then col(s, k * 0.8); rect(x + 4, y + 6, 8, 4) end
  elseif p == "roof" then
    col(s, k * 0.7)
    for yy = 3, 15, 4 do rect(x, y + yy, T, 1) end
    col(s, k * 1.12)
    local o = (r % 2) * 2
    for xx = o, 15, 4 do rect(x + xx, y + 1, 1, 1); rect(x + xx, y + 9, 1, 1) end
  elseif p == "rock" then
    for i = 1, 4 do
      local hx, hy = floor(hash(c * 3 + i, r) * 12), floor(hash(r * 3 + i, c) * 12)
      col(s, k * (0.75 + 0.4 * hash(c + i, r + i)))
      rect(x + hx, y + hy, 3 + i % 3, 2 + i % 2)
    end
    if hash(c, r * 7) > 0.85 then lg.setColor(0.95, 0.75, 0.3, 0.8); rect(x + 6, y + 8, 2, 1) end   -- vena d'oro
  else
    col(s, k * 1.2)
    rect(x, y, T, 1); rect(x, y, 1, T)
    rect(x + 7, y + 7, 2, 2)
  end
  -- macchioline
  for i = 1, 3 do
    if hash(c * 7 + i, r) > 0.55 then
      col(s, k * 0.75)
      rect(x + floor(hash(c, r + i) * 14) + 1, y + floor(hash(r, c + i) * 14) + 1, 1, 1)
    end
  end
  -- bordi esposti
  if lf then col(s, 0.62); rect(x, y, 1, T) end
  if rt then col(s, 0.62); rect(x + T - 1, y, 1, T) end
  if dn then col(s, 0.42); rect(x, y + T - 2, T, 2) end
  if up then
    if th.deco == "factory" then
      -- strisce di pericolo
      for xx = 0, T - 1, 4 do
        if ((c * 4 + xx) / 4) % 2 < 1 then col(th.top, 1) else lg.setColor(0.1, 0.1, 0.1) end
        rect(x + xx, y, 4, 3)
      end
    else
      col(th.top, 1); rect(x, y, T, 3)
      col(th.top, 1.35); rect(x, y, T, 1)
    end
    col(th.top, 0.55); rect(x, y + 3, T, 1)
  end

  -- decorazioni
  local d = th.deco
  local hv = hash(c * 13, r * 7)
  if d == "arena" then
    if up and open(0, -2) and hv < 0.4 then
      col(th.top, 1.15)
      for b = 0, 2 do
        local bx = x + 3 + floor(hash(c + b, r) * 10)
        rect(bx, y - 2 - b % 2, 1, 2 + b % 2)
      end
    end
    if dn and hv > 0.75 then
      local len = 4 + floor(hash(c, r * 5) * 10)
      local vx = x + 2 + floor(hash(c * 3, r) * 12)
      col(th.top, 0.8); rect(vx, y + T, 1, len)
      col(th.top, 1.1); rect(vx - 1, y + T + floor(len / 2), 1, 1); rect(vx + 1, y + T + len - 1, 1, 1)
    end
    if (lf or rt) and not up and not dn and hv > 0.88 then
      anims[#anims + 1] = { kind = "torch", x = lf and x - 3 or x + T + 2, y = y + 6, seed = hv }
    end
  elseif d == "factory" then
    if dn and hv < 0.16 then
      local len = 8 + floor(hash(c, r * 9) * 30)
      lg.setColor(0.42, 0.44, 0.46)
      for yy = 0, len, 3 do
        if (yy / 3) % 2 == 0 then rect(x + 7, y + T + yy, 2, 3) else rect(x + 7.5, y + T + yy, 1, 3) end
      end
    elseif dn and hv > 0.9 then
      anims[#anims + 1] = { kind = "lamp", x = x + T / 2, y = y + T, seed = hv }
    end
    if (lf or rt) and hv > 0.5 and hv < 0.56 then
      lg.setColor(0.25, 0.30, 0.28)
      rect(lf and x - 2 or x + T, y, 2, T)
    end
  elseif d == "mine" then
    if dn and hv < 0.22 then
      -- trave di sostegno sotto il soffitto
      lg.setColor(0.45, 0.30, 0.16); rect(x, y + T, T, 3)
      lg.setColor(0.30, 0.20, 0.10); rect(x, y + T + 3, T, 1)
    elseif dn and hv > 0.9 then
      anims[#anims + 1] = { kind = "lamp", x = x + T / 2, y = y + T, seed = hv }
    end
    if (lf or rt) and not up and hv > 0.9 then
      anims[#anims + 1] = { kind = "torch", x = lf and x - 3 or x + T + 2, y = y + 6, seed = hv }
    end
  elseif d == "roofs" then
    if up and open(0, -2) and open(0, -3) and hv < 0.07 then
      local h = 10 + floor(hash(c, r) * 10)
      lg.setColor(0.22, 0.22, 0.28)
      rect(x + 7, y - h, 1, h); rect(x + 4, y - h + 4, 7, 1)
      anims[#anims + 1] = { kind = "blink", x = x + 7.5, y = y - h, seed = hv }
    elseif up and open(0, -2) and hv > 0.88 then
      col(th.stone, 0.75); rect(x + 4, y - 9, 7, 9)
      lg.setColor(0.12, 0.10, 0.12); rect(x + 3, y - 10, 9, 2)
    end
  end
end

-- blocco distruttibile: cassa di legno (fabbrica, tetti) o roccia crepata (arena, miniera)
local function draw_breakable(w, th, c, r, x, y)
  local crate = th.deco == "factory" or th.deco == "roofs"
  if crate then
    lg.setColor(0.10, 0.06, 0.03); rect(x, y, T, T)
    lg.setColor(0.62, 0.42, 0.20); rect(x + 1, y + 1, T - 2, T - 2)
    lg.setColor(0.45, 0.29, 0.13); rect(x + 1, y + 7, T - 2, 2); rect(x + 7, y + 1, 2, T - 2)
    lg.setColor(0.78, 0.56, 0.30); rect(x + 1, y + 1, T - 2, 1)
    lg.setColor(0.30, 0.18, 0.08); rect(x + 2, y + 2, 1, 1); rect(x + 13, y + 2, 1, 1)
    rect(x + 2, y + 13, 1, 1); rect(x + 13, y + 13, 1, 1)
  else
    col(th.stone, 0.95); rect(x, y, T, T)
    col(th.stone, 1.2); rect(x + 1, y + 1, T - 2, 1)
    -- crepe: si capisce che si puo' rompere
    lg.setColor(0.08, 0.06, 0.05)
    local o = floor(hash(c, r) * 6)
    rect(x + 3 + o, y + 2, 1, 4); rect(x + 4 + o, y + 5, 1, 4); rect(x + 5 + o, y + 8, 3, 1)
    rect(x + 8 + o % 3, y + 9, 1, 4); rect(x + 2, y + 11, 3, 1)
    col(th.stone, 0.7); rect(x, y + T - 1, T, 1); rect(x + T - 1, y, 1, T)
  end
end

local function draw_belt_base(x, y)
  lg.setColor(0.10, 0.10, 0.12); rect(x, y, T, T)
  lg.setColor(0.24, 0.25, 0.28); rect(x, y + 4, T, T - 4)
  lg.setColor(0.36, 0.37, 0.40); rect(x, y + 4, T, 1)
  lg.setColor(0.15, 0.15, 0.18); lg.circle("fill", x + 4, y + 10, 2.5); lg.circle("fill", x + 12, y + 10, 2.5)
end

local function draw_platform(w, th, c, r, x, y)
  local P = th.plat
  col(P, 1); rect(x, y, T, 4)
  col(P, 1.3); rect(x, y, T, 1)
  col(P, 0.55); rect(x, y + 4, T, 1)
  if th.deco == "factory" then
    col(P, 0.6)
    for xx = 2, T - 1, 3 do rect(x + xx, y + 1, 1, 3) end
  else
    col(P, 0.45); rect(x + 2, y + 2, 1, 1); rect(x + 13, y + 2, 1, 1)
    if c % 2 == 0 then col(P, 0.8); rect(x + 7, y + 1, 1, 3) end
  end
  -- staffe agli estremi
  col(P, 0.5)
  if w:tile(c - 1, r) ~= "=" then rect(x + 1, y + 5, 2, 4); rect(x + 3, y + 5, 2, 2) end
  if w:tile(c + 1, r) ~= "=" then rect(x + T - 3, y + 5, 2, 4); rect(x + T - 5, y + 5, 2, 2) end
end

local function draw_spikes(th, x, y)
  lg.setColor(0.18, 0.16, 0.18); rect(x, y + T - 3, T, 3)
  for i = 0, 2 do
    local bx = x + i * 5 + 1
    col(th.spike, 0.7)
    lg.polygon("fill", bx, y + T - 3, bx + 2.5, y + 4, bx + 5, y + T - 3)
    col(th.spike, 1.15)
    lg.polygon("fill", bx, y + T - 3, bx + 2.5, y + 4, bx + 2.5, y + T - 3)
    lg.setColor(0.9, 0.2, 0.2)
    rect(bx + 2, y + 4, 1, 3)
  end
end

-- ombre morbide sotto e accanto ai blocchi pieni
local function draw_shade(w, c, r, x, y)
  if w:tile(c, r - 1) == "#" then
    for i = 0, 5 do lg.setColor(0, 0, 0, 0.30 * (1 - i / 6)); rect(x, y + i, T, 1) end
  end
  if w:tile(c - 1, r) == "#" then
    for i = 0, 2 do lg.setColor(0, 0, 0, 0.18 * (1 - i / 3)); rect(x + i, y, 1, T) end
  end
  if w:tile(c + 1, r) == "#" then
    for i = 0, 2 do lg.setColor(0, 0, 0, 0.18 * (1 - i / 3)); rect(x + T - 1 - i, y, 1, T) end
  end
end

-- ---------------------------------------------------------------------------
-- Sfondi (livelli in parallasse)

local function far_layer(w, th, kind, color, near)
  local W, H = w.width + PAD * 2, w.height
  local cv = lg.newCanvas(W, H)
  lg.setCanvas(cv)
  lg.clear(0, 0, 0, 0)
  local seed = near and 50 or 0
  local base = H * (near and 0.82 or 0.66)
  local x = 0
  local i = seed
  if kind == "ruins" then
    -- colline e rovine di colonne
    for xx = 0, W, 4 do
      local h = 40 + sin(xx * 0.008 + seed) * 25 + sin(xx * 0.021) * 10
      col(color); rect(xx, base - h, 4, H)
    end
    while x < W do
      i = i + 1
      if hash(i, 1) > 0.55 then
        local cw, ch = 10 + hash(i, 2) * 8, 50 + hash(i, 3) * 70
        col(color, 1.15); rect(x, base - 40 - ch, cw, ch + 40)
        rect(x - 3, base - 40 - ch, cw + 6, 5)
      end
      x = x + 30 + hash(i, 4) * 30
    end
  elseif kind == "factory" then
    while x < W do
      i = i + 1
      local bw, bh = 40 + hash(i, 1) * 70, 60 + hash(i, 2) * (near and 90 or 160)
      col(color); rect(x, base - bh, bw, H)
      if hash(i, 3) > 0.5 then
        local cw, chh = 8 + hash(i, 4) * 6, 40 + hash(i, 5) * 80
        rect(x + bw * 0.3, base - bh - chh, cw, chh)
        col(color, 1.5); rect(x + bw * 0.3, base - bh - chh + 6, cw, 3)
      end
      for wy = base - bh + 10, H - 10, 14 do
        for wx = x + 6, x + bw - 8, 10 do
          if hash(wx, wy) > 0.82 then lg.setColor(0.9, 0.7, 0.3, near and 0.35 or 0.2); rect(wx, wy, 4, 5) end
        end
      end
      x = x + bw + hash(i, 6) * 20
    end
  elseif kind == "city" then
    while x < W do
      i = i + 1
      local bw, bh = 30 + hash(i, 1) * 60, 80 + hash(i, 2) * (near and 120 or 220)
      col(color); rect(x, base - bh, bw, H)
      if hash(i, 7) > 0.7 then rect(x + bw / 2 - 1, base - bh - 20, 2, 20) end
      for wy = base - bh + 8, H - 8, 9 do
        for wx = x + 4, x + bw - 6, 7 do
          if hash(wx * 1.3, wy) > (near and 0.78 or 0.7) then
            lg.setColor(1, 0.85, 0.5, near and 0.45 or 0.25); rect(wx, wy, 3, 4)
          end
        end
      end
      x = x + bw + 4 + hash(i, 3) * 14
    end
  elseif kind == "cave" then
    -- pareti di roccia con stalattiti e stalagmiti, qualche cristallo
    for xx = 0, W, 4 do
      local top = 30 + sin(xx * 0.03 + seed) * 18 + sin(xx * 0.11) * 8 + (hash(xx, 3) > 0.92 and 30 or 0)
      local bot = 40 + sin(xx * 0.02 + seed * 2) * 20 + (hash(xx, 5) > 0.93 and 26 or 0)
      col(color); rect(xx, 0, 4, top); rect(xx, H - bot, 4, bot)
    end
    for k = 1, 30 do
      local cx, cy = hash(k, seed + 1) * W, H * (0.2 + 0.6 * hash(k, seed + 2))
      lg.setColor(0.5, 0.8, 1, near and 0.25 or 0.12)
      lg.polygon("fill", cx, cy - 4, cx + 2, cy, cx, cy + 4, cx - 2, cy)
    end
  else
    col(color, 1, 0.5)
    for xx = 0, W, 48 do rect(xx, 0, 1, H) end
    for yy = 0, H, 48 do rect(0, yy, W, 1) end
  end
  lg.setCanvas()
  return cv
end

local cache = {}

local function prepare(w)
  local cv = cache[w]
  if cv and cv.version == w.version then return cv end
  local th = Look.theme(w)
  lg.push("all")
  lg.origin()
  lg.setLineWidth(1)
  if not cv then
    cv = {}
    cv.far = far_layer(w, th, th.far, th.farc, false)
    cv.near = far_layer(w, th, th.far, th.nearc, true)
    cv.map = lg.newCanvas(w.width, w.height)
  end
  cv.anims, cv.version = {}, w.version
  lg.setCanvas(cv.map)
  lg.clear(0, 0, 0, 0)
  for r = 1, w.rows_n do
    for c = 1, w.cols do
      if w.grid[r][c] ~= "#" then draw_shade(w, c, r, (c - 1) * T, (r - 1) * T) end
    end
  end
  for r = 1, w.rows_n do
    for c = 1, w.cols do
      local t, x, y = w.grid[r][c], (c - 1) * T, (r - 1) * T
      if t == "#" and w.breakable[r] and w.breakable[r][c] then draw_breakable(w, th, c, r, x, y)
      elseif t == "#" and w.belts[r] and w.belts[r][c] then draw_belt_base(x, y)
      elseif t == "#" then draw_solid(w, th, c, r, x, y, cv.anims)
      elseif t == "=" then draw_platform(w, th, c, r, x, y)
      elseif t == "^" then draw_spikes(th, x, y) end
    end
  end
  lg.setCanvas()
  lg.pop()
  cache = { [w] = cv }   -- tiene solo la mappa corrente
  return cv
end

-- cielo a schermo intero (prima della telecamera)
function Look.sky(w, time, W, H)
  local th = Look.theme(w)
  local a, b = th.sky[1], th.sky[2]
  for i = 0, 17 do
    local t = i / 17
    lg.setColor(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t)
    rect(0, i * H / 18, W, H / 18 + 1)
  end
  if th.stars then
    for i = 1, 50 do
      local tw = 0.4 + 0.6 * abs(sin(time * (0.5 + hash(i, 9)) + i))
      lg.setColor(1, 1, 1, 0.5 * tw)
      rect(floor(hash(i, 1) * W), floor(hash(i, 2) * H * 0.6), 1, 1)
    end
  end
end

-- livelli dentro la telecamera: luna, sfondo lontano e vicino, nebbia
function Look.back(w, cam, time)
  local cv = prepare(w)
  local th = Look.theme(w)
  local cx, cy = cam.x - w.width / 2, cam.y - w.height / 2
  if th.moon then
    local mx, my = w.width * 0.72 + cx * 0.9, w.height * 0.2 + cy * 0.9
    lg.setColor(th.moon[1], th.moon[2], th.moon[3], 0.08); lg.circle("fill", mx, my, 40)
    lg.setColor(th.moon[1], th.moon[2], th.moon[3], 0.9); lg.circle("fill", mx, my, 22)
  end
  lg.setColor(1, 1, 1)
  lg.draw(cv.far, -PAD + cx * 0.7, cy * 0.5)
  lg.draw(cv.near, -PAD + cx * 0.4, cy * 0.25)
  local b = th.sky[2]
  for i = 0, 7 do
    lg.setColor(b[1], b[2], b[3], 0.05 * i)
    rect(-PAD, w.height - 80 + i * 10, w.width + PAD * 2, 10)
  end
end

-- mappa + decorazioni animate
function Look.map(w, time)
  local cv = prepare(w)
  lg.setColor(1, 1, 1)
  lg.draw(cv.map, 0, 0)
  for _, a in ipairs(cv.anims) do
    local s = a.seed * 10
    if a.kind == "torch" then
      lg.setColor(0.25, 0.18, 0.12); rect(a.x - 1, a.y, 3, 6)
      local f = sin(time * 13 + s) * 0.5 + sin(time * 7.3 + s * 2) * 0.5
      lg.setBlendMode("add")
      lg.setColor(1, 0.55, 0.2, 0.10 + 0.03 * f); lg.circle("fill", a.x, a.y - 3, 22 + 2 * f)
      lg.setBlendMode("alpha")
      lg.setColor(1, 0.45, 0.1); rect(a.x - 2, a.y - 5 - f, 5, 5 + f)
      lg.setColor(1, 0.9, 0.4); rect(a.x - 1, a.y - 3, 3, 3)
    elseif a.kind == "lamp" then
      local on = not (sin(time * 2 + s) > 0.97 and sin(time * 31) > 0)
      lg.setColor(0.2, 0.22, 0.22); rect(a.x - 4, a.y, 8, 3)
      if on then
        lg.setBlendMode("add")
        lg.setColor(1, 0.75, 0.3, 0.07)
        lg.polygon("fill", a.x - 3, a.y + 3, a.x + 3, a.y + 3, a.x + 22, a.y + 60, a.x - 22, a.y + 60)
        lg.setBlendMode("alpha")
        lg.setColor(1, 0.85, 0.45); rect(a.x - 2, a.y + 3, 4, 1)
      end
    elseif a.kind == "blink" then
      if (time + s) % 1.6 < 0.5 then
        lg.setBlendMode("add")
        lg.setColor(1, 0.2, 0.2, 0.25); lg.circle("fill", a.x, a.y, 4)
        lg.setBlendMode("alpha")
        lg.setColor(1, 0.3, 0.3); rect(a.x - 1, a.y - 1, 2, 2)
      end
    end
  end
end

-- elementi interattivi, disegnati ogni frame (si muovono o sono animati)
function Look.gadgets(game, time)
  local w = game.world
  local th = Look.theme(w)
  -- frecce dei nastri che scorrono
  for r = 1, w.rows_n do
    for c, d in pairs(w.belts[r]) do
      local x, y = (c - 1) * T, (r - 1) * T
      local off = (time * 60 * d) % 8
      lg.setColor(0.50, 0.50, 0.55); rect(x, y, T, 3)
      lg.setColor(1, 0.75, 0.15)
      for k = -1, 2 do
        local ax = x + k * 8 + off
        if ax >= x - 1 and ax <= x + T - 4 then
          if d > 0 then lg.polygon("fill", ax, y, ax + 4, y + 1.5, ax, y + 3)
          else lg.polygon("fill", ax + 4, y, ax, y + 1.5, ax + 4, y + 3) end
        end
      end
    end
  end
  -- molle: base, spirale che si comprime quando qualcuno ci sta vicino, piatto
  for _, s in ipairs(w.springs) do
    local press = 0
    for _, p in ipairs(game.players) do
      if p.alive and abs(p.x - s.x) < 10 and abs(p.y - s.y) < 6 then press = 3 end
    end
    local boing = Look.spring_t and Look.spring_t[s] or 0
    local top = s.y - 9 + press - boing * 4
    lg.setColor(0.08, 0.08, 0.1); rect(s.x - 7, s.y - 3, 14, 3)
    lg.setColor(0.35, 0.36, 0.4); rect(s.x - 6, s.y - 3, 12, 2)
    lg.setColor(0.75, 0.78, 0.82)
    local n = 3
    for i = 0, n - 1 do
      local yy = s.y - 3 - (s.y - 3 - top) * (i + 0.5) / n
      rect(s.x - 4 + (i % 2) * 2, yy, 6, 1)
    end
    lg.setColor(0.08, 0.08, 0.1); rect(s.x - 7, top - 2, 14, 3)
    lg.setColor(1, 0.35, 0.3); rect(s.x - 6, top - 2, 12, 2)
    lg.setColor(1, 0.7, 0.65); rect(s.x - 6, top - 2, 12, 1)
  end
  -- portali: ovale che pulsa, nel colore della coppia
  for _, pt in ipairs(w.portals) do
    local c = pt.pair == "P" and { 0.35, 0.8, 1 } or { 1, 0.55, 0.25 }
    local cx, cy = pt.x, pt.y - T
    lg.setBlendMode("add")
    lg.setColor(c[1], c[2], c[3], 0.12 + 0.05 * sin(time * 4))
    lg.ellipse("fill", cx, cy, 11, 20)
    lg.setBlendMode("alpha")
    lg.setColor(0.03, 0.02, 0.06, 0.9); lg.ellipse("fill", cx, cy, 6, 14)
    lg.setLineWidth(2)
    lg.setColor(c[1], c[2], c[3])
    lg.ellipse("line", cx, cy, 7 + sin(time * 5) * 0.6, 15)
    lg.setLineWidth(1)
    for k = 1, 6 do
      local a = time * 2.5 + k * 1.05
      lg.setColor(c[1], c[2], c[3], 0.8)
      rect(cx + cos(a) * 6, cy + sin(a) * 13, 1, 1)
    end
  end
  -- piattaforme mobili
  for _, m in ipairs(game.movers or {}) do
    local x, y = floor(m.x), floor(m.y)
    local P = th.plat
    -- cavi o binari verso il punto di partenza, per far capire il percorso
    lg.setColor(0.3, 0.3, 0.35, 0.5)
    if m.ddy ~= 0 then
      rect(x + 2, min(m.y0, m.y0 + m.ddy), 1, abs(m.ddy) + 4); rect(x + m.w - 3, min(m.y0, m.y0 + m.ddy), 1, abs(m.ddy) + 4)
    else
      rect(min(m.x0, m.x0 + m.ddx), m.y0 + 8, abs(m.ddx) + m.w, 1)
    end
    lg.setColor(0.06, 0.06, 0.08); rect(x - 1, y - 1, m.w + 2, 8)
    col(P, 1); rect(x, y, m.w, 5)
    col(P, 1.3); rect(x, y, m.w, 1)
    lg.setColor(1, 0.75, 0.15)
    for xx = 2, m.w - 4, 6 do rect(x + xx, y + 5, 3, 2) end
    -- spia che lampeggia nel verso del movimento
    if floor(time * 4) % 2 == 0 then
      lg.setColor(0.4, 1, 0.5)
      rect(x + (m.vx >= 0 and m.w - 3 or 1), y + 2, 2, 2)
    end
  end
end

-- particelle d'ambiente, senza stato: la posizione dipende solo dal tempo
function Look.ambient(w, time)
  local kind = Look.theme(w).ambient
  local W, H = w.width, w.height
  if kind == "rain" then
    lg.setColor(0.7, 0.8, 1, 0.22)
    for i = 1, 140 do
      local x = (hash(i, 1) * W - time * 90) % W
      local y = (hash(i, 2) * H + time * (380 + hash(i, 3) * 120)) % H
      lg.line(x, y, x - 2, y + 7)
    end
  elseif kind == "embers" then
    for i = 1, 40 do
      local x = (hash(i, 1) * W + sin(time * 0.8 + i) * 12) % W
      local y = H - (hash(i, 2) * H + time * (14 + hash(i, 3) * 22)) % H
      lg.setColor(1, 0.55 + 0.3 * hash(i, 4), 0.2, 0.35 + 0.35 * abs(sin(time * 3 + i)))
      rect(floor(x), floor(y), 1, 1)
    end
  elseif kind == "sparks" then
    for i = 1, 30 do
      local x = (hash(i, 1) * W + time * 8) % W
      local y = (hash(i, 2) * H + time * (50 + hash(i, 3) * 60)) % H
      lg.setColor(1, 0.75, 0.3, 0.45)
      rect(floor(x), floor(y), 1, 2)
    end
  else
    for i = 1, 40 do
      local x = (hash(i, 1) * W + time * (4 + hash(i, 3) * 6)) % W
      local y = (hash(i, 2) * H + sin(time * 0.5 + i) * 10) % H
      lg.setColor(0.8, 0.85, 1, 0.18)
      rect(floor(x), floor(y), 1, 1)
    end
  end
end

-- ---------------------------------------------------------------------------
-- Personaggio: l'animale scelto da quel giocatore (vedi src/heroes.lua).
-- Look.loadout[id] = { hero = "gatto", skin = 1 }, impostato da main all'avvio della partita.

local Heroes = require("src.heroes")
Look.loadout = {}

function Look.player(p, c, alpha, ps, time)
  local lo = Look.loadout[p.id] or { hero = Heroes.list[(p.id - 1) % #Heroes.list + 1].id, skin = 1 }
  local flash = c[1] == 1 and c[2] == 1 and c[3] == 1
  Heroes.draw(lo.hero, lo.skin, p, data.colors[p.id] or c, alpha, flash, time, ps)
end

return Look
