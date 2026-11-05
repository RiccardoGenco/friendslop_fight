-- Modalita' foto per lo sviluppo: love . shot <scena> <cartella> [mappa]
-- Avvia una scena, simula i tasti, salva PNG del gioco a frame stabiliti e chiude.
-- Scene: menu, heroes, achievements, settings, cookbook, lobby, game, pause, matchend, fusion, recipes

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
  elseif sc == "achievements" then for i = 1, 3 do at(4 + i, key("down")) end; at(9, key("return")); snap(80, "achievements")
  elseif sc == "settings" then for i = 1, 4 do at(4 + i, key("down")) end; at(10, key("return")); snap(80, "settings")
  elseif sc == "cookbook" then
    -- ricettario con qualche scoperta finta (non salvata)
    at(3, function()
      local P = require("src.profile").data
      P.recipes = { tornado = true, bubblerocket = true, harpoon = true }
      P.fusions = { ["pistol+flamer"] = true, ["sword+grenade"] = true, ["smg+sniper"] = true, ["hammer+boomerang"] = true }
    end)
    at(5, key("down")); at(6, key("down")); at(7, key("return")); snap(80, "cookbook1")
    at(90, key("right")); snap(150, "cookbook2")
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
      elseif sc == "recipes" then
        -- i giocatori usano le ricette speciali, quattro alla volta
        local list = require("src.sim.recipes")
        for wave = 0, 3 do
          at(260 + wave * 150, function()
            local g = __smoke_game(); if not g then return end
            local Fusion = require("src.sim.fusion")
            for k, p in ipairs(g.players) do
              local r = list[(wave * 4 + k - 1) % #list + 1]
              if p.alive then p.weapon = Fusion.fuse({ id = r.a }, { id = r.b }); p.invuln = 400 end
            end
          end)
          snap(330 + wave * 150, "recipes" .. (wave + 1))
          snap(350 + wave * 150, "recipes" .. (wave + 1) .. "b")
        end
      elseif sc == "fusion" then
        -- armi fuse in mano, anteprime e una fusione in corso: giocatori fermi, armi ai loro piedi
        local spots
        at(260, function()
          local g = __smoke_game(); if not g then return end
          local Fusion = require("src.sim.fusion")
          g.items, g.projectiles, g.spawn_timer, g.crate_timer = {}, {}, 1e9, 1e9
          -- il pavimento piu' basso con piu' punti di partenza vicini
          local sp = {}
          for _, s in ipairs(g.world.spawns) do sp[#sp + 1] = s end
          table.sort(sp, function(a, b) if a.y ~= b.y then return a.y > b.y end return a.x < b.x end)
          local floor_y, base = sp[1].y, sp[1].x
          local held = { "pistol", "bubble", "sword", "hammer" }
          local ground = { "flamer", "mines", "ghost", nil }
          spots = {}
          for k, p in ipairs(g.players) do
            spots[k] = { x = base + (k - 1) * 85, y = floor_y }
            p.weapon = g:make_weapon(held[k] or "pistol")
            if ground[k] then g:add_item(spots[k].x, floor_y - 4, g:make_weapon(ground[k])) end
          end
          if g.players[4] then g.players[4].weapon = Fusion.fuse({ id = "hammer" }, { id = "boomerang" }) end
          if g.players[3] then g.players[3].weapon = Fusion.fuse({ id = "shotgun" }, { id = "bubble" }) end
        end)
        for f = 261, 300 do at(f, function()
          local g = __smoke_game(); if not (g and spots) then return end
          for k, p in ipairs(g.players) do
            p.x, p.y, p.vx, p.vy, p.freeze, p.invuln = spots[k].x, spots[k].y, 0, 0, 2, 1e9
            p.action = nil
          end
        end) end
        -- il giocatore 1 (un bot) tiene premuto il tasto raccogli: parte una fusione vera
        at(275, function()
          local Bot = require("src.bot")
          local orig = Bot.think
          Bot.think = function(game, i, lvl)
            if i == 1 then return { pickup_held = true } end
            return orig(game, i, lvl)
          end
        end)
        snap(300, "fusion")
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
      lg.translate(16 + (pi - 1) * 27, 40 + (hi - 1) * 46)
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
