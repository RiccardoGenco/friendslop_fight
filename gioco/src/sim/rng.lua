-- Generatore di numeri casuali con seme (Park-Miller).
-- Serve a rendere ogni round riproducibile: stesso seme + stessi input = stessa partita.
local RNG = {}
RNG.__index = RNG

function RNG.new(seed)
  local s = math.floor(math.abs(seed or 1)) % 2147483646 + 1
  return setmetatable({ s = s }, RNG)
end

function RNG:next()
  self.s = (self.s * 16807) % 2147483647
  return self.s
end

-- float in [0, 1)
function RNG:float()
  return (self:next() - 1) / 2147483646
end

-- intero in [a, b]
function RNG:int(a, b)
  return a + math.floor(self:float() * (b - a + 1))
end

function RNG:range(a, b)
  return a + self:float() * (b - a)
end

function RNG:pick(list)
  return list[self:int(1, #list)]
end

-- entries: lista di { key = ..., weight = n }
function RNG:weighted(entries)
  local total = 0
  for _, e in ipairs(entries) do total = total + e.weight end
  local r = self:float() * total
  for _, e in ipairs(entries) do
    r = r - e.weight
    if r < 0 then return e.key end
  end
  return entries[#entries].key
end

function RNG:shuffle(list)
  for i = #list, 2, -1 do
    local j = self:int(1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

return RNG
