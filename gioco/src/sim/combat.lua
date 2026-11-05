-- Regole del combattimento: colpi, parry (Deflect), clash, proiettili, lancio, morte.
-- Riceve sempre il gioco `game` (vedi game.lua) per leggere giocatori ed emettere eventi.
local data = require("src.sim.data")

local Combat = {}

local abs, min, max, sqrt = math.abs, math.min, math.max, math.sqrt

local function overlap(a1, b1, a2, b2, c1, d1, c2, d2)
  return a1 < c2 and a2 > c1 and b1 < d2 and b2 > d1
end
Combat.overlap = overlap

local function sign(v)
  if v > 0 then return 1 elseif v < 0 then return -1 end
  return 0
end

-- Rettangolo del colpo in mischia davanti al personaggio
function Combat.melee_rect(p, def)
  local hb = def.hit
  local x1, x2
  if p.facing > 0 then
    x1 = p.x + p.w / 2 + hb.ox
    x2 = x1 + hb.w
  else
    x2 = p.x - p.w / 2 - hb.ox
    x1 = x2 - hb.w
  end
  local y1 = p.y + hb.oy
  return x1, y1, x2, y1 + hb.h
end

local function hurtbox(t)
  return t.x - t.w / 2, t.y - t.h, t.x + t.w / 2, t.y
end

-- ---------------------------------------------------------------------------
-- Morte e danno

function Combat.kill(game, vic, killer, cause, wid)
  if not vic.alive then return end
  vic.alive = false
  vic.hp = 0
  vic.death_frame = game.frame
  vic.death_cause = cause
  vic.action = nil
  if vic.weapon then
    vic.fusing = nil
    game:drop_item(vic.x, vic.y - 4, vic.weapon, (killer and killer.id == vic.id) and 0 or sign(vic.vx) * 40)
    vic.weapon = nil
  end
  game:emit("death", vic.x, vic.y - 10, { id = vic.id, cause = cause, weapon = wid,
                                          killer = killer and killer.id or nil })
  if killer and killer.id ~= vic.id and killer.alive then
    local Player = require("src.sim.player")
    Player.gain_momentum(killer, data.momentum.gain_kill)
  end
end

-- Applica danno e conseguenze di un colpo andato a segno.
local function land_hit(game, atk, vic, spec)
  local Player = require("src.sim.player")
  local P, M = data.player, data.momentum
  local dmg = spec.dmg
  local src_x = spec.src_x or (atk and atk.x) or vic.x
  local dir = sign(vic.x - src_x)
  if dir == 0 then dir = atk and atk.facing or 1 end
  if spec.pull then dir = -dir end           -- frusta: tira verso chi colpisce

  -- effetti del colpo: uno singolo (armi normali) e/o una lista (armi fuse)
  local effs = {}
  if spec.effect then effs[#effs + 1] = spec.effect end
  if spec.effects then for _, e in ipairs(spec.effects) do effs[#effs + 1] = e end end
  local has_bubble = false
  for _, e in ipairs(effs) do if e == "bubble" then has_bubble = true end end

  -- un colpo fa scoppiare la bolla, con danno extra (una bolla nuova invece la rinnova)
  if vic.bubble > 0 and not has_bubble then
    vic.bubble = 0
    dmg = dmg + P.bubble_pop_bonus
    game:emit("pop", vic.x, vic.y - 10, { id = vic.id })
  end

  vic.hp = vic.hp - dmg
  vic.last_hit_by = atk and atk.id or nil
  vic.last_hit_frame = game.frame
  Player.lose_momentum(vic, M.loss_hit)
  if atk and atk.alive and atk.id ~= vic.id then Player.gain_momentum(atk, M.gain_hit) end

  local kb = spec.kb or 0
  if spec.nostun then
    -- colpi leggerissimi (fiamme): niente stordimento, solo una piccola spinta
    vic.vx = vic.vx + dir * 8
  else
    vic.action = nil
    vic.clash = 0
    vic.grapple = nil
    vic.hitstun = spec.stun or math.floor(P.hitstun_base + dmg * P.hitstun_per_dmg)
    if kb > 0 then
      vic.vx = dir * kb
      vic.vy = -kb * P.knockback_up
      vic.grounded = false
    else
      vic.vx = vic.vx + dir * 30
    end
  end

  -- effetti delle armi
  for _, eff in ipairs(effs) do
    if eff == "burn" then
      if vic.burn <= 0 then game:emit("ignite", vic.x, vic.y - 10, { id = vic.id }) end
      vic.burn = P.burn_frames
      vic.burn_by = atk and atk.id or nil
    elseif eff == "bubble" then
      vic.bubble = P.bubble_frames
      vic.action, vic.grapple, vic.fusing = nil, nil, nil
      vic.vx, vic.vy = vic.vx * 0.3, 0
      game:emit("bubbled", vic.x, vic.y - 10, { id = vic.id })
    elseif eff == "hookpull" and atk and atk.alive and atk.id ~= vic.id then
      -- rampino: trascina la vittima verso chi ha sparato
      local dx, dy = atk.x - vic.x, (atk.y - 6) - vic.y
      local d = sqrt(dx * dx + dy * dy) + 0.001
      vic.vx = dx / d * P.hook_pull_speed
      vic.vy = dy / d * P.hook_pull_speed - 120
      vic.hitstun = P.hook_stun
      vic.grounded = false
    end
  end

  local stop = math.floor(min(P.hitstop_max, P.hitstop_base + dmg * 0.04))
  if spec.melee then
    vic.freeze = stop
    if atk then atk.freeze = stop end
  end

  game:emit("hit", vic.x, vic.y - 10, { id = vic.id, dmg = dmg, dir = dir, melee = spec.melee,
                                        light = spec.nostun or dmg <= 3 })

  if vic.hp <= 0 then
    Combat.kill(game, vic, atk, "hit", spec.wid)
    return "kill"
  end
  return "hit"
end

-- Danno nel tempo (fuoco, nucleo del buco nero): niente stordimento ne' spinta.
function Combat.dot(game, vic, dmg, by_id, wid)
  if not vic.alive then return end
  vic.hp = vic.hp - dmg
  vic.last_hit_by, vic.last_hit_frame = by_id, game.frame
  game:emit("hit", vic.x, vic.y - 10, { id = vic.id, dmg = dmg, dir = 0, light = true })
  if vic.hp <= 0 then
    local killer = by_id and game.players[by_id] or nil
    Combat.kill(game, vic, killer, wid, wid)
  end
end

-- Danno da trappola (spuntoni): spinge verso l'alto e conta come eliminazione ambientale.
function Combat.hazard_hit(game, vic, dmg, cause)
  if not vic.alive then return end
  local res = land_hit(game, nil, vic, { dmg = dmg, kb = 0, src_x = vic.x, wid = cause })
  if res == "kill" then
    vic.death_cause = cause
  else
    vic.vy = -240
    vic.vx = -vic.facing * 80
    vic.grounded = false
  end
end

-- ---------------------------------------------------------------------------
-- Deflect (parry)

local function deflect(game, atk, vic, spec)
  local Player = require("src.sim.player")
  local P = data.player
  vic.action = nil
  vic.parry_flash = 12
  Player.gain_momentum(vic, data.momentum.gain_parry)
  game:emit("parry", vic.x + vic.facing * 8, vic.y - 12, { id = vic.id })
  if spec.proj then
    local pr = spec.proj
    pr.vx = -pr.vx * P.parry_proj_speed
    pr.vy = -pr.vy * P.parry_proj_speed
    pr.owner = vic.id
    pr.reflected = true
    pr.life = max(pr.life, 40)
    pr.x = pr.x + sign(pr.vx) * 3
  elseif atk then
    atk.action = nil
    atk.hitstun = P.parry_stun
    atk.vx = sign(atk.x - vic.x) * 80
    atk.freeze = 0
    vic.freeze = 3
  end
  return "parried"
end

-- Scudo: para un colpo frontale. Il martello consuma 3 parate invece di una.
local function shield_block(game, atk, vic, spec)
  local P = data.player
  local w = vic.weapon
  local cost = spec.guardbreak and 3 or 1
  if w.uses then w.uses = w.uses - cost elseif w.ammo then w.ammo = w.ammo - cost end
  local dir = sign(vic.x - (spec.src_x or (atk and atk.x) or vic.x))
  if dir == 0 then dir = -vic.facing end
  vic.vx = dir * P.shield_block_push * (spec.guardbreak and 2 or 1)
  if spec.melee and atk then
    atk.action = nil
    atk.hitstun = P.shield_attacker_stun
    atk.vx = -dir * P.shield_block_push
  end
  game:emit("block", vic.x + vic.facing * 8, vic.y - 12, { id = vic.id })
  if (w.uses or w.ammo or 1) <= 0 then
    game:emit("break", vic.x, vic.y - 12, { weapon = w.id })
    vic.weapon = nil
  end
  return "blocked"
end

-- Risolve un colpo contro una vittima. spec = { dmg, kb, guardbreak, melee, proj, src_x, ... }
function Combat.hit(game, atk, vic, spec)
  if not vic.alive or vic.invuln > 0 then return "miss" end
  local a = vic.action
  -- scudo in mano e non si sta attaccando: para tutto cio' che arriva da davanti
  local vdef = vic.weapon and (vic.weapon.def or data.weapons[vic.weapon.id])
  if vdef and (vdef.id == "shield" or vdef.guard) and not (a and a.type == "attack")
     and vic.hitstun <= 0 and vic.bubble <= 0 then
    local sx = spec.src_x or (atk and atk.x) or vic.x
    if (sx - vic.x) * vic.facing > -2 then
      return shield_block(game, atk, vic, spec)
    end
  end
  if a and a.type == "parry" and a.active then
    local P = data.player
    local perfect = a.frame <= P.parry_startup + P.perfect_parry
    if spec.guardbreak and not perfect then
      game:emit("guardbreak", vic.x, vic.y - 12, { id = vic.id })
    else
      if spec.guardbreak then game:emit("perfect_parry", vic.x, vic.y - 12, { id = vic.id }) end
      local sx = spec.src_x or (atk and atk.x) or vic.x
      if (sx - vic.x) * vic.facing >= -4 then
        return deflect(game, atk, vic, spec)
      end
    end
  end
  return land_hit(game, atk, vic, spec)
end

-- ---------------------------------------------------------------------------
-- Clash

local function clash(game, a, b)
  local P = data.player
  a.action, b.action = nil, nil
  for _, p in ipairs({ a, b }) do
    p.clash = P.clash_window
    p.clash_winner = false
    p.freeze = 3
  end
  a.clash_partner, b.clash_partner = b.id, a.id
  local dir = sign(a.x - b.x)
  if dir == 0 then dir = -a.facing end
  a.vx = dir * P.clash_knockback
  b.vx = -dir * P.clash_knockback
  game:emit("clash", (a.x + b.x) / 2, (a.y + b.y) / 2 - 12)
end

-- ---------------------------------------------------------------------------
-- Colpi in mischia

function Combat.melee_check(game, p, a)
  local def = a.def
  local x1, y1, x2, y2 = Combat.melee_rect(p, def)
  for _, t in ipairs(game.players) do
    if t.id ~= p.id and t.alive and not a.hit[t.id] then
      local hx1, hy1, hx2, hy2 = hurtbox(t)
      if overlap(x1, y1, x2, y2, hx1, hy1, hx2, hy2) then
        local ta = t.action
        local bx1, by1, bx2, by2 = hurtbox(p)
        -- tolleranza di qualche frame: i due colpi contano come simultanei anche se
        -- l'ordine di aggiornamento li fa sfasare di poco
        if ta and ta.type == "attack" and ta.def.kind == "melee" and not ta.hit[p.id]
           and ta.frame >= ta.startup - data.player.clash_tolerance
           and ta.frame <= ta.startup + ta.def.active + data.player.clash_tolerance then
          local tx1, ty1, tx2, ty2 = Combat.melee_rect(t, ta.def)
          if overlap(tx1, ty1, tx2, ty2, bx1, by1, bx2, by2) then
            a.hit[t.id] = true
            ta.hit[p.id] = true
            clash(game, p, t)
            return
          end
        end
        a.hit[t.id] = true
        local res = Combat.hit(game, p, t, {
          wid = def.id, pull = def.pull, stun = def.stun,
          dmg = def.damage * a.mul,
          kb = def.knockback * a.kmul,
          guardbreak = def.guardbreak,
          melee = true, effects = def.effects,
        })
        if (res == "hit" or res == "kill") and def.on_hit_blast then
          -- tratto Esplosivo su un'arma da mischia: il colpo esplode dove arriva
          Combat.explode(game, t.x, t.y - t.h / 2, def.on_hit_blast, p, def.id)
        end
        if res == "parried" or res == "blocked" then return end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Armi a distanza

function Combat.new_projectile(game, owner_id, x, y, vx, vy, props)
  local pr = {
    x = x, y = y, vx = vx, vy = vy,
    w = 4, h = 3, owner = owner_id, dmg = 0, kb = 0,
    life = 60, gravity = 0, kind = "bullet", reflected = false, bounces = 0, age = 0,
  }
  -- tutte le proprieta' del proiettile (vedi proj nelle armi di data.lua)
  for k, v in pairs(props) do
    if k ~= "count" and k ~= "spread" and k ~= "speed" then pr[k] = v end
  end
  pr.bounces = pr.bounces or 0
  game.projectiles[#game.projectiles + 1] = pr
  return pr
end

function Combat.fire(game, p, a)
  local def = a.def
  local pj = def.proj
  local w = a.weapon
  if not w or not w.ammo then return end
  w.ammo = w.ammo - 1
  local ax, ay = p.aimx, p.aimy
  if ax == 0 and ay == 0 then ax = p.facing end
  local len = sqrt(ax * ax + ay * ay)
  ax, ay = ax / len, ay / len
  local base = math.atan2 and math.atan2(ay, ax) or math.atan(ay, ax)
  if def.jitter then base = base + game.rng:range(-def.jitter, def.jitter) end
  local blast = pj.blast
  if blast then
    blast = { radius = blast.radius, dmg = blast.dmg * a.mul, kb = blast.kb * a.kmul,
              self_mul = blast.self_mul }
  end
  local mx = p.x + ax * (p.w / 2 + 3)
  local my = p.y - 12 + ay * 4
  for i = 1, pj.count do
    local ang = base
    if pj.count > 1 then
      local t = (i - 1) / (pj.count - 1) * 2 - 1
      ang = base + t * pj.spread + game.rng:range(-0.03, 0.03)
    end
    local props = {}
    for k, v in pairs(pj) do props[k] = v end
    props.wid, props.dmg, props.kb = def.id, def.damage * a.mul, def.knockback * a.kmul
    props.color, props.blast, props.field = def.color, blast, def.field
    props.kind = pj.kind or "bullet"
    props.guardbreak = def.guardbreak
    if def.returns then
      -- boomerang e rampino: un solo colpo in volo alla volta
      props.wref = w
      w.out = true
    end
    Combat.new_projectile(game, p.id, mx, my, math.cos(ang) * pj.speed, math.sin(ang) * pj.speed, props)
  end
  if def.recoil then
    p.vx = p.vx - ax * def.recoil
  end
  if def.fire_dash then
    -- tratto Scatto: ogni colpo ti spinge in avanti, con una breve invulnerabilita'
    p.vx = ax * def.fire_dash
    if ay < -0.5 then p.vy = math.min(p.vy, ay * def.fire_dash * 0.8) end
    p.invuln = max(p.invuln, 8)
  end
  game:emit("shoot", mx, my, { weapon = def.id, id = p.id })
end

-- Proiettile extra di un'arma da mischia fusa (tratti Calibro, Rosa, Aggancio, Trappola)
function Combat.melee_shot(game, p, a)
  local s = a.def.melee_shot
  local ax, ay = p.aimx, p.aimy
  if not p.aim_free then ax, ay = p.facing, 0 end
  if s.dir == "down" then ax, ay = p.facing * 0.3, 0.6 end
  local len = sqrt(ax * ax + ay * ay)
  ax, ay = ax / len, ay / len
  local base = math.atan2 and math.atan2(ay, ax) or math.atan(ay, ax)
  local mx, my = p.x + ax * (p.w / 2 + 4), p.y - 12 + ay * 4
  for i = 1, s.count or 1 do
    local ang = base
    if (s.count or 1) > 1 then ang = base + ((i - 1) / (s.count - 1) * 2 - 1) * s.spread end
    local props = {}
    for k, v in pairs(s) do props[k] = v end
    props.wid, props.color = a.def.id, a.def.color
    props.kind = s.kind or "bullet"
    Combat.new_projectile(game, p.id, mx, my, math.cos(ang) * s.speed, math.sin(ang) * s.speed, props)
  end
  game:emit("shoot", mx, my, { weapon = (s.kind == "hook") and "hook" or "pistol", id = p.id })
end

function Combat.throw_weapon(game, p)
  local P = data.player
  local ax, ay = p.aimx, p.aimy
  if ax == 0 and ay == 0 then ax = p.facing end
  if ay == 0 then ay = -0.25 end
  local len = sqrt(ax * ax + ay * ay)
  ax, ay = ax / len, ay / len
  local def = data.weapons[p.weapon and p.weapon.id or "fists"]
  Combat.new_projectile(game, p.id, p.x + ax * 6, p.y - 12, ax * P.throw_speed, ay * P.throw_speed,
    { dmg = P.throw_damage, kb = 140, life = 50, gravity = P.throw_gravity, w = 8, h = 6,
      kind = "thrown", color = def.color, bounces = 1, bounce_keep = 0.5, wid = "lancio",
      carry = p.weapon })
  game:emit("throw", p.x, p.y - 12)
  p.weapon = nil
  p.fusing = nil
end

-- Un proiettile si muove a passi di al massimo STEP pixel: anche i colpi velocissimi
-- (cecchino) non attraversano muri sottili ne' giocatori.
local STEP = 4

-- Rimbalzo: inverte la componente che ha toccato il muro e rallenta il proiettile.
local function bounce(game, pr, axis)
  pr.bounces = pr.bounces - 1
  pr.bounced = (pr.bounced or 0) + 1
  local keep = pr.bounce_keep or 0.85
  if axis == "x" then pr.vx = -pr.vx else pr.vy = -pr.vy end
  pr.vx, pr.vy = pr.vx * keep, pr.vy * keep
  game:emit("bounce", pr.x, pr.y, { kind = pr.kind })
end

-- Prova i giocatori contro il proiettile.
-- Ritorna nil oppure un esito: "remove", "explode", "parried", "catch", "blackhole".
local function projectile_vs_players(game, pr)
  local x1, y1, x2, y2 = pr.x - pr.w / 2, pr.y - pr.h / 2, pr.x + pr.w / 2, pr.y + pr.h / 2
  local shooter = game.players[pr.owner]
  -- dopo un rimbalzo il proiettile puo' colpire anche chi l'ha sparato
  local self_ok = data.projectiles.self_hit_after_bounce and (pr.bounced or 0) > 0
  for _, t in ipairs(game.players) do
    if t.alive and not (pr.hit and pr.hit[t.id]) then
      local hx1, hy1, hx2, hy2 = hurtbox(t)
      if overlap(x1, y1, x2, y2, hx1, hy1, hx2, hy2) then
        local own = (t.id == pr.owner)
        if pr.return_after and own then
          -- il boomerang che torna viene ripreso al volo
          if pr.returning then return "catch" end
          goto continue
        end
        if pr.on_touch == "mine" then
          -- la mina esplode sotto chiunque, ma solo quando e' armata
          if pr.stuck and pr.arm <= 0 then return "explode" end
          goto continue
        end
        if own and not self_ok then goto continue end
        if pr.on_touch == "explode" or pr.on_touch == "blackhole" then
          if own then goto continue end
          return pr.on_touch
        end
        do
          local res = Combat.hit(game, shooter, t, {
            wid = pr.wid, dmg = pr.dmg, kb = pr.kb, proj = pr, src_x = pr.x - sign(pr.vx) * 4,
            effect = pr.effect, effects = pr.effects, nostun = pr.nostun, guardbreak = pr.guardbreak,
          })
          if res == "parried" then return "parried" end
          if res == "blocked" then return "remove" end
          if res ~= "miss" then
            if pr.pierce and pr.pierce > 0 then
              pr.pierce = pr.pierce - 1
              pr.hit = pr.hit or {}
              pr.hit[t.id] = true
            else
              return "remove"
            end
          end
        end
      end
    end
    ::continue::
  end
  return nil
end

local function nearest_enemy(game, pr, range)
  local best, bd
  for _, t in ipairs(game.players) do
    if t.alive and t.id ~= pr.owner then
      local dx, dy = t.x - pr.x, (t.y - 10) - pr.y
      local d = dx * dx + dy * dy
      if d < range * range and (not bd or d < bd) then best, bd = t, d end
    end
  end
  return best
end

-- sterza la velocita' verso un punto, con accelerazione `force` e velocita' massima
local function steer(pr, tx, ty, force, max_speed, dt)
  local dx, dy = tx - pr.x, ty - pr.y
  local d = sqrt(dx * dx + dy * dy) + 0.001
  pr.vx = pr.vx + dx / d * force * dt
  pr.vy = pr.vy + dy / d * force * dt
  local sp = sqrt(pr.vx * pr.vx + pr.vy * pr.vy)
  if sp > max_speed then pr.vx, pr.vy = pr.vx / sp * max_speed, pr.vy / sp * max_speed end
end

-- Comportamenti che cambiano la velocita' prima del movimento
local function guide(game, pr, dt)
  if pr.accel then
    -- razzo: accelera nella direzione di volo
    local sp = sqrt(pr.vx * pr.vx + pr.vy * pr.vy)
    if sp > 0 and sp < pr.max_speed then
      local k = min(pr.max_speed, sp + pr.accel * dt) / sp
      pr.vx, pr.vy = pr.vx * k, pr.vy * k
    end
  end
  if pr.return_after and pr.age > pr.return_after then
    local o = game.players[pr.owner]
    if not pr.returning then
      pr.returning = true
      pr.hit = {}            -- al ritorno puo' colpire di nuovo
      pr.pierce = pr.pierce or 9
    end
    if o and o.alive then steer(pr, o.x, o.y - 12, pr.homing, pr.max_speed, dt) end
  end
  if pr.seek and pr.age > (pr.seek_delay or 0) then
    local t = nearest_enemy(game, pr, 500)
    if t then steer(pr, t.x, t.y - 10, pr.seek, pr.max_speed, dt) end
  end
end

-- Cosa succede quando il proiettile tocca un muro senza piu' rimbalzi.
-- Ritorna l'esito (vedi update_projectiles) oppure "stop" se resta in gioco.
local function wall_impact(game, pr)
  local what = pr.on_impact
  if what == "stick" then
    pr.stuck = true
    pr.vx, pr.vy, pr.gravity = 0, 0, 0
    game:emit("mine_set", pr.x, pr.y)
    return "stop"
  end
  game:emit("impact", pr.x, pr.y, { kind = pr.kind, vx = pr.vx })
  if what == "grapple" then
    local o = game.players[pr.owner]
    if o and o.alive then
      o.grapple = { x = pr.x, y = pr.y + 10, t = data.player.grapple_frames }
      game:emit("grapple", pr.x, pr.y, { id = o.id })
    end
    return "remove"
  end
  if what == "explode" or what == "blackhole" then return what end
  return "remove"
end

-- Aggiorna tutti i proiettili di un frame
function Combat.update_projectiles(game)
  local dt = data.dt
  local world = game.world
  local list = game.projectiles
  local i = 1
  while i <= #list do
    local pr = list[i]
    local outcome = nil          -- nil | "remove" | "explode" | "blackhole" | "catch"
    pr.age = pr.age + 1
    pr.life = pr.life - 1
    if pr.life <= 0 then
      outcome = (pr.on_expire == "explode" or pr.on_expire == "blackhole") and pr.on_expire or "remove"
    end

    if not outcome and pr.stuck then
      -- mina posata: si arma, poi aspetta qualcuno
      if pr.arm > 0 then
        pr.arm = pr.arm - 1
        if pr.arm == 0 then game:emit("mine_armed", pr.x, pr.y) end
      end
      local res = projectile_vs_players(game, pr)
      if res then outcome = res end
    elseif not outcome then
      pr.vy = pr.vy + pr.gravity * dt
      if pr.drag then pr.vx, pr.vy = pr.vx * pr.drag, pr.vy * pr.drag end
      guide(game, pr, dt)

      local dx, dy = pr.vx * dt, pr.vy * dt
      local n = math.max(1, math.ceil(max(abs(dx), abs(dy)) / STEP))
      local sx, sy = dx / n, dy / n
      for _ = 1, n do
        if pr.phase_walls then
          -- proiettile fantasma: attraversa i muri
          pr.x, pr.y = pr.x + sx, pr.y + sy
        else
          -- asse orizzontale
          local nx = pr.x + sx
          if world:tile_at(nx, pr.y) == "#" then
            if pr.bounces > 0 then
              bounce(game, pr, "x")
              local k = pr.bounce_keep or 0.85
              sx, sy = -sx * k, sy * k
            else
              local r = wall_impact(game, pr)
              if r ~= "stop" then outcome = r end
              break
            end
          else
            pr.x = nx
          end
          -- asse verticale (granate, mine e armi lanciate si posano anche sulle piattaforme
          -- sottili; i proiettili le attraversano)
          local ny = pr.y + sy
          local tile_y = world:tile_at(pr.x, ny)
          local solid_y = tile_y == "#"
          if not solid_y and tile_y == "=" and sy > 0
             and (pr.kind == "grenade" or pr.kind == "thrown" or pr.kind == "mine")
             and world:tile_at(pr.x, pr.y) ~= "=" then
            solid_y = true
          end
          if solid_y then
            if pr.bounces > 0 then
              bounce(game, pr, "y")
              local k = pr.bounce_keep or 0.85
              sx, sy = sx * k, -sy * k
            else
              local r = wall_impact(game, pr)
              if r ~= "stop" then outcome = r end
              break
            end
          else
            pr.y = ny
          end
        end
        if pr.y > world.height + 40 or pr.y < -200 or pr.x < -60 or pr.x > world.width + 60 then
          outcome = "remove"
          break
        end
        local res = projectile_vs_players(game, pr)
        if res == "parried" then break end
        if res then outcome = res; break end
      end
    end

    if outcome then
      if outcome == "explode" then
        Combat.explode(game, pr.x, pr.y, pr.blast, game.players[pr.owner], pr.wid)
      elseif outcome == "blackhole" then
        Combat.open_blackhole(game, pr.x, pr.y, pr.field, pr.owner)
      elseif outcome == "catch" then
        game:emit("catch", pr.x, pr.y, { id = pr.owner })
      end
      if pr.wref then pr.wref.out = false end
      -- un'arma lanciata, dopo il colpo, cade a terra se ha ancora munizioni (altrimenti si rompe)
      if pr.carry then game:drop_item(pr.x - sign(pr.vx) * 6, pr.y - 4, pr.carry, -pr.vx * 0.15, -100) end
      table.remove(list, i)
    else
      i = i + 1
    end
  end
end

-- ---------------------------------------------------------------------------
-- Buchi neri: campi che risucchiano giocatori, proiettili e armi a terra

function Combat.open_blackhole(game, x, y, field, owner_id)
  if not field then return end
  game.fields = game.fields or {}
  game.fields[#game.fields + 1] = { x = x, y = y, t = field.frames, max = field.frames,
                                    def = field, owner = owner_id }
  game:emit("blackhole", x, y, { radius = field.radius })
end

function Combat.update_fields(game)
  local fields = game.fields
  if not fields then return end
  local dt = data.dt
  for i = #fields, 1, -1 do
    local f = fields[i]
    local d = f.def
    f.t = f.t - 1
    -- la forza cresce avvicinandosi al centro
    local function pull(obj, ox, oy, mul)
      local dx, dy = f.x - ox, f.y - oy
      local dist = sqrt(dx * dx + dy * dy)
      if dist < d.radius and dist > 0.5 then
        local force = d.force * (1 - dist / d.radius) * 0.8 + d.force * 0.2
        obj.vx = obj.vx + dx / dist * force * mul * dt
        obj.vy = obj.vy + dy / dist * force * mul * dt
        return dist
      end
      return dist
    end
    for _, p in ipairs(game.players) do
      if p.alive then
        local mul = (p.id == f.owner) and d.owner_mul or 1
        local dist = pull(p, p.x, p.y - p.h / 2, mul)
        if dist < d.radius then
          p.grounded = false
          p.grapple = nil
        end
        if dist < d.core and f.t % d.core_every == 0 then
          Combat.dot(game, p, d.core_dmg, f.owner ~= p.id and f.owner or nil, "blackhole")
        end
      end
    end
    for _, pr in ipairs(game.projectiles) do
      if not pr.stuck then pull(pr, pr.x, pr.y, 0.6) end
    end
    for _, it in ipairs(game.items) do pull(it, it.x, it.y, 1) end
    if f.t <= 0 then
      Combat.explode(game, f.x, f.y, d.end_blast, game.players[f.owner], "blackhole")
      table.remove(fields, i)
    end
  end
end

-- Esplosione ad area: danno e spinta decrescono con la distanza; colpisce tutti,
-- anche chi l'ha causata. I muri pieni riparano.
function Combat.explode(game, x, y, blast, owner, wid)
  if not blast then return end
  local world = game.world
  game:emit("explosion", x, y, { radius = blast.radius })
  local broken = world:break_blocks(x, y, blast.radius * 0.75)
  if #broken > 0 then game:emit("blocks_broken", x, y, { list = broken }) end
  for _, t in ipairs(game.players) do
    if t.alive and t.invuln <= 0 then
      local cx, cy = t.x, t.y - t.h / 2
      local ddx, ddy = cx - x, cy - y
      local d = sqrt(ddx * ddx + ddy * ddy)
      if d < blast.radius then
        -- linea di vista: un muro pieno tra centro ed esplosione protegge
        local blocked = false
        local steps = math.ceil(d / 6)
        for k = 1, steps - 1 do
          local f = k / steps
          if world:tile_at(x + ddx * f, y + ddy * f) == "#" then blocked = true; break end
        end
        if not blocked then
          local f = 1 - (d / blast.radius) * 0.6
          local dmg = math.floor(blast.dmg * f + 0.5)
          if owner and t.id == owner.id then dmg = math.floor(dmg * (blast.self_mul or 1) + 0.5) end
          local kb = blast.kb * f
          local res = land_hit(game, owner, t, { dmg = dmg, kb = 0, src_x = x, melee = false,
                                                 wid = wid or "esplosione" })
          if t.alive then
            local len = math.max(d, 1)
            t.vx = ddx / len * kb
            t.vy = math.min(-kb * 0.45, ddy / len * kb)
            t.grounded = false
          end
        end
      end
    end
  end
end

return Combat
