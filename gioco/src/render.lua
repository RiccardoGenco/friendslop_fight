-- Disegno della partita. Le coordinate dell'interfaccia sono virtuali 640x360;
-- la canvas reale e' il doppio (Render.SS) cosi' la telecamera puo' allontanarsi
-- senza perdere dettaglio. Tutto qui legge lo stato della simulazione senza modificarlo.

local data = require("src.sim.data")
local Player = require("src.sim.player")
local Combat = require("src.sim.combat")
local Sprites = require("src.sprites")
local Fx = require("src.fx")
local Look = require("src.look")
local Heroes = require("src.heroes")

local lg = love.graphics
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local floor, sin, cos, min, max, abs = math.floor, math.sin, math.cos, math.min, math.max, math.abs

local Render = { W = 640, H = 360, SS = 2 }

-- ---------------------------------------------------------------------------
-- Telecamera: inquadra tutti i giocatori vivi, zooma quando si allontanano.
-- Vive solo nel disegno: non tocca la simulazione.

local Cam = { x = 320, y = 180, z = 1, world = nil }
Render.cam = Cam

local CAM = {
  zoom_max = 1.0,        -- zoom massimo (1 = scala del vecchio prototipo)
  margin_x = 120, margin_top = 90, margin_bottom = 50,
  follow = 5.0,          -- velocita' di inseguimento della posizione
  zoom_speed = 2.5,      -- velocita' del cambio di zoom
}
Render.CAM = CAM

local function cam_target(game)
  local world = game.world
  local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(game.players) do
    if p.alive then
      x1, x2 = min(x1, p.x), max(x2, p.x)
      y1, y2 = min(y1, p.y - p.h), max(y2, p.y)
    end
  end
  if x1 == math.huge then x1, y1, x2, y2 = 0, 0, world.width, world.height end
  x1, x2 = x1 - CAM.margin_x, x2 + CAM.margin_x
  y1, y2 = y1 - CAM.margin_top, y2 + CAM.margin_bottom
  local zmin = min(Render.W / world.width, Render.H / world.height)
  local z = min(Render.W / (x2 - x1), Render.H / (y2 - y1))
  z = max(zmin, min(CAM.zoom_max, z))
  return (x1 + x2) / 2, (y1 + y2) / 2, z
end

-- tiene l'inquadratura dentro la mappa
local function cam_clamp(world)
  local hw, hh = Render.W / (2 * Cam.z), Render.H / (2 * Cam.z)
  if world.width <= hw * 2 then Cam.x = world.width / 2
  else Cam.x = max(hw, min(world.width - hw, Cam.x)) end
  if world.height <= hh * 2 then Cam.y = world.height / 2
  else Cam.y = max(hh, min(world.height - hh, Cam.y)) end
end

function Render.update_camera(game, dt)
  local tx, ty, tz = cam_target(game)
  if Cam.world ~= game.world then
    -- nuova mappa: la telecamera parte gia' inquadrata
    Cam.world = game.world
    Cam.x, Cam.y, Cam.z = tx, ty, tz
  else
    local kp = 1 - math.exp(-dt * CAM.follow)
    local kz = 1 - math.exp(-dt * CAM.zoom_speed)
    Cam.x = Cam.x + (tx - Cam.x) * kp
    Cam.y = Cam.y + (ty - Cam.y) * kp
    Cam.z = Cam.z + (tz - Cam.z) * kz
  end
  cam_clamp(game.world)
end

function Render.apply_camera()
  lg.translate(Render.W / 2, Render.H / 2)
  lg.scale(Cam.z)
  lg.translate(-Cam.x, -Cam.y)
end

-- coordinate virtuali (640x360) -> coordinate del mondo
function Render.to_world(vx, vy)
  return (vx - Render.W / 2) / Cam.z + Cam.x, (vy - Render.H / 2) / Cam.z + Cam.y
end
local fonts = {}

function Render.load()
  fonts.small = lg.newFont(8, "mono")
  fonts.mid = lg.newFont(16, "mono")
  fonts.big = lg.newFont(32, "mono")
  for _, f in pairs(fonts) do f:setFilter("nearest", "nearest") end
end

function Render.font(name) return fonts[name] end

-- testo con ombra; align = "left" | "center" | "right" rispetto a x (centrato su limit se dato)
function Render.text(str, x, y, color, font, align, limit)
  lg.setFont(fonts[font or "small"])
  align = align or "left"
  limit = limit or 400
  local px = x
  if align == "center" then px = x - limit / 2 elseif align == "right" then px = x - limit end
  px, y = floor(px), floor(y)
  lg.setColor(0, 0, 0, 0.8)
  lg.printf(str, px + 1, y + 1, limit, align)
  lg.setColor(color[1], color[2], color[3], color[4] or 1)
  lg.printf(str, px, y, limit, align)
  lg.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Sfondo e mappa

local function draw_background()
  for i = 0, 11 do
    local t = i / 11
    lg.setColor(0.04 + 0.04 * t, 0.05 + 0.03 * t, 0.10 + 0.06 * t)
    lg.rectangle("fill", 0, i * 30, Render.W, 30)
  end
end

-- fondale dell'area di gioco, un po' piu' chiaro del fuori-mappa
local function draw_backdrop(world)
  local bands = 12
  local bh = world.height / bands
  for i = 0, bands - 1 do
    local t = i / (bands - 1)
    lg.setColor(0.06 + 0.05 * t, 0.07 + 0.04 * t, 0.14 + 0.08 * t)
    lg.rectangle("fill", 0, i * bh, world.width, bh + 1)
  end
end

local function draw_map(world, frame)
  local T = data.tile
  for r = 1, world.rows_n do
    for c = 1, world.cols do
      local t = world.grid[r][c]
      local x, y = (c - 1) * T, (r - 1) * T
      if t == "#" then
        local shade = ((c + r) % 2 == 0) and 0.0 or 0.02
        lg.setColor(0.15 + shade, 0.17 + shade, 0.27 + shade)
        lg.rectangle("fill", x, y, T, T)
        if world:tile(c, r - 1) ~= "#" then
          lg.setColor(0.36, 0.42, 0.62)
          lg.rectangle("fill", x, y, T, 2)
        end
        if world:tile(c, r + 1) ~= "#" then
          lg.setColor(0.08, 0.09, 0.15)
          lg.rectangle("fill", x, y + T - 2, T, 2)
        end
      elseif t == "=" then
        lg.setColor(0.80, 0.66, 0.38)
        lg.rectangle("fill", x, y, T, 4)
        lg.setColor(0.55, 0.43, 0.22)
        lg.rectangle("fill", x, y + 4, T, 2)
        if (c % 2) == 0 then
          lg.rectangle("fill", x + 6, y + 6, 4, 3)
        end
      elseif t == "^" then
        lg.setColor(0.85, 0.25, 0.25)
        lg.polygon("fill", x, y + T, x + T / 4, y + 5, x + T / 2, y + T)
        lg.polygon("fill", x + T / 2, y + T, x + T * 3 / 4, y + 5, x + T, y + T)
        lg.setColor(1, 0.7, 0.7)
        lg.rectangle("fill", x + T / 4 - 1, y + 5, 2, 2)
        lg.rectangle("fill", x + T * 3 / 4 - 1, y + 5, 2, 2)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Armi

local function draw_weapon_shape(id, color)
  lg.setColor(color[1], color[2], color[3])
  if id == "sword" then
    lg.rectangle("fill", 2, -1, 16, 2)
    lg.setColor(0.55, 0.4, 0.2)
    lg.rectangle("fill", 2, -3, 2, 6)
  elseif id == "hammer" then
    lg.setColor(0.55, 0.4, 0.2)
    lg.rectangle("fill", 2, -1, 14, 2)
    lg.setColor(color[1], color[2], color[3])
    lg.rectangle("fill", 13, -6, 8, 12)
    lg.setColor(1, 1, 1, 0.3)
    lg.rectangle("fill", 13, -6, 8, 2)
  elseif id == "pistol" then
    lg.rectangle("fill", 2, -2, 9, 3)
    lg.rectangle("fill", 3, 1, 3, 4)
  elseif id == "shotgun" then
    lg.rectangle("fill", 2, -2, 16, 3)
    lg.setColor(0.55, 0.4, 0.2)
    lg.rectangle("fill", 0, -1, 5, 4)
  elseif id == "spear" then
    lg.setColor(0.55, 0.4, 0.2)
    lg.rectangle("fill", 0, -1, 26, 2)
    lg.setColor(color[1], color[2], color[3])
    lg.polygon("fill", 26, -3, 33, 0, 26, 3)
  elseif id == "smg" then
    lg.rectangle("fill", 2, -2, 11, 4)
    lg.rectangle("fill", 6, 2, 3, 5)
    lg.setColor(0.25, 0.3, 0.28)
    lg.rectangle("fill", 13, -1, 3, 2)
  elseif id == "sniper" then
    lg.rectangle("fill", 0, -1, 24, 2)
    lg.rectangle("fill", 0, -1, 7, 4)
    lg.setColor(0.2, 0.25, 0.35)
    lg.rectangle("fill", 7, -4, 7, 2)
  elseif id == "grenade" then
    lg.rectangle("fill", 2, -3, 13, 6)
    lg.setColor(0.25, 0.3, 0.2)
    lg.rectangle("fill", 13, -3, 3, 6)
    lg.rectangle("fill", 5, 3, 3, 3)
  elseif id == "whip" then
    lg.rectangle("fill", 0, -1, 6, 3)
    lg.setColor(0.45, 0.3, 0.18)
    for i = 0, 7 do lg.rectangle("fill", 6 + i * 2, -1 + ((i % 2 == 0) and 0 or 1), 2, 1) end
  elseif id == "katana" then
    lg.rectangle("fill", 4, -1, 20, 1.5)
    lg.setColor(0.2, 0.2, 0.25)
    lg.rectangle("fill", 0, -1, 4, 2)
    lg.setColor(0.8, 0.65, 0.2)
    lg.rectangle("fill", 4, -2.5, 1, 5)
  elseif id == "shield" then
    lg.rectangle("fill", 3, -9, 4, 18)
    lg.setColor(0.85, 0.85, 0.9)
    lg.rectangle("fill", 5, -2, 2, 4)
  elseif id == "boomerang" then
    lg.polygon("fill", 2, -6, 10, 0, 2, 6, 5, 0)
  elseif id == "flamer" then
    lg.rectangle("fill", 2, -2, 13, 4)
    lg.setColor(0.7, 0.2, 0.1)
    lg.circle("fill", 4, 3, 3)
    lg.setColor(0.3, 0.3, 0.3)
    lg.rectangle("fill", 15, -1.5, 3, 3)
  elseif id == "mines" then
    lg.rectangle("fill", 2, -3, 9, 6)
    lg.setColor(1, 0.3, 0.2)
    lg.rectangle("fill", 5, -1, 2, 2)
  elseif id == "hook" then
    lg.rectangle("fill", 2, -1.5, 12, 3)
    lg.setColor(0.85, 0.85, 0.9)
    lg.rectangle("fill", 14, -4, 2, 8)
    lg.rectangle("fill", 16, -4, 2, 2)
    lg.rectangle("fill", 16, 2, 2, 2)
  elseif id == "bazooka" then
    lg.rectangle("fill", -2, -3, 22, 6)
    lg.setColor(0.25, 0.28, 0.2)
    lg.rectangle("fill", 18, -4, 3, 8)
    lg.rectangle("fill", 6, 3, 3, 4)
  elseif id == "gust" then
    lg.rectangle("fill", 2, -2, 8, 4)
    lg.polygon("fill", 10, -2, 18, -6, 18, 6, 10, 2)
  elseif id == "bubble" then
    lg.rectangle("fill", 2, -2, 9, 4)
    lg.rectangle("fill", 3, 2, 3, 3)
    lg.setColor(0.8, 0.95, 1, 0.8)
    lg.circle("line", 14, 0, 3)
  elseif id == "autoshotgun" then
    lg.rectangle("fill", 2, -2, 16, 3)
    lg.setColor(0.35, 0.25, 0.2)
    lg.circle("fill", 8, 3, 3)
    lg.rectangle("fill", 0, -1, 4, 4)
  elseif id == "assault" then
    lg.rectangle("fill", 0, -2, 20, 3)
    lg.rectangle("fill", 8, 1, 3, 5)
    lg.setColor(0.25, 0.3, 0.22)
    lg.rectangle("fill", 0, -1, 4, 4)
    lg.rectangle("fill", 20, -1, 3, 1)
  elseif id == "blackhole" then
    lg.rectangle("fill", 2, -3, 12, 6)
    lg.setColor(0.08, 0.02, 0.15)
    lg.circle("fill", 17, 0, 4)
    lg.setColor(0.7, 0.4, 1, 0.9)
    lg.circle("line", 17, 0, 4)
  elseif id == "ghost" then
    lg.setColor(color[1], color[2], color[3], 0.75)
    lg.rectangle("fill", 0, -1.5, 22, 3)
    lg.rectangle("fill", 0, -1, 6, 4)
    lg.setColor(1, 1, 1, 0.5)
    lg.rectangle("fill", 8, -3, 5, 1)
  elseif id == "swarm" then
    lg.rectangle("fill", 2, -4, 13, 8)
    lg.setColor(0.3, 0.1, 0.15)
    for k = -1, 1 do lg.circle("fill", 15, k * 2.5, 1.2) end
  else
    lg.rectangle("fill", 2, -1, 8, 2)
  end
end

local function draw_held_weapon(p, game)
  local def = Player.weapon_def(p)
  local a = p.action
  lg.push()
  lg.translate(floor(p.x), floor(p.y - 11))
  if p.weapon and def.kind == "ranged" then
    local ang = atan2(p.aimy, p.aimx)
    if a and a.type == "attack" and a.phase == "recovery" then ang = ang - 0.15 * p.facing end
    lg.rotate(ang)
    lg.translate(-floor(Fx.pstate(p.id).recoil + 0.5), 0)
    draw_weapon_shape(def.id, def.color)
  elseif p.weapon then
    lg.scale(p.facing, 1)
    local ang = (def.id == "shield") and 0 or 1.0
    if def.id == "shield" and a and a.type == "attack" then
      -- spinta: lo scudo avanza invece di ruotare
      if a.phase == "active" then lg.translate(5, 0) end
      a = nil
    end
    if a and a.type == "attack" then
      local s = a.startup
      if a.frame <= s then
        ang = 1.0 - (2.3 * a.frame / s)
      elseif a.frame <= s + def.active then
        ang = -1.0 + 1.6 * ((a.frame - s) / def.active)
      else
        local r = (a.frame - s - def.active) / def.recovery
        ang = 0.6 + 0.4 * r
      end
    end
    lg.rotate(ang)
    draw_weapon_shape(def.id, def.color)
  else
    -- pugni
    lg.scale(p.facing, 1)
    local reach = 4
    if a and a.type == "attack" then
      if a.phase == "active" then reach = 11
      elseif a.phase == "startup" then reach = 1 end
    end
    lg.setColor(p.color[1] * 0.6 + 0.4, p.color[2] * 0.6 + 0.4, p.color[3] * 0.6 + 0.4)
    lg.rectangle("fill", reach, -2, 4, 4)
  end
  lg.pop()
  -- effetto del colpo in mischia
  if a and a.type == "attack" and a.phase == "active" and def.kind == "melee" then
    local x1, y1, x2, y2 = Combat.melee_rect(p, def)
    local f = p.facing
    local cx, cy = p.x, p.y - 11
    local reach = max(abs(x1 - cx), abs(x2 - cx))
    local k = min(1, (a.frame - a.startup) / max(1, def.active))
    local col = def.color or { 1, 1, 1 }
    local heavy = (def.damage or 10) >= 25
    lg.setBlendMode("add")
    if def.id == "spear" or (y2 - y1) <= 10 then
      -- affondo: striscia che si allunga in avanti
      local len = reach * (0.5 + 0.5 * k)
      for j = 0, 2 do
        lg.setColor(col[1], col[2], col[3], 0.55 - j * 0.15)
        lg.polygon("fill", cx + f * 6, cy - 3 + j, cx + f * len, cy, cx + f * 6, cy + 3 - j)
      end
      lg.setColor(1, 1, 1, 0.8)
      lg.rectangle("fill", cx + f * (len - 3) - 1.5, cy - 1, 3, 2)
    else
      -- fendente: mezzaluna che spazza dall'alto in avanti
      local a0 = -1.35
      local a1 = a0 + (heavy and 2.9 or 2.5) * min(1, 0.35 + k)
      local rin = reach * 0.45
      local n = 10
      for layer = 1, 2 do
        local ro = reach * (layer == 1 and 1 or 0.85)
        lg.setColor(col[1], col[2], col[3], (layer == 1 and 0.35 or 0.55) * (1 - 0.6 * k))
        local poly = {}
        for i = 0, n do
          local t = a0 + (a1 - a0) * i / n
          poly[#poly + 1] = cx + f * cos(t) * ro
          poly[#poly + 1] = cy + sin(t) * ro
        end
        for i = n, 0, -1 do
          local t = a0 + (a1 - a0) * i / n
          local r2 = rin + (ro - rin) * (1 - i / n) * 0.6
          poly[#poly + 1] = cx + f * cos(t) * r2
          poly[#poly + 1] = cy + sin(t) * r2
        end
        local ok = pcall(lg.polygon, "fill", poly)
        if not ok then lg.circle("fill", cx + f * reach * 0.6, cy, reach * 0.4) end
      end
      lg.setColor(1, 1, 1, 0.9 * (1 - k))
      lg.setLineWidth(heavy and 2 or 1)
      local pts = {}
      for i = 0, n do
        local t = a0 + (a1 - a0) * i / n
        pts[#pts + 1] = cx + f * cos(t) * reach
        pts[#pts + 1] = cy + sin(t) * reach
      end
      lg.line(pts)
      lg.setLineWidth(1)
    end
    lg.setBlendMode("alpha")
  end
end

-- ---------------------------------------------------------------------------
-- Giocatori

local function draw_player(p, game, time)
  if not p.alive then return end
  local a = p.action
  local alpha = 1
  if p.invuln > 0 and a and a.type == "dash" then alpha = 0.45 end
  local c = p.color
  if p.hitstun > 0 and (game.frame % 4) < 2 then c = { 1, 1, 1 } end
  local ps = Fx.pstate(p.id)
  if ps.white > 0 then c = { 1, 1, 1 } end

  local x, y = floor(p.x), floor(p.y)
  -- schiacciamento/allungamento con i piedi come perno
  lg.push()
  lg.translate(x, y)
  lg.scale(1 + ps.sq, 1 - ps.sq)
  lg.translate(-x, -y)

  if not Sprites.draw_player(p, time, c, alpha) then
    Look.player(p, c, alpha, ps, time)
  end
  lg.pop()

  -- corda del rampino durante il traino
  if p.grapple then
    lg.setColor(0.75, 0.7, 0.6, 0.9)
    lg.line(x, y - 11, p.grapple.x, p.grapple.y - 10)
    lg.setColor(0.85, 0.85, 0.9)
    lg.circle("fill", p.grapple.x, p.grapple.y - 10, 2.5)
  end

  draw_held_weapon(p, game)

  -- fuoco: fiammelle che salgono dal personaggio
  if p.burn > 0 then
    for k = 1, 5 do
      local ph = (time * 3 + k * 0.37) % 1
      local fx = x - 5 + ((k * 7) % 11)
      lg.setColor(1, 0.85 - 0.6 * ph, 0.2, 0.9 * (1 - ph))
      lg.rectangle("fill", fx, y - 6 - ph * 22, 2, 2)
    end
  end
  -- bolla
  if p.bubble > 0 then
    local wob = sin(time * 8) * 1.2
    lg.setColor(0.6, 0.85, 1, 0.22)
    lg.circle("fill", x, y - 10, 16 + wob)
    lg.setColor(0.8, 0.95, 1, 0.9)
    lg.circle("line", x, y - 10, 16 + wob)
    lg.rectangle("fill", x - 8, y - 20, 3, 2)
    -- la bolla lampeggia quando sta per scoppiare
    if p.bubble < 30 and floor(time * 12) % 2 == 0 then
      lg.setColor(1, 1, 1, 0.6)
      lg.circle("line", x, y - 10, 18)
    end
  end

  -- nessun mirino: la direzione di tiro si legge dall'arma, che ruota verso la mira.
  -- Il cecchino in carica fa brillare la canna, senza mostrare la traiettoria.
  local wdef = Player.weapon_def(p)
  if p.weapon and wdef.id == "sniper" and a and a.type == "attack" and a.phase == "startup" then
    local k = a.frame / a.startup
    local tx, ty = x + p.aimx * 25, y - 11 + p.aimy * 25
    lg.setColor(1, 0.3, 0.2, 0.4 + 0.6 * k)
    lg.circle("fill", tx, ty, 1 + 2 * k)
  end

  -- scudo del parry
  if a and a.type == "parry" then
    local alpha2 = a.active and 0.95 or 0.3
    lg.setColor(0.5, 0.95, 1, alpha2)
    lg.setLineWidth(2)
    local cx = x + p.facing * 5
    local from, to = -1.1, 1.1
    if p.facing < 0 then from, to = math.pi - 1.1, math.pi + 1.1 end
    lg.arc("line", "open", cx, y - 10, 11, from, to)
    lg.setLineWidth(1)
  end
  if p.parry_flash > 0 then
    lg.setColor(0.6, 1, 1, p.parry_flash / 12)
    lg.circle("line", x, y - 10, 14 + (12 - p.parry_flash))
  end
  if p.clash > 0 then
    lg.setColor(1, 1, 0.5, 0.9)
    lg.print("*", x - 3, y - 36)
  end

  -- barre sopra la testa
  local bx = x - 8
  lg.setColor(0, 0, 0, 0.7)
  lg.rectangle("fill", bx - 1, y - 30, 18, 4)
  lg.setColor(0.2, 0.2, 0.2)
  lg.rectangle("fill", bx, y - 29, 16, 2)
  local hpf = max(0, p.hp) / data.player.hp
  -- danno appena subito: tratto bianco che si consuma dopo un attimo
  local chipf = max(0, ps.chip or p.hp) / data.player.hp
  if chipf > hpf then
    lg.setColor(1, 1, 1, 0.9)
    lg.rectangle("fill", bx + 16 * hpf, y - 29, 16 * (chipf - hpf), 2)
  end
  -- vita bassa: la barra lampeggia
  if hpf < 0.3 and floor(time * 6) % 2 == 0 then lg.setColor(1, 0.95, 0.9)
  else lg.setColor(1 - hpf, 0.3 + 0.7 * hpf, 0.25) end
  lg.rectangle("fill", bx, y - 29, 16 * hpf, 2)
  local mf = min(1, p.momentum / data.momentum.max)
  lg.setColor(0, 0, 0, 0.6)
  lg.rectangle("fill", bx, y - 26, 16, 2)
  local tier = Player.tier(p)
  if tier == 2 then lg.setColor(1, 0.85, 0.2)
  elseif tier == 1 then lg.setColor(0.8, 0.9, 0.4) else lg.setColor(0.6, 0.6, 0.6) end
  lg.rectangle("fill", bx, y - 26, 16 * mf, 2)
  -- indicatore giocatore
  lg.setColor(c[1], c[2], c[3])
  lg.polygon("fill", x - 3, y - 37, x + 3, y - 37, x, y - 33)
end

-- ---------------------------------------------------------------------------
-- Oggetti, proiettili, annunci

local function draw_items(game, time)
  for _, it in ipairs(game.items) do
    local def = data.weapons[it.weapon.id]
    local r = data.tiers[it.weapon.tier or 1]
    local bob = floor(sin(time * 4 + it.id) * 1.5)
    local blink = it.life < 120 and (floor(time * 10) % 2 == 0)
    local tier = it.weapon.tier or 1
    local c = r.color
    local gx, gy = floor(it.x), floor(it.y)
    -- piedistallo luminoso e, per le armi forti, fascio di luce visibile da lontano
    lg.setBlendMode("add")
    lg.setColor(c[1], c[2], c[3], 0.25 + 0.1 * sin(time * 5))
    lg.ellipse("fill", gx, gy, 10, 3)
    if tier >= 3 then
      local hgt = tier == 4 and 120 or 70
      for j = 0, 5 do
        lg.setColor(c[1], c[2], c[3], (tier == 4 and 0.10 or 0.07) * (1 - j / 6))
        lg.rectangle("fill", gx - 5 + j * 0.5, gy - j * hgt / 6 - hgt / 6, 10 - j, hgt / 6)
      end
      if tier == 4 then
        for j = 1, 4 do
          local ph = (time * 0.8 + j * 0.25) % 1
          lg.setColor(1, 0.95, 0.6, 1 - ph)
          lg.rectangle("fill", gx - 8 + (j * 5) % 16, gy - 4 - ph * 30, 1, 1)
        end
      end
    end
    lg.setBlendMode("alpha")
    -- nome dell'arma quando un giocatore e' vicino
    for _, p in ipairs(game.players) do
      if p.alive and abs(p.x - it.x) < 40 and abs(p.y - it.y) < 30 then
        Render.text(def.short or def.name, gx, gy - 26 + bob, { c[1], c[2], c[3] }, "small", "center", 80)
        break
      end
    end
    if not blink then
      local x, y = floor(it.x), floor(it.y) + bob
      lg.setColor(r.color[1], r.color[2], r.color[3], 0.35 + 0.2 * sin(time * 6))
      lg.rectangle("fill", x - 7, y - 11, 14, 11)
      lg.push()
      lg.translate(x - 7, y - 5)
      lg.scale(0.85, 0.85)
      draw_weapon_shape(def.id, def.color)
      lg.pop()
      lg.setColor(r.color[1], r.color[2], r.color[3])
      lg.rectangle("line", x - 7.5, y - 11.5, 15, 12)
    end
  end
end

local function draw_telegraphs(game, time)
  for _, t in ipairs(game.telegraphs) do
    local prog = 1 - t.t / data.round.telegraph
    local col = t.crate and { 1, 0.85, 0.3 } or { 0.8, 0.9, 1 }
    lg.setColor(col[1], col[2], col[3], 0.15 + 0.25 * prog)
    lg.rectangle("fill", t.x - 3, 0, 6, t.y)
    lg.setColor(col[1], col[2], col[3], 0.5 + 0.5 * sin(time * 20))
    lg.circle("line", t.x, t.y - 4, 12 - 8 * prog)
    if t.crate then
      lg.rectangle("line", t.x - 8, t.y - 14, 16, 14)
    end
  end
end

-- Eventi di mappa: colonne di avviso e oggetti in caduta
local function draw_hazards(game, time)
  for _, h in ipairs(game.hazards or {}) do
    local x = floor(h.x)
    if h.phase == "warn" then
      local k = 1 - min(1, h.t / data.map_events.warn)
      local fast = h.t < 25
      local on = floor(time * (fast and 16 or 6)) % 2 == 0
      local c = h.kind == "lightning" and { 0.6, 0.85, 1 } or (h.kind == "barrels" and { 1, 0.4, 0.2 } or { 1, 0.75, 0.3 })
      local hw = h.kind == "lightning" and data.map_events.lightning.width / 2 or 7
      lg.setBlendMode("add")
      lg.setColor(c[1], c[2], c[3], 0.06 + 0.16 * k)
      lg.rectangle("fill", x - hw, h.y0, hw * 2, (h.y2 or h.y0 + 200) - h.y0)
      lg.setBlendMode("alpha")
      -- tratteggio ai bordi
      lg.setColor(c[1], c[2], c[3], 0.5 + 0.4 * k)
      for yy = h.y0, (h.y2 or h.y0) - 6, 12 do
        lg.rectangle("fill", x - hw, yy + (time * 30) % 12, 1, 5)
        lg.rectangle("fill", x + hw - 1, yy + (time * 30) % 12, 1, 5)
      end
      -- bersaglio sul pavimento e segnale in alto
      if h.y2 then
        lg.setColor(c[1], c[2], c[3], 0.4 + 0.5 * k)
        lg.ellipse("line", x, h.y2, hw + 6 - 4 * k, 3)
      end
      if on then
        lg.setColor(c[1], c[2], c[3])
        lg.polygon("fill", x, h.y0 + 2, x - 6, h.y0 + 13, x + 6, h.y0 + 13)
        lg.setColor(0.1, 0.05, 0.05)
        lg.rectangle("fill", x - 0.5, h.y0 + 5, 1, 4)
        lg.rectangle("fill", x - 0.5, h.y0 + 10, 1, 1)
      end
    elseif h.kind == "rocks" then
      lg.push()
      lg.translate(x, h.y)
      lg.rotate(time * 4 + h.x)
      lg.setColor(0.08, 0.07, 0.07)
      lg.polygon("fill", -7, -3, -3, -7, 4, -6, 7, -1, 5, 6, -2, 7, -7, 3)
      lg.setColor(0.52, 0.47, 0.42)
      lg.polygon("fill", -6, -3, -3, -6, 4, -5, 6, -1, 4, 5, -2, 6, -6, 3)
      lg.setColor(0.68, 0.63, 0.58)
      lg.polygon("fill", -3, -5, 3, -4, 0, -1)
      lg.pop()
    else
      lg.setColor(0.08, 0.05, 0.05)
      lg.rectangle("fill", x - 6, h.y - 7, 12, 14, 2, 2)
      lg.setColor(0.75, 0.2, 0.15)
      lg.rectangle("fill", x - 5, h.y - 6, 10, 12, 2, 2)
      lg.setColor(0.95, 0.8, 0.2)
      lg.rectangle("fill", x - 5, h.y - 2, 10, 3)
      lg.setColor(0.1, 0.1, 0.1)
      lg.rectangle("fill", x - 1, h.y - 2, 2, 3)
      if floor(time * 10) % 2 == 0 then lg.setColor(1, 0.3, 0.2); lg.rectangle("fill", x - 1, h.y - 8, 2, 2) end
    end
  end
end

-- Buchi neri: nucleo scuro, polvere che gira verso il centro, bordo del raggio d'azione
local function draw_fields(game, time)
  for _, f in ipairs(game.fields or {}) do
    local d = f.def
    local life = f.t / f.max
    lg.setColor(0.5, 0.25, 0.9, 0.06 + 0.04 * sin(time * 6))
    lg.circle("fill", f.x, f.y, d.radius)
    lg.setColor(0.6, 0.35, 1, 0.25)
    lg.circle("line", f.x, f.y, d.radius)
    for k = 1, 28 do
      local seed = k * 2.399
      local r = ((seed * 37 + time * 90) % d.radius)
      r = d.radius - r
      local ang = seed + time * (3 + 140 / (r + 10))
      lg.setColor(0.8, 0.6, 1, 0.7 * (1 - r / d.radius))
      lg.rectangle("fill", f.x + math.cos(ang) * r, f.y + math.sin(ang) * r, 1.5, 1.5)
    end
    lg.setColor(0.7, 0.45, 1, 0.8)
    lg.circle("line", f.x, f.y, 12 + 2 * sin(time * 15))
    lg.setColor(0, 0, 0)
    lg.circle("fill", f.x, f.y, 10 * (0.6 + 0.4 * life))
  end
end

local function draw_projectiles(game, time)
  for _, pr in ipairs(game.projectiles) do
    local col = pr.color or { 1, 1, 0.6 }
    if pr.kind == "grenade" then
      lg.setColor(0.25, 0.35, 0.2)
      lg.circle("fill", pr.x, pr.y, 3.5)
      -- la spia lampeggia sempre piu' veloce prima dell'esplosione
      local rate = pr.life < 30 and 30 or 10
      if floor(time * rate) % 2 == 0 then
        lg.setColor(1, 0.3, 0.2)
        lg.rectangle("fill", pr.x - 1, pr.y - 4, 2, 2)
      end
    elseif pr.kind == "sniper" then
      local len = math.sqrt(pr.vx * pr.vx + pr.vy * pr.vy)
      local tx, ty = pr.vx / len, pr.vy / len
      lg.setColor(0.6, 0.85, 1, 0.5)
      lg.setLineWidth(2)
      lg.line(pr.x - tx * 26, pr.y - ty * 26, pr.x, pr.y)
      lg.setLineWidth(1)
      lg.setColor(1, 1, 1)
      lg.rectangle("fill", pr.x - 1.5, pr.y - 1.5, 3, 3)
    elseif pr.kind == "thrown" then
      lg.setColor(col[1], col[2], col[3])
      lg.rectangle("fill", pr.x - 4, pr.y - 3, 8, 6)
    elseif pr.kind == "boomerang" then
      lg.push()
      lg.translate(pr.x, pr.y)
      lg.rotate(pr.age * 0.6)
      lg.setColor(col[1], col[2], col[3])
      lg.polygon("fill", -5, -5, 4, 0, -5, 5, -2, 0)
      lg.pop()
    elseif pr.kind == "flame" then
      local k = math.min(1, pr.age / 32)
      lg.setColor(1, 0.9 - 0.6 * k, 0.3 - 0.25 * k, 0.85 - 0.6 * k)
      lg.circle("fill", pr.x, pr.y, 2 + 5 * k)
    elseif pr.kind == "mine" then
      local armed = pr.stuck and pr.arm <= 0
      lg.setColor(0.35, 0.35, 0.32)
      lg.rectangle("fill", pr.x - 5, pr.y - 3, 10, 4)
      if not pr.stuck or not armed or floor(time * 4) % 2 == 0 then
        if armed then lg.setColor(1, 0.2, 0.15) else lg.setColor(0.4, 1, 0.4) end
        lg.rectangle("fill", pr.x - 1, pr.y - 4, 2, 2)
      end
    elseif pr.kind == "hook" then
      local o = game.players[pr.owner]
      if o and o.alive then
        lg.setColor(0.75, 0.7, 0.6, 0.9)
        lg.line(o.x, o.y - 11, pr.x, pr.y)
      end
      lg.setColor(0.85, 0.85, 0.9)
      lg.circle("fill", pr.x, pr.y, 2.5)
    elseif pr.kind == "rocket" or pr.kind == "missile" then
      local len = math.sqrt(pr.vx * pr.vx + pr.vy * pr.vy) + 0.001
      local tx, ty = pr.vx / len, pr.vy / len
      local L = (pr.kind == "rocket") and 7 or 4
      lg.setColor(1, 0.6, 0.15, 0.7 + 0.3 * sin(time * 40))
      lg.circle("fill", pr.x - tx * L, pr.y - ty * L, (pr.kind == "rocket") and 3 or 2)
      lg.setColor(0.6, 0.6, 0.6, 0.25)
      lg.circle("fill", pr.x - tx * L * 2.2, pr.y - ty * L * 2.2, (pr.kind == "rocket") and 4 or 2.5)
      lg.setColor(col[1], col[2], col[3])
      lg.setLineWidth((pr.kind == "rocket") and 4 or 2)
      lg.line(pr.x - tx * L, pr.y - ty * L, pr.x + tx * 2, pr.y + ty * 2)
      lg.setLineWidth(1)
    elseif pr.kind == "gust" then
      local k = math.min(1, pr.age / 26)
      local dir = (pr.vx >= 0) and 1 or -1
      lg.setColor(0.85, 0.95, 1, 0.55 * (1 - k))
      for j = 0, 2 do
        lg.arc("line", "open", pr.x - dir * j * 5, pr.y, 7 + j * 3 + 6 * k,
          dir > 0 and -1 or math.pi - 1, dir > 0 and 1 or math.pi + 1)
      end
    elseif pr.kind == "bubble" then
      lg.setColor(0.6, 0.85, 1, 0.25)
      lg.circle("fill", pr.x, pr.y, 5)
      lg.setColor(0.8, 0.95, 1, 0.9)
      lg.circle("line", pr.x, pr.y, 5)
      lg.rectangle("fill", pr.x - 2.5, pr.y - 3, 1.5, 1.5)
    elseif pr.kind == "singularity" then
      lg.setColor(0.6, 0.35, 1, 0.35)
      lg.circle("fill", pr.x, pr.y, 8 + sin(time * 20))
      lg.setColor(0.05, 0.0, 0.1)
      lg.circle("fill", pr.x, pr.y, 5)
    elseif pr.kind == "ghost" then
      local len = math.sqrt(pr.vx * pr.vx + pr.vy * pr.vy) + 0.001
      local tx, ty = pr.vx / len, pr.vy / len
      for j = 4, 1, -1 do
        lg.setColor(0.75, 0.6, 1, 0.12 * (5 - j))
        lg.circle("fill", pr.x - tx * j * 5, pr.y - ty * j * 5, 2.5)
      end
      lg.setColor(0.95, 0.9, 1, 0.85)
      lg.circle("fill", pr.x, pr.y, 2.5)
    else
      lg.setBlendMode("add")
      lg.setColor(col[1], col[2], col[3], 0.45)
      lg.setLineWidth(max(1, min(pr.w, pr.h)))
      lg.line(pr.x - pr.vx * 0.04, pr.y - pr.vy * 0.04, pr.x, pr.y)
      lg.setLineWidth(1)
      lg.setColor(col[1], col[2], col[3], 0.18)
      lg.circle("fill", pr.x, pr.y, max(pr.w, pr.h) + 2)
      lg.setBlendMode("alpha")
      lg.setColor(1, 1, 0.85)
      lg.rectangle("fill", pr.x - pr.w / 2, pr.y - pr.h / 2, pr.w, pr.h)
      if pr.reflected then
        lg.setColor(0.5, 0.95, 1, 0.7)
        lg.rectangle("line", pr.x - pr.w / 2 - 1, pr.y - pr.h / 2 - 1, pr.w + 2, pr.h + 2)
      end
    end
  end
end

local function draw_lava(game, time)
  if not game.lava_on then return end
  local W = game.world.width
  local y = game.lava_y
  local h = game.world.height + 200 - y
  -- bagliore sopra la superficie
  lg.setBlendMode("add")
  for j = 0, 5 do
    lg.setColor(1, 0.35, 0.1, 0.05 * (6 - j) / 6)
    lg.rectangle("fill", 0, y - 12 - j * 10, W, 12)
  end
  lg.setBlendMode("alpha")
  -- strati: crosta scura in profondita', arancio, superficie gialla ondulata
  lg.setColor(0.55, 0.08, 0.04, 0.95)
  lg.rectangle("fill", 0, y + 14, W, h)
  lg.setColor(0.9, 0.25, 0.06, 0.95)
  lg.rectangle("fill", 0, y + 4, W, 12)
  for x = 0, W, 6 do
    local wv = sin(time * 4 + x * 0.12) * 2 + sin(time * 2.3 + x * 0.05) * 2
    lg.setColor(1, 0.5, 0.1)
    lg.rectangle("fill", x, y + wv, 6, 6)
    lg.setColor(1, 0.85, 0.3)
    lg.rectangle("fill", x, y + wv - 1, 6, 2)
  end
  -- bolle che salgono e scoppiano
  for i = 1, 24 do
    local ph = (time * (0.6 + (i % 5) * 0.15) + i * 0.37) % 1
    local bx = (i * 53.7) % W
    lg.setColor(1, 0.8, 0.3, 1 - ph)
    lg.circle(ph > 0.8 and "line" or "fill", bx, y + 12 - ph * 10, 1 + ph * 2)
  end
  -- braci che volano su
  for i = 1, 18 do
    local ph = (time * 0.5 + i * 0.13) % 1
    lg.setColor(1, 0.6, 0.2, 1 - ph)
    lg.rectangle("fill", (i * 97.3 + sin(time + i) * 10) % W, y - ph * 60, 1, 1)
  end
end

-- ---------------------------------------------------------------------------
-- Interfaccia

-- schede dei giocatori in alto: faccia dell'eroe, vita, vittorie, arma
local function draw_hud(game, time)
  local n = #game.players
  local gap = 4
  local cw = min(104, (Render.W - 16 - gap * (n - 1)) / n)
  local x0 = (Render.W - (cw * n + gap * (n - 1))) / 2
  for i, p in ipairs(game.players) do
    local x, y = floor(x0 + (i - 1) * (cw + gap)), 3
    local c = p.color
    local a = p.alive and 1 or 0.55
    local lo = Look.loadout[i] or {}
    lg.setColor(0, 0, 0, 0.55 * a)
    lg.rectangle("fill", x, y, cw, 24, 4, 4)
    lg.setColor(c[1], c[2], c[3], a)
    lg.rectangle("fill", x, y, 3, 24, 2, 2)
    lg.setColor(c[1], c[2], c[3], 0.6 * a)
    lg.rectangle("line", x + 0.5, y + 0.5, cw - 1, 23, 4, 4)
    -- faccia: sobbalza quando prende un colpo, grigia se eliminato
    local ps = Fx.pstate(p.id)
    local jig = (ps.white or 0) > 0 and 1 or 0
    Heroes.draw_head(lo.hero or "gatto", lo.skin or 1, x + 5 + jig, y + 5, 1, a, not p.alive)
    if not p.alive then
      lg.setColor(1, 0.3, 0.3, 0.9)
      lg.setLineWidth(2)
      lg.line(x + 6, y + 6, x + 17, y + 17); lg.line(x + 17, y + 6, x + 6, y + 17)
      lg.setLineWidth(1)
    end
    -- vita con la parte persa che si consuma
    local bx, bw = x + 22, cw - 26
    local hpf = max(0, p.hp) / data.player.hp
    local chipf = max(0, ps.chip or p.hp) / data.player.hp
    lg.setColor(0.12, 0.12, 0.16, a)
    lg.rectangle("fill", bx, y + 4, bw, 4, 2, 2)
    if chipf > hpf then lg.setColor(1, 1, 1, 0.8 * a); lg.rectangle("fill", bx, y + 4, bw * chipf, 4, 2, 2) end
    if hpf < 0.3 and p.alive and floor(time * 6) % 2 == 0 then lg.setColor(1, 0.95, 0.9)
    else lg.setColor(1 - hpf * 0.7, 0.35 + 0.6 * hpf, 0.3, a) end
    if hpf > 0 then lg.rectangle("fill", bx, y + 4, max(2, bw * hpf), 4, 2, 2) end
    -- vittorie
    for k = 1, game.wins_target do
      if k <= game.scores[i] then lg.setColor(1, 0.85, 0.25, a) else lg.setColor(0.28, 0.28, 0.36, a) end
      lg.circle("fill", bx + 2 + (k - 1) * 6, y + 12, 2)
    end
    -- arma
    if p.weapon then
      local def = data.weapons[p.weapon.id]
      local amount = p.weapon.ammo or p.weapon.uses
      local rc = data.tiers[p.weapon.tier or 1].color
      Render.text((def.short or def.name) .. (amount and (" " .. amount) or ""), bx, y + 14,
        { rc[1], rc[2], rc[3], a }, "small", "left", bw)
    else
      Render.text("a mani nude", bx, y + 14, { 0.5, 0.5, 0.6, a }, "small", "left", bw)
    end
  end
end

local function draw_banner(game, time)
  local W, H = Render.W, Render.H
  local R = data.round
  local function winner_name(id)
    local lo = Look.loadout[id]
    return lo and Heroes.get(lo.hero).name or data.color_names[((id - 1) % #data.color_names) + 1]
  end
  if game.phase == "countdown" then
    -- numero che "salta" a ogni secondo, poi VIA! che esplode
    local secs = math.ceil(game.timer / 60)
    local frac = (game.timer % 60) / 60
    local go = game.timer <= 15
    local label = go and "VIA!" or tostring(secs)
    local pop = go and (1 + (15 - game.timer) / 15 * 0.8) or (1 + 0.6 * max(0, frac - 0.75) * 4)
    local band = 0.45 * min(1, (data.round.countdown - game.timer) / 12)
    lg.setColor(0, 0, 0, band)
    lg.rectangle("fill", 0, H / 2 - 52, W, 104)
    lg.setColor(1, 0.85, 0.3, band)
    lg.rectangle("fill", 0, H / 2 - 52, W, 2); lg.rectangle("fill", 0, H / 2 + 50, W, 2)
    Render.text("ROUND " .. game.round, W / 2, H / 2 - 46, { 1, 1, 1 }, "mid", "center", W)
    Render.text(string.upper(game.world.name), W / 2, H / 2 + 34, { 0.7, 0.75, 0.95 }, "small", "center", W)
    lg.push()
    lg.translate(W / 2, H / 2 + 2)
    lg.scale(pop * (go and 1.3 or 1))
    Render.text(label, 0, -16, go and { 0.5, 1, 0.5, go and min(1, game.timer / 8) or 1 } or { 1, 0.9, 0.3 },
      "big", "center", W)
    lg.pop()
  elseif game.phase == "roundend" then
    local k = min(1, (data.round.end_delay - game.timer) / 15)
    local ek = 1 - (1 - k) ^ 3
    lg.setColor(0, 0, 0, 0.45 * ek)
    lg.rectangle("fill", 0, H / 2 - 34, W, 68)
    if #game.winners == 0 then
      Render.text("PAREGGIO", W / 2, H / 2 - 16, { 1, 1, 1, ek }, "big", "center", W)
    else
      local id = game.winners[1]
      local wc = game.players[id].color
      local lo = Look.loadout[id] or {}
      local names = {}
      for _, w in ipairs(game.winners) do names[#names + 1] = winner_name(w) end
      local xoff = (1 - ek) * -60
      lg.setColor(wc[1], wc[2], wc[3], ek)
      lg.rectangle("fill", 0, H / 2 - 34, W, 2); lg.rectangle("fill", 0, H / 2 + 32, W, 2)
      Heroes.draw_head(lo.hero or "gatto", lo.skin or 1, W / 2 - 150 + xoff, H / 2 - 26, 4, ek)
      Render.text("PUNTO A", W / 2 + 20 - xoff, H / 2 - 26, { 1, 1, 1, ek }, "mid", "center", 300)
      Render.text(table.concat(names, " e "), W / 2 + 20 - xoff, H / 2 - 6, { wc[1], wc[2], wc[3], ek }, "mid", "center", 300)
      local sc = game.scores[id] or 0
      for s2 = 1, game.wins_target do
        if s2 <= sc then lg.setColor(1, 0.85, 0.25, ek) else lg.setColor(0.3, 0.3, 0.4, ek) end
        local pop2 = (s2 == sc) and (1 + 0.6 * (1 - ek)) or 1
        lg.circle("fill", W / 2 + 20 - (game.wins_target - 1) * 6 + (s2 - 1) * 12, H / 2 + 20, 4 * pop2)
      end
    end
  end
  if Fx.banner and game.phase == "playing" then
    local b = Fx.banner
    local k = min(1, (1.6 - b.t) * 6)
    local s = 1 + 0.4 * (1 - k)
    lg.push()
    lg.translate(W / 2, 64)
    lg.scale(s)
    Render.text(b.text, 0, -16, { 1, 0.75, 0.3, min(1, b.t * 2) }, "big", "center", W)
    lg.pop()
  end
  if game.phase == "playing" and (game.lava_on or game.round_frame >= R.sudden_death_warning) then
    local pulse = (sin(time * (game.lava_on and 3 or 8)) + 1) / 2
    local a = (game.lava_on and 0.10 or 0.18) * pulse
    for j = 0, 4 do
      lg.setColor(1, 0.2, 0.05, a * (5 - j) / 5)
      lg.rectangle("fill", 0, j * 4, W, 4)
      lg.rectangle("fill", 0, H - (j + 1) * 4, W, 4)
      lg.rectangle("fill", j * 4, 0, 4, H)
      lg.rectangle("fill", W - (j + 1) * 4, 0, 4, H)
    end
  end
  if game.phase == "playing" and game.round_frame >= R.sudden_death_warning and not game.lava_on
     and floor(time * 4) % 2 == 0 then
    Render.text("LAVA IN ARRIVO!", W / 2, 32, { 1, 0.4, 0.2 }, "mid", "center", W)
  elseif game.lava_on and game.phase == "playing" then
    Render.text("MORTE IMPROVVISA", W / 2, 32, { 1, 0.4, 0.2 }, "small", "center", W)
  end
end

-- ---------------------------------------------------------------------------

function Render.game(game, time)
  Look.sky(game.world, time, Render.W, Render.H)
  lg.push()
  Render.apply_camera()
  Look.back(game.world, Cam, time)
  Look.map(game.world, time)
  draw_telegraphs(game, time)
  draw_items(game, time)
  Fx.draw_under()
  for _, p in ipairs(game.players) do draw_player(p, game, time) end
  draw_fields(game, time)
  draw_hazards(game, time)
  draw_projectiles(game, time)
  draw_lava(game, time)
  Look.ambient(game.world, time)
  Fx.draw()
  lg.pop()
  Fx.draw_screen(Render.W, Render.H)
  draw_hud(game, time)
  draw_banner(game, time)
  lg.setColor(1, 1, 1, 1)
end

return Render
