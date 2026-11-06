-- Menu principale, galleria dei personaggi (skin e acquisti) e obiettivi.
-- Comandi astratti: up down left right ok back (tastiera e controller, vedi main.lua)
-- piu' il mouse: passandoci sopra si seleziona, il click attiva.

local Render = require("src.render")
local Heroes = require("src.heroes")
local Profile = require("src.profile")
local Look = require("src.look")
local Audio = require("src.audio")
local data = require("src.sim.data")
local Fusion = require("src.sim.fusion")
local Recipes = require("src.sim.recipes")

local lg = love.graphics
local floor, sin, cos, min, max, abs = math.floor, math.sin, math.cos, math.min, math.max, math.abs

local Menu = {
  screen = "main", sel = 1, hero = 1, skin = 1, scroll = 0, scroll_f = 0,
  shake = 0, flash = 0, trans = 1, dir = 1, coins_f = nil, coin_bump = 0,
  anim = {}, hits = {}, mx = -1, my = -1, pose_t = 0, focus = "skins",
}

local ITEMS = {
  { id = "play", label = "GIOCA", sub = "2-6 giocatori, ultimo in piedi vince" },
  { id = "heroes", label = "PERSONAGGI", sub = "eroi, skin e negozio" },
  { id = "recipes", label = "RICETTARIO", sub = "fusioni e ricette scoperte" },
  { id = "achievements", label = "OBIETTIVI", sub = "sfide e ricompense" },
  { id = "settings", label = "IMPOSTAZIONI", sub = "audio e video" },
  { id = "quit", label = "ESCI", sub = "a presto" },
}

-- palette dell'interfaccia
local UI = {
  gold = { 1, 0.82, 0.28 }, gold_d = { 0.62, 0.42, 0.10 }, coral = { 1, 0.42, 0.36 },
  ink = { 0.06, 0.05, 0.12 }, panel = { 0.11, 0.10, 0.20 }, panel_l = { 0.18, 0.16, 0.30 },
  text = { 0.92, 0.93, 1 }, dim = { 0.58, 0.60, 0.76 }, green = { 0.45, 1, 0.6 }, red = { 1, 0.45, 0.4 },
}
local SKY = { name = "Tetti" }

local function sfx(name, pitch) Audio.play(name, pitch or 1, 0.7) end

local function ease(cur, target, dt, speed) return cur + (target - cur) * min(1, dt * (speed or 14)) end
local function setc(c, a) lg.setColor(c[1], c[2], c[3], a or c[4] or 1) end
local function lerpc(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end

-- ---------------------------------------------------------------------------
-- Impostazioni

local SETTINGS = {
  { header = "AUDIO" },
  { key = "master", label = "Volume generale", kind = "slider" },
  { key = "music", label = "Musica", kind = "slider" },
  { key = "sfx", label = "Effetti sonori", kind = "slider" },
  { header = "VIDEO" },
  { key = "fullscreen", label = "Schermo intero", kind = "toggle" },
  { key = "vsync", label = "Sincronia verticale (vsync)", kind = "toggle" },
  { key = "pixel_perfect", label = "Scala pixel perfetta", kind = "toggle" },
  { key = "shake", label = "Scosse dello schermo", kind = "slider" },
  { key = "flash", label = "Lampi a schermo", kind = "slider" },
  { key = "vibration", label = "Vibrazione controller", kind = "toggle" },
  { key = "reset", label = "Ripristina predefinite", kind = "action" },
}
local SEL_ROWS = {}
for i, r in ipairs(SETTINGS) do if not r.header then SEL_ROWS[#SEL_ROWS + 1] = i end end

-- applica volumi, finestra ed effetti; da chiamare dopo ogni modifica
function Menu.apply_settings()
  local st = Profile.data.settings
  Audio.sfx_vol = st.master * st.sfx
  Audio.music_mul = st.master * st.music
  local Fx = require("src.fx")
  Fx.shake_mul, Fx.flash_mul = st.shake, st.flash
  local w = love.window
  if w and w.getFullscreen then
    pcall(function()
      if w.getFullscreen() ~= st.fullscreen then w.setFullscreen(st.fullscreen, "desktop") end
      if w.getVSync and w.setVSync and (w.getVSync() ~= 0) ~= st.vsync then w.setVSync(st.vsync and 1 or 0) end
    end)
  end
end

local function set_setting(row, value)
  local st = Profile.data.settings
  if row.kind == "slider" then
    value = math.floor(max(0, min(1, value)) * 10 + 0.5) / 10
    if value == st[row.key] then return end
    st[row.key] = value
  elseif row.kind == "toggle" then
    st[row.key] = value
  end
  Menu.apply_settings()
  sfx("ui_move", 0.8 + 0.4 * (type(value) == "number" and value or 1))
end

local function settings_press(b)
  local row = SETTINGS[SEL_ROWS[Menu.sel]]
  local st = Profile.data.settings
  if b == "up" or b == "down" then
    Menu.sel = (Menu.sel - 1 + (b == "up" and -1 or 1)) % #SEL_ROWS + 1
    sfx("ui_move")
  elseif b == "left" or b == "right" then
    local d = b == "left" and -1 or 1
    if row.kind == "slider" then set_setting(row, st[row.key] + d * 0.1)
    elseif row.kind == "toggle" then set_setting(row, d > 0) end
  elseif b == "ok" then
    if row.kind == "toggle" then set_setting(row, not st[row.key])
    elseif row.kind == "action" then
      for k, v in pairs(Profile.DEFAULT_SETTINGS) do st[k] = v end
      Menu.apply_settings()
      Menu.flash = 0.3
      sfx("ui_ok")
    end
  elseif b == "back" then
    Profile.save()
    sfx("ui_back")
    Menu.open("main", -1)
  end
end

-- ---------------------------------------------------------------------------
-- Navigazione

function Menu.open(screen, dir)
  local prev = Menu.screen
  Menu.screen, Menu.sel = screen or "main", 1
  Menu.trans, Menu.dir = 0, dir or 1
  Menu.anim = {}
  if Menu.screen == "heroes" then
    local fav = Profile.data.fav
    Menu.hero = Heroes.get(fav.hero).index
    Menu.skin = fav.skin or 1
    Menu.pose_t = 0
  elseif Menu.screen == "main" then
    for i, it in ipairs(ITEMS) do if it.id == prev then Menu.sel = i end end
  end
end

local function fail()
  Menu.shake = 0.35
  sfx("ui_error")
end

local function hero_step(d)
  Menu.hero = (Menu.hero - 1 + d) % #Heroes.list + 1
  Menu.skin, Menu.pose_t = 1, 0
  sfx("ui_move", 0.9)
end

local function skin_step(d)
  local h = Heroes.list[Menu.hero]
  Menu.skin = (Menu.skin - 1 + d) % #h.skins + 1
  Menu.pose_t = 0
  sfx("ui_move", 1.1)
end

local function hero_action()
  local h = Heroes.list[Menu.hero]
  if Profile.skin_owned(h, Menu.skin) then
    local fav = Profile.data.fav
    if fav.hero == h.id and fav.skin == Menu.skin then sfx("ui_ok") return end
    Profile.data.fav = { hero = h.id, skin = Menu.skin }
    Profile.save()
    Menu.flash = 0.4
    sfx("ui_ok")
  elseif Profile.buy(h, Menu.skin) then
    Menu.flash, Menu.coin_bump = 0.6, 0.5
    sfx("ui_coin")
  else
    fail()
  end
end

-- ritorna "play" o "quit" quando il menu passa la mano a main
function Menu.press(b)
  local s = Menu.screen
  if s == "main" then
    if b == "up" or b == "down" then
      Menu.sel = (Menu.sel - 1 + (b == "up" and -1 or 1)) % #ITEMS + 1
      sfx("ui_move")
    elseif b == "ok" then
      local id = ITEMS[Menu.sel].id
      sfx("ui_ok")
      if id == "play" or id == "quit" then return id end
      Menu.open(id, 1)
    elseif b == "back" then
      if Menu.sel ~= #ITEMS then Menu.sel = #ITEMS; sfx("ui_back") end
    end
  elseif s == "heroes" then
    if b == "left" then hero_step(-1)
    elseif b == "right" then hero_step(1)
    elseif b == "up" then skin_step(-1)
    elseif b == "down" then skin_step(1)
    elseif b == "ok" then hero_action()
    elseif b == "back" then sfx("ui_back"); Menu.open("main", -1) end
  elseif s == "settings" then
    settings_press(b)
  elseif s == "recipes" then
    -- due pagine: ricette speciali (lista) e griglia delle fusioni normali
    if b == "left" or b == "right" then
      Menu.page = (Menu.page or 1) == 1 and 2 or 1
      Menu.scroll, Menu.scroll_f = 0, 0
      sfx("ui_move")
    elseif b == "up" and (Menu.page or 1) == 1 and Menu.scroll > 0 then Menu.scroll = Menu.scroll - 1; sfx("ui_move")
    elseif b == "down" and (Menu.page or 1) == 1 and Menu.scroll < #Recipes - 6 then Menu.scroll = Menu.scroll + 1; sfx("ui_move")
    elseif b == "back" or b == "ok" then sfx("ui_back"); Menu.open("main", -1) end
  elseif s == "achievements" then
    local maxs = max(0, #Profile.ACHIEVEMENTS - 6)
    if b == "up" and Menu.scroll > 0 then Menu.scroll = Menu.scroll - 1; sfx("ui_move")
    elseif b == "down" and Menu.scroll < maxs then Menu.scroll = Menu.scroll + 1; sfx("ui_move")
    elseif b == "back" or b == "ok" then sfx("ui_back"); Menu.open("main", -1) end
  end
end

-- ---------------------------------------------------------------------------
-- Mouse (coordinate virtuali 640x360)

local function hit_at(x, y)
  for i = #Menu.hits, 1, -1 do
    local h = Menu.hits[i]
    if x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h then return h end
  end
end

function Menu.pointer(x, y)
  local moved = abs(x - Menu.mx) + abs(y - Menu.my) > 0.5
  Menu.mx, Menu.my = x, y
  if not moved then return end
  local h = hit_at(x, y)
  if h and h.hover then h.hover() end
end

function Menu.click(x, y, button)
  if button == 2 then return Menu.press("back") end
  local h = hit_at(x, y)
  if h and h.click then return h.click() end
end

function Menu.wheel(dy)
  if Menu.screen == "achievements" or Menu.screen == "recipes" then Menu.press(dy > 0 and "up" or "down")
  elseif Menu.screen == "heroes" then skin_step(dy > 0 and -1 or 1) end
end

local function hit(x, y, w, h, hover, click)
  Menu.hits[#Menu.hits + 1] = { x = x, y = y, w = w, h = h, hover = hover, click = click }
end

-- ---------------------------------------------------------------------------

function Menu.update(dt)
  Menu.shake = max(0, Menu.shake - dt)
  Menu.flash = max(0, Menu.flash - dt)
  Menu.coin_bump = max(0, Menu.coin_bump - dt)
  Menu.trans = min(1, Menu.trans + dt * 4)
  Menu.pose_t = Menu.pose_t + dt
  Menu.scroll_f = ease(Menu.scroll_f, Menu.scroll, dt, 12)
  local c = Profile.data.coins
  Menu.coins_f = Menu.coins_f or c
  if abs(Menu.coins_f - c) < 0.5 then Menu.coins_f = c
  else Menu.coins_f = ease(Menu.coins_f, c, dt, 6) end
  for k, v in pairs(Menu.anim) do Menu.anim[k] = ease(v, Menu.anim_target[k] or 0, dt, 16) end
  Menu.anim_target = {}
end
Menu.anim_target = {}

-- valore animato 0..1 legato a una chiave (selezione dei pulsanti)
local function anim(key, on)
  Menu.anim_target[key] = on and 1 or 0
  Menu.anim[key] = Menu.anim[key] or 0
  return Menu.anim[key]
end

-- ---------------------------------------------------------------------------
-- Elementi grafici

local function fake(id, time, pose)
  local p = { x = 0, y = 0, facing = 1, vx = 0, vy = 0, grounded = true, id = id }
  if pose == "run" then p.vx = 120
  elseif pose == "jump" then p.grounded, p.vy = false, -120
  elseif pose == "fall" then p.grounded, p.vy = false, 120 end
  return p, { dist = time * 120 }
end

-- disegna un eroe ingrandito con i piedi in (x, y); run puo' essere true o il nome di una posa
function Menu.draw_hero(hid, skin, x, y, scale, team, time, run, alpha, id)
  lg.push()
  lg.translate(x, y)
  lg.scale(scale)
  local pose = (run == true) and "run" or run
  local p, ps = fake(id or 1, time, pose)
  Heroes.draw(hid, skin, p, team or data.colors[1], alpha or 1, false, time, ps)
  lg.pop()
end

local function panel(x, y, w, h, alpha, border)
  alpha = alpha or 1
  lg.setColor(0, 0, 0, 0.35 * alpha)
  lg.rectangle("fill", x + 3, y + 4, w, h, 7, 7)
  setc(UI.panel, 0.92 * alpha)
  lg.rectangle("fill", x, y, w, h, 7, 7)
  lg.setColor(1, 1, 1, 0.05 * alpha)
  lg.rectangle("fill", x + 3, y + 3, w - 6, h * 0.4, 5, 5)
  setc(border or UI.panel_l, alpha)
  lg.setLineWidth(1)
  lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 7, 7)
end

local function coin_icon(x, y, r, t)
  local sq = abs(cos((t or 0) * 3))            -- moneta che gira
  setc(UI.gold_d); lg.ellipse("fill", x, y + 1, r * max(0.25, sq), r)
  setc(UI.gold); lg.ellipse("fill", x, y, r * max(0.25, sq), r)
  lg.setColor(1, 1, 0.8, 0.9); lg.rectangle("fill", x - r * 0.3 * sq, y - r * 0.5, max(1, r * 0.25 * sq), r * 0.6)
end

local function lock_icon(x, y, a)
  lg.setColor(0, 0, 0, 0.6 * a); lg.rectangle("fill", x - 5, y - 1, 12, 10, 2, 2)
  lg.setColor(0.85, 0.85, 0.95, a)
  lg.setLineWidth(2); lg.arc("line", "open", x + 1, y - 1, 3.5, math.pi, 2 * math.pi); lg.setLineWidth(1)
  lg.rectangle("fill", x - 4, y - 1, 10, 8, 2, 2)
  lg.setColor(0.2, 0.2, 0.3, a); lg.rectangle("fill", x, y + 2, 2, 3)
end

local function trophy(x, y, done, t)
  local c = done and UI.gold or { 0.35, 0.35, 0.45 }
  local bob = done and floor(sin(t * 3 + x) * 1 + 0.5) or 0
  y = y + bob
  setc(UI.ink); lg.rectangle("fill", x - 8, y - 9, 16, 19, 3, 3)
  setc(c); lg.polygon("fill", x - 6, y - 7, x + 6, y - 7, x + 4, y + 1, x - 4, y + 1)
  lg.rectangle("fill", x - 1, y + 1, 2, 4); lg.rectangle("fill", x - 4, y + 5, 8, 2)
  lg.setLineWidth(1); lg.circle("line", x - 6, y - 4, 2.5); lg.circle("line", x + 6, y - 4, 2.5)
  if done then lg.setColor(1, 1, 1, 0.7); lg.rectangle("fill", x - 4, y - 6, 2, 4) end
end

-- pulsante: k = animazione di selezione 0..1
local function button(x, y, w, h, label, k, accent, font, alpha)
  alpha = alpha or 1
  local lift = -2 * k
  accent = accent or UI.gold
  lg.setColor(0, 0, 0, 0.45 * alpha)
  lg.rectangle("fill", x + 2, y + 4, w, h, 6, 6)
  local base = lerpc(UI.panel, accent, 0.18 + 0.82 * k)
  setc(lerpc(base, { 0, 0, 0 }, 0.35), alpha)
  lg.rectangle("fill", x, y + 2 + lift, w, h, 6, 6)       -- bordo inferiore (spessore)
  setc(base, alpha)
  lg.rectangle("fill", x, y + lift, w, h - 2, 6, 6)
  lg.setColor(1, 1, 1, (0.10 + 0.15 * k) * alpha)
  lg.rectangle("fill", x + 3, y + lift + 2, w - 6, 3, 2, 2)
  if k > 0.05 then
    lg.setColor(1, 1, 1, 0.8 * k * alpha)
    lg.rectangle("line", x + 0.5, y + lift + 0.5, w - 1, h - 3, 6, 6)
  end
  local tc = lerpc(UI.text, UI.ink, k)
  Render.text(label, x + w / 2, y + lift + (h - 2) / 2 - (font == "small" and 4 or 8), { tc[1], tc[2], tc[3], alpha },
    font or "mid", "center", w)
end

local function title(W, y, time)
  local word1, word2 = "FRIENDSLOP", "FIGHT"
  local f = Render.font("big")
  lg.setFont(f)
  local function wave(word, cx, yy, c1, c2, delay)
    local tw = f:getWidth(word)
    local x = cx - tw / 2
    for i = 1, #word do
      local ch = word:sub(i, i)
      local cw = f:getWidth(ch)
      local dy = sin(time * 3 - i * 0.45 + delay) * 2.5
      local c = lerpc(c1, c2, (sin(time * 2 + i * 0.6) + 1) / 2)
      lg.setColor(UI.ink[1], UI.ink[2], UI.ink[3]); lg.print(ch, floor(x) + 2, floor(yy + dy) + 3)
      lg.setColor(0, 0, 0, 0.7); lg.print(ch, floor(x) - 1, floor(yy + dy))
      setc(c); lg.print(ch, floor(x), floor(yy + dy))
      x = x + cw
    end
  end
  wave(word1, W / 2, y, UI.gold, { 1, 0.95, 0.65 }, 0)
  wave(word2, W / 2, y + 30, UI.coral, { 1, 0.65, 0.4 }, 1.5)
  -- stelline attorno
  for i = 1, 4 do
    local a = time * 1.5 + i * 1.57
    local sx, sy = W / 2 + cos(a) * 150, y + 30 + sin(a * 1.3) * 26
    local tw = (sin(time * 5 + i) + 1) / 2
    lg.setColor(1, 0.95, 0.7, 0.5 + 0.5 * tw)
    lg.rectangle("fill", sx - 2 * tw, sy, 1 + 4 * tw, 1)
    lg.rectangle("fill", sx, sy - 2 * tw, 1, 1 + 4 * tw)
  end
end

local function coins_box(W, time)
  local k = Menu.coin_bump / 0.5
  local x, y = W - 104, 8
  panel(x, y, 96, 22, 1, k > 0 and UI.gold or nil)
  coin_icon(x + 13, y + 11, 6, time)
  local s = 1 + 0.25 * k
  lg.push()
  lg.translate(x + 26, y + 3)
  lg.scale(s)
  Render.text(tostring(floor(Menu.coins_f or Profile.data.coins)), 0, 0, UI.gold, "mid", "left", 70)
  lg.pop()
end

local function toasts(W)
  local t = Profile.toasts[1]
  if not t then return end
  local k = min(1, t.t * 3, (3 - t.t) * 5)
  local ek = 1 - (1 - k) ^ 3
  local y = -24 + 34 * ek
  local w = 320
  panel(W / 2 - w / 2, y, w, 22, k, t.color)
  lg.setColor(t.color[1], t.color[2], t.color[3], k)
  lg.rectangle("fill", W / 2 - w / 2 + 4, y + 4, 3, 14, 1, 1)
  Render.text(t.text, W / 2, y + 7, { t.color[1], t.color[2], t.color[3], k }, "small", "center", w - 20)
end

-- quando compare un avviso nuovo suona una fanfara
local last_toast = nil
local function toast_sound()
  local t = Profile.toasts[1]
  if t and t ~= last_toast then sfx("ui_unlock") end
  last_toast = t
end
function Menu.draw_toasts(W) toast_sound(); toasts(W) end

local function background(time, W, H)
  Look.sky(SKY, time, W, H)
  -- tre file di palazzi in parallasse
  local rows = { { 0.07, 0.07, 0.17, 12, 90 }, { 0.055, 0.05, 0.13, 22, 60 }, { 0.04, 0.035, 0.09, 40, 35 } }
  for r, row in ipairs(rows) do
    local off = (time * row[4]) % 400
    for i = -1, 22 do
      local bx = i * 36 - off % 36
      local wi = math.floor((time * row[4] + i * 36) / 36)
      bh = row[5] + ((wi * 7 + r * 13) * 37) % 60
      lg.setColor(row[1], row[2], row[3])
      lg.rectangle("fill", bx, H - 52 - bh, 32, bh)
      for wy = H - 46 - bh, H - 60, 9 do
        if ((wi * 31 + wy * 7 + r) % 5) == 0 then
          lg.setColor(1, 0.8, 0.45, 0.25 + 0.1 * r)
          lg.rectangle("fill", bx + 6 + (wy % 3) * 7, wy, 3, 4)
        end
      end
    end
  end
  -- tetto in primo piano
  lg.setColor(0.10, 0.09, 0.18); lg.rectangle("fill", 0, H - 52, W, 52)
  lg.setColor(0.32, 0.30, 0.40); lg.rectangle("fill", 0, H - 52, W, 3)
  lg.setColor(0.16, 0.15, 0.26)
  for x = -((time * 70) % 24), W, 24 do lg.rectangle("fill", x, H - 44, 12, 2) end
  -- vignettatura
  for i = 0, 5 do
    lg.setColor(0, 0, 0, 0.06)
    lg.rectangle("fill", 0, 0, W, 10 + i * 6)
    lg.rectangle("fill", 0, H - 6 - i * 4, W, 6 + i * 4)
  end
end

local function footer(text, W, H)
  lg.setColor(0, 0, 0, 0.45)
  lg.rectangle("fill", 0, H - 18, W, 18)
  Render.text(text, W / 2, H - 14, UI.dim, "small", "center", W)
end

local function back_button(time)
  local on = Menu.mx >= 8 and Menu.mx <= 74 and Menu.my >= 8 and Menu.my <= 30
  local k = anim("back", on)
  button(8, 8, 66, 22, "< ESC", k, UI.coral, "small")
  hit(8, 8, 66, 22, nil, function() Menu.press("back") end)
end

-- ---------------------------------------------------------------------------
-- Schermate

local function draw_main(time, W, H)
  -- parata degli eroi sul tetto, ognuno con la sua ombra
  for i, h in ipairs(Heroes.list) do
    local x = (time * 70 + i * 118) % (W + 160) - 80
    local jump = ((time * 0.7 + i * 0.37) % 3) < 0.35
    local jy = jump and -sin(((time * 0.7 + i * 0.37) % 3) / 0.35 * math.pi) * 18 or 0
    lg.setColor(0, 0, 0, 0.35)
    lg.ellipse("fill", x, H - 51, 12 + jy * 0.2, 3)
    Menu.draw_hero(h.id, 1, x, H - 52 + jy, 2, data.colors[i], time + i, jump and "jump" or "run", 1, i)
  end
  title(W, 18, time)
  for i, it in ipairs(ITEMS) do
    local y = 98 + (i - 1) * 30
    local on = i == Menu.sel
    local k = anim("item" .. i, on)
    local w = 200 + 20 * k
    local x = W / 2 - w / 2
    -- entrata a cascata dopo la transizione
    local enter = min(1, max(0, Menu.trans * 4 - i * 0.4))
    local a = enter
    x = x + (1 - enter) * 40 * Menu.dir
    button(x, y, w, 26, it.label, k, i == #ITEMS and UI.coral or UI.gold, "mid", a)
    if k > 0.05 then
      local ax = x - 14 - sin(time * 8) * 2
      lg.setColor(UI.gold[1], UI.gold[2], UI.gold[3], k)
      lg.polygon("fill", ax, y + 6, ax + 8, y + 12, ax, y + 18)
      lg.polygon("fill", x + w + 14 + sin(time * 8) * 2, y + 6, x + w + 6 + sin(time * 8) * 2, y + 12,
        x + w + 14 + sin(time * 8) * 2, y + 18)
    end
    hit(x, y, w, 26, function() if Menu.sel ~= i then Menu.sel = i; sfx("ui_move") end end,
      function() Menu.sel = i; return Menu.press("ok") end)
  end
  local it = ITEMS[Menu.sel]
  Render.text(it.sub, W / 2, 98 + #ITEMS * 30 + 2, UI.dim, "small", "center", W)   -- sotto l'ultimo pulsante
  Render.text("v0.12", 8, H - 30, { 0.4, 0.4, 0.55 }, "small", "left", 60)
  footer("Frecce / WASD / croce: muovi    Invio / A / click: scegli    Esc / B: indietro", W, H)
end

local POSES = { "idle", "run", "jump", "fall", "idle", "run" }

local function draw_heroes(time, W, H)
  local h = Heroes.list[Menu.hero]
  local owned_h = Profile.hero_owned(h)
  local owned = Profile.skin_owned(h, Menu.skin)
  Render.text("PERSONAGGI", W / 2, 6, UI.gold, "big", "center", W)

  -- palco con riflettore
  local px = 160 + (Menu.shake > 0 and sin(Menu.shake * 70) * 4 or 0)
  local py = 252
  lg.setBlendMode("add")
  lg.setColor(1, 0.9, 0.6, 0.06)
  lg.polygon("fill", px - 20, 40, px + 20, 40, px + 95, py, px - 95, py)
  lg.setColor(1, 0.9, 0.6, 0.05)
  lg.polygon("fill", px - 10, 40, px + 10, 40, px + 60, py, px - 60, py)
  lg.setBlendMode("alpha")
  setc(UI.ink); lg.ellipse("fill", px, py + 6, 82, 14)
  setc(UI.panel_l); lg.ellipse("fill", px, py + 2, 80, 12)
  setc(UI.panel); lg.ellipse("fill", px, py, 74, 10)
  lg.setColor(1, 0.85, 0.3, 0.25 + 0.15 * sin(time * 3)); lg.ellipse("line", px, py, 74, 10)
  lg.setColor(0, 0, 0, 0.4); lg.ellipse("fill", px, py, 26, 4)
  local pose = POSES[floor(Menu.pose_t / 2.2) % #POSES + 1]
  local jy = 0
  if pose == "jump" then jy = -10 elseif pose == "fall" then jy = -6 end
  local intro = min(1, Menu.pose_t * 5)
  local sc = 5 * (0.85 + 0.15 * (1 - (1 - intro) ^ 3))
  if owned then
    Menu.draw_hero(h.id, Menu.skin, px, py + jy * sc / 5, sc, data.colors[1], time, pose, 1, 1)
  else
    Menu.draw_hero(h.id, Menu.skin, px, py, sc, data.colors[1], time, "idle", 0.35, 1)
    lock_icon(px, py - 70, 1)
  end
  if Menu.flash > 0 then
    lg.setBlendMode("add")
    lg.setColor(1, 1, 0.8, Menu.flash)
    lg.circle("fill", px, py - 60, 70 * (1.2 - Menu.flash))
    lg.setBlendMode("alpha")
  end
  -- frecce per cambiare eroe
  for _, d in ipairs({ -1, 1 }) do
    local ax = px + d * (100 + sin(time * 6) * 2)
    local on = abs(Menu.mx - ax) < 14 and abs(Menu.my - 150) < 18
    local k = anim("arrow" .. d, on)
    lg.setColor(UI.gold[1], UI.gold[2], UI.gold[3], 0.5 + 0.5 * k)
    lg.polygon("fill", ax + d * 8, 150, ax - d * 4, 140 - 3 * k, ax - d * 4, 160 + 3 * k)
    hit(ax - 14, 132, 28, 36, nil, function() hero_step(d) end)
  end

  -- scheda a destra
  local x, y0, w = 300, 44, 316
  panel(x, y0, w, 230)
  Render.text(h.name, x + 14, y0 + 8, UI.text, "mid", "left", w)
  Render.text(string.upper(h.title), x + 14, y0 + 28, UI.coral, "small", "left", w)
  lg.setColor(1, 1, 1, 0.08); lg.rectangle("fill", x + 14, y0 + 42, w - 28, 1)
  for i, s in ipairs(h.skins) do
    local y = y0 + 52 + (i - 1) * 34
    local on = i == Menu.skin
    local k = anim("skin" .. i, on)
    setc(lerpc(UI.panel, UI.panel_l, 0.4 + 0.6 * k))
    lg.rectangle("fill", x + 10 + 4 * k, y, w - 20, 30, 5, 5)
    if k > 0.05 then
      lg.setColor(UI.gold[1], UI.gold[2], UI.gold[3], k)
      lg.rectangle("fill", x + 10 + 4 * k, y + 4, 3, 22, 1, 1)
    end
    -- miniatura della skin
    local sown = Profile.skin_owned(h, i)
    Menu.draw_hero(h.id, i, x + 34 + 4 * k, y + 28, 0.7, data.colors[1], time, false, sown and 1 or 0.35, i)
    Render.text(s.name, x + 54 + 4 * k, y + 4, on and UI.gold or UI.text, "mid", "left", 140)
    local lock, price = Profile.lock_text(h, i)
    if not lock then
      local fav = Profile.data.fav
      local is_fav = fav.hero == h.id and fav.skin == i
      Render.text(is_fav and "PREFERITO" or "SBLOCCATA", x + 54 + 4 * k, y + 20, is_fav and UI.gold or UI.green, "small", "left", 140)
    elseif price then
      coin_icon(x + 58 + 4 * k, y + 24, 3.5, time)
      Render.text(tostring(price), x + 64 + 4 * k, y + 20,
        Profile.data.coins >= price and UI.gold or UI.red, "small", "left", 140)
    else
      Render.text(lock, x + 54 + 4 * k, y + 20, UI.dim, "small", "left", 220)
    end
    if not sown then lock_icon(x + w - 28, y + 12, 0.8) end
    hit(x + 10, y, w - 20, 30, function() if Menu.skin ~= i then Menu.skin, Menu.pose_t = i, 0; sfx("ui_move", 1.1) end end,
      function() if Menu.skin == i then hero_action() else Menu.skin, Menu.pose_t = i, 0; sfx("ui_move", 1.1) end end)
  end
  -- pulsante d'azione
  local label, accent = "PREFERITO", UI.green
  local fav = Profile.data.fav
  if owned then
    if not (fav.hero == h.id and fav.skin == Menu.skin) then label, accent = "SCEGLI", UI.gold end
  else
    local text, price = Profile.lock_text(h, Menu.skin)
    if price then
      label = (owned_h and "COMPRA SKIN " or "COMPRA EROE ") .. price
      accent = Profile.data.coins >= price and UI.gold or UI.red
    else
      label, accent = "BLOCCATA", { 0.45, 0.45, 0.55 }
    end
  end
  local bx, by, bw = x + 14, y0 + 190, w - 28
  local on = Menu.mx >= bx and Menu.mx <= bx + bw and Menu.my >= by and Menu.my <= by + 28
  local k = anim("action", true)
  button(bx, by, bw, 28, label, (0.7 + 0.3 * (on and 1 or sin(time * 4) * 0.5 + 0.5)) * k, accent, "mid")
  hit(bx, by, bw, 28, nil, hero_action)

  -- galleria in basso
  local n = #Heroes.list
  for i, hh in ipairs(Heroes.list) do
    local cx = W / 2 + (i - (n + 1) / 2) * 50
    local on = i == Menu.hero
    local kk = anim("card" .. i, on)
    local cy = 286 - 4 * kk
    setc(lerpc(UI.panel, UI.panel_l, kk)); lg.rectangle("fill", cx - 22, cy, 44, 44, 6, 6)
    if kk > 0.05 then lg.setColor(UI.gold[1], UI.gold[2], UI.gold[3], kk); lg.rectangle("line", cx - 22.5, cy - 0.5, 45, 45, 6, 6) end
    local own = Profile.hero_owned(hh)
    Menu.draw_hero(hh.id, 1, cx, cy + 41, 1.0, data.colors[1], time, on and "run" or false, own and 1 or 0.3, i)
    if not own then lock_icon(cx + 12, cy + 6, 0.9) end
    hit(cx - 22, cy, 44, 44, nil, function() if Menu.hero ~= i then hero_step(i - Menu.hero) end end)
  end
  footer("Sinistra/destra: eroe    Su/giu o rotella: skin    Invio/A: scegli o compra    Esc/B: indietro", W, H)
end

local function draw_achievements(time, W, H)
  Render.text("OBIETTIVI", W / 2, 6, UI.gold, "big", "center", W)
  local list = Profile.ACHIEVEMENTS
  local done_n = 0
  for _, a in ipairs(list) do if Profile.data.done[a.id] then done_n = done_n + 1 end end
  Render.text(done_n .. " / " .. #list .. " completati", W / 2, 40, UI.dim, "small", "center", W)
  local x, w = 50, W - 100
  lg.setScissor(0, 54 * Render.SS, Render.W * Render.SS, 270 * Render.SS)
  for i, a in ipairs(list) do
    local y = 56 + (i - 1 - Menu.scroll_f) * 44
    if y > 20 and y < 340 then
      local done = Profile.data.done[a.id]
      local enter = min(1, max(0, Menu.trans * 3 - (i - Menu.scroll) * 0.25))
      local ox = (1 - enter) * 30
      panel(x + ox, y, w, 38, enter, done and UI.gold_d or nil)
      trophy(x + ox + 20, y + 19, done, time)
      Render.text(a.name, x + ox + 40, y + 5, done and UI.gold or UI.text, "mid", "left", 260)
      Render.text(a.desc, x + ox + 40, y + 24, UI.dim, "small", "left", 300)
      -- ricompensa
      coin_icon(x + ox + w - 104, y + 10, 4, time)
      local reward = "+" .. a.coins
      for _, h in ipairs(Heroes.list) do
        for _, s in ipairs(h.skins) do if s.unlock == a.id then reward = reward .. " + skin" end end
      end
      Render.text(reward, x + ox + w - 96, y + 6, UI.gold, "small", "left", 100)
      -- barra di progresso
      local pr = Profile.progress(a)
      local bx, bw = x + ox + w - 200, 180
      setc(UI.ink); lg.rectangle("fill", bx, y + 24, bw, 7, 3, 3)
      local f = pr / a.goal * min(1, Menu.trans * 1.5)
      setc(done and UI.green or UI.gold); lg.rectangle("fill", bx, y + 24, max(4, bw * f), 7, 3, 3)
      lg.setColor(1, 1, 1, 0.3); lg.rectangle("fill", bx + 2, y + 25, max(0, bw * f - 4), 1)
      Render.text(done and "FATTO" or (pr .. "/" .. a.goal), bx - 60, y + 22, done and UI.green or UI.dim, "small", "right", 56)
    end
  end
  lg.setScissor()
  -- barra di scorrimento
  local maxs = max(1, #list - 6)
  lg.setColor(1, 1, 1, 0.1); lg.rectangle("fill", W - 38, 58, 3, 262, 1, 1)
  setc(UI.gold); lg.rectangle("fill", W - 38, 58 + 262 * (Menu.scroll_f / maxs) * (1 - 6 / #list), 3, 262 * 6 / #list, 1, 1)
  footer("Su/giu o rotella: scorri    Esc/B: indietro", W, H)
end

-- icona di un'arma ridotta, centrata in (x, y)
local function weapon_icon(id, x, y, scale, alpha)
  local d = data.weapons[id]
  lg.push()
  lg.translate(x, y)
  lg.scale(scale or 1)
  Render.draw_weapon_shape(id, d and d.color or { 1, 1, 1 }, true, alpha)
  lg.pop()
end

local function draw_recipes(time, W, H)
  Render.text("RICETTARIO", W / 2, 6, UI.gold, "big", "center", W)
  local found = Profile.data.recipes or {}
  local fusions = Profile.data.fusions or {}
  local page = Menu.page or 1
  -- schede delle due pagine
  local tabs = { "RICETTE SPECIALI", "FUSIONI NORMALI" }
  for i, t in ipairs(tabs) do
    local tx = W / 2 + (i == 1 and -86 or 86)
    local on = page == i
    local k = anim("rtab" .. i, on)
    button(tx - 80, 38, 160, 16, t, on and 1 or 0.15 * k, on and UI.gold or UI.dim, "small")
    hit(tx - 80, 38, 160, 16, nil, function() if page ~= i then Menu.press("right") end end)
  end
  if page == 1 then
    local n = 0
    for _, r in ipairs(Recipes) do if found[r.id] then n = n + 1 end end
    Render.text(n .. " / " .. #Recipes .. " scoperte", W / 2, 58, UI.dim, "small", "center", W)
    local x, w = 50, W - 100
    lg.setScissor(0, 70 * Render.SS, Render.W * Render.SS, 254 * Render.SS)
    for i, r in ipairs(Recipes) do
      local y = 72 + (i - 1 - Menu.scroll_f) * 42
      if y > 30 and y < 340 then
        local ok = found[r.id]
        local enter = min(1, max(0, Menu.trans * 3 - (i - Menu.scroll) * 0.25))
        local ox = (1 - enter) * 30
        panel(x + ox, y, w, 36, enter, ok and UI.gold_d or nil)
        -- ingredienti: se la ricetta manca se ne vede uno solo, come indizio
        weapon_icon(r.a, x + ox + 22, y + 18, 0.9, enter)
        Render.text("+", x + ox + 44, y + 12, UI.dim, "mid", "center", 20)
        if ok then weapon_icon(r.b, x + ox + 66, y + 18, 0.9, enter)
        else Render.text("?", x + ox + 66, y + 10, UI.dim, "mid", "center", 20) end
        Render.text(ok and r.name or "???", x + ox + 96, y + 4, ok and UI.gold or UI.text, "mid", "left", 300)
        local hint = ok and r.hint or ("Indizio: contiene " .. data.weapons[r.a].name:lower())
        Render.text(hint, x + ox + 96, y + 22, UI.dim, "small", "left", w - 110)
        if ok then
          lg.setColor(UI.green[1], UI.green[2], UI.green[3], enter)
          Render.text("SCOPERTA", x + ox + w - 70, y + 6, UI.green, "small", "left", 70)
        else
          coin_icon(x + ox + w - 52, y + 10, 4, time)
          Render.text("+" .. Profile.REWARD.recipe, x + ox + w - 44, y + 6, UI.gold, "small", "left", 60)
        end
      end
    end
    lg.setScissor()
    local maxs = max(1, #Recipes - 6)
    lg.setColor(1, 1, 1, 0.1); lg.rectangle("fill", W - 38, 74, 3, 246, 1, 1)
    setc(UI.gold); lg.rectangle("fill", W - 38, 74 + 246 * (Menu.scroll_f / maxs) * (1 - 6 / #Recipes), 3, 246 * 6 / #Recipes, 1, 1)
    footer("Sinistra/destra: pagina    Su/giu o rotella: scorri    Esc/B: indietro", W, H)
  else
    -- griglia corpo (righe) x donatore (colonne)
    local list, ids = Fusion.all_pairs()
    local n = 0
    for _, pr in ipairs(list) do if fusions[pr.body .. "+" .. pr.donor] then n = n + 1 end end
    Render.text(n .. " / " .. #list .. " fusioni normali scoperte   (oro: ricetta speciale)", W / 2, 58, UI.dim, "small", "center", W)
    -- legenda: corpo a sinistra, donatore in alto
    local cs = 10
    local gx = floor(W / 2 - #ids * cs / 2) + 24
    local gy = 96
    Render.text("in mano  v", gx - 80, gy - 12, UI.dim, "small", "left", 70)
    Render.text("raccolta  >", gx - 80, gy - 26, UI.dim, "small", "left", 70)
    local hover
    local hr, hc = -1, -1
    if Menu.mx >= gx and Menu.my >= gy then
      hc, hr = floor((Menu.mx - gx) / cs) + 1, floor((Menu.my - gy) / cs) + 1
    end
    -- armi raccolte in colonna (icone in verticale), armi in mano in riga
    for c, id in ipairs(ids) do
      lg.push(); lg.translate(gx + (c - 0.5) * cs, gy - 14); lg.rotate(-math.pi / 2)
      local d = data.weapons[id]
      lg.scale(0.55); Render.draw_weapon_shape(id, d.color, true, (c == hc) and 1 or 0.7); lg.pop()
    end
    for r, b in ipairs(ids) do
      weapon_icon(b, gx - 14, gy + (r - 0.5) * cs, 0.55, (r == hr) and 1 or 0.7)
      for c, d in ipairs(ids) do
        local x, y = gx + (c - 1) * cs, gy + (r - 1) * cs
        local recipe = Fusion.RECIPES[Fusion.recipe_key(b, d)]
        local got = recipe and found[recipe.id] or fusions[b .. "+" .. d]
        if recipe then
          if got then lg.setColor(1, 0.82, 0.3, 0.95) else lg.setColor(0.5, 0.4, 0.15, 0.6) end
        elseif got then
          local dc = data.weapons[d].color
          lg.setColor(dc[1], dc[2], dc[3], 0.9)
        else
          lg.setColor(0.16, 0.15, 0.26, 0.9)
        end
        lg.rectangle("fill", x + 1, y + 1, cs - 2, cs - 2, 2, 2)
        if Menu.mx >= x and Menu.mx < x + cs and Menu.my >= y and Menu.my < y + cs then
          hover = { b = b, d = d, got = got, recipe = recipe }
          lg.setColor(1, 1, 1, 0.9); lg.rectangle("line", x + 0.5, y + 0.5, cs - 1, cs - 1, 2, 2)
        end
      end
    end
    -- nome della casella sotto il mouse
    local label = "Passa col mouse su una casella"
    if hover then
      if hover.recipe then label = hover.got and hover.recipe.name or "??? (ricetta speciale)"
      elseif hover.got then label = Fusion.name(Fusion.fuse({ id = hover.b }, { id = hover.d }))
      else label = data.weapons[hover.b].name .. " + " .. data.weapons[hover.d].name .. ": da scoprire" end
    end
    Render.text(label, W / 2, gy + #ids * cs + 6, hover and UI.text or UI.dim, "small", "center", W)
    footer("Sinistra/destra: pagina    Mouse: nome della fusione    Esc/B: indietro", W, H)
  end
end

local function draw_settings(time, W, H)
  Render.text("IMPOSTAZIONI", W / 2, 6, UI.gold, "big", "center", W)
  local st = Profile.data.settings
  local x, w = 110, W - 220
  panel(x - 10, 44, w + 20, 272)
  local y = 50
  for i, row in ipairs(SETTINGS) do
    if row.header then
      Render.text(row.header, x + 4, y + 6, UI.coral, "small", "left", 200)
      lg.setColor(UI.coral[1], UI.coral[2], UI.coral[3], 0.3)
      lg.rectangle("fill", x + 50, y + 10, w - 54, 1)
      y = y + 18
    else
      local idx
      for k, v in ipairs(SEL_ROWS) do if v == i then idx = k end end
      local on = Menu.sel == idx
      local k = anim("set" .. i, on)
      setc(lerpc(UI.panel, UI.panel_l, 0.3 + 0.7 * k))
      lg.rectangle("fill", x, y, w, 21, 4, 4)
      if k > 0.05 then
        lg.setColor(UI.gold[1], UI.gold[2], UI.gold[3], k)
        lg.rectangle("fill", x, y + 3, 3, 15, 1, 1)
      end
      Render.text(row.label, x + 12 + 3 * k, y + 2, on and UI.gold or UI.text, "mid", "left", 260)
      local cx = x + w - 170
      if row.kind == "slider" then
        local v = st[row.key]
        local bw = 120
        setc(UI.ink); lg.rectangle("fill", cx, y + 8, bw, 6, 3, 3)
        setc(on and UI.gold or UI.dim); lg.rectangle("fill", cx, y + 8, max(4, bw * v), 6, 3, 3)
        lg.setColor(1, 1, 1); lg.circle("fill", cx + bw * v, y + 11, 4 + k)
        setc(UI.ink); lg.circle("line", cx + bw * v, y + 11, 4 + k)
        Render.text(floor(v * 100 + 0.5) .. "%", cx + bw + 10, y + 6, UI.dim, "small", "left", 40)
        local function from_mouse()
          if love.mouse and love.mouse.isDown and love.mouse.isDown(1) then
            set_setting(row, (Menu.mx - cx) / bw)
          end
        end
        hit(x, y, w, 21, function()
          if Menu.sel ~= idx then Menu.sel = idx; sfx("ui_move") end
          from_mouse()
        end, function()
          Menu.sel = idx
          if Menu.mx >= cx - 6 then set_setting(row, (Menu.mx - cx) / bw) end
        end)
      elseif row.kind == "toggle" then
        local v = st[row.key]
        local kk = anim("tog" .. i, v)
        setc(lerpc(UI.ink, UI.green, kk * 0.8)); lg.rectangle("fill", cx, y + 4, 34, 13, 6, 6)
        lg.setColor(1, 1, 1); lg.circle("fill", cx + 7 + 20 * kk, y + 10.5, 5)
        Render.text(v and "SI" or "NO", cx + 44, y + 6, v and UI.green or UI.dim, "small", "left", 40)
        hit(x, y, w, 21, function() if Menu.sel ~= idx then Menu.sel = idx; sfx("ui_move") end end,
          function() Menu.sel = idx; settings_press("ok") end)
      else
        Render.text("Invio", cx, y + 6, UI.dim, "small", "left", 80)
        hit(x, y, w, 21, function() if Menu.sel ~= idx then Menu.sel = idx; sfx("ui_move") end end,
          function() Menu.sel = idx; settings_press("ok") end)
      end
      y = y + 23
    end
  end
  footer("Su/giu: scegli    Sinistra/destra o click: cambia    Esc/B: salva e torna", W, H)
end

function Menu.draw(time)
  local W, H = Render.W, Render.H
  Menu.hits = {}
  toast_sound()
  background(time, W, H)
  -- transizione: la schermata entra scivolando
  local k = 1 - (1 - Menu.trans) ^ 3
  lg.push()
  lg.translate((1 - k) * 60 * Menu.dir, 0)
  if Menu.screen == "main" then draw_main(time, W, H)
  elseif Menu.screen == "heroes" then draw_heroes(time, W, H)
  elseif Menu.screen == "settings" then draw_settings(time, W, H)
  elseif Menu.screen == "recipes" then draw_recipes(time, W, H)
  else draw_achievements(time, W, H) end
  lg.pop()
  if Menu.trans < 1 then
    lg.setColor(UI.ink[1], UI.ink[2], UI.ink[3], (1 - k) * 0.8)
    lg.rectangle("fill", 0, 0, W, H)
  end
  if Menu.screen ~= "main" then back_button(time) end
  coins_box(W, time)
  toasts(W)
end

return Menu
