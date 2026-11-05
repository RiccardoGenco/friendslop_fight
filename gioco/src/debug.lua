-- Strumenti di debug e taratura, attivi in gioco.
--   F3  hitbox e stato dei giocatori      F4  slow motion (1/4 di velocita')
--   F5  pausa / riprendi                  F6  avanza di un frame (da pausa)
--   F7  rilegge src/sim/data.lua          F8  pannello di taratura
--   Nel pannello: Su/Giu scelgono il valore, Sinistra/Destra lo cambiano (Maiusc = x5),
--   F9 salva tutti i valori in tuning.txt (nella cartella di salvataggio di LÖVE).

local data = require("src.sim.data")
local Player = require("src.sim.player")
local Combat = require("src.sim.combat")
local Render = require("src.render")

local Debug = {
  hitboxes = false, slowmo = false, paused = false, step = false, panel = false,
  selected = 1, message = nil, message_t = 0,
}

-- { percorso, passo }
local PARAMS = {
  { "player.run_speed", 5 }, { "player.accel_ground", 100 }, { "player.gravity", 25 },
  { "player.jump_vel", 10 }, { "player.jump_cut", 0.05 }, { "player.dash_speed", 10 },
  { "player.dash_frames", 1 }, { "player.dash_cooldown", 2 },
  { "player.parry_startup", 1 }, { "player.parry_active", 1 }, { "player.parry_stun", 2 },
  { "player.parry_whiff_recovery", 2 }, { "player.clash_window", 1 },
  { "player.hitstop_base", 1 }, { "player.hitstun_per_dmg", 0.05 },
  { "momentum.gain_hit", 1 }, { "momentum.gain_parry", 1 }, { "momentum.loss_hit", 5 },
  { "weapons.fists.damage", 1 }, { "weapons.fists.recovery", 1 },
  { "weapons.sword.damage", 1 }, { "weapons.sword.startup", 1 }, { "weapons.sword.recovery", 1 },
  { "weapons.sword.knockback", 10 },
  { "weapons.hammer.damage", 1 }, { "weapons.hammer.startup", 1 }, { "weapons.hammer.recovery", 1 },
  { "weapons.hammer.knockback", 10 },
  { "weapons.pistol.damage", 1 }, { "weapons.pistol.recovery", 1 },
  { "weapons.shotgun.damage", 1 }, { "weapons.shotgun.recovery", 1 },
  { "weapons.spear.damage", 1 }, { "weapons.spear.startup", 1 },
  { "weapons.smg.damage", 1 }, { "weapons.smg.recovery", 1 },
  { "weapons.sniper.damage", 1 }, { "weapons.sniper.startup", 1 },
  { "weapons.grenade.proj.blast.dmg", 1 }, { "weapons.grenade.proj.blast.radius", 2 },
  { "weapons.grenade.proj.life", 5 }, { "player.perfect_parry", 1 },
  { "camera.zoom_max", 0.05 },
  { "tier_ramp_frames", 120 },
  { "player.burn_dmg", 1 }, { "player.bubble_frames", 5 }, { "player.grapple_speed", 20 },
  { "weapons.katana.lunge", 10 }, { "weapons.whip.knockback", 10 },
  { "weapons.assault.damage", 1 }, { "weapons.autoshotgun.recovery", 1 },
  { "weapons.bazooka.proj.blast.dmg", 1 }, { "weapons.gust.knockback", 10 },
  { "weapons.ghost.damage", 1 }, { "weapons.blackhole.field.force", 100 },
  { "round.spawn_min", 20 }, { "round.spawn_max", 20 }, { "round.max_items", 1 },
  { "round.sudden_death", 60 },
}

local function resolve(path)
  local parts = {}
  for part in path:gmatch("[^%.]+") do parts[#parts + 1] = part end
  local t = data
  if parts[1] == "camera" then
    t = Render.CAM
    table.remove(parts, 1)
  end
  for i = 1, #parts - 1 do t = t[parts[i]] end
  return t, parts[#parts]
end

local function get(path)
  local t, k = resolve(path)
  return t[k]
end

local function round_val(v)
  return math.floor(v * 1000 + 0.5) / 1000
end

local function notify(msg)
  Debug.message, Debug.message_t = msg, 2.5
end

function Debug.keypressed(key)
  if key == "f3" then Debug.hitboxes = not Debug.hitboxes
  elseif key == "f4" then Debug.slowmo = not Debug.slowmo
  elseif key == "f5" then Debug.paused = not Debug.paused
  elseif key == "f6" then Debug.step = true; Debug.paused = true
  elseif key == "f7" then
    notify(data.reload() and "data.lua ricaricato" or "ricarica non riuscita")
  elseif key == "f8" then Debug.panel = not Debug.panel
  elseif key == "f9" then
    local lines = {}
    for _, pr in ipairs(PARAMS) do
      lines[#lines + 1] = pr[1] .. " = " .. tostring(round_val(get(pr[1])))
    end
    local ok = love.filesystem.write("tuning.txt", table.concat(lines, "\n") .. "\n")
    notify(ok and ("salvato in " .. love.filesystem.getSaveDirectory() .. "/tuning.txt") or "salvataggio fallito")
  elseif Debug.panel then
    local shift = love.keyboard.isDown("lshift", "rshift")
    if key == "down" then Debug.selected = Debug.selected % #PARAMS + 1; return true
    elseif key == "up" then Debug.selected = (Debug.selected - 2) % #PARAMS + 1; return true
    elseif key == "left" or key == "right" then
      local path, step = PARAMS[Debug.selected][1], PARAMS[Debug.selected][2]
      local t, k = resolve(path)
      local d = (key == "right" and 1 or -1) * step * (shift and 5 or 1)
      t[k] = round_val(t[k] + d)
      return true
    end
  end
  return false
end

function Debug.update(dt)
  if Debug.message_t > 0 then Debug.message_t = Debug.message_t - dt end
end

-- Quante volte far girare la simulazione in questo frame di rendering (pausa e avanzamento)
function Debug.consume_step()
  if Debug.step then
    Debug.step = false
    return true
  end
  return false
end

function Debug.draw(game, fps)
  local lg = love.graphics
  if Debug.hitboxes then
    lg.push()
    Render.apply_camera()
    for _, p in ipairs(game.players) do
      if p.alive then
        local x1, y1, x2, y2 = Player.box(p)
        lg.setColor(0.3, 1, 0.3, 0.9)
        lg.rectangle("line", x1 + 0.5, y1 + 0.5, x2 - x1, y2 - y1)
        local a = p.action
        if a and a.type == "attack" and a.def.kind == "melee" then
          local hx1, hy1, hx2, hy2 = Combat.melee_rect(p, a.def)
          if a.phase == "active" then lg.setColor(1, 0.2, 0.2, 0.9)
          elseif a.phase == "startup" then lg.setColor(1, 0.9, 0.2, 0.6)
          else lg.setColor(0.5, 0.5, 1, 0.5) end
          lg.rectangle("line", hx1 + 0.5, hy1 + 0.5, hx2 - hx1, hy2 - hy1)
        end
        local state = a and (a.type .. (a.phase and ("/" .. a.phase) or "") .. " f" .. a.frame) or "-"
        Render.text(string.format("%d %s", p.id, state), x1 - 6, y2 + 2, { 1, 1, 1 }, "small")
        Render.text(string.format("hp%d m%d", p.hp, p.momentum), x1 - 6, y2 + 10, { 0.8, 0.9, 1 }, "small")
      end
    end
    for _, pr in ipairs(game.projectiles) do
      lg.setColor(1, 0.2, 0.2, 0.9)
      lg.rectangle("line", pr.x - pr.w / 2, pr.y - pr.h / 2, pr.w, pr.h)
    end
    lg.pop()
  end

  local flags = {}
  if Debug.paused then flags[#flags + 1] = "PAUSA" end
  if Debug.slowmo then flags[#flags + 1] = "SLOW" end
  if Debug.hitboxes then flags[#flags + 1] = "HITBOX" end
  Render.text(string.format("%d fps  frame %d  %s", fps, game.frame, table.concat(flags, " ")),
    Render.W - 6, Render.H - 12, { 0.7, 0.9, 0.7 }, "small", "right", 400)

  if Debug.panel then
    lg.setColor(0, 0, 0, 0.78)
    lg.rectangle("fill", 4, 24, 230, 14 + 10 * 14)
    Render.text("TARATURA (F8 chiude, F9 salva)", 8, 27, { 1, 0.9, 0.4 }, "small")
    local first = math.max(1, math.min(Debug.selected - 6, #PARAMS - 13))
    for row = 0, 13 do
      local i = first + row
      local pr = PARAMS[i]
      if not pr then break end
      local sel = (i == Debug.selected)
      Render.text((sel and "> " or "  ") .. pr[1] .. " = " .. tostring(round_val(get(pr[1]))),
        8, 38 + row * 10, sel and { 1, 1, 0.5 } or { 0.8, 0.8, 0.8 }, "small")
    end
  end
  if Debug.message_t > 0 and Debug.message then
    Render.text(Debug.message, Render.W / 2, Render.H - 24, { 1, 1, 0.6 }, "small", "center", Render.W)
  end
  lg.setColor(1, 1, 1, 1)
end

return Debug
