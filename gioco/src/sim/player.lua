-- Stato e aggiornamento di un giocatore. Nessuna dipendenza da LÖVE.
-- Il combattimento vero e proprio (colpi, parry, clash) sta in combat.lua.
local data = require("src.sim.data")
local Combat = require("src.sim.combat")

local Player = {}

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local abs, min, max, floor, sqrt = math.abs, math.min, math.max, math.floor, math.sqrt

local BUF_KEYS = { "jump", "attack", "dash", "parry", "pickup" }

function Player.new(id, spawn, color)
  local P = data.player
  local p = {
    id = id, color = color,
    x = spawn.x, y = spawn.y, vx = 0, vy = 0,
    w = P.w, h = P.h,
    facing = spawn.facing or 1,
    hp = P.hp, alive = true,
    grounded = false, coyote = 0, jump_cut_done = true,
    air_jumps = P.air_jumps, wall = 0, wall_t = 0, wall_dir = 0, wall_lock = 0, sliding = false,
    drop_timer = 0, dash_cd = 0, invuln = 0, freeze = 0, hitstun = 0,
    clash = 0, clash_partner = nil, clash_winner = false, counter = false,
    buf = { jump = 0, attack = 0, dash = 0, parry = 0, pickup = 0 },
    action = nil,
    weapon = nil,
    momentum = 0, mom_timer = 0,
    aimx = 1, aimy = 0, aim_free = false,
    spike_cd = 0, parry_flash = 0,
    last_hit_by = nil, last_hit_frame = -999, death_frame = nil, death_cause = nil,
    burn = 0, burn_by = nil,     -- fuoco (lanciafiamme)
    bubble = 0,                  -- chiuso in una bolla (pistola a bolle)
    grapple = nil,               -- trainato dal rampino verso un punto
  }
  return p
end

function Player.weapon_def(p)
  if p.weapon then return data.weapons[p.weapon.id] end
  return data.weapons.fists
end

function Player.tier(p)
  local M = data.momentum
  if p.momentum >= M.tier2 then return 2 end
  if p.momentum >= M.tier1 then return 1 end
  return 0
end

function Player.gain_momentum(p, n)
  local M = data.momentum
  p.momentum = min(M.max, p.momentum + n)
  p.mom_timer = 0
end

function Player.lose_momentum(p, n)
  p.momentum = max(0, p.momentum - n)
end

function Player.box(p)
  return p.x - p.w / 2, p.y - p.h, p.x + p.w / 2, p.y
end

local function sign(v)
  if v > 0 then return 1 elseif v < 0 then return -1 end
  return 0
end

local function approach(v, target, delta)
  if v < target then return min(v + delta, target) end
  return max(v - delta, target)
end

-- Direzione di mira.
-- Con la levetta destra (inp.ax, inp.ay) la mira e' libera a 360 gradi.
-- Senza levetta destra (tastiera, o levetta a riposo) si mira a 8 direzioni con la
-- levetta sinistra, e senza input si punta nella direzione in cui si guarda.
-- Ritorna ax, ay (vettore unitario) e true se la mira e' libera.
local function compute_aim(p, inp)
  local rx, ry = inp.ax or 0, inp.ay or 0
  local rlen = sqrt(rx * rx + ry * ry)
  if rlen >= data.player.aim_deadzone then
    return rx / rlen, ry / rlen, true
  end
  local mx, my = inp.mx or 0, inp.my or 0
  if abs(mx) < 0.35 and abs(my) < 0.35 then return p.facing, 0, false end
  local step = floor(atan2(my, mx) / (math.pi / 4) + 0.5) * (math.pi / 4)
  local ax, ay = math.cos(step), math.sin(step)
  if abs(ax) < 1e-6 then ax = 0 end
  if abs(ay) < 1e-6 then ay = 0 end
  return ax, ay, false
end

local function start_attack(p, game)
  local def = Player.weapon_def(p)
  p.buf.attack = 0
  -- boomerang o rampino ancora in volo: non si puo' sparare di nuovo
  if p.weapon and p.weapon.out then return end
  if def.kind == "ranged" and p.weapon.ammo <= 0 then
    Combat.throw_weapon(game, p)
    return
  end
  local tier = Player.tier(p)
  local M = data.momentum
  local mul = (p.weapon and p.weapon.dmg_mul or 1)
  local kmul = 1
  if tier >= 2 then mul = mul * (1 + M.dmg_bonus); kmul = 1 + M.knock_bonus end
  local startup = def.startup
  if p.counter then
    mul = mul * data.player.counter_mul
    startup = 1
    p.counter = false
    p.vx = p.facing * data.player.counter_lunge   -- scatta verso l'avversario
  end
  if def.kind == "melee" and p.weapon and not def.no_wear then p.weapon.uses = p.weapon.uses - 1 end
  p.action = { type = "attack", def = def, weapon = p.weapon, frame = 0, hit = {},
               mul = mul, kmul = kmul, startup = startup, fired = false }
end

local function advance_attack(p, game)
  local a = p.action
  local def = a.def
  a.frame = a.frame + 1
  local startup = a.startup
  if a.frame <= startup then
    a.phase = "startup"
  elseif a.frame <= startup + def.active then
    if a.phase ~= "active" and def.lunge then
      p.vx = p.facing * def.lunge   -- affondo (lancia) o scatto-fendente (katana)
      if def.lunge_invuln then p.invuln = max(p.invuln, def.active + 2) end
    end
    a.phase = "active"
    if def.kind == "melee" then
      Combat.melee_check(game, p, a)
    elseif not a.fired then
      a.fired = true
      Combat.fire(game, p, a)
    end
  else
    a.phase = "recovery"
  end
  if a.frame >= startup + def.active + def.recovery then
    p.action = nil
    if def.kind == "melee" and a.weapon and a.weapon.uses and a.weapon.uses <= 0
       and p.weapon == a.weapon then
      game:emit("break", p.x, p.y - 12, { weapon = a.weapon.id })
      p.weapon = nil
    end
  end
end

local function advance_parry(p, game)
  local P = data.player
  local a = p.action
  a.frame = a.frame + 1
  a.active = a.frame > P.parry_startup and a.frame <= P.parry_startup + P.parry_active
  a.whiff = a.frame > P.parry_startup + P.parry_active
  if a.frame >= P.parry_startup + P.parry_active + P.parry_whiff_recovery then
    p.action = nil
  end
end

local function try_dash(p, inp, game)
  local P = data.player
  if p.buf.dash <= 0 or p.dash_cd > 0 then return false end
  local a = p.action
  local cancelling = false
  if a then
    if a.type == "attack" and a.phase == "recovery" then
      cancelling = true
    else
      return false
    end
  end
  local dir = abs(inp.mx or 0) > 0.3 and sign(inp.mx) or p.facing
  p.facing = dir
  p.action = { type = "dash", frame = 0, dir = dir }
  p.dash_cd = cancelling and P.dash_cancel_cooldown or P.dash_cooldown
  p.invuln = max(p.invuln, P.dash_invuln)
  p.buf.dash = 0
  game:emit("dash", p.x, p.y - 8, { dir = dir })
  return true
end

local function try_parry(p)
  if p.buf.parry <= 0 or p.action then return false end
  p.action = { type = "parry", frame = 0, active = false, whiff = false }
  p.buf.parry = 0
  return true
end

local function try_attack(p, game, inp)
  if p.action then return false end
  local def = Player.weapon_def(p)
  -- armi automatiche: basta tenere premuto
  local auto = def.auto and p.weapon and inp.attack_held
  if p.buf.attack <= 0 and not auto then return false end
  start_attack(p, game)
  return true
end

local function apply_movement(p, inp)
  local P = data.player
  local M = data.momentum
  local a = p.action
  local mult = 1
  if Player.tier(p) >= 1 then mult = mult + M.speed_bonus end
  local target = (inp.mx or 0) * P.run_speed * mult
  if abs(inp.mx or 0) < 0.2 then target = 0 end
  if a and a.type == "attack" then
    -- la katana conserva lo slancio dello scatto finche' il colpo e' attivo
    if a.def.keep_momentum and a.phase == "active" then return end
    target = target * a.def.move_mult
  end
  if a and a.type == "parry" then target = 0 end
  local accel
  local reversing = (target == 0) or (p.vx ~= 0 and sign(target) ~= sign(p.vx))
  if p.grounded then
    accel = reversing and P.decel_ground or P.accel_ground
  else
    accel = reversing and P.decel_air or P.accel_air
  end
  p.vx = approach(p.vx, target, accel * data.dt)
end

function Player.update(p, inp, game)
  if not p.alive then return end
  local P = data.player
  local dt = data.dt
  local world = game.world
  inp = inp or {}

  -- buffer degli input
  for _, k in ipairs(BUF_KEYS) do
    if inp[k .. "_pressed"] then
      p.buf[k] = P.buffer
    elseif p.buf[k] > 0 then
      p.buf[k] = p.buf[k] - 1
    end
  end

  -- fuoco: danno a intervalli finche' dura
  if p.burn > 0 then
    p.burn = p.burn - 1
    if p.burn % P.burn_every == 0 then
      Combat.dot(game, p, P.burn_dmg, p.burn_by, "fuoco")
      if not p.alive then return end
    end
  end

  if p.freeze > 0 then
    p.freeze = p.freeze - 1
    return
  end

  -- bolla: si galleggia verso l'alto senza poter agire; premere tasti libera prima
  if p.bubble > 0 then
    p.bubble = p.bubble - 1
    for _, k in ipairs(BUF_KEYS) do
      if inp[k .. "_pressed"] then p.bubble = max(0, p.bubble - P.bubble_mash) end
    end
    p.action, p.grapple = nil, nil
    p.vx = p.vx * 0.9 + (inp.mx or 0) * 6
    p.vy = -P.bubble_rise
    local world = game.world
    if world:move_x(p, p.vx * dt) then p.vx = -p.vx * 0.5 end
    local _, bumped = world:move_y(p, p.vy * dt, true)
    p.grounded = false
    if p.bubble == 0 then
      p.vy = 0
      game:emit("pop", p.x, p.y - 10, { id = p.id })
    end
    return
  end

  -- timer
  if p.dash_cd > 0 then p.dash_cd = p.dash_cd - 1 end
  if p.invuln > 0 then p.invuln = p.invuln - 1 end
  if p.drop_timer > 0 then p.drop_timer = p.drop_timer - 1 end
  if p.spike_cd > 0 then p.spike_cd = p.spike_cd - 1 end
  if p.parry_flash > 0 then p.parry_flash = p.parry_flash - 1 end
  p.mom_timer = p.mom_timer + 1
  if p.mom_timer > data.momentum.decay_delay and p.momentum > 0 then
    p.momentum = max(0, p.momentum - data.momentum.decay_rate * dt)
  end

  p.aimx, p.aimy, p.aim_free = compute_aim(p, inp)
  local mx = inp.mx or 0
  local stunned = p.hitstun > 0

  -- contatto con una parete (solo muri pieni)
  p.wall = 0
  if not p.grounded and not stunned then
    local hw = p.w / 2 + 1
    local function solid(x, y) return world:tile_at(x, y) == "#" end
    if solid(p.x + hw, p.y - 4) and solid(p.x + hw, p.y - p.h + 4) then p.wall = 1
    elseif solid(p.x - hw, p.y - 4) and solid(p.x - hw, p.y - p.h + 4) then p.wall = -1 end
  end
  if p.wall ~= 0 then p.wall_t, p.wall_dir = P.wall_coyote, p.wall
  elseif p.wall_t > 0 then p.wall_t = p.wall_t - 1 end
  if p.wall_lock > 0 then p.wall_lock = p.wall_lock - 1 end
  if p.wall ~= 0 and p.vy > 0 and not (p.action and p.action.type == "dash") then
    if mx * p.wall < -0.3 then p.wall_release = (p.wall_release or 0) + 1 else p.wall_release = 0 end
    p.sliding = p.wall_release < P.wall_release
  else
    p.sliding, p.wall_release = false, 0
  end
  if p.sliding then p.wall_grab = (p.wall_grab or 0) + 1 else p.wall_grab = 0 end
  if p.sliding and game.frame % 5 == 0 then game:emit("slide", p.x + p.wall * p.w / 2, p.y - 4) end

  if stunned then
    p.hitstun = p.hitstun - 1
    p.vx = p.vx * (p.grounded and 0.9 or 0.985)
  elseif p.clash > 0 then
    p.clash = p.clash - 1
    p.vx = p.vx * 0.85
    if not p.clash_winner then
      local partner = game.players[p.clash_partner]
      local taken = partner and partner.clash_winner
      if not taken then
        if p.buf.attack > 0 then
          p.clash_winner = true
          p.counter = true
          p.clash = 0
          game:emit("counter", p.x, p.y - 12)
        elseif p.buf.dash > 0 then
          p.clash_winner = true
          p.clash = 0
        end
      end
    end
  else
    -- avanzamento dell'azione corrente
    local a = p.action
    if a then
      if a.type == "attack" then
        advance_attack(p, game)
      elseif a.type == "parry" then
        advance_parry(p, game)
      elseif a.type == "dash" then
        a.frame = a.frame + 1
        if a.frame >= P.dash_frames then
          p.action = nil
          p.vx = p.vx * 0.5
        end
      end
    end

    -- nuove azioni
    if not try_dash(p, inp, game) then
      if not try_parry(p) then
        try_attack(p, game, inp)
      end
    end

    -- direzione del personaggio
    local a2 = p.action
    local can_turn = not a2 or a2.type == "parry" or (a2.type == "attack" and a2.phase ~= "active")
    if can_turn then
      -- con la mira libera il personaggio guarda dove mira (si puo' indietreggiare sparando)
      if p.aim_free and abs(p.aimx) > 0.2 then
        p.facing = sign(p.aimx)
      elseif abs(mx) > 0.35 then
        p.facing = sign(mx)
      end
    end

    -- rampino: il traino sostituisce corsa e gravita'; il salto lo interrompe
    local g = p.grapple
    if g then
      local dx, dy = g.x - p.x, g.y - p.y
      local d = math.sqrt(dx * dx + dy * dy)
      g.t = g.t - 1
      if p.buf.jump > 0 or d < 14 or g.t <= 0 then
        p.grapple = nil
        p.vx, p.vy = p.vx * 0.6, p.vy * 0.6
        p.air_jumps = P.air_jumps
      else
        p.vx, p.vy = dx / d * P.grapple_speed, dy / d * P.grapple_speed
      end
    end

    -- movimento orizzontale
    if p.grapple then
      -- gia' impostato dal traino
    elseif p.action and p.action.type == "dash" then
      p.vx = p.action.dir * P.dash_speed
    elseif p.wall_lock > 0 then
      -- dopo il salto dal muro il controllo torna un po' alla volta
      local keep = p.vx
      apply_movement(p, inp)
      local k = p.wall_lock / (p.wall_lock_max or P.wall_lock)
      p.vx = keep * k + p.vx * (1 - k)
    else
      apply_movement(p, inp)
      -- agganciati al muro non ci si allontana finche' non ci si stacca
      if p.sliding and p.vx * p.wall < 0 then p.vx = 0 end
    end

    -- salto e discesa dalle piattaforme
    if p.buf.jump > 0 then
      if (inp.my or 0) > 0.6 and p.grounded and world:standing_on_oneway(p) then
        p.drop_timer = P.drop_frames
        p.buf.jump = 0
      elseif p.coyote > 0 and not (p.action and p.action.type == "dash") then
        p.vy = -P.jump_vel
        p.coyote = 0
        p.grounded = false
        p.buf.jump = 0
        p.jump_cut_done = false
        game:emit("jump", p.x, p.y)
      elseif p.wall_t > 0 and not p.grounded and not (p.action and p.action.type == "dash") then
        -- salto dalla parete: spinge via dal muro e restituisce il doppio salto
        local away = mx * p.wall_dir < -0.3
        p.vy = -P.wall_jump_vy
        p.vx = -p.wall_dir * (away and P.wall_jump_vx_away or P.wall_jump_vx)
        p.facing = -p.wall_dir
        p.wall_lock = away and P.wall_lock_away or P.wall_lock
        p.wall_lock_max = p.wall_lock
        p.sliding = false
        p.wall_t = 0
        p.air_jumps = P.air_jumps
        p.buf.jump = 0
        p.jump_cut_done = false
        game:emit("walljump", p.x + p.wall_dir * p.w / 2, p.y - p.h / 2)
      elseif p.air_jumps > 0 and not p.grounded and not (p.action and p.action.type == "dash") then
        p.vy = -P.double_jump_vel
        p.air_jumps = p.air_jumps - 1
        p.buf.jump = 0
        p.jump_cut_done = false
        game:emit("doublejump", p.x, p.y)
      end
    end
    if not inp.jump_held and p.vy < 0 and not p.jump_cut_done then
      p.vy = p.vy * P.jump_cut
      p.jump_cut_done = true
    end
  end

  -- gravita'
  if p.grapple then
    -- niente gravita' durante il traino
  elseif not (p.action and p.action.type == "dash" and not stunned) then
    local gm = 1
    if p.vy > 0 then gm = P.fall_gravity_mul
    elseif inp.jump_held and abs(p.vy) < P.apex_speed then gm = P.apex_gravity_mul end
    p.vy = min(p.vy + P.gravity * gm * dt, P.max_fall)
    if p.sliding then
      -- presa: i primi frame si scivola piano, poi alla velocita' normale; frenata morbida
      local cap = p.wall_grab < P.wall_grab_frames and P.wall_slide_speed * 0.3 or P.wall_slide_speed
      if p.vy > cap then p.vy = max(cap, p.vy - P.wall_brake * dt) end
    end
  else
    p.vy = 0
  end

  -- movimento e collisioni
  local hit_wall = world:move_x(p, p.vx * dt)
  if hit_wall then p.vx = (stunned and -p.vx * 0.3) or 0 end
  local landed, bumped = world:move_y(p, p.vy * dt, p.drop_timer > 0)
  if landed then
    p.vy = 0
    p.grounded = true
    p.coyote = P.coyote
    p.jump_cut_done = true
    p.air_jumps = P.air_jumps
  else
    p.grounded = false
    if p.coyote > 0 then p.coyote = p.coyote - 1 end
    if bumped then p.vy = 0 end
  end
end

return Player
