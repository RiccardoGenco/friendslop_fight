-- Elementi interattivi delle mappe: molle, nastri trasportatori, portali.
-- Chiamato a ogni passo dopo il movimento dei giocatori. Deterministico.

local data = require("src.sim.data")

local G = {}
local T = data.tile

local function in_portal(pt, x, cy)
  return math.abs(x - pt.x) < 7 and cy > pt.y - 2 * T and cy < pt.y
end

function G.update(game)
  local w = game.world
  local K = data.gadgets
  local dt = data.dt
  for _, p in ipairs(game.players) do
    if p.alive then
      -- molle: chi ci arriva sopra (in piedi o cadendo) vola in alto e ritrova il doppio salto
      for _, s in ipairs(w.springs) do
        if math.abs(p.x - s.x) < T / 2 + p.w / 2 - 2 and p.y >= s.y - 3 and p.y <= s.y + 0.5 and p.vy >= 0 then
          p.vy = -K.spring_vel
          p.grounded, p.coyote = false, 0
          p.jump_cut_done = true
          p.air_jumps = data.player.air_jumps
          p.on_mover = nil
          game:emit("spring", s.x, s.y, { id = p.id })
        end
      end
      -- nastri
      if p.grounded and not p.on_mover then
        local d = w:belt_under(p)
        if d ~= 0 then w:move_x(p, d * K.belt_speed * dt) end
      end
      -- portali: si esce dall'altro con la stessa velocita'
      -- chi esce da un portale deve allontanarsene prima di poterlo riprendere
      if p.portal_in and not in_portal(p.portal_in, p.x, p.y - p.h / 2) then p.portal_in = nil end
      if (p.portal_cd or 0) > 0 then
        p.portal_cd = p.portal_cd - 1
      else
        for _, pt in ipairs(w.portals) do
          if pt ~= p.portal_in and in_portal(pt, p.x, p.y - p.h / 2) then
            game:emit("portal", pt.x, pt.y - T, { id = p.id, tx = pt.to.x, ty = pt.to.y - T })
            p.x, p.y = pt.to.x, pt.to.y
            p.grapple, p.on_mover = nil, nil
            p.portal_cd = K.portal_cd
            p.portal_in = pt.to
            break
          end
        end
      end
    end
  end
  -- anche le armi a terra viaggiano sui nastri, e i proiettili passano dai portali
  for _, it in ipairs(game.items) do
    local d = w:belt_under(it)
    if d ~= 0 then w:move_x(it, d * K.belt_speed * dt) end
  end
  for _, pr in ipairs(game.projectiles) do
    if (pr.portal_cd or 0) > 0 then
      pr.portal_cd = pr.portal_cd - 1
    elseif not pr.stuck then
      for _, pt in ipairs(w.portals) do
        if in_portal(pt, pr.x, pr.y) then
          pr.x, pr.y = pt.to.x, pt.to.y - T
          pr.portal_cd = K.portal_cd
          game:emit("portal", pt.x, pt.y - T, { tx = pt.to.x, ty = pt.to.y - T, small = true })
          break
        end
      end
    end
  end
end

return G
