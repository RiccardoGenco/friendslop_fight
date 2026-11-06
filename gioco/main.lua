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
local pause_sel = 1
local match_stats = {}       -- per giocatore: eliminazioni e morti della partita
local PAUSE_ITEMS = { "Riprendi", "Volume", "Torna alla lobby", "Menu principale" }
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
  fit_canvas()
  Render.load()
  Audio.load()
  Sprites.load()
  Profile.load()
  Menu.apply_settings()
  love.mouse.setVisible(false)
  if args and args[1] == "shot" then
    __shot = require("src.shot")
    __shot.start(args)
  end
end

-- accesso alla partita per la prova a secco (tests/smoke_love.lua)
function __smoke_game() return game end

local function new_seed()
  return math.floor(os.time() + love.timer.getTime() * 1000) % 2147483646
end

local ensure_loadouts

-- vibrazione del controller del giocatore id (se e' un controller e l'opzione e' attiva)
local function rumble(id, strength, dur)
  if not Profile.data.settings.vibration then return end
  local s = Input.slots[id]
  if s and s.kind == "pad" and s.joy and s.joy.setVibration then
    pcall(s.joy.setVibration, s.joy, strength, strength, dur)
  end
end

local function rumble_event(e)
  local t = e.type
  if t == "hit" and not e.light then
    rumble(e.id, math.min(1, 0.3 + (e.dmg or 10) / 60), 0.12)
  elseif t == "death" then
    rumble(e.id, 1, 0.4)
    if e.killer and e.killer ~= e.id then rumble(e.killer, 0.45, 0.12) end
  elseif t == "perfect_parry" or t == "parry" then
    rumble(e.id, t == "perfect_parry" and 0.6 or 0.35, 0.1)
  elseif t == "explosion" or t == "lightning" then
    for _, p in ipairs(game.players) do
      local dx, dy = p.x - e.x, p.y - e.y
      if p.alive and dx * dx + dy * dy < 120 * 120 then rumble(p.id, 0.6, 0.2) end
    end
  end
end
local menu_press_result
local pause_press

local function is_human(id)
  local s = Input.slots[id]
  return s ~= nil and s.kind ~= "bot"
end

local function start_game()
  ensure_loadouts()
  game = Game.new({ players = Input.count(), seed = new_seed(), maps = __force_maps })
  Look.loadout = {}
  for i, s in ipairs(Input.slots) do Look.loadout[i] = { hero = s.hero, skin = s.skin } end
  local has_bot = false
  for _, sl in ipairs(Input.slots) do if sl.kind == "bot" then has_bot = true end end
  Profile.start_match(has_bot and Profile.data.settings.bot_level == 3)
  match_stats = {}
  for i = 1, Input.count() do match_stats[i] = { kills = 0, deaths = 0 } end
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
      inputs[i] = Bot.think(game, i, Profile.data.settings.bot_level)
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
    if e.type == "fused" and Profile.is_new_recipe(e, is_human) then
      -- prima scoperta di una ricetta speciale: rallentatore e nome a tutto schermo
      e.first = true
      slow_frames = math.max(slow_frames, 45)
    end
    Fx.handle(e, game)
    Profile.event(e, is_human)
    rumble_event(e)
    if e.type == "death" then
      local v = match_stats[e.id]
      if v then v.deaths = v.deaths + 1 end
      local k = e.killer and e.killer ~= e.id and match_stats[e.killer]
      if k then k.kills = k.kills + 1 end
    end
    if e.type == "round_end" then slow_frames = 80 end
  end
  Fx.track(game)
  Profile.after_step(game, is_human)
  if slow_frames > 0 then slow_frames = slow_frames - 1 end
  if game.phase == "matchend" then state = "matchend" end
end

-- ---------------------------------------------------------------------------

function love.update(dt)
  if __shot then __shot.update(); dt = 1 / 60 end
  dt = math.min(dt, 0.1)
  time = time + dt
  Input.poll()
  Debug.update(dt)
  Profile.update(dt)
  Menu.update(dt)
  local mode = (state == "menu" or state == "lobby" or state == "matchend") and "menu"
    or ((state == "game" or state == "pause") and "battle") or nil
  Audio.update_music(dt, mode, game and game.lava_on, state == "pause")
  poll_menu_sticks()

  if state == "menu" then
    -- niente: il menu reagisce ai tasti
  elseif state == "lobby" then
    ensure_loadouts()
    if Input.start_pressed() and Input.count() >= 1 then fill_and_start() end
  elseif state == "game" then
    if Input.start_pressed() then
      state, pause_reason, pause_sel = "pause", "pausa", 1
      Audio.play("ui_ok", 1, 0.7)
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
      Menu.draw_hero(s.hero, s.skin, x + 40, y + 92, 2.4, c, time, false, 1, i)
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
  Render.text(msg, W / 2, 282, { 0.5, 1, 0.5 }, "mid", "center", W)
  local lv = Bot.LEVELS[Profile.data.settings.bot_level] or Bot.LEVELS[2]
  local lc = ({ { 0.5, 1, 0.6 }, { 1, 0.85, 0.3 }, { 1, 0.45, 0.4 } })[Profile.data.settings.bot_level] or { 1, 1, 1 }
  Render.text("Bot: " .. lv.name .. "   (Tab o Select per cambiare)", W / 2, 268, lc, "small", "center", W)
  Render.text("F1/F2 tastiera   F10 bot   Backspace togli   Esc menu   Tastiera 1: A D W S   Tastiera 2: frecce",
    W / 2, 304, { 0.6, 0.7, 0.9 }, "small", "center", W)
  Render.text("In gioco: F3 hitbox  F4 slow  F5 pausa  F6 frame  F7 ricarica dati  F8 taratura",
    W / 2, 318, { 0.5, 0.6, 0.75 }, "small", "center", W)
  if menu_msg then Render.text(menu_msg, W / 2, 340, { 1, 0.6, 0.4 }, "small", "center", W) end
end

local function draw_overlay_pause()
  local W, H = Render.W, Render.H
  lg.setColor(0.03, 0.02, 0.08, 0.7)
  lg.rectangle("fill", 0, 0, W, H)
  if pause_reason == "disconnesso" then
    local i, s = Input.any_disconnected()
    Render.text("CONTROLLER SCOLLEGATO", W / 2, H / 2 - 30, { 1, 0.5, 0.4 }, "mid", "center", W)
    Render.text((s and s.name or "") .. " (giocatore " .. tostring(i) .. ")", W / 2, H / 2 - 6, { 1, 1, 1 }, "small", "center", W)
    Render.text("Ricollegalo per continuare", W / 2, H / 2 + 10, { 0.8, 0.8, 0.9 }, "small", "center", W)
    return
  end
  local pw, ph = 240, 170
  local px, py = W / 2 - pw / 2, H / 2 - ph / 2
  lg.setColor(0, 0, 0, 0.4); lg.rectangle("fill", px + 3, py + 4, pw, ph, 8, 8)
  lg.setColor(0.11, 0.10, 0.20, 0.96); lg.rectangle("fill", px, py, pw, ph, 8, 8)
  lg.setColor(1, 0.82, 0.28, 0.6); lg.rectangle("line", px + 0.5, py + 0.5, pw - 1, ph - 1, 8, 8)
  Render.text("PAUSA", W / 2, py + 8, { 1, 0.85, 0.3 }, "big", "center", pw)
  for i, label in ipairs(PAUSE_ITEMS) do
    local y = py + 50 + (i - 1) * 28
    local on = i == pause_sel
    if on then
      lg.setColor(1, 0.82, 0.28, 0.9); lg.rectangle("fill", px + 16, y - 3, pw - 32, 22, 5, 5)
    else
      lg.setColor(1, 1, 1, 0.06); lg.rectangle("fill", px + 16, y - 3, pw - 32, 22, 5, 5)
    end
    local tc = on and { 0.06, 0.05, 0.12 } or { 0.92, 0.93, 1 }
    if label == "Volume" then
      local v = Profile.data.settings.master
      Render.text("Volume", px + 26, y + 1, tc, "mid", "left", 100)
      lg.setColor(tc[1], tc[2], tc[3], 0.35); lg.rectangle("fill", px + 116, y + 6, 80, 5, 2, 2)
      lg.setColor(tc[1], tc[2], tc[3]); lg.rectangle("fill", px + 116, y + 6, 80 * v, 5, 2, 2)
      Render.text(math.floor(v * 100 + 0.5) .. "%", px + 200, y + 3, tc, "small", "left", 40)
    else
      Render.text(label, W / 2, y + 1, tc, "mid", "center", pw)
    end
  end
  Render.text("Su/giu scegli   sinistra/destra volume   Invio/A conferma   Esc/B riprendi",
    W / 2, py + ph + 10, { 0.6, 0.62, 0.8 }, "small", "center", W)
end

-- podio di fine partita: eroi in ordine di punteggio, statistiche, monete
local function draw_overlay_matchend()
  local W, H = Render.W, Render.H
  lg.setColor(0.03, 0.02, 0.08, 0.78)
  lg.rectangle("fill", 0, 0, W, H)
  local order = {}
  for i = 1, #game.players do order[#order + 1] = i end
  table.sort(order, function(a, b)
    if game.scores[a] ~= game.scores[b] then return game.scores[a] > game.scores[b] end
    local ka, kb = match_stats[a] and match_stats[a].kills or 0, match_stats[b] and match_stats[b].kills or 0
    if ka ~= kb then return ka > kb end
    return a < b
  end)
  local wid = order[1]
  local wc = data.colors[wid]
  local lo = Look.loadout[wid] or { hero = "gatto", skin = 1 }
  Render.text("VINCE " .. string.upper(Heroes.get(lo.hero).name) .. "!", W / 2, 10, wc, "big", "center", W)
  -- coriandoli
  for i = 1, 70 do
    local cx = (i * 73.1 + math.sin(time + i) * 20) % W
    local cy = (i * 41.7 + time * (40 + (i % 7) * 12)) % H
    local c = data.colors[(i % 6) + 1]
    lg.setColor(c[1], c[2], c[3], 0.8)
    lg.push(); lg.translate(cx, cy); lg.rotate(time * 3 + i); lg.rectangle("fill", -2, -1, 4, 2); lg.pop()
  end
  -- podio: secondo a sinistra, primo al centro, terzo a destra
  local slots = { { x = W / 2, h = 70 }, { x = W / 2 - 110, h = 46 }, { x = W / 2 + 110, h = 30 } }
  local base = 250
  for place = 1, math.min(3, #order) do
    local id = order[place]
    local sl = slots[place]
    local c = data.colors[id]
    local l2 = Look.loadout[id] or { hero = "gatto", skin = 1 }
    lg.setColor(0.13, 0.12, 0.22); lg.rectangle("fill", sl.x - 46, base - sl.h, 92, sl.h, 4, 4)
    lg.setColor(c[1], c[2], c[3]); lg.rectangle("fill", sl.x - 46, base - sl.h, 92, 4, 2, 2)
    Render.text(tostring(place), sl.x, base - sl.h + 10, { 1, 0.85, 0.3 }, "big", "center", 92)
    local jump = place == 1 and math.abs(math.sin(time * 4)) * 10 or 0
    Menu.draw_hero(l2.hero, l2.skin, sl.x, base - sl.h - jump, 3, c, time, place == 1 and (jump > 2 and "jump" or false) or false, 1, id)
    local st = match_stats[id] or { kills = 0, deaths = 0 }
    Render.text(game.scores[id] .. " round   " .. st.kills .. " elim.", sl.x, base + 4, c, "small", "center", 120)
  end
  -- gli altri in riga
  for place = 4, #order do
    local id = order[place]
    local st = match_stats[id] or { kills = 0, deaths = 0 }
    local l2 = Look.loadout[id] or { hero = "gatto", skin = 1 }
    local x = W / 2 + (place - 5) * 150
    Heroes.draw_head(l2.hero, l2.skin, x - 60, 270, 1)
    Render.text(place .. ". " .. Heroes.get(l2.hero).name .. "  " .. game.scores[id] .. " round " .. st.kills .. " elim.",
      x - 40, 272, data.colors[id], "small", "left", 140)
  end
  local m = Profile.match
  if m then
    Render.text("+" .. m.coins .. " monete   (totale " .. Profile.data.coins .. ")", W / 2, 292, { 1, 0.85, 0.3 }, "mid", "center", W)
    if #m.unlocked > 0 then
      Render.text("Obiettivi: " .. table.concat(m.unlocked, ", "), W / 2, 312, { 0.5, 1, 0.6 }, "small", "center", W)
    end
  end
  Render.text("A / Invio: rivincita      B / Esc: lobby", W / 2, 334, { 0.9, 0.9, 1 }, "small", "center", W)
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

-- La canvas segue la risoluzione dello schermo: a 1080p e' 1920x1080, a 1440p 2560x1440, ecc.
-- Cosi' si disegna gia' alla misura giusta e non si ingrandisce un'immagine piccola.
-- Con "Scala pixel perfetta" la densita' resta un numero intero (bordi neri se serve).
function fit_canvas()
  local sw, sh = lg.getDimensions()
  local ss = math.max(1, math.min(sw / Render.W, sh / Render.H))
  if Profile.data and Profile.data.settings and Profile.data.settings.pixel_perfect then ss = math.max(1, math.floor(ss)) end
  if __shot then ss = 2 end   -- screenshot di prova sempre uguali
  local cw, ch = math.floor(Render.W * ss + 0.5), math.floor(Render.H * ss + 0.5)
  if canvas and Render.SS == ss then return end
  Render.SS = ss
  canvas = lg.newCanvas(cw, ch)
  canvas:setFilter("nearest", "nearest")
end

function love.resize() fit_canvas() end

function love.draw()
  fit_canvas()
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

  local cw, ch = math.floor(Render.W * Render.SS + 0.5), math.floor(Render.H * Render.SS + 0.5)
  local sw, sh = lg.getDimensions()
  local s = math.min(sw / cw, sh / ch)
  if s >= 1 and Profile.data.settings.pixel_perfect then s = math.floor(s) end
  local ox = math.floor((sw - cw * s) / 2)
  local oy = math.floor((sh - ch * s) / 2)
  screen = { ox = ox, oy = oy, s = s * Render.SS }   -- da pixel dello schermo a coordinate virtuali
  lg.clear(0, 0, 0, 1)
  lg.setColor(1, 1, 1, 1)
  lg.draw(canvas, ox, oy, 0, s, s)
  if __shot then __shot.after_draw(canvas) end
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

function pause_press(b)
  if pause_reason == "disconnesso" then return end
  if b == "up" or b == "down" then
    pause_sel = (pause_sel - 1 + (b == "up" and -1 or 1)) % #PAUSE_ITEMS + 1
    Audio.play("ui_move", 1, 0.7)
  elseif (b == "left" or b == "right") and PAUSE_ITEMS[pause_sel] == "Volume" then
    local st = Profile.data.settings
    st.master = math.floor(math.max(0, math.min(1, st.master + (b == "left" and -0.1 or 0.1))) * 10 + 0.5) / 10
    Menu.apply_settings()
    Audio.play("ui_move", 0.8 + 0.4 * st.master, 0.7)
  elseif b == "back" or (b == "ok" and pause_sel == 1) then
    Profile.save()
    state = "game"
    Input.clear_pending()
    Audio.play("ui_back", 1, 0.7)
  elseif b == "ok" then
    local it = PAUSE_ITEMS[pause_sel]
    Profile.save()
    if it == "Torna alla lobby" then to_lobby(); Audio.play("ui_back", 1, 0.7)
    elseif it == "Menu principale" then to_lobby(); to_menu() end
  end
end

local GAMEPAD_MENU = { dpup = "up", dpdown = "down", dpleft = "left", dpright = "right",
                       a = "ok", start = "ok", b = "back", back = "back" }

function love.gamepadpressed(joy, button)
  local b = GAMEPAD_MENU[button]
  if not b then return end
  if state == "menu" then
    menu_press(b)
  elseif state == "pause" then
    if button ~= "start" then pause_press(b) end
  elseif state == "lobby" then
    if button == "back" then
      local st = Profile.data.settings
      st.bot_level = st.bot_level % 3 + 1
      Audio.play("ui_move", 0.8 + 0.2 * st.bot_level, 0.7)
      Profile.save()
      return
    end
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
    if key == "tab" then
      local st = Profile.data.settings
      st.bot_level = st.bot_level % 3 + 1
      Audio.play("ui_move", 0.8 + 0.2 * st.bot_level, 0.7)
      Profile.save()
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
    if key == "escape" then state, pause_reason, pause_sel = "pause", "pausa", 1; Audio.play("ui_ok", 1, 0.7) end
  elseif state == "pause" then
    local map = { up = "up", w = "up", down = "down", s = "down", left = "left", a = "left",
                  right = "right", d = "right", ["return"] = "ok", space = "ok", escape = "back" }
    if key == "q" then to_lobby()
    elseif map[key] then pause_press(map[key]) end
  elseif state == "matchend" then
    if key == "return" then start_game()
    elseif key == "escape" then to_lobby() end
  end
end
