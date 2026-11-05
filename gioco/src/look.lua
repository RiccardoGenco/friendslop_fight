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
  if cv then return cv end
  local th = Look.theme(w)
  cv = { anims = {} }
  lg.push("all")
  lg.origin()
  lg.setLineWidth(1)
  cv.far = far_layer(w, th, th.far, th.farc, false)
  cv.near = far_layer(w, th, th.far, th.nearc, true)
  cv.map = lg.newCanvas(w.width, w.height)
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
      if t == "#" then draw_solid(w, th, c, r, x, y, cv.anims)
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
-- Personaggio: testa con visiera, busto, gambe, sciarpa. Piedi in (x, y).

local BLACK = { 0.03, 0.03, 0.05 }

function Look.player(p, c, alpha, ps, time)
  local x, y = floor(p.x), floor(p.y)
  local f = p.facing
  if p.sliding and p.wall ~= 0 then f = -p.wall end   -- sul muro guarda via dalla parete
  local light = { min(1, c[1] * 0.7 + 0.35), min(1, c[2] * 0.7 + 0.35), min(1, c[3] * 0.7 + 0.35) }
  local dark = { c[1] * 0.5, c[2] * 0.5, c[3] * 0.5 }
  local dash = p.action and p.action.type == "dash"
  local bob, l1, l2, k1, k2 = 0, 0, 0, 0, 0     -- l = spostamento gamba, k = sollevamento piede
  local hand = nil
  if dash then
    l1, l2, k1, k2 = -2, -4, 1, 2
  elseif p.sliding then
    l1, l2, k1, k2 = -1, -3, 2, 0
    hand = { -6, -13 }
  elseif not p.grounded then
    if p.vy < -40 then l1, l2, k1, k2 = 1, -2, 2, 1
    else l1, l2, k1, k2 = 2, -2, 0, 1 end
  elseif abs(p.vx) > 20 then
    local ph = (ps.dist or 0) / 6
    l1 = floor(sin(ph) * 3 + 0.5); l2 = -l1
    k1 = floor(max(0, cos(ph)) * 2 + 0.5); k2 = floor(max(0, -cos(ph)) * 2 + 0.5)
    bob = (abs(sin(ph)) > 0.7) and -1 or 0
  else
    bob = (sin(time * 2.5 + p.id * 1.7) > 0.4) and 1 or 0
  end
  local blink = ((time + p.id * 0.7) % 3.3) < 0.12
  local sw = 2 + min(5, floor(abs(p.vx) / 35))
  local fl = floor(sin(time * 16 + p.id) * (abs(p.vx) > 40 and 1 or 0.4) + 0.5)

  local parts = {
    { dark, -4 + l2, -5 + k2 - k2, 3, 5 - k2 },        -- gamba dietro
    { dark, 1 + l1, -5, 3, 5 - k1 },                    -- gamba davanti
    { c, -5, -13 + bob, 10, 8 },                        -- busto
    { light, -5, -21 + bob, 10, 8 },                    -- testa
    { dark, -5 - sw, -13 + bob + fl, sw, 2 },           -- sciarpa
  }
  if hand then parts[#parts + 1] = { light, hand[1], hand[2] + bob, 2, 2 } end
  lg.push()
  lg.translate(x, y)
  lg.scale(f, 1)
  if dash then lg.shear(-0.25, 0) end
  for pass = 1, 2 do
    for _, q in ipairs(parts) do
      if pass == 1 then
        lg.setColor(BLACK[1], BLACK[2], BLACK[3], alpha)
        rect(q[2] - 1, q[3] - 1, q[4] + 2, q[5] + 2)
      else
        lg.setColor(q[1][1], q[1][2], q[1][3], alpha)
        rect(q[2], q[3], q[4], q[5])
      end
    end
  end
  -- visiera e occhio
  lg.setColor(0.08, 0.08, 0.12, alpha)
  rect(0, -18 + bob, 5, 3)
  lg.setColor(1, 1, 1, alpha)
  rect(2, blink and -17 + bob or -18 + bob, 2, blink and 1 or 2)
  -- cintura
  lg.setColor(dark[1], dark[2], dark[3], alpha)
  rect(-5, -7 + bob, 10, 1)
  lg.pop()
end

return Look
