-- Personaggi giocabili: animali guerrieri. Solo grafica, la simulazione non li conosce.
-- Ogni personaggio ha una testa in pixel art (griglia di lettere = colori della skin),
-- un corpo animato disegnato via codice e una coda. Le skin cambiano solo la palette.
--
-- Lettere della griglia (testa vista da destra, 14x13, ultima riga = collo):
--   O contorno  F pelo  f pelo in ombra  L pelo chiaro (muso, pancia)  W bianco occhio
--   E pupilla  N naso  A/a accessorio  B/b secondo accessorio  M/m metallo

local floor, sin, cos, min, max, abs = math.floor, math.sin, math.cos, math.min, math.max, math.abs

local Heroes = {}

local function hex(s)
  return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255 }
end
local function pal(t)
  local o = {}
  for k, v in pairs(t) do o[k] = type(v) == "string" and hex(v) or v end
  return o
end

local OUTLINE = { 0.05, 0.04, 0.07 }

Heroes.list = {
  {
    id = "gatto", name = "Micio Kage", title = "Gatto ninja", price = 0, tail = "cat",
    knot = "B",   -- nodo della fascia che svolazza dietro la testa
    head = {
      "....OO............OO....",
      "...OHFO..........OFFO...",
      "...OFNFO........OFNFO...",
      "..OFFNNFOOOOOOOOFNNFFO..",
      "..OHHFFFFHHHHFFFFFFFFO..",
      ".OAAAAAAAAAAAAAAAAAAAAO.",
      ".OaAAAAAAAAAAAAAAAAAAAAO",
      ".OaaaaaaaaaaaaaaaaaaaaO.",
      ".OfFFFfFFFFFFFFWWWWFFFO.",
      "OfFFFFFfFFFFFFWWWEEWFFFO",
      "OfFfFFFFFFFFFFWWWEEWFFFO",
      "OfFFfFFFFFFFFFFWWWWFFLLO",
      "OfFFFFFFFFFFFFFFFFFLLLNO",
      "OffFFfFFFFFFFFFFFFLLLLLO",
      ".OffFFFFFFFFFFFFFLLOOLO.",
      ".OfffFFFFFFFFFFFFLLLLLO.",
      "..OOfffffffffffffffOO...",
      "....OOOOOOOOOOOOOOO.....",
    },
    skins = {
      { name = "Tigrato", pal = pal{ F = "e8913a", f = "b0602a", L = "f6dcb4", W = "ffffff", E = "1b2a1a",
        N = "e86a7a", A = "262236", a = "17141f", B = "c4313b", b = "8a1f27", C = "2c2840", c = "1c1a2a" } },
      { name = "Siamese", price = 150, pal = pal{ F = "efe1c6", f = "6b4b3a", L = "fff6e6", W = "ffffff", E = "2f6fd6",
        N = "5a3a30", A = "e8e8f0", a = "b8b8c8", B = "d63a3a", b = "9a2424", C = "f0eef4", c = "b8b6c4" } },
      { name = "Ombra", unlock = "muro_maestro", pal = pal{ F = "2a2633", f = "17141d", L = "4a4458", W = "fff27a", E = "1a1500",
        N = "6a5a80", A = "7a3ad6", a = "4f2391", B = "b77aff", b = "7a3ad6", C = "3a2a5a", c = "251a3c" } },
      { name = "Alchimista", unlock = "alchimista", pal = pal{ F = "f2c24a", f = "b8862a", L = "fff0c4", W = "ffffff", E = "7a1fd6",
        N = "e86a7a", A = "3a1f6a", a = "24124a", B = "ffb02e", b = "c07010", C = "4a2a7a", c = "2c1850" } },
    },
  },
  {
    id = "rana", name = "Ranocchio Taro", title = "Rana samurai", price = 0, tail = "none",
    head = {
      ".....A............A.....",
      ".....AA..........AA.....",
      "......AA........AA......",
      ".......AAyMMMMyAA.......",
      "....OOMMMMMMMMMMMMOO....",
      "..OOMMMMMMMMMMMMMMMMOO..",
      ".OmMMMMMMMMMMMMMMMMMMmO.",
      "OmmmmmmmmmmmmmmmmmmmmmmO",
      ".OOFFFFFFFFFFFFOOOOOOO..",
      "..OFFFFFFFFFFFOWWWWWWO..",
      ".OHFFFFFFFFFFFOWWWWEEWO.",
      ".OFFFFFFFFFFFFOWWWWEEWO.",
      "OFFFFFFFFFFFFFFOWWWWWO..",
      "OfFFFFFFFFFFFFFFOOOOOFO.",
      "OfFFFFFFFFFFFFFFFFFFFFFO",
      "OfLLLLLLLLLLLLLLLLLLOOOO",
      "OffLLLLLLLLLLLLLLLLLLLO.",
      ".OffLLLLLLLLLLLLLLLLLO..",
      "..OOffffLLLLLLLLLLLOO...",
      "....OOOOOOOOOOOOOOO.....",
    },
    skins = {
      { name = "Stagno", pal = pal{ F = "5fbf4a", f = "3a8a32", L = "d8eaa0", W = "ffffff", E = "111111",
        N = "2a5a22", A = "e2b13c", a = "a87a1c", M = "c23a32", m = "7e2020", C = "b8302a", c = "7a1e1c" } },
      { name = "Velenosa", price = 150, pal = pal{ F = "3a7ce0", f = "2450a0", L = "f2d23a", W = "ffffff", E = "111111",
        N = "1a2a60", A = "f2d23a", a = "b0921a", M = "2a2a33", m = "15151c", C = "33333d", c = "1d1d24" } },
      { name = "Oro", unlock = "campione", pal = pal{ F = "f0c03a", f = "b08a1e", L = "fff0b0", W = "ffffff", E = "3a1a00",
        N = "8a5a10", A = "ffffff", a = "c8c8d8", M = "f6d870", m = "b0921a", C = "fff0b0", c = "d8b860" } },
    },
  },
  {
    id = "orso", name = "Orso Barbanera", title = "Orso pirata", price = 0, tail = "bear",
    head = {
      "........OOOOOOOO........",
      "......OOAAAAAAAAOO......",
      "....OOAAAAAAWWAAAAOO....",
      "...OAAAAAAAWWWWAAAAAO...",
      "..OAAAAAAAAWkWkAAAAAAO..",
      ".OAAAAAAAAAAWWAAAAAAAAO.",
      "OaaaaaaaaaaaaaaaaaaaaaaO",
      ".OOOFFFFFFFFFFFFFFFFOOO.",
      "..OFHHFFFFFFFFFFFFFFFO..",
      ".OfFFFFFFFFkkkkkkkFFFFO.",
      ".OfFFFFFFFFFFFFkkkkFFFO.",
      ".OfFFFFFFFFFFFFkkkkFFFO.",
      ".OfFFFFFFFFFFFFFkkLLLLO.",
      ".OfFFFFFFFFFFFFFLLLLNNNO",
      ".OffFFFFFFFFFFFLLLLLNNNO",
      "..OffFFFFFFFFFFLLOOLLLO.",
      "..OfffFFFFFFFFFFLLLLLO..",
      "...OOfffffffffffffOO....",
      ".....OOOOOOOOOOOOOO.....",
    },
    skins = {
      { name = "Bruno", pal = pal{ F = "8a5a34", f = "5e3b22", L = "d4a878", W = "f4f0e6", E = "111111",
        N = "2a1a12", A = "23202a", a = "141218", C = "e8e2d4", c = "a8302c" } },
      { name = "Polare", price = 150, pal = pal{ F = "eef2f6", f = "b8c4d0", L = "ffffff", W = "f4d040", E = "111111",
        N = "2a2a33", A = "1f3a7a", a = "142650", C = "2a4a8a", c = "f0f0f0" } },
      { name = "Fantasma", unlock = "mitico", pal = pal{ F = "7ae0e0", f = "3a9aa8", L = "c8fff8", W = "ffffff", E = "0a3a40",
        N = "1a6a70", A = "1a3a4a", a = "0e2430", C = "2a6a78", c = "9af0e8" } },
    },
  },
  {
    id = "volpe", name = "Volpe Dakota", title = "Volpe cowboy", price = 250, tail = "fox",
    head = {
      "........OOOOOO..........",
      ".......OAAAAAAO.........",
      "......OAAAAAAAAO........",
      "......ObbbbbbbbbO.......",
      "..OOOOAAAAAAAAAAAOOOOO..",
      ".OaAAAAAAAAAAAAAAAAAAaO.",
      "..OOOFFFFFFFFFFFFFOOOO..",
      "...OFHHFFFFFFFFFFFFO....",
      "..OfFFFFFFFFFFWWWFFFO...",
      "..OfFFFFFFFFFWWWEEFFFO..",
      "..OfFFFFFFFFFFWWEEFFFFOO",
      "..OfFFFFFFFFFFFFFFFLLLNO",
      "..OffFFFFFFFFFFFLLLLLLOO",
      "...OffFFFFFFFFLLLLOOOO..",
      "....OfffFFFFLLLLLO......",
      "...OBBBBBBBBBBBBBO......",
      "...ObBBBBBBBBBBbbO......",
      "....OOOOOOOOOOOOO.......",
    },
    skins = {
      { name = "Prateria", pal = pal{ F = "e0702a", f = "a84a1a", L = "fff2e0", W = "ffffff", E = "111111",
        N = "1a1212", A = "8a5a30", a = "5a3818", B = "c43030", b = "8a1e1e", C = "3a5a8a", c = "26405e" } },
      { name = "Artica", price = 150, pal = pal{ F = "f2f4f8", f = "b8c0cc", L = "ffffff", W = "ffffff", E = "1a3a6a",
        N = "2a2a33", A = "26262e", a = "141418", B = "3a8ad6", b = "24609a", C = "4a4a58", c = "2e2e3a" } },
      { name = "Fuoco", unlock = "demolitore", pal = pal{ F = "ff5a1a", f = "c0301a", L = "ffe060", W = "fff4a0", E = "3a0a00",
        N = "3a0a00", A = "2a1a1a", a = "140a0a", B = "ffb020", b = "c07010", C = "3a1a14", c = "24100c" } },
    },
  },
  {
    id = "coniglio", name = "Coniglio Ragnar", title = "Coniglio vichingo", price = 350, tail = "rabbit",
    head = {
      ".....OFFO....OFFO.......",
      ".....OLLO....OLLO.......",
      ".....OLLO....OLLO.......",
      ".....OLLO....OLLO.......",
      ".OO..OFFO....OFFO...OO..",
      "OWWO.OFFO....OFFO..OWWO.",
      "OWWWOOMMMMMMMMMMMOOWWWO.",
      ".OWWMMMMMMMMMMMMMMMWWO..",
      "..OMMMMsMMMMMMMMMMMMMO..",
      ".OmmmmmmmmmmmmmmmmmmmmO.",
      ".OFFFFFFFFFFFFFWWWFFFO..",
      "OfFFFFFFFFFFFFWWWEEFFFO.",
      "OfFFFFFFFFFFFFWWWEEFFFO.",
      "OfFFFFFFFFFFFFFFFFFLLLO.",
      "OfFFFFFFFFFFFFFFFFLLLNNO",
      "OffFFFFFFFFFFFFFFLLLLLO.",
      ".OffFFFFFFFFFFFFFLOWOLO.",
      "..OfffFFFFFFFFFFFLLLLO..",
      "...OOfffffffffffffOO....",
      ".....OOOOOOOOOOOOOO.....",
    },
    skins = {
      { name = "Fiordo", pal = pal{ F = "b08462", f = "7a5638", L = "f2dcc8", W = "ffffff", E = "111111",
        N = "d86a80", M = "c8ccd4", m = "8a8e98", C = "7a5434", c = "4e3420" } },
      { name = "Neve", price = 150, pal = pal{ F = "f6f6fa", f = "c4c4d4", L = "ffd8e0", W = "ffffff", E = "c0202a",
        N = "e87a90", M = "f0c84a", m = "b08a20", C = "3a6aa8", c = "264a78" } },
      { name = "Runico", unlock = "veterano", pal = pal{ F = "5a4a7a", f = "3a2e54", L = "a890d8", W = "7affea", E = "003a30",
        N = "a890d8", M = "3affd0", m = "1aa088", C = "2a2238", c = "181420" } },
    },
  },
  {
    id = "procione", name = "Procione Lesto", title = "Procione ladro", price = 450, tail = "raccoon",
    head = {
      "...OOO...........OOO....",
      "..OfFfO.........OfFfO...",
      "..OFLFOOOOOOOOOOOFLFO...",
      "..OFFFFFHHHHFFFFFFFFO...",
      ".OFFFFFFFFFFFFFFFFFFFO..",
      ".OFFLLLFFFFFFFFFLLLFFO..",
      "OfFFFFFFFFFFFFFFFFFFFFO.",
      "OBBBBBBBBBBBBBWWWWBBBBO.",
      "OBBBBBBBBBBBBWWWWEEBBBBO",
      "OBBBBBBBBBBBBWWWWEEBBBO.",
      "OfFFFFFFFFFFFFFFFFLLLLO.",
      "OfFFFFFFFFFFFFFFFLLLLNNO",
      "OffFFFFFFFFFFFFFLLLLLNNO",
      ".OffFFFFFFFFFFFFLLOOLLO.",
      ".OfffFFFFFFFFFFFLLLLLO..",
      "..OOfffffffffffffffOO...",
      "....OOOOOOOOOOOOOOO.....",
    },
    skins = {
      { name = "Bidone", pal = pal{ F = "8a8a94", f = "5c5c66", L = "e4e4ea", W = "ffffff", E = "111111",
        N = "1a1a1a", B = "26262e", b = "14141a", C = "3a3a44", c = "dcdce4" } },
      { name = "Albino", price = 150, pal = pal{ F = "f2f2f6", f = "c4c4d0", L = "ffffff", W = "ffffff", E = "d02040",
        N = "e88aa0", B = "f0c0d0", b = "c890a0", C = "8a2a3a", c = "f2f2f6" } },
      { name = "Notturno", unlock = "parata", pal = pal{ F = "2a3a5a", f = "1a243a", L = "8aa8d8", W = "ffe066", E = "302000",
        N = "0a0a14", B = "0a0e18", b = "05070c", C = "121a2c", c = "3a5a8a" } },
    },
  },
}

Heroes.by_id = {}
for i, h in ipairs(Heroes.list) do
  h.index = i
  Heroes.by_id[h.id] = h
  -- la griglia diventa una lista di strisce orizzontali dello stesso colore (disegno veloce)
  h.runs = {}
  for y, row in ipairs(h.head) do
    local x = 1
    while x <= #row do
      local ch = row:sub(x, x)
      local x2 = x
      while x2 < #row and row:sub(x2 + 1, x2 + 1) == ch do x2 = x2 + 1 end
      if ch ~= "." then h.runs[#h.runs + 1] = { ch, x - 1, y - 1, x2 - x + 1 } end
      x = x2 + 1
    end
  end
end

function Heroes.get(id) return Heroes.by_id[id] or Heroes.list[1] end
function Heroes.skin(h, i) return h.skins[i] or h.skins[1] end

-- ---------------------------------------------------------------------------
-- Disegno. Tutto in "pixel d'arte" (mezzo pixel del mondo): il personaggio e' alto
-- circa 24 pixel del mondo, un po' piu' della sua area di collisione (20).
-- p: x, y, facing, vx, vy, grounded, id, action, sliding, wall
-- team: colore del giocatore (sciarpa e cintura), flash: tutto bianco (colpito)

local Art = require("src.art")
local lg
local S = 0.5
local BOOT = { 0.16, 0.11, 0.09 }

local function shade(c, k) return { min(1, c[1] * k), min(1, c[2] * k), min(1, c[3] * k) } end

-- colori ricavati: luce del pelo, ombra del vestito
local function full_pal(P)
  if P._full then return P._full end
  local q = {}
  for k, v in pairs(P) do q[k] = v end
  q.H = q.H or shade(P.F, 1.25)
  q.O = OUTLINE
  q.k = q.k or { 0.06, 0.05, 0.08 }
  q.y = q.y or { 0.95, 0.75, 0.2 }
  q.s = q.s or { 0.95, 0.95, 1 }
  P._full = q
  return q
end

local WHITE = { 1, 1, 1 }
local function white() return WHITE end

-- code (unita' d'arte, rivolte a destra: la coda sta a sinistra)
local function draw_tail(kind, P, a, t, speed)
  local sway = sin(t * 4) * 3 + min(6, speed / 25)
  local rect = lg.rectangle
  local function blob(x, y, r, c)
    lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a); rect("fill", x - r - 1, y - r - 1, 2 * r + 2, 2 * r + 2)
    lg.setColor(c[1], c[2], c[3], a); rect("fill", x - r, y - r, 2 * r, 2 * r)
  end
  if kind == "cat" then
    local pts = {}
    for i = 0, 7 do pts[#pts + 1] = { -10 - i * 2, -14 - i * 2.4 + sin(t * 4 + i * 0.6) * (i / 2) } end
    for _, q in ipairs(pts) do
      lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a); rect("fill", q[1] - 2, q[2] - 2, 4, 4)
    end
    for i, q in ipairs(pts) do
      local c = (i % 2 == 0) and P.f or P.F
      lg.setColor(c[1], c[2], c[3], a); rect("fill", q[1] - 1, q[2] - 1, 2, 2)
    end
  elseif kind == "fox" or kind == "raccoon" then
    local n = 6
    local pts = {}
    for i = 0, n - 1 do pts[#pts + 1] = { -10 - i * 3, -12 + i * 1.2 - sway * i / n } end
    for i, q in ipairs(pts) do
      local r = (i == 1 or i == n) and 3 or 4
      lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a); rect("fill", q[1] - r - 1, q[2] - r - 1, 2 * r + 2, 2 * r + 2)
    end
    for i, q in ipairs(pts) do
      local r = (i == 1 or i == n) and 3 or 4
      local c = P.F
      if kind == "fox" and i >= n - 1 then c = P.L end
      if kind == "raccoon" and i % 2 == 0 then c = P.B or P.f end
      lg.setColor(c[1], c[2], c[3], a); rect("fill", q[1] - r, q[2] - r, 2 * r, 2 * r)
      lg.setColor(1, 1, 1, 0.15 * a); rect("fill", q[1] - r, q[2] - r, 2 * r, 1)
    end
  elseif kind == "rabbit" then
    blob(-10, -15, 4, P.L)
  elseif kind == "bear" then
    blob(-9, -16, 3, P.f)
  end
end

function Heroes.hand_color(hero, skin_i)
  return Heroes.skin(Heroes.get(hero), skin_i).pal.F
end

-- ---------------------------------------------------------------------------
-- Eroi da immagine (pixel art generata e ripulita): assets/heroes/<id>_<skin>.png
-- Se il file c'e' si usa quello, animato via codice; altrimenti il disegno a griglia.

local images = {}
local outline_shader, white_shader
local function shaders()
  if outline_shader ~= nil then return end
  local ok1, a = pcall(love.graphics.newShader, [[
    extern vec4 col;
    vec4 effect(vec4 c, Image tex, vec2 uv, vec2 sc) { return vec4(col.rgb, col.a * Texel(tex, uv).a); }
  ]])
  outline_shader = ok1 and a or false
  white_shader = outline_shader
end

local function hero_image(hero, skin_i)
  local key = hero .. "_" .. skin_i
  local e = images[key]
  if e ~= nil then return e end
  e = false
  local path = "assets/heroes/" .. key .. ".png"
  if love.filesystem and love.filesystem.getInfo and love.filesystem.getInfo(path) then
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img and img.getDimensions then
      img:setFilter("nearest", "nearest")
      local w, h = img:getDimensions()
      e = { img = img, w = w, h = h, ox = w / 2 }
      -- foglio di pose: assets/heroes/<id>_<skin>.lua = { fw, fh, ox, frames [, scale] }
      -- ordine delle pose: fermo, corsa 1, corsa 2, salto, caduta, scatto
      local meta = "assets/heroes/" .. key .. ".lua"
      if love.filesystem.getInfo(meta) then
        local ok2, m = pcall(function() return love.filesystem.load(meta)() end)
        if ok2 and type(m) == "table" and m.frames then
          e.quads = {}
          for i = 1, m.frames do e.quads[i] = love.graphics.newQuad((i - 1) * m.fw, 0, m.fw, m.fh, w, h) end
          e.w, e.h, e.ox = m.fw, m.fh, m.ox
          e.scale = m.scale   -- porta ogni eroe alla stessa altezza in gioco (pixel nitidi, scalati al disegno)
        end
      end
    end
  end
  images[key] = e
  return e
end
Heroes.hero_image = hero_image

local function draw_image_hero(e, p, team, a, flash, time, ps)
  local x, y = floor(p.x), floor(p.y)
  local f = p.facing or 1
  if p.sliding and (p.wall or 0) ~= 0 then f = -p.wall end
  local vx, vy = p.vx or 0, p.vy or 0
  local dash = p.action and p.action.type == "dash"
  -- posa via codice: respiro, passi, salto, caduta, scatto
  local sx, sy, rot, oy, shear = 1, 1, 0, 0, 0
  if dash then
    sx, sy, rot, shear = 1.12, 0.9, 0.12, -0.25
  elseif p.sliding then
    rot = -0.08
  elseif not p.grounded then
    if vy < -40 then sx, sy, rot = 0.9, 1.1, -0.06 else sx, sy, rot = 1.04, 0.97, 0.08 end
  elseif abs(vx) > 20 then
    local ph = ((ps and ps.dist) or 0) / 6
    oy = -abs(sin(ph)) * 1.5
    rot = 0.1 + sin(ph * 2) * 0.03
    sy = 1 - abs(cos(ph)) * 0.05
    sx = 2 - sy
  else
    local b = sin(time * 2.5 + (p.id or 0) * 1.7)
    sy, sx = 1 + b * 0.025, 1 - b * 0.015
  end
  -- posa dal foglio (se c'e'): il disegno mostra gia' il movimento, il codice lo accompagna
  local q
  if e.quads then
    local n = #e.quads
    local pick = 1
    if dash then pick = 6
    elseif not p.grounded and not p.sliding then pick = (vy < -40) and 4 or 5
    elseif p.grounded and abs(vx) > 20 then
      local ph = ((ps and ps.dist) or 0) / 6
      pick = (sin(ph) >= 0) and 2 or 3
      rot = rot * 0.4
    end
    q = e.quads[math.min(pick, n)]
    if pick ~= 1 then sx, sy = 1 + (sx - 1) * 0.5, 1 + (sy - 1) * 0.5 end
  end
  local s = S * (e.scale or 1)
  lg.push()
  lg.translate(x, y + oy)
  lg.rotate(rot * f)
  lg.shear(shear * f, 0)
  lg.scale(f * s * sx, s * sy)
  shaders()
  -- contorno nel colore del giocatore: si capisce chi e' chi anche in mischia
  if outline_shader and team then
    lg.setShader(outline_shader)
    outline_shader:send("col", { team[1], team[2], team[3], 0.9 * a })
    for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
      if q then lg.draw(e.img, q, -e.ox + d[1], -e.h + d[2]) else lg.draw(e.img, -e.ox + d[1], -e.h + d[2]) end
    end
    lg.setShader()
  end
  if flash and white_shader then
    lg.setShader(white_shader)
    white_shader:send("col", { 1, 1, 1, a })
    if q then lg.draw(e.img, q, -e.ox, -e.h) else lg.draw(e.img, -e.ox, -e.h) end
    lg.setShader()
  else
    lg.setColor(1, 1, 1, a)
    if q then lg.draw(e.img, q, -e.ox, -e.h) else lg.draw(e.img, -e.ox, -e.h) end
  end
  lg.pop()
end

function Heroes.draw(hero, skin_i, p, team, alpha, flash, time, ps)
  lg = love.graphics
  local img = hero_image(hero, skin_i or 1)
  if img then return draw_image_hero(img, p, team, alpha or 1, flash, time, ps) end
  local h = Heroes.get(hero)
  local P = full_pal(Heroes.skin(h, skin_i).pal)
  local tint = flash and white or nil
  local function C(c) return flash and WHITE or c end
  local x, y = floor(p.x), floor(p.y)
  local f = p.facing or 1
  if p.sliding and (p.wall or 0) ~= 0 then f = -p.wall end   -- sul muro guarda via dalla parete
  local a = alpha or 1
  local dash = p.action and p.action.type == "dash"
  local vx, vy = p.vx or 0, p.vy or 0
  local bob, l1, l2, k1, k2, arm = 0, 0, 0, 0, 0, 0
  local hand_up = false
  if dash then
    l1, l2, k1, k2, arm = -4, -8, 2, 4, -4
  elseif p.sliding then
    l1, l2, k1, k2 = -2, -6, 4, 0
    hand_up = true
  elseif not p.grounded then
    if vy < -40 then l1, l2, k1, k2, arm = 2, -4, 4, 2, -3 else l1, l2, k1, k2, arm = 4, -4, 0, 2, 2 end
  elseif abs(vx) > 20 then
    local ph = ((ps and ps.dist) or 0) / 6
    l1 = floor(sin(ph) * 6 + 0.5); l2 = -l1
    k1 = floor(max(0, cos(ph)) * 4 + 0.5); k2 = floor(max(0, -cos(ph)) * 4 + 0.5)
    bob = (abs(sin(ph)) > 0.7) and -2 or 0
    arm = -l1
  else
    bob = (sin(time * 2.5 + (p.id or 0) * 1.7) > 0.4) and 1 or 0
  end
  local blink = ((time + (p.id or 0) * 0.7) % 3.3) < 0.12
  local sw = 6 + min(12, floor(abs(vx) / 15))
  local fl = floor(sin(time * 16 + (p.id or 0)) * (abs(vx) > 40 and 2 or 1) + 0.5)
  local T = C(team)
  local Td = C(shade(team, 0.65))
  local rect = lg.rectangle

  lg.push()
  lg.translate(x, y)
  lg.scale(f * S, S)
  if dash then lg.shear(-0.25, 0) end

  draw_tail(h.tail, flash and setmetatable({}, { __index = white }) or P, a, time + (p.id or 0), abs(vx))

  -- parti del corpo: { colore, x, y, w, h }, prima tutte col contorno, poi i colori
  local Cc, cc = C(P.C), C(P.c)
  local parts = {
    { cc, -6 + l2, -13, 5, 13 - k2 },                 -- gamba dietro
    { C(BOOT), -7 + l2, -4 - k2, 7, 4 },              -- stivale dietro
    { C(shade(P.C, 0.7)), -10 + arm, -25 + bob, 4, 9 }, -- braccio dietro
    { C(P.F), -10 + arm, -17 + bob, 4, 3 },           -- mano dietro
    { cc, 1 + l1, -13, 5, 13 - k1 },                  -- gamba davanti
    { C(BOOT), 0 + l1, -4 - k1, 8, 4 },               -- stivale davanti
    { Cc, -7, -28 + bob, 14, 16 },                    -- busto
    { T, -8 - sw, -28 + bob + fl, sw + 2, 4 },        -- coda della sciarpa
    { T, -8, -29 + bob, 16, 4 },                      -- sciarpa al collo
  }
  if hand_up then parts[#parts + 1] = { C(P.F), -12, -30 + bob, 4, 4 } end
  lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a)
  for _, q in ipairs(parts) do rect("fill", q[2] - 1, q[3] - 1, q[4] + 2, q[5] + 2) end
  for _, q in ipairs(parts) do
    lg.setColor(q[1][1], q[1][2], q[1][3], a)
    rect("fill", q[2], q[3], q[4], q[5])
  end
  -- ombre e luci del busto, cintura, fibbia, pieghe della sciarpa
  local dk = C(shade(P.C, 0.72))
  lg.setColor(dk[1], dk[2], dk[3], a); rect("fill", -7, -28 + bob, 3, 16)
  local lt = C(shade(P.C, 1.25))
  lg.setColor(lt[1], lt[2], lt[3], a); rect("fill", -4, -25 + bob, 10, 1)
  lg.setColor(T[1], T[2], T[3], a); rect("fill", -7, -16 + bob, 14, 3)
  local gold = C({ 1, 0.85, 0.35 })
  lg.setColor(gold[1], gold[2], gold[3], a); rect("fill", 2, -16 + bob, 3, 3)
  lg.setColor(Td[1], Td[2], Td[3], a); rect("fill", -8, -26 + bob, 16, 1); rect("fill", -8 - sw, -26 + bob + fl, sw, 1)
  local bh = C(shade(BOOT, 2))
  lg.setColor(bh[1], bh[2], bh[3], a); rect("fill", 1 + l1, -4 - k1, 6, 1); rect("fill", -6 + l2, -4 - k2, 5, 1)

  -- testa: la riga piu' bassa poggia sulla sciarpa
  local gw, gh = Art.size(h.head)
  local hx, hy = -12, -27 + bob - gh + 3
  local hp = P
  if blink and not flash then
    hp = setmetatable({ E = P.F, W = P.f }, { __index = P })
  end
  Art.draw(h.head, hp, hx, hy, 1, a, tint)
  -- nodo della fascia del ninja che svolazza
  if h.knot then
    local kc = C(P[h.knot])
    for i = 0, 2 do
      local kx, ky = hx - 2 - i * 4, hy + 6 + i * 2 + floor(sin(time * 12 + i) * 1.5 + 0.5)
      lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a); rect("fill", kx - 1, ky - 1, 6, 4)
      lg.setColor(kc[1], kc[2], kc[3], a); rect("fill", kx, ky, 4, 2)
    end
  end
  lg.pop()
end

-- solo la testa, come icona (HUD, podio). s: scala in pixel del mondo per pixel d'arte * 2
-- gray: versione spenta per chi e' eliminato
function Heroes.draw_head(hero, skin_i, x, y, s, alpha, gray)
  lg = love.graphics
  local e = hero_image(hero, skin_i or 1)
  if e then
    if not e.head then
      local iw, ih = e.img:getDimensions()
      e.head = lg.newQuad(0, 0, e.w, floor(e.h * 0.55), iw, ih)
    end
    local k = (s or 1) * 12 / e.w * 1.25
    if gray then lg.setColor(0.45, 0.45, 0.45, alpha or 1) else lg.setColor(1, 1, 1, alpha or 1) end
    lg.draw(e.img, e.head, x - 2, y - 2, 0, k, k)
    return
  end
  local h = Heroes.get(hero)
  local P = full_pal(Heroes.skin(h, skin_i).pal)
  local tint = nil
  if gray then
    tint = function(c) local v = (c[1] + c[2] + c[3]) / 3 * 0.6; return { v, v, v } end
  end
  Art.draw(h.head, P, x, y, (s or 1) * 0.6, alpha, tint)
end

return Heroes
