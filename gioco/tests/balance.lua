-- Partite simulate tra bot per controllare il ritmo e il bilanciamento.
-- Uso (dalla cartella del progetto): luajit tests/balance.lua [partite] [giocatori]
-- Stampa la durata dei round e le eliminazioni per arma. I bot sono semplici:
-- i numeri indicano tendenze, non il bilanciamento tra giocatori veri.
package.path = "./?.lua;" .. package.path
love = { math = { random = function(a, b)
  if a and b then return math.random(a, b) elseif a then return math.random(a) end
  return math.random() end } }
local Game = require("src.sim.game")
local Bot = require("src.bot")
local data = require("src.sim.data")

local matches = tonumber(arg[1]) or 6
local n = tonumber(arg[2]) or 4
math.randomseed(1234)
local lengths, kills, causes, lava_rounds, rounds = {}, {}, {}, 0, 0
for m = 1, matches do
  local g = Game.new({ players = n, seed = m * 31 })
  local round_start
  for _ = 1, 60 * 60 * 15 do
    local inputs = {}
    for i = 1, n do inputs[i] = Bot.think(g, i) end
    local was = g.phase
    g:update(inputs)
    if was == "countdown" and g.phase == "playing" then round_start = g.frame end
    if was == "playing" and g.phase ~= "playing" then
      lengths[#lengths + 1] = (g.frame - round_start) / 60
      rounds = rounds + 1
      if g.lava_on then lava_rounds = lava_rounds + 1 end
    end
    for _, e in ipairs(g:drain_events()) do
      if e.type == "death" then
        local k = e.weapon or e.cause or "?"
        kills[k] = (kills[k] or 0) + 1
      end
    end
    if g.phase == "matchend" then break end
  end
end
table.sort(lengths)
local sum = 0
for _, v in ipairs(lengths) do sum = sum + v end
print(string.format("%d giocatori, %d round: durata media %.1f s, mediana %.1f s, min %.1f, max %.1f; finiti con la lava: %d",
  n, rounds, sum / #lengths, lengths[math.floor(#lengths / 2) + 1], lengths[1], lengths[#lengths], lava_rounds))
local list = {}
for k, v in pairs(kills) do list[#list + 1] = { k, v } end
table.sort(list, function(a, b) return a[2] > b[2] end)
local parts = {}
for _, kv in ipairs(list) do parts[#parts + 1] = kv[1] .. " " .. kv[2] end
print("eliminazioni: " .. table.concat(parts, ", "))
