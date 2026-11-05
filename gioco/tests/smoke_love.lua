-- Prova "a secco" del livello LÖVE: sostituisce le API di LÖVE con funzioni vuote
-- e fa giocare una partita intera ai bot, disegnando ogni frame.
-- Uso (dalla cartella del progetto): luajit tests/smoke_love.lua
package.path = "./?.lua;" .. package.path

local function dummy()
  local d = {}
  setmetatable(d, { __index = function() return function() return d end end,
                    __call = function() return d end })
  return d
end
local function stub(extra)
  return setmetatable({}, { __index = function(_, k)
    if extra and extra[k] then return extra[k] end
    return function() return dummy() end
  end })
end
local mouse_x, mouse_y = 400, 200
love = {
  graphics = stub({
    getDimensions = function() return 1280, 720 end,
    getWidth = function() return 1280 end, getHeight = function() return 720 end,
    newFont = function()
      return setmetatable({ getWidth = function() return 8 end, getHeight = function() return 8 end },
                          { __index = dummy() })
    end, newCanvas = function() return dummy() end,
  }),
  keyboard = stub({ isDown = function() return false end }),
  mouse = stub({ getPosition = function() return mouse_x, mouse_y end, isDown = function() return false end }),
  window = stub({ getFullscreen = function() return false end }),
  timer = stub({ getTime = function() return 1.5 end, getFPS = function() return 60 end }),
  math = { random = function(a, b)
    if a and b then return math.random(a, b) elseif a then return math.random(a) end
    return math.random() end },
  filesystem = stub({ getInfo = function() return nil end, write = function() return true end,
                      getSaveDirectory = function() return "/tmp" end }),
  audio = stub(), sound = stub(), event = stub({ quit = function() end }),
}
math.randomseed(tonumber(arg and arg[1]) or 42)
dofile("main.lua")
love.load({})
local function key(k) love.keypressed(k) end
local function frame() love.update(1 / 60); love.draw() end
-- giro nei menu: personaggi (scorri, prova a comprare), obiettivi, poi Gioca
for _, k in ipairs({ "down", "return", "right", "down", "return", "left", "up", "return", "escape",
                     "down", "return", "down", "escape", "up", "up" }) do
  key(k); frame()
end
-- mouse nei menu: passa sopra e clicca, rotella negli obiettivi
for _, pt in ipairs({ { 640, 330 }, { 640, 400 }, { 100, 100 } }) do
  love.mousemoved(pt[1], pt[2]); frame()
end
key("down"); key("return"); frame()                 -- personaggi
love.mousemoved(900, 500); love.mousepressed(900, 500, 1); frame()
love.mousepressed(60, 30, 1); frame()               -- indietro
key("down"); key("return"); frame(); love.wheelmoved(0, -1); frame(); key("escape")
key("up"); key("up")
for _ = 1, 30 do frame() end
key("return")
key("f1")
for _ = 1, 5 do key("f10") end
key("return")
local frames, rounds = 0, {}
local Debug = require("src.debug")
local Render = require("src.render")
local zmin_seen, zmax_seen = 9, 0
-- conta gli eventi visti, per sapere quali effetti sono stati disegnati
local Fx = require("src.fx")
local seen = {}
local orig_handle = Fx.handle
Fx.handle = function(e, g) seen[e.type] = (seen[e.type] or 0) + 1; return orig_handle(e, g) end
for i = 1, 60 * 60 * 8 do
  love.update(1 / 60)
  love.draw()
  frames = i
  local Cam = Render.cam
  if Cam.world then
    local hw, hh = Render.W / (2 * Cam.z), Render.H / (2 * Cam.z)
    assert(Cam.x - hw >= -0.5 and Cam.x + hw <= Cam.world.width + 0.5, "telecamera fuori mappa in x")
    assert(Cam.y - hh >= -0.5 and Cam.y + hh <= Cam.world.height + 0.5, "telecamera fuori mappa in y")
    zmin_seen, zmax_seen = math.min(zmin_seen, Cam.z), math.max(zmax_seen, Cam.z)
  end
  if i == 200 then key("f3"); key("f8"); key("down"); key("right"); key("f9"); key("f7"); key("f8") end
  if i == 260 then key("f3") end
  -- ogni 5 secondi dai a tutti un'arma diversa, cosi' si disegnano tutte
  if i % 300 == 0 then
    local data = require("src.sim.data")
    local g = _G.__smoke_game and _G.__smoke_game()
    if g and g.players then
      for k, p in ipairs(g.players) do
        if p.alive then
          local id = data.weapon_order[((i / 300 + k) % #data.weapon_order) + 1]
          p.weapon = g:make_weapon(id, "epic")
        end
      end
    end
  end
  -- forza gli stati speciali ogni tanto, per disegnarli tutti
  if i % 300 == 150 then
    local g = __smoke_game()
    if g and g.players then
      local Combat = require("src.sim.combat")
      local p = g.players[1 + (i / 300) % #g.players]
      if p and p.alive then
        p.bubble, p.burn = 60, 60
        Combat.hit(g, g.players[1], p, { dmg = 1, kb = 0, effect = "bubble" })
      end
      local q = g.players[1 + ((i / 300) + 1) % #g.players]
      if q and q.alive then q.grapple = { x = q.x + 60, y = q.y - 40, t = 20 } end
    end
  end
  if i % 90 == 0 then
    love.mousemoved(300 + (i % 700), 200 + (i % 300))
    love.mousepressed(300, 300, 1 + (i % 2))
  end
  if i == 400 then key("f5"); love.update(1 / 60); key("f6"); love.update(1 / 60); key("f5") end
end
print(string.format("smoke ok, frame %d, zoom tra %.2f e %.2f", frames, zmin_seen, zmax_seen))
local list = {}
for _, k in ipairs({ "ignite", "bubbled", "pop", "block", "catch", "grapple", "mine_set", "mine_armed",
                     "blackhole", "explosion", "bounce" }) do
  list[#list + 1] = k .. "=" .. (seen[k] or 0)
end
print("eventi: " .. table.concat(list, " "))
