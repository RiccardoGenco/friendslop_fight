-- Partita completa: match, round, armi a terra, proiettili, morte improvvisa.
-- Nessuna dipendenza da LÖVE: si puo' simulare senza finestra.
--
-- Uso:
--   local g = Game.new{ players = 4, seed = 123 }
--   ogni frame (60 al secondo):  g:update(inputs)   -- inputs[i] = tabella input del giocatore i
--   eventi per grafica e audio:  for _, e in ipairs(g:drain_events()) do ... end
local data = require("src.sim.data")
local RNG = require("src.sim.rng")
local World = require("src.sim.world")
local Player = require("src.sim.player")
local Combat = require("src.sim.combat")
local MapEvents = require("src.sim.mapevents")

local Game = {}
Game.__index = Game

local MAP_NAMES = { "arena", "fabbrica", "tetti" }
local EMPTY = {}
local min, max = math.min, math.max

function Game.new(opts)
  opts = opts or {}
  local g = setmetatable({}, Game)
  g.n = opts.players or 2
  g.seed = opts.seed or 1
  g.rng = RNG.new(g.seed)
  g.frame = 0
  g.events = {}
  g.scores = {}
  for i = 1, g.n do g.scores[i] = 0 end
  g.wins_target = opts.wins or (g.n == 2 and data.round.wins_duel or data.round.wins)
  g.round = 0
  g.recent_maps = {}
  g.map_names = opts.maps or MAP_NAMES
  g.winners = {}
  g.match_winners = nil
  g.next_item_id = 1
  g:start_round(opts.first_map)
  return g
end

function Game:emit(kind, x, y, extra)
  local e = extra or {}
  e.type, e.x, e.y = kind, x, y
  self.events[#self.events + 1] = e
end

function Game:drain_events()
  local ev = self.events
  self.events = {}
  return ev
end

-- ---------------------------------------------------------------------------
-- Round

function Game:pick_map(forced)
  if forced then return forced end
  local candidates = {}
  for _, name in ipairs(self.map_names) do
    local recent = false
    for _, r in ipairs(self.recent_maps) do
      if r == name then recent = true end
    end
    if not recent then candidates[#candidates + 1] = name end
  end
  if #candidates == 0 then candidates = self.map_names end
  return self.rng:pick(candidates)
end

function Game:start_round(forced_map)
  local R = data.round
  self.round = self.round + 1
  self.map_name = self:pick_map(forced_map)
  self.recent_maps[#self.recent_maps + 1] = self.map_name
  while #self.recent_maps > R.map_repeat_block do table.remove(self.recent_maps, 1) end

  self.world = World.new(require("src.maps." .. self.map_name))
  local world = self.world

  local spawns = {}
  for _, s in ipairs(world.spawns) do spawns[#spawns + 1] = s end
  self.rng:shuffle(spawns)

  self.players = {}
  for i = 1, self.n do
    local s = spawns[((i - 1) % #spawns) + 1]
    self.players[i] = Player.new(i, s, data.colors[((i - 1) % #data.colors) + 1])
  end

  self.items, self.projectiles, self.telegraphs, self.fields = {}, {}, {}, {}
  -- armi iniziali: meno dei giocatori, in punti diversi della mappa, cosi' si fa a gara
  local pts = {}
  for _, s in ipairs(world.weapon_spawns) do pts[#pts + 1] = s end
  self.rng:shuffle(pts)
  local count = min(#pts, max(1, self.n - R.start_items_less))
  for k = 1, count do
    local it = self:add_item(pts[k].x, pts[k].y - 6, self:random_weapon(data.start_tier))
    it.life = it.life + R.countdown
  end

  self.phase = "countdown"
  self.timer = R.countdown
  self.round_frame = 0
  self.lava_on = false
  self.lava_y = world.height
  self.spawn_timer = self.rng:int(R.spawn_min, R.spawn_max)
  self.crate_timer = self.rng:int(R.crate_min, R.crate_max)
  self.winners = {}
  MapEvents.reset(self)
  self:emit("round_setup", 0, 0, { round = self.round, map = world.name })
end

function Game:alive_count()
  local n = 0
  for _, p in ipairs(self.players) do
    if p.alive then n = n + 1 end
  end
  return n
end

function Game:check_round_end()
  local R = data.round
  local alive = {}
  for _, p in ipairs(self.players) do
    if p.alive then alive[#alive + 1] = p end
  end
  if #alive > 1 then return end
  local winners = {}
  if #alive == 1 then
    winners[1] = alive[1].id
  else
    local last = 0
    for _, p in ipairs(self.players) do
      if p.death_frame and p.death_frame > last then last = p.death_frame end
    end
    for _, p in ipairs(self.players) do
      if p.death_frame and p.death_frame >= last - R.simultaneous_window then
        winners[#winners + 1] = p.id
      end
    end
  end
  for _, id in ipairs(winners) do self.scores[id] = self.scores[id] + 1 end
  self.winners = winners
  self.phase = "roundend"
  self.timer = R.end_delay
  self:emit("round_end", 0, 0, { winners = winners })
end

function Game:finish_round_end()
  local best = 0
  for _, s in ipairs(self.scores) do best = max(best, s) end
  if best >= self.wins_target then
    local w = {}
    for i, s in ipairs(self.scores) do
      if s == best then w[#w + 1] = i end
    end
    self.match_winners = w
    self.phase = "matchend"
    self:emit("match_end", 0, 0, { winners = w })
  else
    self:start_round()
  end
end

-- ---------------------------------------------------------------------------
-- Armi a terra

-- Crea un'arma nuova (piena di munizioni o colpi). Il secondo argomento e' ignorato:
-- resta per compatibilita' con il codice della v0.2.
function Game:make_weapon(id)
  local def = data.weapons[id]
  local w = { id = id, tier = def.tier or 1, dmg_mul = 1 }
  if def.uses then w.uses = def.uses end
  if def.ammo then w.ammo = def.ammo end
  return w
end

-- Probabilita' dei livelli in questo momento del round (si spostano verso i livelli alti)
function Game:tier_weights()
  local k = min(1, max(0, (self.round_frame or 0) / data.tier_ramp_frames))
  local out = {}
  for t, tier in ipairs(data.tiers) do
    out[#out + 1] = { key = t, weight = tier.weight_start + (tier.weight_end - tier.weight_start) * k }
  end
  return out
end

-- Arma a caso: prima il livello (se non e' dato), poi l'arma dentro il livello
function Game:random_weapon(tier)
  if type(tier) ~= "number" then tier = self.rng:weighted(self:tier_weights()) end
  local entries = {}
  for _, id in ipairs(data.tiers[tier].weapons) do
    entries[#entries + 1] = { key = id, weight = data.weapons[id].weight or 10 }
  end
  return self:make_weapon(self.rng:weighted(entries))
end

-- Contenuto della cassa centrale: solo livelli alti
function Game:crate_weapon()
  local entries = {}
  for _, c in ipairs(data.crate_tiers) do entries[#entries + 1] = { key = c.tier, weight = c.weight } end
  return self:random_weapon(self.rng:weighted(entries))
end

function Game:add_item(x, y, weapon, vx, vy)
  local it = {
    id = self.next_item_id, x = x, y = y, w = 10, h = 8,
    vx = vx or 0, vy = vy or 0, weapon = weapon,
    life = data.round.item_life, grounded = false, pickup_delay = 0,
  }
  self.next_item_id = self.next_item_id + 1
  self.items[#self.items + 1] = it
  return it
end

-- Lascia cadere un'arma (morte o cambio arma)
function Game:drop_item(x, y, weapon, vx)
  local it = self:add_item(x, y, weapon, vx or 0, -120)
  it.pickup_delay = 20
  return it
end

function Game:update_items()
  local world = self.world
  local dt = data.dt
  for i = #self.items, 1, -1 do
    local it = self.items[i]
    it.life = it.life - 1
    if it.pickup_delay > 0 then it.pickup_delay = it.pickup_delay - 1 end
    it.vy = min(it.vy + 700 * dt, 400)
    if it.grounded then it.vx = it.vx * 0.8 end
    world:move_x(it, it.vx * dt)
    local landed = world:move_y(it, it.vy * dt)
    if landed then it.vy = 0; it.grounded = true else it.grounded = false end
    if it.life <= 0 or it.y > world.height + 40 or (self.lava_on and it.y > self.lava_y) then
      table.remove(self.items, i)
    end
  end
end

function Game:update_spawner()
  local R = data.round
  local world = self.world
  self.spawn_timer = self.spawn_timer - 1
  if self.spawn_timer <= 0 then
    self.spawn_timer = self.rng:int(R.spawn_min, R.spawn_max)
    local pts = world.weapon_spawns
    if #pts > 0 and (#self.items + #self.telegraphs) < R.max_items then
      local pt = self.rng:pick(pts)
      self.telegraphs[#self.telegraphs + 1] = { x = pt.x, y = pt.y - 6, t = R.telegraph,
                                                weapon = self:random_weapon() }
      self:emit("telegraph", pt.x, pt.y)
    end
  end
  self.crate_timer = self.crate_timer - 1
  if self.crate_timer <= 0 then
    self.crate_timer = self.rng:int(R.crate_min, R.crate_max)
    local c = world.crate
    self.telegraphs[#self.telegraphs + 1] = { x = c.x, y = c.y, t = R.telegraph,
                                              weapon = self:crate_weapon(), crate = true }
    self:emit("telegraph", c.x, c.y, { crate = true })
  end
  for i = #self.telegraphs, 1, -1 do
    local t = self.telegraphs[i]
    t.t = t.t - 1
    if t.t <= 0 then
      self:add_item(t.x, t.y, t.weapon)
      self:emit("item_spawn", t.x, t.y, { crate = t.crate })
      table.remove(self.telegraphs, i)
    end
  end
end

function Game:update_pickups()
  for _, p in ipairs(self.players) do
    local attacking = p.action and p.action.type == "attack"
    if p.alive and p.hitstun == 0 and p.clash == 0 and not attacking then
      local wants = p.buf.pickup > 0
      if wants or not p.weapon then
        local x1, y1, x2, y2 = Player.box(p)
        local found
        for _, it in ipairs(self.items) do
          if it.pickup_delay <= 0
             and Combat.overlap(x1 - 3, y1 - 3, x2 + 3, y2 + 3, it.x - 5, it.y - 8, it.x + 5, it.y) then
            found = it
            break
          end
        end
        if found then
          if p.weapon then self:drop_item(p.x, p.y - 6, p.weapon, 0) end
          p.weapon = found.weapon
          for i, it in ipairs(self.items) do
            if it == found then table.remove(self.items, i); break end
          end
          p.buf.pickup = 0
          self:emit("pickup", p.x, p.y - 12, { id = p.id, weapon = p.weapon.id })
        elseif wants and p.weapon and not p.action then
          p.buf.pickup = 0
          Combat.throw_weapon(self, p)
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Pericoli

-- Chi cade nel vuoto (mappa Tetti) muore, in qualunque fase del round.
function Game:update_void()
  local limit = self.world.height + data.player.fall_death_margin
  for _, p in ipairs(self.players) do
    if p.alive and p.y > limit then
      Combat.kill(self, p, nil, "void")
    end
  end
end

function Game:update_hazards()
  local P = data.player
  local world = self.world
  for _, p in ipairs(self.players) do
    if p.alive then
      local x1, y1, x2, y2 = Player.box(p)
      if p.spike_cd == 0 and p.invuln == 0 and world:rect_touches(x1, y2 - 8, x2, y2, "^") then
        p.spike_cd = P.spike_cooldown
        Combat.hazard_hit(self, p, P.spike_damage, "spikes")
      end
      if p.alive and self.lava_on and p.y > self.lava_y then
        Combat.kill(self, p, nil, "lava")
      end
    end
  end
  self:update_void()
end

function Game:update_lava()
  local R = data.round
  if self.round_frame == R.sudden_death_warning then
    self:emit("sudden_death_warning", 0, 0)
  end
  if self.round_frame >= R.sudden_death then
    if not self.lava_on then
      self.lava_on = true
      self:emit("sudden_death", 0, 0)
    end
    self.lava_y = self.lava_y - R.lava_speed
  end
end

-- ---------------------------------------------------------------------------
-- Aggiornamento

function Game:step_players(inputs, idle)
  local n = #self.players
  for k = 0, n - 1 do
    local i = ((self.frame + k) % n) + 1
    Player.update(self.players[i], idle and EMPTY or (inputs[i] or EMPTY), self)
  end
end

function Game:update(inputs)
  inputs = inputs or EMPTY
  self.frame = self.frame + 1
  local ph = self.phase
  if ph == "countdown" then
    self:step_players(inputs, true)
    self:update_void()
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self.phase = "playing"
      self.round_frame = 0
      self:emit("round_start", 0, 0)
    end
  elseif ph == "playing" then
    self.round_frame = self.round_frame + 1
    self:step_players(inputs, false)
    Combat.update_projectiles(self)
    Combat.update_fields(self)
    self:update_items()
    self:update_pickups()
    self:update_hazards()
    self:update_lava()
    MapEvents.update(self)
    self:update_spawner()
    self:check_round_end()
  elseif ph == "roundend" then
    self:step_players(inputs, true)
    Combat.update_projectiles(self)
    Combat.update_fields(self)
    self:update_items()
    self:update_void()
    self.timer = self.timer - 1
    if self.timer <= 0 then self:finish_round_end() end
  end
end

-- Riassunto numerico dello stato, utile per i test di determinismo
function Game:checksum()
  local s = 0
  for _, p in ipairs(self.players) do
    s = s + p.x * 1.3 + p.y * 1.7 + p.hp * 0.3 + p.vx * 0.01 + p.vy * 0.02
  end
  s = s + #self.items * 11 + #self.projectiles * 7 + self.frame * 0.001
  return string.format("%.4f", s)
end

return Game
