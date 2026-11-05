-- Piattaforme mobili: attraversabili dal basso come "=", si muovono avanti e indietro
-- con un'andatura morbida (coseno). Chi ci sta sopra viene trasportato.
-- Nella mappa: movers = { { c = colonna, r = riga, len = tile, dc = spostamento in tile,
--                          dr = spostamento in tile, period = frame per un giro completo } }

local data = require("src.sim.data")

local M = {}
local T = data.tile

function M.reset(game)
  game.movers = {}
  for i, d in ipairs(game.world.movers_def) do
    local x0, y0 = (d.c - 1) * T, (d.r - 1) * T
    game.movers[i] = { id = i, x0 = x0, y0 = y0, x = x0, y = y0, w = d.len * T,
                       ddx = d.dc * T, ddy = d.dr * T, period = d.period or 300, phase = d.phase or 0,
                       vx = 0, vy = 0 }
  end
end

function M.update(game)
  local f = game.frame
  for _, m in ipairs(game.movers or {}) do
    local k = (1 - math.cos(2 * math.pi * (f / m.period + m.phase))) / 2
    local nx, ny = m.x0 + m.ddx * k, m.y0 + m.ddy * k
    local dx, dy = nx - m.x, ny - m.y
    m.x, m.y, m.vx, m.vy = nx, ny, dx, dy
    for _, p in ipairs(game.players) do
      if p.alive and p.on_mover == m.id and p.grounded then
        game.world:move_x(p, dx)
        p.y = m.y
      end
    end
  end
end

-- dopo il movimento verticale del giocatore: atterra su una piattaforma mobile?
function M.collide(game, p, prev_y, drop)
  if drop or p.vy < 0 then return false end
  for _, m in ipairs(game.movers or {}) do
    local hw = p.w / 2
    if p.x + hw > m.x and p.x - hw < m.x + m.w
       and prev_y <= m.y + math.max(0, -m.vy) + 0.5 and p.y >= m.y then
      p.y = m.y
      p.on_mover = m.id
      return true
    end
  end
  return false
end

return M
