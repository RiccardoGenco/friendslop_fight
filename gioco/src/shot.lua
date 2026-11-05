-- Modalita' foto per lo sviluppo: love . shot <scena> <cartella> [mappa]
-- Avvia una scena, simula i tasti, salva PNG del gioco a frame stabiliti e chiude.
-- Scene: menu, heroes, achievements, settings, lobby, game, pause, matchend

local Shot = { frame = 0, steps = {}, shots = {} }

local function key(k) return function() love.keypressed(k) end end

function Shot.start(args)
  Shot.scene = args[2] or "game"
  Shot.dir = args[3] or "."
  Shot.map = args[4]
  local s = Shot.steps
  local function at(f, fn) s[#s + 1] = { f = f, fn = fn } end
  local function snap(f, name) Shot.shots[#Shot.shots + 1] = { f = f, name = name } end
  local sc = Shot.scene
  if sc == "gallery" then snap(3, "gallery")
  elseif sc == "menu" then snap(90, "menu")
  elseif sc == "heroes" then at(5, key("down")); at(6, key("return")); snap(80, "heroes")
  elseif sc == "achievements" then at(5, key("down")); at(6, key("down")); at(7, key("return")); snap(80, "achievements")
  elseif sc == "settings" then for i = 1, 3 do at(4 + i, key("down")) end; at(9, key("return")); snap(80, "settings")
  else
    at(5, key("return"))                      -- menu -> lobby
    at(8, key("f10")); at(9, key("f10")); at(10, key("f10"))
    if sc == "lobby" then snap(60, "lobby")
    else
      if Shot.map then __force_maps = { Shot.map } end
      at(12, key("return"))                   -- tastiera + 3 bot
      if sc == "game" then
        snap(100, "countdown"); snap(420, "game1"); snap(700, "game2"); snap(1100, "game3"); snap(1600, "game4")
      elseif sc == "pause" then at(500, key("escape")); snap(530, "pause")
      elseif sc == "matchend" then
        at(300, function() local g = __smoke_game(); if g then g.scores[2] = g.wins_target - 1 end end)
        snap(2400, "matchend")
      end
    end
  end
  table.sort(Shot.steps, function(a, b) return a.f < b.f end)
  Shot.last = 0
  for _, x in ipairs(Shot.shots) do Shot.last = math.max(Shot.last, x.f) end
end

function Shot.update()
  Shot.frame = Shot.frame + 1
  for _, st in ipairs(Shot.steps) do
    if st.f == Shot.frame then st.fn() end
  end
end

-- tavola di controllo: eroi in tutte le pose, armi, effetti, oggetti degli eventi
local function gallery(canvas)
  local lg = love.graphics
  local Heroes = require("src.heroes")
  local Render = require("src.render")
  local Fx = require("src.fx")
  local Art = require("src.art")
  local data = require("src.sim.data")
  lg.setCanvas(canvas)
  lg.clear(0.16, 0.17, 0.22, 1)
  lg.push()
  lg.scale(2)
  local poses = {
    { grounded = true, vx = 0, vy = 0 }, { grounded = true, vx = 120, vy = 0, dist = 3 },
    { grounded = true, vx = 120, vy = 0, dist = 12 }, { grounded = false, vx = 40, vy = -120 },
    { grounded = false, vx = 40, vy = 120 }, { grounded = false, vx = 200, vy = 0, action = { type = "dash" } },
    { grounded = false, vx = 0, vy = 60, sliding = true, wall = 1 },
  }
  for hi, h in ipairs(Heroes.list) do
    for pi, po in ipairs(poses) do
      local p = { x = 0, y = 0, facing = 1, id = hi, vx = po.vx, vy = po.vy, grounded = po.grounded,
                  action = po.action, sliding = po.sliding, wall = po.wall }
      lg.push()
      lg.translate(14 + (pi - 1) * 27, 32 + (hi - 1) * 40)
      lg.scale(1.5)
      Heroes.draw(h.id, 1, p, data.colors[hi], 1, false, 0.3, { dist = po.dist or 0 })
      lg.pop()
    end
  end
  -- armi
  for i, id in ipairs(data.weapon_order) do
    local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
    lg.push()
    lg.translate(212 + col * 48, 18 + row * 22)
    lg.scale(1.5)
    Render.draw_weapon(id)
    lg.pop()
    lg.setColor(1, 1, 1, 0.5)
    lg.print(id, 200 + col * 48, 24 + row * 22, 0, 0.4)
  end
  -- esplosione a eta' diverse, masso e barile
  local ages = { 0.02, 0.08, 0.16, 0.3, 0.5, 0.9 }
  for i, age in ipairs(ages) do
    Fx.reset()
    love.math.setRandomSeed(i)
    Fx.explosion(390 + i * 40, 300, 46)
    for _ = 1, math.floor(age * 60) do Fx.update(1 / 60) end
    Fx.draw()
  end
  Art.draw(Art.ROCK, Art.ROCK_PAL, 420, 200, 0.5 * 2)
  Art.draw(Art.BARREL, Art.BARREL_PAL, 450, 200, 0.5 * 2)
  lg.pop()
  lg.setCanvas()
end

function Shot.after_draw(canvas)
  if Shot.scene == "gallery" and Shot.frame == 3 then gallery(canvas) end
  for _, x in ipairs(Shot.shots) do
    if x.f == Shot.frame then
      local data = canvas:newImageData():encode("png")
      local path = Shot.dir .. "/" .. Shot.scene .. (Shot.map and ("_" .. Shot.map) or "") .. "_" .. x.name .. ".png"
      local f = io.open(path, "wb")
      if f then f:write(data:getString()); f:close() end
    end
  end
  if Shot.frame >= Shot.last then love.event.quit() end
end

return Shot
