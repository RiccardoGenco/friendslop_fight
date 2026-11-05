-- Caricamento degli sprite. Se non c'e' nulla, il gioco disegna rettangoli colorati.
-- Per usare grafica vera: copia le immagini in assets/ e crea assets/sprites.lua
-- (guarda assets/sprites.example.lua e assets/README.md).

local Sprites = { player = nil }

local function load_sheet(cfg)
  if not cfg or not cfg.image or not love.filesystem.getInfo(cfg.image) then return nil end
  local img = love.graphics.newImage(cfg.image)
  img:setFilter("nearest", "nearest")
  local iw, ih = img:getDimensions()
  local fw, fh = cfg.frame_w, cfg.frame_h
  local cols = math.floor(iw / fw)
  local quads = {}
  local total = cols * math.floor(ih / fh)
  for i = 1, total do
    local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
    quads[i] = love.graphics.newQuad(c * fw, r * fh, fw, fh, iw, ih)
  end
  return { cfg = cfg, img = img, quads = quads }
end

function Sprites.load()
  Sprites.player = nil
  if not love.filesystem.getInfo("assets/sprites.lua") then return end
  local ok, cfg = pcall(function() return love.filesystem.load("assets/sprites.lua")() end)
  if not ok or type(cfg) ~= "table" then
    print("assets/sprites.lua non valido: " .. tostring(cfg))
    return
  end
  Sprites.player = load_sheet(cfg.player)
end

-- Sceglie l'animazione in base allo stato del giocatore
local function anim_for(p)
  local a = p.action
  if p.hitstun > 0 then return "hurt" end
  if a then
    if a.type == "dash" then return "dash" end
    if a.type == "parry" then return "parry" end
    if a.type == "attack" then return "attack" end
  end
  if not p.grounded then return "jump" end
  if math.abs(p.vx) > 10 then return "run" end
  return "idle"
end

-- Disegna il giocatore con lo sprite sheet. Ritorna false se non ci sono sprite.
function Sprites.draw_player(p, time, tint, alpha)
  local s = Sprites.player
  if not s then return false end
  local cfg = s.cfg
  local frames = cfg.anims[anim_for(p)] or cfg.anims.idle or { 1 }
  local fps = cfg.fps or 10
  local idx = frames[(math.floor(time * fps) % #frames) + 1]
  local q = s.quads[idx]
  if not q then return false end
  local scale = cfg.scale or 1
  local ox, oy = cfg.ox or (cfg.frame_w / 2), cfg.oy or cfg.frame_h
  if cfg.tint == false then
    love.graphics.setColor(1, 1, 1, alpha)
  else
    love.graphics.setColor(tint[1] * 0.5 + 0.5, tint[2] * 0.5 + 0.5, tint[3] * 0.5 + 0.5, alpha)
  end
  local flip = (p.facing < 0) and -1 or 1
  if cfg.faces_left then flip = -flip end
  love.graphics.draw(s.img, q, math.floor(p.x), math.floor(p.y), 0, scale * flip, scale, ox, oy)
  return true
end

return Sprites
