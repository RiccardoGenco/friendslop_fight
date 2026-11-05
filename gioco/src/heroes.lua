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
      ".OO......OO...",
      ".OFO....OFFO..",
      ".OFFOOOOOFFO..",
      "OFFFFFFFFFFFO.",
      "OAAAAAAAAAAAAO",
      "OaAAAAAAAAAAAO",
      "OFFFFFFWWFFFO.",
      "OFFFFFFWEFFFFO",
      "OFFFFFFFFLLLNO",
      "OfFFFFFLLLLLO.",
      ".OfFFFFFLLLO..",
      "..OOfffffOO...",
      "....OOOOO.....",
    },
    skins = {
      { name = "Tigrato", pal = pal{ F = "e8913a", f = "b0602a", L = "f6dcb4", W = "ffffff", E = "1b2a1a",
        N = "e86a7a", A = "262236", a = "17141f", B = "c4313b", b = "8a1f27", C = "2c2840", c = "1c1a2a" } },
      { name = "Siamese", price = 150, pal = pal{ F = "efe1c6", f = "6b4b3a", L = "fff6e6", W = "ffffff", E = "2f6fd6",
        N = "5a3a30", A = "e8e8f0", a = "b8b8c8", B = "d63a3a", b = "9a2424", C = "f0eef4", c = "b8b6c4" } },
      { name = "Ombra", unlock = "muro_maestro", pal = pal{ F = "2a2633", f = "17141d", L = "4a4458", W = "fff27a", E = "1a1500",
        N = "6a5a80", A = "7a3ad6", a = "4f2391", B = "b77aff", b = "7a3ad6", C = "3a2a5a", c = "251a3c" } },
    },
  },
  {
    id = "rana", name = "Ranocchio Taro", title = "Rana samurai", price = 0, tail = "none",
    head = {
      "...A......A...",
      "...AA....AA...",
      "....AMMMMA....",
      "..OMMMMMMMMO..",
      ".OMmMMMMMMmMO.",
      "OmmmmmmmmmmmmO",
      ".OFFFFFFWWWFO.",
      ".OFFFFFWWEEWO.",
      "OFFFFFFFWWWFFO",
      "OFFFFFFFFFFFFO",
      "OfLLLLLLLLLLNO",
      ".OfLLLLLLLLLO.",
      "..OOOOOOOOOO..",
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
      "....OAAAAO....",
      "..OAAAWWAAAO..",
      ".OAAAAWWAAAAO.",
      "OaaaaaaaaaaaaO",
      ".OFFFFFFFFFFO.",
      "OFFFFFOOOOOFFO",
      "OFFFFFFFOOOFFO",
      "OFFFFFFFFOFFFO",
      "OFFFFFFFLLLLO.",
      "OfFFFFFLLLLNNO",
      ".OfFFFFFLLLLO.",
      "..OOffffffOO..",
      "....OOOOOO....",
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
      ".....OAAAO....",
      "....OAAAAAO...",
      "...OaaaaaaaO..",
      "OAAAAAAAAAAAAO",
      ".OOFFFFFFFOO..",
      ".OFFFFFFWWFO..",
      ".OFFFFFFWEFFO.",
      ".OFFFFFFFFFFFO",
      ".OfFFFFFLLLLNO",
      "..OfFFLLLLLOO.",
      "..OBBBBBBBO...",
      "...ObbBbbO....",
      "....OOOO......",
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
      "...OFO.OFO....",
      "...OLO.OLO....",
      "...OLO.OLO....",
      "MO.OFO.OFO.OM.",
      "MMOOMMMMMMOMM.",
      ".OMMMMMMMMMMO.",
      ".OmmmmmmmmmmO.",
      ".OFFFFFFWWFFO.",
      "OFFFFFFFWEFFFO",
      "OFFFFFFFLLLNFO",
      "OfFFFFFLLLLLO.",
      ".OffFFFLLLLO..",
      "..OOOOOOOOO...",
    },
    skins = {
      { name = "Fiordo", pal = pal{ F = "9a9aa6", f = "6a6a78", L = "f0d8d8", W = "ffffff", E = "111111",
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
      ".OO.......OO..",
      "OFfO.....OfFO.",
      "OFFFOOOOOFFFO.",
      "OFFFFFFFFFFFFO",
      "OFFLLLFFFFLLFO",
      "OBBBBBBBWWBBBO",
      "OBBBBBBBWEBBBO",
      "OFFFFFFFFFLLLO",
      "OFFFFFFFLLLLNO",
      "OfFFFFFLLLLLO.",
      ".OfFFFFFLLLO..",
      "..OOfffffOO...",
      "....OOOOO.....",
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
-- Disegno. Posa ricavata dallo stato del giocatore (vero o finto, per i menu).
-- p: x, y, facing, vx, vy, grounded, id, action, sliding, wall
-- team: colore del giocatore (sciarpa e cintura), flash: tutto bianco (colpito)

local lg

local function setc(c, a, k)
  k = k or 1
  lg.setColor(min(1, c[1] * k), min(1, c[2] * k), min(1, c[3] * k), a)
end

local function draw_tail(kind, P, a, t, speed)
  local sway = sin(t * 4) * 1.5 + min(3, speed / 50)
  local rect = lg.rectangle
  if kind == "cat" then
    for i = 0, 5 do
      local tx, ty = -6 - i, -7 - i * 1.2 + sin(t * 4 + i * 0.6) * (i / 3)
      lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a); rect("fill", tx - 1, ty - 1, 3, 3)
    end
    for i = 0, 5 do
      local tx, ty = -6 - i, -7 - i * 1.2 + sin(t * 4 + i * 0.6) * (i / 3)
      setc(i >= 4 and P.f or P.F, a); rect("fill", tx, ty, 1, 1)
    end
  elseif kind == "fox" or kind == "raccoon" then
    local pts = {}
    for i = 0, 4 do pts[#pts + 1] = { -6 - i * 1.6, -7 + i * 0.6 - sway * i / 5 } end
    for _, q in ipairs(pts) do
      lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a); rect("fill", q[1] - 3, q[2] - 3, 6, 6)
    end
    for i, q in ipairs(pts) do
      local c = P.F
      if kind == "fox" and i == #pts then c = P.L end
      if kind == "raccoon" and i % 2 == 0 then c = P.B or P.f end
      setc(c, a); rect("fill", q[1] - 2, q[2] - 2, 4, 4)
    end
  elseif kind == "rabbit" then
    lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a); rect("fill", -8, -9, 5, 5)
    setc(P.L, a); rect("fill", -7, -8, 3, 3)
  elseif kind == "bear" then
    lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a); rect("fill", -7, -9, 4, 4)
    setc(P.f, a); rect("fill", -6, -8, 2, 2)
  end
end

function Heroes.draw(hero, skin_i, p, team, alpha, flash, time, ps)
  lg = love.graphics
  local h = Heroes.get(hero)
  local skin = Heroes.skin(h, skin_i)
  local P = skin.pal
  if flash then
    local W = { 1, 1, 1 }
    P = setmetatable({}, { __index = function() return W end })
  end
  local x, y = floor(p.x), floor(p.y)
  local f = p.facing or 1
  if p.sliding and (p.wall or 0) ~= 0 then f = -p.wall end   -- sul muro guarda via dalla parete
  local a = alpha or 1
  local dash = p.action and p.action.type == "dash"
  local vx, vy = p.vx or 0, p.vy or 0
  local bob, l1, l2, k1, k2 = 0, 0, 0, 0, 0
  local hand = nil
  if dash then
    l1, l2, k1, k2 = -2, -4, 1, 2
  elseif p.sliding then
    l1, l2, k1, k2 = -1, -3, 2, 0
    hand = { -6, -14 }
  elseif not p.grounded then
    if vy < -40 then l1, l2, k1, k2 = 1, -2, 2, 1 else l1, l2, k1, k2 = 2, -2, 0, 1 end
  elseif abs(vx) > 20 then
    local ph = ((ps and ps.dist) or 0) / 6
    l1 = floor(sin(ph) * 3 + 0.5); l2 = -l1
    k1 = floor(max(0, cos(ph)) * 2 + 0.5); k2 = floor(max(0, -cos(ph)) * 2 + 0.5)
    bob = (abs(sin(ph)) > 0.7) and -1 or 0
  else
    bob = (sin(time * 2.5 + (p.id or 0) * 1.7) > 0.4) and 1 or 0
  end
  local blink = ((time + (p.id or 0) * 0.7) % 3.3) < 0.12
  local sw = 3 + min(6, floor(abs(vx) / 30))
  local fl = floor(sin(time * 16 + (p.id or 0)) * (abs(vx) > 40 and 1 or 0.5) + 0.5)
  local T = flash and { 1, 1, 1 } or team
  local rect = lg.rectangle

  lg.push()
  lg.translate(x, y)
  lg.scale(f, 1)
  if dash then lg.shear(-0.25, 0) end

  draw_tail(h.tail, P, a, time + (p.id or 0), abs(vx))

  -- corpo: gambe, busto, sciarpa (contorno prima, poi colore)
  local parts = {
    { P.c, -4 + l2, -5, 3, 5 - k2 },
    { P.C, 1 + l1, -5, 3, 5 - k1 },
    { P.C, -4, -13 + bob, 8, 8 },
    { T, -4 - sw, -13 + bob + fl, sw + 2, 2 },
  }
  if hand then parts[#parts + 1] = { P.F, hand[1], hand[2] + bob, 2, 2 } end
  lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a)
  for _, q in ipairs(parts) do rect("fill", q[2] - 1, q[3] - 1, q[4] + 2, q[5] + 2) end
  for _, q in ipairs(parts) do setc(q[1], a); rect("fill", q[2], q[3], q[4], q[5]) end
  -- piedi, dettagli del vestito, cintura col colore del giocatore
  setc(P.f, a); rect("fill", -4 + l2, -1 - k2, 3, 1); rect("fill", 1 + l1, -1 - k1, 4, 1)
  setc(P.c, a); rect("fill", -1, -12 + bob, 1, 5)
  setc(P.L, a); rect("fill", 0, -12 + bob, 3, 3)
  setc(T, a); rect("fill", -4, -7 + bob, 8, 2)
  setc(T, a, 1.3); rect("fill", 1, -7 + bob, 2, 2)

  -- testa in pixel art (la riga piu' bassa poggia sul busto)
  local hx, hy = -7, -24 + bob
  for _, r in ipairs(h.runs) do
    local ch = r[1]
    local c
    if ch == "O" then c = OUTLINE
    elseif ch == "E" and blink then c = P.F
    elseif ch == "W" and blink then c = P.f
    else c = P[ch] or P.F end
    setc(c, a)
    rect("fill", hx + r[2], hy + r[3], r[4], 1)
  end
  -- nodo della fascia del ninja che svolazza
  if h.knot then
    local kc = P[h.knot]
    for i = 0, 2 do
      local kx, ky = hx - 1 - i * 2, hy + 4 + i + floor(sin(time * 12 + i) * 0.8 + 0.5)
      lg.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], a); rect("fill", kx - 1, ky - 1, 4, 3)
      setc(kc, a); rect("fill", kx, ky, 2, 1)
    end
  end
  lg.pop()
end

-- solo la testa, come icona (HUD, podio). gray: versione spenta per chi e' eliminato
function Heroes.draw_head(hero, skin_i, x, y, s, alpha, gray)
  lg = love.graphics
  local h = Heroes.get(hero)
  local P = Heroes.skin(h, skin_i).pal
  lg.push()
  lg.translate(x, y)
  lg.scale(s or 1)
  for _, r in ipairs(h.runs) do
    local c = (r[1] == "O") and OUTLINE or (P[r[1]] or P.F)
    if gray then
      local v = (c[1] + c[2] + c[3]) / 3 * 0.6
      lg.setColor(v, v, v, alpha or 1)
    else
      lg.setColor(c[1], c[2], c[3], alpha or 1)
    end
    lg.rectangle("fill", r[2], r[3], r[4], 1)
  end
  lg.pop()
end

return Heroes
