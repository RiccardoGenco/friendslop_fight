-- Party Game (prototipo) - punto di ingresso LÖVE.
-- Avvio:        love .
-- Test:         love . test
-- Controlli, strumenti di debug e struttura: vedi README.md

local data = require("src.sim.data")
local Game = require("src.sim.game")
local Input = require("src.input")
local Render = require("src.render")
local Fx = require("src.fx")
local Audio = require("src.audio")
local Sprites = require("src.sprites")
local Debug = require("src.debug")
local Bot = require("src.bot")
local Profile = require("src.profile")
local Menu = require("src.menu")
local Heroes = require("src.heroes")
local Look = require("src.look")

local lg = love.graphics

local STEP = data.dt
local state = "menu"         -- menu | lobby | game | pause | matchend
local pause_reason = nil
local game
local canvas
local acc, time = 0, 0
local slow_frames = 0        -- rallentatore dopo l'ultimo colpo del round
local menu_msg = nil
local screen = { ox = 0, oy = 0, s = 2 }   -- trasformazione schermo -> coordinate virtuali

-- ---------------------------------------------------------------------------

function love.load(args)
  if args and args[1] == "test" then
    local ok, run = pcall(require, "tests.run_tests")
    if not ok then
      print("impossibile caricare i test: " .. tostring(run))
      love.event.quit(1)
      return
    end
    local failed = run()
    love.event.quit(failed > 0 and 1 or 0)
    return
  end

  lg.setDefaultFilter("nearest", "nearest")
  canvas = lg.newCanvas(Render.W * Render.SS, Render.H * Render.SS)
  canvas:setFilter("nearest", "nearest")
  Render.load()
  Audio.load()
  Sprites.load()
  Profile.load()
  Menu.apply_settings()
  love.mouse.setVisible(false)
end

-- accesso alla partita per la prova a secco (tests/smoke_love.lua)
function __smoke_game() return game end

local function new_seed()
  return math.floor(os.time() + love.timer.getTime() * 1000) % 2147483646
end

local ensure_loadouts
local menu_press_result

local function is_human(id)
  local s = Input.slots[id]
  return s ~= nil and s.kind ~= "bot"
end

local function start_game()
  ensure_loadouts()
  game = Game.new({ players = Input.count(), seed = new_seed() })
  Look.loadout = {}
  for i, s in ipairs(Input.slots) do Look.loadout[i] = { hero = s.hero, skin = s.skin } end
  Profile.start_match()
  Fx.reset()
  Input.clear_pending()
  acc, slow_frames = 0, 0
  state = "game"
end

-- Con meno di 2 giocatori aggiunge dei bot (e la tastiera 1 se non c'e' nessuno)
local function fill_and_start()
  if Input.count() == 0 then Input.add_keyboard(1) end
  while Input.count() < 3 do Input.add_bot() end
  start_game()
end

-- ---------------------------------------------------------------------------
-- Scelta del personaggio nella lobby (solo tra quelli sbloccati)

local function cycle_hero(s, d)
  local hs = {}
  for _, h in ipairs(Heroes.list) do if Profile.hero_owned(h) or s.kind == "bot" then hs[#hs + 1] = h end end
  local cur = 1
  for i, h in ipairs(hs) do if h.id == s.hero then cur = i end end
  local h = hs[(cur - 1 + d) % #hs + 1]
  s.hero, s.skin = h.id, 1
end

local function cycle_skin(s, d)
  local h = Heroes.get(s.hero)
  local i = s.skin
  for _ = 1, #h.skins do
    i = (i - 1 + d) % #h.skins + 1
    if Profile.skin_owned(h, i) then s.skin = i return end
  end
end

local function hero_taken(s)
  for _, o in ipairs(Input.slots) do
    if o ~= s and o.hero == s.hero and o.kind ~= "bot" then return true end
  end
  return false
end

function ensure_loadouts()
  for _, s in ipairs(Input.slots) do
    if not s.hero then
      if s.kind == "bot" then
        local h = Heroes.list[love.math.random(#Heroes.list)]
        s.hero, s.skin = h.id, 1
      else
        local fav = Profile.data.fav
        local h = Heroes.get(fav.hero)
        if Profile.skin_owned(h, fav.skin) then s.hero, s.skin = h.id, fav.skin
        else s.hero, s.skin = "gatto", 1 end
        for _ = 1, #Heroes.list do
          if not hero_taken(s) then break end
          cycle_hero(s, 1)
        end
      end
    end
  end
end

local function lobby_slot_press(s, b)
  if not s or s.kind == "bot" or b == "ok" or b == "back" then return end
  Audio.play("ui_move", (b == "left" or b == "right") and 0.9 or 1.1, 0.7)
  if b == "left" then cycle_hero(s, -1) elseif b == "right" then cycle_hero(s, 1)
  elseif b == "up" then cycle_skin(s, -1) elseif b == "down" then cycle_skin(s, 1) end
end

local function to_menu()
  Audio.play("ui_back", 1, 0.7)
  state = "menu"
  Menu.open("main")
end

function menu_press_result(r)
  if r == "play" then
    state = "lobby"
    Audio.play("ui_join", 1, 0.7)
    Input.clear_pending()
  elseif r == "quit" then
    love.event.quit()
  end
end

local function menu_press(b) menu_press_result(Menu.press(b)) end

-- levetta sinistra nei menu: un passo per ogni spinta
local stick_prev = {}
local function poll_menu_sticks()
  if not (love.joystick and love.joystick.getJoysticks) then return end
  for _, j in ipairs(love.joystick.getJoysticks()) do
    if j:isGamepad() then
      local x, y = j:getGamepadAxis("leftx"), j:getGamepadAxis("lefty")
      local dir = nil
      if y < -0.6 then dir = "up" elseif y > 0.6 then dir = "down"
      elseif x < -0.6 then dir = "left" elseif x > 0.6 then dir = "right" end
      if dir and stick_prev[j] ~= dir then
        if state == "menu" then menu_press(dir)
        elseif state == "lobby" then
          for _, s in ipairs(Input.slots) do if s.joy == j then lobby_slot_press(s, dir) end end
        end
      end
      stick_prev[j] = dir
    end
  end
end

local function to_lobby()
  state = "lobby"
  game = nil
  Fx.reset()
  menu_msg = nil
end

local function step()
  local inputs = {}
  for i, s in ipairs(Input.slots) do
    if s.kind == "bot" then
      inputs[i] = Bot.think(game, i)
    else
      inputs[i] = Input.consume(s)
      -- tastiera 1: mira col mouse (se il mouse e' stato usato)
      if s.kind == "kb" and s.kb == 1 and Input.mouse.active then
        local p = game.players[i]
        if p and p.alive then
          local vx = (Input.mouse.x - screen.ox) / screen.s
          local vy = (Input.mouse.y - screen.oy) / screen.s
          local wx, wy = Render.to_world(vx, vy)
          local dx, dy = wx - p.x, wy - (p.y - 12)
          local len = math.sqrt(dx * dx + dy * dy)
          if len > 4 then inputs[i].ax, inputs[i].ay = dx / len, dy / len end
        end
      end
    end
  end
  game:update(inputs)
  for _, e in ipairs(game:drain_events()) do
    Fx.handle(e, game)
    Profile.event(e, is_human)
    if e.type == "round_end" then slow_frames = 80 end
  end
  Fx.track(game)
  if slow_frames > 0 then slow_frames = slow_frames - 1 end
  if game.phase == "matchend" then state = "matchend" end
end

-- ---------------------------------------------------------------------------

function love.update(dt)
  dt = math.min(dt, 0.1)
  time = time + dt
  Input.poll()
  Debug.update(dt)
  Profile.update(dt)
  Menu.update(dt)
  Audio.update_music(dt, state == "menu" or state == "lobby" or state == "matchend")
  poll_menu_sticks()

  if state == "menu" then
    -- niente: il menu reagisce ai tasti
  elseif state == "lobby" then
    ensure_loadouts()
    if Input.start_pressed() and Input.count() >= 1 then fill_and_start() end
  elseif state == "game" then
    if Input.start_pressed() then
      state, pause_reason = "pause", "pausa"
    elseif Input.any_disconnected() then
      state, pause_reason = "pause", "disconnesso"
    elseif Debug.paused then
      if Debug.consume_step() then step() end
    else
      local scale = 1
      if Debug.slowmo then scale = 0.25 end
      if slow_frames > 0 then scale = math.min(scale, 0.4) end
      acc = math.min(acc + dt * scale, 0.25)
      while acc >= STEP do
        -- hitstop: per qualche frame il mondo si ferma, poi riparte
        if Fx.freeze > 0 then Fx.freeze = Fx.freeze - 1 else step() end
        acc = acc - STEP
        if state ~= "game" then break end
      end
    end
    if game then Render.update_camera(game, dt) end
  elseif state == "pause" then
    if Input.start_pressed() and not Input.any_disconnected() then
      state = "game"
      Input.clear_pending()
    end
  elseif state == "matchend" then
    local _ = Input.start_pressed()
    Render.update_camera(game, dt)
    -- l'animazione continua per qualche istante
    game:update({})
    game:drain_events()
  end
  Fx.update(dt)
end

-- ---------------------------------------------------------------------------
-- Schermate

local function draw_lobby()
  local W, H = Render.W, Render.H
  Look.sky({ name = "Tetti" }, time, W, H)
  Render.text("SCEGLI IL COMBATTENTE", W / 2, 10, { 1, 0.9, 0.3 }, "big", "center", W)
  for i = 1, 6 do
    local x = 28 + ((i - 1) % 3) * 200
    local y = 54 + math.floor((i - 1) / 3) * 110
    local s = Input.slots[i]
    local c = data.colors[i]
    lg.setColor(c[1], c[2], c[3], s and 1 or 0.18)
    lg.rectangle("fill", x, y, 184, 102, 6, 6)
    lg.setColor(0.03, 0.03, 0.07, s and 0.82 or 0.75)
    lg.rectangle("fill", x + 2, y + 2, 180, 98, 5, 5)
    if s and s.hero then
      local h = Heroes.get(s.hero)
      lg.setColor(0, 0, 0, 0.4)
      lg.ellipse("fill", x + 40, y + 90, 22, 4)
      Menu.draw_hero(s.hero, s.skin, x + 40, y + 90, 3, c, time, false, 1, i)
      Render.text(data.color_names[i], x + 80, y + 8, c, "mid", "left", 100)
      Render.text(h.name, x + 80, y + 30, { 1, 1, 1 }, "small", "left", 100)
      Render.text(h.skins[s.skin].name, x + 80, y + 42, { 0.7, 0.75, 0.9 }, "small", "left", 100)
      Render.text(s.name or "", x + 80, y + 60, { 0.55, 0.55, 0.65 }, "small", "left", 100)
      if s.kind ~= "bot" then
        Render.text("<> eroe   su/giu skin", x + 80, y + 84, { 0.5, 0.55, 0.7 }, "small", "left", 100)
      end
    else
      Render.text("libero", x + 92, y + 42, { 0.5, 0.5, 0.6 }, "mid", "center", 184)
    end
  end

  local n = Input.count()
  local msg = (n >= 2 and "START (o Invio) per iniziare")
    or (n == 1 and "START (o Invio): parti da solo contro 2 bot")
    or "Invio: tastiera + 2 bot   oppure premi un tasto del controller"
  Render.text(msg, W / 2, 280, { 0.5, 1, 0.5 }, "mid", "center", W)
  Render.text("F1/F2 tastiera   F10 bot   Backspace togli   Esc menu   Tastiera 1: A D W S   Tastiera 2: frecce",
    W / 2, 304, { 0.6, 0.7, 0.9 }, "small", "center", W)
  Render.text("In gioco: F3 hitbox  F4 slow  F5 pausa  F6 frame  F7 ricarica dati  F8 taratura",
    W / 2, 318, { 0.5, 0.6, 0.75 }, "small", "center", W)
  if menu_msg then Render.text(menu_msg, W / 2, 340, { 1, 0.6, 0.4 }, "small", "center", W) end
end

local function draw_overlay_pause()
  local W, H = Render.W, Render.H
  lg.setColor(0, 0, 0, 0.6)
  lg.rectangle("fill", 0, 0, W, H)
  if pause_reason == "disconnesso" then
    local i, s = Input.any_disconnected()
    Render.text("CONTROLLER SCOLLEGATO", W / 2, H / 2 - 30, { 1, 0.5, 0.4 }, "mid", "center", W)
    Render.text((s and s.name or "") .. " (giocatore " .. tostring(i) .. ")", W / 2, H / 2 - 6, { 1, 1, 1 }, "small", "center", W)
    Render.text("Ricollegalo per continuare", W / 2, H / 2 + 10, { 0.8, 0.8, 0.9 }, "small", "center", W)
  else
    Render.text("PAUSA", W / 2, H / 2 - 30, { 1, 0.9, 0.3 }, "big", "center", W)
    Render.text("START o Esc per riprendere   -   Q torna alla lobby", W / 2, H / 2 + 10, { 0.8, 0.8, 0.9 }, "small", "center", W)
  end
end

local function draw_overlay_matchend()
  local W, H = Render.W, Render.H
  lg.setColor(0, 0, 0, 0.55)
  lg.rectangle("fill", 0, 0, W, H)
  local names = {}
  for _, id in ipairs(game.match_winners or {}) do names[#names + 1] = data.color_names[id] end
  local c = game.match_winners and data.colors[game.match_winners[1]] or { 1, 1, 1 }
  Render.text("VINCE " .. string.upper(table.concat(names, " e ")) .. "!", W / 2, 90, c, "big", "center", W)
  for i = 1, #game.players do
    Render.text(data.color_names[i] .. ": " .. game.scores[i], W / 2, 140 + (i - 1) * 16, data.colors[i], "mid", "center", W)
  end
  local m = Profile.match
  if m then
    Render.text("+" .. m.coins .. " monete   (totale " .. Profile.data.coins .. ")", W / 2, 236, { 1, 0.85, 0.3 }, "mid", "center", W)
    if #m.unlocked > 0 then
      Render.text("Obiettivi: " .. table.concat(m.unlocked, ", "), W / 2, 258, { 0.5, 1, 0.6 }, "small", "center", W)
    end
  end
  Render.text("A / Invio: rivincita      B / Esc: lobby", W / 2, 285, { 0.9, 0.9, 1 }, "small", "center", W)
end

-- mirino del mouse (tastiera 1)
local function draw_crosshair()
  if not (Input.mouse.active and Input.has_keyboard(1)) then return end
  local x = (Input.mouse.x - screen.ox) / screen.s
  local y = (Input.mouse.y - screen.oy) / screen.s
  lg.setColor(1, 1, 1, 0.9)
  lg.rectangle("fill", x - 5, y - 0.5, 3, 1)
  lg.rectangle("fill", x + 2, y - 0.5, 3, 1)
  lg.rectangle("fill", x - 0.5, y - 5, 1, 3)
  lg.rectangle("fill", x - 0.5, y + 2, 1, 3)
  lg.setColor(1, 1, 1, 1)
end

function love.draw()
  if not canvas then return end
  lg.setCanvas(canvas)
  lg.clear(0, 0, 0, 1)
  lg.push()
  lg.scale(Render.SS)
  if state == "menu" then
    Menu.draw(time)
    if Input.mouse.active then
      local x, y = (Input.mouse.x - screen.ox) / screen.s, (Input.mouse.y - screen.oy) / screen.s
      lg.setColor(0, 0, 0, 0.8)
      lg.polygon("fill", x - 1, y - 1, x + 9, y + 8, x + 4, y + 9, x + 1, y + 13)
      lg.setColor(1, 0.95, 0.85)
      lg.polygon("fill", x, y, x + 7, y + 7, x + 3, y + 7, x + 1, y + 11)
    end
  elseif state == "lobby" then
    draw_lobby()
  elseif game then
    lg.push()
    local ox, oy = Fx.offset()
    lg.translate(ox, oy)
    Render.game(game, time)
    lg.pop()
    if state == "pause" then draw_overlay_pause() end
    if state == "matchend" then draw_overlay_matchend() end
    Debug.draw(game, love.timer.getFPS())
    draw_crosshair()
  end
  if state ~= "menu" then Menu.draw_toasts(Render.W) end
  lg.pop()
  lg.setCanvas()

  local cw, ch = Render.W * Render.SS, Render.H * Render.SS
  local sw, sh = lg.getDimensions()
  local s = math.min(sw / cw, sh / ch)
  if s >= 1 and Profile.data.settings.pixel_perfect then s = math.floor(s) end
  local ox = math.floor((sw - cw * s) / 2)
  local oy = math.floor((sh - ch * s) / 2)
  screen = { ox = ox, oy = oy, s = s * Render.SS }   -- da pixel dello schermo a coordinate virtuali
  lg.clear(0, 0, 0, 1)
  lg.setColor(1, 1, 1, 1)
  lg.draw(canvas, ox, oy, 0, s, s)
end

-- ---------------------------------------------------------------------------
-- Eventi

local function to_virtual(x, y)
  return (x - screen.ox) / screen.s, (y - screen.oy) / screen.s
end

function love.mousemoved(x, y)
  Input.mouse.x, Input.mouse.y = x, y
  Input.mouse.active = true
  if state == "menu" then Menu.pointer(to_virtual(x, y)) end
end

function love.wheelmoved(_, dy)
  if state == "menu" and dy ~= 0 then Menu.wheel(dy) end
end

function love.mousepressed(x, y, button)
  Input.mouse.x, Input.mouse.y = x, y
  Input.mouse.active = true
  if state == "menu" then
    local vx, vy = to_virtual(x, y)
    local r = Menu.click(vx, vy, button)
    if r == "play" then menu_press_result("play") elseif r == "quit" then love.event.quit() end
    return
  end
  Input.mouse_button(button)
end

function love.joystickadded(joy)
  Input.joystick_added(joy)
end

function love.joystickremoved(joy)
  Input.joystick_removed(joy)
end

local GAMEPAD_MENU = { dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
                       a = "ok", start = "ok", b = "back", back = "back" }

function love.gamepadpressed(joy, button)
  local b = GAMEPAD_MENU[button]
  if not b then return end
  if state == "menu" then
    menu_press(b)
  elseif state == "lobby" then
    for _, s in ipairs(Input.slots) do
      if s.joy == joy and s.join_t ~= time then lobby_slot_press(s, b) end
    end
  end
end

function love.joystickpressed(joy, button)
  if state == "menu" then return end
  if state == "lobby" then
    if not Input.has_joystick(joy) then
      if joy:isGamepad() then
        local s = Input.add_joystick(joy)
        if s then s.join_t = time; Audio.play("ui_join", 1, 0.7) end
        menu_msg = nil
      else
        menu_msg = "Controller non riconosciuto come gamepad standard (SDL)"
      end
    elseif joy:isGamepadDown("b") then
      Input.remove_joystick(joy)
    end
  elseif state == "matchend" then
    if joy:isGamepadDown("a") then start_game()
    elseif joy:isGamepadDown("b") then to_lobby() end
  end
end

function love.keypressed(key)
  if state == "game" or state == "pause" then
    if Debug.keypressed(key) then return end
  end
  if key == "f11" then
    Profile.data.settings.fullscreen = not love.window.getFullscreen()
    Menu.apply_settings()
    Profile.save()
    return
  end
  if state == "menu" then
    local map = { up = "up", w = "up", down = "down", s = "down", left = "left", a = "left",
                  right = "right", d = "right", ["return"] = "ok", space = "ok", escape = "back", backspace = "back" }
    if map[key] then menu_press(map[key]) end
    return
  end
  if state == "lobby" then
    local kb1 = { a = "left", d = "right", w = "up", s = "down" }
    local kb2 = { left = "left", right = "right", up = "up", down = "down" }
    for _, sl in ipairs(Input.slots) do
      if sl.kb == 1 and kb1[key] then lobby_slot_press(sl, kb1[key]) end
      if sl.kb == 2 and kb2[key] then lobby_slot_press(sl, kb2[key]) end
    end
    if key == "f1" or key == "f2" or key == "f10" then Audio.play("ui_join", 1, 0.7) end
    if key == "f1" then Input.add_keyboard(1)
    elseif key == "f2" then Input.add_keyboard(2)
    elseif key == "f10" then Input.add_bot()
    elseif key == "backspace" then Input.remove_last()
    elseif key == "return" then
      if Input.count() >= 2 then start_game() else fill_and_start() end
    elseif key == "escape" then to_menu() end
  elseif state == "game" then
    if key == "escape" then state, pause_reason = "pause", "pausa" end
  elseif state == "pause" then
    if key == "escape" and not Input.any_disconnected() then
      state = "game"
      Input.clear_pending()
    elseif key == "q" then to_lobby() end
  elseif state == "matchend" then
    if key == "return" then start_game()
    elseif key == "escape" then to_lobby() end
  end
end
