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
  sky = { { 0.07, 0.05, 0.05 }, { 0.22, 0.14, 0.10 } },
  far = "cave", farc = { 0.17, 0.11, 0.09 }, nearc = { 0.11, 0.07, 0.055 },
  stone = { 0.52, 0.38, 0.27 }, top = { 0.62, 0.48, 0.32 }, pattern = "rock",
  plat = { 0.62, 0.42, 0.22 }, spike = { 0.55, 0.45, 0.38 }, deco = "mine", ambient = "dust",
}

local DEFAULT = {
  sky = { { 0.05, 0.06, 0.11 }, { 0.13, 0.15, 0.24 } }, stars = true,
  far = "grid", farc = { 0.12, 0.14, 0.22 }, nearc = { 0.08, 0.09, 0.15 },
  stone = { 0.23, 0.26, 0.38 }, top = { 0.40, 0.78, 0.92 }, pattern = "lab",
  plat = { 0.72, 0.62, 0.40 }, spike = { 0.68, 0.68, 0.74 }, ambient = "dust",
}
THEMES.Arena.tex, THEMES.Fabbrica.tex, THEMES.Tetti.tex, THEMES.Miniera.tex = "arena", "fabbrica", "tetti", "miniera"
DEFAULT.tex = "prova"
-- tinta delle texture: le accorda con la luce della mappa (tramonto, notte, grotta...)
THEMES.Arena.tint = { 0.80, 0.68, 0.66 }
THEMES.Fabbrica.tint = { 0.80, 0.86, 0.86 }
THEMES.Tetti.tint = { 0.72, 0.72, 0.86 }
THEMES.Miniera.tint = { 0.85, 0.74, 0.66 }
DEFAULT.tint = { 0.85, 0.88, 1 }
function Look.theme(world) return THEMES[world.name] or DEFAULT end

-- Texture dipinte (assets/tiles/<nome>.png): 32 pixel d'arte per casella, si ripetono senza cuciture.
-- La casella prende il pezzo che le spetta per posizione, cosi' il disegno continua da una all'altra.
local textures = {}
local function texture(name)
  if not name then return nil end
  local t = textures[name]
  if t ~= nil then return t end
  t = false
  local path = "assets/tiles/" .. name .. ".png"
  if love.filesystem.getInfo(path) then
    local ok, img = pcall(lg.newImage, path)
    if ok then
      img:setFilter("nearest", "nearest")
      img:setWrap("repeat", "repeat")   -- la misura puo' non essere un multiplo della casella
      local iw, ih = img:getDimensions()
      t = { img = img, w = iw, h = ih, quad = lg.newQuad(0, 0, 32, 32, iw, ih) }
    end
  end
  textures[name] = t
  return t
end
Look.texture = texture

-- ---------------------------------------------------------------------------
-- Tile

-- ---------------------------------------------------------------------------
-- Mattonelle a doppia densita' (mezzo pixel del mondo), luce da sinistra in alto.
-- hp(x, y, w, h) disegna in mezzi pixel dentro la mattonella corrente.

local TX, TY = 0, 0
local function hp(x0, y0, w0, h0) rect(TX + x0 * 0.5, TY + y0 * 0.5, w0 * 0.5, h0 * 0.5) end
local function tone(c, k, a) lg.setColor(min(1, c[1] * k), min(1, c[2] * k), min(1, c[3] * k), a or 1) end

-- distanza (in mattonelle, fino a 4) dalla casella libera piu' vicina: piu' e' profonda, piu' e' scura
local function depth(w, c, r)
  for d = 1, 3 do
    for dr = -d, d do
      for dc = -d, d do
        if w:tile(c + dc, r + dr) ~= "#" then return d end
      end
    end
  end
  return 4
end
local DEPTH_K = { 1, 0.82, 0.68, 0.58 }

local function tex_brick(s, k, c, r, small)
  local bw, bh = small and 8 or 16, small and 4 or 8
  tone(s, k * 0.5); hp(0, 0, 32, 32)                          -- malta
  for j = 0, 32 / bh - 1 do
    local row = (r - 1) * (32 / bh) + j
    local off = (row % 2 == 0) and 0 or bw / 2
    for bx = -bw, 32, bw do
      local X = bx + off
      local x0, x1 = math.max(0, X), math.min(32, X + bw - 1)
      if x1 > x0 then
        local id = floor(((c - 1) * 32 + X) / bw)
        local v = 0.86 + 0.24 * hash(id, row)
        local y0 = j * bh
        tone(s, k * v); hp(x0, y0, x1 - x0, bh - 1)
        tone(s, k * v * 1.18); hp(x0, y0, x1 - x0, 1)
        if X >= 0 then hp(x0, y0, 1, bh - 1) end
        tone(s, k * v * 0.78); hp(x0, y0 + bh - 2, x1 - x0, 1)
        if not small and hash(id * 3, row) > 0.9 then
          tone(s, k * 0.45)
          local cx = x0 + 3 + floor(hash(id, row * 2) * 6)
          hp(cx, y0 + 1, 1, 2); hp(cx + 1, y0 + 3, 1, 2); hp(cx, y0 + 5, 1, 1)
        end
      end
    end
  end
end

local function tex_panel(s, k, c, r)
  tone(s, k); hp(0, 0, 32, 32)
  tone(s, k * 1.12); hp(3, 3, 26, 26)
  tone(s, k * 1.3); hp(0, 0, 32, 1); hp(0, 0, 1, 32)
  tone(s, k * 0.55); hp(0, 31, 32, 1); hp(31, 0, 1, 32)
  tone(s, k * 0.75); hp(3, 28, 26, 1); hp(28, 3, 1, 26)
  for _, q in ipairs({ { 4, 4 }, { 26, 4 }, { 4, 26 }, { 26, 26 } }) do
    tone(s, k * 0.5); hp(q[1], q[2], 2, 2)
    tone(s, k * 1.6); hp(q[1], q[2], 1, 1)
  end
  local hv = hash(c * 7, r * 13)
  if hv < 0.18 then
    -- griglia di ventilazione
    tone(s, k * 0.35)
    for yy = 10, 20, 4 do hp(9, yy, 14, 2) end
    tone(s, k * 1.4)
    for yy = 12, 22, 4 do hp(9, yy, 14, 1) end
  elseif hv > 0.85 then
    -- colatura di ruggine da un rivetto
    lg.setColor(0.55, 0.3, 0.14, 0.55 * k)
    hp(26, 6, 2, 10); hp(27, 16, 1, 6)
  elseif hv > 0.78 then
    lg.setColor(0.95, 0.75, 0.15, k)
    hp(11, 11, 10, 10)
    lg.setColor(0.1, 0.1, 0.1, k)
    hp(15, 13, 2, 4); hp(15, 18, 2, 2)
  end
end

local function tex_rock(s, k, c, r)
  tone(s, k * 0.62); hp(0, 0, 32, 32)
  for i = 1, 7 do
    local sx = floor(hash(c * 13 + i, r * 7) * 26)
    local sy = floor(hash(r * 11 + i, c * 5) * 26)
    local sw = 6 + floor(hash(c + i * 3, r) * 8)
    local sh = 5 + floor(hash(r + i * 5, c) * 6)
    local v = 0.85 + 0.3 * hash(c * i, r + i)
    tone(s, k * v * 0.7); hp(sx + 1, sy + 1, sw, sh)
    tone(s, k * v); hp(sx, sy, sw, sh)
    tone(s, k * v * 1.25); hp(sx + 1, sy, sw - 2, 1); hp(sx, sy + 1, 1, sh - 2)
  end
  local hv = hash(c * 3, r * 17)
  if hv > 0.88 then
    lg.setColor(1, 0.8, 0.3, k)                                  -- vena d'oro
    hp(10, 14, 3, 2); hp(13, 15, 2, 1); hp(15, 16, 3, 2)
    lg.setColor(1, 1, 0.7, k); hp(11, 14, 1, 1)
  elseif hv < 0.06 then
    lg.setColor(0.5, 0.85, 1, k)                                  -- cristallo
    hp(18, 10, 2, 5); hp(20, 12, 2, 3)
    lg.setColor(0.9, 1, 1, k); hp(18, 10, 1, 2)
  end
end

local function tex_window(s, c, r)
  if hash(c * 5, r * 3) < 0.35 then
    local lit = hash(c, r * 9) > 0.45
    lg.setColor(0.08, 0.06, 0.07); hp(7, 5, 18, 22)
    tone(s, 1.25); hp(7, 5, 18, 2)
    if lit then lg.setColor(1, 0.82, 0.45) else lg.setColor(0.12, 0.16, 0.28) end
    hp(9, 8, 6, 8); hp(17, 8, 6, 8); hp(9, 18, 6, 7); hp(17, 18, 6, 7)
    if lit then lg.setColor(1, 0.95, 0.75) else lg.setColor(0.3, 0.38, 0.55) end
    hp(9, 8, 2, 1); hp(17, 8, 2, 1)
  end
end

local function tex_building(s, k, c, r, interior)
  tex_brick(s, k, c, r, true)
  if interior then tex_window(s, c, r) end   -- finestre nelle parti interne dei palazzi
end

local function draw_solid(w, th, c, r, x, y, anims)
  local function open(dc, dr) return w:tile(c + dc, r + dr) ~= "#" end
  local up, dn, lf, rt = open(0, -1), open(0, 1), open(-1, 0), open(1, 0)
  local d = depth(w, c, r)
  local k = DEPTH_K[d]
  local s = th.stone
  TX, TY = x, y
  local p = th.pattern
  local tx = texture(th.tex)
  if tx then
    tx.quad:setViewport(((c - 1) * 32) % tx.w, ((r - 1) * 32) % tx.h, 32, 32)
    local tn = th.tint or { 1, 1, 1 }
    lg.setColor(k * tn[1], k * tn[2], k * tn[3])
    lg.draw(tx.img, tx.quad, x, y, 0, 0.5, 0.5)
    if p == "roof" and d >= 2 then tex_window(s, c, r) end
  elseif p == "brick" then tex_brick(s, k, c, r)
  elseif p == "panel" then tex_panel(s, k, c, r)
  elseif p == "rock" then tex_rock(s, k, c, r)
  elseif p == "roof" then tex_building(s, k, c, r, d >= 2)
  else tex_panel(s, k, c, r) end

  -- bordi: lato sinistro in luce, destro e sotto in ombra, contorno scuro sul vuoto
  if lf then tone(s, 1.15); hp(0, 0, 2, 32); lg.setColor(0.04, 0.03, 0.05); hp(0, 0, 1, 32) end
  if rt then tone(s, 0.5); hp(29, 0, 3, 32); lg.setColor(0.04, 0.03, 0.05); hp(31, 0, 1, 32) end
  if dn then
    tone(s, 0.45); hp(0, 28, 32, 4)
    lg.setColor(0.04, 0.03, 0.05); hp(0, 31, 32, 1)
  end
  if up then
    local t = th.top
    local d2 = th.deco
    if d2 == "factory" then
      -- bordo d'acciaio con strisce di pericolo inclinate
      for yy = 0, 5 do
        for xx = 0, 31 do
          local on = floor(((c - 1) * 32 + xx + yy) / 5) % 2 == 0
          if on then tone(t, 1) else lg.setColor(0.12, 0.12, 0.13) end
          hp(xx, yy, 1, 1)
        end
      end
      lg.setColor(0.75, 0.78, 0.82); hp(0, 6, 32, 1)
      lg.setColor(0.2, 0.22, 0.24); hp(0, 7, 32, 2)
    elseif d2 == "arena" then
      -- erba: striscia con luce, ciuffi sopra e frange che pendono
      tone(t, 0.6); hp(0, 0, 32, 6)
      tone(t, 1); hp(0, 0, 32, 4)
      tone(t, 1.35); hp(0, 0, 32, 1)
      for i = 0, 7 do
        local gx = i * 4 + floor(hash(c * 8 + i, r) * 3)
        local hh = 1 + floor(hash(c + i, r * 3) * 3)
        tone(t, 1.2); hp(gx, -hh, 1, hh)
        if hash(c * 2 + i, r) > 0.5 then tone(t, 0.75); hp(gx + 1, 6, 1, 1 + floor(hash(i, c) * 3)) end
      end
      lg.setColor(0, 0, 0, 0.25); hp(0, 6, 32, 2)
    elseif d2 == "roofs" then
      -- cornicione di pietra
      tone(t, 1); hp(0, 0, 32, 6)
      tone(t, 1.4); hp(0, 0, 32, 1)
      tone(t, 0.6); hp(0, 5, 32, 1)
      lg.setColor(0.04, 0.03, 0.05); hp(0, 6, 32, 1)
      tone(t, 0.8); hp(floor(hash(c, r) * 24), 2, 4, 1)
    elseif d2 == "mine" then
      -- crosta di terra con sassolini
      tone(t, 0.8); hp(0, 0, 32, 5)
      tone(t, 1.1); hp(0, 0, 32, 2)
      for i = 0, 3 do
        local gx = floor(hash(c * 4 + i, r * 2) * 29)
        tone(t, 1.35); hp(gx, 2, 3, 2)
        tone(t, 0.6); hp(gx + 1, 3, 2, 1)
      end
      lg.setColor(0, 0, 0, 0.3); hp(0, 5, 32, 2)
    else
      tone(t, 1); hp(0, 0, 32, 4)
      tone(t, 1.4); hp(0, 0, 32, 1)
      tone(t, 0.55); hp(0, 4, 32, 1)
    end
  end
  -- spigoli esterni arrotondati: si cancellano due pixel d'angolo
  lg.setBlendMode("replace")
  lg.setColor(0, 0, 0, 0)
  if up and lf then hp(0, 0, 2, 1); hp(0, 1, 1, 1) end
  if up and rt then hp(30, 0, 2, 1); hp(31, 1, 1, 1) end
  if dn and lf then hp(0, 31, 2, 1); hp(0, 30, 1, 1) end
  if dn and rt then hp(30, 31, 2, 1); hp(31, 30, 1, 1) end
  lg.setBlendMode("alpha")

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
-- blocco distruttibile: cassa di legno (fabbrica, tetti) o roccia crepata (arena, miniera)
local function draw_breakable(w, th, c, r, x, y)
  TX, TY = x, y
  local crate = th.deco == "factory" or th.deco == "roofs"
  local img = texture(crate and "blocco_cassa" or "blocco_pietra")
  if img then
    -- disegno dipinto; nella miniera la pietra prende il colore della roccia
    local tn = crate and { 1, 1, 1 } or (th.tint or { 1, 1, 1 })
    if th.deco == "mine" then tn = { 0.78, 0.62, 0.5 } end
    lg.setColor(tn[1], tn[2], tn[3])
    img.quad:setViewport(0, 0, 32, 32)
    lg.draw(img.img, img.quad, x, y, 0, 0.5, 0.5)
    return
  end
  if crate then
    local wd = { 0.66, 0.45, 0.22 }
    lg.setColor(0.08, 0.05, 0.03); hp(0, 0, 32, 32)
    tone(wd, 1); hp(1, 1, 30, 30)
    -- assi orizzontali
    for yy = 1, 25, 8 do
      tone(wd, 0.9 + 0.15 * hash(c, r * 4 + yy)); hp(4, yy + 3, 24, 6)
      tone(wd, 0.7); hp(4, yy + 8, 24, 1)
    end
    -- telaio e croce
    tone(wd, 0.62); hp(1, 1, 30, 3); hp(1, 28, 30, 3); hp(1, 1, 3, 30); hp(28, 1, 3, 30)
    tone(wd, 1.25); hp(1, 1, 30, 1); hp(1, 1, 1, 30)
    tone(wd, 0.55)
    for i = 0, 23 do hp(4 + i, 4 + i, 2, 1) end
    tone(wd, 1.15)
    for i = 0, 23 do hp(4 + i, 3 + i, 1, 1) end
    lg.setColor(0.8, 0.8, 0.85)
    for _, q in ipairs({ { 2, 2 }, { 29, 2 }, { 2, 29 }, { 29, 29 } }) do hp(q[1], q[2], 1, 1) end
  else
    tex_rock(th.stone, 1.05, c, r)
    -- crepe marcate e bordo chiaro: si capisce che si rompe
    lg.setColor(0.06, 0.04, 0.03)
    local o = floor(hash(c, r) * 8)
    hp(6 + o, 2, 2, 6); hp(8 + o, 7, 2, 6); hp(7 + o, 12, 4, 2); hp(10 + o, 13, 2, 7); hp(12 + o, 19, 5, 2)
    hp(3, 20, 6, 2); hp(8, 21, 2, 5); hp(20, 6, 6, 2); hp(24, 7, 2, 5)
    tone(th.stone, 1.5); hp(7 + o, 2, 1, 5); hp(9 + o, 7, 1, 5)
    tone(th.stone, 1.3); hp(0, 0, 32, 1); hp(0, 0, 1, 32)
    lg.setColor(0.04, 0.03, 0.05); hp(0, 31, 32, 1); hp(31, 0, 1, 32)
  end
end

local function draw_belt_base(x, y)
  TX, TY = x, y
  lg.setColor(0.05, 0.05, 0.06); hp(0, 0, 32, 32)
  lg.setColor(0.22, 0.23, 0.26); hp(0, 8, 32, 24)
  lg.setColor(0.32, 0.33, 0.36); hp(0, 8, 32, 1)
  for _, cx in ipairs({ 8, 24 }) do
    lg.setColor(0.08, 0.08, 0.1); lg.circle("fill", x + cx * 0.5, y + 10, 3)
    lg.setColor(0.45, 0.46, 0.5); lg.circle("fill", x + cx * 0.5, y + 10, 2.2)
    lg.setColor(0.7, 0.72, 0.76); hp(cx - 2, 16, 2, 1)
    lg.setColor(0.15, 0.15, 0.18); hp(cx - 1, 19, 2, 2)
  end
  lg.setColor(0.15, 0.15, 0.17); hp(0, 28, 32, 4)
end

-- cose appese sotto le piattaforme: stendardi (arena), lampade (fabbrica, miniera), lucine (tetti)
local function draw_hanging(w, th, c, r, x, y, anims)
  if w:tile(c, r + 1) ~= "." or w:tile(c, r + 2) ~= "." then return end
  local hv = hash(c * 17, r * 5)
  local d = th.deco
  if d == "arena" and hv < 0.12 and w:tile(c - 1, r) == "=" and w:tile(c + 1, r) == "=" then
    lg.setColor(0.25, 0.2, 0.15); rect(x + 4, y + 5, 8, 1)
    local cr = hash(c, r) > 0.5 and { 0.7, 0.18, 0.15 } or { 0.2, 0.3, 0.6 }
    lg.setColor(0.08, 0.05, 0.05); rect(x + 4.5, y + 5.5, 7, 13); lg.polygon("fill", x + 4.5, y + 18.5, x + 11.5, y + 18.5, x + 8, y + 22)
    col(cr); rect(x + 5, y + 6, 6, 12); lg.polygon("fill", x + 5, y + 18, x + 11, y + 18, x + 8, y + 21)
    lg.setColor(0.95, 0.78, 0.3); rect(x + 7.5, y + 9, 1, 6); rect(x + 6, y + 11, 4, 1)
    col(cr, 0.7); rect(x + 5, y + 6, 1.5, 12)
  elseif (d == "factory" or d == "mine") and hv < 0.1 then
    lg.setColor(0.2, 0.2, 0.22); rect(x + 7.5, y + 5, 1, 6)
    if d == "mine" then
      lg.setColor(0.08, 0.06, 0.05); rect(x + 5, y + 10, 6, 7)
      lg.setColor(1, 0.8, 0.4); rect(x + 6, y + 11, 4, 5)
      anims[#anims + 1] = { kind = "glow", x = x + 8, y = y + 13, color = { 1, 0.7, 0.3 }, seed = hv }
    else
      anims[#anims + 1] = { kind = "lamp", x = x + 8, y = y + 10, seed = hv }
    end
  elseif d == "roofs" and w:tile(c + 1, r) == "=" and hv < 0.5 then
    -- filo di lucine colorate che pende tra le travi
    lg.setColor(0.15, 0.15, 0.18)
    rect(x, y + 6, T, 0.5)
    local cols = { { 1, 0.4, 0.4 }, { 1, 0.85, 0.3 }, { 0.4, 0.8, 1 }, { 0.5, 1, 0.5 } }
    local cc = cols[(c % 4) + 1]
    anims[#anims + 1] = { kind = "bulb", x = x + 8, y = y + 7.5, color = cc, seed = hash(c, r) }
  end
end

local function draw_platform(w, th, c, r, x, y)
  local P = th.plat
  TX, TY = x, y
  local left_end, right_end = w:tile(c - 1, r) ~= "=", w:tile(c + 1, r) ~= "="
  if th.deco == "factory" then
    -- grata d'acciaio: telaio, fori, rivetti
    lg.setColor(0.04, 0.03, 0.05); hp(0, 0, 32, 10)
    tone(P, 1); hp(0, 1, 32, 8)
    tone(P, 1.35); hp(0, 1, 32, 1)
    tone(P, 0.55); hp(0, 7, 32, 2)
    lg.setColor(0.06, 0.06, 0.08)
    for xx = 2, 30, 4 do hp(xx, 3, 2, 3) end
    tone(P, 1.5)
    for xx = 2, 30, 4 do hp(xx, 2, 2, 1) end
  else
    -- tavola di legno: venature, giunture con chiodi
    lg.setColor(0.04, 0.03, 0.05); hp(0, 0, 32, 10)
    tone(P, 1); hp(0, 1, 32, 8)
    tone(P, 1.3); hp(0, 1, 32, 1)
    tone(P, 0.6); hp(0, 7, 32, 2)
    tone(P, 0.8)
    for i = 0, 2 do
      local gx = floor(hash(c * 3 + i, r) * 24)
      hp(gx, 3 + (i % 2) * 2, 6 + floor(hash(i, c) * 6), 1)
    end
    if c % 2 == 0 and not left_end then
      lg.setColor(0.04, 0.03, 0.05); hp(0, 1, 1, 7)
      lg.setColor(0.75, 0.75, 0.8); hp(2, 3, 1, 1); hp(2, 6, 1, 1)
    end
  end
  if left_end then lg.setColor(0.04, 0.03, 0.05); hp(0, 0, 1, 10) end
  if right_end then lg.setColor(0.04, 0.03, 0.05); hp(31, 0, 1, 10) end
  -- staffe agli estremi
  local function bracket(x0, dir)
    lg.setColor(0.04, 0.03, 0.05)
    lg.polygon("fill", x + x0 * 0.5, y + 4.5, x + (x0 + dir * 9) * 0.5, y + 4.5, x + x0 * 0.5, y + 13)
    tone(P, 0.55)
    lg.polygon("fill", x + (x0 + dir) * 0.5, y + 5, x + (x0 + dir * 7) * 0.5, y + 5, x + (x0 + dir) * 0.5, y + 11.5)
  end
  if left_end then bracket(2, 1) end
  if right_end then bracket(30, -1) end
end

local function draw_spikes(th, x, y)
  TX, TY = x, y
  lg.setColor(0.04, 0.03, 0.05); hp(0, 25, 32, 7)
  lg.setColor(0.25, 0.22, 0.25); hp(0, 26, 32, 5)
  lg.setColor(0.4, 0.36, 0.4); hp(0, 26, 32, 1)
  for i = 0, 3 do
    local bx = x + i * 4
    local by = y + 13
    lg.setColor(0.04, 0.03, 0.05)
    lg.polygon("fill", bx - 0.5, by, bx + 2, y + 3.5, bx + 4.5, by)
    tone(th.spike, 0.75)
    lg.polygon("fill", bx, by, bx + 2, y + 4.5, bx + 4, by)
    tone(th.spike, 1.3)
    lg.polygon("fill", bx + 0.5, by, bx + 2, y + 4.5, bx + 2, by)
    lg.setColor(0.85, 0.15, 0.15)
    lg.polygon("fill", bx + 1.4, y + 7, bx + 2, y + 4.5, bx + 2.6, y + 7)
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
local last_r = nil

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
    cv.map = lg.newCanvas(w.width, w.height, { dpiscale = 2 })   -- doppia densita': le texture restano nitide
    cv.map:setFilter("nearest", "nearest")
  end
  cv.anims, cv.version = {}, w.version
  lg.setCanvas(cv.map)
  lg.clear(0, 0, 0, 0)
  for r = 1, w.rows_n do
    for c = 1, w.cols do
      if w.grid[r][c] ~= "#" then draw_shade(w, c, r, (c - 1) * T, (r - 1) * T) end
    end
  end
  -- oggetti di scena: su pavimenti pieni, con due caselle libere sopra, lontani da molle e portali
  local Props = require("src.props")
  local set = Props.THEME[th.deco or ""]
  if set then
    local last = -100
    for r = 3, w.rows_n - 1 do
      for c = 2, w.cols - 1 do
        local below = w.grid[r + 1] and w.grid[r + 1][c]
        local solid_below = (below == "#" and not w.breakable[r + 1][c] and not w.belts[r + 1][c]) or below == "="
        if solid_below and w.grid[r][c] == "." and w.grid[r - 1][c] == "." and w.grid[r - 2][c] == "."
           and hash(c * 5, r * 3) < 0.2 and (c - last > 4 or r ~= last_r) then
          local x, y = (c - 0.5) * T, r * T
          local near = false
          for _, g in ipairs(w.springs) do if abs(g.x - x) < 24 and abs(g.y - y) < 20 then near = true end end
          for _, g in ipairs(w.portals) do if abs(g.x - x) < 24 and abs(g.y - y) < 40 then near = true end end
          if not near then
            local pick = set[floor(hash(c, r * 11) * #set) + 1]
            Props.draw(pick[1], x, y)
            if pick.glow then cv.anims[#cv.anims + 1] = { kind = "glow", x = x, y = y - 10, color = pick.glow, seed = hash(c, r) } end
            last, last_r = c, r
          end
        end
      end
    end
  end
  for r = 1, w.rows_n do
    for c = 1, w.cols do
      local t, x, y = w.grid[r][c], (c - 1) * T, (r - 1) * T
      if t == "#" and w.breakable[r] and w.breakable[r][c] then draw_breakable(w, th, c, r, x, y)
      elseif t == "#" and w.belts[r] and w.belts[r][c] then draw_belt_base(x, y)
      elseif t == "#" then draw_solid(w, th, c, r, x, y, cv.anims)
      elseif t == "=" then draw_platform(w, th, c, r, x, y); draw_hanging(w, th, c, r, x, y, cv.anims)
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
      local f = sin(time * 13 + s) * 0.5 + sin(time * 7.3 + s * 2) * 0.5
      -- alone morbido: tanti cerchi additivi sempre piu' larghi e deboli
      lg.setBlendMode("add")
      for k = 1, 6 do
        lg.setColor(1, 0.5, 0.18, 0.022 + 0.004 * f)
        lg.circle("fill", a.x, a.y - 3, 4 + k * 4 + f)
      end
      lg.setBlendMode("alpha")
      -- supporto e fiamma a tre strati
      lg.setColor(0.08, 0.06, 0.05); rect(a.x - 2, a.y - 1, 5, 3); rect(a.x - 1, a.y + 2, 3, 5)
      lg.setColor(0.45, 0.32, 0.2); rect(a.x - 1.5, a.y - 0.5, 4, 1.5)
      lg.setColor(0.9, 0.25, 0.08); rect(a.x - 2, a.y - 6 - f, 5, 6 + f)
      lg.setColor(1, 0.6, 0.15); rect(a.x - 1.5, a.y - 5 - f * 0.7, 4, 5)
      lg.setColor(1, 0.95, 0.6); rect(a.x - 0.5, a.y - 3, 2, 2.5)
    elseif a.kind == "bulb" then
      local on = sin(time * 2 + a.seed * 20) > -0.3
      lg.setColor(a.color[1], a.color[2], a.color[3], on and 1 or 0.35)
      rect(a.x - 1, a.y, 2, 2)
      if on then
        lg.setBlendMode("add")
        lg.setColor(a.color[1], a.color[2], a.color[3], 0.12)
        lg.circle("fill", a.x, a.y + 1, 5)
        lg.setBlendMode("alpha")
      end
    elseif a.kind == "glow" then
      local f = sin(time * 3 + s) * 0.5 + 0.5
      lg.setBlendMode("add")
      for k = 1, 5 do
        lg.setColor(a.color[1], a.color[2], a.color[3], 0.02 + 0.008 * f)
        lg.circle("fill", a.x, a.y, 3 + k * 4)
      end
      lg.setBlendMode("alpha")
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
