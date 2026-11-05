-- Profilo salvato su disco: monete, personaggi e skin sbloccati, obiettivi, statistiche.
-- Un solo profilo per computer (party game sullo stesso schermo).
-- Contano solo i giocatori umani; i bot non fanno guadagnare niente.

local Heroes = require("src.heroes")
local data = require("src.sim.data")

local Profile = {}
local FILE = "profilo.lua"

Profile.ACHIEVEMENTS = {
  { id = "primo_sangue", name = "Primo sangue", desc = "Elimina un avversario", stat = "kills", goal = 1, coins = 50 },
  { id = "cacciatore", name = "Cacciatore", desc = "Elimina 50 avversari", stat = "kills", goal = 50, coins = 200 },
  { id = "campione", name = "Campione", desc = "Vinci una partita", stat = "wins", goal = 1, coins = 100 },
  { id = "ultimo", name = "Ultimo in piedi", desc = "Vinci 10 round", stat = "rounds_won", goal = 10, coins = 100 },
  { id = "veterano", name = "Veterano", desc = "Gioca 20 partite", stat = "matches", goal = 20, coins = 150 },
  { id = "muro_maestro", name = "Ninja dei muri", desc = "Fai 100 salti dal muro", stat = "walljumps", goal = 100, coins = 100 },
  { id = "parata", name = "Mano ferma", desc = "Fai 10 parry perfetti", stat = "perfect_parries", goal = 10, coins = 150 },
  { id = "mitico", name = "Leggenda", desc = "Elimina qualcuno con un'arma mitica", stat = "mythic_kills", goal = 1, coins = 150 },
  { id = "demolitore", name = "Demolitore", desc = "Elimina 15 avversari con le esplosioni", stat = "explosive_kills", goal = 15, coins = 150 },
  { id = "collezionista", name = "Collezionista", desc = "Raccogli 100 armi", stat = "pickups", goal = 100, coins = 150 },
}
Profile.by_id = {}
for _, a in ipairs(Profile.ACHIEVEMENTS) do Profile.by_id[a.id] = a end

-- monete guadagnate in partita
Profile.REWARD = { match = 20, kill = 5, round = 3, win = 30 }

local EXPLOSIVE = { grenade = true, bazooka = true, mines = true, swarm = true }

local function fresh()
  return { coins = 0, owned = {}, done = {}, stats = {}, fav = { hero = "gatto", skin = 1 } }
end

local p = fresh()
Profile.data = p
Profile.toasts = {}       -- avvisi a schermo (obiettivi, acquisti)
Profile.match = nil       -- monete e obiettivi della partita in corso

local function serialize(v, ind)
  ind = ind or ""
  if type(v) == "table" then
    local out = { "{\n" }
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local key = type(k) == "number" and ("[" .. k .. "]") or string.format("[%q]", k)
      out[#out + 1] = ind .. "  " .. key .. " = " .. serialize(v[k], ind .. "  ") .. ",\n"
    end
    out[#out + 1] = ind .. "}"
    return table.concat(out)
  elseif type(v) == "string" then
    return string.format("%q", v)
  end
  return tostring(v)
end

function Profile.load()
  local fs = love.filesystem
  local ok, text = pcall(function() return fs.getInfo(FILE) and fs.read(FILE) end)
  if ok and type(text) == "string" then
    local chunk = loadstring and loadstring("return " .. text) or load("return " .. text)
    local good, t = pcall(chunk or function() end)
    if good and type(t) == "table" then
      local base = fresh()
      for k, v in pairs(base) do if type(t[k]) ~= type(v) then t[k] = v end end
      p = t
    end
  end
  Profile.data = p
end

function Profile.save()
  pcall(function() love.filesystem.write(FILE, serialize(p)) end)
end

function Profile.toast(text, color)
  Profile.toasts[#Profile.toasts + 1] = { text = text, color = color or { 1, 0.85, 0.3 }, t = 3 }
end

-- ---------------------------------------------------------------------------
-- Sblocchi

function Profile.hero_owned(h)
  return h.price == 0 or p.owned[h.id] == true
end

function Profile.skin_owned(h, i)
  if not Profile.hero_owned(h) then return false end
  local s = h.skins[i]
  if not s then return false end
  if s.unlock then return p.done[s.unlock] == true end
  return not s.price or p.owned[h.id .. ":" .. i] == true
end

-- descrizione di cosa serve per sbloccare (nil se gia' tuo)
function Profile.lock_text(h, i)
  if not Profile.hero_owned(h) then return h.price .. " monete", h.price end
  local s = h.skins[i]
  if Profile.skin_owned(h, i) then return nil end
  if s.unlock then return "Obiettivo: " .. Profile.by_id[s.unlock].name end
  return s.price .. " monete", s.price
end

-- compra il personaggio (se bloccato) o la skin; ritorna true se ha comprato
function Profile.buy(h, i)
  local _, price = Profile.lock_text(h, i)
  if not price or p.coins < price then return false end
  p.coins = p.coins - price
  if not Profile.hero_owned(h) then
    p.owned[h.id] = true
    Profile.toast("Sbloccato " .. h.name .. "!")
  else
    p.owned[h.id .. ":" .. i] = true
    Profile.toast("Skin " .. h.skins[i].name .. " sbloccata!")
  end
  Profile.save()
  return true
end

-- ---------------------------------------------------------------------------
-- Statistiche e obiettivi

local function bump(stat, n)
  p.stats[stat] = (p.stats[stat] or 0) + (n or 1)
  for _, a in ipairs(Profile.ACHIEVEMENTS) do
    if a.stat == stat and not p.done[a.id] and p.stats[stat] >= a.goal then
      p.done[a.id] = true
      p.coins = p.coins + a.coins
      Profile.toast("Obiettivo: " .. a.name .. "  +" .. a.coins .. " monete", { 0.5, 1, 0.6 })
      if Profile.match then
        Profile.match.unlocked[#Profile.match.unlocked + 1] = a.name
      end
      for _, h in ipairs(Heroes.list) do
        for _, s in ipairs(h.skins) do
          if s.unlock == a.id then Profile.toast("Nuova skin: " .. h.name .. " " .. s.name, { 0.7, 0.8, 1 }) end
        end
      end
    end
  end
end

function Profile.progress(a) return math.min(a.goal, p.stats[a.stat] or 0) end

function Profile.start_match()
  Profile.match = { coins = 0, unlocked = {} }
end

local function earn(n)
  p.coins = p.coins + n
  if Profile.match then Profile.match.coins = Profile.match.coins + n end
end

-- eventi della simulazione; is_human(id) dice se il giocatore e' una persona
function Profile.event(e, is_human)
  local t = e.type
  if t == "death" then
    local k = e.killer
    if k and k ~= e.id and is_human(k) then
      earn(Profile.REWARD.kill)
      bump("kills")
      local w = e.weapon and data.weapons[e.weapon]
      if w and w.tier == 4 then bump("mythic_kills") end
      if e.cause == "explosion" or EXPLOSIVE[e.weapon] then bump("explosive_kills") end
    end
  elseif t == "walljump" and e.id and is_human(e.id) then
    bump("walljumps")
  elseif t == "perfect_parry" and e.id and is_human(e.id) then
    bump("perfect_parries")
  elseif t == "pickup" and e.id and is_human(e.id) then
    bump("pickups")
  elseif t == "round_end" then
    for _, id in ipairs(e.winners or {}) do
      if is_human(id) then earn(Profile.REWARD.round); bump("rounds_won") end
    end
  elseif t == "match_end" then
    earn(Profile.REWARD.match)
    bump("matches")
    for _, id in ipairs(e.winners or {}) do
      if is_human(id) then earn(Profile.REWARD.win); bump("wins"); break end
    end
    Profile.save()
  end
end

function Profile.update(dt)
  local list = Profile.toasts
  if list[1] then
    list[1].t = list[1].t - dt
    if list[1].t <= 0 then table.remove(list, 1) end
  end
end

return Profile
