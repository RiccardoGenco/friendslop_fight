-- Effetti visivi e sonori guidati dagli eventi della simulazione:
-- particelle, screen shake, scie dello scatto. Qui si usa il random di LÖVE perche'
-- non influisce sulla simulazione.

local Audio = require("src.audio")

local Fx = { particles = {}, ghosts = {}, rings = {}, shake = 0,
             freeze = 0, kx = 0, ky = 0, flash = 0, flashes = {}, pl = {}, bolts = {}, banner = nil,
             columns = {} }

local function rnd(a, b) return a + love.math.random() * (b - a) end

function Fx.reset()
  Fx.particles, Fx.ghosts, Fx.rings, Fx.shake = {}, {}, {}, 0
  Fx.freeze, Fx.kx, Fx.ky, Fx.flash, Fx.flashes, Fx.pl = 0, 0, 0, 0, {}, {}
  Fx.bolts, Fx.banner, Fx.columns = {}, nil, {}
end

function Fx.add_shake(v)
  Fx.shake = math.min(10, Fx.shake + v)
end

function Fx.burst(x, y, color, n, speed, life, grav, size)
  for _ = 1, n do
    local ang = rnd(0, math.pi * 2)
    local sp = rnd(speed * 0.3, speed)
    Fx.particles[#Fx.particles + 1] = {
      x = x, y = y, vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
      life = rnd(life * 0.6, life), max = life, color = color, grav = grav or 0, size = size or 2,
    }
  end
end

function Fx.spray(x, y, dir, color, n, speed, life)
  for _ = 1, n do
    local ang = rnd(-0.5, 0.5)
    local sp = rnd(speed * 0.4, speed)
    Fx.particles[#Fx.particles + 1] = {
      x = x, y = y, vx = math.cos(ang) * sp * dir, vy = math.sin(ang) * sp,
      life = rnd(life * 0.6, life), max = life, color = color, grav = 0, size = 2,
    }
  end
end

local WHITE = { 1, 1, 1 }

-- ---------------------------------------------------------------------------
-- Feedback di gioco: hitstop, spinta della camera, schiacciamenti, lampi.
-- Tutto lato grafica: la simulazione non ne sa niente.

-- stato visivo per giocatore: sq = schiacciamento (+ largo, - alto),
-- recoil = rinculo dell'arma, white = lampo bianco, chip = vita "fantasma"
function Fx.pstate(id)
  local s = Fx.pl[id]
  if not s then
    s = { sq = 0, recoil = 0, white = 0, gy = true, vy = 0 }
    Fx.pl[id] = s
  end
  return s
end

function Fx.hitstop(n) Fx.freeze = math.max(Fx.freeze, n) end
function Fx.kick(x, y) Fx.kx, Fx.ky = Fx.kx + x, Fx.ky + y end

local function flash_at(x, y, r, color, life, star)
  Fx.flashes[#Fx.flashes + 1] = { x = x, y = y, r = r, color = color, life = life, max = life, star = star }
end

local function nearest(game, x, y)
  local best, bd = nil, 30 * 30
  for _, p in ipairs(game.players) do
    if p.alive then
      local dx, dy = p.x - x, p.y - y
      local d = dx * dx + dy * dy
      if d < bd then best, bd = p, d end
    end
  end
  return best
end

local MUZZLE = { sniper = 10, shotgun = 8, autoshotgun = 7, bazooka = 9, grenade = 6, blackhole = 8 }
local RECOIL = { sniper = 7, shotgun = 6, autoshotgun = 5, bazooka = 7, grenade = 4, blackhole = 5 }

function Fx.juice(e, game)
  local t = e.type
  if t == "hit" and not e.light then
    local d = e.dmg or 10
    -- fermo globale solo per i colpi pesanti: con le armi rapide sarebbe uno scatto continuo
    if d >= 20 then Fx.hitstop(math.min(7, 2 + math.floor(d / 15))) end
    local dir = (e.dir and e.dir ~= 0) and (e.dir > 0 and 1 or -1) or 0
    Fx.kick(dir * math.min(5, 1 + d / 10), -1)
    flash_at(e.x, e.y, 5 + math.min(10, d / 4), WHITE, 0.09, true)
    if dir ~= 0 then Fx.spray(e.x, e.y, dir, { 1, 1, 0.85 }, 5, 250 + d * 3, 0.16) end
    if e.id then
      local s = Fx.pstate(e.id)
      s.sq, s.white = 0.35, 0.09
    end
  elseif t == "parry" then
    Fx.hitstop(5); flash_at(e.x, e.y, 12, { 0.6, 1, 1 }, 0.12, true)
  elseif t == "perfect_parry" then
    Fx.hitstop(9); Fx.flash = 0.35; flash_at(e.x, e.y, 20, WHITE, 0.16, true)
  elseif t == "clash" then
    Fx.hitstop(6); flash_at(e.x, e.y, 16, { 1, 1, 0.6 }, 0.14, true)
  elseif t == "block" then
    Fx.hitstop(2)
  elseif t == "death" then
    Fx.hitstop(12); Fx.flash = 0.5
    local v = e.id and game.players[e.id]
    Fx.rings[#Fx.rings + 1] = { x = e.x, y = e.y, r = 48, life = 0.4, max = 0.4,
                                color = v and v.color or WHITE }
  elseif t == "explosion" then
    Fx.hitstop(3)
    if (e.radius or 40) >= 40 then Fx.flash = math.max(Fx.flash, 0.18) end
  elseif t == "shoot" then
    flash_at(e.x, e.y, MUZZLE[e.weapon] or 4, { 1, 0.95, 0.6 }, 0.06, false)
    if e.id then Fx.pstate(e.id).recoil = RECOIL[e.weapon] or 3 end
  elseif t == "jump" or t == "doublejump" or t == "walljump" then
    local p = nearest(game, e.x, e.y)
    if p then Fx.pstate(p.id).sq = -0.3 end
  elseif t == "dash" then
    local p = nearest(game, e.x, e.y + 8)
    if p then Fx.pstate(p.id).sq = 0.25 end
  elseif t == "pickup" then
    if e.id then Fx.pstate(e.id).white = 0.08 end
    flash_at(e.x, e.y, 10, { 1, 1, 0.7 }, 0.12, true)
  end
end

-- chiamata a ogni passo della simulazione: atterraggi, scie dello scatto, vita
function Fx.track(game)
  if game.phase == "countdown" and game.timer % 60 == 0 and game.timer > 0 then
    Audio.play("tick", game.timer <= 60 and 1.5 or 1.1, 0.8)
  end
  for _, p in ipairs(game.players) do
    local s = Fx.pstate(p.id)
    if p.alive then
      if p.grounded and not s.gy and s.vy > 200 then
        s.sq = math.min(0.4, s.vy / 1000)
        Fx.burst(p.x, p.y, { 0.75, 0.75, 0.8 }, 3 + math.floor(s.vy / 140), 70, 0.25, 40, 1)
      end
      s.gy, s.vy = p.grounded, p.vy
      if p.grounded then
        local before = s.dist or 0
        s.dist = before + math.abs(p.vx) / 60
        -- un passo ogni ~19 px percorsi (stesso ritmo delle gambe)
        if math.abs(p.vx) > 50 and math.floor(s.dist / 18.85) ~= math.floor(before / 18.85) then
          Fx.burst(p.x - p.vx * 0.02, p.y - 1, { 0.75, 0.72, 0.7 }, 2, 25, 0.25, -30, 1)
        end
        -- sgommata: si corre in un verso guardando nell'altro (inversione di marcia)
        if math.abs(p.vx) > 70 and p.facing * p.vx < 0 and game.frame % 3 == 0 then
          Fx.spray(p.x, p.y - 1, p.vx > 0 and 1 or -1, { 0.85, 0.8, 0.75 }, 2, 90, 0.2)
        end
      end
      if p.sliding and game.frame % 4 == 0 then
        Fx.burst(p.x + p.wall * 5, p.y - 16, { 1, 0.85, 0.5 }, 1, 30, 0.2, 200, 1)
      end
      if p.action and p.action.type == "dash" and game.frame % 2 == 0 then
        Fx.ghosts[#Fx.ghosts + 1] = { x = p.x, y = p.y, color = p.color, life = 0.18, max = 0.18 }
      end
    end
    s.hp = p.hp
    if not s.chip or p.hp > s.chip then s.chip, s.chip_wait = p.hp, 0 end
    if p.hp < (s.last_hp or p.hp) then s.chip_wait = 0.35 end
    s.last_hp = p.hp
  end
end

function Fx.draw_under()
  for _, g in ipairs(Fx.ghosts) do
    love.graphics.setColor(g.color[1], g.color[2], g.color[3], 0.4 * g.life / g.max)
    love.graphics.rectangle("fill", math.floor(g.x) - 5, math.floor(g.y) - 20, 10, 20)
  end
end

function Fx.draw_screen(W, H)
  if Fx.flash > 0 then
    love.graphics.setColor(1, 1, 1, Fx.flash * 0.45 * (Fx.flash_mul or 1))
    love.graphics.rectangle("fill", 0, 0, W, H)
  end
end

function Fx.handle(e, game)
  Fx.juice(e, game)
  local t = e.type
  local victim = e.id and game.players[e.id]
  local color = victim and victim.color or WHITE
  if t == "hit" and e.light then
    -- colpi leggeri (fiamme, fuoco, nucleo del buco nero): effetto piccolo, niente scossa
    Fx.burst(e.x, e.y, color, 2, 60, 0.25, 100)
  elseif t == "hit" then
    Fx.burst(e.x, e.y, color, 8 + math.floor(e.dmg / 4), 140 + e.dmg * 2, 0.4, 300)
    Fx.burst(e.x, e.y, WHITE, 4, 120, 0.2, 0)
    Fx.add_shake(math.min(5, 1 + e.dmg / 12))
    Audio.play("hit", 1.3 - math.min(0.6, e.dmg / 80))
  elseif t == "parry" then
    Fx.burst(e.x, e.y, { 0.5, 0.95, 1 }, 14, 200, 0.3, 0)
    Fx.add_shake(3)
    Audio.play("parry")
  elseif t == "perfect_parry" then
    Fx.burst(e.x, e.y, { 1, 1, 1 }, 20, 260, 0.35, 0)
    Fx.add_shake(5)
    Audio.play("parry", 1.3)
  elseif t == "guardbreak" then
    Fx.burst(e.x, e.y, { 1, 0.6, 0.2 }, 10, 180, 0.3, 0)
    Audio.play("clash", 0.7)
  elseif t == "clash" then
    Fx.burst(e.x, e.y, { 1, 1, 0.6 }, 16, 220, 0.3, 0)
    Fx.add_shake(3)
    Audio.play("clash")
  elseif t == "counter" then
    Fx.burst(e.x, e.y, { 1, 0.9, 0.4 }, 8, 160, 0.25, 0)
  elseif t == "death" then
    Fx.burst(e.x, e.y, color, 32, 230, 0.8, 350, 3)
    Fx.burst(e.x, e.y, WHITE, 10, 160, 0.4, 0)
    Fx.add_shake(7)
    Audio.play("death")
  elseif t == "shoot" then
    Fx.burst(e.x, e.y, { 1, 0.9, 0.5 }, 5, 120, 0.12, 0)
    Fx.add_shake(1)
    if e.weapon == "sniper" then
      Fx.burst(e.x, e.y, { 0.7, 0.9, 1 }, 10, 200, 0.2, 0)
      Fx.add_shake(4)
      Audio.play("sniper")
    else
      local pitch = ({ shotgun = 0.6, autoshotgun = 0.65, smg = 1.4, assault = 1.15, grenade = 0.5,
                       bazooka = 0.35, swarm = 0.8, blackhole = 0.3, ghost = 1.7, bubble = 2.0,
                       gust = 0.45, flamer = 0.3, boomerang = 1.2, hook = 1.5, mines = 0.7 })[e.weapon] or 1.0
      local vol = ({ smg = 0.5, assault = 0.6, flamer = 0.15, bubble = 0.5 })[e.weapon] or 0.8
      Audio.play("shoot", pitch, vol)
    end
  elseif t == "throw" then
    Audio.play("dash", 0.8)
  elseif t == "ignite" then
    Fx.burst(e.x, e.y, { 1, 0.6, 0.15 }, 12, 90, 0.4, -120)
    Audio.play("shoot", 0.4, 0.4)
  elseif t == "bubbled" then
    Fx.burst(e.x, e.y, { 0.7, 0.9, 1 }, 10, 70, 0.4, -40)
    Audio.play("pickup", 1.6, 0.6)
  elseif t == "pop" then
    Fx.burst(e.x, e.y, { 0.8, 0.95, 1 }, 16, 160, 0.3, 0, 1)
    Audio.play("pickup", 2.0, 0.7)
  elseif t == "block" then
    Fx.burst(e.x, e.y, { 0.85, 0.9, 1 }, 10, 140, 0.2, 0)
    Fx.add_shake(2)
    Audio.play("clash", 1.3, 0.7)
  elseif t == "catch" then
    Audio.play("pickup", 0.8, 0.5)
  elseif t == "grapple" then
    Fx.burst(e.x, e.y, { 0.85, 0.85, 0.9 }, 6, 80, 0.2, 0)
    Audio.play("clash", 1.6, 0.5)
  elseif t == "mine_set" then
    Audio.play("tick", 0.8, 0.6)
  elseif t == "mine_armed" then
    Fx.burst(e.x, e.y, { 1, 0.3, 0.2 }, 4, 40, 0.2, 0)
    Audio.play("tick", 1.4, 0.6)
  elseif t == "blackhole" then
    Fx.burst(e.x, e.y, { 0.6, 0.35, 1 }, 30, 260, 0.5, 0, 2)
    Fx.add_shake(6)
    Audio.play("explosion", 0.5)
  elseif t == "bounce" then
    Fx.burst(e.x, e.y, { 1, 0.95, 0.6 }, 5, 110, 0.15, 0, 1)
    Audio.play("ricochet", 0.9 + love.math.random() * 0.3, 0.5)
  elseif t == "explosion" then
    local r = e.radius or 40
    Fx.burst(e.x, e.y, { 1, 0.55, 0.15 }, 30, r * 5, 0.5, 120, 3)
    Fx.burst(e.x, e.y, { 1, 0.9, 0.4 }, 16, r * 3, 0.3, 0, 2)
    Fx.burst(e.x, e.y, { 0.35, 0.33, 0.33 }, 14, r * 2, 0.9, -40, 3)
    Fx.rings[#Fx.rings + 1] = { x = e.x, y = e.y, r = r, life = 0.25, max = 0.25 }
    Fx.add_shake(8)
    Audio.play("explosion")
  elseif t == "impact" then
    Fx.burst(e.x, e.y, { 1, 0.85, 0.5 }, 4, 90, 0.15, 0)
  elseif t == "pickup" then
    Audio.play("pickup")
  elseif t == "jump" then
    Fx.burst(e.x, e.y, { 0.8, 0.8, 0.9 }, 3, 40, 0.2, 60, 1)
    Audio.play("jump")
  elseif t == "slide" then
    Fx.burst(e.x, e.y, { 0.7, 0.7, 0.75 }, 1, 25, 0.25, -20, 1)
  elseif t == "doublejump" then
    Fx.burst(e.x, e.y, { 0.9, 0.95, 1 }, 6, 70, 0.25, 0, 1)
    Audio.play("jump")
  elseif t == "walljump" then
    Fx.burst(e.x, e.y, { 0.8, 0.8, 0.9 }, 5, 60, 0.25, 60, 1)
    Audio.play("jump")
  elseif t == "dash" then
    local p = game.players[1]
    Fx.burst(e.x, e.y, { 0.9, 0.9, 1 }, 5, 60, 0.2, 0, 1)
    Audio.play("dash")
  elseif t == "break" then
    Fx.burst(e.x, e.y, { 0.8, 0.8, 0.8 }, 10, 120, 0.4, 300)
    Audio.play("break_")
  elseif t == "telegraph" then
    Audio.play("telegraph", e.crate and 0.7 or 1)
  elseif t == "item_spawn" then
    Fx.burst(e.x, e.y, { 1, 1, 0.7 }, 8, 80, 0.3, 0)
    Audio.play("spawn")
  elseif t == "map_event" then
    local names = { rocks = "FRANA!", barrels = "BARILI IN ARRIVO!", lightning = "TEMPESTA!",
                    press = "PRESSE!", geyser = "GEYSER DI FUOCO!",
                    wind = (e.dir or 1) > 0 and "VENTO  >>>" or "<<<  VENTO" }
    local text = names[e.kind] or "ATTENZIONE!"
    if Fx.banner and Fx.banner.t > 1.55 then text = "ONDATA!  " .. Fx.banner.text .. " + " .. text end
    Fx.banner = { text = text, t = 1.6 }
    Audio.play("telegraph", 0.6)
    Audio.play("telegraph", 0.45, 0.6)
  elseif t == "lightning" then
    Fx.bolts[#Fx.bolts + 1] = { x = e.x, y1 = e.y1 or 0, y2 = e.y, life = 0.22, max = 0.22 }
    Fx.burst(e.x, e.y, { 0.8, 0.9, 1 }, 18, 200, 0.35, 200, 2)
    Fx.flash = math.max(Fx.flash, 0.3)
    Fx.add_shake(6)
    Fx.hitstop(3)
    Audio.play("explosion", 1.6)
    Audio.play("sniper", 1.8, 0.7)
  elseif t == "press" then
    Fx.columns[#Fx.columns + 1] = { kind = "press", x = e.x, y1 = e.y1 or 0, y2 = e.y, w = e.width or 40, life = 0.6, max = 0.6 }
    Fx.burst(e.x - (e.width or 40) / 2, e.y, { 0.8, 0.8, 0.75 }, 10, 160, 0.4, 300, 2)
    Fx.burst(e.x + (e.width or 40) / 2, e.y, { 0.8, 0.8, 0.75 }, 10, 160, 0.4, 300, 2)
    Fx.add_shake(8); Fx.hitstop(4)
    Audio.play("break_", 0.4); Audio.play("explosion", 0.7, 0.6)
  elseif t == "geyser" then
    Fx.columns[#Fx.columns + 1] = { kind = "geyser", x = e.x, y1 = e.y1 or 0, y2 = e.y, w = e.width or 14, life = 0.8, max = 0.8 }
    Fx.burst(e.x, e.y, { 1, 0.6, 0.15 }, 20, 220, 0.5, -200, 2)
    Fx.add_shake(4)
    Audio.play("explosion", 1.3, 0.7); Audio.play("shoot", 0.3, 0.6)
  elseif t == "wind_start" then
    Audio.play("dash", 0.4); Audio.play("telegraph", 0.35, 0.5)
  elseif t == "spring" then
    Fx.burst(e.x, e.y - 4, { 1, 0.8, 0.6 }, 6, 90, 0.25, 0, 1)
    Audio.play("jump", 1.8); Audio.play("ricochet", 0.6, 0.4)
  elseif t == "portal" then
    local c = { 0.5, 0.85, 1 }
    Fx.burst(e.x, e.y, c, e.small and 4 or 12, 110, 0.3, 0, 1)
    Fx.burst(e.tx, e.ty, c, e.small and 4 or 12, 110, 0.3, 0, 1)
    if not e.small then Audio.play("pickup", 0.6, 0.6); Audio.play("telegraph", 1.8, 0.4) end
  elseif t == "blocks_broken" then
    for _, b in ipairs(e.list or {}) do
      Fx.burst(b.x, b.y, { 0.55, 0.42, 0.3 }, 6, 150, 0.6, 500, 2)
    end
    Audio.play("break_", 0.8)
  elseif t == "rock" then
    Fx.burst(e.x, e.y, { 0.55, 0.5, 0.45 }, 14, 150, 0.5, 400, 2)
    Fx.burst(e.x, e.y, { 0.7, 0.68, 0.65 }, 8, 60, 0.7, -30, 3)
    Fx.add_shake(4)
    Audio.play("break_", 0.6)
  elseif t == "round_start" then
    Audio.play("round_start")
  elseif t == "round_end" then
    Audio.play("round_end")
  end
end

function Fx.update(dt)
  for i = #Fx.particles, 1, -1 do
    local p = Fx.particles[i]
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(Fx.particles, i)
    else
      p.vy = p.vy + p.grav * dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
    end
  end
  for i = #Fx.rings, 1, -1 do
    local r = Fx.rings[i]
    r.life = r.life - dt
    if r.life <= 0 then table.remove(Fx.rings, i) end
  end
  if Fx.banner then
    Fx.banner.t = Fx.banner.t - dt
    if Fx.banner.t <= 0 then Fx.banner = nil end
  end
  for _, list in ipairs({ Fx.flashes, Fx.ghosts, Fx.bolts, Fx.columns }) do
    for i = #list, 1, -1 do
      local f = list[i]
      f.life = f.life - dt
      if f.life <= 0 then table.remove(list, i) end
    end
  end
  local k = math.exp(-dt * 18)
  Fx.kx, Fx.ky = Fx.kx * k, Fx.ky * k
  Fx.flash = math.max(0, Fx.flash - dt * 2.5)
  local ks, kr = math.exp(-dt * 12), math.exp(-dt * 20)
  for _, s in pairs(Fx.pl) do
    s.sq, s.recoil, s.white = s.sq * ks, s.recoil * kr, math.max(0, s.white - dt)
    if s.chip and s.hp and s.chip > s.hp then
      if (s.chip_wait or 0) > 0 then s.chip_wait = s.chip_wait - dt
      else s.chip = math.max(s.hp, s.chip - dt * 80) end
    end
  end
  Fx.shake = math.max(0, Fx.shake - 28 * dt)
end

function Fx.offset()
  local sx, sy = 0, 0
  if Fx.shake > 0.05 then sx, sy = rnd(-Fx.shake, Fx.shake), rnd(-Fx.shake, Fx.shake) end
  local m = Fx.shake_mul or 1
  return math.floor((sx + Fx.kx) * m + 0.5), math.floor((sy + Fx.ky) * m + 0.5)
end

function Fx.draw()
  for _, r in ipairs(Fx.rings) do
    local k = 1 - r.life / r.max
    local c = r.color or { 1, 0.8, 0.4 }
    love.graphics.setColor(c[1], c[2], c[3], 0.6 * (1 - k))
    love.graphics.circle("fill", r.x, r.y, r.r * (0.4 + 0.6 * k))
    love.graphics.setColor(1, 1, 0.8, 0.9 * (1 - k))
    love.graphics.circle("line", r.x, r.y, r.r * (0.5 + 0.5 * k))
  end
  for _, p in ipairs(Fx.particles) do
    local a = math.min(1, p.life / (p.max * 0.5))
    love.graphics.setColor(p.color[1], p.color[2], p.color[3], a)
    love.graphics.rectangle("fill", math.floor(p.x), math.floor(p.y), p.size, p.size)
  end
  -- presse e geyser
  for _, c in ipairs(Fx.columns) do
    local k = 1 - c.life / c.max
    local x1 = c.x - c.w / 2
    if c.kind == "press" then
      -- il pistone scende di colpo e risale piano
      local down = k < 0.15 and k / 0.15 or 1 - (k - 0.15) / 0.85
      local bottom = c.y1 + (c.y2 - c.y1) * down
      love.graphics.setColor(0.25, 0.26, 0.28); love.graphics.rectangle("fill", c.x - 4, c.y1, 8, bottom - c.y1)
      love.graphics.setColor(0.08, 0.08, 0.09); love.graphics.rectangle("fill", x1 - 1, bottom - 13, c.w + 2, 14)
      love.graphics.setColor(0.55, 0.57, 0.6); love.graphics.rectangle("fill", x1, bottom - 12, c.w, 12)
      love.graphics.setColor(0.95, 0.75, 0.15)
      for xx = 0, c.w - 6, 8 do love.graphics.rectangle("fill", x1 + xx, bottom - 4, 4, 3) end
    else
      local h = (c.y2 - c.y1) * math.min(1, k * 4)
      love.graphics.setBlendMode("add")
      for j = 0, 3 do
        love.graphics.setColor(1, 0.5 - j * 0.1, 0.1, (0.5 - j * 0.1) * (1 - k))
        local ww = c.w * (1 - j * 0.2) + math.sin((k * 30) + j) * 2
        love.graphics.rectangle("fill", c.x - ww / 2, c.y2 - h, ww, h)
      end
      love.graphics.setColor(1, 0.95, 0.6, 0.8 * (1 - k))
      love.graphics.rectangle("fill", c.x - 2, c.y2 - h, 4, h)
      love.graphics.setBlendMode("alpha")
    end
  end
  -- fulmini: linea spezzata che cambia forma a ogni frame
  for _, b in ipairs(Fx.bolts) do
    local k = b.life / b.max
    love.graphics.setBlendMode("add")
    for pass = 1, 2 do
      local pts, y, x = {}, b.y1, b.x
      while y < b.y2 do
        pts[#pts + 1] = x; pts[#pts + 1] = y
        y = math.min(b.y2, y + 10 + love.math.random() * 10)
        x = b.x + (love.math.random() - 0.5) * 14
      end
      pts[#pts + 1] = b.x; pts[#pts + 1] = b.y2
      if #pts >= 4 then
        love.graphics.setLineWidth(pass == 1 and 6 or 2)
        love.graphics.setColor(pass == 1 and 0.4 or 1, pass == 1 and 0.6 or 1, 1, (pass == 1 and 0.4 or 1) * k)
        love.graphics.line(pts)
      end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setBlendMode("alpha")
  end
  for _, f in ipairs(Fx.flashes) do
    local k = f.life / f.max
    love.graphics.setColor(f.color[1], f.color[2], f.color[3], k)
    if f.star then
      local r, d = f.r * (1.3 - 0.3 * k), f.r * 0.55
      love.graphics.setLineWidth(2)
      love.graphics.line(f.x - r, f.y, f.x + r, f.y)
      love.graphics.line(f.x, f.y - r, f.x, f.y + r)
      love.graphics.setLineWidth(1)
      love.graphics.line(f.x - d, f.y - d, f.x + d, f.y + d)
      love.graphics.line(f.x - d, f.y + d, f.x + d, f.y - d)
      love.graphics.circle("fill", f.x, f.y, f.r * 0.35 * k)
    else
      love.graphics.circle("fill", f.x, f.y, f.r * k)
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return Fx
