-- Pixel art da griglie di testo. Ogni lettera e' un colore della palette, "." e' trasparente.
-- La griglia si converte una volta in strisce orizzontali (veloce da disegnare).
-- Scala 0.5 = mezzo pixel del mondo: la canvas e' a risoluzione doppia, quindi resta nitido.

local Art = {}
local cache = setmetatable({}, { __mode = "k" })

local function hex(s)
  return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255 }
end
Art.hex = hex

function Art.pal(t)
  local o = {}
  for k, v in pairs(t) do o[k] = type(v) == "string" and hex(v) or v end
  return o
end

local function runs(grid)
  local r = cache[grid]
  if r then return r end
  r = { w = 0, h = #grid }
  for y, row in ipairs(grid) do
    r.w = math.max(r.w, #row)
    local x = 1
    while x <= #row do
      local ch = row:sub(x, x)
      local x2 = x
      while x2 < #row and row:sub(x2 + 1, x2 + 1) == ch do x2 = x2 + 1 end
      if ch ~= "." and ch ~= " " then r[#r + 1] = { ch, x - 1, y - 1, x2 - x + 1 } end
      x = x2 + 1
    end
  end
  cache[grid] = r
  return r
end
Art.runs = runs

-- disegna la griglia con l'angolo in alto a sinistra in (x, y)
-- tint(c, ch) opzionale: trasforma ogni colore (lampo bianco, grigio, ...)
function Art.draw(grid, pal, x, y, s, alpha, tint)
  local lg = love.graphics
  local r = runs(grid)
  s = s or 1
  alpha = alpha or 1
  for i = 1, #r do
    local q = r[i]
    local c = pal[q[1]]
    if c then
      if tint then c = tint(c, q[1]) end
      lg.setColor(c[1], c[2], c[3], (c[4] or 1) * alpha)
      lg.rectangle("fill", x + q[2] * s, y + q[3] * s, q[4] * s, s)
    end
  end
end

function Art.size(grid)
  local r = runs(grid)
  return r.w, r.h
end

-- ---------------------------------------------------------------------------
-- Oggetti degli eventi di mappa (scala 0.5)

Art.ROCK = {
  "......oooooo........",
  "....oohhhhggoo......",
  "...ohhhgggggggoo....",
  "..ohhggggggggddgo...",
  ".ohgggggdgggggddgo..",
  ".ohggggdddgggggdgo..",
  "ohgggggggdggggggddo.",
  "ohggggggggggggdddgo.",
  "ogggdggggggggggdddoo",
  "ogggddggggggggddddko",
  "ogggggggggdgggdddkko",
  "oggggggggddggdddkkko",
  ".oggggggggggdddkkko.",
  ".odgggggggdddkkkkko.",
  "..oddgggddddkkkkoo..",
  "...ooddddddkkkooo...",
  ".....oooooooooo.....",
}
Art.ROCK_PAL = Art.pal({ o = "1a1512", h = "b9ab9a", g = "8a7c6c", d = "5e5246", k = "3e352d" })

Art.BARREL = {
  "..oooooooooooooooo..",
  ".ommmmmmmmmmmmmmmmo.",
  ".orrhrrrrrrrrrrrRRo.",
  ".orrhrrrrrrrrrrrRRo.",
  ".ommmmmmmmmmmmmmmmo.",
  ".orrhrrrrrrrrrrrRRo.",
  ".oyyyyyykkyyyyyyyyo.",
  ".oyyyyykkkkyyyyyyyo.",
  ".oyyyykkykkkyyyyyyo.",
  ".oyyyykkkkkkyyyyyyo.",
  ".oyyyyyyyyyyyyyyyyo.",
  ".orrhrrrrrrrrrrrRRo.",
  ".ommmmmmmmmmmmmmmmo.",
  ".orrhrrrrrrrrrrrRRo.",
  ".orrhrrrrrrrrrrrRRo.",
  ".ommmmmmmmmmmmmmmmo.",
  "..oooooooooooooooo..",
}
Art.BARREL_PAL = Art.pal({ o = "140c0c", m = "5a5a62", r = "b8321f", R = "7a1e14", h = "e86a50",
                           y = "f2c230", k = "1a1a1a" })

return Art
