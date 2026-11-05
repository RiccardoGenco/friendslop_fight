-- Menu principale, galleria dei personaggi (skin e acquisti) e obiettivi.
-- Si comanda con tasti astratti: up down left right ok back (vedi main.lua).

local Render = require("src.render")
local Heroes = require("src.heroes")
local Profile = require("src.profile")
local Look = require("src.look")
local data = require("src.sim.data")

local lg = love.graphics
local floor, sin, min = math.floor, math.sin, math.min

local Menu = { screen = "main", sel = 1, hero = 1, skin = 1, scroll = 0, bump = 0 }

local ITEMS = {
  { id = "play", label = "Gioca" },
  { id = "heroes", label = "Personaggi" },
  { id = "achievements", label = "Obiettivi" },
  { id = "quit", label = "Esci" },
}

local GOLD = { 1, 0.85, 0.3 }
local DIM = { 0.6, 0.65, 0.8 }
local SKY = { name = "Tetti" }

function Menu.open(screen)
  Menu.screen, Menu.sel = screen or "main", 1
  if Menu.screen == "heroes" then
    local fav = Profile.data.fav
    Menu.hero = Heroes.get(fav.hero).index
    Menu.skin = fav.skin or 1
  end
end

-- ritorna "play" o "quit" quando il menu passa la mano a main
function Menu.press(b)
  local s = Menu.screen
  if s == "main" then
    if b == "up" then Menu.sel = (Menu.sel - 2) % #ITEMS + 1
    elseif b == "down" then Menu.sel = Menu.sel % #ITEMS + 1
    elseif b == "ok" then
      local id = ITEMS[Menu.sel].id
      if id == "play" or id == "quit" then return id end
      Menu.open(id)
    elseif b == "back" then Menu.sel = #ITEMS end
  elseif s == "heroes" then
    local h = Heroes.list[Menu.hero]
    if b == "left" or b == "right" then
      Menu.hero = (Menu.hero - 1 + (b == "left" and -1 or 1)) % #Heroes.list + 1
      Menu.skin = 1
    elseif b == "up" or b == "down" then
      Menu.skin = (Menu.skin - 1 + (b == "up" and -1 or 1)) % #h.skins + 1
    elseif b == "ok" then
      if Profile.skin_owned(h, Menu.skin) then
        Profile.data.fav = { hero = h.id, skin = Menu.skin }
        Profile.save()
        Profile.toast(h.name .. " " .. h.skins[Menu.skin].name .. ": scelto come preferito")
      elseif not Profile.buy(h, Menu.skin) then
        Menu.bump = 0.3
      end
    elseif b == "back" then Menu.open("main"); Menu.sel = 2 end
  elseif s == "achievements" then
    if b == "up" then Menu.scroll = math.max(0, Menu.scroll - 1)
    elseif b == "down" then Menu.scroll = min(#Profile.ACHIEVEMENTS - 7, Menu.scroll + 1)
    elseif b == "back" or b == "ok" then Menu.open("main"); Menu.sel = 3 end
  end
end

function Menu.update(dt)
  Menu.bump = math.max(0, Menu.bump - dt)
end

-- ---------------------------------------------------------------------------

local function fake(x, y, id, time, run)
  local vx = run and 120 or 0
  return { x = x, y = y, facing = 1, vx = vx, vy = 0, grounded = true, id = id }, { dist = time * 120 }
end

-- disegna un eroe ingrandito con i piedi in (x, y)
function Menu.draw_hero(hid, skin, x, y, scale, team, time, run, alpha, id)
  lg.push()
  lg.translate(x, y)
  lg.scale(scale)
  local p, ps = fake(0, 0, id or 1, time, run)
  Heroes.draw(hid, skin, p, team or data.colors[1], alpha or 1, false, time, ps)
  lg.pop()
end

local function coins(W)
  local t = tostring(Profile.data.coins)
  lg.setColor(0, 0, 0, 0.5)
  lg.rectangle("fill", W - 92, 8, 84, 18, 4, 4)
  lg.setColor(1, 0.8, 0.2)
  lg.circle("fill", W - 80, 17, 5)
  lg.setColor(0.75, 0.55, 0.1)
  lg.circle("line", W - 80, 17, 5)
  Render.text(t, W - 70, 11, GOLD, "mid", "left", 60)
end

local function toasts(W)
  local t = Profile.toasts[1]
  if not t then return end
  local k = min(1, t.t * 3, (3 - t.t) * 6)
  local y = 330 - 10 * (1 - k)
  lg.setColor(0, 0, 0, 0.7 * k)
  lg.rectangle("fill", W / 2 - 170, y - 3, 340, 18, 4, 4)
  Render.text(t.text, W / 2, y, { t.color[1], t.color[2], t.color[3], k }, "small", "center", 340)
end
Menu.draw_toasts = toasts

local function background(time, W, H)
  Look.sky(SKY, time, W, H)
  -- skyline semplice e pavimento
  lg.setColor(0.06, 0.06, 0.15)
  for i = 0, 20 do
    local bh = 40 + ((i * 37) % 70)
    lg.rectangle("fill", i * 34 - 10, H - 60 - bh, 30, bh)
  end
  lg.setColor(0.10, 0.09, 0.18)
  lg.rectangle("fill", 0, H - 60, W, 60)
  lg.setColor(0.30, 0.29, 0.36)
  lg.rectangle("fill", 0, H - 60, W, 3)
end

local function draw_main(time, W, H)
  -- parata degli eroi che corrono sul tetto
  for i, h in ipairs(Heroes.list) do
    local x = (time * 70 + i * 120) % (W + 160) - 80
    Menu.draw_hero(h.id, 1, x, H - 60, 2, data.colors[i], time + i, true, 1, i)
  end
  local ty = 34 + sin(time * 2) * 3
  Render.text("FRIENDSLOP", W / 2, ty, GOLD, "big", "center", W)
  Render.text("FIGHT", W / 2, ty + 34, { 1, 0.45, 0.35 }, "big", "center", W)
  for i, it in ipairs(ITEMS) do
    local y = 128 + (i - 1) * 26
    local on = i == Menu.sel
    if on then
      lg.setColor(1, 0.85, 0.3, 0.18)
      lg.rectangle("fill", W / 2 - 90, y - 4, 180, 22, 4, 4)
      local ax = W / 2 - 84 + sin(time * 8) * 2
      lg.setColor(1, 0.85, 0.3)
      lg.polygon("fill", ax, y + 2, ax + 6, y + 7, ax, y + 12)
    end
    Render.text(it.label, W / 2, y, on and GOLD or { 0.85, 0.88, 1 }, "mid", "center", 200)
  end
  Render.text("Frecce/WASD o croce per muoverti, Invio/A per scegliere, Esc/B per tornare",
    W / 2, H - 22, DIM, "small", "center", W)
end

local function draw_heroes(time, W, H)
  local h = Heroes.list[Menu.hero]
  Render.text("PERSONAGGI", W / 2, 14, GOLD, "big", "center", W)
  -- striscia dei personaggi
  for i, hh in ipairs(Heroes.list) do
    local x = W / 2 + (i - (#Heroes.list + 1) / 2) * 46
    local on = i == Menu.hero
    lg.setColor(1, 1, 1, on and 0.2 or 0.06)
    lg.rectangle("fill", x - 20, 56, 40, 40, 4, 4)
    if on then lg.setColor(1, 0.85, 0.3); lg.rectangle("line", x - 20, 56, 40, 40, 4, 4) end
    local owned = Profile.hero_owned(hh)
    Menu.draw_hero(hh.id, 1, x, 92, 1.4, data.colors[1], time, false, owned and 1 or 0.35, i)
    if not owned then Render.text("?", x, 62, { 1, 1, 1, 0.8 }, "mid", "center", 40) end
  end
  -- anteprima grande
  local owned = Profile.skin_owned(h, Menu.skin)
  local px = W / 2 - 110 + (Menu.bump > 0 and sin(Menu.bump * 60) * 3 or 0)
  lg.setColor(0, 0, 0, 0.35)
  lg.ellipse("fill", px, 268, 40, 6)
  Menu.draw_hero(h.id, Menu.skin, px, 268, 5, data.colors[1], time, false, owned and 1 or 0.45, 1)
  -- scheda
  local x = W / 2 - 10
  Render.text(h.name, x, 112, { 1, 1, 1 }, "big", "left", 300)
  Render.text(h.title, x, 146, DIM, "mid", "left", 300)
  for i, s in ipairs(h.skins) do
    local y = 174 + (i - 1) * 22
    local on = i == Menu.skin
    if on then
      lg.setColor(1, 1, 1, 0.12)
      lg.rectangle("fill", x - 6, y - 3, 260, 19, 3, 3)
    end
    local lock = Profile.lock_text(h, i)
    local c = s.pal.F
    lg.setColor(c[1], c[2], c[3]); lg.rectangle("fill", x, y + 2, 9, 9)
    c = s.pal.C or s.pal.A
    lg.setColor(c[1], c[2], c[3]); lg.rectangle("fill", x + 10, y + 2, 9, 9)
    Render.text(s.name, x + 26, y, on and GOLD or { 0.9, 0.9, 1 }, "mid", "left", 120)
    Render.text(lock or "tua", x + 120, y + 2, lock and { 1, 0.6, 0.45 } or { 0.5, 1, 0.6 }, "small", "left", 140)
  end
  local fav = Profile.data.fav
  local hint
  if owned then
    hint = (fav.hero == h.id and fav.skin == Menu.skin) and "Preferito" or "Invio/A: imposta come preferito"
  else
    local text, price = Profile.lock_text(h, Menu.skin)
    if price then
      hint = (Profile.data.coins >= price) and ("Invio/A: compra per " .. text) or ("Ti servono " .. text)
    else
      hint = "Si sblocca con un obiettivo"
    end
  end
  Render.text(hint, x, 248, GOLD, "small", "left", 260)
  Render.text("Sinistra/destra: personaggio   su/giu: skin   Esc/B: indietro", W / 2, H - 22, DIM, "small", "center", W)
end

local function draw_achievements(time, W, H)
  Render.text("OBIETTIVI", W / 2, 14, GOLD, "big", "center", W)
  local list = Profile.ACHIEVEMENTS
  for k = 1, 7 do
    local a = list[k + Menu.scroll]
    if not a then break end
    local y = 54 + (k - 1) * 36
    local done = Profile.data.done[a.id]
    lg.setColor(0, 0, 0, 0.45)
    lg.rectangle("fill", 60, y, W - 120, 32, 4, 4)
    Render.text(a.name, 70, y + 3, done and { 0.5, 1, 0.6 } or { 1, 1, 1 }, "mid", "left", 260)
    Render.text(a.desc, 70, y + 19, DIM, "small", "left", 300)
    local reward = "+" .. a.coins
    for _, h in ipairs(Heroes.list) do
      for _, s in ipairs(h.skins) do
        if s.unlock == a.id then reward = reward .. "  skin " .. s.name end
      end
    end
    Render.text(reward, W - 70, y + 3, GOLD, "small", "right", 200)
    local pr = Profile.progress(a)
    lg.setColor(0.15, 0.15, 0.2)
    lg.rectangle("fill", W - 230, y + 20, 160, 5)
    lg.setColor(done and 0.4 or 1, done and 1 or 0.8, done and 0.5 or 0.3)
    lg.rectangle("fill", W - 230, y + 20, 160 * pr / a.goal, 5)
    Render.text(pr .. "/" .. a.goal, W - 236, y + 17, DIM, "small", "right", 60)
  end
  Render.text("Su/giu: scorri   Esc/B: indietro", W / 2, H - 22, DIM, "small", "center", W)
end

function Menu.draw(time)
  local W, H = Render.W, Render.H
  background(time, W, H)
  if Menu.screen == "main" then draw_main(time, W, H)
  elseif Menu.screen == "heroes" then draw_heroes(time, W, H)
  else draw_achievements(time, W, H) end
  coins(W)
  toasts(W)
end

return Menu
